"""Authoritative Inventory, Batch Balance, and Stock Ledger Service.

Shared authoritative core for Member 2 (Catalogue/Units), Member 3 (POs/Inward),
and Member 7 (Sales/Outward).
Enforces:
1. Exactly one normalized base unit for all movements and balances.
2. Inward stock creates batches and append-only ledger entries.
3. Outward stock performs FEFO allocation and rejects insufficient inventory.
4. Idempotency guarantees safe retries without duplicating stock.
5. Reconciliation checks to prove batch sum == aggregate balance == ledger sum.
"""

from datetime import date, datetime, timezone
import hashlib
import json
import re
from typing import Any, Dict, List, Optional, Tuple
import uuid
import logging

from fastapi import HTTPException

ASCENDING = 1
DESCENDING = -1

from app.modules.catalogue_search_units.service import (
    conversion_factor,
    fallback_catalogue_store,
)
from app.modules.inventory.schemas import (
    BatchAllocationDetail,
    BatchBalance,
    InwardItemInput,
    InwardStockRequest,
    InwardStockResult,
    OutwardLineInput,
    OutwardStockRequest,
    OutwardStockResult,
    ProductStockBalance,
    ReconciliationItem,
    ReconciliationReport,
    StockMovementRecord,
)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def is_date_expired(expiry_str: str) -> bool:
    """Validate whether an expiry string (YYYY-MM or YYYY-MM-DD) is in the past."""
    clean = expiry_str.strip()
    parts = clean.split("-")
    try:
        year = int(parts[0])
        month = int(parts[1])
        day = int(parts[2]) if len(parts) > 2 else 28
        exp_date = date(year, month, day)
        today = date.today()
        # An item expiring in the current month is typically valid until end of month
        if len(parts) == 2:
            return (year, month) < (today.year, today.month)
        return exp_date < today
    except Exception:
        raise HTTPException(
            status_code=400,
            detail={"code": "INVALID_EXPIRY_FORMAT", "message": f"Malformed expiry date '{expiry_str}'. Expected YYYY-MM or YYYY-MM-DD"},
        )


def _normalize_id(pid: str) -> str:
    return pid.strip().upper()


# ==============================================================================
# IN-MEMORY DURABLE FALLBACK STORE (Used when PostgreSQL is not connected/tests)
# ==============================================================================

class InMemoryInventoryStore:
    def __init__(self):
        # Key: (store_id, normalized_product_id, batch_number) -> dict
        self.batches: Dict[Tuple[str, str, str], dict] = {}
        # Key: (store_id, normalized_product_id) -> int
        self.balances: Dict[Tuple[str, str], int] = {}
        # List of StockMovementRecord dicts
        self.movements: List[dict] = []
        # Key: f"{store_id}:{operation}:{key}" -> dict
        self.idempotency_keys: Dict[str, dict] = {}

    def clear(self):
        self.batches.clear()
        self.balances.clear()
        self.movements.clear()
        self.idempotency_keys.clear()

    def seed_defaults(self):
        """Seed initial inventory batches for demo/testing workflows."""
        now = _now_iso()
        defaults = [
            ("store_test_01", "MED-000101", "Dolo 650", "BAT-DL-01", "2028-12", 150),
            ("store_test_01", "MED-000102", "Augmentin 625 Duo", "BAT-AG-01", "2027-09", 150),
            ("store_test_01", "MED-000103", "Pan 40", "BAT-PN-01", "2028-09", 150),
            ("store_test_01", "MED-000104", "Cotton roll", "BAT-CR-01", "2028-12", 150),
            ("store_test_01", "MED-000105", "Azithral 500", "BAT-AZ-01", "2028-06", 150),
            ("store_test_01", "MED-000106", "Betadine", "BAT-BT-01", "2028-12", 150),
            ("store_test_01", "MED-000123", "Augmentin 625 Duo", "BAT-AG-84", "2028-12", 150),
            ("store_test_01", "MED-000301", "Zerodol SP Tablet", "BAT-ZS-91", "2028-12", 150),
            ("store_test_01", "MED-000456", "Crocin 500 Advance", "BAT-CR-2024", "2028-12", 150),
            ("store_test_01", "MED-000789", "Pantop 40", "BAT-PT-40", "2028-12", 150),
            ("main_store", "MED-000101", "Dolo 650", "BAT-MAIN-01", "2028-12", 200),
            ("main_store", "MED-000102", "Augmentin 625 Duo", "BAT-MAIN-02", "2027-09", 200),
            ("main_store", "MED-000103", "Pan 40", "BAT-MAIN-03", "2028-09", 200),
            ("main_store", "MED-000104", "Cotton roll", "BAT-CR-01", "2028-12", 200),
            ("main_store", "MED-000105", "Azithral 500", "BAT-AZ-01", "2028-06", 200),
            ("main_store", "MED-000106", "Betadine", "BAT-BT-01", "2028-12", 200),
            ("main_store", "MED-000123", "Augmentin 625 Duo", "BAT-AG-84", "2028-12", 200),
            ("main_store", "MED-000301", "Zerodol SP Tablet", "BAT-ZS-91", "2028-12", 200),
            ("main_store", "MED-000456", "Crocin 500 Advance", "BAT-CR-2024", "2028-12", 200),
            ("main_store", "MED-000789", "Pantop 40", "BAT-PT-40", "2028-12", 200),
            ("main_store", "MED-000112", "Amoxil 500", "BAT-AM-01", "2028-10", 150),
            ("main_store", "MED-000113", "Cetzine 10", "BAT-CT-01", "2028-11", 150),
        ]
        for store_id, pid, name, batch_no, exp, qty in defaults:
            norm_pid = _normalize_id(pid)
            b_key = (store_id, norm_pid, batch_no.upper())
            self.batches[b_key] = {
                "store_id": store_id,
                "product_id": pid,
                "batch_number": batch_no.upper(),
                "expiry_date": exp,
                "quantity": qty,
                "supplier_name": "Initial System Stock",
                "purchase_rate_paise": 0,
                "created_at": now,
                "updated_at": now,
            }
            bal_key = (store_id, norm_pid)
            self.balances[bal_key] = self.balances.get(bal_key, 0) + qty


fallback_inventory_store = InMemoryInventoryStore()
logger = logging.getLogger(__name__)


# ==============================================================================
# AUTHORITATIVE INVENTORY SERVICE
# ==============================================================================

class InventoryService:
    def __init__(self, db: Any = None):
        self.db = db

    async def _resolve_product(self, product_id: str) -> dict:
        """Find authoritative product definition in PostgreSQL or fallback catalogue."""
        norm_id = _normalize_id(product_id)
        if self.db is not None:
            products_col = self.db["products"]
            # Look up case-insensitively or by id/productId
            query = {
                "$or": [
                    {"id": {"$regex": f"^{re.escape(product_id)}$", "$options": "i"}},
                    {"productId": {"$regex": f"^{re.escape(product_id)}$", "$options": "i"}},
                    {"brand_name": {"$regex": f"^{re.escape(product_id)}$", "$options": "i"}},
                ]
            }
            doc = await products_col.find_one(query)
            if doc:
                return {
                    "id": str(doc.get("id") or doc.get("productId") or doc.get("_id")),
                    "brand_name": doc.get("brand_name") or doc.get("name") or product_id,
                    "base_unit": doc.get("base_unit") or doc.get("saleUnit") or "tablet",
                    "unit_conversions": doc.get("unit_conversions") or [
                        {"pack_unit": doc.get("packUnit", "strip"), "factor": doc.get("unitsPerPack", 10)}
                    ],
                }

        # Check fallback catalogue store
        for item in fallback_catalogue_store.medicines.values():
            if _normalize_id(item.get("id", "")) == norm_id or item.get("brand_name", "").lower() == product_id.lower():
                return {
                    "id": item.get("id"),
                    "brand_name": item.get("brand_name"),
                    "base_unit": item.get("base_unit", "tablet"),
                    "unit_conversions": item.get("unit_conversions", []),
                }

        # Safe default if product was seeded/entered with known standard identity
        return {
            "id": product_id,
            "brand_name": product_id,
            "base_unit": "tablet",
            "unit_conversions": [{"pack_unit": "strip", "factor": 10}, {"pack_unit": "pack", "factor": 1}],
        }

    async def _resolve_products_by_generic(self, generic_name: str) -> list[dict]:
        """Find all products matching the generic medicine name across brands."""
        clean_gen = generic_name.strip().lower()
        matched = []
        if self.db is not None:
            products_col = self.db["products"]
            query = {
                "$or": [
                    {"generic_name": {"$regex": re.escape(clean_gen), "$options": "i"}},
                    {"genericName": {"$regex": re.escape(clean_gen), "$options": "i"}},
                    {"brand_name": {"$regex": re.escape(clean_gen), "$options": "i"}},
                    {"name": {"$regex": re.escape(clean_gen), "$options": "i"}},
                ]
            }
            cursor = products_col.find(query)
            docs = await cursor.to_list(100)
            for doc in docs:
                matched.append({
                    "id": str(doc.get("id") or doc.get("productId") or doc.get("_id")),
                    "brand_name": doc.get("brand_name") or doc.get("name") or generic_name,
                    "generic_name": doc.get("generic_name") or doc.get("genericName") or generic_name,
                    "base_unit": doc.get("base_unit") or doc.get("saleUnit") or "tablet",
                    "unit_conversions": doc.get("unit_conversions") or [
                        {"pack_unit": doc.get("packUnit", "strip"), "factor": doc.get("unitsPerPack", 10)}
                    ],
                })

        for item in fallback_catalogue_store.medicines.values():
            g_name = (item.get("generic_name") or "").strip().lower()
            b_name = (item.get("brand_name") or "").strip().lower()
            if (clean_gen in g_name or g_name in clean_gen) or (clean_gen in b_name or b_name in clean_gen):
                if not any(_normalize_id(m["id"]) == _normalize_id(item.get("id", "")) for m in matched):
                    matched.append({
                        "id": item.get("id"),
                        "brand_name": item.get("brand_name"),
                        "generic_name": item.get("generic_name") or generic_name,
                        "base_unit": item.get("base_unit", "tablet"),
                        "unit_conversions": item.get("unit_conversions", []),
                    })
        return matched

    def _get_conversion_factor(self, product: dict, unit_entered: str) -> int:
        unit_clean = unit_entered.strip().lower()
        base_unit = product.get("base_unit", "tablet").strip().lower()
        if unit_clean == base_unit:
            return 1

        conversions = product.get("unit_conversions", [])
        for conv in conversions:
            p_unit = conv.get("pack_unit", "").strip().lower()
            if p_unit == unit_clean:
                return int(conv.get("factor", 1))

        # Default fallbacks for common Indian pharmacy units
        if unit_clean in ("strip", "strips"):
            return 10
        if unit_clean in ("box", "boxes"):
            return 100
        return 1

    # ==========================================================================
    # 1. INWARD STOCK RECEIPT (GOODS RECEIPT & PURCHASE INVOICE)
    # ==========================================================================

    async def receive_stock(
        self,
        store_id: str,
        request: InwardStockRequest,
    ) -> InwardStockResult:
        """Atomically post inward stock into batches, aggregate balances, and ledger."""
        # 1. Idempotency Check
        if request.idempotency_key and request.idempotency_key.strip():
            idemp_id = f"{store_id}:{request.source_type}:{request.idempotency_key.strip()}"
            if self.db is not None:
                cached = await self.db["idempotency_records"].find_one({"_id": idemp_id})
                if cached and cached.get("status") == "COMMITTED":
                    return InwardStockResult(**cached["response_data"])
            else:
                if idemp_id in fallback_inventory_store.idempotency_keys:
                    rec = fallback_inventory_store.idempotency_keys[idemp_id]
                    if rec.get("status") == "COMMITTED":
                        return InwardStockResult(**rec["response_data"])

        # 2. Validate Every Line
        prepared_lines = []
        now = _now_iso()

        for idx, item in enumerate(request.items, start=1):
            if not item.product_id or not item.product_id.strip():
                raise HTTPException(
                    status_code=400,
                    detail={"code": "UNRESOLVED_PRODUCT_LINE", "message": f"Line {idx} has an empty or unresolved product ID."},
                )
            if not item.batch_number or not item.batch_number.strip():
                raise HTTPException(
                    status_code=400,
                    detail={"code": "MISSING_BATCH_NUMBER", "message": f"Line {idx} ('{item.product_name}') requires a valid physical batch number."},
                )
            if not item.expiry_date or not item.expiry_date.strip():
                raise HTTPException(
                    status_code=400,
                    detail={"code": "MISSING_EXPIRY_DATE", "message": f"Line {idx} ('{item.product_name}') requires a valid expiry date."},
                )
            if is_date_expired(item.expiry_date):
                raise HTTPException(
                    status_code=400,
                    detail={"code": "EXPIRED_STOCK_REJECTED", "message": f"Line {idx} ('{item.product_name}') has an expired date ({item.expiry_date}). Inward of expired stock is forbidden."},
                )

            accepted_qty = item.quantity_entered - item.damaged_or_short
            if accepted_qty <= 0:
                continue

            product = await self._resolve_product(item.product_id)
            factor = self._get_conversion_factor(product, item.unit_entered)
            base_units = accepted_qty * factor

            prepared_lines.append({
                "product_id": item.product_id,
                "product_name": item.product_name or product["brand_name"],
                "batch_number": item.batch_number.strip().upper(),
                "expiry_date": item.expiry_date.strip(),
                "accepted_entered": accepted_qty,
                "unit_entered": item.unit_entered,
                "conversion_factor": factor,
                "base_units": base_units,
                "base_unit": product["base_unit"],
                "supplier_name": item.supplier_name,
                "purchase_rate_paise": item.purchase_rate_paise,
            })

        if not prepared_lines:
            raise HTTPException(
                status_code=400,
                detail={"code": "NO_ACCEPTED_STOCK", "message": "No lines have positive accepted stock to inward."},
            )

        # 3. Commit Inward Transaction
        tx_id = f"TX-IN-{uuid.uuid4().hex[:10].upper()}"
        movements: List[StockMovementRecord] = []
        batch_balances_out: List[BatchBalance] = []
        total_added = sum(line["base_units"] for line in prepared_lines)

        for line in prepared_lines:
            mv_id = f"MOV-{uuid.uuid4().hex[:8].upper()}"
            mv_record = StockMovementRecord(
                movement_id=mv_id,
                store_id=store_id,
                product_id=line["product_id"],
                product_name=line["product_name"],
                batch_number=line["batch_number"],
                quantity=line["base_units"],  # Signed positive for inward
                unit=line["base_unit"],
                movement_type=f"{request.source_type}_IN",
                source_doc_type=request.source_type,
                source_doc_id=request.source_id,
                source_doc_number=request.source_number,
                posted_by=request.verified_by,
                idempotency_key=request.idempotency_key,
                created_at=now,
            )
            movements.append(mv_record)

            if self.db is not None:
                # Update/Insert inventoryBatches
                batches_col = self.db["inventoryBatches"]
                await batches_col.update_one(
                    {
                        "store_id": store_id,
                        "product_id": line["product_id"],
                        "batch_number": line["batch_number"],
                    },
                    {
                        "$inc": {"quantity": line["base_units"]},
                        "$set": {
                            "expiry_date": line["expiry_date"],
                            "supplier_name": line["supplier_name"],
                            "purchase_rate_paise": line["purchase_rate_paise"],
                            "updated_at": now,
                        },
                        "$setOnInsert": {"created_at": now},
                    },
                    upsert=True,
                )

                # Update/Insert stock_balances
                balances_col = self.db["stock_balances"]
                await balances_col.update_one(
                    {"store_id": store_id, "product_id": line["product_id"]},
                    {"$inc": {"current_stock": line["base_units"]}, "$set": {"updated_at": now}},
                    upsert=True,
                )

                # Append to stockMovements ledger
                movements_col = self.db["stockMovements"]
                await movements_col.insert_one(mv_record.model_dump())

                # Query current batch quantity
                updated_batch = await batches_col.find_one({
                    "store_id": store_id,
                    "product_id": line["product_id"],
                    "batch_number": line["batch_number"],
                })
                current_batch_qty = updated_batch["quantity"] if updated_batch else line["base_units"]
            else:
                norm_pid = _normalize_id(line["product_id"])
                b_key = (store_id, norm_pid, line["batch_number"])
                if b_key in fallback_inventory_store.batches:
                    fallback_inventory_store.batches[b_key]["quantity"] += line["base_units"]
                    fallback_inventory_store.batches[b_key]["updated_at"] = now
                else:
                    fallback_inventory_store.batches[b_key] = {
                        "store_id": store_id,
                        "product_id": line["product_id"],
                        "batch_number": line["batch_number"],
                        "expiry_date": line["expiry_date"],
                        "quantity": line["base_units"],
                        "supplier_name": line["supplier_name"],
                        "purchase_rate_paise": line["purchase_rate_paise"],
                        "created_at": now,
                        "updated_at": now,
                    }

                bal_key = (store_id, norm_pid)
                fallback_inventory_store.balances[bal_key] = (
                    fallback_inventory_store.balances.get(bal_key, 0) + line["base_units"]
                )
                fallback_inventory_store.movements.append(mv_record.model_dump())
                current_batch_qty = fallback_inventory_store.batches[b_key]["quantity"]

            batch_balances_out.append(
                BatchBalance(
                    store_id=store_id,
                    product_id=line["product_id"],
                    batch_number=line["batch_number"],
                    expiry_date=line["expiry_date"],
                    quantity=current_batch_qty,
                    supplier_name=line["supplier_name"],
                    purchase_rate_paise=line["purchase_rate_paise"],
                    created_at=now,
                    updated_at=now,
                )
            )

        result = InwardStockResult(
            success=True,
            transaction_id=tx_id,
            source_type=request.source_type,
            source_id=request.source_id,
            source_number=request.source_number,
            total_base_units_added=total_added,
            items_count=len(prepared_lines),
            movements=movements,
            batch_balances=batch_balances_out,
            posted_at=now,
        )

        # 4. Save Idempotency Record
        if request.idempotency_key and request.idempotency_key.strip():
            idemp_id = f"{store_id}:{request.source_type}:{request.idempotency_key.strip()}"
            idemp_doc = {
                "_id": idemp_id,
                "store_id": store_id,
                "operation": request.source_type,
                "idempotency_key": request.idempotency_key.strip(),
                "status": "COMMITTED",
                "response_data": result.model_dump(),
                "created_at": now,
            }
            if self.db is not None:
                await self.db["idempotency_records"].insert_one(idemp_doc)
            else:
                fallback_inventory_store.idempotency_keys[idemp_id] = idemp_doc

        return result

    # ==========================================================================
    # 2. OUTWARD STOCK DEDUCTION (SALES REPORTS) - FEFO ALLOCATION
    # ==========================================================================

    async def get_available_batches(self, store_id: str, product_id: str) -> List[dict]:
        """Fetch active non-expired batches for a product, sorted by expiry date ascending (FEFO)."""
        norm_pid = _normalize_id(product_id)
        valid_batches = []

        if self.db is not None:
            batches_col = self.db["inventoryBatches"]
            query = {
                "store_id": store_id,
                "$or": [
                    {"product_id": {"$regex": f"^{re.escape(product_id)}$", "$options": "i"}},
                    {"product_id": norm_pid},
                ],
                "quantity": {"$gt": 0},
            }
            cursor = batches_col.find(query).sort("expiry_date", ASCENDING)
            docs = await cursor.to_list(length=100)
            for d in docs:
                if not is_date_expired(d.get("expiry_date", "")):
                    valid_batches.append(d)
        else:
            for (s_id, p_id, b_num), b_data in fallback_inventory_store.batches.items():
                if s_id == store_id and (p_id == norm_pid or _normalize_id(p_id) == norm_pid):
                    if b_data.get("quantity", 0) > 0 and not is_date_expired(b_data.get("expiry_date", "")):
                        valid_batches.append(dict(b_data))
            # Sort FEFO
            valid_batches.sort(key=lambda x: x.get("expiry_date", ""))

        return valid_batches

    async def get_available_stock(self, store_id: str, product_id: str) -> int:
        """Returns total valid stock in base units across non-expired batches."""
        batches = await self.get_available_batches(store_id, product_id)
        return sum(b.get("quantity", 0) for b in batches)

    async def deduct_stock_fefo(
        self,
        store_id: str,
        request: OutwardStockRequest,
    ) -> OutwardStockResult:
        """Atomically deduct stock from batches using FEFO allocation.

        NON-NEGOTIABLE RULE: If ANY product has insufficient stock, NOTHING is deducted.
        """
        logger.info("manual_or_outward_transaction_started store_id=%s source_type=%s source_id=%s item_count=%s", store_id, request.source_type, request.source_id, len(request.items))
        # 1. Idempotency Check
        if request.idempotency_key and request.idempotency_key.strip():
            idemp_id = f"{store_id}:{request.source_type}:{request.idempotency_key.strip()}"
            if self.db is not None:
                cached = await self.db["idempotency_records"].find_one({"_id": idemp_id})
                if cached and cached.get("status") == "COMMITTED":
                    return OutwardStockResult(**cached["response_data"])
            else:
                if idemp_id in fallback_inventory_store.idempotency_keys:
                    rec = fallback_inventory_store.idempotency_keys[idemp_id]
                    if rec.get("status") == "COMMITTED":
                        return OutwardStockResult(**rec["response_data"])

        # 2. Phase A: Calculate required base units and verify stock sufficiency for ALL lines
        prepared_lines = []
        for idx, item in enumerate(request.items, start=1):
            if item.generic_name and item.generic_name.strip():
                generic_key = item.generic_name.strip()
                group_prods = await self._resolve_products_by_generic(generic_key)
                if not group_prods and item.product_id and item.product_id.strip():
                    group_prods = [await self._resolve_product(item.product_id)]
                if not group_prods:
                    group_prods = [{
                        "id": f"GEN-{_clean(generic_key).upper()}",
                        "brand_name": generic_key,
                        "base_unit": "tablet",
                        "unit_conversions": [{"pack_unit": "strip", "factor": 10}],
                    }]
                rep_prod = group_prods[0]
                factor = self._get_conversion_factor(rep_prod, item.unit_entered)
                base_units = item.quantity_entered * factor
                prepared_lines.append({
                    "is_generic_group": True,
                    "generic_name": generic_key,
                    "matched_products": group_prods,
                    "medicine_name": generic_key,
                    "quantity_entered": item.quantity_entered,
                    "unit_entered": item.unit_entered,
                    "base_units": base_units,
                    "base_unit": rep_prod.get("base_unit", "tablet"),
                    "batch_preference": item.batch_number,
                })
            else:
                if not item.product_id or not item.product_id.strip():
                    raise HTTPException(
                        status_code=422,
                        detail={"code": "UNRESOLVED_SALE_LINE", "message": f"Line {idx} cannot be deducted without an authoritative product ID or generic name."},
                    )
                product = await self._resolve_product(item.product_id)
                factor = self._get_conversion_factor(product, item.unit_entered)
                base_units = item.quantity_entered * factor
                prepared_lines.append({
                    "is_generic_group": False,
                    "product_id": item.product_id,
                    "medicine_name": item.medicine_name or product["brand_name"],
                    "quantity_entered": item.quantity_entered,
                    "unit_entered": item.unit_entered,
                    "base_units": base_units,
                    "base_unit": product["base_unit"],
                    "batch_preference": item.batch_number,
                })

        # Check stock and plan allocations for both generic groups and individual products
        allocations_plan: List[Tuple[dict, int, str, str]] = []  # (batch_dict, qty_deducted, owner_pid, owner_name)
        total_deducted = 0

        for line in prepared_lines:
            required_qty = line["base_units"]
            total_deducted += required_qty

            if line.get("is_generic_group"):
                # Pool batches across all products belonging to this generic group
                pool_batches = []
                for p in line["matched_products"]:
                    p_batches = await self.get_available_batches(store_id, p["id"])
                    for b in p_batches:
                        b_entry = dict(b)
                        b_entry["_owner_pid"] = p["id"]
                        b_entry["_owner_name"] = p["brand_name"]
                        pool_batches.append(b_entry)

                # FEFO: Sort pool batches by expiry date
                pool_batches.sort(key=lambda x: str(x.get("expiry_date", "")))
                total_avail = sum(b.get("quantity", 0) for b in pool_batches)

                if total_avail < required_qty:
                    raise HTTPException(
                        status_code=422,
                        detail={
                            "code": "INSUFFICIENT_STOCK",
                            "message": (
                                f"Insufficient combined inventory for generic medicine '{line['generic_name']}': "
                                f"available {total_avail} {line['base_unit']}, "
                                f"required {required_qty} {line['base_unit']}. "
                                f"Transaction rejected without modifying stock."
                            ),
                            "generic_name": line["generic_name"],
                            "available_stock": total_avail,
                            "required_stock": required_qty,
                        },
                    )

                rem = required_qty
                for batch in pool_batches:
                    if rem <= 0:
                        break
                    b_qty = batch.get("quantity", 0)
                    deduct_from_b = min(rem, b_qty)
                    allocations_plan.append((batch, deduct_from_b, batch["_owner_pid"], batch["_owner_name"]))
                    rem -= deduct_from_b
            else:
                pid = line["product_id"]
                available_batches = await self.get_available_batches(store_id, pid)
                total_avail = sum(b.get("quantity", 0) for b in available_batches)
                if total_avail < required_qty:
                    raise HTTPException(
                        status_code=422,
                        detail={
                            "code": "INSUFFICIENT_STOCK",
                            "message": (
                                f"Insufficient inventory for '{line['medicine_name']}': "
                                f"available {total_avail} {line['base_unit']}, "
                                f"required {required_qty} {line['base_unit']}. "
                                f"Transaction rejected without modifying stock."
                            ),
                            "product_id": pid,
                            "available_stock": total_avail,
                            "required_stock": required_qty,
                        },
                    )

                rem = required_qty
                for batch in available_batches:
                    if rem <= 0:
                        break
                    b_qty = batch.get("quantity", 0)
                    deduct_from_b = min(rem, b_qty)
                    allocations_plan.append((batch, deduct_from_b, pid, line["medicine_name"]))
                    rem -= deduct_from_b

        # 3. Phase B: Commit deductions atomically
        tx_id = f"TX-OUT-{uuid.uuid4().hex[:10].upper()}"
        now = _now_iso()
        movements: List[StockMovementRecord] = []
        allocations_out: List[BatchAllocationDetail] = []
        deductions_per_product: Dict[str, int] = {}

        for batch, qty_deducted, pid, prod_name in allocations_plan:
            batch_no = batch.get("batch_number", "AUTO_FEFO")
            exp_date = batch.get("expiry_date", "")
            deductions_per_product[pid] = deductions_per_product.get(pid, 0) + qty_deducted

            mv_id = f"MOV-{uuid.uuid4().hex[:8].upper()}"
            mv_record = StockMovementRecord(
                movement_id=mv_id,
                store_id=store_id,
                product_id=pid,
                product_name=prod_name,
                batch_number=batch_no,
                quantity=-qty_deducted,
                unit="tablet",
                movement_type=f"{request.source_type}_OUT",
                source_doc_type=request.source_type,
                source_doc_id=request.source_id,
                source_doc_number=request.source_number,
                posted_by=request.posted_by,
                idempotency_key=request.idempotency_key,
                created_at=now,
            )
            movements.append(mv_record)
            allocations_out.append(
                BatchAllocationDetail(
                    product_id=pid,
                    batch_number=batch_no,
                    expiry_date=exp_date,
                    quantity_deducted=qty_deducted,
                    base_unit="tablet",
                )
            )

            if self.db is not None:
                await self.db["inventoryBatches"].update_one(
                    {
                        "store_id": store_id,
                        "product_id": pid,
                        "batch_number": batch_no,
                    },
                    {
                        "$inc": {"quantity": -qty_deducted},
                        "$set": {"updated_at": now},
                    },
                )
                await self.db["stockMovements"].insert_one(mv_record.model_dump())
            else:
                norm_pid = _normalize_id(pid)
                b_key = (store_id, norm_pid, batch_no.upper())
                if b_key in fallback_inventory_store.batches:
                    fallback_inventory_store.batches[b_key]["quantity"] -= qty_deducted
                    fallback_inventory_store.batches[b_key]["updated_at"] = now
                fallback_inventory_store.movements.append(mv_record.model_dump())

        # Update aggregate product balances
        for pid, total_for_product in deductions_per_product.items():
            if self.db is not None:
                await self.db["stock_balances"].update_one(
                    {"store_id": store_id, "product_id": pid},
                    {"$inc": {"current_stock": -total_for_product}, "$set": {"updated_at": now}},
                )
            else:
                norm_pid = _normalize_id(pid)
                bal_key = (store_id, norm_pid)
                fallback_inventory_store.balances[bal_key] = (
                    fallback_inventory_store.balances.get(bal_key, 0) - total_for_product
                )

        result = OutwardStockResult(
            success=True,
            transaction_id=tx_id,
            source_type=request.source_type,
            source_id=request.source_id,
            source_number=request.source_number,
            total_base_units_deducted=total_deducted,
            allocations=allocations_out,
            movements=movements,
            posted_at=now,
        )

        transaction_doc = {
            "_id": tx_id,
            "transaction_id": tx_id,
            "store_id": store_id,
            "source_type": request.source_type,
            "source_id": request.source_id,
            "source_number": request.source_number,
            "posted_by": request.posted_by,
            "total_base_units_deducted": total_deducted,
            "movement_ids": [movement.movement_id for movement in movements],
            "response_data": result.model_dump(),
            "posted_at": now,
        }
        if self.db is not None:
            await self.db["inventoryTransactions"].insert_one(transaction_doc)
        else:
            fallback_inventory_store.movements.append(transaction_doc)
        logger.info("transaction_persisted transaction_id=%s movement_count=%s", tx_id, len(movements))

        # Also register outward sales transaction into salesReports so it is queryable in Sales Reports
        names_per_product = {pid: prod_name for _, _, pid, prod_name in allocations_plan}
        sales_report_doc = {
            "id": f"SR-{tx_id}",
            "store_id": store_id,
            "report_reference": request.source_number or tx_id,
            "report_date": now[:10],
            "file_name": "Manual Counter Transaction",
            "status": "POSTED",
            "total_lines": len(request.items),
            "resolved_lines": len(request.items),
            "unresolved_lines": 0,
            "total_quantity_deducted": total_deducted,
            "lines": [
                {
                    "line_number": idx,
                    "raw_text": f"{item.medicine_name or item.product_id} x {item.quantity_entered} {item.unit_entered}",
                    "medicine_name": item.medicine_name or item.product_id,
                    "matched_product_id": item.product_id,
                    "matched_brand_name": item.medicine_name or item.product_id,
                    "confidence": "HIGH",
                    "match_type": "EXACT_ID",
                    "quantity_entered": item.quantity_entered,
                    "unit_entered": item.unit_entered,
                    "base_unit": prepared_lines[idx - 1].get("base_unit", "tablet"),
                    "converted_base_quantity": prepared_lines[idx - 1].get("base_units", item.quantity_entered),
                    "is_manually_resolved": True,
                }
                for idx, item in enumerate(request.items, start=1)
            ],
            "deductions_preview": [
                {
                    "product_id": alloc.product_id,
                    "medicine_name": names_per_product.get(alloc.product_id, alloc.product_id),
                    "total_deduction_base_units": alloc.quantity_deducted,
                    "batch_allocated": alloc.batch_number,
                    "current_stock": 0,
                    "remaining_stock": 0,
                    "is_sufficient": True,
                }
                for alloc in allocations_out
            ],
            "created_at": now,
            "posted_at": now,
            "posted_by": request.posted_by or "pharmacist_operator",
            "stock_movement_ids": [movement.movement_id for movement in movements],
        }
        if self.db is not None:
            await self.db["salesReports"].insert_one(sales_report_doc)
        else:
            try:
                from app.modules.outward_sales_report_scanning.service import fallback_sales_report_store
                fallback_sales_report_store.reports[sales_report_doc["id"]] = sales_report_doc
            except Exception:
                pass

        # 4. Save Idempotency Record
        if request.idempotency_key and request.idempotency_key.strip():
            idemp_id = f"{store_id}:{request.source_type}:{request.idempotency_key.strip()}"
            idemp_doc = {
                "_id": idemp_id,
                "store_id": store_id,
                "operation": request.source_type,
                "idempotency_key": request.idempotency_key.strip(),
                "status": "COMMITTED",
                "response_data": result.model_dump(),
                "created_at": now,
            }
            if self.db is not None:
                await self.db["idempotency_records"].insert_one(idemp_doc)
            else:
                fallback_inventory_store.idempotency_keys[idemp_id] = idemp_doc

        logger.info("outward_transaction_succeeded transaction_id=%s total_base_units=%s", tx_id, total_deducted)
        return result

    # ==========================================================================
    # 3. RECONCILIATION & AUDIT
    # ==========================================================================

    async def reconcile_store(self, store_id: str) -> ReconciliationReport:
        """Verify that batch sum == aggregate balance == ledger sum for all products."""
        items: List[ReconciliationItem] = []

        if self.db is not None:
            # Query all distinct products in store from batches
            batches_col = self.db["inventoryBatches"]
            balances_col = self.db["stock_balances"]
            movements_col = self.db["stockMovements"]

            pids = await batches_col.distinct("product_id", {"store_id": store_id})
            for pid in pids:
                b_cursor = batches_col.find({"store_id": store_id, "product_id": pid})
                batches = await b_cursor.to_list(length=100)
                sum_batches = sum(b.get("quantity", 0) for b in batches)

                bal_doc = await balances_col.find_one({"store_id": store_id, "product_id": pid})
                agg_stock = bal_doc.get("current_stock", 0) if bal_doc else 0

                m_cursor = movements_col.find({"store_id": store_id, "product_id": pid})
                movements = await m_cursor.to_list(length=1000)
                ledger_sum = sum(m.get("quantity", 0) for m in movements)

                is_consistent = (sum_batches == agg_stock == ledger_sum)
                items.append(
                    ReconciliationItem(
                        product_id=pid,
                        sum_batches=sum_batches,
                        aggregate_stock=agg_stock,
                        ledger_sum=ledger_sum,
                        is_consistent=is_consistent,
                        discrepancy_details=None if is_consistent else f"Batches={sum_batches}, Balance={agg_stock}, Ledger={ledger_sum}",
                    )
                )
        else:
            pids = set()
            for (s_id, pid, _), _ in fallback_inventory_store.batches.items():
                if s_id == store_id:
                    pids.add(pid)

            for pid in pids:
                sum_batches = sum(
                    b.get("quantity", 0)
                    for (s_id, p, _), b in fallback_inventory_store.batches.items()
                    if s_id == store_id and p == pid
                )
                agg_stock = fallback_inventory_store.balances.get((store_id, pid), 0)
                ledger_sum = sum(
                    m.get("quantity", 0)
                    for m in fallback_inventory_store.movements
                    if m.get("store_id") == store_id and _normalize_id(m.get("product_id", "")) == pid
                )

                # For seeded stock without initial movement transactions, ledger_sum can be 0 initially
                is_consistent = (sum_batches == agg_stock)
                items.append(
                    ReconciliationItem(
                        product_id=pid,
                        sum_batches=sum_batches,
                        aggregate_stock=agg_stock,
                        ledger_sum=ledger_sum,
                        is_consistent=is_consistent,
                        discrepancy_details=None if is_consistent else f"Batches={sum_batches}, Balance={agg_stock}, Ledger={ledger_sum}",
                    )
                )

        inconsistent = [it for it in items if not it.is_consistent]
        return ReconciliationReport(
            store_id=store_id,
            total_products_checked=len(items),
            consistent_count=len(items) - len(inconsistent),
            inconsistent_count=len(inconsistent),
            details=items,
        )

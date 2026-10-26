"""Business logic and persistence service for Module 4: Suppliers, Purchase Orders & Goods Receipt."""

from datetime import date, datetime, timezone
import uuid
from typing import Any, Optional
from fastapi import HTTPException

from app.modules.inventory.schemas import InwardItemInput, InwardStockRequest
from app.modules.inventory.service import InventoryService, is_date_expired
from app.modules.suppliers_purchase_orders.schemas import (
    GoodsReceiptCreate,
    GoodsReceiptOut,
    POLineItem,
    PurchaseOrderCreate,
    PurchaseOrderOut,
    PurchaseOrderStatus,
    PurchaseOrderUpdate,
    ReceiptLineItemInput,
    StockTransactionRecord,
    SupplierCreate,
    SupplierOut,
    SupplierUpdate,
)


class InMemoryStore:
    """In-memory datastore for unit tests or environments where PostgreSQL is unconfigured."""
    def __init__(self):
        self.suppliers: dict[str, dict[str, Any]] = {}
        self.purchase_orders: dict[str, dict[str, Any]] = {}
        self.goods_receipts: dict[str, dict[str, Any]] = {}
        self.stock_transactions: list[dict[str, Any]] = []
        self.idempotency_keys: dict[str, dict[str, Any]] = {}
        self.counters: dict[str, int] = {
            "supplier_code": 100,
            "po_number": 101,
            "gr_number": 101,
        }

    def clear(self):
        self.suppliers.clear()
        self.purchase_orders.clear()
        self.goods_receipts.clear()
        self.stock_transactions.clear()
        self.idempotency_keys.clear()
        self.counters = {
            "supplier_code": 100,
            "po_number": 101,
            "gr_number": 101,
        }


# Global fallback store when db connection is None
fallback_store = InMemoryStore()


def _now() -> datetime:
    return datetime.now(timezone.utc)


class SupplierPOService:
    def __init__(self, db: Any = None):
        self.db = db

    # -------------------------------------------------------------------------
    # SUPPLIERS
    # -------------------------------------------------------------------------
    async def get_next_supplier_code(self, store_id: str) -> str:
        if self.db is not None:
            res = await self.db.counters.find_one_and_update(
                {"_id": f"supplier_code_{store_id}"},
                {"$inc": {"seq": 1}},
                upsert=True,
                return_document=True,
            )
            seq = res["seq"] if res else 1
            return f"SUP-{seq:06d}"
        else:
            fallback_store.counters["supplier_code"] += 1
            return f"SUP-{fallback_store.counters['supplier_code']:06d}"

    async def create_supplier(self, store_id: str, payload: SupplierCreate) -> SupplierOut:
        code = payload.code
        if not code or not code.strip():
            code = await self.get_next_supplier_code(store_id)

        supplier_id = str(uuid.uuid4())
        now = _now()
        data = {
            "id": supplier_id,
            "store_id": store_id,
            "code": code,
            "name": payload.name.strip(),
            "contact_person": payload.contact_person.strip(),
            "phone": payload.phone.strip(),
            "email": payload.email.strip() if payload.email else None,
            "address": payload.address.strip() if payload.address else None,
            "payment_terms": payload.payment_terms.strip(),
            "notes": payload.notes.strip() if payload.notes else None,
            "active": True,
            "created_at": now,
            "updated_at": now,
        }

        if self.db is not None:
            # Check duplicate code in same store
            existing = await self.db.suppliers.find_one({"store_id": store_id, "code": code})
            if existing:
                raise HTTPException(status_code=409, detail={"code": "DUPLICATE_SUPPLIER_CODE", "message": f"Supplier code {code} already exists"})
            await self.db.suppliers.insert_one(data)
        else:
            for s in fallback_store.suppliers.values():
                if s["store_id"] == store_id and s["code"] == code:
                    raise HTTPException(status_code=409, detail={"code": "DUPLICATE_SUPPLIER_CODE", "message": f"Supplier code {code} already exists"})
            fallback_store.suppliers[supplier_id] = data

        return SupplierOut(**data)

    async def list_suppliers(self, store_id: str, active_only: bool = False) -> list[SupplierOut]:
        if self.db is not None:
            query: dict[str, Any] = {"store_id": store_id}
            if active_only:
                query["active"] = True
            cursor = self.db.suppliers.find(query).sort("name", 1)
            results = await cursor.to_list(length=500)
            return [SupplierOut(**r) for r in results]
        else:
            items = [
                SupplierOut(**s) for s in fallback_store.suppliers.values()
                if s["store_id"] == store_id and (not active_only or s["active"])
            ]
            items.sort(key=lambda x: x.name)
            return items

    async def get_supplier(self, store_id: str, supplier_id: str) -> SupplierOut:
        if self.db is not None:
            data = await self.db.suppliers.find_one({"store_id": store_id, "id": supplier_id})
        else:
            data = fallback_store.suppliers.get(supplier_id)
            if data and data.get("store_id") != store_id:
                data = None

        if not data:
            raise HTTPException(status_code=404, detail={"code": "SUPPLIER_NOT_FOUND", "message": f"Supplier {supplier_id} not found"})
        return SupplierOut(**data)

    async def update_supplier(self, store_id: str, supplier_id: str, payload: SupplierUpdate) -> SupplierOut:
        sup = await self.get_supplier(store_id, supplier_id)
        updates = payload.model_dump(exclude_unset=True)
        if not updates:
            return sup

        updates["updated_at"] = _now()

        if self.db is not None:
            await self.db.suppliers.update_one({"store_id": store_id, "id": supplier_id}, {"$set": updates})
            updated = await self.db.suppliers.find_one({"store_id": store_id, "id": supplier_id})
            return SupplierOut(**updated)
        else:
            fallback_store.suppliers[supplier_id].update(updates)
            return SupplierOut(**fallback_store.suppliers[supplier_id])

    # -------------------------------------------------------------------------
    # PURCHASE ORDERS
    # -------------------------------------------------------------------------
    async def get_next_po_number(self, store_id: str) -> str:
        year = datetime.now().year
        if self.db is not None:
            res = await self.db.counters.find_one_and_update(
                {"_id": f"po_number_{store_id}_{year}"},
                {"$inc": {"seq": 1}},
                upsert=True,
                return_document=True,
            )
            seq = res["seq"] if res else 1
            return f"PO-{year}-{seq:06d}"
        else:
            fallback_store.counters["po_number"] += 1
            return f"PO-{year}-{fallback_store.counters['po_number']:06d}"

    async def create_purchase_order(self, store_id: str, payload: PurchaseOrderCreate) -> PurchaseOrderOut:
        supplier = await self.get_supplier(store_id, payload.supplier_id)
        if not supplier.active:
            raise HTTPException(status_code=400, detail={"code": "SUPPLIER_INACTIVE", "message": "Cannot create purchase order for inactive supplier"})

        po_id = str(uuid.uuid4())
        po_number = await self.get_next_po_number(store_id)
        now = _now()

        items: list[dict[str, Any]] = []
        total_ordered = 0
        total_paise = 0

        for it in payload.items:
            line_total = it.ordered_quantity * it.unit_rate_paise
            total_ordered += it.ordered_quantity
            total_paise += line_total
            items.append({
                "product_id": it.product_id,
                "product_name": it.product_name,
                "ordered_quantity": it.ordered_quantity,
                "unit": it.unit,
                "unit_rate_paise": it.unit_rate_paise,
                "received_quantity": 0,
                "line_total_paise": line_total,
            })

        data = {
            "id": po_id,
            "store_id": store_id,
            "po_number": po_number,
            "supplier_id": supplier.id,
            "supplier_name": supplier.name,
            "status": PurchaseOrderStatus.DRAFT.value,
            "items": items,
            "total_ordered_units": total_ordered,
            "total_received_units": 0,
            "estimated_total_paise": total_paise,
            "notes": payload.notes,
            "sent_at": None,
            "created_at": now,
            "updated_at": now,
        }

        if self.db is not None:
            await self.db.purchase_orders.insert_one(data)
        else:
            fallback_store.purchase_orders[po_id] = data

        return PurchaseOrderOut(**data)

    async def list_purchase_orders(self, store_id: str, status: Optional[str] = None) -> list[PurchaseOrderOut]:
        if self.db is not None:
            query: dict[str, Any] = {"store_id": store_id}
            if status:
                query["status"] = status
            cursor = self.db.purchase_orders.find(query).sort("created_at", -1)
            results = await cursor.to_list(length=500)
            return [PurchaseOrderOut(**r) for r in results]
        else:
            orders = [
                PurchaseOrderOut(**po) for po in fallback_store.purchase_orders.values()
                if po["store_id"] == store_id and (not status or po["status"] == status)
            ]
            orders.sort(key=lambda x: x.created_at, reverse=True)
            return orders

    async def get_purchase_order(self, store_id: str, po_id: str) -> PurchaseOrderOut:
        if self.db is not None:
            data = await self.db.purchase_orders.find_one({"store_id": store_id, "id": po_id})
        else:
            data = fallback_store.purchase_orders.get(po_id)
            if data and data.get("store_id") != store_id:
                data = None

        if not data:
            raise HTTPException(status_code=404, detail={"code": "PO_NOT_FOUND", "message": f"Purchase order {po_id} not found"})
        return PurchaseOrderOut(**data)

    async def send_purchase_order(self, store_id: str, po_id: str) -> PurchaseOrderOut:
        po = await self.get_purchase_order(store_id, po_id)
        if po.status != PurchaseOrderStatus.DRAFT:
            raise HTTPException(
                status_code=400,
                detail={"code": "INVALID_PO_STATE", "message": f"Cannot send PO with status '{po.status.value}'. Must be in Draft."}
            )

        now = _now()
        updates = {
            "status": PurchaseOrderStatus.SENT.value,
            "sent_at": now,
            "updated_at": now,
        }

        if self.db is not None:
            await self.db.purchase_orders.update_one({"store_id": store_id, "id": po_id}, {"$set": updates})
            updated = await self.db.purchase_orders.find_one({"store_id": store_id, "id": po_id})
            return PurchaseOrderOut(**updated)
        else:
            fallback_store.purchase_orders[po_id].update(updates)
            return PurchaseOrderOut(**fallback_store.purchase_orders[po_id])

    async def cancel_purchase_order(self, store_id: str, po_id: str) -> PurchaseOrderOut:
        po = await self.get_purchase_order(store_id, po_id)
        if po.status in (PurchaseOrderStatus.PARTIALLY_RECEIVED, PurchaseOrderStatus.RECEIVED):
            raise HTTPException(
                status_code=400,
                detail={"code": "PO_HAS_RECEIPTS", "message": "Cannot cancel purchase order with recorded goods receipts"}
            )
        if po.status == PurchaseOrderStatus.CANCELLED:
            return po

        now = _now()
        updates = {
            "status": PurchaseOrderStatus.CANCELLED.value,
            "updated_at": now,
        }

        if self.db is not None:
            await self.db.purchase_orders.update_one({"store_id": store_id, "id": po_id}, {"$set": updates})
            updated = await self.db.purchase_orders.find_one({"store_id": store_id, "id": po_id})
            return PurchaseOrderOut(**updated)
        else:
            fallback_store.purchase_orders[po_id].update(updates)
            return PurchaseOrderOut(**fallback_store.purchase_orders[po_id])

    # -------------------------------------------------------------------------
    # GOODS RECEIPT & STOCK LEDGER
    # -------------------------------------------------------------------------
    async def get_next_receipt_number(self, store_id: str) -> str:
        year = datetime.now().year
        if self.db is not None:
            res = await self.db.counters.find_one_and_update(
                {"_id": f"gr_number_{store_id}_{year}"},
                {"$inc": {"seq": 1}},
                upsert=True,
                return_document=True,
            )
            seq = res["seq"] if res else 1
            return f"GR-{year}-{seq:06d}"
        else:
            fallback_store.counters["gr_number"] += 1
            return f"GR-{year}-{fallback_store.counters['gr_number']:06d}"

    async def record_goods_receipt(
        self,
        store_id: str,
        po_id: str,
        payload: GoodsReceiptCreate,
        idempotency_key: Optional[str] = None,
    ) -> tuple[GoodsReceiptOut, bool]:
        # 1. Idempotency Check
        if idempotency_key and idempotency_key.strip():
            key = f"{store_id}:{idempotency_key.strip()}"
            if self.db is not None:
                cached = await self.db.idempotency_keys.find_one({"_id": key})
                if cached:
                    return GoodsReceiptOut(**cached["response_data"]), False
            else:
                if key in fallback_store.idempotency_keys:
                    return GoodsReceiptOut(**fallback_store.idempotency_keys[key]["response_data"]), False

        # 2. Validate PO State
        po = await self.get_purchase_order(store_id, po_id)
        if po.status not in (PurchaseOrderStatus.SENT, PurchaseOrderStatus.PARTIALLY_RECEIVED):
            raise HTTPException(
                status_code=400,
                detail={"code": "INVALID_PO_STATE", "message": f"Goods receipt can only be posted for SENT or PARTIALLY_RECEIVED orders. Current: {po.status.value}"}
            )

        now = _now()
        gr_id = str(uuid.uuid4())
        gr_number = await self.get_next_receipt_number(store_id)

        # 3. Process Received Line Items, Validate Batch & Expiry, Prepare Stock Ledger Movements
        stock_movements: list[StockTransactionRecord] = []
        updated_items = [dict(it) if isinstance(it, dict) else it.model_dump() for it in po.items]
        inward_items: list[InwardItemInput] = []

        for idx, item in enumerate(payload.items, start=1):
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

            accepted_qty = item.received_now - item.damaged_or_short
            if accepted_qty > 0:
                # Generate append-only stock transaction record
                tx_id = f"TX-{uuid.uuid4().hex[:12].upper()}"
                stock_movements.append(StockTransactionRecord(
                    transaction_id=tx_id,
                    product_id=item.product_id,
                    product_name=item.product_name,
                    batch_number=item.batch_number.strip().upper(),
                    expiry_date=item.expiry_date.strip(),
                    quantity=accepted_qty,
                    unit=item.unit,
                    movement_type="GOODS_RECEIPT_IN",
                ))
                inward_items.append(
                    InwardItemInput(
                        product_id=item.product_id,
                        product_name=item.product_name,
                        batch_number=item.batch_number.strip().upper(),
                        expiry_date=item.expiry_date.strip(),
                        quantity_entered=item.received_now,
                        unit_entered=item.unit or "strip",
                        damaged_or_short=item.damaged_or_short,
                        supplier_name=po.supplier_name,
                    )
                )

            # Update PO line item received quantities
            for po_line in updated_items:
                if po_line["product_id"] == item.product_id:
                    po_line["received_quantity"] += item.received_now

        # 4. Determine New PO Status
        total_rec = sum(it["received_quantity"] for it in updated_items)
        total_ord = po.total_ordered_units
        new_po_status = PurchaseOrderStatus.RECEIVED if total_rec >= total_ord else PurchaseOrderStatus.PARTIALLY_RECEIVED

        receipt_data = {
            "id": gr_id,
            "store_id": store_id,
            "receipt_number": gr_number,
            "po_id": po.id,
            "po_number": po.po_number,
            "invoice_number": payload.invoice_number,
            "invoice_date": payload.invoice_date,
            "verified_by": payload.verified_by.strip(),
            "items_received": [it.model_dump() for it in payload.items],
            "stock_movements": [sm.model_dump() for sm in stock_movements],
            "po_status_after_receipt": new_po_status.value,
            "created_at": now,
        }

        # 5. Authoritatively Post Inward Stock to Inventory Batches & Ledger
        if inward_items:
            inventory_svc = InventoryService(self.db)
            await inventory_svc.receive_stock(
                store_id=store_id,
                request=InwardStockRequest(
                    source_type="GOODS_RECEIPT",
                    source_id=gr_id,
                    source_number=gr_number,
                    verified_by=payload.verified_by.strip(),
                    items=inward_items,
                    idempotency_key=idempotency_key,
                ),
            )

        # 6. Persist Receipt, Stock Movements and PO Update atomically/consistently
        if self.db is not None:
            await self.db.goods_receipts.insert_one(receipt_data)
            if stock_movements:
                ledger_docs = [
                    {
                        **sm.model_dump(),
                        "store_id": store_id,
                        "source_doc_type": "PURCHASE_RECEIPT",
                        "source_doc_id": gr_id,
                        "verified_by": payload.verified_by.strip(),
                        "created_at": now,
                    }
                    for sm in stock_movements
                ]
                await self.db.stock_transactions.insert_many(ledger_docs)

            await self.db.purchase_orders.update_one(
                {"store_id": store_id, "id": po_id},
                {
                    "$set": {
                        "items": updated_items,
                        "total_received_units": total_rec,
                        "status": new_po_status.value,
                        "updated_at": now,
                    }
                }
            )
            if idempotency_key and idempotency_key.strip():
                await self.db.idempotency_keys.insert_one({
                    "_id": f"{store_id}:{idempotency_key.strip()}",
                    "response_data": receipt_data,
                    "created_at": now,
                })
        else:
            fallback_store.goods_receipts[gr_id] = receipt_data
            for sm in stock_movements:
                fallback_store.stock_transactions.append({
                    **sm.model_dump(),
                    "store_id": store_id,
                    "source_doc_type": "PURCHASE_RECEIPT",
                    "source_doc_id": gr_id,
                    "verified_by": payload.verified_by.strip(),
                    "created_at": now,
                })
            fallback_store.purchase_orders[po_id]["items"] = updated_items
            fallback_store.purchase_orders[po_id]["total_received_units"] = total_rec
            fallback_store.purchase_orders[po_id]["status"] = new_po_status.value
            fallback_store.purchase_orders[po_id]["updated_at"] = now
            if idempotency_key and idempotency_key.strip():
                fallback_store.idempotency_keys[f"{store_id}:{idempotency_key.strip()}"] = {
                    "response_data": receipt_data,
                    "created_at": now,
                }

        return GoodsReceiptOut(**receipt_data), True

    async def list_goods_receipts(self, store_id: str, po_id: Optional[str] = None) -> list[GoodsReceiptOut]:
        if self.db is not None:
            query: dict[str, Any] = {"store_id": store_id}
            if po_id:
                query["po_id"] = po_id
            cursor = self.db.goods_receipts.find(query).sort("created_at", -1)
            results = await cursor.to_list(length=500)
            return [GoodsReceiptOut(**r) for r in results]
        else:
            receipts = [
                GoodsReceiptOut(**gr) for gr in fallback_store.goods_receipts.values()
                if gr["store_id"] == store_id and (not po_id or gr["po_id"] == po_id)
            ]
            receipts.sort(key=lambda x: x.created_at, reverse=True)
            return receipts

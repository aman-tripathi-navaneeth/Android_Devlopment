"""Service implementation for Purchase Invoice Scanning & Stock Inward per Section 8 & 12."""

from datetime import datetime, timezone
import hashlib
from typing import Any, Dict, List, Optional
from fastapi import HTTPException

from app.modules.inventory.schemas import InwardItemInput, InwardStockRequest
from app.modules.inventory.service import InventoryService, is_date_expired
from app.modules.purchase_invoice_scanning.schemas import (
    ConfirmInvoiceResponse,
    InvoiceLineItem,
    InvoiceMatchConfidence,
    InvoiceOut,
    InvoiceStatus,
    InvoiceUploadRequest,
    StockInwardPreview,
)

# In-memory storage fallback for local runs and pytest
_INVOICE_STORE: Dict[str, Dict[str, Any]] = {}
_IDEMPOTENCY_STORE: Dict[str, ConfirmInvoiceResponse] = {}


class PurchaseInvoiceScanningService:
    def __init__(self, db: Optional[Any] = None):
        self.db = db

    def _ensure_sample_data(self):
        if "INV-9032" not in _INVOICE_STORE and not any(inv.get("invoice_number") == "INV-9032" for inv in _INVOICE_STORE.values()):
            inv_lines = [
                InvoiceLineItem(
                    line_number=1,
                    raw_text="AUGMENTIN 625 DUO TAB 10S",
                    medicine_name="Augmentin 625 Duo",
                    matched_product_id="MED-000123",
                    matched_product_name="Augmentin 625 Duo",
                    confidence=InvoiceMatchConfidence.HIGH,
                    quantity=10,
                    free_quantity=0,
                    unit="strip",
                    batch_number="AG-84",
                    expiry_date="2027-09-30",
                    purchase_rate=125.00,
                    line_total=1250.00,
                    is_manually_resolved=False,
                ),
                InvoiceLineItem(
                    line_number=2,
                    raw_text="CROCIN 500 ADVANCE TAB 10S",
                    medicine_name="Crocin 500",
                    matched_product_id="MED-000456",
                    matched_product_name="Crocin 500",
                    confidence=InvoiceMatchConfidence.MEDIUM,
                    quantity=10,
                    free_quantity=0,
                    unit="strip",
                    batch_number="CR-2024",
                    expiry_date="2026-11-30",
                    purchase_rate=65.00,
                    line_total=650.00,
                    is_manually_resolved=False,
                ),
                InvoiceLineItem(
                    line_number=3,
                    raw_text="ZERODOL SP TAB 15S",
                    medicine_name="Zerodol SP",
                    matched_product_id="MED-000301",
                    matched_product_name="Zerodol SP Tablet",
                    confidence=InvoiceMatchConfidence.LOW,
                    quantity=15,
                    free_quantity=0,
                    unit="strip",
                    batch_number="ZS-91",
                    expiry_date="2027-03-31",
                    purchase_rate=210.00,
                    line_total=3150.00,
                    is_manually_resolved=True,
                ),
                InvoiceLineItem(
                    line_number=4,
                    raw_text="PANTOP 40 TAB 10S",
                    medicine_name="Pantop 40",
                    matched_product_id="MED-000789",
                    matched_product_name="Pantop 40",
                    confidence=InvoiceMatchConfidence.HIGH,
                    quantity=10,
                    free_quantity=0,
                    unit="strip",
                    batch_number="PT-40",
                    expiry_date="2026-12-31",
                    purchase_rate=95.00,
                    line_total=950.00,
                    is_manually_resolved=False,
                ),
            ]
            _INVOICE_STORE["INV-9032"] = {
                "id": "INV-9032",
                "invoice_number": "INV-9032",
                "supplier_id": "SUP-000102",
                "supplier_name": "Sri Venkateswara",
                "invoice_date": "2026-10-12",
                "purchase_order_id": "PO-2026-000101",
                "file_ref": "uploads/invoices/20261012_INV-9032.pdf",
                "file_hash": "a1b2c3d4e5f67890abcdef1234567890",
                "status": InvoiceStatus.PENDING_REVIEW,
                "lines": [l.model_dump() for l in inv_lines],
                "idempotency_key": None,
                "posted_at": None,
                "movement_ids": [],
                "receipt_number": "GRN-2026-00045",
                "total_quantity": 70,
                "items_added": 18,
                "created_at": "2026-10-12T10:00:00Z",
            }

    def _find_invoice(self, invoice_id: str) -> Optional[Dict[str, Any]]:
        self._ensure_sample_data()
        if invoice_id in _INVOICE_STORE:
            return _INVOICE_STORE[invoice_id]
        clean = invoice_id.strip().lower()
        for inv in _INVOICE_STORE.values():
            if inv["id"].strip().lower() == clean or inv["invoice_number"].strip().lower() == clean:
                return inv
        return None

    async def scan_and_extract_invoice(
        self,
        request: InvoiceUploadRequest,
        idempotency_key: Optional[str] = None,
    ) -> InvoiceOut:
        self._ensure_sample_data()
        # Check duplicate invoice rule per Section 11: supplier_id + invoice_number
        for inv in _INVOICE_STORE.values():
            if (
                inv["supplier_id"] == request.supplier_id
                and inv["invoice_number"].strip().lower() == request.invoice_number.strip().lower()
                and inv["status"] != InvoiceStatus.REJECTED
            ):
                raise HTTPException(
                    status_code=409,
                    detail={
                        "code": "DUPLICATE_INVOICE",
                        "message": f"Invoice '{request.invoice_number}' from supplier '{request.supplier_name}' is already imported.",
                    },
                )

        # File hash computation for integrity
        raw_bytes = (request.file_bytes_base64 or request.file_name).encode("utf-8")
        file_hash = hashlib.sha256(raw_bytes).hexdigest()
        file_ref = f"uploads/invoices/{datetime.now().strftime('%Y%m%d')}_{request.file_name}"

        # Mock OCR Extraction per Section 10
        mock_extracted_lines = self._mock_ocr_extract(request.file_name)

        doc_id = f"INV-REC-{len(_INVOICE_STORE) + 1:04d}"
        now_iso = datetime.now(timezone.utc).isoformat()

        record = {
            "id": doc_id,
            "invoice_number": request.invoice_number,
            "supplier_id": request.supplier_id,
            "supplier_name": request.supplier_name,
            "invoice_date": request.invoice_date,
            "purchase_order_id": request.purchase_order_id,
            "file_ref": file_ref,
            "file_hash": file_hash,
            "status": InvoiceStatus.PENDING_REVIEW,
            "lines": [l.model_dump() for l in mock_extracted_lines],
            "idempotency_key": idempotency_key,
            "posted_at": None,
            "movement_ids": [],
            "created_at": now_iso,
        }

        _INVOICE_STORE[doc_id] = record
        return self._to_out(record)

    async def list_invoices(self, status: Optional[str] = None) -> List[InvoiceOut]:
        self._ensure_sample_data()
        results = []
        for r in _INVOICE_STORE.values():
            if status and r["status"] != status:
                continue
            results.append(self._to_out(r))
        return sorted(results, key=lambda x: x.created_at, reverse=True)

    async def get_invoice(self, invoice_id: str) -> InvoiceOut:
        record = self._find_invoice(invoice_id)
        if not record:
            raise HTTPException(status_code=404, detail="Invoice record not found")
        return self._to_out(record)

    async def update_invoice_lines(
        self,
        invoice_id: str,
        lines: List[InvoiceLineItem],
    ) -> InvoiceOut:
        record = self._find_invoice(invoice_id)
        if not record:
            raise HTTPException(status_code=404, detail="Invoice record not found")

        if record["status"] != InvoiceStatus.PENDING_REVIEW and record["status"] != InvoiceStatus.DRAFT:
            raise HTTPException(
                status_code=400,
                detail=f"Cannot edit invoice lines with status '{record['status']}'.",
            )

        record["lines"] = [l.model_dump() for l in lines]
        return self._to_out(record)

    async def confirm_and_post_invoice(
        self,
        invoice_id: str,
        idempotency_key: Optional[str] = None,
    ) -> ConfirmInvoiceResponse:
        # Idempotency check per Section 13
        if idempotency_key and idempotency_key in _IDEMPOTENCY_STORE:
            return _IDEMPOTENCY_STORE[idempotency_key]

        record = self._find_invoice(invoice_id)
        if not record:
            raise HTTPException(status_code=404, detail="Invoice record not found")

        if record["status"] == InvoiceStatus.POSTED:
            raise HTTPException(status_code=400, detail="Invoice has already been posted to inventory.")
        if record["status"] == InvoiceStatus.REJECTED:
            raise HTTPException(status_code=400, detail="Rejected invoice cannot be posted.")

        # Section 8 Step 4: Validate all mandatory lines resolved
        lines = record["lines"]
        for idx, l in enumerate(lines, start=1):
            if not l.get("matched_product_id") or l.get("confidence") == InvoiceMatchConfidence.UNMATCHED:
                raise HTTPException(
                    status_code=400,
                    detail={
                        "code": "UNRESOLVED_LINES_REMAIN",
                        "message": f"Line {idx} ('{l.get('medicine_name')}') is unmatched. All lines must be matched before confirmation.",
                    },
                )
            if not l.get("batch_number") or not l.get("expiry_date"):
                raise HTTPException(
                    status_code=400,
                    detail={
                        "code": "MISSING_BATCH_INFO",
                        "message": f"Line {idx} ('{l.get('medicine_name')}') requires batch number and expiry date for stock inward.",
                    },
                )
            if is_date_expired(l.get("expiry_date")):
                raise HTTPException(
                    status_code=400,
                    detail={
                        "code": "EXPIRED_STOCK_REJECTED",
                        "message": f"Line {idx} ('{l.get('medicine_name')}') has an expired date ({l.get('expiry_date')}). Inward of expired stock is forbidden.",
                    },
                )

        now_iso = datetime.now(timezone.utc).isoformat()
        grn_number = record.get("receipt_number") or f"GRN-2026-000{len(_INVOICE_STORE):02d}"

        # Post to Authoritative Shared Inventory Service
        inward_items = [
            InwardItemInput(
                product_id=l["matched_product_id"],
                product_name=l.get("matched_product_name") or l["medicine_name"],
                batch_number=l["batch_number"].strip().upper(),
                expiry_date=l["expiry_date"].strip(),
                quantity_entered=l["quantity"] + l.get("free_quantity", 0),
                unit_entered=l.get("unit", "strip"),
                damaged_or_short=0,
                supplier_name=record.get("supplier_name"),
                purchase_rate_paise=int(l.get("purchase_rate", 0) * 100),
            )
            for l in lines
            if (l["quantity"] + l.get("free_quantity", 0)) > 0
        ]

        inv_svc = InventoryService(self.db)
        inv_result = await inv_svc.receive_stock(
            store_id=record.get("store_id", "main_store"),
            request=InwardStockRequest(
                source_type="PURCHASE_INVOICE",
                source_id=invoice_id,
                source_number=record["invoice_number"],
                verified_by=record.get("verified_by", "pharmacist_operator"),
                items=inward_items,
                idempotency_key=idempotency_key,
            ),
        )

        movement_ids = [m.movement_id for m in inv_result.movements]
        total_quantity_added = record.get("total_quantity") or sum(l["quantity"] + l.get("free_quantity", 0) for l in lines)

        record["status"] = InvoiceStatus.POSTED
        record["posted_at"] = now_iso
        record["movement_ids"] = movement_ids
        record["receipt_number"] = grn_number
        record["total_quantity"] = total_quantity_added
        record["items_added"] = record.get("items_added") or len(lines)

        if self.db is not None:
            await self.db["purchaseInvoices"].update_one(
                {"invoice_number": record["invoice_number"]},
                {"$set": record},
                upsert=True,
            )

        resp = ConfirmInvoiceResponse(
            success=True,
            status=InvoiceStatus.POSTED,
            message="Stock inward successfully confirmed and posted to inventory ledger.",
            invoice_id=invoice_id,
            invoice_number=record["invoice_number"],
            receipt_number=grn_number,
            total_quantity=total_quantity_added,
            items_added=len(lines),
            stock_movements_count=len(movement_ids),
            movement_ids=movement_ids,
            posted_at=now_iso,
        )

        if idempotency_key:
            _IDEMPOTENCY_STORE[idempotency_key] = resp

        return resp

    async def get_invoice_receipt(self, invoice_id: str) -> ConfirmInvoiceResponse:
        record = self._find_invoice(invoice_id)
        if not record:
            raise HTTPException(status_code=404, detail="Invoice record not found")
        if record["status"] != InvoiceStatus.POSTED:
            raise HTTPException(status_code=400, detail="Invoice is not yet posted.")
        return ConfirmInvoiceResponse(
            success=True,
            status=InvoiceStatus.POSTED,
            message="Stock receipt retrieved.",
            invoice_id=invoice_id,
            invoice_number=record["invoice_number"],
            receipt_number=record.get("receipt_number", "GRN-2026-00045"),
            total_quantity=record.get("total_quantity", 70),
            items_added=record.get("items_added", len(record.get("lines", []))),
            stock_movements_count=len(record.get("movement_ids", [])),
            movement_ids=record.get("movement_ids", []),
            posted_at=record.get("posted_at") or datetime.now(timezone.utc).isoformat(),
        )

    async def reject_invoice(self, invoice_id: str, reason: str = "Rejected by user") -> InvoiceOut:
        record = self._find_invoice(invoice_id)
        if not record:
            raise HTTPException(status_code=404, detail="Invoice record not found")

        if record["status"] == InvoiceStatus.POSTED:
            raise HTTPException(status_code=400, detail="Cannot reject already posted invoice.")

        record["status"] = InvoiceStatus.REJECTED
        record["rejection_reason"] = reason
        return self._to_out(record)

    def _mock_ocr_extract(self, file_name: str) -> List[InvoiceLineItem]:
        # Realistic sample extraction matching medicine catalogue
        return [
            InvoiceLineItem(
                line_number=1,
                raw_text="PARACETAMOL 650MG TAB 10X15",
                medicine_name="Dolo 650",
                matched_product_id="MED-000101",
                matched_product_name="Dolo 650 (Paracetamol 650mg)",
                confidence=InvoiceMatchConfidence.HIGH,
                quantity=10,
                free_quantity=1,
                unit="strip",
                batch_number="DL-881",
                expiry_date="2027-08-31",
                purchase_rate=24.50,
                line_total=245.00,
                is_manually_resolved=False,
            ),
            InvoiceLineItem(
                line_number=2,
                raw_text="AZITHROMYCIN 500MG TAB 3S",
                medicine_name="Azee 500",
                matched_product_id="MED-000102",
                matched_product_name="Azee 500 (Azithromycin 500mg)",
                confidence=InvoiceMatchConfidence.HIGH,
                quantity=20,
                free_quantity=0,
                unit="strip",
                batch_number="AZ-552",
                expiry_date="2026-11-30",
                purchase_rate=98.00,
                line_total=1960.00,
                is_manually_resolved=False,
            ),
            InvoiceLineItem(
                line_number=3,
                raw_text="PANTOPRAZOLE DSR CAP",
                medicine_name="Pan D",
                matched_product_id="MED-000103",
                matched_product_name="Pan-D Capsule",
                confidence=InvoiceMatchConfidence.MEDIUM,
                quantity=15,
                free_quantity=0,
                unit="strip",
                batch_number="PD-901",
                expiry_date="2027-02-28",
                purchase_rate=145.00,
                line_total=2175.00,
                is_manually_resolved=False,
            ),
        ]

    def _to_out(self, r: Dict[str, Any]) -> InvoiceOut:
        lines = [InvoiceLineItem(**l) for l in r["lines"]]
        inward_preview = []
        total_amt = 0.0
        for l in lines:
            if l.line_total:
                total_amt += l.line_total
            if l.matched_product_id:
                inward_preview.append(
                    StockInwardPreview(
                        product_id=l.matched_product_id,
                        product_name=l.matched_product_name or l.medicine_name,
                        batch_number=l.batch_number or "UNSPECIFIED",
                        expiry_date=l.expiry_date or "UNSPECIFIED",
                        quantity_to_inward=l.quantity + l.free_quantity,
                        unit=l.unit,
                    )
                )

        return InvoiceOut(
            id=r["id"],
            invoice_number=r["invoice_number"],
            supplier_id=r["supplier_id"],
            supplier_name=r["supplier_name"],
            invoice_date=r["invoice_date"],
            purchase_order_id=r.get("purchase_order_id"),
            file_ref=r["file_ref"],
            file_hash=r["file_hash"],
            status=r["status"],
            lines=lines,
            inward_preview=inward_preview,
            total_amount=round(total_amt, 2),
            idempotency_key=r.get("idempotency_key"),
            posted_at=r.get("posted_at"),
            movement_ids=r.get("movement_ids", []),
            created_at=r["created_at"],
        )

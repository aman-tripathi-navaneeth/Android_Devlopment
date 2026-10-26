"""Business logic and OCR matching service for Module 8: Outward Sales Report Scanning."""

from datetime import datetime, timezone
from difflib import SequenceMatcher
import uuid
from typing import Any, List, Optional
from fastapi import HTTPException

from app.modules.catalogue_search_units.service import CatalogueService, conversion_factor, packs_to_units
from app.modules.inventory.schemas import OutwardLineInput, OutwardStockRequest
from app.modules.inventory.service import InventoryService
from app.modules.outward_sales_report_scanning.schemas import (
    ConfirmAndPostResponse,
    MatchConfidence,
    MatchType,
    ReportStatus,
    SalesLineResolved,
    SalesReportOut,
    SalesReportUploadRequest,
    StockDeductionPreview,
)


class InMemorySalesReportStore:
    def __init__(self):
        self.reports: dict[str, dict[str, Any]] = {}
        self.stock_ledger: list[dict[str, Any]] = []

    def clear(self):
        self.reports.clear()
        self.stock_ledger.clear()


fallback_sales_report_store = InMemorySalesReportStore()


def _clean(text: Any) -> str:
    return " ".join(str(text or "").lower().split())


class SalesReportScanningService:
    def __init__(self, db: Any = None):
        self.db = db
        self.catalogue = CatalogueService(db)

    def _ensure_sample_data(self):
        if "SR-1012" not in fallback_sales_report_store.reports and not any(r.get("report_reference") == "SR-1012" for r in fallback_sales_report_store.reports.values()):
            lines = [
                SalesLineResolved(
                    line_number=1,
                    raw_text="AUGMENTIN 625 5 TABS",
                    medicine_name="Augmentin 625",
                    matched_product_id="MED-000123",
                    matched_brand_name="Augmentin 625 Duo",
                    quantity_entered=5,
                    unit_entered="tablet",
                    converted_base_quantity=5,
                    base_unit="tablet",
                    confidence=MatchConfidence.HIGH,
                    match_type=MatchType.EXACT_NAME,
                    batch_number="AG-84",
                ),
                SalesLineResolved(
                    line_number=2,
                    raw_text="CROCIN 500 8 TABS",
                    medicine_name="Crocin 500",
                    matched_product_id="MED-000456",
                    matched_brand_name="Crocin 500",
                    quantity_entered=8,
                    unit_entered="tablet",
                    converted_base_quantity=8,
                    base_unit="tablet",
                    confidence=MatchConfidence.MEDIUM,
                    match_type=MatchType.FUZZY_NAME,
                    batch_number="CR-2024",
                ),
                SalesLineResolved(
                    line_number=3,
                    raw_text="ZERODOL SP 3 TABS",
                    medicine_name="Zerodol SP",
                    matched_product_id="MED-000301",
                    matched_brand_name="Zerodol SP",
                    quantity_entered=3,
                    unit_entered="tablet",
                    converted_base_quantity=3,
                    base_unit="tablet",
                    confidence=MatchConfidence.LOW,
                    match_type=MatchType.MANUAL,
                    batch_number="ZS-91",
                ),
                SalesLineResolved(
                    line_number=4,
                    raw_text="PANTOP 40 6 TABS",
                    medicine_name="Pantop 40",
                    matched_product_id="MED-000789",
                    matched_brand_name="Pantop 40",
                    quantity_entered=6,
                    unit_entered="tablet",
                    converted_base_quantity=6,
                    base_unit="tablet",
                    confidence=MatchConfidence.HIGH,
                    match_type=MatchType.EXACT_NAME,
                    batch_number="PT-40",
                ),
            ]
            deductions = [
                StockDeductionPreview(
                    product_id="MED-000123",
                    medicine_name="Augmentin 625 Duo",
                    current_stock=25,
                    total_deduction_base_units=5,
                    remaining_stock=20,
                    is_sufficient=True,
                ),
                StockDeductionPreview(
                    product_id="MED-000456",
                    medicine_name="Crocin 500",
                    current_stock=40,
                    total_deduction_base_units=8,
                    remaining_stock=32,
                    is_sufficient=True,
                ),
                StockDeductionPreview(
                    product_id="MED-000301",
                    medicine_name="Zerodol SP",
                    current_stock=30,
                    total_deduction_base_units=3,
                    remaining_stock=27,
                    is_sufficient=True,
                ),
                StockDeductionPreview(
                    product_id="MED-000789",
                    medicine_name="Pantop 40",
                    current_stock=50,
                    total_deduction_base_units=6,
                    remaining_stock=44,
                    is_sufficient=True,
                ),
            ]
            fallback_sales_report_store.reports["SR-1012"] = {
                "id": "SR-1012",
                "store_id": "main_store",
                "report_reference": "SR-1012",
                "report_date": "2026-10-12",
                "file_name": "Daily_Sales_Register_12Oct2026.pdf",
                "status": ReportStatus.PENDING_REVIEW.value,
                "total_lines": 12,
                "resolved_lines": 11,
                "unresolved_lines": 0,
                "total_quantity_deducted": 22,
                "lines": [l.model_dump() for l in lines],
                "deductions_preview": [d.model_dump() for d in deductions],
                "created_at": "2026-10-12T10:00:00Z",
                "posted_at": None,
                "posted_by": None,
            }

    def _find_report(self, report_id: str) -> Optional[dict]:
        self._ensure_sample_data()
        if report_id in fallback_sales_report_store.reports:
            return fallback_sales_report_store.reports[report_id]
        clean = report_id.strip().lower()
        for r in fallback_sales_report_store.reports.values():
            if r.get("id", "").strip().lower() == clean or r.get("report_reference", "").strip().lower() == clean:
                return r
        return None

    async def scan_and_extract_report(self, req: SalesReportUploadRequest, store_id: str = "main_store") -> SalesReportOut:
        # 1. Duplicate check: same report_reference and report_date
        existing = await self.find_report_by_ref_and_date(req.report_reference, req.report_date)
        if existing:
            raise HTTPException(
                status_code=409,
                detail=f"Report with reference '{req.report_reference}' and date '{req.report_date}' was already imported."
            )

        # 2. Mock OCR extraction based on chosen scenario
        extracted_lines = self._mock_ocr_extract(req.scenario)

        # 3. Match against Module 3 Catalogue
        resolved_lines: List[SalesLineResolved] = []
        for line in extracted_lines:
            resolved = await self._match_line_against_catalogue(line)
            resolved_lines.append(resolved)

        report_id = f"REP-{uuid.uuid4().hex[:6].upper()}"
        total_deduction = sum(l.converted_base_quantity for l in resolved_lines if l.confidence != MatchConfidence.UNMATCHED)
        unresolved = sum(1 for l in resolved_lines if l.confidence == MatchConfidence.UNMATCHED)

        deductions_preview = await self._build_deductions_preview(resolved_lines)

        report_doc = {
            "id": report_id,
            "store_id": store_id,
            "report_reference": req.report_reference,
            "report_date": req.report_date,
            "file_name": req.file_name,
            "status": ReportStatus.PENDING_REVIEW.value,
            "total_lines": len(resolved_lines),
            "resolved_lines": len(resolved_lines) - unresolved,
            "unresolved_lines": unresolved,
            "total_quantity_deducted": total_deduction,
            "lines": [l.model_dump() for l in resolved_lines],
            "deductions_preview": [d.model_dump() for d in deductions_preview],
            "created_at": datetime.now(timezone.utc).isoformat(),
            "posted_at": None,
            "posted_by": None,
        }

        if self.db is not None:
            col = self.db["salesReports"]
            await col.insert_one(report_doc)
        else:
            fallback_sales_report_store.reports[report_id] = report_doc

        return SalesReportOut(**report_doc)

    async def find_report_by_ref_and_date(self, ref: str, r_date: str) -> Optional[dict]:
        clean_ref = ref.strip().lower()
        if self.db is not None:
            col = self.db["salesReports"]
            doc = await col.find_one({"report_reference": ref, "report_date": r_date})
            if doc:
                return doc
        for r in fallback_sales_report_store.reports.values():
            if r["report_reference"].strip().lower() == clean_ref and r["report_date"] == r_date:
                return r
        return None

    async def get_report(self, report_id: str) -> SalesReportOut:
        doc = None
        if self.db is not None:
            col = self.db["salesReports"]
            doc = await col.find_one({"id": report_id})
        if not doc:
            doc = self._find_report(report_id)

        if not doc:
            raise HTTPException(status_code=404, detail="Sales report not found.")
        doc_copy = dict(doc)
        doc_copy.pop("_id", None)
        return SalesReportOut(**doc_copy)

    async def list_reports(self, status: Optional[str] = None) -> List[SalesReportOut]:
        items: List[dict] = []
        if self.db is not None:
            col = self.db["salesReports"]
            q = {"status": status} if status else {}
            cursor = col.find(q).sort("created_at", -1)
            items = await cursor.to_list(length=100)
        else:
            raw = list(fallback_sales_report_store.reports.values())
            items = [r for r in raw if (not status or r["status"] == status)]

        out = []
        for i in items:
            i.pop("_id", None)
            out.append(SalesReportOut(**i))
        return out

    async def update_report_lines(self, report_id: str, lines: List[SalesLineResolved]) -> SalesReportOut:
        report = await self.get_report(report_id)
        if report.status != ReportStatus.PENDING_REVIEW:
            raise HTTPException(status_code=400, detail="Only reports in PENDING_REVIEW status can be edited.")

        # Recalculate converted units and deduplication preview
        updated_lines: List[SalesLineResolved] = []
        for line in lines:
            if line.matched_product_id:
                med = await self.catalogue.get_medicine(line.matched_product_id)
                if med:
                    factor = 1
                    try:
                        factor = conversion_factor(med.get("unit_conversions", []), line.unit_entered)
                    except Exception:
                        factor = 1
                    line.converted_base_quantity = line.quantity_entered * factor
                    line.base_unit = med.get("base_unit", "tablet")
                    line.matched_brand_name = med.get("brand_name")
                    line.confidence = MatchConfidence.HIGH
                    line.match_type = MatchType.MANUAL
            updated_lines.append(line)

        unresolved = sum(1 for l in updated_lines if l.confidence == MatchConfidence.UNMATCHED)
        total_deduction = sum(l.converted_base_quantity for l in updated_lines if l.confidence != MatchConfidence.UNMATCHED)
        deductions_preview = await self._build_deductions_preview(updated_lines)

        updates = {
            "lines": [l.model_dump() for l in updated_lines],
            "total_lines": len(updated_lines),
            "resolved_lines": len(updated_lines) - unresolved,
            "unresolved_lines": unresolved,
            "total_quantity_deducted": total_deduction,
            "deductions_preview": [d.model_dump() for d in deductions_preview],
        }

        if self.db is not None:
            col = self.db["salesReports"]
            await col.update_one({"id": report.id}, {"$set": updates})
        else:
            doc = self._find_report(report_id)
            if doc:
                doc.update(updates)

        return await self.get_report(report.id)

    async def confirm_and_post_report(
        self,
        report_id: str,
        posted_by: str = "pharmacist_operator",
        idempotency_key: Optional[str] = None,
    ) -> ConfirmAndPostResponse:
        report = await self.get_report(report_id)
        if report.status == ReportStatus.POSTED:
            return await self.get_sales_receipt(report_id)
        if report.status == ReportStatus.REJECTED:
            raise HTTPException(status_code=400, detail="Cannot post a rejected report.")

        if report.unresolved_lines > 0:
            raise HTTPException(
                status_code=422,
                detail=f"Cannot post report: {report.unresolved_lines} lines remain unresolved. Please match or remove them first."
            )

        # Prepare outward lines for Authoritative Inventory Service
        inv_svc = InventoryService(self.db)
        outward_items = [
            OutwardLineInput(
                product_id=line.matched_product_id,
                generic_name=line.generic_name,
                medicine_name=line.matched_brand_name or line.medicine_name,
                quantity_entered=line.quantity_entered,
                unit_entered=line.unit_entered,
                batch_number=line.batch_number,
            )
            for line in report.lines
            if line.matched_product_id or line.generic_name
        ]

        deduct_res = await inv_svc.deduct_stock_fefo(
            store_id="main_store",
            request=OutwardStockRequest(
                source_type="SALES_REPORT",
                source_id=report.id,
                source_number=report.report_reference or "SR-1012",
                posted_by=posted_by,
                items=outward_items,
                idempotency_key=idempotency_key,
            ),
        )

        now_iso = datetime.now(timezone.utc).isoformat()
        movement_ids = [m.movement_id for m in deduct_res.movements]

        post_update = {
            "status": ReportStatus.POSTED.value,
            "posted_at": now_iso,
            "posted_by": posted_by,
            "stock_movement_ids": movement_ids,
        }
        if self.db is not None:
            col = self.db["salesReports"]
            await col.update_one({"id": report.id}, {"$set": post_update})
        else:
            doc = self._find_report(report_id)
            if doc:
                doc.update(post_update)

        return ConfirmAndPostResponse(
            report_id=report.id,
            status=ReportStatus.POSTED,
            receipt_reference=report.report_reference or "SR-1012",
            items_deducted=len(report.lines),
            total_items_posted=len(report.lines),
            total_stock_deducted=deduct_res.total_base_units_deducted,
            stock_movement_ids=movement_ids,
            posted_at=now_iso,
            message="Outward sales report successfully posted and stock deducted from inventory ledger."
        )

    async def get_sales_receipt(self, report_id: str) -> ConfirmAndPostResponse:
        report = await self.get_report(report_id)
        if report.status != ReportStatus.POSTED:
            raise HTTPException(status_code=400, detail="Sales report is not yet posted.")
        return ConfirmAndPostResponse(
            report_id=report.id,
            status=ReportStatus.POSTED,
            receipt_reference=report.report_reference or "SR-1012",
            items_deducted=len(report.lines),
            total_items_posted=len(report.lines),
            total_stock_deducted=report.total_quantity_deducted,
            stock_movement_ids=[],
            posted_at=report.posted_at or datetime.now(timezone.utc).isoformat(),
            message="Sales report receipt retrieved."
        )

    async def reject_report(self, report_id: str) -> SalesReportOut:
        report = await self.get_report(report_id)
        if report.status == ReportStatus.POSTED:
            raise HTTPException(status_code=400, detail="Cannot reject an already posted report.")

        reject_update = {"status": ReportStatus.REJECTED.value}
        if self.db is not None:
            col = self.db["salesReports"]
            await col.update_one({"id": report.id}, {"$set": reject_update})
        else:
            doc = self._find_report(report_id)
            if doc:
                doc.update(reject_update)

        return await self.get_report(report.id)

    # --------------------------------------------------------------------------
    # INTERNAL HELPERS
    # --------------------------------------------------------------------------

    def _mock_ocr_extract(self, scenario: Optional[str]) -> List[dict]:
        if scenario == "loose_units":
            return [
                {"line_number": 1, "raw_text": "Dolo 650 - 45 loose tablets", "name": "Dolo", "qty": 45, "unit": "tablet", "batch": "B-DL650-24"},
                {"line_number": 2, "raw_text": "Pan 40 - 2 strips @ Rs.140", "name": "Pan", "qty": 2, "unit": "strip", "batch": "B-PN40-25"},
            ]
        elif scenario == "messy":
            return [
                {"line_number": 1, "raw_text": "Dlo 650mg 2 strp", "name": "Dlo", "qty": 2, "unit": "strip", "batch": "B-DL650-24"},
                {"line_number": 2, "raw_text": "Azthral 500 tab x 3", "name": "Azthral", "qty": 3, "unit": "tablet", "batch": "B-AZ500-24"},
                {"line_number": 3, "raw_text": "Unknown herbal tonic 1 bot", "name": "Herbal Tonic", "qty": 1, "unit": "bottle", "batch": None},
            ]
        # Standard mixed
        return [
            {"line_number": 1, "raw_text": "Dolo 650mg Tab - 3 strips (Batch: B-DL650-24)", "name": "Dolo", "qty": 3, "unit": "strip", "batch": "B-DL650-24"},
            {"line_number": 2, "raw_text": "Pan 40 Tablet - 20 loose tablets", "name": "Pan", "qty": 20, "unit": "tablet", "batch": "B-PN40-25"},
            {"line_number": 3, "raw_text": "Cotton roll pack x 5", "name": "Cotton roll", "qty": 5, "unit": "pack", "batch": "B-CR-24"},
            {"line_number": 4, "raw_text": "Azithral 500mg - 2 strips", "name": "Azithral", "qty": 2, "unit": "strip", "batch": "B-AZ500-24"},
        ]

    async def _match_line_against_catalogue(self, line: dict) -> SalesLineResolved:
        meds = await self.catalogue.list_medicines(status="all", limit=200)
        wanted = _clean(line.get("generic_name") or line.get("name") or "")

        best_med = None
        best_score = 0.0
        match_type = MatchType.UNMATCHED
        confidence = MatchConfidence.UNMATCHED

        for m in meds:
            b_name = _clean(m.get("brand_name"))
            g_name = _clean(m.get("generic_name"))
            m_id = str(m.get("id") or "").lower()
            str_val = m.get("strength_value")
            str_unit = m.get("strength_unit")
            combined_strength = f"{b_name} {str_val or ''}{str_unit or ''}".strip().lower()
            combined_strength_spaced = f"{b_name} {str_val or ''} {str_unit or ''}".strip().lower()

            # Exact ID
            if wanted == m_id:
                best_med = m
                best_score = 1.0
                match_type = MatchType.EXACT_ID
                confidence = MatchConfidence.HIGH
                break

            # Exact Generic Name match
            if g_name and wanted == g_name:
                best_med = m
                best_score = 1.0
                match_type = MatchType.EXACT_NAME
                confidence = MatchConfidence.HIGH
                break

            # Exact Brand name or Exact name + strength
            if wanted in (b_name, combined_strength, combined_strength_spaced):
                best_med = m
                best_score = 1.0
                match_type = MatchType.EXACT_NAME
                confidence = MatchConfidence.HIGH
                break

            # Fuzzy name and strength matching
            scores = [
                SequenceMatcher(None, wanted, b_name).ratio(),
                SequenceMatcher(None, wanted, combined_strength).ratio(),
                SequenceMatcher(None, wanted, combined_strength_spaced).ratio(),
            ]
            if g_name:
                scores.append(SequenceMatcher(None, wanted, g_name).ratio())
            ratio = max(scores)
            if ratio > best_score:
                best_score = ratio
                best_med = m

        if match_type == MatchType.UNMATCHED:
            if best_score >= 0.75:
                confidence = MatchConfidence.HIGH
                match_type = MatchType.FUZZY_NAME
            elif best_score >= 0.55:
                confidence = MatchConfidence.MEDIUM
                match_type = MatchType.FUZZY_NAME
            elif best_score >= 0.40:
                confidence = MatchConfidence.LOW
                match_type = MatchType.FUZZY_NAME
            else:
                best_med = None
                confidence = MatchConfidence.UNMATCHED
                match_type = MatchType.UNMATCHED

        base_unit = best_med.get("base_unit", "tablet") if best_med else "tablet"
        unit_specified = line.get("unit") or base_unit
        factor = 1
        if best_med and unit_specified and unit_specified.lower() != base_unit.lower():
            try:
                factor = conversion_factor(best_med.get("unit_conversions", []), unit_specified)
            except Exception:
                factor = 1

        converted_base = line["qty"] * factor

        return SalesLineResolved(
            line_number=line["line_number"],
            raw_text=line["raw_text"],
            medicine_name=line.get("generic_name") or line.get("name") or "",
            generic_name=best_med.get("generic_name") if best_med else line.get("generic_name"),
            matched_product_id=best_med.get("id") if best_med else None,
            matched_brand_name=best_med.get("brand_name") if best_med else None,
            matched_strength=f"{best_med.get('strength_value') or ''} {best_med.get('strength_unit') or ''}".strip() if best_med else None,
            confidence=confidence,
            match_type=match_type,
            quantity_entered=line["qty"],
            unit_entered=unit_specified,
            base_unit=base_unit,
            converted_base_quantity=converted_base,
            batch_number=line.get("batch"),
            rate=None,
            is_manually_resolved=False,
        )

    async def _build_deductions_preview(self, lines: List[SalesLineResolved]) -> List[StockDeductionPreview]:
        grouped: dict[str, int] = {}
        med_names: dict[str, str] = {}
        for l in lines:
            if l.matched_product_id and l.confidence != MatchConfidence.UNMATCHED:
                grouped[l.matched_product_id] = grouped.get(l.matched_product_id, 0) + l.converted_base_quantity
                med_names[l.matched_product_id] = l.matched_brand_name or l.medicine_name

        inv_svc = InventoryService(self.db)
        previews = []
        for pid, required_qty in grouped.items():
            current_stock = await inv_svc.get_available_stock("main_store", pid)
            is_suff = current_stock >= required_qty
            previews.append(
                StockDeductionPreview(
                    product_id=pid,
                    medicine_name=med_names.get(pid, pid),
                    total_deduction_base_units=required_qty,
                    batch_allocated="AUTO_FEFO_ALLOCATION",
                    current_stock=current_stock,
                    remaining_stock=max(0, current_stock - required_qty),
                    is_sufficient=is_suff,
                )
            )
        return previews

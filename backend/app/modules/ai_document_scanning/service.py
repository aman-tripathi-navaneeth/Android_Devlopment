from __future__ import annotations

import base64
import io
import json
import re
import uuid
from datetime import datetime, timezone
from typing import Any

import logging
import httpx
import asyncio
from PIL import Image
from fastapi import HTTPException, UploadFile

from app.core.config import Settings
from app.modules.catalogue_search_units.service import CatalogueService
from app.modules.inventory.service import InventoryService
from app.modules.inventory.schemas import OutwardStockRequest, OutwardLineInput


MAX_IMAGE_BYTES = 10 * 1024 * 1024
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}
UNIT_PATTERN = r"(?:tablets?|tabs?|tbl|capsules?|caps?|strips?|strp|bottles?|bot|packs?|boxes?|box|pck|units?|nos?)"

# Target size for Gemini upload — keeps API fast without losing text readability
_GEMINI_MAX_SIDE = 1280  # px
_GEMINI_JPEG_QUALITY = 80


def _compress_for_gemini(image_bytes: bytes) -> tuple[bytes, str]:
    """Resize image so longest side <= 1280px and re-encode as JPEG.
    Returns (compressed_bytes, 'image/jpeg').
    Falls back to original bytes on any error.
    """
    try:
        img = Image.open(io.BytesIO(image_bytes))
        # Convert non-RGB modes (RGBA, P, CMYK …) to RGB for JPEG encoding
        if img.mode not in ("RGB", "L"):
            img = img.convert("RGB")
        w, h = img.size
        longest = max(w, h)
        if longest > _GEMINI_MAX_SIDE:
            scale = _GEMINI_MAX_SIDE / longest
            img = img.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=_GEMINI_JPEG_QUALITY, optimize=True)
        compressed = buf.getvalue()
        logging.info(
            "Image compressed: %d KB → %d KB",
            len(image_bytes) // 1024,
            len(compressed) // 1024,
        )
        return compressed, "image/jpeg"
    except Exception as exc:
        logging.warning("Image compression failed (%s), using original.", exc)
        return image_bytes, "image/jpeg"


def _clean_str(text: Any) -> str:
    if not text:
        return ""
    return re.sub(r"[^a-z0-9]", "", str(text).lower())


def _levenshtein(a: str, b: str) -> int:
    """Compute the Levenshtein edit distance between two strings."""
    if len(a) < len(b):
        a, b = b, a
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a):
        curr = [i + 1]
        for j, cb in enumerate(b):
            curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (ca != cb)))
        prev = curr
    return prev[-1]


def _fuzzy_ratio(a: str, b: str) -> float:
    """Return similarity ratio 0.0-1.0 between two strings (1.0 = identical)."""
    if not a or not b:
        return 0.0
    dist = _levenshtein(a, b)
    return 1.0 - dist / max(len(a), len(b))


def _separate_medicine_name_and_quantity(
    medicine_name: str,
    generic_name: str,
    quantity: int,
    quantity_unit: str,
    raw_text: str = "",
) -> tuple[str, str, int, str]:
    """Ensures medicine_name strictly contains ONLY the drug brand/name.

    Extracts and separates any trailing or leading quantity and measurement
    unit into dedicated fields. Handles:
      - Trailing count and unit: 'Paracetamol 10 tablets' -> ('Paracetamol', 10, 'tablet')
      - Trailing count: 'Paracetamol 10' -> ('Paracetamol', 10, 'tablet')
      - Leading count: '10 tablets Paracetamol' -> ('Paracetamol', 10, 'tablet')
      - Multiplier syntax: 'Paracetamol x 10' -> ('Paracetamol', 10, 'tablet')
    """
    m = (medicine_name or "").strip()
    g = (generic_name or "").strip()
    q = quantity
    u = (quantity_unit or "unknown").strip().lower()

    # Pattern 1: Multiplier syntax, e.g. "Paracetamol x 10" or "Dolo 650 * 2 strips"
    p_mult = re.search(
        r"^(.*?)\s+([xX*])\s*(\d+)\s*(" + UNIT_PATTERN + r")?\s*$",
        m,
        re.IGNORECASE,
    )
    if p_mult:
        m = p_mult.group(1).strip()
        q = int(p_mult.group(3))
        if p_mult.group(4):
            u = p_mult.group(4).lower()

    # Pattern 2: Trailing count + unit: "Paracetamol 10 tablets", "Dolo 650 2 strips"
    p_trailing = re.search(
        r"^(.*?)\s+(\d+)\s*(" + UNIT_PATTERN + r")\s*$",
        m,
        re.IGNORECASE,
    )
    if p_trailing:
        m = p_trailing.group(1).strip()
        q = int(p_trailing.group(2))
        u = p_trailing.group(3).lower()
    else:
        # Pattern 3: Trailing count without unit: "Paracetamol 10"
        p_trailing_num = re.search(
            r"^(.*?[a-zA-Z](?:\s*\d+\s*(?:mg|ml|mcg|gm|g))?)\s+(\d+)\s*$",
            m,
            re.IGNORECASE,
        )
        if p_trailing_num:
            prefix = p_trailing_num.group(1).strip()
            num_val = int(p_trailing_num.group(2))
            # Protect common pharmaceutical strength values from being treated as quantities
            if num_val not in (650, 500, 250, 125, 1000, 625, 40, 20):
                m = prefix
                if q <= 0:
                    q = num_val
                if u == "unknown":
                    u = "tablet"

    # Pattern 4: Leading count + unit: "10 tablets Paracetamol"
    p_leading = re.search(
        r"^(\d+)\s*(" + UNIT_PATTERN + r")?\s+(?:of\s+)?(.*)$",
        m,
        re.IGNORECASE,
    )
    if p_leading and p_leading.group(3):
        extracted_q = int(p_leading.group(1))
        if extracted_q > 0:
            q = extracted_q
        if p_leading.group(2):
            u = p_leading.group(2).lower()
        m = p_leading.group(3).strip()

    # Pattern 5: Also clean generic name if it has trailing quantity
    p_gen = re.search(
        r"^(.*?)\s*[-–xX*:]?\s*(\d+)\s*(" + UNIT_PATTERN + r")?\s*$",
        g,
        re.IGNORECASE,
    )
    if p_gen and p_gen.group(1):
        g = p_gen.group(1).strip()

    # Fallback to raw_text if q is still 0
    if q <= 0 and raw_text:
        p_raw = re.search(r"(\d+)\s*(" + UNIT_PATTERN + r")", raw_text, re.IGNORECASE)
        if p_raw:
            q = int(p_raw.group(1))
            if p_raw.group(2):
                u = p_raw.group(2).lower()

    if q <= 0:
        q = 1

    # Normalize unit representation
    if re.search(r"strips?|strp", u):
        u = "strip"
    elif re.search(r"tablets?|tabs?|tbl|capsules?|caps?", u):
        u = "tablet"
    elif re.search(r"bottles?|bot", u):
        u = "bottle"
    elif re.search(r"packs?|boxes?|box|pck", u):
        u = "pack"
    elif u == "unknown":
        u = "tablet"

    if not g:
        g = m

    return m, g, q, u


class GeminiDocumentService:
    def __init__(self, settings: Settings, db: Any = None):
        self.settings = settings
        self.db = db

    async def scan_image(self, file: UploadFile, document_type: str) -> dict[str, Any]:
        if document_type not in {"invoice", "sales_report"}:
            raise HTTPException(status_code=400, detail="document_type must be invoice or sales_report")
        if not self.settings.gemini_api_key.strip():
            raise HTTPException(status_code=503, detail="GEMINI_API_KEY is not configured on the backend")

        mime_type = (file.content_type or "").lower()
        if mime_type not in ALLOWED_MIME_TYPES:
            raise HTTPException(status_code=415, detail="Only JPEG, PNG, WebP, HEIC, and HEIF images are supported")
        image_bytes = await file.read(MAX_IMAGE_BYTES + 1)
        if len(image_bytes) > MAX_IMAGE_BYTES:
            raise HTTPException(status_code=413, detail="Image must be 10 MB or smaller")
        if not image_bytes:
            raise HTTPException(status_code=400, detail="Uploaded image is empty")

        # Compress image before sending to Gemini — drastically reduces API latency
        compressed_bytes, compressed_mime = _compress_for_gemini(image_bytes)
        extracted_data = await self._extract_with_gemini(compressed_bytes, compressed_mime, document_type)
        raw_items = extracted_data.get("items") or extracted_data.get("medicines") or []

        matched_items = await self._match_medicines_against_catalogue(raw_items)

        now = datetime.now(timezone.utc)
        ocr_id = f"OCR-{uuid.uuid4().hex[:12].upper()}"
        file_name = file.filename or "uploaded-image"

        record = {
            "id": ocr_id,
            "document_type": document_type,
            "file_name": file_name,
            "mime_type": mime_type,
            "status": "PENDING_REVIEW",
            "medicines": matched_items,
            "items": matched_items,
            "source_text": extracted_data.get("source_text", ""),
            "model": self.settings.gemini_model,
            "created_at": now,
        }
        if self.db is not None:
            await self.db["ai_document_scans"].insert_one(record)

        # For sales_report scans: also create a PENDING_REVIEW draft in salesReports so it
        # immediately appears in the Transactions → Sales Reports tab.
        if document_type == "sales_report":
            sales_report_id = f"SR-OCR-{uuid.uuid4().hex[:10].upper()}"
            today_str = now.strftime("%Y-%m-%d")
            sales_report_lines = []
            for idx, item in enumerate(matched_items, start=1):
                med_name = str(item.get("medicine_name") or "").strip()
                gen_name = str(item.get("generic_name") or "").strip()
                qty = int(item.get("quantity") or 0)
                unit = str(item.get("unit") or item.get("quantity_unit") or "unknown")
                # Convert to base units for preview: 1 strip = 10 tablets by default
                factor = 10 if "strip" in unit.lower() else 1
                base_qty = qty * factor

                sales_report_lines.append({
                    "line_number": idx,
                    "raw_text": str(item.get("raw_text") or f"{med_name} {qty} {unit}"),
                    "medicine_name": med_name,
                    "generic_name": gen_name,
                    "matched_product_id": item.get("matched_product_id") or None,
                    "matched_brand_name": item.get("matched_product_name") or med_name or None,
                    "confidence": (
                        "HIGH" if (item.get("confidence_score") or 0) >= 0.9
                        else "MEDIUM" if (item.get("confidence_score") or 0) >= 0.7
                        else "LOW" if (item.get("confidence_score") or 0) > 0
                        else "UNMATCHED"
                    ),
                    "match_type": (
                        "EXACT_ID" if item.get("match_status") == "EXACT_MATCH" else
                        "FUZZY_NAME" if item.get("match_status") == "MULTIPLE_MATCHES" else
                        "UNMATCHED"
                    ),
                    "quantity_entered": qty,
                    "unit_entered": unit,
                    "base_unit": "tablet",
                    "converted_base_quantity": base_qty,
                    "batch_number": item.get("batch_number") or None,
                    "is_manually_resolved": False,
                })

            unresolved_count = sum(
                1 for l in sales_report_lines
                if l.get("match_type") == "UNMATCHED" or not l.get("matched_product_id")
            )
            total_base_units = sum(l.get("converted_base_quantity", 0) for l in sales_report_lines)

            # Automatically deduct stock from database for all resolved outward medicines
            inv_svc = InventoryService(self.db)
            outward_items = [
                OutwardLineInput(
                    product_id=item.get("matched_product_id"),
                    generic_name=item.get("generic_name") or item.get("medicine_name"),
                    medicine_name=item.get("matched_product_name") or item.get("medicine_name"),
                    quantity_entered=item.get("quantity") or 0,
                    unit_entered=item.get("unit") or item.get("quantity_unit") or "tablet",
                    batch_number=item.get("batch_number") or None,
                )
                for item in matched_items
                if item.get("matched_product_id") and (item.get("quantity") or 0) > 0
            ]

            deduct_movements = []
            total_deducted = 0
            is_posted = False

            if outward_items:
                try:
                    deduct_res = await inv_svc.deduct_stock_fefo(
                        store_id="main_store",
                        request=OutwardStockRequest(
                            source_type="SALES_REPORT",
                            source_id=sales_report_id,
                            source_number=f"AI-SCAN-{now.strftime('%Y%m%d-%H%M%S')}",
                            posted_by="Gemini OCR Auto-Post",
                            items=outward_items,
                            idempotency_key=f"AUTO-DEDUCT-{sales_report_id}",
                        ),
                    )
                    deduct_movements = [m.movement_id for m in deduct_res.movements]
                    total_deducted = deduct_res.total_base_units_deducted
                    is_posted = True
                except Exception as exc:
                    logging.warning("Could not auto-deduct stock for sales report %s: %s", sales_report_id, exc)

            report_status = "POSTED" if is_posted else "PENDING_REVIEW"

            sales_report_doc = {
                "id": sales_report_id,
                "store_id": "main_store",
                "report_reference": f"AI-SCAN-{now.strftime('%Y%m%d-%H%M%S')}",
                "report_date": today_str,
                "file_name": file_name,
                "source_type": "AI_SCAN",
                "ocr_scan_id": ocr_id,
                "status": report_status,
                "total_lines": len(sales_report_lines),
                "resolved_lines": len(sales_report_lines) - unresolved_count,
                "unresolved_lines": unresolved_count,
                "total_quantity_deducted": total_deducted,
                "total_base_units_preview": total_base_units,
                "lines": sales_report_lines,
                "stock_movement_ids": deduct_movements,
                "deductions_preview": [],
                "created_at": now.isoformat(),
                "posted_at": now.isoformat() if is_posted else None,
                "posted_by": "Gemini OCR Auto-Post" if is_posted else None,
            }

            if self.db is not None:
                await self.db["salesReports"].insert_one(sales_report_doc)
            try:
                from app.modules.outward_sales_report_scanning.service import fallback_sales_report_store
                fallback_sales_report_store.reports[sales_report_id] = sales_report_doc
            except Exception:
                pass

            # Include the sales_report_id and posted details so Flutter can immediately display results
            record["sales_report_id"] = sales_report_id
            record["status"] = report_status
            record["total_quantity_deducted"] = total_deducted

        return record

    async def list_scans(self, limit: int = 50) -> list[dict[str, Any]]:
        if self.db is None:
            return []
        return await self.db["ai_document_scans"].find().sort("created_at", -1).limit(limit).to_list(limit)

    @staticmethod
    def _normalize_unit(unit_str: str) -> str:
        u = str(unit_str or "").strip().lower()
        if any(s in u for s in ["strip", "strp"]):
            return "strip"
        if any(s in u for s in ["tablet", "tab", "tbl", "cap", "capsule"]):
            return "tablet"
        if any(s in u for s in ["bottle", "bot"]):
            return "bottle"
        if any(s in u for s in ["pack", "box", "pck"]):
            return "pack"
        return "unknown"

    async def _match_medicines_against_catalogue(self, items: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Separate extraction from medicine identification:

        Matches each extracted medicine against the existing PostgreSQL catalogue.
        Uses stable productId, brand name, generic name, strength, dosage form, and manufacturer.
        If unique match -> EXACT_MATCH with matched_product_id.
        If multiple matches -> MULTIPLE_MATCHES, leaves matched_product_id null for manual review.
        If no match -> UNMATCHED, leaves matched_product_id null for manual review.
        """
        catalogue_svc = CatalogueService(self.db)
        catalogue_medicines = await catalogue_svc.list_medicines(status="all", limit=500)

        results = []
        for item in items:
            med_name_raw = str(item.get("medicine_name") or "").strip()
            gen_name_raw = str(item.get("generic_name") or "").strip()
            raw_text = str(item.get("raw_text") or f"{med_name_raw} {item.get('quantity', '')} {item.get('quantity_unit', '')}")

            # Ensure medicine name and quantity are strictly separated
            med_name_clean, gen_name_clean, item_qty, item_unit = _separate_medicine_name_and_quantity(
                med_name_raw,
                gen_name_raw,
                int(item.get("quantity") or 0),
                str(item.get("quantity_unit") or item.get("unit") or "unknown"),
                raw_text,
            )

            cleaned_med = _clean_str(med_name_clean)
            cleaned_gen = _clean_str(gen_name_clean)

            candidate_matches = []

            for cat in catalogue_medicines:
                cat_id = str(cat.get("id") or cat.get("productId") or "").strip()
                cat_brand = str(cat.get("brand_name") or "").strip()
                cat_gen = str(cat.get("generic_name") or "").strip()
                cat_strength_val = str(cat.get("strength_value") or "").strip()
                cat_strength_unit = str(cat.get("strength_unit") or "").strip()
                cat_brand_clean = _clean_str(cat_brand)
                cat_gen_clean = _clean_str(cat_gen)
                cat_combined_clean = _clean_str(f"{cat_brand} {cat_strength_val}{cat_strength_unit}")

                # 1. Exact Product ID match
                if cat_id.lower() == med_name_clean.lower() or cat_id.lower() == cleaned_med:
                    candidate_matches.append((cat, 1.0))
                    continue

                # 2. Exact Brand Name + Strength match
                if cleaned_med and cleaned_med == cat_combined_clean:
                    candidate_matches.append((cat, 0.98))
                    continue

                # 3. Exact Brand Name match
                if cleaned_med and cleaned_med == cat_brand_clean:
                    candidate_matches.append((cat, 0.95))
                    continue

                # 4. Exact Generic Name match
                if cleaned_gen and cleaned_gen == cat_gen_clean:
                    candidate_matches.append((cat, 0.92))
                    continue
                if cleaned_med and cleaned_med == cat_gen_clean:
                    candidate_matches.append((cat, 0.90))
                    continue
                if cleaned_gen and cleaned_gen == cat_brand_clean:
                    candidate_matches.append((cat, 0.90))
                    continue

                # 5. Token containment match
                if cat_brand_clean and len(cat_brand_clean) >= 3 and (cat_brand_clean in cleaned_med or cleaned_med in cat_brand_clean):
                    candidate_matches.append((cat, 0.82))
                    continue
                if cat_gen_clean and len(cat_gen_clean) >= 3 and (cat_gen_clean in cleaned_med or cleaned_med in cat_gen_clean):
                    candidate_matches.append((cat, 0.80))
                    continue

                # 6. Fuzzy matching (handles typos like paracetamol <-> paractmol)
                best_ratio = 0.0
                for s1 in (cleaned_med, cleaned_gen):
                    for s2 in (cat_brand_clean, cat_gen_clean):
                        if s1 and s2 and len(s1) >= 3 and len(s2) >= 3:
                            r = _fuzzy_ratio(s1, s2)
                            if r > best_ratio:
                                best_ratio = r

                if best_ratio >= 0.70:
                    candidate_matches.append((cat, round(0.50 + best_ratio * 0.40, 3)))
                    continue

            # Deduplicate candidates by product ID
            unique_candidates: dict[str, tuple[dict[str, Any], float]] = {}
            for cand, score in candidate_matches:
                p_id = str(cand.get("id") or cand.get("productId"))
                if p_id not in unique_candidates or score > unique_candidates[p_id][1]:
                    unique_candidates[p_id] = (cand, score)

            matched_id: str | None = None
            matched_name: str | None = None
            match_status: str = "UNMATCHED"
            confidence: float = 0.0

            if unique_candidates:
                # Pick the highest scoring candidate (closest match!)
                sorted_cands = sorted(unique_candidates.values(), key=lambda x: x[1], reverse=True)
                top_cat, top_score = sorted_cands[0]
                matched_id = str(top_cat.get("id") or top_cat.get("productId"))
                str_val = top_cat.get("strength_value") or ""
                str_unit = top_cat.get("strength_unit") or ""
                brand = top_cat.get("brand_name") or top_cat.get("name") or ""
                matched_name = f"{brand} {str_val}{str_unit}".strip()
                match_status = "EXACT_MATCH" if top_score >= 0.90 else "FUZZY_MATCH"
                confidence = top_score
            else:
                # No match found. Flag for manual review.
                match_status = "UNMATCHED"
                confidence = 0.0

            norm_unit = self._normalize_unit(item_unit)

            results.append({
                "medicine_name": med_name_clean,
                "generic_name": gen_name_clean,
                "quantity": max(0, int(item_qty)),
                "quantity_unit": item_unit,
                "unit": norm_unit,
                "batch_number": item.get("batch_number") or None,
                "expiry_date": item.get("expiry_date") or None,
                "raw_text": raw_text,
                "matched_product_id": matched_id,
                "matched_product_name": matched_name,
                "match_status": match_status,
                "confidence_score": confidence,
            })

        return results

    async def _extract_with_gemini(self, image_bytes: bytes, mime_type: str, document_type: str) -> dict[str, Any]:
        doc_context = (
            "a pharmacy daily sales register or POS receipt (recording medicines SOLD to customers)"
            if document_type == "sales_report"
            else "a pharmacy purchase invoice or supplier challan (recording medicines PURCHASED from a supplier)"
        )

        prompt = f"""
You are an expert pharmacy assistant. Extract structured medicine data from this image of {doc_context}.

YOUR ONLY JOB: Parse each line in the document and return a JSON array where EVERY medicine is a SEPARATE object with:
  - medicine_name: ONLY the drug brand/product name. Example: "Paracetamol 500mg", "Dolo 650", "Augmentin 625 Duo".
  - generic_name: The active ingredient / generic INN name. Example: "Paracetamol", "Amoxicillin & Clavulanate", "Cetirizine".
  - quantity: The INTEGER count sold/purchased. Example: 10, 2, 5.
  - quantity_unit: EXACTLY ONE of: "strips", "tablets", "bottles", "packs", "unknown".
  - batch_number: The batch/lot code if visible, else empty string "".
  - expiry_date: Expiry date formatted YYYY-MM or YYYY-MM-DD if visible, else empty string "".
  - raw_text: The exact full original line text from the document.

=== CRITICAL SEPARATION RULE ===
If a document line says "Paracetamol 10 tablets":
  - medicine_name = "Paracetamol"    ← name ONLY
  - quantity      = 10               ← number ONLY
  - quantity_unit = "tablets"        ← unit ONLY
  - NEVER put "Paracetamol 10 tablets" inside medicine_name!

More examples:
  "Dolo 650 2 strips"       → medicine_name="Dolo 650",          quantity=2,  quantity_unit="strips"
  "Augmentin 625 x5 tabs"   → medicine_name="Augmentin 625 Duo", quantity=5,  quantity_unit="tablets"
  "PAN 40 - 1 strip Rs.45"  → medicine_name="Pan 40",            quantity=1,  quantity_unit="strips"
  "Crocin 500mg 10T"        → medicine_name="Crocin 500mg",      quantity=10, quantity_unit="tablets"

=== UNIT DETECTION ===
  - strips / strip / strp / STR  → "strips"
  - tablets / tablet / tab / tabs / T / caps / capsules → "tablets"
  - bottle / syrup / liq         → "bottles"
  - pack / box / pck             → "packs"
  - anything else or unclear     → "unknown"

Return a single JSON object:
{{
  "source_text": "<full transcription of all text in the document>",
  "items": [<one object per medicine line>]
}}
""".strip()

        schema = {
            "type": "object",
            "properties": {
                "source_text": {"type": "string"},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "medicine_name": {
                                "type": "string",
                                "description": "Brand or product name only. Never include quantity, unit, price, or batch.",
                            },
                            "generic_name": {
                                "type": "string",
                                "description": "Generic active chemical substance.",
                            },
                            "quantity": {
                                "type": "integer",
                                "description": "Numeric quantity as an integer.",
                            },
                            "quantity_unit": {
                                "type": "string",
                                "description": "'strips' or 'tablets' or 'bottles' or 'packs' or 'unknown'.",
                            },
                            "batch_number": {
                                "type": "string",
                                "description": "Batch code if printed, else empty.",
                            },
                            "expiry_date": {
                                "type": "string",
                                "description": "Expiry date formatted YYYY-MM or YYYY-MM-DD if printed, else empty.",
                            },
                            "raw_text": {
                                "type": "string",
                                "description": "Exact original line text.",
                            },
                        },
                        "required": ["medicine_name", "quantity", "quantity_unit", "raw_text"],
                    },
                },
            },
            "required": ["source_text", "items"],
        }

        payload = {
            "contents": [{
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {"inline_data": {"mime_type": mime_type, "data": base64.b64encode(image_bytes).decode("ascii")}},
                ],
            }],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": 0,
            },
        }
        # Prioritize configured model and verified fast stable models
        preferred = [
            self.settings.gemini_model,
            "gemini-3.5-flash-lite",
            "gemini-2.5-flash",
            "gemini-3-flash-preview",
            "gemini-3.1-flash-lite-preview",
        ]
        models_to_try = list(dict.fromkeys(m for m in preferred if m))

        # Fast timeout per model to fall through quickly if a model is hanging or overloaded
        per_model_timeout = min(self.settings.gemini_timeout_seconds, 10.0)

        response = None
        last_error_msg = ""
        for model_name in models_to_try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
            headers = {"x-goog-api-key": self.settings.gemini_api_key, "content-type": "application/json"}
            try:
                async with httpx.AsyncClient(timeout=per_model_timeout) as client:
                    resp = await client.post(url, headers=headers, json=payload)
                if resp.status_code == 200:
                    logging.info("Gemini model %s succeeded.", model_name)
                    response = resp
                    break
                elif resp.status_code == 429:
                    err_text = resp.text[:200]
                    last_error_msg = f"{model_name} quota exceeded (HTTP 429): {err_text}"
                    logging.warning("Gemini model %s quota exceeded (429). Switching to next model immediately...", model_name)
                    continue
                elif resp.status_code == 503:
                    err_text = resp.text[:200]
                    last_error_msg = f"{model_name} overloaded (HTTP 503): {err_text}"
                    logging.warning("Gemini model %s overloaded (503). Switching to next model...", model_name)
                    continue
                else:
                    err_text = resp.text[:200]
                    last_error_msg = f"{model_name} (HTTP {resp.status_code}): {err_text}"
                    logging.warning("Gemini model %s returned status %d. Switching to next model...", model_name, resp.status_code)
                    continue
            except httpx.HTTPError as exc:
                last_error_msg = f"{model_name} network/timeout error: {exc}"
                logging.warning("Gemini model %s network/timeout error: %s. Switching to next model...", model_name, exc)
                continue

        if response is None or response.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=f"Gemini API error across all models. Last error: {last_error_msg}",
            )

        try:
            body = response.json()
            candidates = body.get("candidates") or []
            if not candidates:
                return {"source_text": "", "items": []}
            part = candidates[0].get("content", {}).get("parts", [{}])[0]

            raw = part.get("text") or part.get("json")
            if not raw:
                return {"source_text": "", "items": []}

            extracted: dict = json.loads(raw) if isinstance(raw, str) else raw
            if not isinstance(extracted, dict):
                extracted = {"items": extracted if isinstance(extracted, list) else []}

            items = extracted.get("items")
            if items is None:
                items = extracted.get("medicines")
            if not isinstance(items, list):
                items = []

            cleaned = []
            for itm in items:
                gen_name = str(itm.get("generic_name") or "").strip()
                med_name = str(itm.get("medicine_name") or gen_name).strip()
                unit_raw = str(itm.get("quantity_unit") or itm.get("unit") or "unknown")
                qty = itm.get("quantity")
                try:
                    qty_int = max(0, int(qty)) if qty is not None else 0
                except (ValueError, TypeError):
                    qty_int = 0

                raw_line_text = str(itm.get("raw_text") or "")

                # Strictly separate medicine name and quantity/unit
                med_name_clean, gen_name_clean, qty_clean, unit_clean = _separate_medicine_name_and_quantity(
                    medicine_name=med_name,
                    generic_name=gen_name,
                    quantity=qty_int,
                    quantity_unit=unit_raw,
                    raw_text=raw_line_text,
                )

                cleaned.append({
                    "medicine_name": med_name_clean,
                    "generic_name": gen_name_clean,
                    "quantity": qty_clean,
                    "quantity_unit": unit_clean,
                    "batch_number": itm.get("batch_number") or None,
                    "expiry_date": itm.get("expiry_date") or None,
                    "raw_text": raw_line_text or f"{med_name_clean} {qty_clean} {unit_clean}",
                })

            return {"source_text": str(extracted.get("source_text", "")), "items": cleaned}
        except (KeyError, IndexError) as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Unexpected Gemini response structure: {exc}. Body snippet: {str(body)[:300]}",
            ) from exc
        except (TypeError, ValueError, json.JSONDecodeError) as exc:
            raise HTTPException(status_code=502, detail=f"Gemini returned unparseable data: {exc}") from exc

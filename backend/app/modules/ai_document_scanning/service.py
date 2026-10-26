from __future__ import annotations

import json
import base64
import uuid
from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import HTTPException, UploadFile

from app.core.config import Settings


MAX_IMAGE_BYTES = 10 * 1024 * 1024
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}


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

        result = await self._extract_with_gemini(image_bytes, mime_type, document_type)
        record = {
            "id": f"OCR-{uuid.uuid4().hex[:12].upper()}",
            "document_type": document_type,
            "file_name": file.filename or "uploaded-image",
            "mime_type": mime_type,
            "status": "PENDING_REVIEW",
            "medicines": result["medicines"],
            "source_text": result.get("source_text", ""),
            "model": self.settings.gemini_model,
            "created_at": datetime.now(timezone.utc),
        }
        if self.db is not None:
            await self.db["ai_document_scans"].insert_one(record)
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
        if any(s in u for s in ["tablet", "tab", "tbl"]):
            return "tablet"
        return "unknown"

    async def _extract_with_gemini(self, image_bytes: bytes, mime_type: str, document_type: str) -> dict[str, Any]:
        prompt = f"""
You are an expert pharmacy assistant extracting medicine sales records from an image.
Analyze the handwritten or printed text and convert each medicine entry into structured JSON.

For each medicine, extract:
1. generic_name: The medicine's generic name / active chemical ingredient.
   - Examples: 'Paracetamol', 'Amoxicillin', 'Cetirizine', 'Pantoprazole', 'Azithromycin'.
   - If a brand name is written (e.g. 'Dolo', 'Crocin', 'Calpol'), identify and extract its generic name (e.g. 'Paracetamol').
   - Ignore company or manufacturer names when extracting generic_name.
2. quantity: The numeric quantity sold as an integer.
3. unit: Automatically identify whether the quantity is in strips or tablets:
   - If text indicates strips (e.g., '2 strips', '2 strip', '2 strp'), output 'strip'.
   - If text indicates tablets (e.g., '10 tablets', '10 tabs', '10 tab'), output 'tablet'.
   - If the unit is unclear, ambiguous, or not mentioned, output 'unknown'. Do not guess.
4. medicine_name: The brand name or text as written on the paper.
5. raw_text: The exact original line text written.

Return a JSON object with:
- "source_text": The full document text.
- "medicines": Array of objects, each containing:
  "generic_name": string,
  "medicine_name": string,
  "quantity": integer,
  "unit": string ("strip" | "tablet" | "unknown"),
  "batch_number": string (empty if not visible),
  "expiry_date": string (empty if not visible),
  "raw_text": string.
""".strip()
        schema = {
            "type": "object",
            "properties": {
                "source_text": {"type": "string"},
                "medicines": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "generic_name": {"type": "string", "description": "Generic medicine name e.g. Paracetamol, Amoxicillin, Cetirizine"},
                            "medicine_name": {"type": "string", "description": "Brand or full name as written"},
                            "quantity": {"type": "integer", "description": "Numeric quantity sold"},
                            "unit": {"type": "string", "description": "'strip' or 'tablet' or 'unknown'"},
                            "batch_number": {"type": "string", "description": "Empty string when not visible"},
                            "expiry_date": {"type": "string", "description": "Empty string when not visible"},
                            "raw_text": {"type": "string"},
                        },
                        "required": ["generic_name", "quantity", "unit", "raw_text"],
                    },
                },
            },
            "required": ["source_text", "medicines"],
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
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.settings.gemini_model}:generateContent"
        headers = {"x-goog-api-key": self.settings.gemini_api_key, "content-type": "application/json"}
        try:
            async with httpx.AsyncClient(timeout=self.settings.gemini_timeout_seconds) as client:
                response = await client.post(url, headers=headers, json=payload)
        except httpx.HTTPError as exc:
            raise HTTPException(status_code=502, detail=f"Gemini network error: {exc}") from exc

        if response.status_code >= 400:
            # Surface the actual Gemini error text so the Flutter client can show it
            try:
                err_body = response.json()
                err_msg = err_body.get("error", {}).get("message", response.text[:500])
            except Exception:
                err_msg = response.text[:500]
            raise HTTPException(
                status_code=502,
                detail=f"Gemini API error (HTTP {response.status_code}): {err_msg}",
            )

        try:
            body = response.json()
            candidate = body["candidates"][0]
            part = candidate["content"]["parts"][0]

            # Gemini returns either a "text" field (string JSON) or a direct dict when
            # responseMimeType=application/json is used. Handle both.
            raw = part.get("text") or part.get("json")
            if raw is None:
                raise ValueError(f"Unexpected Gemini part keys: {list(part.keys())}")

            extracted: dict = json.loads(raw) if isinstance(raw, str) else raw

            medicines = extracted.get("medicines")
            if not isinstance(medicines, list):
                raise ValueError("medicines field is not an array in Gemini response")

            cleaned = []
            for medicine in medicines:
                gen_name = str(medicine.get("generic_name") or medicine.get("medicine_name") or "").strip()
                med_name = str(medicine.get("medicine_name") or gen_name).strip()
                unit_raw = str(medicine.get("unit") or "unknown")
                normalized_unit = self._normalize_unit(unit_raw)
                cleaned.append({
                    "generic_name": gen_name,
                    "medicine_name": med_name,
                    "quantity": max(0, int(medicine.get("quantity", 0))),
                    "unit": normalized_unit,
                    "batch_number": medicine.get("batch_number") or None,
                    "expiry_date": medicine.get("expiry_date") or None,
                    "raw_text": str(medicine.get("raw_text", "")),
                })
            return {"source_text": str(extracted.get("source_text", "")), "medicines": cleaned}
        except (KeyError, IndexError) as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Unexpected Gemini response structure: {exc}. Body snippet: {str(body)[:300]}",
            ) from exc
        except (TypeError, ValueError, json.JSONDecodeError) as exc:
            raise HTTPException(status_code=502, detail=f"Gemini returned unparseable data: {exc}") from exc

"""Business logic, validation rules, unit conversions, and persistence for Module 3: Medicine Catalogue."""

from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP
from difflib import SequenceMatcher
import re
import uuid
from typing import Any, List, Optional
from fastapi import HTTPException
import json
from pathlib import Path


class CatalogueError(ValueError):
    """Business rule violation for medicine catalogue."""


class ConversionError(ValueError):
    """Business rule violation for pack and unit conversions."""


ALLOWED_FORMS = {"tablet", "strip", "bottle", "injection", "tube", "other"}
ALLOWED_CATEGORIES = {"medicine", "derma", "clinic", "personal_care", "sanitary", "food"}
REQUIRED_FIELDS = ["catalogue_scope", "brand_name", "form", "category", "base_unit", "unit_conversions"]
EDITABLE_FIELDS = {
    "brand_name", "generic_name", "manufacturer", "strength_value",
    "strength_unit", "form", "category", "base_unit", "unit_conversions"
}


# ==============================================================================
# UNIT CONVERSION ENGINE (Pure Functions)
# ==============================================================================

def validate_conversions(conversions: list) -> None:
    if not conversions:
        raise ConversionError("At least one unit conversion is required.")
    seen = set()
    for conversion in conversions:
        if isinstance(conversion, dict):
            unit = str(conversion.get("pack_unit", "")).strip().lower()
            factor = conversion.get("factor")
        else:
            unit = str(getattr(conversion, "pack_unit", "")).strip().lower()
            factor = getattr(conversion, "factor", None)

        if not unit:
            raise ConversionError("Each conversion needs a pack unit, such as strip or bottle.")
        if factor is None or isinstance(factor, bool) or not isinstance(factor, int) or factor < 1:
            raise ConversionError(f"The conversion factor for '{unit}' must be a whole number of at least 1.")
        if unit in seen:
            raise ConversionError(f"The pack unit '{unit}' is defined twice.")
        seen.add(unit)


def conversion_factor(conversions: list, pack_unit: str) -> int:
    wanted = pack_unit.strip().lower()
    for conversion in conversions:
        if isinstance(conversion, dict):
            p = str(conversion.get("pack_unit", "")).strip().lower()
            f = conversion.get("factor")
        else:
            p = str(getattr(conversion, "pack_unit", "")).strip().lower()
            f = getattr(conversion, "factor", None)
        if p == wanted:
            return int(f)
    raise ConversionError(f"No conversion is defined for pack unit '{pack_unit}'.")


def packs_to_units(packs: int, factor: int) -> int:
    """e.g. 2 strips of 15 tablets = 30 tablets."""
    if packs < 0 or factor < 1:
        raise ConversionError("Packs cannot be negative, and the factor must be at least 1.")
    return packs * factor


def units_to_packs(units: int, factor: int) -> tuple[int, int]:
    """e.g. 293 tablets with factor 15 = (19 strips, 8 loose tablets)."""
    if units < 0 or factor < 1:
        raise ConversionError("Units cannot be negative, and the factor must be at least 1.")
    return units // factor, units % factor


def loose_unit_price(pack_price: float, factor: int) -> Decimal:
    """Loose unit price = pack price / factor, rounded to 2 decimal places (paise)."""
    if factor < 1:
        raise ConversionError("The factor must be at least 1.")
    price = Decimal(str(pack_price)) / Decimal(factor)
    return price.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


# ==============================================================================
# SEARCH RANKING & TYPO TOLERANCE
# ==============================================================================

def _clean(text: Any) -> str:
    return " ".join(str(text or "").lower().split())


def compute_search_score(document: dict, query: str) -> float:
    wanted = _clean(query)
    if not wanted:
        return 0.0

    # Direct ID match
    doc_id = str(document.get("id") or document.get("_id") or "").lower()
    if wanted == doc_id or wanted in doc_id:
        return 1.0

    best = 0.0
    for field in ("brand_name", "generic_name", "manufacturer"):
        val = _clean(document.get(field))
        if not val:
            continue
        if val == wanted:
            s = 1.0
        elif val.startswith(wanted):
            s = 0.9
        elif wanted in val:
            s = 0.8
        else:
            s = SequenceMatcher(None, wanted, val).ratio() * 0.7
        best = max(best, s)
    return best


def rank_medicines(documents: list, query: str, min_score: float = 0.45) -> list:
    scored = [(compute_search_score(d, query), d) for d in documents]
    kept = [(s, d) for s, d in scored if s >= min_score]
    kept.sort(key=lambda pair: (-pair[0], _clean(pair[1].get("brand_name"))))
    return [d for _, d in kept]


# ==============================================================================
# VALIDATION & DUPLICATE CHECKS
# ==============================================================================

def check_new_medicine(data: dict) -> None:
    for field in REQUIRED_FIELDS:
        if not data.get(field):
            raise CatalogueError(f"Missing required field: {field}")
    if not data["brand_name"].strip():
        raise CatalogueError("Brand name cannot be empty.")
    if data.get("strength_value") is not None and not data.get("strength_unit"):
        raise CatalogueError("Give the strength unit (for example mg) together with the strength value.")
    if data.get("form") not in ALLOWED_FORMS:
        raise CatalogueError(f"Form '{data.get('form')}' is invalid. Allowed: {sorted(ALLOWED_FORMS)}")
    if data.get("category") not in ALLOWED_CATEGORIES:
        raise CatalogueError(f"Category '{data.get('category')}' is invalid. Allowed: {sorted(ALLOWED_CATEGORIES)}")
    validate_conversions(data["unit_conversions"])


def check_changes(changes: dict) -> None:
    unknown = set(changes) - EDITABLE_FIELDS
    if unknown:
        raise CatalogueError(f"These fields cannot be edited: {', '.join(sorted(unknown))}")
    if not changes:
        raise CatalogueError("Nothing to change.")
    if "brand_name" in changes and not str(changes["brand_name"] or "").strip():
        raise CatalogueError("Brand name cannot be empty.")
    if changes.get("strength_value") is not None and "strength_unit" not in changes:
        raise CatalogueError("Give the strength unit together with the strength value.")
    if "form" in changes and changes["form"] not in ALLOWED_FORMS:
        raise CatalogueError(f"Form '{changes['form']}' is invalid. Allowed: {sorted(ALLOWED_FORMS)}")
    if "category" in changes and changes["category"] not in ALLOWED_CATEGORIES:
        raise CatalogueError(f"Category '{changes['category']}' is invalid. Allowed: {sorted(ALLOWED_CATEGORIES)}")
    if "unit_conversions" in changes:
        validate_conversions(changes["unit_conversions"])


def manufacturer_warnings(candidate: dict, existing: list) -> list:
    name = _clean(candidate.get("brand_name"))
    maker = _clean(candidate.get("manufacturer"))
    if not name or not maker:
        return []
    warnings = []
    for doc in existing:
        if doc.get("status", "active") != "active":
            continue
        if _clean(doc.get("brand_name")) == name and _clean(doc.get("manufacturer")) == maker:
            strength = doc.get("strength_value")
            detail = f" {strength:g}{doc.get('strength_unit') or ''}" if strength is not None else ""
            warnings.append(
                f"'{doc.get('brand_name')}{detail}' from {doc.get('manufacturer')} already exists in catalogue. "
                "Check that this is a different strength or form."
            )
    return warnings


# ==============================================================================
# IN-MEMORY REPOSITORY & PERSISTENCE
# ==============================================================================

_FALLBACK_STORE_PATH = Path(__file__).resolve().parents[3] / "data" / "catalogue_store.json"


class InMemoryCatalogueStore:
    def __init__(self):
        self.medicines: dict[str, dict[str, Any]] = {}
        self._load()
        if not self.medicines:
            self.seed_sample_data()
            self._save()

    def _load(self):
        try:
            if _FALLBACK_STORE_PATH.exists():
                with open(_FALLBACK_STORE_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        self.medicines = data
        except Exception:
            pass

    def _save(self):
        try:
            _FALLBACK_STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
            with open(_FALLBACK_STORE_PATH, "w", encoding="utf-8") as f:
                json.dump(self.medicines, f, indent=2, default=str)
        except Exception:
            pass

    def clear(self):
        self.medicines.clear()
        self._save()

    def seed_sample_data(self):
        samples = [
            {
                "id": "med-000101",
                "catalogue_scope": "shared",
                "brand_name": "Dolo",
                "generic_name": "Paracetamol",
                "strength_value": 650.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "Micro Labs",
                "unit_conversions": [{"pack_unit": "strip", "factor": 15}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000102",
                "catalogue_scope": "shared",
                "brand_name": "Dolo",
                "generic_name": "Paracetamol",
                "strength_value": 500.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "Micro Labs",
                "unit_conversions": [{"pack_unit": "strip", "factor": 15}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000103",
                "catalogue_scope": "shared",
                "brand_name": "Pan",
                "generic_name": "Pantoprazole",
                "strength_value": 40.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "Alkem",
                "unit_conversions": [{"pack_unit": "strip", "factor": 10}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000104",
                "catalogue_scope": "shared",
                "brand_name": "Cotton roll",
                "generic_name": None,
                "strength_value": None,
                "strength_unit": None,
                "form": "other",
                "category": "clinic",
                "base_unit": "piece",
                "status": "active",
                "manufacturer": "Sample Surgicals",
                "unit_conversions": [{"pack_unit": "pack", "factor": 1}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000105",
                "catalogue_scope": "shared",
                "brand_name": "Azithral",
                "generic_name": "Azithromycin",
                "strength_value": 500.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "Alembic",
                "unit_conversions": [{"pack_unit": "strip", "factor": 5}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000106",
                "catalogue_scope": "shared",
                "brand_name": "Betadine",
                "generic_name": "Povidone Iodine",
                "strength_value": 10.0,
                "strength_unit": "%",
                "form": "tube",
                "category": "derma",
                "base_unit": "tube",
                "status": "inactive",
                "manufacturer": "Win-Medicare",
                "unit_conversions": [{"pack_unit": "box", "factor": 1}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000456",
                "catalogue_scope": "shared",
                "brand_name": "Crocin 500 Advance",
                "generic_name": "Paracetamol",
                "strength_value": 500.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "GlaxoSmithKline",
                "unit_conversions": [{"pack_unit": "strip", "factor": 15}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000112",
                "catalogue_scope": "shared",
                "brand_name": "Amoxil 500",
                "generic_name": "Amoxicillin",
                "strength_value": 500.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "GSK",
                "unit_conversions": [{"pack_unit": "strip", "factor": 10}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
            {
                "id": "med-000113",
                "catalogue_scope": "shared",
                "brand_name": "Cetzine 10",
                "generic_name": "Cetirizine",
                "strength_value": 10.0,
                "strength_unit": "mg",
                "form": "tablet",
                "category": "medicine",
                "base_unit": "tablet",
                "status": "active",
                "manufacturer": "GSK",
                "unit_conversions": [{"pack_unit": "strip", "factor": 10}],
                "created_at": datetime.now(timezone.utc).isoformat(),
            },
        ]
        for s in samples:
            self.medicines[s["id"]] = s


fallback_catalogue_store = InMemoryCatalogueStore()


class CatalogueService:
    def __init__(self, db: Any = None):
        self.db = db

    async def create_medicine(self, data: dict) -> dict:
        check_new_medicine(data)

        # Uniqueness check: One active medicine per name, strength, and form
        existing_all = await self.list_medicines(status="all", scope=data.get("catalogue_scope"))
        for item in existing_all:
            if item.get("status") == "active":
                same_name = _clean(item.get("brand_name")) == _clean(data.get("brand_name"))
                same_strength_val = item.get("strength_value") == data.get("strength_value")
                same_strength_unit = _clean(item.get("strength_unit")) == _clean(data.get("strength_unit"))
                same_form = _clean(item.get("form")) == _clean(data.get("form"))
                if same_name and same_strength_val and same_strength_unit and same_form:
                    raise HTTPException(status_code=409, detail="This active medicine already exists in the catalogue.")

        warnings = manufacturer_warnings(data, existing_all)

        med_id = f"MED-{uuid.uuid4().hex[:6].upper()}"
        doc = {
            **data,
            "id": med_id,
            "productId": med_id,
            "status": "active",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        if self.db is not None:
            products_col = self.db["products"]
            insert_doc = {**doc}
            await products_col.insert_one(insert_doc)
        else:
            fallback_catalogue_store.medicines[med_id] = doc
            fallback_catalogue_store._save()

        return {"id": med_id, "brand_name": doc["brand_name"], "warnings": warnings}

    async def _ensure_seed_products(self) -> None:
        if self.db is not None:
            products_col = self.db["products"]
            existing = await products_col.find({}).limit(1).to_list(1)
            if not existing:
                for s in fallback_catalogue_store.medicines.values():
                    await products_col.insert_one(dict(s))

    async def get_medicine(self, product_id: str) -> Optional[dict]:
        await self._ensure_seed_products()
        if self.db is not None:
            products_col = self.db["products"]
            conds: list[dict[str, Any]] = [{"id": product_id}, {"productId": product_id}]
            doc = await products_col.find_one({"$or": conds})
            if doc:
                doc["id"] = str(doc.get("id") or doc.get("productId") or doc.get("_id"))
                return doc
            return None
        return fallback_catalogue_store.medicines.get(product_id)

    async def list_medicines(
        self,
        status: str = "active",
        scope: Optional[str] = None,
        category: Optional[str] = None,
        form: Optional[str] = None,
        limit: int = 100,
    ) -> List[dict]:
        await self._ensure_seed_products()
        if self.db is not None:
            products_col = self.db["products"]
            query: dict[str, Any] = {}
            if status != "all":
                query["status"] = status
            if scope:
                query["catalogue_scope"] = scope
            if category:
                query["category"] = category
            if form:
                query["form"] = form
            cursor = products_col.find(query).limit(limit)
            docs = await cursor.to_list(length=limit)
            out = []
            for d in docs:
                d["id"] = str(d.get("id") or d.get("productId") or d.pop("_id", ""))
                out.append(d)
            return out

        # In-memory store
        items = list(fallback_catalogue_store.medicines.values())
        filtered = []
        for m in items:
            if status != "all" and m.get("status") != status:
                continue
            if scope and m.get("catalogue_scope") != scope:
                continue
            if category and m.get("category") != category:
                continue
            if form and m.get("form") != form:
                continue
            filtered.append(m)
        return filtered[:limit]

    async def search_medicines(
        self,
        query: Optional[str] = None,
        status: str = "active",
        scope: Optional[str] = None,
        category: Optional[str] = None,
        form: Optional[str] = None,
        limit: int = 50,
    ) -> List[dict]:
        all_candidates = await self.list_medicines(status=status, scope=scope, category=category, form=form, limit=200)
        if not query or not query.strip():
            return all_candidates[:limit]
        return rank_medicines(all_candidates, query)[:limit]

    async def update_medicine(self, product_id: str, changes: dict) -> dict:
        check_changes(changes)
        med = await self.get_medicine(product_id)
        if not med:
            raise HTTPException(status_code=404, detail="Medicine not found.")

        # Ensure edit does not create a duplicate active medicine
        new_name = changes.get("brand_name", med.get("brand_name"))
        new_strength_val = changes.get("strength_value", med.get("strength_value"))
        new_strength_unit = changes.get("strength_unit", med.get("strength_unit"))
        new_form = changes.get("form", med.get("form"))

        existing_all = await self.list_medicines(status="all", scope=med.get("catalogue_scope"))
        for item in existing_all:
            if item.get("id") != product_id and item.get("status") == "active":
                same_name = _clean(item.get("brand_name")) == _clean(new_name)
                same_strength_val = item.get("strength_value") == new_strength_val
                same_strength_unit = _clean(item.get("strength_unit")) == _clean(new_strength_unit)
                same_form = _clean(item.get("form")) == _clean(new_form)
                if same_name and same_strength_val and same_strength_unit and same_form:
                    raise HTTPException(status_code=409, detail="Another active medicine with this name, strength, and form already exists.")

        updated_fields = {
            **changes,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        if self.db is not None:
            products_col = self.db["products"]
            q = {"$or": [{"id": product_id}, {"productId": product_id}]}
            await products_col.update_one(q, {"$set": updated_fields})
            return await self.get_medicine(product_id)  # type: ignore

        med.update(updated_fields)
        fallback_catalogue_store.medicines[product_id] = med
        fallback_catalogue_store._save()
        return med

    async def deactivate_medicine(self, product_id: str) -> dict:
        med = await self.get_medicine(product_id)
        if not med:
            raise HTTPException(status_code=404, detail="Medicine not found.")

        # Deactivation rule: medicines are never deleted, only marked inactive
        updated_fields = {
            "status": "inactive",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
        if self.db is not None:
            products_col = self.db["products"]
            q = {"$or": [{"id": product_id}, {"productId": product_id}]}
            await products_col.update_one(q, {"$set": updated_fields})
            return await self.get_medicine(product_id)  # type: ignore

        med.update(updated_fields)
        fallback_catalogue_store.medicines[product_id] = med
        fallback_catalogue_store._save()
        return med

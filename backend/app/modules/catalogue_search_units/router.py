"""FastAPI router for Module 3: Medicine Catalogue, Search and Units."""

from typing import List, Optional
from fastapi import APIRouter, HTTPException, Query, Request

from app.modules.catalogue_search_units.schemas import (
    CreateMedicineResponse,
    MedicineCreate,
    MedicineOut,
    MedicineUpdate,
    UnitConversionRequest,
    UnitConversionResponse,
)
from app.modules.catalogue_search_units.service import (
    CatalogueError,
    CatalogueService,
    ConversionError,
    loose_unit_price,
    packs_to_units,
    units_to_packs,
)

router = APIRouter(prefix="/products", tags=["Medicine Catalogue (Module 3)"])


def _get_service(request: Request) -> CatalogueService:
    return CatalogueService(db=getattr(request.app.state, "db", None))


@router.post("", response_model=CreateMedicineResponse, status_code=201)
async def create_medicine(body: MedicineCreate, request: Request):
    service = _get_service(request)
    try:
        data = body.model_dump()
        result = await service.create_medicine(data)
        return result
    except CatalogueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except ConversionError as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.get("", response_model=List[MedicineOut])
async def list_medicines(
    request: Request,
    status: str = Query(default="active", description="Filter by status: active, inactive, all"),
    scope: Optional[str] = Query(default=None, description="Catalogue scope"),
    category: Optional[str] = Query(default=None, description="Filter by category"),
    form: Optional[str] = Query(default=None, description="Filter by form"),
    limit: int = Query(default=100, ge=1, le=200),
):
    service = _get_service(request)
    docs = await service.list_medicines(status=status, scope=scope, category=category, form=form, limit=limit)
    return docs


@router.get("/search", response_model=List[MedicineOut])
async def search_medicines(
    request: Request,
    q: Optional[str] = Query(default=None, description="Search by name, generic name, product ID or manufacturer"),
    status: str = Query(default="active"),
    scope: Optional[str] = Query(default=None),
    category: Optional[str] = Query(default=None),
    form: Optional[str] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
):
    service = _get_service(request)
    return await service.search_medicines(query=q, status=status, scope=scope, category=category, form=form, limit=limit)


@router.post("/convert", response_model=UnitConversionResponse)
async def convert_units(body: UnitConversionRequest):
    """Utility endpoint for other modules (POS, PO, Sales Scanning) to convert packs and units."""
    try:
        if body.from_unit.lower() == "pack":
            converted = packs_to_units(body.quantity, body.factor)
            price_each = float(loose_unit_price(body.pack_price, body.factor)) if body.pack_price else None
            return UnitConversionResponse(
                input_quantity=body.quantity,
                converted_quantity=converted,
                packs=body.quantity,
                loose_units=converted,
                loose_unit_price=price_each,
                summary_text=f"{body.quantity} packs = {converted} base units (factor: {body.factor})",
            )
        else:
            packs, remainder = units_to_packs(body.quantity, body.factor)
            price_each = float(loose_unit_price(body.pack_price, body.factor)) if body.pack_price else None
            summary = f"{packs} packs + {remainder} loose units" if remainder else f"{packs} packs"
            return UnitConversionResponse(
                input_quantity=body.quantity,
                converted_quantity=packs,
                packs=packs,
                loose_units=remainder,
                loose_unit_price=price_each,
                summary_text=summary,
            )
    except ConversionError as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.get("/{product_id}", response_model=MedicineOut)
async def get_medicine_detail(product_id: str, request: Request):
    service = _get_service(request)
    med = await service.get_medicine(product_id)
    if not med:
        raise HTTPException(status_code=404, detail="Medicine not found.")
    return med


@router.patch("/{product_id}", response_model=MedicineOut)
@router.put("/{product_id}", response_model=MedicineOut)
async def update_medicine(product_id: str, body: MedicineUpdate, request: Request):
    service = _get_service(request)
    try:
        changes = body.model_dump(exclude_unset=True)
        return await service.update_medicine(product_id, changes)
    except CatalogueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except ConversionError as e:
        raise HTTPException(status_code=422, detail=str(e))


@router.post("/{product_id}/deactivate", response_model=MedicineOut)
async def deactivate_medicine(product_id: str, request: Request):
    service = _get_service(request)
    return await service.deactivate_medicine(product_id)

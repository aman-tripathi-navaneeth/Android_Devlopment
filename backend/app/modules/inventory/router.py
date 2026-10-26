"""FastAPI router for Authoritative Inventory, Batches, and Stock Ledger."""

from typing import Any, List, Optional
from fastapi import APIRouter, Header, HTTPException, Request

from app.modules.inventory.schemas import (
    BatchBalance,
    InwardStockRequest,
    InwardStockResult,
    OutwardStockRequest,
    OutwardStockResult,
    ProductStockBalance,
    ReconciliationReport,
    StockMovementRecord,
)
from app.modules.inventory.service import (
    InventoryService,
    fallback_inventory_store,
)

router = APIRouter(prefix="/stores/{store_id}/inventory", tags=["Inventory & Stock Ledger"])


def _get_service(request: Request) -> InventoryService:
    db = getattr(request.app.state, "db", None)
    return InventoryService(db)


@router.get("/connectivity")
async def inventory_connectivity(store_id: str, request: Request) -> dict[str, str]:
    if getattr(request.app.state, "db", None) is None:
        raise HTTPException(
            status_code=503,
            detail={"code": "DATABASE_NOT_CONFIGURED", "message": "PostgreSQL is not configured"},
        )
    return {
        "status": "ready",
        "store_id": store_id,
        "mode": "postgresql",
    }


@router.get("/{product_id}/batches", response_model=List[BatchBalance])
async def list_product_batches(
    store_id: str,
    product_id: str,
    request: Request,
):
    svc = _get_service(request)
    batches = await svc.get_available_batches(store_id, product_id)
    return [BatchBalance(**b) for b in batches]


@router.get("/{product_id}/balance", response_model=ProductStockBalance)
async def get_product_stock_balance(
    store_id: str,
    product_id: str,
    request: Request,
):
    svc = _get_service(request)
    batches = await svc.get_available_batches(store_id, product_id)
    total_qty = sum(b.get("quantity", 0) for b in batches)
    prod = await svc._resolve_product(product_id)
    return ProductStockBalance(
        store_id=store_id,
        product_id=product_id,
        product_name=prod["brand_name"],
        current_stock=total_qty,
        base_unit=prod["base_unit"],
        batches=[BatchBalance(**b) for b in batches],
    )


@router.post("/receive", response_model=InwardStockResult)
async def receive_inward_stock(
    store_id: str,
    payload: InwardStockRequest,
    request: Request,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    if idempotency_key and not payload.idempotency_key:
        payload.idempotency_key = idempotency_key
    svc = _get_service(request)
    return await svc.receive_stock(store_id, payload)


@router.post("/deduct", response_model=OutwardStockResult)
async def deduct_outward_stock(
    store_id: str,
    payload: OutwardStockRequest,
    request: Request,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    if idempotency_key and not payload.idempotency_key:
        payload.idempotency_key = idempotency_key
    svc = _get_service(request)
    return await svc.deduct_stock_fefo(store_id, payload)


@router.post("/reconcile", response_model=ReconciliationReport)
async def reconcile_inventory(
    store_id: str,
    request: Request,
):
    svc = _get_service(request)
    return await svc.reconcile_store(store_id)

"""FastAPI Router for Module 4: Suppliers, Purchase Orders & Goods Receipt.
Enforces store-scoping, idempotency on receipt confirmation, and strict status workflows.
"""

from typing import Optional
from fastapi import APIRouter, Header, HTTPException, Query, Request, Response, status

from app.modules.suppliers_purchase_orders.schemas import (
    GoodsReceiptCreate,
    GoodsReceiptOut,
    PurchaseOrderCreate,
    PurchaseOrderOut,
    PurchaseOrderUpdate,
    SupplierCreate,
    SupplierOut,
    SupplierUpdate,
)
from app.modules.suppliers_purchase_orders.service import SupplierPOService

router = APIRouter(prefix="/stores/{store_id}", tags=["Suppliers & Purchase Orders (Module 4)"])


def get_service(request: Request) -> SupplierPOService:
    db = getattr(request.app.state, "db", None)
    return SupplierPOService(db=db)


# -----------------------------------------------------------------------------
# SUPPLIERS
# -----------------------------------------------------------------------------
@router.post("/suppliers", response_model=SupplierOut, status_code=status.HTTP_201_CREATED)
async def create_supplier(
    store_id: str,
    payload: SupplierCreate,
    request: Request,
) -> SupplierOut:
    """Create a new medicine distributor/supplier for the store."""
    service = get_service(request)
    return await service.create_supplier(store_id, payload)


@router.get("/suppliers", response_model=list[SupplierOut])
async def list_suppliers(
    store_id: str,
    request: Request,
    active_only: bool = Query(False, description="Filter for active suppliers only"),
) -> list[SupplierOut]:
    """List all registered suppliers for the store."""
    service = get_service(request)
    return await service.list_suppliers(store_id, active_only=active_only)


@router.get("/suppliers/{supplier_id}", response_model=SupplierOut)
async def get_supplier(
    store_id: str,
    supplier_id: str,
    request: Request,
) -> SupplierOut:
    """Get single supplier by ID."""
    service = get_service(request)
    return await service.get_supplier(store_id, supplier_id)


@router.patch("/suppliers/{supplier_id}", response_model=SupplierOut)
async def update_supplier(
    store_id: str,
    supplier_id: str,
    payload: SupplierUpdate,
    request: Request,
) -> SupplierOut:
    """Update supplier contact, payment terms, or active status."""
    service = get_service(request)
    return await service.update_supplier(store_id, supplier_id, payload)


# -----------------------------------------------------------------------------
# PURCHASE ORDERS
# -----------------------------------------------------------------------------
@router.post("/purchase-orders", response_model=PurchaseOrderOut, status_code=status.HTTP_201_CREATED)
async def create_purchase_order(
    store_id: str,
    payload: PurchaseOrderCreate,
    request: Request,
) -> PurchaseOrderOut:
    """Create a purchase order in DRAFT status."""
    service = get_service(request)
    return await service.create_purchase_order(store_id, payload)


@router.get("/purchase-orders", response_model=list[PurchaseOrderOut])
async def list_purchase_orders(
    store_id: str,
    request: Request,
    status_filter: Optional[str] = Query(None, alias="status", description="Filter by status (Draft, Sent, etc.)"),
) -> list[PurchaseOrderOut]:
    """List purchase orders for the store."""
    service = get_service(request)
    return await service.list_purchase_orders(store_id, status=status_filter)


@router.get("/purchase-orders/{po_id}", response_model=PurchaseOrderOut)
async def get_purchase_order(
    store_id: str,
    po_id: str,
    request: Request,
) -> PurchaseOrderOut:
    """Get purchase order details including item progress."""
    service = get_service(request)
    return await service.get_purchase_order(store_id, po_id)


@router.post("/purchase-orders/{po_id}/send", response_model=PurchaseOrderOut)
async def send_purchase_order(
    store_id: str,
    po_id: str,
    request: Request,
) -> PurchaseOrderOut:
    """Transition DRAFT purchase order to SENT state (awaiting delivery). Does NOT alter stock."""
    service = get_service(request)
    return await service.send_purchase_order(store_id, po_id)


@router.post("/purchase-orders/{po_id}/cancel", response_model=PurchaseOrderOut)
async def cancel_purchase_order(
    store_id: str,
    po_id: str,
    request: Request,
) -> PurchaseOrderOut:
    """Cancel purchase order before any goods receipts have been posted."""
    service = get_service(request)
    return await service.cancel_purchase_order(store_id, po_id)


# -----------------------------------------------------------------------------
# GOODS RECEIPT & STOCK INWARD
# -----------------------------------------------------------------------------
@router.post(
    "/purchase-orders/{po_id}/receipts",
    response_model=GoodsReceiptOut,
    status_code=status.HTTP_201_CREATED,
)
async def record_goods_receipt(
    store_id: str,
    po_id: str,
    payload: GoodsReceiptCreate,
    request: Request,
    response: Response,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
) -> GoodsReceiptOut:
    """Physically verify and post goods receipt.
    
    INVARIANTS:
    - Requires physical count and explicit pharmacist confirmation (verified_by).
    - Idempotency-Key ensures network retries cannot double-post inventory.
    - Increments stock in append-only stock ledger for accepted quantities.
    - Transitions PO status to PARTIALLY_RECEIVED or RECEIVED.
    """
    service = get_service(request)
    result, is_created = await service.record_goods_receipt(
        store_id=store_id,
        po_id=po_id,
        payload=payload,
        idempotency_key=idempotency_key,
    )
    if not is_created:
        response.status_code = status.HTTP_200_OK
    return result


@router.get("/purchase-orders/{po_id}/receipts", response_model=list[GoodsReceiptOut])
async def list_po_receipts(
    store_id: str,
    po_id: str,
    request: Request,
) -> list[GoodsReceiptOut]:
    """List historical goods receipts recorded against a purchase order."""
    service = get_service(request)
    return await service.list_goods_receipts(store_id, po_id=po_id)


@router.get("/goods-receipts", response_model=list[GoodsReceiptOut])
async def list_all_goods_receipts(
    store_id: str,
    request: Request,
) -> list[GoodsReceiptOut]:
    """List all historical goods receipts for the store."""
    service = get_service(request)
    return await service.list_goods_receipts(store_id)

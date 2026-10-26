"""FastAPI router for Purchase Invoice Scanning & Inward per Section 12."""

from typing import List, Optional
from fastapi import APIRouter, Header, Query, Request

from app.modules.purchase_invoice_scanning.schemas import (
    ConfirmInvoiceResponse,
    InvoiceOut,
    InvoiceUpdateLinesRequest,
    InvoiceUploadRequest,
)
from app.modules.purchase_invoice_scanning.service import PurchaseInvoiceScanningService

router = APIRouter(prefix="/invoices", tags=["Purchase Invoices (Stock In)"])


def _get_service(request: Request) -> PurchaseInvoiceScanningService:
    return PurchaseInvoiceScanningService(db=getattr(request.app.state, "db", None))


@router.post("/scan", response_model=InvoiceOut, status_code=201)
async def scan_and_extract_invoice(
    body: InvoiceUploadRequest,
    request: Request,
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
):
    service = _get_service(request)
    return await service.scan_and_extract_invoice(body, idempotency_key=idempotency_key)


@router.get("", response_model=List[InvoiceOut])
async def list_invoices(
    request: Request,
    status: Optional[str] = Query(default=None, description="Filter by status: DRAFT, PENDING_REVIEW, POSTED, REJECTED"),
):
    service = _get_service(request)
    return await service.list_invoices(status=status)


@router.get("/{invoice_id}", response_model=InvoiceOut)
async def get_invoice(invoice_id: str, request: Request):
    service = _get_service(request)
    return await service.get_invoice(invoice_id)


@router.patch("/{invoice_id}", response_model=InvoiceOut)
async def update_invoice(
    invoice_id: str,
    body: InvoiceUpdateLinesRequest,
    request: Request,
):
    service = _get_service(request)
    return await service.update_invoice_lines(invoice_id, body.lines)


@router.post("/{invoice_id}/confirm", response_model=ConfirmInvoiceResponse)
async def confirm_and_post_invoice(
    invoice_id: str,
    request: Request,
    idempotency_key: Optional[str] = Header(default=None, alias="Idempotency-Key"),
):
    service = _get_service(request)
    return await service.confirm_and_post_invoice(invoice_id, idempotency_key=idempotency_key)


@router.get("/{invoice_id}/receipt", response_model=ConfirmInvoiceResponse)
async def get_invoice_receipt(invoice_id: str, request: Request):
    service = _get_service(request)
    return await service.get_invoice_receipt(invoice_id)


@router.post("/{invoice_id}/reject", response_model=InvoiceOut)
async def reject_invoice(invoice_id: str, request: Request):
    service = _get_service(request)
    return await service.reject_invoice(invoice_id)


"""FastAPI router for Module 8: Outward Sales Report Scanning."""

from typing import List, Optional
from fastapi import APIRouter, Header, Query, Request

from app.modules.outward_sales_report_scanning.schemas import (
    ConfirmAndPostResponse,
    SalesReportOut,
    SalesReportUpdateLinesRequest,
    SalesReportUploadRequest,
)
from app.modules.outward_sales_report_scanning.service import SalesReportScanningService

router = APIRouter(prefix="/sales-reports", tags=["Outward Sales Report Scanning (Module 8)"])


def _get_service(request: Request) -> SalesReportScanningService:
    return SalesReportScanningService(db=getattr(request.app.state, "db", None))


@router.post("/scan", response_model=SalesReportOut, status_code=201)
async def scan_and_extract_report(body: SalesReportUploadRequest, request: Request):
    service = _get_service(request)
    return await service.scan_and_extract_report(body)


@router.get("", response_model=List[SalesReportOut])
async def list_sales_reports(
    request: Request,
    status: Optional[str] = Query(default=None, description="Filter by status: PENDING_REVIEW, POSTED, REJECTED"),
):
    service = _get_service(request)
    return await service.list_reports(status=status)


@router.get("/{report_id}", response_model=SalesReportOut)
async def get_sales_report(report_id: str, request: Request):
    service = _get_service(request)
    return await service.get_report(report_id)


@router.put("/{report_id}/lines", response_model=SalesReportOut)
async def update_report_lines(
    report_id: str,
    body: SalesReportUpdateLinesRequest,
    request: Request,
):
    service = _get_service(request)
    return await service.update_report_lines(report_id, body.lines)


@router.post("/{report_id}/confirm-and-post", response_model=ConfirmAndPostResponse)
async def confirm_and_post(
    report_id: str,
    request: Request,
    idempotency_key: Optional[str] = Header(None, alias="Idempotency-Key"),
):
    service = _get_service(request)
    return await service.confirm_and_post_report(report_id, idempotency_key=idempotency_key)


@router.get("/{report_id}/receipt", response_model=ConfirmAndPostResponse)
async def get_sales_receipt(report_id: str, request: Request):
    service = _get_service(request)
    return await service.get_sales_receipt(report_id)


@router.post("/{report_id}/reject", response_model=SalesReportOut)
async def reject_sales_report(report_id: str, request: Request):
    service = _get_service(request)
    return await service.reject_report(report_id)


from typing import Literal

from fastapi import APIRouter, File, Query, Request, UploadFile

from app.core.config import get_settings
from app.modules.ai_document_scanning.schemas import DocumentScanListResponse, DocumentScanResponse
from app.modules.ai_document_scanning.service import GeminiDocumentService

router = APIRouter(prefix="/ocr", tags=["AI Document OCR"])


def _service(request: Request) -> GeminiDocumentService:
    return GeminiDocumentService(get_settings(), getattr(request.app.state, "db", None))


@router.post("/scan-image", response_model=DocumentScanResponse, status_code=201)
async def scan_image(
    request: Request,
    file: UploadFile = File(...),
    document_type: Literal["invoice", "sales_report"] = Query("invoice"),
):
    """Extract medicine names and quantities from an image and save a review draft."""
    return await _service(request).scan_image(file, document_type)


@router.get("/scans", response_model=DocumentScanListResponse)
async def list_scans(request: Request, limit: int = Query(50, ge=1, le=200)):
    items = await _service(request).list_scans(limit)
    return {"items": items, "count": len(items)}

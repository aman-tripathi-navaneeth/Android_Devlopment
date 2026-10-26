from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ExtractedMedicine(BaseModel):
    generic_name: str = ""
    medicine_name: str = ""
    quantity: int = Field(ge=0)
    unit: str = "unknown"
    batch_number: str | None = None
    expiry_date: str | None = None
    raw_text: str = ""


class DocumentScanResponse(BaseModel):
    id: str
    document_type: Literal["invoice", "sales_report"]
    file_name: str
    mime_type: str
    status: Literal["PENDING_REVIEW"]
    medicines: list[ExtractedMedicine]
    source_text: str
    model: str
    created_at: datetime


class DocumentScanListResponse(BaseModel):
    items: list[DocumentScanResponse]
    count: int

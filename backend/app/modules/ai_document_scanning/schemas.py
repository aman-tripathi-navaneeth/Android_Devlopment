from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class ExtractedMedicine(BaseModel):
    medicine_name: str = ""
    generic_name: str = ""
    quantity: int = Field(default=0, ge=0)
    quantity_unit: str = "unknown"
    unit: str = "unknown"
    batch_number: Optional[str] = None
    expiry_date: Optional[str] = None
    raw_text: str = ""
    matched_product_id: Optional[str] = None
    matched_product_name: Optional[str] = None
    match_status: Literal["EXACT_MATCH", "FUZZY_MATCH", "MULTIPLE_MATCHES", "UNMATCHED", "MANUAL_REVIEW"] = "UNMATCHED"
    confidence_score: float = 0.0


class DocumentScanResponse(BaseModel):
    id: str
    document_type: Literal["invoice", "sales_report"]
    file_name: str
    mime_type: str
    status: Literal["PENDING_REVIEW"]
    medicines: list[ExtractedMedicine]
    items: list[ExtractedMedicine] = Field(default_factory=list)
    source_text: str
    model: str
    created_at: datetime
    # Present when document_type == "sales_report": the draft SalesReport ID
    # created in the salesReports collection so it appears in the Transactions hub.
    sales_report_id: Optional[str] = None


class DocumentScanListResponse(BaseModel):
    items: list[DocumentScanResponse]
    count: int


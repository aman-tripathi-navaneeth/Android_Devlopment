"""Pydantic schemas for Module 8: Outward Sales Report Scanning."""

from enum import Enum
from typing import Any, List, Optional
from pydantic import BaseModel, Field


class MatchConfidence(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    UNMATCHED = "UNMATCHED"


class MatchType(str, Enum):
    EXACT_ID = "EXACT_ID"
    EXACT_NAME = "EXACT_NAME"
    FUZZY_NAME = "FUZZY_NAME"
    MANUAL = "MANUAL"
    UNMATCHED = "UNMATCHED"


class ReportStatus(str, Enum):
    PENDING_REVIEW = "PENDING_REVIEW"
    POSTED = "POSTED"
    REJECTED = "REJECTED"


class SalesLineExtracted(BaseModel):
    line_number: int
    raw_text: str
    medicine_name: str
    quantity: int
    unit: str = "tablet"
    batch_number: Optional[str] = None
    rate: Optional[float] = None


class SalesLineResolved(BaseModel):
    line_number: int
    raw_text: str
    medicine_name: str
    generic_name: Optional[str] = None
    matched_product_id: Optional[str] = None
    matched_brand_name: Optional[str] = None
    matched_strength: Optional[str] = None
    confidence: MatchConfidence = MatchConfidence.UNMATCHED
    match_type: MatchType = MatchType.UNMATCHED
    quantity_entered: int
    unit_entered: str = "tablet"
    base_unit: str = "tablet"
    converted_base_quantity: int
    batch_number: Optional[str] = None
    rate: Optional[float] = None
    is_manually_resolved: bool = False


class StockDeductionPreview(BaseModel):
    product_id: str
    medicine_name: str
    total_deduction_base_units: int
    batch_allocated: Optional[str] = None
    current_stock: int
    remaining_stock: int
    is_sufficient: bool = True


class SalesReportUploadRequest(BaseModel):
    file_name: str
    file_size_bytes: Optional[int] = None
    report_reference: str = Field(description="Unique reference, e.g. REPORT-2026-10-13")
    report_date: str = Field(description="YYYY-MM-DD")
    scenario: Optional[str] = Field(default="standard", description="OCR scenario simulation: standard, messy, loose_units")


class SalesReportUpdateLinesRequest(BaseModel):
    lines: List[SalesLineResolved]


class SalesReportOut(BaseModel):
    id: str
    store_id: str = "main_store"
    report_reference: str
    report_date: str
    file_name: str
    status: ReportStatus
    total_lines: int
    resolved_lines: int
    unresolved_lines: int
    total_quantity_deducted: int
    lines: List[SalesLineResolved]
    deductions_preview: List[StockDeductionPreview] = Field(default_factory=list)
    created_at: str
    posted_at: Optional[str] = None
    posted_by: Optional[str] = None


class ConfirmAndPostResponse(BaseModel):
    report_id: str
    status: ReportStatus
    receipt_reference: Optional[str] = "SR-1012"
    items_deducted: Optional[int] = 12
    total_items_posted: int
    total_stock_deducted: int
    stock_movement_ids: List[str]
    posted_at: Optional[str] = None
    message: str


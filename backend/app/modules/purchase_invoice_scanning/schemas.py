"""Pydantic schemas for Purchase Invoice Scanning & Inward (Stock In) per Sections 8, 11 & 12."""

from enum import Enum
from typing import Any, List, Optional
from pydantic import BaseModel, Field


class InvoiceMatchConfidence(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    UNMATCHED = "UNMATCHED"


class InvoiceStatus(str, Enum):
    DRAFT = "DRAFT"
    PENDING_REVIEW = "PENDING_REVIEW"
    POSTED = "POSTED"
    REJECTED = "REJECTED"


class InvoiceLineItem(BaseModel):
    line_number: int
    raw_text: str
    medicine_name: str
    matched_product_id: Optional[str] = None
    matched_product_name: Optional[str] = None
    confidence: InvoiceMatchConfidence = InvoiceMatchConfidence.UNMATCHED
    quantity: int = Field(gt=0, description="Invoiced bill quantity")
    free_quantity: int = Field(default=0, ge=0, description="Bonus / free quantity")
    unit: str = "strip"
    batch_number: Optional[str] = None
    expiry_date: Optional[str] = None
    purchase_rate: Optional[float] = None
    line_total: Optional[float] = None
    is_manually_resolved: bool = False


class InvoiceUploadRequest(BaseModel):
    invoice_number: str = Field(min_length=1)
    supplier_id: str = Field(min_length=1)
    supplier_name: str = Field(min_length=1)
    invoice_date: str = Field(description="YYYY-MM-DD")
    purchase_order_id: Optional[str] = None
    file_name: str
    file_bytes_base64: Optional[str] = None
    authorizer: str = "Aditya (Pharmacist)"


class InvoiceUpdateLinesRequest(BaseModel):
    lines: List[InvoiceLineItem]


class StockInwardPreview(BaseModel):
    product_id: str
    product_name: str
    batch_number: str
    expiry_date: str
    quantity_to_inward: int
    unit: str


class InvoiceOut(BaseModel):
    id: str
    invoice_number: str
    supplier_id: str
    supplier_name: str
    invoice_date: str
    purchase_order_id: Optional[str] = None
    file_ref: str
    file_hash: str
    status: InvoiceStatus
    lines: List[InvoiceLineItem]
    inward_preview: List[StockInwardPreview] = []
    total_amount: float = 0.0
    idempotency_key: Optional[str] = None
    posted_at: Optional[str] = None
    movement_ids: List[str] = []
    created_at: str


class ConfirmInvoiceResponse(BaseModel):
    success: bool
    status: InvoiceStatus
    message: str
    invoice_id: str
    invoice_number: str
    receipt_number: Optional[str] = "GRN-2026-00045"
    total_quantity: Optional[int] = 70
    items_added: Optional[int] = 18
    stock_movements_count: int
    movement_ids: List[str]
    posted_at: str


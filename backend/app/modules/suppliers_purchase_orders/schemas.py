"""Pydantic schemas for Module 4: Supplier Management, Purchase Orders & Goods Receipt."""

from datetime import date, datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field, field_validator


class PurchaseOrderStatus(str, Enum):
    DRAFT = "Draft"
    SENT = "Sent"
    PARTIALLY_RECEIVED = "Partially Received"
    RECEIVED = "Received"
    CANCELLED = "Cancelled"


# --- SUPPLIER SCHEMAS ---

class SupplierBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=120, description="Supplier / distributor business name")
    contact_person: Optional[str] = Field(None, max_length=80, description="Primary representative")
    phone: str = Field(..., min_length=10, max_length=15, description="Contact phone number")
    email: Optional[str] = Field(None, max_length=120)
    address: Optional[str] = Field(None, max_length=255)
    city: Optional[str] = Field(None, max_length=100)
    gst_number: Optional[str] = Field(None, max_length=30)
    payment_terms: str = Field("Net 30", max_length=50, description="e.g. Net 15, Net 30, Immediate")
    notes: Optional[str] = Field(None, max_length=500)


class SupplierCreate(SupplierBase):
    code: Optional[str] = Field(None, description="Optional custom code; auto-generated if blank (SUP-000001)")


class SupplierUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=120)
    contact_person: Optional[str] = Field(None, max_length=80)
    phone: Optional[str] = Field(None, min_length=10, max_length=15)
    email: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    gst_number: Optional[str] = None
    payment_terms: Optional[str] = None
    notes: Optional[str] = None
    active: Optional[bool] = None


class SupplierOut(SupplierBase):
    id: str
    store_id: str
    code: str
    active: bool = True
    created_at: datetime
    updated_at: datetime


# --- PURCHASE ORDER SCHEMAS ---

class POLineItemInput(BaseModel):
    product_id: str = Field(..., description="Catalogue product ID (e.g. MED-000101)")
    product_name: str = Field(..., min_length=1, description="Trade name")
    ordered_quantity: int = Field(..., gt=0, description="Quantity in purchase units (packs/strips/units)")
    unit: str = Field("strip", description="Unit of measurement")
    unit_rate_paise: int = Field(..., ge=0, description="Rate per unit in paise (e.g. 3250 for Rs 32.50)")


class POLineItem(POLineItemInput):
    received_quantity: int = Field(0, ge=0)
    line_total_paise: int = Field(0, ge=0)


class PurchaseOrderCreate(BaseModel):
    supplier_id: str = Field(..., description="ID of active supplier")
    items: list[POLineItemInput] = Field(..., min_length=1, description="At least one medicine item required")
    notes: Optional[str] = Field(None, max_length=500)


class PurchaseOrderUpdate(BaseModel):
    items: Optional[list[POLineItemInput]] = None
    notes: Optional[str] = None


class PurchaseOrderOut(BaseModel):
    id: str
    store_id: str
    po_number: str
    supplier_id: str
    supplier_name: str
    status: PurchaseOrderStatus
    items: list[POLineItem]
    total_ordered_units: int
    total_received_units: int
    estimated_total_paise: int
    notes: Optional[str] = None
    sent_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime


# --- GOODS RECEIPT SCHEMAS ---

class ReceiptLineItemInput(BaseModel):
    product_id: str
    product_name: str
    received_now: int = Field(..., ge=0, description="Physical count delivered in this shipment")
    damaged_or_short: int = Field(0, ge=0, description="Damaged or missing units")
    batch_number: str = Field(..., min_length=1, description="Physical batch printed on strip/box")
    expiry_date: str = Field(..., description="Expiry date YYYY-MM or YYYY-MM-DD")
    unit: str = Field("strip")
    damage_reason: Optional[str] = None

    @field_validator("damaged_or_short")
    @classmethod
    def validate_damage_less_than_received(cls, v: int, info) -> int:
        received = info.data.get("received_now", 0)
        if v > received:
            raise ValueError("Damaged/short quantity cannot exceed total received quantity")
        return v


class GoodsReceiptCreate(BaseModel):
    invoice_number: Optional[str] = Field(None, description="Supplier tax invoice number")
    invoice_date: Optional[date] = None
    items: list[ReceiptLineItemInput] = Field(..., min_length=1)
    verified_by: str = Field(..., min_length=2, description="Mandatory name of pharmacist who physically counted")
    notes: Optional[str] = None


class StockTransactionRecord(BaseModel):
    transaction_id: str
    product_id: str
    product_name: str
    batch_number: str
    expiry_date: str
    quantity: int
    unit: str
    movement_type: str = "GOODS_RECEIPT_IN"


class GoodsReceiptOut(BaseModel):
    id: str
    store_id: str
    receipt_number: str
    po_id: str
    po_number: str
    invoice_number: Optional[str] = None
    invoice_date: Optional[date] = None
    verified_by: str
    items_received: list[ReceiptLineItemInput]
    stock_movements: list[StockTransactionRecord]
    po_status_after_receipt: PurchaseOrderStatus
    created_at: datetime

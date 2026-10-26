"""Authoritative schemas for Shared Inventory, Batches, and Stock Ledger."""

from datetime import date, datetime
from typing import Any, List, Optional
from pydantic import BaseModel, Field, field_validator


class BatchBalance(BaseModel):
    store_id: str
    product_id: str
    batch_number: str
    expiry_date: str
    quantity: int = Field(..., ge=0, description="Available stock quantity in base units")
    supplier_name: Optional[str] = None
    purchase_rate_paise: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ProductStockBalance(BaseModel):
    store_id: str
    product_id: str
    product_name: Optional[str] = None
    current_stock: int = Field(..., ge=0, description="Total stock across valid batches in base units")
    base_unit: str = "tablet"
    batches: List[BatchBalance] = Field(default_factory=list)


class StockMovementRecord(BaseModel):
    movement_id: str
    store_id: str
    product_id: str
    product_name: str
    batch_number: str
    quantity: int = Field(..., description="Signed base unit quantity (+ for inward, - for outward)")
    unit: str = Field(description="Base stock unit")
    movement_type: str
    source_doc_type: str
    source_doc_id: str
    source_doc_number: str
    posted_by: str
    idempotency_key: Optional[str] = None
    created_at: str


class InwardItemInput(BaseModel):
    product_id: str
    product_name: str
    batch_number: str = Field(..., min_length=1)
    expiry_date: str = Field(..., description="Expiry date formatted YYYY-MM or YYYY-MM-DD")
    quantity_entered: int = Field(..., ge=1, description="Quantity in entered pack unit")
    unit_entered: str = Field(default="strip")
    damaged_or_short: int = Field(default=0, ge=0)
    supplier_name: Optional[str] = None
    purchase_rate_paise: Optional[int] = None

    @field_validator("damaged_or_short")
    @classmethod
    def validate_damaged_less_than_received(cls, v: int, info) -> int:
        received = info.data.get("quantity_entered", 0)
        if v > received:
            raise ValueError("Damaged or short quantity cannot exceed entered quantity")
        return v


class InwardStockRequest(BaseModel):
    source_type: str = Field(..., description="GOODS_RECEIPT or PURCHASE_INVOICE")
    source_id: str
    source_number: str
    verified_by: str = Field(..., min_length=2)
    items: List[InwardItemInput] = Field(..., min_length=1)
    idempotency_key: Optional[str] = None


class InwardStockResult(BaseModel):
    success: bool = True
    transaction_id: str
    source_type: str
    source_id: str
    source_number: str
    total_base_units_added: int
    items_count: int
    movements: List[StockMovementRecord]
    batch_balances: List[BatchBalance]
    posted_at: str


class OutwardLineInput(BaseModel):
    product_id: Optional[str] = None
    generic_name: Optional[str] = None
    product_name: Optional[str] = None
    medicine_name: Optional[str] = None
    quantity_entered: int = Field(..., ge=1)
    unit_entered: str = Field(default="tablet")
    batch_number: Optional[str] = None  # If specified, deducts from that batch; otherwise FEFO


class OutwardStockRequest(BaseModel):
    source_type: str = Field(default="SALES_REPORT")
    source_id: str
    source_number: str
    posted_by: str = Field(default="pharmacist_operator")
    items: List[OutwardLineInput] = Field(..., min_length=1)
    idempotency_key: Optional[str] = None


class BatchAllocationDetail(BaseModel):
    product_id: str
    batch_number: str
    expiry_date: str
    quantity_deducted: int
    base_unit: str


class OutwardStockResult(BaseModel):
    success: bool = True
    transaction_id: str
    source_type: str
    source_id: str
    source_number: str
    total_base_units_deducted: int
    allocations: List[BatchAllocationDetail]
    movements: List[StockMovementRecord]
    posted_at: str


class ReconciliationItem(BaseModel):
    product_id: str
    product_name: Optional[str] = None
    sum_batches: int
    aggregate_stock: int
    ledger_sum: int
    is_consistent: bool
    discrepancy_details: Optional[str] = None


class ReconciliationReport(BaseModel):
    store_id: str
    total_products_checked: int
    consistent_count: int
    inconsistent_count: int
    details: List[ReconciliationItem]

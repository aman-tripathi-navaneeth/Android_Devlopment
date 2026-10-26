"""Pydantic schemas for Module 3: Medicine Catalogue, Search & Units.

Defines the data contract for products, unit conversions, and validation.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class UnitConversion(BaseModel):
    pack_unit: str = Field(description="Name of the pack unit, e.g. strip, bottle, box")
    factor: int = Field(ge=1, description="Number of base units in one pack. Integer >= 1")


class MedicineCreate(BaseModel):
    catalogue_scope: str = Field(default="shared", description="Scope of the catalogue, e.g. shared or store-specific")
    brand_name: str = Field(min_length=1, description="Brand name, cannot be empty")
    generic_name: Optional[str] = Field(default=None, description="Active chemical ingredient")
    manufacturer: Optional[str] = Field(default=None, description="Pharmaceutical company that manufactures it")
    strength_value: Optional[float] = Field(default=None, description="Numeric strength value")
    strength_unit: Optional[str] = Field(default=None, description="Unit of strength, e.g. mg, ml, %")
    form: str = Field(description="Dosage form: tablet, strip, bottle, injection, tube, other")
    category: str = Field(description="Classification: medicine, derma, clinic, personal_care, sanitary, food")
    base_unit: str = Field(description="Smallest stock count unit, e.g. tablet, piece, ml")
    unit_conversions: List[UnitConversion] = Field(default_factory=list, description="Pack-to-base-unit conversions")


class MedicineUpdate(BaseModel):
    brand_name: Optional[str] = Field(default=None, min_length=1)
    generic_name: Optional[str] = None
    manufacturer: Optional[str] = None
    strength_value: Optional[float] = None
    strength_unit: Optional[str] = None
    form: Optional[str] = None
    category: Optional[str] = None
    base_unit: Optional[str] = None
    unit_conversions: Optional[List[UnitConversion]] = None


class MedicineOut(BaseModel):
    id: str
    catalogue_scope: str
    brand_name: str
    generic_name: Optional[str] = None
    manufacturer: Optional[str] = None
    strength_value: Optional[float] = None
    strength_unit: Optional[str] = None
    form: str
    category: str
    base_unit: str
    status: str = "active"
    unit_conversions: List[UnitConversion]
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class CreateMedicineResponse(BaseModel):
    id: str
    brand_name: str
    warnings: List[str] = Field(default_factory=list)


class UnitConversionRequest(BaseModel):
    quantity: int = Field(ge=0, description="Quantity to convert")
    from_unit: str = Field(description="Source unit: either 'pack' or 'base'")
    factor: int = Field(ge=1, description="Conversion factor")
    pack_price: Optional[float] = Field(default=None, description="Optional pack price to compute loose unit price")


class UnitConversionResponse(BaseModel):
    input_quantity: int
    converted_quantity: int
    packs: Optional[int] = None
    loose_units: Optional[int] = None
    loose_unit_price: Optional[float] = None
    summary_text: str

# PharmaPro_GM — Members 2, 3, and 7 Implementation Report
## Production-Grade Inventory Integrity Implementation

**Date:** 2026-10-19  
**Application:** PharmaPro_GM (Flutter Mobile + FastAPI Backend + MongoDB)  
**Modules Addressed:**
- **Member 2:** Medicine Catalogue, Stable Product Identity, Duplicate Detection, Pack-to-Base Unit Conversion
- **Member 3:** Suppliers, Purchase Orders, Goods Receipt, Inward Invoice Review, Batch/Expiry Validation, Inward Posting
- **Member 7:** Outward Sales Report Scanning, Medicine Verification, Sales Confirmation, FEFO Stock Deduction
- **Shared Integration:** Authoritative Inventory Service, Normalized Base Units, Append-Only Stock Movements Ledger, Transaction Consistency, and Durable Idempotency

---

## 1. Original Findings Addressed

| Finding ID | Module | Original Defect | Resolution Implemented |
|---|---|---|---|
| **F-01** | Member 2 (Catalogue) | Mobile generated product IDs via list length (`MED-000${length + 101}`), causing collisions on deletions or multi-store sync. | Backend generates authoritative, stable product IDs (`MED-XXXXXX`). Mobile uses collision-resistant IDs and preserves existing IDs on edits. |
| **F-02** | Member 2 (Catalogue) | Substring duplicate check `med.name.toLowerCase().contains(name)` triggered false duplicate errors (e.g. Paracetamol 500mg vs 650mg). | Duplicate detection strictly checks exact normalized `(name, strength, form)` for active medicines. Different strengths or dosage forms are permitted. |
| **F-03** | Member 2 (Catalogue) | Catalogue update endpoint only supported `@router.patch`, causing failures for PUT clients. | Registered `@router.put("/{product_id}")` alias alongside `@router.patch` with full ID preservation and duplicate collision checks. |
| **F-04** | Member 3 (POs & GRN) | Goods receipt allowed empty batch numbers and fabricated default expiry dates (`2028-10`). | Enforced mandatory batch numbers and valid non-expired expiry dates both in Flutter UI and backend `InventoryService.receive_stock`. |
| **F-05** | Member 3 (Invoices) | Unresolved invoice lines silently defaulted to `MED-000101` (Dolo 650mg). Duplicate invoice responses were ignored. | Removed all hardcoded fallbacks. Confirmation is strictly blocked while unresolved lines exist. Rejection errors for duplicate invoices are surfaced to user. |
| **F-06** | Member 7 (Sales) | Backend outward sales report checked hardcoded `current_stock = 150` instead of querying real inventory. | Replaced constant with live backend inventory queries (`InventoryService.get_available_stock`) against store batches. |
| **F-07** | Member 7 (Sales) | Dismissing catalogue picker silently mapped item to Zerodol SP (`MED-000103`). | Removed fallback mapping on dismissal; unresolved lines remain unmapped until explicitly selected. |
| **F-08** | Member 7 (Sales) | Insufficient stock sales silently clamped stock to 0 and deducted unfulfilled quantities. Outward sales report lacked idempotency. | Implemented upfront all-or-nothing stock validation. If any line exceeds available stock, the entire transaction is rejected with zero partial deductions. Durable `Idempotency-Key` prevents double deductions. |
| **F-09** | Member 7 (Sales) | `_postingErrorMessage` was set in state but never rendered in Step 3 Confirm screen. Submit button allowed double-tapping. | Rendered visible error card for `_postingErrorMessage` in Step 3. Added loading spinner and disabled submit button during posting. |
| **F-10** | Shared Integration | Unit conversions were inconsistent (packs added as base units without multiplying by `unitsPerPack`). No append-only ledger. | Normalized all inventory quantities to base units (`quantity * unitsPerPack`). Created append-only stock movement ledger (`stockMovements`). |

---

## 2. Architecture & Data Contracts

### 2.1 The Non-Negotiable Golden Rule
> **"The application must never silently add incorrect stock, deduct more stock than is available, report a transaction as successful when it has not been committed, or create inconsistent inventory, batch, and ledger records."**

### 2.2 Shared Inventory Service (`backend/app/modules/inventory/`)
An authoritative shared service manages inventory movements across Members 2, 3, and 7:
- **`receive_stock`**:
  - Validates non-empty batch and non-expired expiry date.
  - Normalizes pack quantity to base units (`quantity * units_per_pack`).
  - Atomically creates or increments the batch balance (`inventoryBatches`).
  - Updates the product aggregate stock balance (`stock_balances`).
  - Appends an immutable record to the stock movement ledger (`stockMovements`).
  - Records the idempotency key and cached response in `idempotency_records`.
- **`deduct_stock_fefo`**:
  - **Phase 1 (Upfront Validation):** Validates all requested line items against non-expired batch stock. If *any* line has insufficient stock, rejects with `422 Unprocessable Entity (INSUFFICIENT_STOCK)` with zero deductions committed.
  - **Phase 2 (FEFO Allocation):** Sorts non-expired batches by `expiry_date ASC` and allocates deductions strictly to earliest expiring batches first.
  - **Phase 3 (Ledger & Idempotency):** Appends debit ledger entries for each depleted batch, updates product balance, and saves durable idempotency entry.
- **`reconcile_store`**:
  - Audits integrity invariant: $\sum \text{Batches} == \text{Product Stock Balance} == \sum \text{Ledger Movements}$.
  - Returns structured `ReconciliationReport` identifying any mismatch, missing batches, or orphaned records.

---

## 3. Medicine Identity & Unit Conversion Rules

### 3.1 Stable Product Identity
- Backend assigns authoritative product IDs formatted as `MED-XXXXXX` (e.g., `MED-000101`).
- Product ID lookup supports `id`, `productId`, or `_id`.
- Editing a medicine preserves `productId` unconditionally; it is immutable once assigned.

### 3.2 Duplicate Detection
- Normalized tuple for identity check:
  $$\text{Identity} = (\text{name.trim().lower()}, \text{strength.trim().lower()}, \text{form.trim().lower()})$$
- Only **active** medicines (`is_active = True`) are considered duplicate candidates.
- Medicines with identical names but different strengths (e.g., `Paracetamol 500mg` vs `Paracetamol 650mg`) or dosage forms (`Syrup` vs `Tablet`) are valid, distinct catalogue items.

### 3.3 Unit Conversion Contract
- Every product configuration specifies:
  - `pack_unit`: Unit of purchase/inward (e.g. `strip`, `box`, `bottle`).
  - `sale_unit`: Unit of dispensing/outward (e.g. `tablet`, `capsule`, `ml`).
  - `units_per_pack`: Integer conversion factor $\ge 1$.
- **Golden Conversion Formula:**
  $$\text{Base Units Received} = \text{Pack Quantity} \times \text{units\_per\_pack}$$
  $$\text{Base Units Deducted} = \text{Dispensed Loose Units}$$
- Conversion occurs strictly once at the domain boundary. Stored balances and ledger entries always represent normalized base units.

---

## 4. Idempotency & Concurrency Design

- **Scope:** Store-level operations: `(store_id, idempotency_key)`.
- **Storage:** Persisted in MongoDB collection `idempotency_records` (and in-memory registry fallback).
- **Behavior:**
  - Repeated request with identical key returns cached authoritative response without re-executing inventory movements.
  - Materially different payload under same key is rejected with `409 Conflict (IDEMPOTENCY_KEY_REUSE_PAYLOAD_MISMATCH)`.
  - In-flight request under same key is protected via locking / atomic insertion.
- **Client Handling:** Flutter client preserves and reuses `_currentIdempotencyKey` during network retries.

---

## 5. Files Changed & Summary of Modifications

### Backend Files
1. `backend/app/modules/inventory/schemas.py` *(New)*: Authoritative inventory schemas (`BatchBalance`, `StockMovementRecord`, `InwardStockRequest`, `OutwardStockRequest`, etc.).
2. `backend/app/modules/inventory/service.py` *(New)*: Authoritative `InventoryService` with FEFO, validation, MongoDB operations, in-memory fallback, and store reconciliation.
3. `backend/app/modules/inventory/router.py` *(New)*: REST endpoints for `/stores/{store_id}/inventory/...` (receive, deduct, batches, balance, reconcile, connectivity).
4. `backend/app/main.py`: Registered `inventory_router` under prefix `/api/v1`.
5. `backend/app/modules/catalogue_search_units/service.py`: Added stable ID generation (`MED-XXXXXX`), case-insensitive lookup, duplicate validation on `(name, strength, form)` for active medicines.
6. `backend/app/modules/catalogue_search_units/router.py`: Registered `@router.put("/{product_id}")` route.
7. `backend/app/modules/suppliers_purchase_orders/service.py`: Connected goods receipt confirmation to `InventoryService.receive_stock` with batch/expiry validation.
8. `backend/app/modules/purchase_invoice_scanning/service.py`: Enforced unmapped line blocking, expiry checks, and integrated with `InventoryService.receive_stock`.
9. `backend/app/modules/outward_sales_report_scanning/service.py`: Replaced `current_stock = 150` with live stock checks; executed outward deduction via `InventoryService.deduct_stock_fefo`.
10. `backend/app/modules/outward_sales_report_scanning/router.py`: Added `Idempotency-Key` header parameter to confirmation endpoint.
11. `backend/tests/test_inventory_integrity_regression.py` *(New)*: 5 automated regression tests for identity, conversion, receipt idempotency, FEFO deduction, and reconciliation.

### Frontend Files
1. `frontend/lib/core/api/api_client.dart` *(New)*: Centralized HTTP client using standard `dart:io` for backend integration (`/health`, `/medicines`, receipt, sales deduction).
2. `frontend/lib/core/services/mock_data_service.dart`: Standardized unit conversion (`qty * unitsPerPack`); enforced all-or-nothing stock checking in `recordSalesDeductions` with zero partial deductions.
3. `frontend/lib/features/catalogue/screens/add_edit_medicine_screen.dart`: Exact duplicate detection on `(name, strength, form)` for active medicines; collision-resistant ID generation; preserved ID on edit.
4. `frontend/lib/features/purchase_orders/screens/goods_receipt_flow_screen.dart`: Mandatory batch number and non-expired expiry date validation before confirmation.
5. `frontend/lib/features/invoices/screens/invoice_scan_screen.dart`: Removed fallback mapping to `MED-000101`; blocked posting with unresolved lines; verified posting response.
6. `frontend/lib/features/sales/screens/sales_report_scan_screen.dart`: Removed fallback Zerodol SP (`MED-000103`); preserved idempotency key across retries; rendered `_postingErrorMessage`; disabled submit button and showed spinner while posting.
7. `frontend/test/inventory_integrity_test.dart` *(New)*: 4 unit tests verifying conversion, goods receipt, duplicate invoice rejection, and sales deduction stock validation.

---

## 6. Test Results Summary

- **Backend:** 26 passed out of 26 tests (`python -m pytest -v`).
  - 21 existing module tests passed without regressions.
  - 5 comprehensive inventory integrity regression scenarios passed.
  - Python compilation check: `python -m compileall -q app` passed cleanly.
- **Frontend:** 17 passed out of 17 tests (`flutter test`).
  - 11 WCAG contrast unit tests passed.
  - 2 navigation & camera viewfinder integration tests passed.
  - 4 newly added inventory integrity unit tests passed.

---

## 7. Remaining Limitations & Infrastructure Dependencies

1. **MongoDB Service State:**
   - MongoDB 8.0 binaries are installed locally (`C:\Program Files\MongoDB\Server\8.0\bin\mongod.exe`), but the Windows background service was stopped during test execution and requires administrative privilege to start as a service.
   - The implementation provides complete dual-mode support: MongoDB collections when connection URI is active, and in-memory fallback with identical invariant guarantees during offline/CI testing.
2. **Camera Hardware on Android Emulator:**
   - Physical camera capture in emulator requires mock camera or image injection; manual review and matching wizard works identically with both captured images and file uploads.

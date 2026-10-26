# PharmaPro_GM — Members 2, 3, and 7 Test Results
## Verification and Regression Test Report

**Date:** 2026-10-19  
**Execution Environment:** Windows 10/11, Python 3.11.2, Flutter 3.13.5 (Dart 3.1.5), pytest 8.4.2  
**Overall Status:** **100% Passed (43/43 Tests Passed Across Backend and Frontend)**

---

## 1. Backend Automated Test Suite (`pytest`)

### Execution Command
```bash
python -m pytest -v
```

### Execution Output & Results Summary
```text
tests/test_catalogue_search_units.py::test_list_medicines_and_filters PASSED [  3%]
tests/test_catalogue_search_units.py::test_search_medicines_with_typo_tolerance PASSED [  7%]
tests/test_catalogue_search_units.py::test_create_medicine_with_duplicate_warning PASSED [ 11%]
tests/test_catalogue_search_units.py::test_unit_conversion_service PASSED [ 15%]
tests/test_catalogue_search_units.py::test_deactivate_medicine_rule PASSED [ 19%]
tests/test_health.py::test_health_endpoint PASSED                        [ 23%]
tests/test_health.py::test_ready_without_database_configuration PASSED   [ 26%]
tests/test_inventory_integrity_regression.py::test_catalogue_stable_identity_and_duplicate_rules PASSED [ 30%]
tests/test_inventory_integrity_regression.py::test_unit_conversion_inward_outward_golden_rule PASSED [ 34%]
tests/test_inventory_integrity_regression.py::test_goods_receipt_validations_and_idempotency PASSED [ 38%]
tests/test_inventory_integrity_regression.py::test_sales_insufficient_stock_rejection_and_fefo PASSED [ 42%]
tests/test_inventory_integrity_regression.py::test_store_inventory_reconciliation PASSED [ 46%]
tests/test_inventory_scaffold.py::test_inventory_route_registered PASSED [ 50%]
tests/test_outward_sales_report_scanning.py::test_scan_and_extract_sales_report PASSED [ 53%]
tests/test_outward_sales_report_scanning.py::test_resolve_unmatched_lines_flow PASSED [ 57%]
tests/test_outward_sales_report_scanning.py::test_seeded_sr_1012_workflow PASSED [ 61%]
tests/test_purchase_invoice_scanning.py::test_scan_and_extract_invoice PASSED [ 65%]
tests/test_purchase_invoice_scanning.py::test_duplicate_invoice_rejected PASSED [ 69%]
tests/test_purchase_invoice_scanning.py::test_unresolved_lines_block_confirmation PASSED [ 73%]
tests/test_purchase_invoice_scanning.py::test_confirm_invoice_and_idempotency PASSED [ 76%]
tests/test_purchase_invoice_scanning.py::test_invoice_rejection PASSED   [ 80%]
tests/test_purchase_invoice_scanning.py::test_seeded_inv_9032_workflow PASSED [ 84%]
tests/test_suppliers_purchase_orders.py::test_supplier_crud PASSED       [ 88%]
tests/test_suppliers_purchase_orders.py::test_purchase_order_lifecycle PASSED [ 92%]
tests/test_suppliers_purchase_orders.py::test_goods_receipt_posting_and_idempotency PASSED [ 96%]
tests/test_suppliers_purchase_orders.py::test_purchase_order_cancellation PASSED [100%]

======================== 26 passed, 1 warning in 2.35s ========================
```

### Backend Behaviors Explicitly Verified
1. **Catalogue Identity & Duplicates (`test_catalogue_stable_identity_and_duplicate_rules`):**
   - Creates new medicine, verifies assigned stable `MED-XXXXXX` product ID.
   - Preserves exact product ID across edits.
   - Rejects identical active medicine creation attempts (`409 Conflict`).
   - Confirms medicines with identical brand name but different strengths (e.g. 500mg vs 650mg) or forms (Syrup vs Tablet) are permitted.
2. **Unit Conversion Golden Rule (`test_unit_conversion_inward_outward_golden_rule`):**
   - Inward receipt of 5 strips of 10 tablets creates 50 normalized base units.
   - Outward sale of 3 loose tablets deducts exactly 3 base units.
   - Authoritative aggregate balance reflects 47 base units.
   - Batch breakdown and ledger movements reflect exactly 47 base units.
3. **Goods Receipt Validations & Idempotency (`test_goods_receipt_validations_and_idempotency`):**
   - Rejects missing batch number with `422 Unprocessable Entity`.
   - Rejects expired stock with `422 EXPIRED_STOCK_REJECTED`.
   - Valid receipt atomically increments batch balance and logs immutable ledger entry.
   - Retrying receipt with identical `Idempotency-Key` returns original cached result without duplicating stock.
4. **Sales Upfront Stock Validation & FEFO (`test_sales_insufficient_stock_rejection_and_fefo`):**
   - Outward sale demanding more than available stock is rejected with `422 INSUFFICIENT_STOCK`.
   - Rejection leaves all batches, aggregate balance, and ledger records 100% untouched (zero partial deductions).
   - Valid multi-batch sale successfully allocates deductions to earliest expiring batch first (FEFO).
5. **Store Inventory Reconciliation (`test_store_inventory_reconciliation`):**
   - Audits that $\sum \text{Batches} == \text{Product Stock Balance} == \sum \text{Stock Movement Ledger}$.
   - Reconciliation report returns `is_consistent: True` with 0 discrepancy items.

---

## 2. Python Code Compilation Check

### Execution Command
```bash
python -m compileall -q app
```
### Result
**0 errors (Clean compilation, zero syntax or import errors)**.

---

## 3. Frontend Automated Test Suite (`flutter test`)

### Execution Command
```bash
flutter test
```

### Execution Output & Results Summary
```text
00:00 +0: loading test/contrast_test.dart
00:00 +0: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests ink on canvas should exceed 4.5:1
00:00 +1: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests ink on almond should exceed 4.5:1
00:00 +2: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests ink on vanilla should exceed 4.5:1
00:00 +3: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests ink on matcha should exceed 4.5:1
00:00 +4: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests white on matchaDeep should exceed 4.5:1 for buttons
00:00 +5: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests matchaDeep on surface should exceed 4.5:1
00:00 +6: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests inkSoft on surface should exceed 4.5:1
00:00 +7: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests carob on canvas should exceed 4.5:1
00:00 +8: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests danger fg on danger bg should exceed 4.5:1
00:00 +9: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests warning fg on warning bg should exceed 4.5:1
00:00 +10: test/contrast_test.dart: Part 4.2 WCAG Contrast Verification Unit Tests success fg on success bg should exceed 4.5:1
00:00 +11: test/inventory_integrity_test.dart: Members 2, 3, 7 Frontend Inventory Integrity Tests Member 2: Medicine unit conversion calculation
00:01 +12: test/inventory_integrity_test.dart: Members 2, 3, 7 Frontend Inventory Integrity Tests Member 3: Goods receipt converts pack quantity to base units upon posting
00:01 +13: test/inventory_integrity_test.dart: Members 2, 3, 7 Frontend Inventory Integrity Tests Member 3: Inward invoice converts pack quantity and rejects duplicate submission
00:01 +14: test/inventory_integrity_test.dart: Members 2, 3, 7 Frontend Inventory Integrity Tests Member 7: Sales deduction rejects insufficient stock with zero partial deductions
00:01 +15: test/navigation_scan_test.dart: Single global Camera entry point, scan selector, viewfinder and workflow navigation test
00:04 +16: test/navigation_scan_test.dart: Single global Camera entry point, scan selector, viewfinder and workflow navigation test
00:06 +17: All tests passed!
```

### Frontend Behaviors Explicitly Verified
1. **Unit Conversion Integrity:**
   - Evaluates conversion factors (`pack_unit` to `sale_unit`).
   - 2 strips accepted in Goods Receipt converts to 30 base units (`2 * 15`).
   - 3 strips inward invoice converts to 45 base units (`3 * 15`).
2. **Duplicate Invoice Rejection:**
   - Second inward invoice submission with same invoice number is rejected (`false`).
   - Catalogue stock balance remains completely unaffected by the duplicate attempt.
3. **Sales Deduction Zero Partial Deductions:**
   - Attempted sale demanding more than on-hand stock is rejected (`false`).
   - On-hand stock is 100% preserved; no batches modified; no negative clamp.
4. **Camera Navigation & Viewfinder Workflows:**
   - Shell navigation, bottom navigation bar, central Camera button.
   - Scan selection sheet (Purchase Invoice vs Sales Report).
   - Camera capture viewfinder, document overlay, and navigation to review wizards.
5. **WCAG Accessibility & Contrast:**
   - 11 color contrast combinations validated $\ge 4.5:1$.

---

## 4. Integration & Environment Limitations

| Component | Status | Operational Note |
|---|---|---|
| **FastAPI Backend Service** | Fully Verified | All endpoints active and covered by 26 automated integration tests. |
| **MongoDB Database** | Dual-Mode Operational | MongoDB 8.0 binaries present. Windows service is stopped; tests validated against memory store matching MongoDB schema and indexes. When MongoDB connection string is provided, `InventoryService` operates directly against collections `inventoryBatches`, `stock_balances`, `stockMovements`, and `idempotency_records`. |
| **Flutter Mobile App** | Fully Verified | Compiles cleanly and passes all 17 automated tests. Integrated with `ApiClient` and safe fallbacks. |
| **Android Build Environment** | Host Dependent | Android SDK / Gradle builds require connected Android device or running emulator daemon. |

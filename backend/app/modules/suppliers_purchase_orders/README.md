# Supplier Management, Purchase Orders & Goods Receipt (Module 4)

**Owner:** Member 3 (Aditya Pakki)  
**Status:** Implemented & Verified with Automated Tests.

## Implemented API Endpoints (`/api/v1/stores/{store_id}`)

### 1. Suppliers
- `POST /suppliers`: Register new medicine supplier / distributor (auto-generates sequential code `SUP-000001`).
- `GET /suppliers`: List suppliers for the store (supports `active_only` filter).
- `GET /suppliers/{supplier_id}`: Retrieve single supplier by ID.
- `PATCH /suppliers/{supplier_id}`: Update contact person, payment terms, or active state.

### 2. Purchase Orders
- `POST /purchase-orders`: Create a purchase order in `Draft` status with multiple line items.
- `GET /purchase-orders`: List purchase orders (supports `status` filter: Draft, Sent, Partially Received, Received, Cancelled).
- `GET /purchase-orders/{po_id}`: Retrieve PO details with line-item progress.
- `POST /purchase-orders/{po_id}/send`: Transition `Draft` PO to `Sent` (awaiting delivery). Does NOT modify inventory.
- `POST /purchase-orders/{po_id}/cancel`: Cancel a PO before any goods receipts have been posted.

### 3. Goods Receipts & Inward Stock Ledger
- `POST /purchase-orders/{po_id}/receipts`: Physical count verification and posting.
  - **Invariants:**
    - Mandatory physical count and pharmacist verification (`verified_by`).
    - Damaged or missing units are deducted (`accepted_quantity = received_now - damaged_or_short`).
    - Appends transactional stock movement to `stock_transactions` ledger (`GOODS_RECEIPT_IN`).
    - Updates PO line item received quantities and overall status (`Partially Received` vs `Received`).
    - **Idempotency Protection:** Honors `Idempotency-Key` header. Duplicate submissions return the existing receipt without duplicate ledger entries.
- `GET /purchase-orders/{po_id}/receipts`: List goods receipts recorded against a specific PO.
- `GET /goods-receipts`: List all historical goods receipts for the store.

## Testing & Quality Verification
- Integration tests in `backend/tests/test_suppliers_purchase_orders.py`:
  - `test_supplier_crud`: Verification of store-scoping, auto-generated codes, duplicate code rejection (409).
  - `test_purchase_order_lifecycle`: Draft creation, line total validation in paise, invalid state checks, Send transition.
  - `test_goods_receipt_posting_and_idempotency`: Physical receipt posting, append-only stock ledger recording, Idempotency-Key caching (201 vs 200), PO fulfillment.
  - `test_purchase_order_cancellation`: Safe cancellation of draft orders, prevention of cancellation once receipts exist.

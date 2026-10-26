# PostgreSQL Database Schema & Indexes (PharmaPro_GM)

All persisted service documents are stored in PostgreSQL through `app_documents` using JSONB payloads, a composite primary key, and a GIN index. Business validation remains in the FastAPI/Pydantic service layer.

---

## 1. Collections & Responsibilities

| Collection | Responsibility | Primary Keys & Compound Indexes |
|---|---|---|
| `products` / `medicines` | Authoritative medicine identity, category, form, unit conversions | `productId` (unique), `uniq_active_product` (`name` + `manufacturer` where `isActive: true`) |
| `suppliers` | Supplier contact, GSTIN, payment terms | `supplierCode` (unique), `name` (index) |
| `purchaseOrders` | Ordered items, expected purchase rates, PO status lifecycle | `purchaseOrderNumber` (unique), `supplierId` (index), `status` (index) |
| `goodsReceipts` | Inward deliveries, accepted vs damaged items, batch creation | `receiptNumber` (unique), `purchaseOrderId` (index) |
| `purchaseInvoices` | Scanned supplier invoices, OCR lines, inward status | `id` (unique), compound unique on `supplierId` + `invoiceNumber`, `fileHash` (index), `idempotencyKey` (sparse unique) |
| `salesReports` | Scanned sales registers, OCR lines, outward status | `id` (unique), compound unique on `reportDate` + `reportReference`, `fileHash` (index), `idempotencyKey` (sparse unique) |
| `inventoryBatches` | Batch-level inventory stock, expiry dates, quarantine status | compound unique on `productId` + `batchNumber` |
| `stockMovements` | Append-only immutable stock ledger | `movementId` (unique), compound index on `productId` + `timestamp` |
| `counters` | Sequential unique ID generators (`MED-`, `SUP-`, `PO-`, `GRN-`) | `_id` (unique sequence identifier) |

---

## 2. Category & Form Validation Rules

Enforced by the PostgreSQL-backed FastAPI service layer for `products`:

### Standardized Categories
- `Medicine`
- `Derma and skin care`
- `Clinic item`
- `Personal care`
- `Sanitary`
- `Food`

### Allowed Dosage Forms
- `Tablet`
- `Capsule`
- `Syrup`
- `Injection`
- `Ointment`
- `Drops`
- `Inhaler`
- `Other`

### Unit Conversion Constraint
- `unitsPerPack` must be a positive integer ($> 0$).
- Example: 1 strip (`packUnit`) = 10 tablets (`saleUnit`).

---

## 3. Stock Ledger Invariants
1. **Append-Only**: No `DELETE` or `UPDATE` operations are ever executed against `stockMovements`.
2. **Double-Entry Traceability**: Every stock movement contains `sourceType` (`GOODS_RECEIPT`, `PURCHASE_INVOICE`, `SALES_REPORT`, `STOCK_ADJUSTMENT`), `sourceId`, and `sourceNumber`.
3. **Derived Balances**: Current stock is computed from or transactionally aligned with the sum of movements.
4. **Idempotency Protection**: Mutating endpoints enforce unique `Idempotency-Key` headers to ensure network retries do not trigger duplicate ledger entries.

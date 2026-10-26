# Team Decisions & Working Assumptions

The following architectural defaults and assumptions from Part 2 and Part 8 are adopted. Any item tagged **"needs team confirmation"** should be verified during team integration meetings:

- **D1 (Backend Framework)**: The repo provides a FastAPI (Python 3.11+) scaffold. We will build and align our Module 4 endpoints within FastAPI rather than switching to Node.js.
- **D2 (State Management & Architecture)**: Flutter frontend structured using clean controller/notifier patterns, separating data, domain, and presentation.
- **D3 (Medicine Identity)**: A medicine is identified by (name + strength + dosage form + manufacturer). Generates a permanent `MED-xxxxxx` Product ID.
- **D4 (Role Model)**: Two roles (`OWNER` and `STAFF`). Backend strictly enforces permission guards.
- **D5 (PO Immutability)**: Sent purchase orders cannot be modified in place. Changes require cancellation and creation of a new PO.
- **D6 (Over-Receipt Guard)**: Over-receipt on goods receipt is blocked (`OVER_RECEIPT` 422 error). *(Needs team confirmation if override is required).*
- **D7 (Tax Policy)**: Purchase orders deal in tax-exclusive expected rates. Tax computation is reserved for the Invoice module.
- **D8 (Currency & Precision)**: Monetary values stored as integer paise in backend storage; formatted as standard Indian Rupee strings (`Rs XX.XX`) with Indian digit grouping (Lakh/Crore) on frontend.
- **D9 (Packaging & Conversion)**: POs use pack units (e.g. Strips, Bottles). Ledger maintains smallest sale units (e.g. Tablets, ML) via conversion factor `unitsPerPack`.
- **D10 (Sequence Identifiers)**:
  - Suppliers: `SUP-000001`
  - Purchase Orders: `PO-2026-000001`
  - Goods Receipts: `GRN-2026-000001`
  - Medicines: `MED-000123`
- **D11 (Alert Windows)**: Default near-expiry threshold is 90 days.
- **D12 (Offline Sync)**: Status badge and offline connectivity warnings are active. Offline queuing is kept behind feature flag `OFFLINE_QUEUE=false`.
- **D13 (OCR Integration)**: Provider-agnostic OCR adapter with development mock.
- **D14 (Messaging Policy)**: No WhatsApp or customer messaging. In-app notification center and local notifications only.
- **D15 (Stock Out Allocation)**: FEFO (First Expiry, First Out) for unassigned sales report batches. *(Needs inventory owner confirmation).*
- **D16 (Prescriptions)**: Minimal records for audit reference; no clinical diagnosis logic.
- **D17 (Credit Entries)**: Immutable ledger; corrections executed via reversal entries with documented rationale.
- **D18 (Telugu Numerals)**: Standard Arabic numerals `0-9` used in both English and Telugu UI.

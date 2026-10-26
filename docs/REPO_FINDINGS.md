# Repository Findings & Architecture Map

## 1. Overview & Stack Summary
- **Workspace**: Pharmacy Store Application (12-module collaborative project)
- **Frontend Stack**: Flutter (Dart 3+), targeted for mobile, web-frame preview, and desktop
- **Backend Stack**: FastAPI (Python 3.11+), Pydantic, asyncpg, Uvicorn
- **Database**: PostgreSQL (accessed exclusively by backend; frontend never interacts directly with PostgreSQL)
- **Assigned Ownership**: Aditya (Member 3) owns **Module 4: Supplier Management, Purchase Orders & Goods Receipt**

## 2. Architecture & File Structure
```text
├── backend/
│   ├── app/
│   │   ├── api/v1/router.py          # Central API v1 router
│   │   ├── core/config.py            # Pydantic Settings & environment variables
│   │   ├── db/postgres.py            # Async PostgreSQL persistence adapter
│   │   ├── main.py                   # FastAPI app with CORS, lifespan, /health, /ready
│   │   └── modules/                  # 12 modules mapped to team members
│   │       ├── authentication_store_roles/
│   │       ├── catalogue_search_units/
│   │       ├── inventory_batches_stock_ledger/
│   │       ├── suppliers_purchase_orders/  # Aditya (Member 3)
│   │       └── ...
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   └── main.dart                 # Scaffold entry point with MobileViewWrapper
│   ├── pubspec.yaml                  # Flutter package definition (uses-material-design: true)
│   ├── analysis_options.yaml         # flutter_lints ^6.0.0
│   └── test/
├── docs/
│   ├── api-conventions.md            # HTTP codes, idempotency, JSON shape
│   ├── architecture.md               # Mermaid data flow & architectural boundaries
│   ├── data-and-stock-rules.md       # Ledger rules, invariants, base units
│   └── team-module-map.md            # 12-member module assignment
```

## 3. Existing Frontend Analysis
- **Current Entry Point**: `frontend/lib/main.dart` contains a minimal `BlankHomePage` wrapped in `MobileViewWrapper` (which centers a mobile 420px frame on wide screens).
- **Existing Theme**: Currently uses a seed color of Teal (`#0F766E`) and slate backgrounds.
- **Master Prompt Mandate**: **Replace** the Teal palette with the custom **Matcha & Almond design system** (PART 4):
  - Brand core: `matcha` (#809671), `almond` (#E5E0D8), `pistache` (#B3B792), `chai` (#D2AB80), `carob` (#725C3A), `vanilla` (#E5D2B8)
  - Derived tokens: `canvas` (#F4F1EA), `surface` (#FBF9F5), `ink` (#2B2118), `inkSoft` (#6B5A44), `matchaDeep` (#5B7050)
  - Status tokens: Muted success, warning, danger, neutral.

## 4. API & Integration Conventions
- Base prefix: `/api/v1`
- Store data scoped under `/stores/{store_id}/...` or tenant shop profile
- Standard JSON envelope: `{ success: true, data: ..., message: ... }`
- Mandatory `Idempotency-Key` on all mutating and confirm endpoints (PO creation, Goods Receipt, Inward posting, Sales deduction)
- Machine error codes (e.g. `OVER_RECEIPT`, `PO_NOT_RECEIVABLE`, `UNKNOWN_PRODUCT`) mapped to localized frontend messages.

## 5. Security & Invariants
- `SECURITY.md` strictly prohibits database credentials in client code.
- OCR outputs from invoice scans or sales reports are strictly **drafts**; stock is never mutated without explicit manual review and user confirmation.
- Stock ledger is append-only; balance edits or deletions are strictly prohibited.

## 6. Integrated Navigation & Scanning Architecture
- **5-Position Bottom Navigation**: Home, Medicines, Central Prominent Scan button, Transactions, More.
- **Transactions Hub**: Unified destination combining Orders (`POListScreen`), Suppliers (`SupplierListScreen`), Inward Bills (`InvoiceScanScreen`), and Sales Reports (`SalesHubScreen`).
- **Central Scan Action**: Elevated matcha-green control opening `ScanSelectionSheet` which forces document type selection (Purchase Invoice for Stock In vs Sales Report for Stock Out) before opening camera or file upload.
- **Full Backend Parity**: FastAPI backend providing endpoints for Module 3 (Medicines), Module 4 (Suppliers/POs), Module 7/8 (Invoices & Sales Reports), and Inventory Ledger. All 19 pytest tests passing.

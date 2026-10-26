# Pharmacy Store Application — Complete Codebase Context

This document is a handoff brief for another developer or IDE. Read it from top to bottom before changing the project. It describes the repository as it currently exists, including the deliberate compromises and unfinished areas.

## 1. Project identity

This is a mobile-first pharmacy inventory and counter-operations application for a small medical shop. The product is designed for a pharmacist or shop operator who needs to:

- maintain a medicine catalogue;
- manage suppliers and purchase orders;
- receive physical stock into batches;
- track stock using an append-only movement ledger and FEFO allocation;
- scan purchase invoices and sales reports into reviewable drafts;
- record manual stock-out transactions;
- view low-stock, expiry, order, and review information;
- use English or Telugu labels;
- run the same Flutter UI on Android, iOS, Windows, and Chrome while preserving a phone-sized layout.

The repository is a monorepo with two independently runnable applications:

```text
pharmacy-app-main/
├── backend/       FastAPI + asyncpg PostgreSQL API
├── frontend/      Flutter application
├── docs/          Architecture, setup, contracts, rules, module status
└── root reports/  Requirements, implementation reports, workflow assets
```

The current backend is PostgreSQL-based. The old MongoDB implementation was removed from the active backend path. The compatibility layer still exposes document-like collection methods so that the feature services can be migrated without rewriting every service at once.

## 2. Runtime architecture

```text
Flutter UI
  ├── MockDataService for most local/demo state
  └── ApiClient for selected live backend operations
          |
          v
FastAPI application: backend/app/main.py
  ├── /health
  ├── /ready
  ├── /api/v1 application information
  └── /api/v1 feature routers
          |
          v
PostgresDatabase adapter: backend/app/db/postgres.py
          |
          v
PostgreSQL database
  └── app_documents(collection, document_id, payload JSONB, timestamps)
```

The backend is asynchronous. FastAPI creates one PostgreSQL connection pool during application startup if `POSTGRES_DSN` is configured. The pool is stored at `app.state.postgres`; the document-style database wrapper is stored at `app.state.db`. Services receive `request.app.state.db` and fall back to in-memory stores when no database is configured.

## 3. How to run it

### Backend

From PowerShell:

```powershell
cd C:\Users\navan\Downloads\pharmacy-app-main\backend
\.venv\Scripts\Activate.ps1
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Backend URLs:

- health: `http://127.0.0.1:8000/health`
- API information: `http://127.0.0.1:8000/api/v1`
- readiness/database check: `http://127.0.0.1:8000/ready`
- Swagger UI: `http://127.0.0.1:8000/docs`

The project expects `backend/.env`, which is intentionally ignored by Git. Use `backend/.env.example` as the template. The important setting is:

```env
POSTGRES_DSN=postgresql://postgres:<password>@localhost:5432/pharmacy_store_dev
```

Never commit or copy the real database password into source code, documentation, prompts, or frontend code.

### Database initialization

PostgreSQL must be running locally on port 5432 and the database named in the DSN must exist. Initialize the schema with:

```powershell
cd C:\Users\navan\Downloads\pharmacy-app-main\backend
\.venv\Scripts\Activate.ps1
python scripts/setup_database.py
```

The script creates the `app_documents` table and its indexes. The application also runs the same `CREATE TABLE IF NOT EXISTS` logic at startup.

### Frontend

From another terminal:

```powershell
cd C:\Users\navan\Downloads\pharmacy-app-main\frontend
flutter pub get
flutter run -d chrome
```

For Android emulator use `flutter run -d emulator-...`. The Flutter API client uses `10.0.2.2` for Android emulator and `127.0.0.1` on other platforms. A physical phone needs a LAN IP instead of localhost and the backend must bind to an accessible interface.

## 4. Backend structure

### Application and configuration

- `backend/app/main.py`: creates FastAPI, configures CORS, owns the PostgreSQL lifespan, exposes health/readiness, and includes the v1 router.
- `backend/app/core/config.py`: `pydantic-settings` configuration. Settings include `APP_NAME`, `APP_ENV`, `API_V1_PREFIX`, `POSTGRES_DSN`, and `CORS_ORIGINS`.
- `backend/requirements.txt`: FastAPI, Uvicorn, asyncpg, pydantic-settings, pytest, and httpx.

### Database adapter

`backend/app/db/postgres.py` is a document-compatible repository on top of PostgreSQL:

- each logical collection is a row in `app_documents.collection`;
- each document is JSONB in `app_documents.payload`;
- `document_id` is the logical primary key within a collection;
- the adapter provides `find_one`, `find`, `insert_one`, `insert_many`, `update_one`, `find_one_and_update`, `distinct`, `sort`, and `limit` methods used by the migrated services;
- supported query operators include `$or`, `$and`, `$regex`, `$options: i`, `$gt`, `$gte`, `$lt`, `$lte`, and `$in`;
- supported update operators include `$set`, `$inc`, and `$setOnInsert`;
- the JSONB GIN index is useful for future JSON queries, but many current filters are evaluated in Python after collection retrieval.

This is a migration bridge, not a fully normalized relational model. It allows the service layer to keep a Mongo-like shape while persistence is PostgreSQL. New work should prefer explicit relational tables for high-value reporting and inventory invariants once the feature behavior is stable.

### Active API router

`backend/app/api/v1/router.py` currently includes:

1. catalogue/search/units;
2. suppliers, purchase orders, and goods receipt;
3. purchase invoice scanning and inward stock;
4. outward sales report scanning;
5. inventory and stock operations.

Several other module directories contain scaffolds and READMEs but are not included in the active central router.

## 5. Backend endpoints

All feature routes are under `/api/v1`.

### Catalogue — `backend/app/modules/catalogue_search_units`

Base path: `/products`

- `POST /products` — create a medicine.
- `GET /products` — list medicines; supports status/category-style filters used by the service.
- `GET /products/search` — ranked search across product ID, brand/name, generic name, strength, form, category, and manufacturer.
- `POST /products/convert` — convert packs/units using a medicine’s conversion factor.
- `GET /products/{product_id}` — fetch one medicine.
- `PATCH /products/{product_id}` and `PUT /products/{product_id}` — update medicine fields.
- `POST /products/{product_id}/deactivate` — deactivate a medicine.

Important model concepts: `productId` is the stable external identifier; `unitsPerPack` is the conversion factor; base-unit quantities are used by inventory; a sale unit may be a pack or loose unit.

### Suppliers, purchase orders, goods receipt — `suppliers_purchase_orders`

Base path: `/stores/{store_id}`

- `POST /suppliers`
- `GET /suppliers?active_only=...`
- `GET /suppliers/{supplier_id}`
- `PATCH /suppliers/{supplier_id}`
- `POST /purchase-orders`
- `GET /purchase-orders?status=...`
- `GET /purchase-orders/{po_id}`
- `POST /purchase-orders/{po_id}/send`
- `POST /purchase-orders/{po_id}/cancel`
- `POST /purchase-orders/{po_id}/receipts`
- `GET /purchase-orders/{po_id}/receipts`
- `GET /goods-receipts`

Purchase-order creation does not alter stock. A physical goods receipt is the stock-in event. Receipt requests accept `Idempotency-Key`; retries return the existing result instead of posting stock twice.

### Purchase invoice scanning — `purchase_invoice_scanning`

Base path: `/invoices`

- `POST /invoices/scan` — create a scanned invoice draft using the current extraction adapter.
- `GET /invoices?status=...` — list invoice drafts or posted invoices.
- `GET /invoices/{invoice_id}`
- `PATCH /invoices/{invoice_id}` — edit extracted lines before confirmation.
- `POST /invoices/{invoice_id}/confirm` — confirm and post inward stock; accepts `Idempotency-Key`.
- `GET /invoices/{invoice_id}/receipt`
- `POST /invoices/{invoice_id}/reject`

The current OCR behavior is a mock adapter. The workflow is intentionally draft-first: scan/extraction never directly changes stock; confirmation does.

### Outward sales report scanning — `outward_sales_report_scanning`

Base path: `/sales-reports`

- `POST /sales-reports/scan`
- `GET /sales-reports?status=...`
- `GET /sales-reports/{report_id}`
- `PUT /sales-reports/{report_id}/lines`
- `POST /sales-reports/{report_id}/confirm-and-post` — accepts `Idempotency-Key`.
- `GET /sales-reports/{report_id}/receipt`
- `POST /sales-reports/{report_id}/reject`

The report is reviewed before it deducts stock. Confirmation uses the inventory service and rejects the entire request if any line cannot be fulfilled.

### Inventory — `backend/app/modules/inventory`

Base path: `/stores/{store_id}/inventory`

- `GET /connectivity`
- `GET /{product_id}/batches`
- `GET /{product_id}/balance`
- `POST /receive`
- `POST /deduct`
- `POST /reconcile`

Inventory is the source of truth for stock movement. It handles base-unit conversion, batch balances, stock ledger entries, FEFO allocation, idempotency, and reconciliation.

## 6. Inventory and data rules

The intended invariant is:

```text
current stock = sum of batch balances = sum of stock ledger movements
```

Rules enforced by the active services:

- all stock-in and stock-out flows go through `InventoryService`;
- quantities are normalized to base units;
- stock is held in batches with expiry information;
- stock-out uses FEFO ordering (earliest expiry first);
- a sale cannot make stock negative;
- multi-line outward requests validate all lines before applying any deduction;
- ledger movements are append-only from the service’s point of view;
- retries use idempotency keys where the endpoint can mutate stock;
- purchase orders are operational records, not stock movements;
- invoice/report scan creates a review draft; confirmation is required to mutate stock;
- reconciliation compares batch totals, aggregate balances, and ledger totals.

Logical collections currently used by services include `products`, `suppliers`, `purchase_orders`, `goods_receipts`, `purchaseInvoices`, `salesReports`, `inventoryBatches`, `stockBalances`, `stockMovements`, `idempotency_keys`, and `counters`. Exact JSON fields are defined in each module’s `schemas.py` and service implementation.

Important migration caveat: the adapter currently performs document operations individually. The service-level multi-write workflows have idempotency protection, but they should eventually be wrapped in real PostgreSQL transactions so a process failure cannot leave partially written receipt, ledger, and balance documents.

## 7. Frontend structure

The Flutter app lives in `frontend/lib` and uses Material 3 with a custom pharmacy palette. There is no large state-management package; state is mostly managed with `ChangeNotifier`, screen-local state, and the singleton `MockDataService`.

### Bootstrap and global layout

- `lib/main.dart`: starts the app, creates `PharmacyApp`, owns language/auth shell state, sets the Material theme, and wraps the entire app in `MobileViewport`.
- `lib/core/ui/mobile_viewport.dart`: constrains wide browser/desktop windows to a centered phone-like width (roughly 430 logical pixels) while using the full width on narrow devices. Because it is installed at the app builder level, pushed screens such as New PO and Add Medicine receive the same mobile frame.
- `lib/core/ui/app_scaffold.dart`: shared screen scaffold.
- `lib/core/ui/app_top_bar.dart`: title, subtitle, back behavior, and English/Telugu toggle.
- `lib/core/ui/bottom_nav_bar.dart`: Home, Medicines, Camera, Transactions, More.
- `lib/features/shell/screens/main_shell_screen.dart`: main tab shell and central camera action.

### Main navigation

The authenticated root is `MainShellScreen`. Its primary tabs are:

- Dashboard — operational summary, quick actions, and needs-attention cards.
- Medicine Catalogue — search, filters, medicine detail, add/edit medicine.
- Transactions — transaction history hub.
- More — suppliers, purchase orders, inventory, customers/credit, reports, notifications, settings-style entries.

The center bottom-nav camera action opens `ScanSelectionSheet`, which offers:

1. Purchase Invoice / stock in;
2. Sales Report / stock out;
3. Manual Transaction / direct stock out.

### Frontend feature directories

- `features/auth`: login and shop setup.
- `features/dashboard`: home dashboard.
- `features/catalogue`: medicine list, add/edit, detail, picker, pack/unit converter.
- `features/camera`: capture/scan entry point.
- `features/invoices`: invoice scan/review flow.
- `features/manual_transaction`: manual stock-out flow.
- `features/purchase_orders`: create, review, detail, timeline, goods receipt.
- `features/suppliers`: supplier list/form/detail and picker.
- `features/inventory`: alerts, reconciliation, stock count, stock ledger.
- `features/sales`: sales hub, report scan/detail, mock OCR adapter, line cards.
- `features/transactions`: transaction hub.
- `features/customers`: customer list, udhaar, payments.
- `features/reports`: reports screen.
- `features/notifications`: notifications screen.
- `features/more`: More menu.

### Shared models, services, and theme

- `core/models`: medicine, batch, supplier, purchase order, goods receipt, customer.
- `core/services/mock_data_service.dart`: seeded demo data and local mutations. This is the main state source for most screens.
- `core/api/api_client.dart`: live HTTP calls for backend reachability, medicine creation, goods receipt, and sales deduction. It catches failures and returns `null`, so UI error detail is currently limited.
- `core/localization`: English/Telugu strings and `LanguageController`.
- `core/theme`: colors, typography, and Material theme.
- `core/ui`: reusable cards, chips, metric strips, search field, quantity stepper, sticky actions, scan sheet, status widgets, and layout primitives.

## 8. Frontend/backend integration boundary

This boundary is essential for understanding current behavior:

```text
Most frontend screens
  -> MockDataService (local in-memory demo state)

Selected mutation paths
  -> ApiClient
  -> FastAPI
  -> PostgreSQL
```

The UI is therefore not yet a complete live-data client. Adding a medicine may call the API, but catalogue lists and many dashboard values still come from seeded local data. Purchase-order and scanner screens also contain local/demo behavior around the live mutation calls. A production completion task should introduce a repository layer that loads API data, handles loading/error states, and invalidates local caches after successful mutations.

## 9. Important user flows

### Manual transaction

`ManualTransactionScreen` searches the local catalogue, lets the operator select medicines, chooses quantities constrained by current local stock, reviews the selected sale units, asks for confirmation, then calls the sales deduction endpoint with source type `MANUAL_TRANSACTION`, store `main_store`, and an idempotency key. On success it updates the local mock inventory and shows a success screen.

### Purchase invoice

The camera/invoice flow creates an invoice draft, shows extracted lines/confidence, allows correction, and confirms only after review. Confirmation calls the backend stock-in flow. The OCR itself is currently simulated and must be replaced or isolated behind a real OCR provider.

### Sales report

The sales scan flow creates a pending report, allows line edits, shows the expected stock deduction, and posts only after explicit confirmation. Backend validation is all-or-nothing for the report.

### Purchase order and goods receipt

The operator creates a draft PO, sends it, later records a physical receipt with quantities and verification, and the receipt service posts accepted stock. Sending a PO alone never increases stock.

## 10. Testing

Backend tests are in `backend/tests` and cover health, catalogue search/unit conversion, inventory integrity, scaffold behavior, outward sales, purchase invoice scanning, and suppliers/POs. Frontend tests are in `frontend/test` and cover widgets, navigation/scan selection, inventory integrity, and contrast.

Run backend tests from the backend virtual environment:

```powershell
cd backend
\.venv\Scripts\Activate.ps1
pytest -q
```

Be aware that older tests were written around the no-database in-memory fallback. When a live `backend/.env` is loaded, tests that create multiple `TestClient` lifecycles can conflict with the global PostgreSQL pool and may need a dedicated test fixture/database. Do not interpret a failing fallback-oriented test as proof that the production database is unreachable.

Run Flutter checks with:

```powershell
cd frontend
flutter analyze
flutter test
```

## 11. Active limitations and next engineering priorities

1. **Live-data completion:** replace broad `MockDataService` usage with API-backed repositories and explicit loading/error/empty states.
2. **Database normalization:** move critical inventory, products, batches, balances, and ledger data from generic JSONB documents into typed PostgreSQL tables with foreign keys and check constraints.
3. **Atomicity:** wrap receipt, inward, outward, balance, ledger, and idempotency writes in a single PostgreSQL transaction.
4. **Authentication and authorization:** authentication/store/roles directories are scaffolds; central API routes currently do not enforce real user identity or store ownership.
5. **Real OCR:** invoice and sales extraction adapters are mock/demo implementations.
6. **Error visibility:** `ApiClient` should preserve HTTP status and structured backend errors rather than returning only `null`.
7. **Test isolation:** add a dedicated test DSN or dependency override and separate fallback tests from PostgreSQL integration tests.
8. **Inactive modules:** expiry/low-stock, dashboard reports, customers/refills, udhaar, WhatsApp notifications, and offline sync have scaffolds or documentation but are not complete production modules in the central API.
9. **Responsive behavior:** `MobileViewport` provides a consistent phone frame on desktop browsers; screen-level widgets should still be checked on very small phones, large phones, keyboard-open states, and accessibility text scaling.

## 12. Files another IDE should inspect first

For immediate understanding, open these in order:

1. `README.md`
2. `docs/SETUP.md`
3. `docs/architecture.md`
4. `docs/api-conventions.md`
5. `docs/data-and-stock-rules.md`
6. `backend/app/main.py`
7. `backend/app/db/postgres.py`
8. `backend/app/api/v1/router.py`
9. `backend/app/modules/inventory/service.py`
10. `backend/app/modules/catalogue_search_units/service.py`
11. `backend/app/modules/suppliers_purchase_orders/service.py`
12. `backend/app/modules/purchase_invoice_scanning/service.py`
13. `backend/app/modules/outward_sales_report_scanning/service.py`
14. `frontend/lib/main.dart`
15. `frontend/lib/core/ui/mobile_viewport.dart`
16. `frontend/lib/core/services/mock_data_service.dart`
17. `frontend/lib/core/api/api_client.dart`
18. `frontend/lib/features/shell/screens/main_shell_screen.dart`
19. `frontend/lib/features/manual_transaction/screens/manual_transaction_screen.dart`

## 13. Safe change guidance

- Preserve `/api/v1` and existing response shapes unless a migration is intentionally documented.
- Preserve `productId` as the stable product identifier and use base units for stock calculations.
- Never mutate stock directly from a route or UI; use `InventoryService`.
- Keep scan workflows draft-first and confirmation-based.
- Require idempotency for retryable stock mutations.
- Do not put PostgreSQL credentials in Flutter, Git, screenshots, or committed documentation.
- When changing a shared Flutter widget, verify every pushed route, not only the dashboard.
- When changing the database adapter, run both backend unit tests and an integration check against `/ready` and a real PostgreSQL database.

## 14. Recent implementation changes represented by this repository

- MongoDB active persistence was replaced with PostgreSQL/asyncpg.
- A PostgreSQL JSONB document adapter was added to support the existing service contracts during migration.
- Database setup and environment examples were updated for PostgreSQL.
- The API root `/api/v1` now returns a discoverable information document instead of a 404.
- Manual stock-out transaction UI was added from the scan selection flow.
- A global Flutter `MobileViewport` was added so the dashboard and pushed screens use a centered phone-sized layout when run in a wide browser window.
- Gemini 3.8 Flash image extraction was added at `POST /api/v1/ocr/scan-image`; extracted medicine rows are stored as `ai_document_scans` records with `PENDING_REVIEW` status, and Flutter gallery uploads call this endpoint.

This file is descriptive context, not a substitute for reading the implementation. If behavior in this document and the code disagree, treat the code and executable tests as authoritative and update this document after resolving the discrepancy.

# Module Status Classification (Phase 0)

Per Part 1.3 of the Master Rulebook, all 12 modules from the repository and Part 10 specification are inspected and classified below:

| Module # | Module Name | Owner | Status | Current Repo State & Required Action |
|---|---|---|---|---|
| **10.1** | Authentication, Store Setup & User Roles | Member 1 | `EXISTS-PARTIAL` | Backend module folder scaffold exists. Needs JWT/auth middleware, store profile endpoints, and Flutter Login + Shop Setup screens. |
| **10.2** | Dashboard and Reports | Member 11 | `EXISTS-PARTIAL` | Backend scaffold exists. Needs metric aggregations. Frontend needs compact MetricStrip, "Needs Attention" list, and 3 standard reports. |
| **10.3** | **Medicine Catalogue, Search & Units** | **Member 2 (Harshitha)** | `COMPLETE-VERIFIED` | **Complete End-to-End**: 5 screens, 6 standardized categories, allowed forms, live conversion formula, Chai duplicate warning banner, non-destructive deactivation, typo-tolerant search, full FastAPI endpoints, schemas, service, and pytest tests passing. |
| **10.4** | **Supplier, Purchase Orders & Goods Receipt** | **Member 3 (Aditya)** | `COMPLETE-VERIFIED` | **Complete End-to-End**: Frontend 7 interactive screens (S1-S7) + full PO and Goods Receipt lifecycle with idempotent transactions. Backend REST endpoints, schemas, service, and pytest test suite all fully implemented and passing. |
| **10.5** | Inventory, Batches & Stock Ledger | Member 5 | `EXISTS-PARTIAL` | Backend has batch movement contract (`/movements/batch`). Append-only ledger updates verified through Goods Receipt and Inward/Outward scan confirmations. |
| **10.6** | Expiry, Low-Stock Alerts & Reconciliation | Member 6 | `EXISTS-PARTIAL` | Backend scaffold exists. Physical count and variance reconciliation screen with FEFO batch quarantine live on frontend. |
| **10.7** | **Purchase Invoice Scanning & Inward** | **Member 4** | `COMPLETE-VERIFIED` | **Complete End-to-End**: Frontend capture, OCR review, confidence indicators, batch/expiry inputs, confirm inward dialog, and result view. Backend 6 endpoints (`/invoices/*`), duplicate protection, idempotency, and pytest tests passing. |
| **10.8** | **Outward Sales Report Scanning** | **Member 7 (Aman)** | `COMPLETE-VERIFIED` | **Complete End-to-End**: Frontend capture, OCR preview, confidence indicators, loose-unit conversion, confirm deduction, and stock movement result. Backend 5 endpoints (`/sales-reports/*`), duplicate checking, idempotency, and pytest tests passing. |
| **10.9** | Customers, Refills & Prescriptions | Member 8 | `EXISTS-PARTIAL` | Backend scaffold exists. Needs customer CRUD, refill tracking, minimal prescriptions. Frontend needs customer tabs. |
| **10.10** | Udhaar (Credit) & Payments | Member 9 | `EXISTS-PARTIAL` | Backend scaffold exists. Needs ledger-derived balance and reversal entries. Frontend needs ledger timeline. |
| **10.11** | Reminders & Notifications | Member 10 | `EXISTS-PARTIAL` | Backend scaffold exists. Needs in-app notification center and local alerts (no external WhatsApp). |
| **10.12** | Offline Handling & Sync | Member 12 | `EXISTS-PARTIAL` | Scaffold exists. Build `SyncStatusBadge` and connectivity banner; queueing kept behind `OFFLINE_QUEUE` flag. |

## Strategy
1. **Never overwrite teammates' code**: Build shared design foundations (`lib/core/ui`, `lib/core/theme`, `lib/core/localization`) so any team member can consume them.
2. **Implement Module 4 (Aditya)** completely end-to-end with high-fidelity screens, realistic mock data and real API adapter readiness.

/**
 * ==============================================================================
 * PHARMAPRO_GM — COMPLETE MONGODB COMPASS SETUP & QUERY SUITE
 * ==============================================================================
 * Database: pharmacy_store_dev
 * Modules: Member 2 (Catalogue), Member 3 (POs/Invoices/GRN), Member 7 (Sales/FEFO),
 *          and Shared Authoritative Inventory Engine (Batches, Balances, Ledger, Idempotency)
 *
 * HOW TO EXECUTE IN MONGODB COMPASS:
 * Option A: Open the embedded '_mongosh_' shell at the bottom of Compass, paste
 *           this entire script, and press ENTER.
 * Option B: In _mongosh_, run:
 *           load("H:/GrayMatterProjects/pharmacy-app-main/pharmacy-app-main/pharmacy_mongodb_compass_complete.js")
 * ==============================================================================
 */

// 1. SELECT TARGET DATABASE (Compatible with mongosh load() and interactive paste)
db = db.getSiblingDB("pharmacy_store_dev");

print(">>> Starting PharmaPro_GM MongoDB Initialization...");

// ==============================================================================
// 2. SCHEMA CONSTRAINTS & INDEX DEFINITIONS
// ==============================================================================
print(">>> Creating collections and indexes...");

// Collection 1: products (Catalogue & Identity - Member 2)
db.createCollection("products");
db.products.createIndex({ "id": 1 }, { unique: true });
db.products.createIndex({ "productId": 1 }, { unique: true, sparse: true });
db.products.createIndex({ "brand_name": 1, "strength": 1, "dosage_form": 1, "is_active": 1 });
db.products.createIndex({ "barcode": 1 }, { sparse: true });

// Collection 2: inventoryBatches (Shared Batch Balances - FEFO Support)
db.createCollection("inventoryBatches");
db.inventoryBatches.createIndex(
  { "store_id": 1, "product_id": 1, "batch_number": 1 },
  { unique: true }
);
db.inventoryBatches.createIndex({ "store_id": 1, "product_id": 1, "expiry_date": 1 });

// Collection 3: stock_balances (Aggregate Product Inventory)
db.createCollection("stock_balances");
db.stock_balances.createIndex({ "store_id": 1, "product_id": 1 }, { unique: true });

// Collection 4: stockMovements (Append-Only Immutable Stock Ledger)
db.createCollection("stockMovements");
db.stockMovements.createIndex({ "movement_id": 1 }, { unique: true });
db.stockMovements.createIndex({ "store_id": 1, "product_id": 1, "created_at": -1 });
db.stockMovements.createIndex({ "store_id": 1, "batch_number": 1 });
db.stockMovements.createIndex({ "source_doc_id": 1 });
db.stockMovements.createIndex({ "idempotency_key": 1 }, { sparse: true });

// Collection 5: idempotency_records (Durable Mutation Protection)
db.createCollection("idempotency_records");
db.idempotency_records.createIndex(
  { "store_id": 1, "operation": 1, "idempotency_key": 1 },
  { unique: true }
);

// Collection 6: suppliers (Supplier Registry - Member 3)
db.createCollection("suppliers");
db.suppliers.createIndex({ "store_id": 1, "code": 1 }, { unique: true });
db.suppliers.createIndex({ "store_id": 1, "name": 1 });

// Collection 7: purchase_orders (PO Lifecycle - Member 3)
db.createCollection("purchase_orders");
db.purchase_orders.createIndex({ "store_id": 1, "po_number": 1 }, { unique: true });
db.purchase_orders.createIndex({ "store_id": 1, "status": 1 });

// Collection 8: goods_receipts (Goods Receipt Notes - Member 3)
db.createCollection("goods_receipts");
db.goods_receipts.createIndex({ "store_id": 1, "receipt_number": 1 }, { unique: true });
db.goods_receipts.createIndex({ "store_id": 1, "po_id": 1 });

// Collection 9: purchaseInvoices (Inward Supplier Invoices - Member 3)
db.createCollection("purchaseInvoices");
db.purchaseInvoices.createIndex({ "invoice_number": 1 }, { unique: true });

// Collection 10: salesReports (Outward Daily Register Scans - Member 7)
db.createCollection("salesReports");
db.salesReports.createIndex({ "id": 1 }, { unique: true });
db.salesReports.createIndex({ "store_id": 1, "report_reference": 1 });

// Collection 11: counters (Sequence Generators)
db.createCollection("counters");

print(">>> Collections and indexes created successfully.");

// ==============================================================================
// 3. AUTHORITATIVE SEED DATA
// ==============================================================================
print(">>> Seeding clean baseline data...");

// Clean up existing demo data
db.products.deleteMany({});
db.inventoryBatches.deleteMany({});
db.stock_balances.deleteMany({});
db.stockMovements.deleteMany({});
db.suppliers.deleteMany({});
db.purchase_orders.deleteMany({});
db.purchaseInvoices.deleteMany({});
db.salesReports.deleteMany({});
db.idempotency_records.deleteMany({});
db.counters.deleteMany({});

const now = new Date();
const nowIso = now.toISOString();

// A. Seed Products (Member 2)
db.products.insertMany([
  {
    "id": "MED-000101",
    "productId": "MED-000101",
    "brand_name": "Dolo 650",
    "name": "Dolo 650mg",
    "generic_name": "Paracetamol",
    "strength": "650mg",
    "dosage_form": "Tablet",
    "form": "Tablet",
    "category": "Analgesic & Antipyretic",
    "manufacturer": "Micro Labs Ltd",
    "base_unit": "tablet",
    "sale_unit": "tablet",
    "pack_unit": "strip",
    "units_per_pack": 15,
    "low_stock_threshold": 50,
    "is_active": true,
    "unit_conversions": [{ "pack_unit": "strip", "factor": 15 }],
    "created_at": nowIso,
    "updated_at": nowIso
  },
  {
    "id": "MED-000102",
    "productId": "MED-000102",
    "brand_name": "Augmentin 625 Duo",
    "name": "Augmentin 625 Duo",
    "generic_name": "Amoxicillin & Potassium Clavulanate",
    "strength": "625mg",
    "dosage_form": "Tablet",
    "form": "Tablet",
    "category": "Antibiotic",
    "manufacturer": "GSK Pharmaceuticals",
    "base_unit": "tablet",
    "sale_unit": "tablet",
    "pack_unit": "strip",
    "units_per_pack": 10,
    "low_stock_threshold": 30,
    "is_active": true,
    "unit_conversions": [{ "pack_unit": "strip", "factor": 10 }],
    "created_at": nowIso,
    "updated_at": nowIso
  },
  {
    "id": "MED-000103",
    "productId": "MED-000103",
    "brand_name": "Pan 40",
    "name": "Pan 40 Tablet",
    "generic_name": "Pantoprazole",
    "strength": "40mg",
    "dosage_form": "Tablet",
    "form": "Tablet",
    "category": "Antacid & Anti-reflux",
    "manufacturer": "Alkem Laboratories",
    "base_unit": "tablet",
    "sale_unit": "tablet",
    "pack_unit": "strip",
    "units_per_pack": 15,
    "low_stock_threshold": 40,
    "is_active": true,
    "unit_conversions": [{ "pack_unit": "strip", "factor": 15 }],
    "created_at": nowIso,
    "updated_at": nowIso
  },
  {
    "id": "MED-000301",
    "productId": "MED-000301",
    "brand_name": "Zerodol SP Tablet",
    "name": "Zerodol SP Tablet",
    "generic_name": "Aceclofenac, Paracetamol & Serratiopeptidase",
    "strength": "100mg/325mg/15mg",
    "dosage_form": "Tablet",
    "form": "Tablet",
    "category": "NSAID & Anti-inflammatory",
    "manufacturer": "Ipca Laboratories",
    "base_unit": "tablet",
    "sale_unit": "tablet",
    "pack_unit": "strip",
    "units_per_pack": 15,
    "low_stock_threshold": 30,
    "is_active": true,
    "unit_conversions": [{ "pack_unit": "strip", "factor": 15 }],
    "created_at": nowIso,
    "updated_at": nowIso
  },
  {
    "id": "MED-000456",
    "productId": "MED-000456",
    "brand_name": "Crocin 500 Advance",
    "name": "Crocin 500 Advance",
    "generic_name": "Paracetamol Fast Release",
    "strength": "500mg",
    "dosage_form": "Tablet",
    "form": "Tablet",
    "category": "Analgesic & Antipyretic",
    "manufacturer": "GlaxoSmithKline",
    "base_unit": "tablet",
    "sale_unit": "tablet",
    "pack_unit": "strip",
    "units_per_pack": 15,
    "low_stock_threshold": 40,
    "is_active": true,
    "unit_conversions": [{ "pack_unit": "strip", "factor": 15 }],
    "created_at": nowIso,
    "updated_at": nowIso
  }
]);

// B. Seed Suppliers (Member 3)
db.suppliers.insertMany([
  {
    "id": "sup-001",
    "store_id": "main_store",
    "code": "SUP-000001",
    "name": "Sri Venkateswara Pharma Distributors",
    "contact_person": "K. Venkatesh",
    "phone": "9848022338",
    "email": "venkatesh@svpharma.in",
    "address": "Governorpet, Vijayawada, AP",
    "payment_terms": "Credit 30 Days",
    "active": true,
    "created_at": nowIso,
    "updated_at": nowIso
  },
  {
    "id": "sup-002",
    "store_id": "main_store",
    "code": "SUP-000002",
    "name": "Balaji Drug Agencies",
    "contact_person": "R. Balaji Rao",
    "phone": "9440188992",
    "email": "orders@balajidrugs.com",
    "address": "Kaleswara Rao Market, Vijayawada, AP",
    "payment_terms": "Credit 15 Days",
    "active": true,
    "created_at": nowIso,
    "updated_at": nowIso
  }
]);

// C. Seed Initial Inventory Batches (Shared Inventory)
// Note: Quantities are strictly stored in normalized base units (tablets)
db.inventoryBatches.insertMany([
  // Dolo 650mg: 2 batches (1 Near-Expiry for FEFO demonstration)
  {
    "store_id": "main_store",
    "product_id": "MED-000101",
    "batch_number": "BAT-DL-84",
    "expiry_date": "2026-11-30", // Earliest expiry: must be deducted first in FEFO!
    "quantity": 60,
    "supplier_name": "Balaji Drug Agencies",
    "purchase_rate_paise": 3100,
    "created_at": nowIso,
    "updated_at": nowIso
  },
  {
    "store_id": "main_store",
    "product_id": "MED-000101",
    "batch_number": "BAT-DL-91",
    "expiry_date": "2028-12-31", // Later expiry
    "quantity": 120,
    "supplier_name": "Sri Venkateswara Pharma Distributors",
    "purchase_rate_paise": 3250,
    "created_at": nowIso,
    "updated_at": nowIso
  },
  // Augmentin 625 Duo: 1 batch
  {
    "store_id": "main_store",
    "product_id": "MED-000102",
    "batch_number": "BAT-AG-84",
    "expiry_date": "2027-09-30",
    "quantity": 100,
    "supplier_name": "Sri Venkateswara Pharma Distributors",
    "purchase_rate_paise": 12500,
    "created_at": nowIso,
    "updated_at": nowIso
  },
  // Pan 40: 1 batch
  {
    "store_id": "main_store",
    "product_id": "MED-000103",
    "batch_number": "BAT-PN-01",
    "expiry_date": "2028-09-30",
    "quantity": 150,
    "supplier_name": "Balaji Drug Agencies",
    "purchase_rate_paise": 8500,
    "created_at": nowIso,
    "updated_at": nowIso
  },
  // Zerodol SP: 1 batch
  {
    "store_id": "main_store",
    "product_id": "MED-000301",
    "batch_number": "BAT-ZS-91",
    "expiry_date": "2028-12-31",
    "quantity": 150,
    "supplier_name": "Balaji Drug Agencies",
    "purchase_rate_paise": 14000,
    "created_at": nowIso,
    "updated_at": nowIso
  }
]);

// D. Seed Initial Stock Balances (Must match sum of batches!)
db.stock_balances.insertMany([
  {
    "store_id": "main_store",
    "product_id": "MED-000101",
    "current_stock": 180, // 60 + 120
    "updated_at": nowIso
  },
  {
    "store_id": "main_store",
    "product_id": "MED-000102",
    "current_stock": 100,
    "updated_at": nowIso
  },
  {
    "store_id": "main_store",
    "product_id": "MED-000103",
    "current_stock": 150,
    "updated_at": nowIso
  },
  {
    "store_id": "main_store",
    "product_id": "MED-000301",
    "current_stock": 150,
    "updated_at": nowIso
  }
]);

// E. Seed Initial Immutable Stock Ledger Entries
db.stockMovements.insertMany([
  {
    "movement_id": "MOV-INIT-001",
    "store_id": "main_store",
    "product_id": "MED-000101",
    "product_name": "Dolo 650",
    "batch_number": "BAT-DL-84",
    "quantity": 60,
    "unit": "tablet",
    "movement_type": "INITIAL_IN",
    "source_doc_type": "STOCK_TAKEOVER",
    "source_doc_id": "INIT-STORE-MAIN",
    "source_doc_number": "TAKEOVER-2026-001",
    "posted_by": "System Administrator",
    "idempotency_key": "IDEMP-INIT-001",
    "created_at": nowIso
  },
  {
    "movement_id": "MOV-INIT-002",
    "store_id": "main_store",
    "product_id": "MED-000101",
    "product_name": "Dolo 650",
    "batch_number": "BAT-DL-91",
    "quantity": 120,
    "unit": "tablet",
    "movement_type": "INITIAL_IN",
    "source_doc_type": "STOCK_TAKEOVER",
    "source_doc_id": "INIT-STORE-MAIN",
    "source_doc_number": "TAKEOVER-2026-001",
    "posted_by": "System Administrator",
    "idempotency_key": "IDEMP-INIT-002",
    "created_at": nowIso
  },
  {
    "movement_id": "MOV-INIT-003",
    "store_id": "main_store",
    "product_id": "MED-000102",
    "product_name": "Augmentin 625 Duo",
    "batch_number": "BAT-AG-84",
    "quantity": 100,
    "unit": "tablet",
    "movement_type": "INITIAL_IN",
    "source_doc_type": "STOCK_TAKEOVER",
    "source_doc_id": "INIT-STORE-MAIN",
    "source_doc_number": "TAKEOVER-2026-001",
    "posted_by": "System Administrator",
    "idempotency_key": "IDEMP-INIT-003",
    "created_at": nowIso
  },
  {
    "movement_id": "MOV-INIT-004",
    "store_id": "main_store",
    "product_id": "MED-000103",
    "product_name": "Pan 40",
    "batch_number": "BAT-PN-01",
    "quantity": 150,
    "unit": "tablet",
    "movement_type": "INITIAL_IN",
    "source_doc_type": "STOCK_TAKEOVER",
    "source_doc_id": "INIT-STORE-MAIN",
    "source_doc_number": "TAKEOVER-2026-001",
    "posted_by": "System Administrator",
    "idempotency_key": "IDEMP-INIT-004",
    "created_at": nowIso
  },
  {
    "movement_id": "MOV-INIT-005",
    "store_id": "main_store",
    "product_id": "MED-000301",
    "product_name": "Zerodol SP Tablet",
    "batch_number": "BAT-ZS-91",
    "quantity": 150,
    "unit": "tablet",
    "movement_type": "INITIAL_IN",
    "source_doc_type": "STOCK_TAKEOVER",
    "source_doc_id": "INIT-STORE-MAIN",
    "source_doc_number": "TAKEOVER-2026-001",
    "posted_by": "System Administrator",
    "idempotency_key": "IDEMP-INIT-005",
    "created_at": nowIso
  }
]);

// F. Seed Sample Inward Purchase Invoice (Member 3)
db.purchaseInvoices.insertOne({
  "invoice_number": "INV-9032",
  "store_id": "main_store",
  "supplier_name": "Sri Venkateswara Pharma Distributors",
  "invoice_date": "2026-10-12",
  "status": "DRAFT",
  "lines": [
    {
      "line_number": 1,
      "medicine_name": "Augmentin 625 Duo",
      "matched_product_id": "MED-000102",
      "matched_product_name": "Augmentin 625 Duo",
      "quantity": 10, // 10 strips = 100 tablets
      "unit": "strip",
      "batch_number": "BAT-AG-84",
      "expiry_date": "2027-09-30",
      "purchase_rate": 125.00
    }
  ],
  "created_at": nowIso
});

// G. Seed Sample Outward Sales Report (Member 7)
db.salesReports.insertOne({
  "id": "SR-1012",
  "store_id": "main_store",
  "report_reference": "SR-1012",
  "report_date": "2026-10-12",
  "status": "DRAFT",
  "unresolved_lines": 0,
  "lines": [
    {
      "line_id": "L1",
      "medicine_name": "Dolo 650mg",
      "matched_product_id": "MED-000101",
      "matched_brand_name": "Dolo 650",
      "quantity_entered": 5, // 5 loose tablets
      "unit_entered": "tablets",
      "converted_base_quantity": 5
    }
  ],
  "created_at": nowIso
});

print(">>> Baseline data seeded successfully.");

// ==============================================================================
// 4. ESSENTIAL OPERATIONAL QUERIES (Ready to run or inspect in Compass)
// ==============================================================================

print("\n=======================================================");
print("4.1 STORE INVENTORY SUMMARY (Current On-Hand Base Units)");
print("=======================================================");
const stockSummary = db.stock_balances.find({ "store_id": "main_store" }).toArray();
printjson(stockSummary);

print("\n=======================================================");
print("4.2 ACTIVE BATCHES SORTED FOR FEFO (Earliest Expiry First)");
print("=======================================================");
const fefoBatches = db.inventoryBatches
  .find({ "store_id": "main_store", "quantity": { "$gt": 0 } })
  .sort({ "product_id": 1, "expiry_date": 1 })
  .toArray();
printjson(fefoBatches);

print("\n=======================================================");
print("4.3 NEAR-EXPIRY AUDIT (< 90 Days from Current Date)");
print("=======================================================");
const ninetyDaysFromNow = new Date(Date.now() + 90 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
const nearExpiryBatches = db.inventoryBatches.find({
  "store_id": "main_store",
  "expiry_date": { "$lte": ninetyDaysFromNow },
  "quantity": { "$gt": 0 }
}).toArray();
printjson(nearExpiryBatches);

// ==============================================================================
// 5. COMPASS AGGREGATION PIPELINES
// ==============================================================================

print("\n===============================================================================");
print("5.1 RECONCILIATION PIPELINE: sum(Batches) vs stock_balance vs sum(Ledger)");
print("===============================================================================");
const reconResult = db.stock_balances.aggregate([
  { "$match": { "store_id": "main_store" } },
  {
    "$lookup": {
      "from": "inventoryBatches",
      "let": { "storeId": "$store_id", "pId": "$product_id" },
      "pipeline": [
        {
          "$match": {
            "$expr": {
              "$and": [
                { "$eq": ["$store_id", "$$storeId"] },
                { "$eq": ["$product_id", "$$pId"] }
              ]
            }
          }
        },
        {
          "$group": {
            "_id": null,
            "total_batch_qty": { "$sum": "$quantity" }
          }
        }
      ],
      "as": "batch_agg"
    }
  },
  {
    "$lookup": {
      "from": "stockMovements",
      "let": { "storeId": "$store_id", "pId": "$product_id" },
      "pipeline": [
        {
          "$match": {
            "$expr": {
              "$and": [
                { "$eq": ["$store_id", "$$storeId"] },
                { "$eq": ["$product_id", "$$pId"] }
              ]
            }
          }
        },
        {
          "$group": {
            "_id": null,
            "total_ledger_qty": { "$sum": "$quantity" }
          }
        }
      ],
      "as": "ledger_agg"
    }
  },
  {
    "$project": {
      "_id": 0,
      "store_id": 1,
      "product_id": 1,
      "current_stock_balance": "$current_stock",
      "sum_batches": {
        "$ifNull": [{ "$arrayElemAt": ["$batch_agg.total_batch_qty", 0] }, 0]
      },
      "sum_ledger": {
        "$ifNull": [{ "$arrayElemAt": ["$ledger_agg.total_ledger_qty", 0] }, 0]
      },
      "is_consistent": {
        "$and": [
          {
            "$eq": [
              "$current_stock",
              { "$ifNull": [{ "$arrayElemAt": ["$batch_agg.total_batch_qty", 0] }, 0] }
            ]
          },
          {
            "$eq": [
              "$current_stock",
              { "$ifNull": [{ "$arrayElemAt": ["$ledger_agg.total_ledger_qty", 0] }, 0] }
            ]
          }
        ]
      }
    }
  }
]).toArray();
printjson(reconResult);

print("\n>>> All PharmaPro_GM MongoDB queries executed successfully in Compass mongosh!");

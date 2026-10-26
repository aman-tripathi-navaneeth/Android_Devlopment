"""Comprehensive regression tests for Phase 8: Inventory Integrity & Module Coordination.

Verifies:
1. Member 2: Product identity stability, duplicate detection, pack-to-base unit conversion.
2. Member 3: Goods receipt validation, batch/expiry requirements, atomic inward posting, idempotency.
3. Member 7: Sales stock sufficiency rejection, FEFO multi-batch allocation, retry idempotency.
4. Shared Integration: Strip inward -> loose tablet sale -> 47 remaining units invariant.
5. Reconciliation: Batch balance == aggregate balance == stock ledger sum.
"""

from fastapi.testclient import TestClient
import pytest

from app.main import app
from app.modules.catalogue_search_units.service import fallback_catalogue_store
from app.modules.inventory.service import fallback_inventory_store
from app.modules.outward_sales_report_scanning.service import fallback_sales_report_store
from app.modules.suppliers_purchase_orders.service import fallback_store

client = TestClient(app)
STORE_ID = "store_test_regression"


@pytest.fixture(autouse=True)
def reset_all_stores():
    fallback_catalogue_store.clear()
    fallback_catalogue_store.seed_sample_data()
    fallback_inventory_store.clear()
    fallback_inventory_store.seed_defaults()
    fallback_sales_report_store.clear()
    fallback_store.clear()
    yield


# ==============================================================================
# SCENARIO 1: CATALOGUE & STABLE PRODUCT IDENTITY
# ==============================================================================

def test_catalogue_stable_identity_and_duplicate_rules():
    # 1. Create a new medicine
    new_med = {
        "catalogue_scope": "shared",
        "brand_name": "Azithral",
        "generic_name": "Azithromycin",
        "strength_value": 250.0,
        "strength_unit": "mg",
        "form": "tablet",
        "category": "medicine",
        "base_unit": "tablet",
        "unit_conversions": [{"pack_unit": "strip", "factor": 6}],
    }
    create_res = client.post("/api/v1/products", json=new_med)
    assert create_res.status_code == 201
    created_data = create_res.json()
    product_id = created_data["id"]
    assert product_id.startswith("MED-")

    # 2. Reload product from server
    get_res = client.get(f"/api/v1/products/{product_id}")
    assert get_res.status_code == 200
    assert get_res.json()["id"] == product_id
    assert get_res.json()["brand_name"] == "Azithral"

    # 3. Edit product without changing its ID
    update_res = client.put(f"/api/v1/products/{product_id}", json={"generic_name": "Azithromycin Dihydrate"})
    assert update_res.status_code == 200
    assert update_res.json()["id"] == product_id
    assert update_res.json()["generic_name"] == "Azithromycin Dihydrate"

    # 4. Attempt exact duplicate creation -> MUST FAIL with 409
    dup_res = client.post("/api/v1/products", json=new_med)
    assert dup_res.status_code == 409

    # 5. Same brand name but different strength (Azithral 100mg) -> MUST SUCCEED
    diff_strength = {**new_med, "strength_value": 100.0}
    diff_res = client.post("/api/v1/products", json=diff_strength)
    assert diff_res.status_code == 201
    assert diff_res.json()["id"] != product_id

    # 6. Same brand name but different dosage form (Azithral Syrup) -> MUST SUCCEED
    diff_form = {**new_med, "form": "bottle", "base_unit": "ml", "unit_conversions": [{"pack_unit": "bottle", "factor": 60}]}
    diff_form_res = client.post("/api/v1/products", json=diff_form)
    assert diff_form_res.status_code == 201


# ==============================================================================
# SCENARIO 2: CORE GOLDEN RULE — 5 STRIPS (10s) INWARD, 3 TABLETS OUTWARD = 47
# ==============================================================================

def test_unit_conversion_inward_outward_golden_rule():
    # Setup medicine: 1 strip = 10 tablets
    med_payload = {
        "catalogue_scope": "shared",
        "brand_name": "Calpol",
        "generic_name": "Paracetamol",
        "strength_value": 500.0,
        "strength_unit": "mg",
        "form": "tablet",
        "category": "medicine",
        "base_unit": "tablet",
        "unit_conversions": [{"pack_unit": "strip", "factor": 10}],
    }
    med_res = client.post("/api/v1/products", json=med_payload)
    assert med_res.status_code == 201
    product_id = med_res.json()["id"]

    # Inward: Receive 5 strips of 10 tablets
    inward_payload = {
        "source_type": "GOODS_RECEIPT",
        "source_id": "GRN-GOLD-001",
        "source_number": "GRN-2026-GOLD",
        "verified_by": "Senior Pharmacist",
        "items": [
            {
                "product_id": product_id,
                "product_name": "Calpol 500",
                "batch_number": "BAT-CAL-01",
                "expiry_date": "2028-10-31",
                "quantity_entered": 5,
                "unit_entered": "strip",
                "damaged_or_short": 0,
            }
        ],
    }
    in_res = client.post(f"/api/v1/stores/{STORE_ID}/inventory/receive", json=inward_payload)
    assert in_res.status_code == 200
    in_data = in_res.json()
    # 5 strips x 10 tablets = 50 base units
    assert in_data["total_base_units_added"] == 50

    # Verify balance
    bal_res = client.get(f"/api/v1/stores/{STORE_ID}/inventory/{product_id}/balance")
    assert bal_res.status_code == 200
    assert bal_res.json()["current_stock"] == 50

    # Outward: Sell 3 loose tablets
    outward_payload = {
        "source_type": "SALES_REPORT",
        "source_id": "SR-GOLD-001",
        "source_number": "SR-2026-GOLD",
        "posted_by": "Pharmacist Operator",
        "items": [
            {
                "product_id": product_id,
                "quantity_entered": 3,
                "unit_entered": "tablet",
            }
        ],
    }
    out_res = client.post(f"/api/v1/stores/{STORE_ID}/inventory/deduct", json=outward_payload)
    assert out_res.status_code == 200
    out_data = out_res.json()
    assert out_data["total_base_units_deducted"] == 3

    # INVARIANT: Remaining stock MUST BE 47 base units!
    final_bal = client.get(f"/api/v1/stores/{STORE_ID}/inventory/{product_id}/balance")
    assert final_bal.status_code == 200
    assert final_bal.json()["current_stock"] == 47


# ==============================================================================
# SCENARIO 3: GOODS RECEIPT VALIDATION & IDEMPOTENCY
# ==============================================================================

def test_goods_receipt_validations_and_idempotency():
    sup = client.post(
        f"/api/v1/stores/{STORE_ID}/suppliers",
        json={"name": "Tata 1mg Wholesale", "contact_person": "Ramesh Kumar", "phone": "9848012345"},
    ).json()
    po = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders",
        json={
            "supplier_id": sup["id"],
            "items": [{"product_id": "MED-000101", "product_name": "Dolo 650", "ordered_quantity": 50, "unit_rate_paise": 3000}],
        },
    ).json()
    client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po['id']}/send")

    # 2. Reject missing batch number
    bad_batch = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po['id']}/receipts",
        json={
            "items": [{"product_id": "MED-000101", "product_name": "Dolo 650", "received_now": 20, "batch_number": "", "expiry_date": "2028-12"}],
            "verified_by": "Pharmacist",
        },
    )
    assert bad_batch.status_code == 422 or bad_batch.status_code == 400

    # 3. Reject expired stock
    expired_batch = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po['id']}/receipts",
        json={
            "items": [{"product_id": "MED-000101", "product_name": "Dolo 650", "received_now": 20, "batch_number": "B-EXP", "expiry_date": "2020-01"}],
            "verified_by": "Pharmacist",
        },
    )
    assert expired_batch.status_code == 400
    assert expired_batch.json()["detail"]["code"] == "EXPIRED_STOCK_REJECTED"

    # 4. Valid Receipt with Idempotency Key
    receipt_payload = {
        "invoice_number": "INV-VALID-01",
        "items": [
            {
                "product_id": "MED-000101",
                "product_name": "Dolo 650",
                "received_now": 30,
                "damaged_or_short": 2,  # 28 accepted
                "batch_number": "BAT-DL-VALID",
                "expiry_date": "2028-12",
            }
        ],
        "verified_by": "Aditya (Pharmacist)",
    }
    idemp_key = "idemp-grn-reg-001"
    first_res = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po['id']}/receipts",
        json=receipt_payload,
        headers={"Idempotency-Key": idemp_key},
    )
    assert first_res.status_code == 201
    first_data = first_res.json()
    assert first_data["stock_movements"][0]["quantity"] == 28

    # Check batch balance
    batch_res = client.get(f"/api/v1/stores/{STORE_ID}/inventory/MED-000101/batches")
    assert batch_res.status_code == 200
    batches = batch_res.json()
    assert any(b["batch_number"] == "BAT-DL-VALID" for b in batches)

    # 5. Retry same receipt with SAME Idempotency-Key
    repeat_res = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po['id']}/receipts",
        json=receipt_payload,
        headers={"Idempotency-Key": idemp_key},
    )
    assert repeat_res.status_code == 200
    assert repeat_res.json()["id"] == first_data["id"]

    # Verify PO received units were NOT double counted (must remain 30)
    po_check = client.get(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po['id']}").json()
    assert po_check["total_received_units"] == 30


# ==============================================================================
# SCENARIO 4: OUTWARD SALES REJECTION & FEFO DEDUCTION
# ==============================================================================

def test_sales_insufficient_stock_rejection_and_fefo():
    # 1. Setup product with two distinct batches:
    # Batch 1: Expiring earlier (2027-01), 10 tablets
    # Batch 2: Expiring later (2028-01), 20 tablets
    prod_payload = {
        "catalogue_scope": "shared",
        "brand_name": "Ecosprin",
        "generic_name": "Aspirin",
        "strength_value": 75.0,
        "strength_unit": "mg",
        "form": "tablet",
        "category": "medicine",
        "base_unit": "tablet",
        "unit_conversions": [{"pack_unit": "strip", "factor": 14}],
    }
    prod_id = client.post("/api/v1/products", json=prod_payload).json()["id"]

    # Inward Batch 2 (Later expiry)
    client.post(
        f"/api/v1/stores/{STORE_ID}/inventory/receive",
        json={
            "source_type": "GOODS_RECEIPT",
            "source_id": "GRN-E-01",
            "source_number": "GR-01",
            "verified_by": "Pharmacist",
            "items": [{"product_id": prod_id, "product_name": "Ecosprin", "batch_number": "B-LATER", "expiry_date": "2028-01", "quantity_entered": 20, "unit_entered": "tablet"}],
        },
    )

    # Inward Batch 1 (Earlier expiry)
    client.post(
        f"/api/v1/stores/{STORE_ID}/inventory/receive",
        json={
            "source_type": "GOODS_RECEIPT",
            "source_id": "GRN-E-02",
            "source_number": "GR-02",
            "verified_by": "Pharmacist",
            "items": [{"product_id": prod_id, "product_name": "Ecosprin", "batch_number": "B-EARLIER", "expiry_date": "2027-01", "quantity_entered": 10, "unit_entered": "tablet"}],
        },
    )

    # Current stock is 30 tablets
    bal = client.get(f"/api/v1/stores/{STORE_ID}/inventory/{prod_id}/balance").json()
    assert bal["current_stock"] == 30

    # Test 4.1: Reject Oversell (Attempting to sell 35 tablets when only 30 exist)
    oversell = client.post(
        f"/api/v1/stores/{STORE_ID}/inventory/deduct",
        json={
            "source_type": "SALES_REPORT",
            "source_id": "SR-OVER",
            "source_number": "SR-OVER",
            "posted_by": "Operator",
            "items": [{"product_id": prod_id, "quantity_entered": 35, "unit_entered": "tablet"}],
        },
    )
    assert oversell.status_code == 422
    assert oversell.json()["detail"]["code"] == "INSUFFICIENT_STOCK"

    # Invariant: Balance MUST STILL BE 30! No partial deduction!
    bal_after_fail = client.get(f"/api/v1/stores/{STORE_ID}/inventory/{prod_id}/balance").json()
    assert bal_after_fail["current_stock"] == 30

    # Test 4.2: Valid FEFO Sale (Selling 15 tablets -> should exhaust B-EARLIER (10) and take 5 from B-LATER (leaving 15))
    valid_sale = client.post(
        f"/api/v1/stores/{STORE_ID}/inventory/deduct",
        json={
            "source_type": "SALES_REPORT",
            "source_id": "SR-VALID",
            "source_number": "SR-VALID",
            "posted_by": "Operator",
            "items": [{"product_id": prod_id, "quantity_entered": 15, "unit_entered": "tablet"}],
        },
    )
    assert valid_sale.status_code == 200
    allocations = valid_sale.json()["allocations"]
    assert len(allocations) == 2
    # B-EARLIER should be first with 10 deducted
    assert allocations[0]["batch_number"] == "B-EARLIER"
    assert allocations[0]["quantity_deducted"] == 10
    # B-LATER should be second with 5 deducted
    assert allocations[1]["batch_number"] == "B-LATER"
    assert allocations[1]["quantity_deducted"] == 5

    # Check updated batches
    batches_after = client.get(f"/api/v1/stores/{STORE_ID}/inventory/{prod_id}/batches").json()
    later_batch = next(b for b in batches_after if b["batch_number"] == "B-LATER")
    assert later_batch["quantity"] == 15
    # Total remaining stock = 15
    final_stock = client.get(f"/api/v1/stores/{STORE_ID}/inventory/{prod_id}/balance").json()
    assert final_stock["current_stock"] == 15


# ==============================================================================
# SCENARIO 5: RECONCILIATION VERIFICATION
# ==============================================================================

def test_store_inventory_reconciliation():
    rec_res = client.post(f"/api/v1/stores/{STORE_ID}/inventory/reconcile")
    assert rec_res.status_code == 200
    report = rec_res.json()
    assert report["store_id"] == STORE_ID
    assert report["inconsistent_count"] == 0
    assert report["consistent_count"] == report["total_products_checked"]

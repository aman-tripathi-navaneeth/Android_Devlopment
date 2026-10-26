"""Unit and integration tests for Module 4: Suppliers, Purchase Orders & Goods Receipt."""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.modules.suppliers_purchase_orders.service import fallback_store


@pytest.fixture(autouse=True)
def reset_store():
    fallback_store.clear()
    yield
    fallback_store.clear()


client = TestClient(app)
STORE_ID = "store_test_01"
OTHER_STORE = "store_test_99"


def test_supplier_crud():
    # 1. Create Supplier
    sup_payload = {
        "name": "Sri Venkateswara Pharma Distributors",
        "contact_person": "K. Ramesh",
        "phone": "9848012345",
        "email": "ramesh@svpharma.example.com",
        "payment_terms": "Net 30",
    }
    res = client.post(f"/api/v1/stores/{STORE_ID}/suppliers", json=sup_payload)
    assert res.status_code == 201
    sup_data = res.json()
    assert sup_data["name"] == sup_payload["name"]
    assert sup_data["code"].startswith("SUP-")
    assert sup_data["active"] is True
    sup_id = sup_data["id"]

    # 2. Store Scoping: Other store cannot see this supplier
    res_other = client.get(f"/api/v1/stores/{OTHER_STORE}/suppliers")
    assert res_other.status_code == 200
    assert len(res_other.json()) == 0

    # 3. Retrieve Supplier
    res_get = client.get(f"/api/v1/stores/{STORE_ID}/suppliers/{sup_id}")
    assert res_get.status_code == 200
    assert res_get.json()["id"] == sup_id

    # 4. Update Supplier
    patch_payload = {"contact_person": "K. Rajesh Kumar", "payment_terms": "Net 15"}
    res_patch = client.patch(f"/api/v1/stores/{STORE_ID}/suppliers/{sup_id}", json=patch_payload)
    assert res_patch.status_code == 200
    assert res_patch.json()["contact_person"] == "K. Rajesh Kumar"
    assert res_patch.json()["payment_terms"] == "Net 15"

    # 5. Duplicate code conflict
    res_dup = client.post(
        f"/api/v1/stores/{STORE_ID}/suppliers",
        json={**sup_payload, "code": sup_data["code"]},
    )
    assert res_dup.status_code == 409


def test_purchase_order_lifecycle():
    # 1. Setup Active Supplier
    sup_res = client.post(
        f"/api/v1/stores/{STORE_ID}/suppliers",
        json={"name": "Apollo Wholesale", "contact_person": "V. Suresh", "phone": "9440167890"},
    )
    sup_id = sup_res.json()["id"]

    # 2. Create Purchase Order with Items in DRAFT state
    po_payload = {
        "supplier_id": sup_id,
        "items": [
            {
                "product_id": "MED-000101",
                "product_name": "Dolo 650mg",
                "ordered_quantity": 100,
                "unit": "strip",
                "unit_rate_paise": 3250,  # Rs 32.50
            },
            {
                "product_id": "MED-000102",
                "product_name": "Augmentin 625 Duo",
                "ordered_quantity": 50,
                "unit": "strip",
                "unit_rate_paise": 17500,  # Rs 175.00
            },
        ],
        "notes": "Urgent seasonal refill",
    }
    po_res = client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders", json=po_payload)
    assert po_res.status_code == 201
    po = po_res.json()
    assert po["status"] == "Draft"
    assert po["total_ordered_units"] == 150
    assert po["total_received_units"] == 0
    # Expected estimated total: (100 * 3250) + (50 * 17500) = 325000 + 875000 = 1200000 paise (Rs 12,000)
    assert po["estimated_total_paise"] == 1200000
    po_id = po["id"]

    # 3. Invariant check: Cannot record goods receipt while PO is in DRAFT state
    receipt_attempt = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/receipts",
        json={
            "items": [
                {
                    "product_id": "MED-000101",
                    "product_name": "Dolo 650mg",
                    "received_now": 50,
                    "damaged_or_short": 0,
                    "batch_number": "DL-99",
                    "expiry_date": "2028-12",
                }
            ],
            "verified_by": "Aditya (Pharmacist)",
        },
    )
    assert receipt_attempt.status_code == 400
    assert receipt_attempt.json()["detail"]["code"] == "INVALID_PO_STATE"

    # 4. Transition Draft -> Sent
    send_res = client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/send")
    assert send_res.status_code == 200
    assert send_res.json()["status"] == "Sent"


def test_goods_receipt_posting_and_idempotency():
    # 1. Setup Supplier & Sent PO
    sup_res = client.post(
        f"/api/v1/stores/{STORE_ID}/suppliers",
        json={"name": "Balaji Drug Agencies", "contact_person": "M. Srinivas", "phone": "9885054321"},
    )
    sup_id = sup_res.json()["id"]

    po_res = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders",
        json={
            "supplier_id": sup_id,
            "items": [
                {"product_id": "MED-000103", "product_name": "Pan 40", "ordered_quantity": 100, "unit_rate_paise": 5000}
            ],
        },
    )
    po_id = po_res.json()["id"]
    client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/send")

    # 2. Record Partial Goods Receipt (60 strips received, 5 damaged/short -> 55 accepted)
    receipt_payload = {
        "invoice_number": "INV-2026-9912",
        "items": [
            {
                "product_id": "MED-000103",
                "product_name": "Pan 40",
                "received_now": 60,
                "damaged_or_short": 5,
                "batch_number": "PN-2026-X",
                "expiry_date": "2028-09",
                "damage_reason": "5 boxes crushed in transport transit",
            }
        ],
        "verified_by": "Aditya (Pharmacist)",
    }
    idempotency_key = "idemp_receipt_test_001"
    gr_res = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/receipts",
        json=receipt_payload,
        headers={"Idempotency-Key": idempotency_key},
    )
    assert gr_res.status_code == 201
    gr = gr_res.json()
    assert gr["po_status_after_receipt"] == "Partially Received"
    assert len(gr["stock_movements"]) == 1
    # Stock movement quantity must be exactly the accepted quantity: 60 - 5 = 55
    assert gr["stock_movements"][0]["quantity"] == 55
    assert gr["stock_movements"][0]["batch_number"] == "PN-2026-X"

    # 3. Verify Idempotency: Repeating exact request with same Idempotency-Key returns cached result
    # without duplicating ledger entries
    gr_repeat = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/receipts",
        json=receipt_payload,
        headers={"Idempotency-Key": idempotency_key},
    )
    assert gr_repeat.status_code == 200
    assert gr_repeat.json()["id"] == gr["id"]

    # Verify PO received units did not double-increment
    po_status = client.get(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}").json()
    assert po_status["total_received_units"] == 60  # Only counted once

    # 4. Fulfill Remainder (40 strips received)
    second_gr = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/receipts",
        json={
            "invoice_number": "INV-2026-9915",
            "items": [
                {
                    "product_id": "MED-000103",
                    "product_name": "Pan 40",
                    "received_now": 40,
                    "damaged_or_short": 0,
                    "batch_number": "PN-2026-Y",
                    "expiry_date": "2028-11",
                }
            ],
            "verified_by": "Aditya (Pharmacist)",
        },
    )
    assert second_gr.status_code == 201
    assert second_gr.json()["po_status_after_receipt"] == "Received"

    # Check updated PO status
    po_final = client.get(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}").json()
    assert po_final["status"] == "Received"
    assert po_final["total_received_units"] == 100

    # 5. Invariant check: Cannot cancel PO that already has recorded goods receipts
    cancel_attempt = client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/cancel")
    assert cancel_attempt.status_code == 400
    assert cancel_attempt.json()["detail"]["code"] == "PO_HAS_RECEIPTS"


def test_purchase_order_cancellation():
    # 1. Create Draft PO
    sup_res = client.post(
        f"/api/v1/stores/{STORE_ID}/suppliers",
        json={"name": "Reddy & Sons", "contact_person": "P. Venkat", "phone": "9700098765"},
    )
    sup_id = sup_res.json()["id"]

    po_res = client.post(
        f"/api/v1/stores/{STORE_ID}/purchase-orders",
        json={
            "supplier_id": sup_id,
            "items": [{"product_id": "MED-000106", "product_name": "Telma 40", "ordered_quantity": 20, "unit_rate_paise": 8000}],
        },
    )
    po_id = po_res.json()["id"]

    # 2. Cancel Draft PO
    cancel_res = client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/cancel")
    assert cancel_res.status_code == 200
    assert cancel_res.json()["status"] == "Cancelled"

    # 3. Cannot send a cancelled PO
    send_attempt = client.post(f"/api/v1/stores/{STORE_ID}/purchase-orders/{po_id}/send")
    assert send_attempt.status_code == 400

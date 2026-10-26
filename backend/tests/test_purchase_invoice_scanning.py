"""Unit and integration tests for Purchase Invoice Scanning & Inward."""

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_scan_and_extract_invoice():
    payload = {
        "invoice_number": "INV-2026-901",
        "supplier_id": "SUP-000101",
        "supplier_name": "Balaji Drug Agencies",
        "invoice_date": "2026-10-15",
        "file_name": "tax_invoice_balaji.pdf",
    }
    resp = client.post("/api/v1/invoices/scan", json=payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["invoice_number"] == "INV-2026-901"
    assert data["status"] == "PENDING_REVIEW"
    assert len(data["lines"]) == 3
    assert data["lines"][0]["matched_product_id"] == "MED-000101"
    assert data["lines"][0]["quantity"] == 10
    assert data["lines"][0]["free_quantity"] == 1


def test_duplicate_invoice_rejected():
    payload = {
        "invoice_number": "INV-2026-901",
        "supplier_id": "SUP-000101",
        "supplier_name": "Balaji Drug Agencies",
        "invoice_date": "2026-10-15",
        "file_name": "duplicate_attempt.pdf",
    }
    resp = client.post("/api/v1/invoices/scan", json=payload)
    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == "DUPLICATE_INVOICE"


def test_unresolved_lines_block_confirmation():
    # Scan a new invoice
    payload = {
        "invoice_number": "INV-2026-902",
        "supplier_id": "SUP-000102",
        "supplier_name": "Sri Venkateswara Pharma",
        "invoice_date": "2026-10-16",
        "file_name": "invoice_unresolved.pdf",
    }
    resp = client.post("/api/v1/invoices/scan", json=payload)
    inv_id = resp.json()["id"]

    # Mark line 2 as UNMATCHED with no matched_product_id
    lines = resp.json()["lines"]
    lines[1]["matched_product_id"] = None
    lines[1]["confidence"] = "UNMATCHED"

    patch_resp = client.patch(f"/api/v1/invoices/{inv_id}", json={"lines": lines})
    assert patch_resp.status_code == 200

    # Attempt confirmation -> must fail with 400
    confirm_resp = client.post(f"/api/v1/invoices/{inv_id}/confirm")
    assert confirm_resp.status_code == 400
    assert confirm_resp.json()["detail"]["code"] == "UNRESOLVED_LINES_REMAIN"


def test_confirm_invoice_and_idempotency():
    payload = {
        "invoice_number": "INV-2026-903",
        "supplier_id": "SUP-000101",
        "supplier_name": "Balaji Drug Agencies",
        "invoice_date": "2026-10-16",
        "file_name": "invoice_clean.pdf",
    }
    resp = client.post("/api/v1/invoices/scan", json=payload)
    inv_id = resp.json()["id"]

    headers = {"Idempotency-Key": "idemp-inv-key-903"}

    # First confirmation -> SUCCESS
    confirm_resp1 = client.post(f"/api/v1/invoices/{inv_id}/confirm", headers=headers)
    assert confirm_resp1.status_code == 200
    data1 = confirm_resp1.json()
    assert data1["success"] is True
    assert data1["status"] == "POSTED"
    assert data1["stock_movements_count"] == 3
    assert "receipt_number" in data1
    assert data1["total_quantity"] > 0

    # Retrieve receipt endpoint
    receipt_resp = client.get(f"/api/v1/invoices/{inv_id}/receipt")
    assert receipt_resp.status_code == 200
    receipt_data = receipt_resp.json()
    assert receipt_data["invoice_id"] == inv_id
    assert receipt_data["status"] == "POSTED"
    assert receipt_data["receipt_number"] == data1["receipt_number"]

    # Duplicate confirmation with SAME key -> returns identical result without duplicating movements
    confirm_resp2 = client.post(f"/api/v1/invoices/{inv_id}/confirm", headers=headers)
    assert confirm_resp2.status_code == 200
    data2 = confirm_resp2.json()
    assert data2["movement_ids"] == data1["movement_ids"]
    assert data2["posted_at"] == data1["posted_at"]



def test_invoice_rejection():
    payload = {
        "invoice_number": "INV-2026-904",
        "supplier_id": "SUP-000103",
        "supplier_name": "MedPlus Wholesale",
        "invoice_date": "2026-10-16",
        "file_name": "invoice_to_reject.pdf",
    }
    resp = client.post("/api/v1/invoices/scan", json=payload)
    inv_id = resp.json()["id"]

    reject_resp = client.post(f"/api/v1/invoices/{inv_id}/reject")
    assert reject_resp.status_code == 200
    assert reject_resp.json()["status"] == "REJECTED"

    # Confirming rejected invoice must fail
    confirm_resp = client.post(f"/api/v1/invoices/{inv_id}/confirm")
    assert confirm_resp.status_code == 400


def test_seeded_inv_9032_workflow():
    # 1. Fetch seeded invoice INV-9032 from workflow board
    resp = client.get("/api/v1/invoices/INV-9032")
    assert resp.status_code == 200
    data = resp.json()
    assert data["invoice_number"] == "INV-9032"
    assert data["supplier_name"] == "Sri Venkateswara"
    assert len(data["lines"]) >= 4

    # 2. Confirm and post invoice
    confirm_resp = client.post("/api/v1/invoices/INV-9032/confirm", headers={"Idempotency-Key": "idemp-seed-inv-9032"})
    assert confirm_resp.status_code == 200
    confirm_data = confirm_resp.json()
    assert confirm_data["status"] == "POSTED"
    assert confirm_data["receipt_number"] == "GRN-2026-00045"
    assert confirm_data["total_quantity"] == 70


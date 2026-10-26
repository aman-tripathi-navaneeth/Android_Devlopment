"""Integration tests for Module 8: Outward Sales Report Scanning."""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.modules.catalogue_search_units.service import fallback_catalogue_store
from app.modules.inventory.service import fallback_inventory_store
from app.modules.outward_sales_report_scanning.service import fallback_sales_report_store

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_stores():
    fallback_catalogue_store.clear()
    fallback_catalogue_store.seed_sample_data()
    fallback_inventory_store.clear()
    fallback_inventory_store.seed_defaults()
    fallback_sales_report_store.clear()
    yield
    fallback_catalogue_store.clear()
    fallback_catalogue_store.seed_sample_data()
    fallback_inventory_store.clear()
    fallback_inventory_store.seed_defaults()
    fallback_sales_report_store.clear()


def test_scan_and_extract_sales_report():
    # 1. Scan / Upload Report
    upload_payload = {
        "file_name": "EOD_Sales_Register_16Oct.jpg",
        "file_size_bytes": 1024000,
        "report_reference": "EOD-2026-10-16",
        "report_date": "2026-10-16",
        "scenario": "standard",
    }
    res = client.post("/api/v1/sales-reports/scan", json=upload_payload)
    assert res.status_code == 201
    data = res.json()
    assert data["report_reference"] == "EOD-2026-10-16"
    assert data["status"] == "PENDING_REVIEW"
    assert data["total_lines"] >= 4
    report_id = data["id"]

    # 2. Duplicate detection: Uploading same reference and date is rejected with 409
    res_dup = client.post("/api/v1/sales-reports/scan", json=upload_payload)
    assert res_dup.status_code == 409

    # 3. Retrieve report
    res_get = client.get(f"/api/v1/sales-reports/{report_id}")
    assert res_get.status_code == 200
    assert res_get.json()["id"] == report_id

    # 4. Check that loose tablet conversion took place for line 1 (Dolo 3 strips = 45 tablets)
    line1 = res_get.json()["lines"][0]
    assert line1["matched_brand_name"] == "Dolo"
    assert line1["quantity_entered"] == 3
    assert line1["converted_base_quantity"] == 45  # 3 strips x 15 tablets

    # 5. Confirm and post report -> stock deductions
    res_post = client.post(f"/api/v1/sales-reports/{report_id}/confirm-and-post")
    assert res_post.status_code == 200
    post_data = res_post.json()
    assert post_data["status"] == "POSTED"
    assert len(post_data["stock_movement_ids"]) > 0
    assert "receipt_reference" in post_data
    assert post_data["total_stock_deducted"] > 0

    # Retrieve receipt endpoint
    res_receipt = client.get(f"/api/v1/sales-reports/{report_id}/receipt")
    assert res_receipt.status_code == 200
    receipt_data = res_receipt.json()
    assert receipt_data["report_id"] == report_id
    assert receipt_data["status"] == "POSTED"
    assert receipt_data["receipt_reference"] == post_data["receipt_reference"]

    # 6. Verify posted status in report detail
    res_final = client.get(f"/api/v1/sales-reports/{report_id}")
    assert res_final.json()["status"] == "POSTED"



def test_resolve_unmatched_lines_flow():
    # Scan messy report with uncertain line
    upload_payload = {
        "file_name": "handwritten_notes.pdf",
        "report_reference": "NOTES-2026-10-16",
        "report_date": "2026-10-16",
        "scenario": "messy",
    }
    res = client.post("/api/v1/sales-reports/scan", json=upload_payload)
    assert res.status_code == 201
    data = res.json()
    report_id = data["id"]

    # Identify lines
    lines = data["lines"]
    assert any(l["confidence"] in ["LOW", "UNMATCHED"] for l in lines)

    # Manually resolve line 3 to Pan 40
    for l in lines:
        if l["line_number"] == 3:
            l["matched_product_id"] = "med-000103"
            l["unit_entered"] = "strip"
            l["quantity_entered"] = 1

    res_update = client.put(f"/api/v1/sales-reports/{report_id}/lines", json={"lines": lines})
    assert res_update.status_code == 200
    updated_report = res_update.json()
    assert updated_report["unresolved_lines"] == 0

    # Now report can be safely confirmed and posted
    res_confirm = client.post(f"/api/v1/sales-reports/{report_id}/confirm-and-post")
    assert res_confirm.status_code == 200
    assert res_confirm.json()["status"] == "POSTED"


def test_seeded_sr_1012_workflow():
    # 1. Fetch seeded sales report SR-1012 from workflow board
    res = client.get("/api/v1/sales-reports/SR-1012")
    assert res.status_code == 200
    data = res.json()
    assert data["report_reference"] == "SR-1012"
    assert data["report_date"] == "2026-10-12"
    assert len(data["lines"]) >= 4

    # 2. Confirm and post sales report
    confirm_res = client.post("/api/v1/sales-reports/SR-1012/confirm-and-post")
    assert confirm_res.status_code == 200
    confirm_data = confirm_res.json()
    assert confirm_data["status"] == "POSTED"
    assert confirm_data["receipt_reference"] == "SR-1012"
    assert confirm_data["total_stock_deducted"] == 22


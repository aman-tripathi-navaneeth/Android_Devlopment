"""Integration tests for Module 3: Medicine Catalogue, Search and Units."""

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.modules.catalogue_search_units.service import fallback_catalogue_store

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_catalogue():
    fallback_catalogue_store.clear()
    fallback_catalogue_store.seed_sample_data()
    yield
    fallback_catalogue_store.clear()
    fallback_catalogue_store.seed_sample_data()


def test_list_medicines_and_filters():
    # 1. List active medicines (seeded with 5 active, 1 inactive)
    res = client.get("/api/v1/products?status=active")
    assert res.status_code == 200
    items = res.json()
    assert len(items) >= 5
    for item in items:
        assert item["status"] == "active"

    # 2. Filter by category
    res_derma = client.get("/api/v1/products?category=derma&status=all")
    assert res_derma.status_code == 200
    assert any(m["brand_name"] == "Betadine" for m in res_derma.json())

    # 3. Filter by form
    res_tube = client.get("/api/v1/products?form=tube&status=all")
    assert res_tube.status_code == 200
    assert any(m["form"] == "tube" for m in res_tube.json())


def test_search_medicines_with_typo_tolerance():
    # 1. Exact match
    res_exact = client.get("/api/v1/products/search?q=Dolo")
    assert res_exact.status_code == 200
    names = [m["brand_name"] for m in res_exact.json()]
    assert "Dolo" in names

    # 2. Typo tolerance: "Dlo" should find "Dolo"
    res_typo = client.get("/api/v1/products/search?q=Dlo")
    assert res_typo.status_code == 200
    assert any(m["brand_name"] == "Dolo" for m in res_typo.json())

    # 3. Search by Generic name: "Paracetamol"
    res_generic = client.get("/api/v1/products/search?q=Paracetamol")
    assert res_generic.status_code == 200
    assert any("Dolo" in m["brand_name"] for m in res_generic.json())


def test_create_medicine_with_duplicate_warning():
    # Adding a medicine with the SAME brand name and SAME manufacturer triggers warning
    payload = {
        "catalogue_scope": "shared",
        "brand_name": "Dolo",
        "generic_name": "Paracetamol",
        "manufacturer": "Micro Labs",
        "strength_value": 250.0,
        "strength_unit": "mg",
        "form": "tablet",
        "category": "medicine",
        "base_unit": "tablet",
        "unit_conversions": [{"pack_unit": "strip", "factor": 10}],
    }
    res = client.post("/api/v1/products", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["brand_name"] == "Dolo"
    assert len(data["warnings"]) > 0
    assert "already exists in catalogue" in data["warnings"][0]

    # Trying to add the EXACT SAME strength and form is refused (409 Conflict)
    exact_duplicate_payload = {
        "catalogue_scope": "shared",
        "brand_name": "Dolo",
        "generic_name": "Paracetamol",
        "manufacturer": "Micro Labs",
        "strength_value": 650.0,
        "strength_unit": "mg",
        "form": "tablet",
        "category": "medicine",
        "base_unit": "tablet",
        "unit_conversions": [{"pack_unit": "strip", "factor": 15}],
    }
    res_conflict = client.post("/api/v1/products", json=exact_duplicate_payload)
    assert res_conflict.status_code == 409


def test_unit_conversion_service():
    # 1. Convert 3 packs of 15 tablets -> 45 tablets
    conv_payload = {
        "quantity": 3,
        "from_unit": "pack",
        "factor": 15,
        "pack_price": 150.0,
    }
    res = client.post("/api/v1/products/convert", json=conv_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["converted_quantity"] == 45
    assert data["loose_unit_price"] == 10.0

    # 2. Convert 293 tablets with factor 15 -> 19 strips + 8 loose
    res_loose = client.post(
        "/api/v1/products/convert",
        json={"quantity": 293, "from_unit": "base", "factor": 15},
    )
    assert res_loose.status_code == 200
    data_loose = res_loose.json()
    assert data_loose["packs"] == 19
    assert data_loose["loose_units"] == 8


def test_deactivate_medicine_rule():
    # Deactivate Dolo 650
    med_id = "med-000101"
    res = client.post(f"/api/v1/products/{med_id}/deactivate")
    assert res.status_code == 200
    assert res.json()["status"] == "inactive"

    # Inactive medicine no longer appears in active list
    res_list = client.get("/api/v1/products?status=active")
    active_ids = [m["id"] for m in res_list.json()]
    assert med_id not in active_ids

    # But still resolves directly so old invoices don't break
    res_detail = client.get(f"/api/v1/products/{med_id}")
    assert res_detail.status_code == 200
    assert res_detail.json()["id"] == med_id

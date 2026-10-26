from fastapi import APIRouter

from app.modules.catalogue_search_units.router import router as catalogue_router
from app.modules.inventory.router import router as inventory_router
from app.modules.ai_document_scanning.router import router as ai_document_scanning_router
from app.modules.outward_sales_report_scanning.router import router as sales_scanning_router
from app.modules.purchase_invoice_scanning.router import router as invoice_scanning_router
from app.modules.suppliers_purchase_orders.router import router as suppliers_po_router

api_router = APIRouter()
api_router.include_router(catalogue_router, tags=["Medicine Catalogue (Module 3)"])
api_router.include_router(suppliers_po_router, tags=["Suppliers & Purchase Orders (Module 4)"])
api_router.include_router(invoice_scanning_router, tags=["Purchase Invoices & Inward (Stock In)"])
api_router.include_router(sales_scanning_router, tags=["Outward Sales Report Scanning (Module 8)"])
api_router.include_router(inventory_router, tags=["Inventory scaffold"])
api_router.include_router(ai_document_scanning_router)

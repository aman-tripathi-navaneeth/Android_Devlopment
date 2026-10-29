from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.db.postgres import PostgresDatabase, create_postgres_database

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.postgres: PostgresDatabase | None = None
    app.state.db = None
    if settings.postgres_dsn.strip():
        app.state.postgres = await create_postgres_database(settings.postgres_dsn)
        app.state.db = app.state.postgres
    try:
        yield
    finally:
        if app.state.postgres is not None:
            await app.state.postgres.close()
            app.state.postgres = None
            app.state.db = None


app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.parsed_cors_origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["System"])
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get(settings.api_v1_prefix, tags=["System"])
async def api_root() -> dict[str, str]:
    """Human-friendly landing response for the versioned API prefix."""
    return {
        "name": settings.app_name,
        "version": "v1",
        "status": "ok",
        "docs": "/docs",
        "health": "/health",
        "readiness": "/ready",
    }


@app.get("/ready", tags=["System"])
async def ready() -> dict[str, str]:
    if app.state.postgres is None:
        from fastapi import HTTPException

        raise HTTPException(status_code=503, detail={"code": "DATABASE_NOT_CONFIGURED", "message": "Set POSTGRES_DSN to enable database access"})
    await app.state.postgres.ping()
    return {"status": "ready", "database": "PostgreSQL"}


@app.post("/api/v1/admin/clear-database", tags=["System"])
async def clear_database() -> dict[str, str]:
    if app.state.postgres is not None:
        await app.state.postgres.pool.execute("TRUNCATE TABLE app_documents")
    from app.modules.inventory.service import fallback_inventory_store
    from app.modules.catalogue_search_units.service import fallback_catalogue_store
    from app.modules.outward_sales_report_scanning.service import fallback_sales_report_store
    from app.modules.suppliers_purchase_orders.service import fallback_store
    fallback_inventory_store.clear()
    fallback_catalogue_store.clear()
    fallback_sales_report_store.clear()
    fallback_store.clear()
    return {"status": "ok", "message": "All database documents and fallback stores cleared"}


app.include_router(api_router, prefix=settings.api_v1_prefix)

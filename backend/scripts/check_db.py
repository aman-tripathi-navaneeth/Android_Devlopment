import asyncio
import sys
import os
sys.path.insert(0, os.path.abspath("."))
import asyncpg
from app.core.config import get_settings

async def main():
    s = get_settings()
    conn = await asyncpg.connect(s.postgres_dsn)
    rows = await conn.fetch("SELECT collection, count(*) as cnt FROM app_documents GROUP BY collection")
    print("Collections in DB:")
    for r in rows:
        print(f"  {r['collection']}: {r['cnt']}")
    
    # Also check products
    prod_rows = await conn.fetch("SELECT document_id, payload FROM app_documents WHERE collection = 'products'")
    print(f"\nProducts count: {len(prod_rows)}")
    import json
    for r in prod_rows:
        p = json.loads(r['payload']) if isinstance(r['payload'], str) else r['payload']
        print("  ", r['document_id'], p.get('brand_name'), p.get('id'), p.get('status'))

    # Test CatalogueService
    from app.db.postgres import PostgresDatabase
    db = PostgresDatabase(conn)
    from app.modules.catalogue_search_units.service import CatalogueService
    cs = CatalogueService(db=db)
    meds = await cs.list_medicines()
    print(f"\nCatalogueService.list_medicines() count: {len(meds)}")
    # Check salesReports
    sr_rows = await conn.fetch("SELECT document_id, payload FROM app_documents WHERE collection = 'salesReports'")
    print(f"\nSales reports count: {len(sr_rows)}")
    for r in sr_rows:
        s = json.loads(r['payload']) if isinstance(r['payload'], str) else r['payload']
        print("  ", r['document_id'], s.get('report_reference'), s.get('file_name'), s.get('status'))

    await conn.close()

if __name__ == '__main__':
    asyncio.run(main())

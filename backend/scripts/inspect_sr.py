import asyncio, asyncpg, json
from app.core.config import get_settings

async def main():
    s = get_settings()
    conn = await asyncpg.connect(s.postgres_dsn)
    rows = await conn.fetch("SELECT document_id, payload FROM app_documents WHERE collection = 'salesReports'")
    print(f"Total salesReports in PostgreSQL: {len(rows)}")
    for r in rows:
        p = json.loads(r['payload']) if isinstance(r['payload'], str) else r['payload']
        print(f" - ID: {r['document_id']} | Ref: {p.get('report_reference')} | Status: {p.get('status')} | Items: {len(p.get('lines', []))}")
    await conn.close()

if __name__ == '__main__':
    asyncio.run(main())

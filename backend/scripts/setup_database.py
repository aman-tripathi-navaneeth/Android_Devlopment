"""Initialize the PostgreSQL persistence schema for the Pharmacy API."""

import asyncio
import os

import asyncpg


SCHEMA = """
CREATE TABLE IF NOT EXISTS app_documents (
    collection TEXT NOT NULL,
    document_id TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (collection, document_id)
);
CREATE INDEX IF NOT EXISTS app_documents_collection_idx ON app_documents(collection);
CREATE INDEX IF NOT EXISTS app_documents_payload_gin_idx ON app_documents USING GIN(payload);
"""


async def main() -> None:
    dsn = os.getenv("POSTGRES_DSN", "")
    if not dsn:
        raise SystemExit(
            "POSTGRES_DSN is required, for example "
            "postgresql://postgres:postgres@localhost:5432/pharmacy_store_dev"
        )
    connection = await asyncpg.connect(dsn)
    try:
        await connection.execute(SCHEMA)
        print("PostgreSQL schema initialized: app_documents")
    finally:
        await connection.close()


if __name__ == "__main__":
    asyncio.run(main())

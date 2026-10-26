"""PostgreSQL persistence adapter used by the existing service layer.

The application services already expose a small document repository contract.
This adapter keeps that contract stable while moving durable storage to a
PostgreSQL JSONB table. It is a deliberate migration seam: business rules stay
in the services, while PostgreSQL owns persistence, indexes, and idempotency.
"""

from __future__ import annotations

import copy
import json
import re
import uuid
from dataclasses import dataclass
from datetime import date, datetime
from typing import Any, Iterable

import asyncpg


def _json_default(value: Any) -> str:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)


def _get_field(document: dict[str, Any], field: str) -> Any:
    value: Any = document
    for part in field.split("."):
        if not isinstance(value, dict):
            return None
        value = value.get(part)
    return value


def _matches(document: dict[str, Any], query: dict[str, Any]) -> bool:
    for field, expected in query.items():
        if field == "$or":
            if not any(_matches(document, item) for item in expected):
                return False
            continue
        if field == "$and":
            if not all(_matches(document, item) for item in expected):
                return False
            continue
        actual = _get_field(document, field)
        if isinstance(expected, dict):
            for operator, operand in expected.items():
                if operator == "$options":
                    continue
                if operator == "$regex":
                    flags = re.IGNORECASE if expected.get("$options") == "i" else 0
                    if re.search(str(operand), str(actual or ""), flags) is None:
                        return False
                elif operator == "$gt" and not (actual is not None and actual > operand):
                    return False
                elif operator == "$gte" and not (actual is not None and actual >= operand):
                    return False
                elif operator == "$lt" and not (actual is not None and actual < operand):
                    return False
                elif operator == "$lte" and not (actual is not None and actual <= operand):
                    return False
                elif operator == "$in" and actual not in operand:
                    return False
        elif actual != expected:
            return False
    return True


def _apply_update(document: dict[str, Any], update: dict[str, Any], inserting: bool = False) -> dict[str, Any]:
    result = copy.deepcopy(document)
    for field, value in update.get("$set", {}).items():
        result[field] = value
    for field, value in update.get("$inc", {}).items():
        result[field] = (result.get(field) or 0) + value
    if inserting:
        for field, value in update.get("$setOnInsert", {}).items():
            result[field] = value
    if not any(key.startswith("$") for key in update):
        result.update(update)
    return result


@dataclass
class PostgresResult:
    value: Any = None


class PostgresCursor:
    def __init__(self, collection: "PostgresCollection", query: dict[str, Any] | None = None):
        self.collection = collection
        self.query = query
        self._rows: list[dict[str, Any]] | None = None
        self._sort_field: str | None = None
        self._sort_direction = 1
        self._limit: int | None = None

    async def _ensure(self) -> None:
        if self._rows is None:
            documents = await self.collection._all()
            self._rows = [d for d in documents if not self.query or _matches(d, self.query)]
        if self._sort_field is not None:
            field = self._sort_field
            self._rows.sort(
                key=lambda row: (_get_field(row, field) is None, _get_field(row, field)),
                reverse=self._sort_direction < 0,
            )
        if self._limit is not None:
            self._rows = self._rows[: self._limit]

    def sort(self, field: str, direction: int) -> "PostgresCursor":
        self._sort_field = field
        self._sort_direction = direction
        return self

    def limit(self, count: int) -> "PostgresCursor":
        self._limit = count
        return self

    async def to_list(self, length: int | None = None) -> list[dict[str, Any]]:
        await self._ensure()
        rows = self._rows if length is None else self._rows[:length]
        return copy.deepcopy(rows)


class PostgresCollection:
    def __init__(self, database: "PostgresDatabase", name: str):
        self.database = database
        self.name = name

    async def _all(self) -> list[dict[str, Any]]:
        rows = await self.database.pool.fetch(
            "SELECT payload FROM app_documents WHERE collection = $1",
            self.name,
        )
        documents: list[dict[str, Any]] = []
        for row in rows:
            payload = row["payload"]
            # asyncpg may return JSONB as a decoded dict or as a JSON string,
            # depending on codec registration and driver version.
            if isinstance(payload, str):
                payload = json.loads(payload)
            if not isinstance(payload, dict):
                raise TypeError(f"Invalid JSONB document in collection {self.name}")
            documents.append(dict(payload))
        return documents

    @staticmethod
    def _document_id(document: dict[str, Any]) -> str:
        return str(document.get("_id") or document.get("id") or uuid.uuid4())

    async def find_one(self, query: dict[str, Any]) -> dict[str, Any] | None:
        for document in await self._all():
            if _matches(document, query):
                return copy.deepcopy(document)
        return None

    def find(self, query: dict[str, Any] | None = None) -> PostgresCursor:
        return PostgresCursor(self, query)

    async def insert_one(self, document: dict[str, Any]) -> PostgresResult:
        payload = copy.deepcopy(document)
        document_id = self._document_id(payload)
        payload.setdefault("_id", document_id)
        try:
            await self.database.pool.execute(
                "INSERT INTO app_documents(collection, document_id, payload) VALUES ($1, $2, $3::jsonb)",
                self.name,
                document_id,
                json.dumps(payload, default=_json_default),
            )
        except asyncpg.UniqueViolationError as exc:
            raise ValueError(f"Duplicate document in {self.name}: {document_id}") from exc
        return PostgresResult(document_id)

    async def insert_many(self, documents: Iterable[dict[str, Any]]) -> None:
        for document in documents:
            await self.insert_one(document)

    async def update_one(self, query: dict[str, Any], update: dict[str, Any], upsert: bool = False) -> PostgresResult:
        existing = await self.find_one(query)
        if existing is None:
            if not upsert:
                return PostgresResult()
            base = {k: v for k, v in query.items() if not k.startswith("$") and not isinstance(v, dict)}
            return await self.insert_one(_apply_update(base, update, inserting=True))
        updated = _apply_update(existing, update)
        document_id = self._document_id(existing)
        await self.database.pool.execute(
            "UPDATE app_documents SET payload = $1::jsonb, updated_at = now() WHERE collection = $2 AND document_id = $3",
            json.dumps(updated, default=_json_default), self.name, document_id,
        )
        return PostgresResult(document_id)

    async def find_one_and_update(self, query: dict[str, Any], update: dict[str, Any], **kwargs: Any) -> dict[str, Any] | None:
        existing = await self.find_one(query)
        if existing is None and kwargs.get("upsert"):
            base = {k: v for k, v in query.items() if not k.startswith("$") and not isinstance(v, dict)}
            existing = _apply_update(base, update, inserting=True)
            await self.insert_one(existing)
            return existing
        if existing is None:
            return None
        updated = _apply_update(existing, update)
        await self.update_one(query, {"$set": updated})
        return updated

    async def distinct(self, field: str, query: dict[str, Any] | None = None) -> list[Any]:
        documents = await self._all()
        values = {_get_field(d, field) for d in documents if not query or _matches(d, query)}
        return list(values)


class PostgresDatabase:
    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    def __getitem__(self, name: str) -> PostgresCollection:
        return PostgresCollection(self, name)

    def __getattr__(self, name: str) -> PostgresCollection:
        if name.startswith("__"):
            raise AttributeError(name)
        return self[name]

    async def ping(self) -> None:
        await self.pool.fetchval("SELECT 1")

    async def close(self) -> None:
        await self.pool.close()


async def create_postgres_database(dsn: str) -> PostgresDatabase:
    pool = await asyncpg.create_pool(dsn=dsn, min_size=1, max_size=10, command_timeout=30)
    await pool.execute(
        """CREATE TABLE IF NOT EXISTS app_documents (
            collection TEXT NOT NULL,
            document_id TEXT NOT NULL,
            payload JSONB NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
            PRIMARY KEY (collection, document_id)
        )"""
    )
    await pool.execute("CREATE INDEX IF NOT EXISTS app_documents_collection_idx ON app_documents(collection)")
    await pool.execute("CREATE INDEX IF NOT EXISTS app_documents_payload_gin_idx ON app_documents USING GIN(payload)")
    return PostgresDatabase(pool)

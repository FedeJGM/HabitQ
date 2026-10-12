import uuid
from datetime import datetime, timedelta, timezone

from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument
from app.services.document_history_service import list_ingested_documents


class _Query:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def filter(self, *clauses) -> "_Query":
        rows = self._rows
        for clause in clauses:
            key = clause.left.key
            value = clause.right.value
            rows = [r for r in rows if getattr(r, key) == value]
        return _Query(rows)

    def all(self) -> list[object]:
        return list(self._rows)


class _Db:
    def __init__(self, rows: list[object]) -> None:
        self._rows = rows

    def query(self, model) -> _Query:
        return _Query([r for r in self._rows if isinstance(r, model)])


def _doc(title: str, days_ago: int, domain: str = "sleep") -> ScientificDocument:
    return ScientificDocument(
        id=uuid.uuid4(), title=title, language="eng", domain=domain, file_path="f.pdf",
        created_at=datetime.now(timezone.utc) - timedelta(days=days_ago),
    )


def _chunk(doc: ScientificDocument, index: int) -> DocumentChunk:
    return DocumentChunk(id=uuid.uuid4(), document_id=doc.id, content="x", chunk_index=index, embedding=[0.0])


def test_documents_are_ordered_newest_first_with_their_chunk_counts() -> None:
    old, new = _doc("Old", 5), _doc("New", 1)
    db = _Db([old, new, _chunk(old, 0), _chunk(new, 0), _chunk(new, 1), _chunk(new, 2)])

    result = list_ingested_documents(db)

    assert [(doc.title, count) for doc, count in result] == [("New", 3), ("Old", 1)]


def test_domain_filter_keeps_only_that_domain() -> None:
    db = _Db([_doc("A", 1, "sleep"), _doc("B", 2, "stress")])

    result = list_ingested_documents(db, domain="stress")

    assert [(doc.title, count) for doc, count in result] == [("B", 0)]

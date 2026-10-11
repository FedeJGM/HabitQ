import uuid
from pathlib import Path

import pytest

from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument
from app.services.ingestion_service import reindex_document


class _FakeTokenizer:
    def encode(self, text: str, add_special_tokens: bool = True) -> list[str]:
        tokens = text.split()
        return ["<s>", *tokens, "</s>"] if add_special_tokens else tokens


class _FakeModel:
    tokenizer = _FakeTokenizer()

    def __init__(self, *, fail: bool = False) -> None:
        self._fail = fail

    def encode(self, texts: list[str]) -> list[list[float]]:
        if self._fail:
            raise RuntimeError("embedding failed")
        return [[9.0, float(len(text))] for text in texts]


class _FakeQuery:
    def __init__(self, items: list[object]) -> None:
        self._items = items

    def filter(self, expr) -> "_FakeQuery":
        return _FakeQuery([i for i in self._items if getattr(i, expr.left.key) == expr.right.value])

    def all(self) -> list[object]:
        return list(self._items)


class _FakeDb:
    def __init__(self, items: list[object]) -> None:
        self.items = list(items)
        self.commits = 0

    def query(self, model) -> _FakeQuery:
        return _FakeQuery([i for i in self.items if isinstance(i, model)])

    def add(self, obj: object) -> None:
        self.items.append(obj)

    def delete(self, obj: object) -> None:
        self.items = [i for i in self.items if i is not obj]

    def commit(self) -> None:
        self.commits += 1


def _document() -> ScientificDocument:
    return ScientificDocument(id=uuid.uuid4(), title="T", language="en", file_path="paper.pdf")


def _old_chunk(document: ScientificDocument, index: int, page: int) -> DocumentChunk:
    return DocumentChunk(
        id=uuid.uuid4(), document_id=document.id, content=f"old text {index}",
        page_number=page, chunk_index=index, embedding=[1.0],
    )


def _chunks_of(db: _FakeDb, document: ScientificDocument) -> list[DocumentChunk]:
    return [i for i in db.items if isinstance(i, DocumentChunk) and i.document_id == document.id]


def test_reindex_rebuilds_the_chunks_from_the_pdf_when_it_exists() -> None:
    document = _document()
    db = _FakeDb([document, _old_chunk(document, 0, 1)])

    def pages(path: Path) -> list[tuple[int, str]]:
        return [(1, "alpha beta"), (2, "gamma delta")]

    count = reindex_document(
        db, document=document, model=_FakeModel(),
        extract_pages_fn=pages, pdf_exists_fn=lambda path: True,
    )

    chunks = _chunks_of(db, document)
    assert count == 2
    assert [c.content for c in chunks] == ["alpha beta", "gamma delta"]
    assert [(c.page_number, c.chunk_index) for c in chunks] == [(1, 0), (2, 1)]
    assert all(c.embedding[0] == 9.0 for c in chunks)
    assert db.commits == 1


def test_reindex_reembeds_the_stored_text_when_the_pdf_is_gone() -> None:
    document = _document()
    db = _FakeDb([document, _old_chunk(document, 0, 3), _old_chunk(document, 1, 4)])

    count = reindex_document(
        db, document=document, model=_FakeModel(),
        extract_pages_fn=lambda path: pytest.fail("must not read a missing PDF"),
        pdf_exists_fn=lambda path: False,
    )

    chunks = _chunks_of(db, document)
    assert count == 2
    assert [c.content for c in chunks] == ["old text 0", "old text 1"]
    assert [(c.page_number, c.chunk_index) for c in chunks] == [(3, 0), (4, 1)]
    assert all(c.embedding[0] == 9.0 for c in chunks)
    assert db.commits == 1


def test_reindex_keeps_the_old_chunks_if_embedding_fails() -> None:
    document = _document()
    old = _old_chunk(document, 0, 1)
    db = _FakeDb([document, old])

    with pytest.raises(RuntimeError, match="embedding failed"):
        reindex_document(
            db, document=document, model=_FakeModel(fail=True),
            extract_pages_fn=lambda path: [(1, "alpha")], pdf_exists_fn=lambda path: True,
        )

    assert _chunks_of(db, document) == [old]
    assert old.embedding == [1.0]
    assert db.commits == 0


def test_reindex_leaves_other_documents_alone() -> None:
    document, other = _document(), _document()
    other_chunk = _old_chunk(other, 0, 1)
    db = _FakeDb([document, other, other_chunk, _old_chunk(document, 0, 1)])

    reindex_document(
        db, document=document, model=_FakeModel(),
        extract_pages_fn=lambda path: [(1, "alpha")], pdf_exists_fn=lambda path: True,
    )

    assert _chunks_of(db, other) == [other_chunk]
    assert other_chunk.embedding == [1.0]

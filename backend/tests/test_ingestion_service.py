import uuid
from pathlib import Path

import pytest

from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument
from app.services.ingestion_service import (
    chunk_text,
    clean_text,
    embed_chunks,
    extract_pages,
    ingest_document,
)

_PDF_DIR = Path(__file__).resolve().parents[2] / "ingestion" / "data" / "scientific_documents"


def _word_tokenize(text: str) -> list[str]:
    return text.split()


class _FakeTokenizer:
    def encode(self, text: str) -> list[str]:
        return text.split()


class _FakeEmbeddingModel:
    tokenizer = _FakeTokenizer()

    def encode(self, texts: list[str]) -> list[list[float]]:
        return [[float(len(text))] for text in texts]


class _FakeDb:
    def __init__(self) -> None:
        self.added: list[object] = []

    def add(self, obj: object) -> None:
        self.added.append(obj)

    def commit(self) -> None:
        pass

    def refresh(self, obj: object) -> None:
        if getattr(obj, "id", None) is None:
            obj.id = uuid.uuid4()


def _fake_extract_pages(pdf_path: Path) -> list[tuple[int, str]]:
    return [
        (1, "alpha " * 10),
        (2, "beta " * 5),
    ]


# --- extract_pages ---


def test_extract_pages_returns_nonempty_text_for_real_pdf() -> None:
    pytest.importorskip("pymupdf", reason="pymupdf not installed in this environment")
    pdf_path = _PDF_DIR / "cdc-healthy-sleep-healthy-brain.pdf"
    pages = extract_pages(pdf_path)
    assert len(pages) > 0
    page_number, text = pages[0]
    assert page_number == 1
    assert isinstance(text, str)
    assert any(text.strip() for _, text in pages)


def test_extract_pages_page_numbers_are_sequential() -> None:
    pytest.importorskip("pymupdf", reason="pymupdf not installed in this environment")
    pdf_path = _PDF_DIR / "who-physical-activity-at-a-glance.pdf"
    pages = extract_pages(pdf_path)
    assert [page_number for page_number, _ in pages] == list(range(1, len(pages) + 1))


# --- clean_text ---


def test_clean_text_collapses_repeated_whitespace() -> None:
    assert clean_text("Hello   world\n\nFoo") == "Hello world Foo"


def test_clean_text_rejoins_hyphenated_line_breaks() -> None:
    assert clean_text("exam-\nple text") == "example text"


def test_clean_text_strips_leading_and_trailing_whitespace() -> None:
    assert clean_text("  \n  padded text  \n  ") == "padded text"


# --- chunk_text ---


def test_chunk_text_splits_by_real_token_count() -> None:
    text = " ".join(f"w{i}" for i in range(10))
    chunks = chunk_text(text, tokenize=_word_tokenize, chunk_size_tokens=5, overlap_tokens=2)
    assert chunks == [
        "w0 w1 w2 w3 w4",
        "w3 w4 w5 w6 w7",
        "w6 w7 w8 w9",
    ]


def test_chunk_text_returns_empty_list_for_empty_text() -> None:
    assert chunk_text("", tokenize=_word_tokenize, chunk_size_tokens=5, overlap_tokens=2) == []


def test_chunk_text_single_chunk_when_under_limit() -> None:
    text = "a b c"
    chunks = chunk_text(text, tokenize=_word_tokenize, chunk_size_tokens=10, overlap_tokens=2)
    assert chunks == ["a b c"]


# --- embed_chunks ---


def test_embed_chunks_delegates_to_model_encode() -> None:
    model = _FakeEmbeddingModel()
    result = embed_chunks(["ab", "abcd"], model)
    assert result == [[2.0], [4.0]]


# --- ingest_document ---


def test_ingest_document_creates_document_and_chunks() -> None:
    db = _FakeDb()
    model = _FakeEmbeddingModel()

    document = ingest_document(
        db,
        pdf_path=Path("fake.pdf"),
        title="Physical Activity Guidance",
        language="en",
        model=model,
        organization="WHO",
        extract_pages_fn=_fake_extract_pages,
    )

    assert isinstance(document, ScientificDocument)
    assert document.title == "Physical Activity Guidance"
    assert document.organization == "WHO"
    assert document.file_path == "fake.pdf"

    chunks = [obj for obj in db.added if isinstance(obj, DocumentChunk)]
    assert len(chunks) > 0
    assert all(chunk.document_id == document.id for chunk in chunks)
    assert [chunk.chunk_index for chunk in chunks] == list(range(len(chunks)))
    assert {chunk.page_number for chunk in chunks} == {1, 2}
    assert all(isinstance(chunk.embedding, list) for chunk in chunks)


def test_ingest_document_skips_empty_pages() -> None:
    db = _FakeDb()
    model = _FakeEmbeddingModel()

    def extract_with_blank_page(pdf_path: Path) -> list[tuple[int, str]]:
        return [(1, "content here"), (2, "   \n  "), (3, "more content")]

    document = ingest_document(
        db,
        pdf_path=Path("fake.pdf"),
        title="T",
        language="en",
        model=model,
        extract_pages_fn=extract_with_blank_page,
    )

    chunks = [obj for obj in db.added if isinstance(obj, DocumentChunk)]
    assert {chunk.page_number for chunk in chunks} == {1, 3}

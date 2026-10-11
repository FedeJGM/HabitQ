import uuid
from pathlib import Path

import pytest

from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument
from app.services.ingestion_service import (
    already_ingested,
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
    def encode(self, text: str, add_special_tokens: bool = True) -> list[str]:
        # Like a real tokenizer, adds begin/end markers unless told not to.
        tokens = text.split()
        return ["<s>", *tokens, "</s>"] if add_special_tokens else tokens


class _FakeEmbeddingModel:
    tokenizer = _FakeTokenizer()

    def encode(self, texts: list[str]) -> list[list[float]]:
        return [[float(len(text))] for text in texts]


class _FakeQuery:
    def __init__(self, results: list[object]) -> None:
        self._results = results

    def filter(self, *args, **kwargs) -> "_FakeQuery":
        return self

    def first(self) -> object | None:
        return self._results[0] if self._results else None


class _FakeDb:
    def __init__(self) -> None:
        self.added: list[object] = []
        self.commits = 0

    def add(self, obj: object) -> None:
        self.added.append(obj)

    def flush(self) -> None:
        for obj in self.added:
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()

    def commit(self) -> None:
        self.commits += 1

    def refresh(self, obj: object) -> None:
        if getattr(obj, "id", None) is None:
            obj.id = uuid.uuid4()

    def query(self, model):
        return _FakeQuery([obj for obj in self.added if isinstance(obj, model)])


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


def test_ingest_document_stores_doi_and_domain() -> None:
    db = _FakeDb()

    document = ingest_document(
        db,
        pdf_path=Path("fake.pdf"),
        title="T",
        language="en",
        model=_FakeEmbeddingModel(),
        doi="10.1/abc",
        domain="sleep",
        extract_pages_fn=_fake_extract_pages,
    )

    assert document.doi == "10.1/abc"
    assert document.domain == "sleep"


def test_ingest_document_commits_once_so_a_failure_leaves_no_orphan_document() -> None:
    class _ExplodingModel(_FakeEmbeddingModel):
        def encode(self, texts: list[str]) -> list[list[float]]:
            raise RuntimeError("embedding failed")

    db = _FakeDb()

    with pytest.raises(RuntimeError, match="embedding failed"):
        ingest_document(
            db,
            pdf_path=Path("fake.pdf"),
            title="T",
            language="en",
            model=_ExplodingModel(),
            extract_pages_fn=_fake_extract_pages,
        )

    assert db.commits == 0


def test_ingest_document_commits_document_and_chunks_together() -> None:
    db = _FakeDb()

    ingest_document(
        db,
        pdf_path=Path("fake.pdf"),
        title="T",
        language="en",
        model=_FakeEmbeddingModel(),
        extract_pages_fn=_fake_extract_pages,
    )

    assert db.commits == 1


def test_ingest_document_never_makes_chunks_longer_than_the_model_can_embed() -> None:
    # Text past the model's max_seq_length is silently dropped from the
    # embedding, so a chunk must fit it (minus room for special tokens).
    class _SmallModel(_FakeEmbeddingModel):
        max_seq_length = 10

    db = _FakeDb()

    def long_page(pdf_path: Path) -> list[tuple[int, str]]:
        return [(1, " ".join(f"w{i}" for i in range(40)))]

    ingest_document(
        db,
        pdf_path=Path("fake.pdf"),
        title="T",
        language="en",
        model=_SmallModel(),
        extract_pages_fn=long_page,
    )

    chunks = [obj for obj in db.added if isinstance(obj, DocumentChunk)]
    assert len(chunks) > 1
    assert all(len(chunk.content.split()) <= 8 for chunk in chunks)


def test_ingest_document_counts_tokens_without_the_special_markers() -> None:
    # Counting each word with its own <s>/</s> would triple its weight and
    # shrink every chunk to a third of what the model can embed.
    class _SmallModel(_FakeEmbeddingModel):
        max_seq_length = 10

    db = _FakeDb()

    def long_page(pdf_path: Path) -> list[tuple[int, str]]:
        return [(1, " ".join(f"w{i}" for i in range(40)))]

    ingest_document(
        db, pdf_path=Path("fake.pdf"), title="T", language="en",
        model=_SmallModel(), extract_pages_fn=long_page,
    )

    chunks = [obj for obj in db.added if isinstance(obj, DocumentChunk)]
    assert len(chunks[0].content.split()) == 8


def test_ingest_document_keeps_the_default_chunk_size_for_models_without_a_limit() -> None:
    db = _FakeDb()

    def mid_page(pdf_path: Path) -> list[tuple[int, str]]:
        return [(1, " ".join(f"w{i}" for i in range(300)))]

    ingest_document(
        db, pdf_path=Path("fake.pdf"), title="T", language="en",
        model=_FakeEmbeddingModel(), extract_pages_fn=mid_page,
    )

    assert len([obj for obj in db.added if isinstance(obj, DocumentChunk)]) == 1


# --- already_ingested ---


def test_already_ingested_returns_false_when_no_documents_exist() -> None:
    db = _FakeDb()
    assert already_ingested(db, "some.pdf") is False


def test_already_ingested_returns_true_when_a_document_exists() -> None:
    db = _FakeDb()
    db.add(ScientificDocument(title="T", language="en", file_path="some.pdf"))
    assert already_ingested(db, "some.pdf") is True


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

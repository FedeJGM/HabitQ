import re
from pathlib import Path
from typing import Callable

from sqlalchemy.orm import Session

from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument

_HYPHEN_LINE_BREAK = re.compile(r"-\n")
_WHITESPACE_RUN = re.compile(r"\s+")


def extract_pages(pdf_path: Path) -> list[tuple[int, str]]:
    import pymupdf  # imported lazily so the rest of this module works without it installed

    pages: list[tuple[int, str]] = []
    with pymupdf.open(pdf_path) as doc:
        for page_number, page in enumerate(doc, start=1):
            pages.append((page_number, page.get_text()))
    return pages


def clean_text(text: str) -> str:
    text = _HYPHEN_LINE_BREAK.sub("", text)
    text = _WHITESPACE_RUN.sub(" ", text)
    return text.strip()


def chunk_text(
    text: str,
    *,
    tokenize: Callable[[str], list],
    chunk_size_tokens: int = 1000,
    overlap_tokens: int = 125,
) -> list[str]:
    words = text.split()
    if not words:
        return []

    token_counts = [len(tokenize(word)) for word in words]
    n = len(words)

    chunks: list[str] = []
    start = 0
    while start < n:
        end = start
        total = 0
        while end < n and (total + token_counts[end] <= chunk_size_tokens or end == start):
            total += token_counts[end]
            end += 1
        chunks.append(" ".join(words[start:end]))
        if end >= n:
            break

        back = end
        overlap_total = 0
        while back > start and overlap_total < overlap_tokens:
            back -= 1
            overlap_total += token_counts[back]
        start = back if back > start else end

    return chunks


_DEFAULT_CHUNK_TOKENS = 1000
_DEFAULT_OVERLAP_TOKENS = 125
_SPECIAL_TOKENS = 2  # [CLS]/[SEP]-style markers the model adds around the text


def chunk_budget(model) -> tuple[int, int]:
    """(chunk size, overlap) in tokens. Embedding models silently drop whatever
    exceeds `max_seq_length`, so a chunk must fit it: otherwise the tail of the
    chunk is stored and cited but never searchable."""
    limit = getattr(model, "max_seq_length", None)
    if not limit:
        return _DEFAULT_CHUNK_TOKENS, _DEFAULT_OVERLAP_TOKENS

    size = max(1, min(_DEFAULT_CHUNK_TOKENS, limit - _SPECIAL_TOKENS))
    return size, min(_DEFAULT_OVERLAP_TOKENS, size // 8)


def already_ingested(db: Session, file_path: str) -> bool:
    return (
        db.query(ScientificDocument)
        .filter(ScientificDocument.file_path == file_path)
        .first()
        is not None
    )


def embed_chunks(texts: list[str], model) -> list[list[float]]:
    embeddings = model.encode(texts)
    return [[float(value) for value in vector] for vector in embeddings]


def ingest_document(
    db: Session,
    *,
    pdf_path: Path,
    title: str,
    language: str,
    model,
    authors: str | None = None,
    organization: str | None = None,
    year: int | None = None,
    source_url: str | None = None,
    doi: str | None = None,
    domain: str | None = None,
    extract_pages_fn: Callable[[Path], list[tuple[int, str]]] = extract_pages,
) -> ScientificDocument:
    pages = extract_pages_fn(pdf_path)

    document = ScientificDocument(
        title=title,
        authors=authors,
        organization=organization,
        year=year,
        language=language,
        source_url=source_url,
        doi=doi,
        domain=domain,
        file_path=str(pdf_path),
    )
    db.add(document)
    # Flush (not commit) to get document.id: the document and its chunks are
    # committed together below, so a failure while embedding leaves no orphan
    # document without chunks behind.
    db.flush()

    for chunk in build_chunks(document.id, pages, model):
        db.add(chunk)

    db.commit()
    db.refresh(document)
    return document


def build_chunks(document_id, pages: list[tuple[int, str]], model) -> list[DocumentChunk]:
    chunk_size, overlap = chunk_budget(model)

    def count_tokens(word: str) -> list:
        # Without the begin/end markers: encoding each word alone would add
        # them to every word and make a chunk look ~3x bigger than it is.
        return model.tokenizer.encode(word, add_special_tokens=False)

    chunks: list[DocumentChunk] = []
    for page_number, raw_text in pages:
        text = clean_text(raw_text)
        if not text:
            continue

        page_chunks = chunk_text(
            text, tokenize=count_tokens, chunk_size_tokens=chunk_size, overlap_tokens=overlap
        )
        if not page_chunks:
            continue

        embeddings = embed_chunks(page_chunks, model)
        for content, embedding in zip(page_chunks, embeddings):
            chunks.append(
                DocumentChunk(
                    document_id=document_id,
                    content=content,
                    page_number=page_number,
                    chunk_index=len(chunks),
                    embedding=embedding,
                )
            )
    return chunks


def reindex_document(
    db: Session,
    *,
    document: ScientificDocument,
    model,
    extract_pages_fn: Callable[[Path], list[tuple[int, str]]] = extract_pages,
    pdf_exists_fn: Callable[[Path], bool] = Path.exists,
) -> int:
    """Rebuilds a document's chunks and embeddings with `model` (needed after
    changing the embedding model: vectors from different models aren't
    comparable). Uses the PDF when it is still on disk, so chunk sizes follow
    the new model's limit; otherwise re-embeds the stored text. The old chunks
    are only replaced if the whole new set was built, in a single commit."""
    old_chunks = sorted(
        db.query(DocumentChunk).filter(DocumentChunk.document_id == document.id).all(),
        key=lambda chunk: chunk.chunk_index,
    )

    pdf_path = Path(document.file_path)
    if pdf_exists_fn(pdf_path):
        new_chunks = build_chunks(document.id, extract_pages_fn(pdf_path), model)
    else:
        embeddings = embed_chunks([chunk.content for chunk in old_chunks], model) if old_chunks else []
        new_chunks = [
            DocumentChunk(
                document_id=document.id,
                content=old.content,
                page_number=old.page_number,
                chunk_index=old.chunk_index,
                embedding=embedding,
            )
            for old, embedding in zip(old_chunks, embeddings)
        ]

    for chunk in old_chunks:
        db.delete(chunk)
    for chunk in new_chunks:
        db.add(chunk)
    db.commit()
    return len(new_chunks)

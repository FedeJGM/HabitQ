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
        file_path=str(pdf_path),
    )
    db.add(document)
    db.commit()
    db.refresh(document)

    chunk_index = 0
    for page_number, raw_text in pages:
        text = clean_text(raw_text)
        if not text:
            continue

        page_chunks = chunk_text(text, tokenize=model.tokenizer.encode)
        if not page_chunks:
            continue

        embeddings = embed_chunks(page_chunks, model)
        for content, embedding in zip(page_chunks, embeddings):
            db.add(
                DocumentChunk(
                    document_id=document.id,
                    content=content,
                    page_number=page_number,
                    chunk_index=chunk_index,
                    embedding=embedding,
                )
            )
            chunk_index += 1

    db.commit()
    db.refresh(document)
    return document

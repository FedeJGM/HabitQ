from collections import Counter
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.document_candidate import DocumentCandidate
from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument


def list_ingested_documents(
    db: Session, domain: str | None = None
) -> list[tuple[ScientificDocument, int]]:
    """Indexed documents (panel and CLI alike), newest first, with their chunk count."""
    query = db.query(ScientificDocument)
    if domain is not None:
        query = query.filter(ScientificDocument.domain == domain)
    documents = sorted(query.all(), key=lambda doc: doc.created_at, reverse=True)
    if not documents:
        return []

    # Counted in Python (not GROUP BY) on purpose: the corpus is small and it
    # keeps the in-memory test doubles simple.
    ids = {doc.id for doc in documents}
    counts = Counter(
        chunk.document_id for chunk in db.query(DocumentChunk).all() if chunk.document_id in ids
    )
    return [(doc, counts[doc.id]) for doc in documents]


def delete_document(db: Session, document: ScientificDocument) -> None:
    """Removes a document and its chunks in a single transaction.

    The chunk FK has no ON DELETE CASCADE, so they go first. The PDF stays on
    disk. The candidate it came from is marked rejected so discovery never
    proposes the same paper again.
    """
    for chunk in db.query(DocumentChunk).filter(DocumentChunk.document_id == document.id).all():
        db.delete(chunk)

    if document.doi:
        doi = document.doi.lower()
        ingested = db.query(DocumentCandidate).filter(DocumentCandidate.status == "ingested").all()
        for candidate in ingested:
            if candidate.doi and candidate.doi.lower() == doi:
                candidate.status = "rejected"
                candidate.reviewed_at = datetime.now(timezone.utc)

    db.delete(document)
    db.commit()

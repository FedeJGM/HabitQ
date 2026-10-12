from collections import Counter

from sqlalchemy.orm import Session

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

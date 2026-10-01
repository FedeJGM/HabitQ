from sqlalchemy.orm import Session

from app.models.document_chunk import DocumentChunk


def cosine_similarity(a: list[float], b: list[float]) -> float:
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(y * y for y in b) ** 0.5
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0

    dot_product = sum(x * y for x, y in zip(a, b))
    return dot_product / (norm_a * norm_b)


def retrieve_top_chunks(
    db: Session, *, query: str, model, top_k: int = 5
) -> list[DocumentChunk]:
    chunks = db.query(DocumentChunk).all()
    if not chunks:
        return []

    query_embedding = model.encode([query])[0]

    scored = [(cosine_similarity(query_embedding, chunk.embedding), chunk) for chunk in chunks]
    scored.sort(key=lambda pair: pair[0], reverse=True)

    return [chunk for _, chunk in scored[:top_k]]

import uuid

from app.models.document_chunk import DocumentChunk
from app.services.retrieval_service import cosine_similarity, retrieve_top_chunks


class _FakeQuery:
    def __init__(self, results: list[object]) -> None:
        self._results = results

    def all(self) -> list[object]:
        return list(self._results)


class _FakeDb:
    def __init__(self, chunks: list[DocumentChunk]) -> None:
        self._chunks = chunks

    def query(self, model):
        if model is DocumentChunk:
            return _FakeQuery(self._chunks)
        return _FakeQuery([])


class _FakeEmbeddingModel:
    def __init__(self, query_embedding: list[float]) -> None:
        self._query_embedding = query_embedding
        self.encoded_queries: list[str] = []

    def encode_query(self, text: str) -> list[float]:
        self.encoded_queries.append(text)
        return self._query_embedding


def _chunk(embedding: list[float], *, document_id=None) -> DocumentChunk:
    return DocumentChunk(
        id=uuid.uuid4(),
        document_id=document_id or uuid.uuid4(),
        content="content",
        page_number=1,
        chunk_index=0,
        embedding=embedding,
    )


# --- cosine_similarity ---


def test_cosine_similarity_identical_vectors_is_one() -> None:
    assert cosine_similarity([1.0, 2.0, 3.0], [1.0, 2.0, 3.0]) == 1.0


def test_cosine_similarity_orthogonal_vectors_is_zero() -> None:
    assert cosine_similarity([1.0, 0.0], [0.0, 1.0]) == 0.0


def test_cosine_similarity_zero_norm_vector_returns_zero_without_error() -> None:
    assert cosine_similarity([0.0, 0.0], [1.0, 2.0]) == 0.0
    assert cosine_similarity([1.0, 2.0], [0.0, 0.0]) == 0.0


# --- retrieve_top_chunks ---


def test_retrieve_top_chunks_returns_most_similar_first() -> None:
    best = _chunk([1.0, 0.0])
    worst = _chunk([0.0, 1.0])
    middle = _chunk([0.7, 0.7])
    db = _FakeDb([worst, middle, best])
    model = _FakeEmbeddingModel(query_embedding=[1.0, 0.0])

    result = retrieve_top_chunks(db, query="how much should I sleep?", model=model, top_k=2)

    assert result == [best, middle]
    assert model.encoded_queries == ["how much should I sleep?"]


def test_retrieve_top_chunks_returns_all_when_fewer_than_top_k() -> None:
    only = _chunk([1.0, 0.0])
    db = _FakeDb([only])
    model = _FakeEmbeddingModel(query_embedding=[1.0, 0.0])

    result = retrieve_top_chunks(db, query="q", model=model, top_k=5)

    assert result == [only]


def test_retrieve_top_chunks_drops_chunks_below_min_score() -> None:
    relevant = _chunk([1.0, 0.0])
    borderline = _chunk([0.6, 0.8])  # cosine 0.6 against the query
    irrelevant = _chunk([0.0, 1.0])
    db = _FakeDb([irrelevant, borderline, relevant])
    model = _FakeEmbeddingModel(query_embedding=[1.0, 0.0])

    result = retrieve_top_chunks(db, query="q", model=model, top_k=5, min_score=0.5)

    assert result == [relevant, borderline]


def test_retrieve_top_chunks_returns_nothing_when_no_chunk_reaches_min_score() -> None:
    db = _FakeDb([_chunk([0.0, 1.0])])
    model = _FakeEmbeddingModel(query_embedding=[1.0, 0.0])

    assert retrieve_top_chunks(db, query="q", model=model, min_score=0.5) == []


def test_retrieve_top_chunks_keeps_everything_when_min_score_is_not_set() -> None:
    db = _FakeDb([_chunk([0.0, 1.0]), _chunk([1.0, 0.0])])
    model = _FakeEmbeddingModel(query_embedding=[1.0, 0.0])

    assert len(retrieve_top_chunks(db, query="q", model=model, top_k=5)) == 2


def test_retrieve_top_chunks_returns_empty_list_when_no_chunks() -> None:
    db = _FakeDb([])
    model = _FakeEmbeddingModel(query_embedding=[1.0, 0.0])

    result = retrieve_top_chunks(db, query="q", model=model, top_k=5)

    assert result == []

import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient
from google.genai import errors as genai_errors

from app.api import deps
from app.main import app
from app.models.conversation import Conversation
from app.models.document_chunk import DocumentChunk
from app.models.message import Message
from app.models.scientific_document import ScientificDocument
from app.models.user import User
from app.services.llm_service import get_gemini_client

client = TestClient(app)


class _FakeQuery:
    def __init__(self, results: list[object]) -> None:
        self._results = results

    def filter(self, *args, **kwargs) -> "_FakeQuery":
        return self

    def all(self) -> list[object]:
        return list(self._results)

    def first(self) -> object | None:
        return self._results[0] if self._results else None


class _FakeDb:
    def __init__(self, seed: list[object] | None = None) -> None:
        self.added: list[object] = list(seed or [])

    def query(self, model):
        return _FakeQuery([obj for obj in self.added if isinstance(obj, model)])

    def add(self, obj: object) -> None:
        # Idempotent, like a real Session: re-adding an already-tracked
        # object (e.g. an existing conversation reused for a new message)
        # must not duplicate it.
        if not any(obj is existing for existing in self.added):
            self.added.append(obj)

    def commit(self) -> None:
        pass

    def refresh(self, obj: object) -> None:
        if getattr(obj, "id", None) is None:
            obj.id = uuid.uuid4()
        now = datetime.now(timezone.utc)
        if hasattr(obj, "created_at") and obj.created_at is None:
            obj.created_at = now
        if hasattr(obj, "updated_at") and obj.updated_at is None:
            obj.updated_at = now

    def flush(self) -> None:
        for obj in self.added:
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()


class _FakeTokenizer:
    def encode(self, text: str) -> list[str]:
        return text.split()


class _FakeEmbeddingModel:
    tokenizer = _FakeTokenizer()

    def encode(self, texts: list[str]) -> list[list[float]]:
        # Deterministic: every text maps to the same vector, so retrieval
        # always finds the single seeded chunk as the top match regardless
        # of content — good enough since this test isn't exercising ranking.
        return [[1.0, 0.0] for _ in texts]


class _FakeModels:
    def __init__(self, answer: str | None = None, error: Exception | None = None) -> None:
        self._answer = answer
        self._error = error

    def generate_content(self, model: str, contents: str):
        if self._error is not None:
            raise self._error

        class _Response:
            text = self._answer

        return _Response()


class _FakeGeminiClient:
    def __init__(self, answer: str | None = "Dormí entre 7 y 9 horas.", error: Exception | None = None) -> None:
        self.models = _FakeModels(answer=answer, error=error)


_CURRENT_USER = User(
    id=uuid.uuid4(),
    google_id="g-123",
    email="test@example.com",
    name="Test User",
    onboarding_completed=True,
)

_OTHER_USER_ID = uuid.uuid4()

_DOCUMENT = ScientificDocument(
    id=uuid.uuid4(),
    title="Healthy Sleep",
    organization="CDC",
    language="en",
    source_url=None,
    file_path="cdc.pdf",
)

_CHUNK = DocumentChunk(
    id=uuid.uuid4(),
    document_id=_DOCUMENT.id,
    content="Adults should sleep 7 to 9 hours per night.",
    page_number=1,
    chunk_index=0,
    embedding=[1.0, 0.0],
)


def _override(
    *,
    seed: list[object] | None = None,
    gemini_client: _FakeGeminiClient | None = None,
) -> _FakeDb:
    fake_db = _FakeDb(seed=seed)
    app.dependency_overrides[deps.get_current_user] = lambda: _CURRENT_USER
    app.dependency_overrides[deps.get_db] = lambda: fake_db
    app.dependency_overrides[deps.get_embedding_model] = lambda: _FakeEmbeddingModel()
    app.dependency_overrides[get_gemini_client] = lambda: gemini_client or _FakeGeminiClient()
    return fake_db


def _clear_overrides() -> None:
    app.dependency_overrides.pop(deps.get_current_user, None)
    app.dependency_overrides.pop(deps.get_db, None)
    app.dependency_overrides.pop(deps.get_embedding_model, None)
    app.dependency_overrides.pop(get_gemini_client, None)


def test_send_chat_message_requires_auth() -> None:
    response = client.post("/chat", json={"message": "hola"})
    assert response.status_code == 401


def test_send_chat_message_rejects_empty_message() -> None:
    _override()
    try:
        response = client.post("/chat", json={"message": ""})
    finally:
        _clear_overrides()
    assert response.status_code == 422


def test_send_chat_message_returns_404_for_unknown_conversation() -> None:
    fake_db = _override(seed=[_DOCUMENT, _CHUNK])
    try:
        response = client.post(
            "/chat",
            json={"message": "¿Cuánto debo dormir?", "conversation_id": str(uuid.uuid4())},
        )
    finally:
        _clear_overrides()
    assert response.status_code == 404
    assert not any(isinstance(obj, Message) for obj in fake_db.added)


def test_send_chat_message_returns_404_for_another_users_conversation() -> None:
    other_conversation = Conversation(id=uuid.uuid4(), user_id=_OTHER_USER_ID, title=None)
    fake_db = _override(seed=[_DOCUMENT, _CHUNK, other_conversation])
    try:
        response = client.post(
            "/chat",
            json={"message": "¿Cuánto debo dormir?", "conversation_id": str(other_conversation.id)},
        )
    finally:
        _clear_overrides()
    assert response.status_code == 404
    assert not any(isinstance(obj, Message) for obj in fake_db.added)


def test_send_chat_message_creates_new_conversation() -> None:
    fake_db = _override(seed=[_DOCUMENT, _CHUNK])
    try:
        response = client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    assert response.status_code == 201
    body = response.json()

    conversations = [obj for obj in fake_db.added if isinstance(obj, Conversation)]
    assert len(conversations) == 1
    assert str(conversations[0].id) == body["conversation_id"]

    messages = [obj for obj in fake_db.added if isinstance(obj, Message)]
    assert len(messages) == 2
    assert messages[0].role == "user"
    assert messages[0].content == "¿Cuánto debo dormir?"
    assert messages[1].role == "assistant"
    assert messages[1].content == "Dormí entre 7 y 9 horas."

    assert body["message"]["role"] == "assistant"
    assert body["message"]["content"] == "Dormí entre 7 y 9 horas."
    assert len(body["sources"]) == 1
    assert body["sources"][0]["document_id"] == str(_DOCUMENT.id)
    assert body["sources"][0]["title"] == "Healthy Sleep"


def test_send_chat_message_reuses_existing_conversation() -> None:
    existing = Conversation(id=uuid.uuid4(), user_id=_CURRENT_USER.id, title=None)
    fake_db = _override(seed=[_DOCUMENT, _CHUNK, existing])
    try:
        response = client.post(
            "/chat",
            json={"message": "¿Y para adolescentes?", "conversation_id": str(existing.id)},
        )
    finally:
        _clear_overrides()

    assert response.status_code == 201
    assert response.json()["conversation_id"] == str(existing.id)

    conversations = [obj for obj in fake_db.added if isinstance(obj, Conversation)]
    assert len(conversations) == 1


def test_send_chat_message_returns_502_when_gemini_fails() -> None:
    error = genai_errors.APIError(503, {"error": {"message": "high demand"}})
    fake_db = _override(seed=[_DOCUMENT, _CHUNK], gemini_client=_FakeGeminiClient(error=error))
    try:
        response = client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    assert response.status_code == 502
    # Fully atomic: a Gemini failure on a brand-new conversation leaves no
    # dangling user message AND no orphaned empty conversation behind.
    assert not any(isinstance(obj, Message) for obj in fake_db.added)
    assert not any(isinstance(obj, Conversation) for obj in fake_db.added)


def test_send_chat_message_does_not_touch_existing_conversation_when_gemini_fails() -> None:
    existing = Conversation(id=uuid.uuid4(), user_id=_CURRENT_USER.id, title=None)
    error = genai_errors.APIError(503, {"error": {"message": "high demand"}})
    fake_db = _override(
        seed=[_DOCUMENT, _CHUNK, existing], gemini_client=_FakeGeminiClient(error=error)
    )
    try:
        response = client.post(
            "/chat",
            json={"message": "¿Cuánto debo dormir?", "conversation_id": str(existing.id)},
        )
    finally:
        _clear_overrides()

    assert response.status_code == 502
    assert not any(isinstance(obj, Message) for obj in fake_db.added)

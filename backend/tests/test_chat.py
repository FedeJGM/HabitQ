import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient
from google.genai import errors as genai_errors
from sqlalchemy.sql import operators

from app.api import deps
from app.main import app
from app.models.conversation import Conversation
from app.models.document_chunk import DocumentChunk
from app.models.habit_record import HabitRecord
from app.models.message import Message
from app.models.profile import Profile
from app.models.scientific_document import ScientificDocument
from app.models.user import User
from app.services.chat_service import build_user_context
from app.services.llm_service import get_gemini_client

client = TestClient(app)


class _FakeQuery:
    def __init__(self, results: list[object]) -> None:
        self._results = results

    def filter(self, *clauses) -> "_FakeQuery":
        # Interprets simple `Column == value` and `Column.in_(...)` clauses
        # well enough for multi-row queries (e.g. list_conversations,
        # the sources lookup in send_message) that genuinely need
        # server-side filtering, unlike the single-object lookups elsewhere
        # that re-check ownership in Python after fetching by id.
        results = list(self._results)
        for clause in clauses:
            key = getattr(getattr(clause, "left", None), "key", None)
            if key is None:
                continue
            right = getattr(clause, "right", None)
            value = getattr(right, "value", right)
            if getattr(clause, "operator", None) is operators.in_op:
                results = [obj for obj in results if getattr(obj, key, None) in value]
            else:
                results = [obj for obj in results if getattr(obj, key, None) == value]
        self._results = results
        return self

    def order_by(self, *clauses) -> "_FakeQuery":
        # Interprets real SQLAlchemy .asc()/.desc() clauses well enough to
        # verify the service actually orders results, not just that it
        # returns the right set.
        results = list(self._results)
        for clause in reversed(clauses):
            element = getattr(clause, "element", clause)
            key = element.key
            descending = "desc" in str(getattr(clause, "modifier", "")).lower()
            results.sort(key=lambda obj: getattr(obj, key), reverse=descending)
        self._results = results
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

    def delete(self, obj: object) -> None:
        self.added = [existing for existing in self.added if existing is not obj]


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
        self.calls: list[dict] = []

    def generate_content(self, model: str, contents: str):
        self.calls.append({"model": model, "contents": contents})
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


def test_send_chat_message_ignores_chunks_below_the_configured_min_score(monkeypatch) -> None:
    from app.core.config import settings

    monkeypatch.setattr(settings, "retrieval_min_score", 0.5)
    gemini = _FakeGeminiClient()
    far_chunk = DocumentChunk(
        id=uuid.uuid4(), document_id=_DOCUMENT.id, content="Unrelated text.",
        page_number=1, chunk_index=0, embedding=[0.0, 1.0],  # orthogonal to the fake query
    )
    _override(seed=[_DOCUMENT, far_chunk], gemini_client=gemini)
    try:
        response = client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    assert response.status_code == 201
    assert response.json()["sources"] == []
    prompt = gemini.models.calls[0]["contents"]
    assert "Unrelated text." not in prompt
    assert "No hay evidencia disponible" in prompt


def test_send_chat_message_persists_the_sources_on_the_assistant_message() -> None:
    fake_db = _override(seed=[_DOCUMENT, _CHUNK])
    try:
        client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    user_message, assistant_message = [obj for obj in fake_db.added if isinstance(obj, Message)]
    assert user_message.sources is None
    assert assistant_message.sources == [
        {
            "document_id": str(_DOCUMENT.id),
            "title": "Healthy Sleep",
            "organization": "CDC",
            "source_url": None,
            "authors": None,
            "year": None,
            "doi": None,
            "pages": [1],
        }
    ]


def test_send_chat_message_returns_full_references_ordered_by_relevance() -> None:
    cited = ScientificDocument(
        id=uuid.uuid4(),
        title="Sleep and health",
        authors="Doe J, Roe R.",
        organization="Sleep Journal",
        year=2024,
        doi="10.1/abc",
        language="en",
        source_url="https://europepmc.org/articles/PMC1",
        file_path="pmc1.pdf",
    )
    less_relevant = ScientificDocument(
        id=uuid.uuid4(), title="Other paper", language="en", file_path="other.pdf"
    )

    def chunk(document: ScientificDocument, page: int | None, embedding: list[float]) -> DocumentChunk:
        return DocumentChunk(
            id=uuid.uuid4(), document_id=document.id, content=f"text p{page}",
            page_number=page, chunk_index=page or 0, embedding=embedding,
        )

    # The fake query vector is [1, 0]: the cited paper's chunks match, the
    # other one doesn't. It is seeded first to prove ordering is by relevance.
    seed = [
        less_relevant,
        chunk(less_relevant, 2, [0.0, 1.0]),
        cited,
        chunk(cited, 3, [1.0, 0.0]),
        chunk(cited, 1, [1.0, 0.0]),
        chunk(cited, None, [1.0, 0.0]),
    ]
    _override(seed=seed)
    try:
        response = client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    sources = response.json()["sources"]
    assert [s["title"] for s in sources] == ["Sleep and health", "Other paper"]
    assert sources[0] == {
        "document_id": str(cited.id),
        "title": "Sleep and health",
        "organization": "Sleep Journal",
        "source_url": "https://europepmc.org/articles/PMC1",
        "authors": "Doe J, Roe R.",
        "year": 2024,
        "doi": "10.1/abc",
        "pages": [1, 3],
    }
    assert sources[1]["pages"] == [2]
    assert sources[1]["authors"] is None
    assert sources[1]["doi"] is None


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


# --- GET /chat/conversations ---


def test_list_conversations_requires_auth() -> None:
    response = client.get("/chat/conversations")
    assert response.status_code == 401


def test_list_conversations_returns_only_current_users_conversations_newest_first() -> None:
    older = Conversation(
        id=uuid.uuid4(),
        user_id=_CURRENT_USER.id,
        title=None,
        created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        updated_at=datetime(2026, 1, 3, tzinfo=timezone.utc),
    )
    newer = Conversation(
        id=uuid.uuid4(),
        user_id=_CURRENT_USER.id,
        title=None,
        created_at=datetime(2026, 1, 2, tzinfo=timezone.utc),
        updated_at=datetime(2026, 1, 5, tzinfo=timezone.utc),
    )
    other_users = Conversation(
        id=uuid.uuid4(),
        user_id=_OTHER_USER_ID,
        title=None,
        created_at=datetime(2026, 1, 6, tzinfo=timezone.utc),
        updated_at=datetime(2026, 1, 6, tzinfo=timezone.utc),
    )
    _override(seed=[older, newer, other_users])
    try:
        response = client.get("/chat/conversations")
    finally:
        _clear_overrides()

    assert response.status_code == 200
    body = response.json()
    assert [c["id"] for c in body] == [str(newer.id), str(older.id)]


# --- GET /chat/conversations/{id}/messages ---


def test_list_conversation_messages_returns_404_for_unknown_conversation() -> None:
    _override()
    try:
        response = client.get(f"/chat/conversations/{uuid.uuid4()}/messages")
    finally:
        _clear_overrides()
    assert response.status_code == 404


def test_list_conversation_messages_returns_404_for_another_users_conversation() -> None:
    other_conversation = Conversation(id=uuid.uuid4(), user_id=_OTHER_USER_ID, title=None)
    _override(seed=[other_conversation])
    try:
        response = client.get(f"/chat/conversations/{other_conversation.id}/messages")
    finally:
        _clear_overrides()
    assert response.status_code == 404


def test_list_conversation_messages_returns_them_in_chronological_order() -> None:
    conversation = Conversation(id=uuid.uuid4(), user_id=_CURRENT_USER.id, title=None)
    first = Message(
        id=uuid.uuid4(),
        conversation_id=conversation.id,
        role="user",
        content="¿Cuánto debo dormir?",
        created_at=datetime(2026, 1, 1, 10, 0, tzinfo=timezone.utc),
    )
    second = Message(
        id=uuid.uuid4(),
        conversation_id=conversation.id,
        role="assistant",
        content="Entre 7 y 9 horas.",
        created_at=datetime(2026, 1, 1, 10, 0, 5, tzinfo=timezone.utc),
    )
    _override(seed=[conversation, second, first])  # seeded out of order on purpose
    try:
        response = client.get(f"/chat/conversations/{conversation.id}/messages")
    finally:
        _clear_overrides()

    assert response.status_code == 200
    body = response.json()
    assert [m["id"] for m in body] == [str(first.id), str(second.id)]


def test_list_conversation_messages_includes_stored_sources() -> None:
    conversation = Conversation(id=uuid.uuid4(), user_id=_CURRENT_USER.id, title=None)
    document_id = uuid.uuid4()
    messages = [
        Message(
            id=uuid.uuid4(), conversation_id=conversation.id, role="user",
            content="¿Cuánto debo dormir?", sources=None,
            created_at=datetime(2026, 1, 1, 10, 0, 0, tzinfo=timezone.utc),
        ),
        Message(
            id=uuid.uuid4(), conversation_id=conversation.id, role="assistant",
            content="Entre 7 y 9 horas.",
            sources=[
                {
                    "document_id": str(document_id), "title": "Sleep and health",
                    "organization": "Sleep Journal", "source_url": None,
                    "authors": "Doe J.", "year": 2024, "doi": "10.1/abc", "pages": [1, 3],
                }
            ],
            created_at=datetime(2026, 1, 1, 10, 0, 5, tzinfo=timezone.utc),
        ),
        # Written before sources were persisted: must still load, with none.
        Message(
            id=uuid.uuid4(), conversation_id=conversation.id, role="assistant",
            content="Respuesta antigua.", sources=None,
            created_at=datetime(2026, 1, 1, 10, 1, 0, tzinfo=timezone.utc),
        ),
    ]
    _override(seed=[conversation, *messages])
    try:
        response = client.get(f"/chat/conversations/{conversation.id}/messages")
    finally:
        _clear_overrides()

    body = response.json()
    assert body[0]["sources"] == []
    assert body[1]["sources"] == [
        {
            "document_id": str(document_id), "title": "Sleep and health",
            "organization": "Sleep Journal", "source_url": None,
            "authors": "Doe J.", "year": 2024, "doi": "10.1/abc", "pages": [1, 3],
        }
    ]
    assert body[2]["sources"] == []


# --- DELETE /chat/conversations/{id} ---


def test_delete_conversation_returns_404_for_unknown_conversation() -> None:
    fake_db = _override()
    try:
        response = client.delete(f"/chat/conversations/{uuid.uuid4()}")
    finally:
        _clear_overrides()
    assert response.status_code == 404
    assert fake_db.added == []


def test_delete_conversation_returns_404_for_another_users_conversation() -> None:
    other_conversation = Conversation(id=uuid.uuid4(), user_id=_OTHER_USER_ID, title=None)
    fake_db = _override(seed=[other_conversation])
    try:
        response = client.delete(f"/chat/conversations/{other_conversation.id}")
    finally:
        _clear_overrides()
    assert response.status_code == 404
    assert other_conversation in fake_db.added


def test_delete_conversation_removes_it_and_its_messages() -> None:
    conversation = Conversation(id=uuid.uuid4(), user_id=_CURRENT_USER.id, title=None)
    message = Message(
        id=uuid.uuid4(), conversation_id=conversation.id, role="user", content="hola"
    )
    fake_db = _override(seed=[conversation, message])
    try:
        response = client.delete(f"/chat/conversations/{conversation.id}")
    finally:
        _clear_overrides()

    assert response.status_code == 204
    assert conversation not in fake_db.added
    assert message not in fake_db.added


# --- build_user_context ---


def test_build_user_context_returns_none_without_profile_or_habits() -> None:
    assert build_user_context(None, []) is None


def test_build_user_context_with_profile_only() -> None:
    profile = Profile(user_id=uuid.uuid4(), age_range="25-34", main_goal="sleep_better")
    context = build_user_context(profile, [])
    assert context is not None
    assert "25-34" in context
    assert "sleep_better" in context
    assert "Hábitos" not in context


def test_build_user_context_with_habits_only() -> None:
    habit = HabitRecord(user_id=uuid.uuid4(), domain="sleep", key="hours", value="5_6")
    context = build_user_context(None, [habit])
    assert context is not None
    assert "sleep.hours" in context
    assert "5_6" in context
    assert "Perfil" not in context


def test_build_user_context_with_profile_and_habits() -> None:
    profile = Profile(user_id=uuid.uuid4(), age_range="25-34", main_goal="sleep_better")
    habit = HabitRecord(user_id=uuid.uuid4(), domain="sleep", key="hours", value="5_6")
    context = build_user_context(profile, [habit])
    assert "25-34" in context
    assert "sleep.hours" in context


# --- POST /chat personalization ---


def test_send_chat_message_includes_user_context_when_profile_and_habits_exist() -> None:
    profile = Profile(user_id=_CURRENT_USER.id, age_range="25-34", main_goal="sleep_better")
    habit = HabitRecord(user_id=_CURRENT_USER.id, domain="sleep", key="hours", value="5_6")
    gemini_client = _FakeGeminiClient()
    _override(seed=[_DOCUMENT, _CHUNK, profile, habit], gemini_client=gemini_client)
    try:
        response = client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    assert response.status_code == 201
    sent_prompt = gemini_client.models.calls[-1]["contents"]
    assert "25-34" in sent_prompt
    assert "sleep.hours" in sent_prompt
    assert "5_6" in sent_prompt


def test_send_chat_message_omits_user_context_section_without_profile_or_habits() -> None:
    gemini_client = _FakeGeminiClient()
    _override(seed=[_DOCUMENT, _CHUNK], gemini_client=gemini_client)
    try:
        response = client.post("/chat", json={"message": "¿Cuánto debo dormir?"})
    finally:
        _clear_overrides()

    assert response.status_code == 201
    sent_prompt = gemini_client.models.calls[-1]["contents"]
    assert "Contexto del usuario" not in sent_prompt

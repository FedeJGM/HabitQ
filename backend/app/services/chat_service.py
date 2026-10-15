import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.conversation import Conversation
from app.models.document_chunk import DocumentChunk
from app.models.habit_record import HabitRecord
from app.models.message import Message
from app.models.profile import Profile
from app.models.scientific_document import ScientificDocument
from app.services.llm_service import generate_answer
from app.services.retrieval_service import retrieve_top_chunks
from app.services.user_context_labels import HABIT_LABELS, MAIN_GOAL_LABELS


@dataclass(frozen=True)
class SourceRef:
    document: ScientificDocument
    pages: list[int]


def build_sources(db: Session, chunks: list[DocumentChunk]) -> list[SourceRef]:
    """One reference per document behind the retrieved chunks, most relevant
    first (chunks arrive ranked), with the pages those chunks came from."""
    pages_by_document: dict[uuid.UUID, set[int]] = {}
    for chunk in chunks:
        pages = pages_by_document.setdefault(chunk.document_id, set())
        if chunk.page_number is not None:
            pages.add(chunk.page_number)

    if not pages_by_document:
        return []

    documents = (
        db.query(ScientificDocument)
        .filter(ScientificDocument.id.in_(list(pages_by_document)))
        .all()
    )
    by_id = {document.id: document for document in documents}
    return [
        SourceRef(document=by_id[document_id], pages=sorted(pages))
        for document_id, pages in pages_by_document.items()
        if document_id in by_id
    ]


def source_to_dict(source: SourceRef) -> dict:
    """JSON-safe form of a reference: what gets stored on the message and what
    the API returns for it."""
    document = source.document
    return {
        "document_id": str(document.id),
        "title": document.title,
        "organization": document.organization,
        "source_url": document.source_url,
        "authors": document.authors,
        "year": document.year,
        "doi": document.doi,
        "pages": source.pages,
    }


def _describe_habit(habit: HabitRecord) -> str:
    entry = HABIT_LABELS.get((habit.domain, habit.key))
    if entry is None:
        return f"{habit.domain}.{habit.key}: {habit.value}"
    question, options = entry
    return f"{question}: {options.get(habit.value, habit.value)}"


def build_user_context(profile: Profile | None, habits: list[HabitRecord]) -> str | None:
    if profile is None and not habits:
        return None

    lines: list[str] = []
    if profile is not None:
        goal = MAIN_GOAL_LABELS.get(profile.main_goal, profile.main_goal)
        lines.append(
            f"Perfil: rango de edad {profile.age_range}, objetivo principal {goal}."
        )
    if habits:
        lines.append("Hábitos registrados:")
        for habit in habits:
            lines.append(f"- {_describe_habit(habit)}")

    return "\n".join(lines)


def get_or_create_conversation(
    db: Session, *, user_id: uuid.UUID, conversation_id: uuid.UUID | None
) -> Conversation | None:
    if conversation_id is None:
        # Transient — not added/persisted yet. send_message() adds and
        # flushes it together with the messages, in the same transaction,
        # so a Gemini failure leaves no orphaned empty conversation behind.
        return Conversation(user_id=user_id)

    conversation = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if conversation is None or conversation.user_id != user_id:
        return None
    return conversation


def list_conversations(db: Session, *, user_id: uuid.UUID) -> list[Conversation]:
    return (
        db.query(Conversation)
        .filter(Conversation.user_id == user_id)
        .order_by(Conversation.updated_at.desc())
        .all()
    )


def get_conversation_for_user(
    db: Session, *, user_id: uuid.UUID, conversation_id: uuid.UUID
) -> Conversation | None:
    conversation = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if conversation is None or conversation.user_id != user_id:
        return None
    return conversation


def list_messages(db: Session, *, conversation_id: uuid.UUID) -> list[Message]:
    return (
        db.query(Message)
        .filter(Message.conversation_id == conversation_id)
        .order_by(Message.created_at.asc())
        .all()
    )


def delete_conversation(db: Session, *, conversation: Conversation) -> None:
    # No ondelete=CASCADE on messages.conversation_id (migration 0005) — the
    # FK rejects deleting a conversation while its messages still reference
    # it. Deleting the Message objects first isn't enough on its own: with
    # no relationship() configured between the two mappers (this codebase
    # never uses relationship(), FKs are plain columns), SQLAlchemy's
    # unit-of-work has no dependency info to order the two DELETEs — it can
    # (and does, in practice) emit the conversation's DELETE before the
    # messages'. The explicit flush() here forces the message deletes to
    # execute first, before the conversation is even marked for deletion.
    messages = db.query(Message).filter(Message.conversation_id == conversation.id).all()
    for message in messages:
        db.delete(message)
    db.flush()
    db.delete(conversation)
    db.commit()


def send_message(
    db: Session,
    *,
    conversation: Conversation,
    question: str,
    embedding_model,
    gemini_client,
    top_k: int = 5,
) -> tuple[Message, list[SourceRef]]:
    chunks = retrieve_top_chunks(
        db,
        query=question,
        model=embedding_model,
        top_k=top_k,
        min_score=settings.retrieval_min_score,
    )
    context_chunks = [chunk.content for chunk in chunks]

    profile = db.query(Profile).filter(Profile.user_id == conversation.user_id).first()
    habits = db.query(HabitRecord).filter(HabitRecord.user_id == conversation.user_id).all()
    user_context = build_user_context(profile, habits)

    # Ask Gemini before persisting anything: if this raises, the turn stays
    # fully unpersisted — including a brand-new conversation, which is only
    # added/flushed below, after a successful answer.
    answer = generate_answer(question, context_chunks, gemini_client, user_context=user_context)

    sources = build_sources(db, chunks)

    db.add(conversation)
    db.flush()  # assigns conversation.id if it's new, without committing yet

    user_message = Message(conversation_id=conversation.id, role="user", content=question)
    db.add(user_message)

    assistant_message = Message(
        conversation_id=conversation.id,
        role="assistant",
        content=answer,
        sources=[source_to_dict(source) for source in sources],
    )
    db.add(assistant_message)

    conversation.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(assistant_message)
    db.refresh(conversation)

    return assistant_message, sources

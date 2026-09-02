import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models.conversation import Conversation
from app.models.message import Message
from app.models.scientific_document import ScientificDocument
from app.services.llm_service import generate_answer
from app.services.retrieval_service import retrieve_top_chunks


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


def send_message(
    db: Session,
    *,
    conversation: Conversation,
    question: str,
    embedding_model,
    gemini_client,
    top_k: int = 5,
) -> tuple[Message, list[ScientificDocument]]:
    chunks = retrieve_top_chunks(db, query=question, model=embedding_model, top_k=top_k)
    context_chunks = [chunk.content for chunk in chunks]

    # Ask Gemini before persisting anything: if this raises, the turn stays
    # fully unpersisted — including a brand-new conversation, which is only
    # added/flushed below, after a successful answer.
    answer = generate_answer(question, context_chunks, gemini_client)

    db.add(conversation)
    db.flush()  # assigns conversation.id if it's new, without committing yet

    user_message = Message(conversation_id=conversation.id, role="user", content=question)
    db.add(user_message)

    assistant_message = Message(conversation_id=conversation.id, role="assistant", content=answer)
    db.add(assistant_message)

    document_ids = {chunk.document_id for chunk in chunks}
    sources = (
        db.query(ScientificDocument).filter(ScientificDocument.id.in_(document_ids)).all()
        if document_ids
        else []
    )

    conversation.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(assistant_message)
    db.refresh(conversation)

    return assistant_message, sources

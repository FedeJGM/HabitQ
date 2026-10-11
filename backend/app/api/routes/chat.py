import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from google.genai import errors as genai_errors
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, get_embedding_model
from app.models.user import User
from app.schemas.chat import ChatRequest, ChatResponse, ConversationOut, MessageOut, SourceOut
from app.services.chat_service import (
    delete_conversation,
    get_conversation_for_user,
    get_or_create_conversation,
    list_conversations,
    list_messages,
    send_message,
)
from app.services.llm_service import get_gemini_client

router = APIRouter(prefix="/chat", tags=["chat"])


@router.post("", response_model=ChatResponse, status_code=status.HTTP_201_CREATED)
def send_chat_message(
    payload: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    embedding_model=Depends(get_embedding_model),
    gemini_client=Depends(get_gemini_client),
) -> ChatResponse:
    conversation = get_or_create_conversation(
        db, user_id=current_user.id, conversation_id=payload.conversation_id
    )
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

    try:
        message, sources = send_message(
            db,
            conversation=conversation,
            question=payload.message,
            embedding_model=embedding_model,
            gemini_client=gemini_client,
        )
    except genai_errors.APIError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="No se pudo generar una respuesta en este momento. Intenta de nuevo.",
        ) from exc

    return ChatResponse(
        conversation_id=conversation.id,
        message=MessageOut.model_validate(message),
        sources=[
            SourceOut(
                document_id=source.document.id,
                title=source.document.title,
                organization=source.document.organization,
                source_url=source.document.source_url,
                authors=source.document.authors,
                year=source.document.year,
                doi=source.document.doi,
                pages=source.pages,
            )
            for source in sources
        ],
    )


@router.get("/conversations", response_model=list[ConversationOut])
def list_conversations_endpoint(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ConversationOut]:
    conversations = list_conversations(db, user_id=current_user.id)
    return [ConversationOut.model_validate(c) for c in conversations]


@router.get("/conversations/{conversation_id}/messages", response_model=list[MessageOut])
def list_conversation_messages_endpoint(
    conversation_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[MessageOut]:
    conversation = get_conversation_for_user(
        db, user_id=current_user.id, conversation_id=conversation_id
    )
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

    messages = list_messages(db, conversation_id=conversation.id)
    return [MessageOut.model_validate(m) for m in messages]


@router.delete("/conversations/{conversation_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_conversation_endpoint(
    conversation_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    conversation = get_conversation_for_user(
        db, user_id=current_user.id, conversation_id=conversation_id
    )
    if conversation is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

    delete_conversation(db, conversation=conversation)
    return None

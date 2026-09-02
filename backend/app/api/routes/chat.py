from fastapi import APIRouter, Depends, HTTPException, status
from google.genai import errors as genai_errors
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db, get_embedding_model
from app.models.user import User
from app.schemas.chat import ChatRequest, ChatResponse, MessageOut, SourceOut
from app.services.chat_service import get_or_create_conversation, send_message
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
                document_id=doc.id,
                title=doc.title,
                organization=doc.organization,
                source_url=doc.source_url,
            )
            for doc in sources
        ],
    )

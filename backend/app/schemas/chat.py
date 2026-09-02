import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    conversation_id: uuid.UUID | None = None


class SourceOut(BaseModel):
    document_id: uuid.UUID
    title: str
    organization: str | None
    source_url: str | None

    model_config = {"from_attributes": True}


class MessageOut(BaseModel):
    id: uuid.UUID
    role: str
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatResponse(BaseModel):
    conversation_id: uuid.UUID
    message: MessageOut
    sources: list[SourceOut]

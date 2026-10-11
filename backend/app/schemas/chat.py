import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    conversation_id: uuid.UUID | None = None


class SourceOut(BaseModel):
    document_id: uuid.UUID
    title: str
    organization: str | None
    source_url: str | None
    authors: str | None = None
    year: int | None = None
    doi: str | None = None
    pages: list[int] = []

    model_config = {"from_attributes": True}


class MessageOut(BaseModel):
    id: uuid.UUID
    role: str
    content: str
    sources: list[SourceOut] = []
    created_at: datetime

    model_config = {"from_attributes": True}

    @field_validator("sources", mode="before")
    @classmethod
    def _none_means_no_sources(cls, value):
        # User messages and answers from before sources were stored have NULL.
        return [] if value is None else value


class ChatResponse(BaseModel):
    conversation_id: uuid.UUID
    message: MessageOut
    sources: list[SourceOut]


class ConversationOut(BaseModel):
    id: uuid.UUID
    title: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

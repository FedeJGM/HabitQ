import uuid
from datetime import datetime

from pydantic import BaseModel, field_validator

from app.services.discovery_service import DOMAIN_QUERIES


class DiscoveryRequest(BaseModel):
    domains: list[str] | None = None

    @field_validator("domains")
    @classmethod
    def _validate_domains(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        if not value:
            raise ValueError("domains cannot be an empty list")
        unknown = [domain for domain in value if domain not in DOMAIN_QUERIES]
        if unknown:
            raise ValueError(f"unknown domain(s): {', '.join(unknown)}")
        return list(dict.fromkeys(value))


class CandidateOut(BaseModel):
    id: uuid.UUID
    run_id: uuid.UUID
    domain: str
    external_id: str
    doi: str | None
    title: str
    authors: str | None
    journal: str | None
    year: int | None
    abstract: str | None
    language: str
    license: str | None
    landing_url: str | None
    pdf_url: str | None
    status: str
    error: str | None
    reviewed_at: datetime | None
    # Indexing was interrupted (server restart/crash): "Indexar aprobados"
    # puts it back in the queue.
    stuck: bool = False

    model_config = {"from_attributes": True}


class RunOut(BaseModel):
    id: uuid.UUID
    domains: list[str]
    created_at: datetime
    candidates: list[CandidateOut]


class IngestResponse(BaseModel):
    queued: int
    # Candidates found stuck in "ingesting" and put back in the queue.
    recovered: int = 0


class DocumentOut(BaseModel):
    id: uuid.UUID
    title: str
    authors: str | None
    journal: str | None
    year: int | None
    doi: str | None
    domain: str | None
    language: str
    source_url: str | None
    created_at: datetime
    chunk_count: int

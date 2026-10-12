import json
import uuid
from pathlib import Path

import requests
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session

from app.api.deps import get_db, get_embedding_model, require_admin
from app.core.config import settings
from app.db.session import SessionLocal
from app.models.document_candidate import DocumentCandidate
from app.models.scientific_document import ScientificDocument
from app.models.user import User
from app.schemas.admin import CandidateOut, DiscoveryRequest, DocumentOut, IngestResponse, RunOut
from app.services.candidate_ingestion_service import ingest_approved
from app.services.candidate_service import (
    CandidateStateError,
    approve_candidate,
    create_run,
    known_identifiers,
    is_stuck,
    recover_stuck_candidates,
    reject_candidate,
)
from app.services.discovery_service import DOMAIN_QUERIES, discover_candidates, europe_pmc_fetch
from app.services.document_history_service import delete_document, list_ingested_documents

router = APIRouter(prefix="/admin", tags=["admin"])

_PANEL_PATH = Path(__file__).resolve().parents[2] / "web" / "admin.html"


def get_discovery_fetch():
    return europe_pmc_fetch


def run_ingestion_job(embedding_model) -> None:
    # Background tasks outlive the request, so they can't reuse its DB session.
    db = SessionLocal()
    try:
        ingest_approved(db, model=embedding_model)
    finally:
        db.close()


def get_ingestion_job():
    return run_ingestion_job


def _candidate_out(candidate: DocumentCandidate) -> CandidateOut:
    out = CandidateOut.model_validate(candidate)
    out.stuck = is_stuck(candidate)
    return out


def _get_candidate_or_404(db: Session, candidate_id: uuid.UUID) -> DocumentCandidate:
    candidate = db.query(DocumentCandidate).filter(DocumentCandidate.id == candidate_id).first()
    if candidate is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Candidate not found")
    return candidate


def _get_document_or_404(db: Session, document_id: uuid.UUID) -> ScientificDocument:
    document = db.query(ScientificDocument).filter(ScientificDocument.id == document_id).first()
    if document is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    return document


@router.get("", response_class=HTMLResponse)
def admin_panel() -> HTMLResponse:
    # Public on purpose: it is a static shell. Every data call it makes goes
    # through the admin-protected endpoints below.
    html = _PANEL_PATH.read_text(encoding="utf-8")
    client_id = json.dumps(settings.google_client_id)[1:-1]
    return HTMLResponse(html.replace("__GOOGLE_CLIENT_ID__", client_id))


@router.post("/discovery", response_model=RunOut, status_code=status.HTTP_201_CREATED)
def start_discovery(
    payload: DiscoveryRequest | None = None,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
    fetch=Depends(get_discovery_fetch),
) -> RunOut:
    domains = (payload.domains if payload else None) or list(DOMAIN_QUERIES)
    known_ids, known_dois = known_identifiers(db)

    try:
        found = discover_candidates(domains, fetch=fetch, known_ids=known_ids, known_dois=known_dois)
    except requests.RequestException as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Europe PMC is not reachable right now. Try again later.",
        ) from exc

    run = create_run(db, user_id=admin.id, domains=domains, candidates=found)
    candidates = (
        db.query(DocumentCandidate)
        .filter(DocumentCandidate.run_id == run.id)
        .order_by(DocumentCandidate.domain, DocumentCandidate.title)
        .all()
    )
    return RunOut(
        id=run.id,
        domains=domains,
        created_at=run.created_at,
        candidates=[_candidate_out(c) for c in candidates],
    )


@router.get("/candidates", response_model=list[CandidateOut])
def list_candidates(
    run_id: uuid.UUID | None = None,
    status_filter: str | None = Query(default=None, alias="status"),
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> list[CandidateOut]:
    query = db.query(DocumentCandidate)
    if run_id is not None:
        query = query.filter(DocumentCandidate.run_id == run_id)
    if status_filter is not None:
        query = query.filter(DocumentCandidate.status == status_filter)
    candidates = query.order_by(DocumentCandidate.domain, DocumentCandidate.title).all()
    return [_candidate_out(c) for c in candidates]


@router.get("/documents", response_model=list[DocumentOut])
def list_documents(
    domain: str | None = None,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> list[DocumentOut]:
    return [
        DocumentOut(
            id=doc.id,
            title=doc.title,
            authors=doc.authors,
            journal=doc.organization,
            year=doc.year,
            doi=doc.doi,
            domain=doc.domain,
            language=doc.language,
            source_url=doc.source_url,
            created_at=doc.created_at,
            chunk_count=chunks,
        )
        for doc, chunks in list_ingested_documents(db, domain)
    ]


@router.delete("/documents/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_document(
    document_id: uuid.UUID,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> None:
    delete_document(db, _get_document_or_404(db, document_id))


@router.post("/candidates/{candidate_id}/approve", response_model=CandidateOut)
def approve(
    candidate_id: uuid.UUID,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> CandidateOut:
    candidate = _get_candidate_or_404(db, candidate_id)
    try:
        approve_candidate(db, candidate)
    except CandidateStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return _candidate_out(candidate)


@router.post("/candidates/{candidate_id}/reject", response_model=CandidateOut)
def reject(
    candidate_id: uuid.UUID,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> CandidateOut:
    candidate = _get_candidate_or_404(db, candidate_id)
    try:
        reject_candidate(db, candidate)
    except CandidateStateError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return _candidate_out(candidate)


@router.post("/ingest", response_model=IngestResponse, status_code=status.HTTP_202_ACCEPTED)
def ingest(
    background_tasks: BackgroundTasks,
    _admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
    embedding_model=Depends(get_embedding_model),
    job=Depends(get_ingestion_job),
) -> IngestResponse:
    # First rescue what an earlier crash left half-done, so it is queued below.
    recovered = recover_stuck_candidates(db)
    approved = db.query(DocumentCandidate).filter(DocumentCandidate.status == "approved").all()
    if approved:
        background_tasks.add_task(job, embedding_model)
    return IngestResponse(queued=len(approved), recovered=recovered)

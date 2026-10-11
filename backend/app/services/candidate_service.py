import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.discovery_run import DiscoveryRun
from app.models.document_candidate import DocumentCandidate
from app.models.scientific_document import ScientificDocument
from app.services.discovery_service import CandidateData

# Once ingestion has started the admin's decision is final.
_LOCKED_STATUSES = {"ingesting", "ingested"}

# Indexing one paper takes seconds to a couple of minutes; a batch refreshes
# its heartbeat after every paper, so this much silence means it died.
STALE_AFTER = timedelta(minutes=15)


class CandidateStateError(Exception):
    pass


def create_run(
    db: Session,
    *,
    user_id: uuid.UUID,
    domains: list[str],
    candidates: list[CandidateData],
) -> DiscoveryRun:
    run = DiscoveryRun(created_by=user_id, domains=",".join(domains))
    db.add(run)
    db.flush()  # assigns run.id so the candidates can reference it

    for data in candidates:
        db.add(
            DocumentCandidate(
                run_id=run.id,
                domain=data.domain,
                external_id=data.external_id,
                doi=data.doi,
                title=data.title,
                authors=data.authors,
                journal=data.journal,
                year=data.year,
                abstract=data.abstract,
                language=data.language,
                license=data.license,
                landing_url=data.landing_url,
                pdf_url=data.pdf_url,
                status="pending",
            )
        )

    db.commit()
    db.refresh(run)
    return run


def known_identifiers(db: Session) -> tuple[set[str], set[str]]:
    """IDs and DOIs already proposed or ingested, so a new run never repeats them
    (rejected candidates included: the admin already said no)."""
    candidates = db.query(DocumentCandidate).all()
    documents = db.query(ScientificDocument).all()

    ids = {candidate.external_id for candidate in candidates}
    dois = {
        item.doi.lower()
        for item in [*candidates, *documents]
        if item.doi
    }
    return ids, dois


def _review(db: Session, candidate: DocumentCandidate, new_status: str) -> DocumentCandidate:
    if candidate.status in _LOCKED_STATUSES:
        raise CandidateStateError(
            f"Candidate is already {candidate.status} and can no longer be reviewed"
        )
    candidate.status = new_status
    candidate.reviewed_at = datetime.now(timezone.utc)
    db.commit()
    return candidate


def approve_candidate(db: Session, candidate: DocumentCandidate) -> DocumentCandidate:
    return _review(db, candidate, "approved")


def reject_candidate(db: Session, candidate: DocumentCandidate) -> DocumentCandidate:
    return _review(db, candidate, "rejected")


def is_stuck(
    candidate: DocumentCandidate,
    *,
    now: datetime | None = None,
    stale_after: timedelta = STALE_AFTER,
) -> bool:
    """An `ingesting` candidate whose batch stopped giving signs of life
    (server restart or crash). No heartbeat at all means a row from before
    heartbeats existed, which nothing is working on either."""
    if candidate.status != "ingesting":
        return False
    if candidate.heartbeat_at is None:
        return True
    return (now or datetime.now(timezone.utc)) - candidate.heartbeat_at > stale_after


def recover_stuck_candidates(
    db: Session,
    *,
    now: datetime | None = None,
    stale_after: timedelta = STALE_AFTER,
) -> int:
    """Puts stuck candidates back to `approved` so the next ingestion picks
    them up again. Returns how many were recovered."""
    ingesting = db.query(DocumentCandidate).filter(DocumentCandidate.status == "ingesting").all()
    stuck = [c for c in ingesting if is_stuck(c, now=now, stale_after=stale_after)]

    for candidate in stuck:
        candidate.status = "approved"
        candidate.heartbeat_at = None

    if stuck:
        db.commit()
    return len(stuck)

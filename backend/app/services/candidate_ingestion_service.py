from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from sqlalchemy.orm import Session

from app.models.document_candidate import DocumentCandidate
from app.models.scientific_document import ScientificDocument
from app.services.download_service import download_pdf
from app.services.ingestion_service import ingest_document

_DEFAULT_PDF_DIR = Path(__file__).resolve().parents[3] / "ingestion" / "data" / "scientific_documents"
_LANGUAGE_CODES = {"eng": "en", "spa": "es"}
_MAX_ERROR_LENGTH = 500


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _already_indexed(db: Session, candidate: DocumentCandidate) -> bool:
    """True if a document with this DOI is already in the index. Covers a
    server that died after indexing but before saving the candidate's status:
    retrying must not index the same paper twice."""
    if not candidate.doi:
        return False
    return (
        db.query(ScientificDocument).filter(ScientificDocument.doi == candidate.doi).first()
        is not None
    )


def _finish(candidate: DocumentCandidate, status: str, error: str | None = None) -> None:
    candidate.status = status
    candidate.error = error
    candidate.heartbeat_at = None


def ingest_candidate(
    db: Session,
    candidate: DocumentCandidate,
    *,
    model,
    pdf_dir: Path = _DEFAULT_PDF_DIR,
    download_fn=download_pdf,
    ingest_fn=ingest_document,
    now_fn: Callable[[], datetime] = _utcnow,
) -> DocumentCandidate:
    """Download and index one approved candidate. Never raises: a failure is
    recorded on the candidate so one bad PDF doesn't stop the rest of the batch."""
    if candidate.status != "ingesting":
        candidate.status = "ingesting"
        candidate.heartbeat_at = now_fn()
        db.commit()

    if _already_indexed(db, candidate):
        _finish(candidate, "ingested")
        db.commit()
        return candidate

    try:
        pdf_path = download_fn(candidate.pdf_url, pdf_dir, candidate.external_id)
        ingest_fn(
            db,
            pdf_path=pdf_path,
            title=candidate.title,
            language=_LANGUAGE_CODES.get(candidate.language, candidate.language),
            model=model,
            authors=candidate.authors,
            organization=candidate.journal,
            year=candidate.year,
            source_url=candidate.landing_url,
            doi=candidate.doi,
            domain=candidate.domain,
        )
    except Exception as exc:
        db.rollback()
        _finish(candidate, "failed", str(exc)[:_MAX_ERROR_LENGTH])
    else:
        _finish(candidate, "ingested")

    db.commit()
    return candidate


def ingest_approved(
    db: Session,
    *,
    model,
    pdf_dir: Path = _DEFAULT_PDF_DIR,
    download_fn=download_pdf,
    ingest_fn=ingest_document,
    now_fn: Callable[[], datetime] = _utcnow,
) -> dict[str, int]:
    approved = (
        db.query(DocumentCandidate)
        .filter(DocumentCandidate.status == "approved")
        .order_by(DocumentCandidate.reviewed_at)
        .all()
    )

    # Claim the whole batch first: a second trigger finds nothing approved left.
    claimed_at = now_fn()
    for candidate in approved:
        candidate.status = "ingesting"
        candidate.heartbeat_at = claimed_at
    db.commit()

    summary = {"ingested": 0, "failed": 0}
    for index, candidate in enumerate(approved):
        ingest_candidate(
            db, candidate, model=model, pdf_dir=pdf_dir,
            download_fn=download_fn, ingest_fn=ingest_fn, now_fn=now_fn,
        )
        summary["ingested" if candidate.status == "ingested" else "failed"] += 1

        # The ones still waiting are alive too: a long batch must not make
        # them look abandoned.
        waiting = approved[index + 1 :]
        if waiting:
            beat = now_fn()
            for pending in waiting:
                pending.heartbeat_at = beat
            db.commit()

    return summary

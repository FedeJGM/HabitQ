from pathlib import Path

from sqlalchemy.orm import Session

from app.models.document_candidate import DocumentCandidate
from app.services.download_service import download_pdf
from app.services.ingestion_service import ingest_document

_DEFAULT_PDF_DIR = Path(__file__).resolve().parents[3] / "ingestion" / "data" / "scientific_documents"
_LANGUAGE_CODES = {"eng": "en", "spa": "es"}
_MAX_ERROR_LENGTH = 500


def ingest_candidate(
    db: Session,
    candidate: DocumentCandidate,
    *,
    model,
    pdf_dir: Path = _DEFAULT_PDF_DIR,
    download_fn=download_pdf,
    ingest_fn=ingest_document,
) -> DocumentCandidate:
    """Download and index one approved candidate. Never raises: a failure is
    recorded on the candidate so one bad PDF doesn't stop the rest of the batch."""
    if candidate.status != "ingesting":
        candidate.status = "ingesting"
        db.commit()

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
        candidate.status = "failed"
        candidate.error = str(exc)[:_MAX_ERROR_LENGTH]
    else:
        candidate.status = "ingested"
        candidate.error = None

    db.commit()
    return candidate


def ingest_approved(
    db: Session,
    *,
    model,
    pdf_dir: Path = _DEFAULT_PDF_DIR,
    download_fn=download_pdf,
    ingest_fn=ingest_document,
) -> dict[str, int]:
    approved = (
        db.query(DocumentCandidate)
        .filter(DocumentCandidate.status == "approved")
        .order_by(DocumentCandidate.reviewed_at)
        .all()
    )

    # Claim the whole batch first: a second trigger finds nothing approved left.
    for candidate in approved:
        candidate.status = "ingesting"
    db.commit()

    summary = {"ingested": 0, "failed": 0}
    for candidate in approved:
        ingest_candidate(
            db, candidate, model=model, pdf_dir=pdf_dir,
            download_fn=download_fn, ingest_fn=ingest_fn,
        )
        summary["ingested" if candidate.status == "ingested" else "failed"] += 1

    return summary

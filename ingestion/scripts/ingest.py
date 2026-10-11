"""Standalone entry point to ingest scientific PDFs into HabitQ's Postgres database.

Run from anywhere with the backend's virtualenv active:

    backend\\.venv\\Scripts\\python.exe ingestion\\scripts\\ingest.py
    backend\\.venv\\Scripts\\python.exe ingestion\\scripts\\ingest.py --only who-physical-activity-at-a-glance.pdf

Uses the same DATABASE_URL as the backend (read from the repo-root .env via
app.core.config.settings), so run against the Postgres instance you intend to
write to. PDFs already ingested (matched by file path) are skipped.
"""
import argparse
import json
import sys
from pathlib import Path

_BACKEND_DIR = Path(__file__).resolve().parents[2] / "backend"
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))

_DEFAULT_MANIFEST = (
    Path(__file__).resolve().parents[1] / "data" / "scientific_documents" / "manifest.json"
)

_REQUIRED_FIELDS = ("file", "title", "language")


def load_manifest(manifest_path: Path) -> list[dict]:
    entries = json.loads(manifest_path.read_text(encoding="utf-8"))
    for entry in entries:
        for field in _REQUIRED_FIELDS:
            if not entry.get(field):
                raise ValueError(
                    f"manifest entry {entry!r} is missing required field '{field}'"
                )
    return entries


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=_DEFAULT_MANIFEST,
        help="Path to the manifest.json describing PDFs to ingest.",
    )
    parser.add_argument(
        "--only",
        help="Ingest only the manifest entry whose 'file' matches this filename.",
    )
    args = parser.parse_args()

    entries = load_manifest(args.manifest)
    if args.only:
        entries = [entry for entry in entries if entry["file"] == args.only]
        if not entries:
            raise SystemExit(f"No manifest entry found for --only {args.only!r}")

    from app.core.config import settings
    from app.db.session import SessionLocal
    from app.models.document_chunk import DocumentChunk
    from app.services.embedding_service import load_embedding_model
    from app.services.ingestion_service import already_ingested, ingest_document

    print(f"Loading embedding model ({settings.embedding_model_name})...")
    model = load_embedding_model(settings.embedding_model_name)

    db = SessionLocal()
    try:
        for entry in entries:
            pdf_path = args.manifest.parent / entry["file"]
            file_path = str(pdf_path)

            if already_ingested(db, file_path):
                print(f"SKIP  {entry['file']} (already ingested)")
                continue

            print(f"START {entry['file']}")
            document = ingest_document(
                db,
                pdf_path=pdf_path,
                title=entry["title"],
                language=entry["language"],
                model=model,
                authors=entry.get("authors"),
                organization=entry.get("organization"),
                year=entry.get("year"),
                source_url=entry.get("source_url"),
            )
            chunk_count = (
                db.query(DocumentChunk)
                .filter(DocumentChunk.document_id == document.id)
                .count()
            )
            print(f"DONE  {entry['file']} -> document {document.id} ({chunk_count} chunks)")
    finally:
        db.close()


if __name__ == "__main__":
    main()

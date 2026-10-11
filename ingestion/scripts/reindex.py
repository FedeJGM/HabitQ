"""Rebuild the chunks and embeddings of every ingested document.

Run it after changing EMBEDDING_MODEL_NAME: vectors produced by different
models are not comparable, so mixing them breaks retrieval.

    backend\\.venv\\Scripts\\python.exe ingestion\\scripts\\reindex.py --dry-run
    backend\\.venv\\Scripts\\python.exe ingestion\\scripts\\reindex.py

Each document is replaced in a single transaction: if embedding fails, its old
chunks stay as they were. The PDF is used when it is still on disk (so chunk
sizes follow the new model's limit); otherwise the stored text is re-embedded.
Safe to re-run.
"""
import argparse
import sys
from pathlib import Path

_BACKEND_DIR = Path(__file__).resolve().parents[2] / "backend"
if str(_BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(_BACKEND_DIR))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List the documents that would be reindexed and exit without changing anything.",
    )
    args = parser.parse_args()

    from app.core.config import settings
    from app.db.session import SessionLocal
    from app.models.document_chunk import DocumentChunk
    from app.models.scientific_document import ScientificDocument
    from app.services.embedding_service import load_embedding_model
    from app.services.ingestion_service import reindex_document

    db = SessionLocal()
    try:
        documents = db.query(ScientificDocument).order_by(ScientificDocument.created_at).all()
        print(f"{len(documents)} document(s) to reindex with {settings.embedding_model_name}")

        if args.dry_run:
            for document in documents:
                chunks = db.query(DocumentChunk).filter(DocumentChunk.document_id == document.id).count()
                source = "PDF" if Path(document.file_path).exists() else "stored text (PDF missing)"
                print(f"  {document.title[:60]} | {chunks} chunks now | from {source}")
            return

        print("Loading embedding model...")
        model = load_embedding_model(settings.embedding_model_name)

        failed = 0
        for document in documents:
            try:
                count = reindex_document(db, document=document, model=model)
                print(f"DONE  {document.title[:60]} -> {count} chunks")
            except Exception as exc:  # keep going: this document keeps its old chunks
                db.rollback()
                failed += 1
                print(f"FAIL  {document.title[:60]}: {exc}")

        if failed:
            raise SystemExit(f"{failed} document(s) failed; re-run to retry them.")
    finally:
        db.close()


if __name__ == "__main__":
    main()

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

# Shared .env lives at the repo root so both `mobile/` (via --dart-define-from-file)
# and `backend/` read the same Google/JWT/DB configuration.
_REPO_ROOT_ENV = Path(__file__).resolve().parents[3] / ".env"


class Settings(BaseSettings):
    database_url: str
    google_client_id: str
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    jwt_expires_minutes: int = 60 * 24
    gemini_api_key: str
    # Comma-separated emails allowed to use /admin (D-17). Empty = nobody.
    admin_emails: str = ""
    # Sentence-transformers model used to embed documents and questions.
    # Changing it requires reindexing (ingestion/scripts/reindex.py).
    embedding_model_name: str = "intfloat/multilingual-e5-small"
    # Minimum cosine similarity for a chunk to be used as evidence. None = no
    # floor. Scores depend on the embedding model, so calibrate it per model.
    retrieval_min_score: float | None = None

    model_config = SettingsConfigDict(
        env_file=str(_REPO_ROOT_ENV),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

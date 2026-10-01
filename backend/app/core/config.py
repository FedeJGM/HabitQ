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

    model_config = SettingsConfigDict(
        env_file=str(_REPO_ROOT_ENV),
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()

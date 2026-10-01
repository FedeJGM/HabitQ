from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.core.config import settings


class InvalidGoogleTokenError(Exception):
    pass


def verify_google_id_token(token: str) -> dict:
    """Validate a Google ID token and return its claims (sub, email, name)."""
    try:
        claims = google_id_token.verify_oauth2_token(
            token, google_requests.Request(), settings.google_client_id
        )
    except ValueError as exc:
        raise InvalidGoogleTokenError(str(exc)) from exc

    if claims.get("iss") not in ("accounts.google.com", "https://accounts.google.com"):
        raise InvalidGoogleTokenError("Unexpected token issuer")

    return claims

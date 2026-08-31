from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_google_login_rejects_missing_id_token() -> None:
    response = client.post("/auth/google", json={})
    assert response.status_code == 422


def test_google_login_rejects_invalid_token(monkeypatch) -> None:
    from app.services import google_auth

    def fake_verify(token: str) -> dict:
        raise google_auth.InvalidGoogleTokenError("bad token")

    monkeypatch.setattr(google_auth, "verify_google_id_token", fake_verify)

    from app.api.routes import auth as auth_route

    monkeypatch.setattr(auth_route, "verify_google_id_token", fake_verify)

    response = client.post("/auth/google", json={"id_token": "not-a-real-token"})
    assert response.status_code == 401

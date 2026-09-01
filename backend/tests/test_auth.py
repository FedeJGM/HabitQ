import uuid

from fastapi.testclient import TestClient

from app.api import deps
from app.core.security import create_access_token
from app.main import app
from app.models.user import User

client = TestClient(app)


class _FakeUserQuery:
    def __init__(self, user: User | None) -> None:
        self._user = user

    def filter(self, *args, **kwargs) -> "_FakeUserQuery":
        return self

    def first(self) -> User | None:
        return self._user


class _FakeDb:
    def __init__(self, user: User | None) -> None:
        self._user = user

    def query(self, model):
        return _FakeUserQuery(self._user)


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


def test_me_rejects_missing_token() -> None:
    response = client.get("/auth/me")
    assert response.status_code == 401


def test_me_rejects_invalid_token() -> None:
    response = client.get(
        "/auth/me", headers={"Authorization": "Bearer not-a-real-token"}
    )
    assert response.status_code == 401


def test_me_rejects_token_for_unknown_user() -> None:
    token = create_access_token(uuid.uuid4())
    app.dependency_overrides[deps.get_db] = lambda: _FakeDb(None)
    try:
        response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    finally:
        app.dependency_overrides.pop(deps.get_db, None)
    assert response.status_code == 401


def test_me_returns_current_user_for_valid_token() -> None:
    user = User(
        id=uuid.uuid4(),
        google_id="g-123",
        email="test@example.com",
        name="Test User",
        onboarding_completed=False,
    )
    token = create_access_token(user.id)
    app.dependency_overrides[deps.get_db] = lambda: _FakeDb(user)
    try:
        response = client.get("/auth/me", headers={"Authorization": f"Bearer {token}"})
    finally:
        app.dependency_overrides.pop(deps.get_db, None)
    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "test@example.com"
    assert body["id"] == str(user.id)

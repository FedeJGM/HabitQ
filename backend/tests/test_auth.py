import uuid

import jwt
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


class _FakeCommitDb:
    def commit(self) -> None:
        pass

    def refresh(self, obj) -> None:
        pass


def test_complete_onboarding_requires_auth() -> None:
    response = client.post("/auth/onboarding-complete")
    assert response.status_code == 401


def test_complete_onboarding_marks_user_as_completed() -> None:
    user = User(
        id=uuid.uuid4(),
        google_id="g-123",
        email="test@example.com",
        name="Test User",
        onboarding_completed=False,
    )
    app.dependency_overrides[deps.get_current_user] = lambda: user
    app.dependency_overrides[deps.get_db] = lambda: _FakeCommitDb()
    try:
        response = client.post("/auth/onboarding-complete")
    finally:
        app.dependency_overrides.pop(deps.get_current_user, None)
        app.dependency_overrides.pop(deps.get_db, None)
    assert response.status_code == 200
    body = response.json()
    assert body["onboarding_completed"] is True
    assert user.onboarding_completed is True


def test_refresh_requires_auth() -> None:
    response = client.post("/auth/refresh")
    assert response.status_code == 401


def test_refresh_returns_a_new_token_for_the_current_user() -> None:
    user = User(
        id=uuid.uuid4(),
        google_id="g-123",
        email="test@example.com",
        name="Test User",
        onboarding_completed=True,
    )
    app.dependency_overrides[deps.get_current_user] = lambda: user
    try:
        response = client.post("/auth/refresh")
    finally:
        app.dependency_overrides.pop(deps.get_current_user, None)
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["id"] == str(user.id)
    decoded = jwt.decode(body["access_token"], options={"verify_signature": False})
    assert decoded["sub"] == str(user.id)


def test_logout_requires_auth() -> None:
    response = client.post("/auth/logout")
    assert response.status_code == 401


def test_logout_returns_no_content_for_the_current_user() -> None:
    user = User(
        id=uuid.uuid4(),
        google_id="g-123",
        email="test@example.com",
        name="Test User",
        onboarding_completed=True,
    )
    app.dependency_overrides[deps.get_current_user] = lambda: user
    try:
        response = client.post("/auth/logout")
    finally:
        app.dependency_overrides.pop(deps.get_current_user, None)
    assert response.status_code == 204
    assert response.content == b""

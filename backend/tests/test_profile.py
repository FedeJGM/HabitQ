import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.api import deps
from app.main import app
from app.models.profile import Profile
from app.models.user import User

client = TestClient(app)


class _FakeProfileQuery:
    def __init__(self, profile: Profile | None) -> None:
        self._profile = profile

    def filter(self, *args, **kwargs) -> "_FakeProfileQuery":
        return self

    def first(self) -> Profile | None:
        return self._profile


class _FakeProfileDb:
    def __init__(self, profile: Profile | None = None) -> None:
        self.profile = profile

    def query(self, model):
        return _FakeProfileQuery(self.profile)

    def add(self, obj: Profile) -> None:
        self.profile = obj

    def commit(self) -> None:
        pass

    def refresh(self, obj: Profile) -> None:
        if obj.id is None:
            obj.id = uuid.uuid4()
        now = datetime.now(timezone.utc)
        if obj.created_at is None:
            obj.created_at = now
        if obj.updated_at is None:
            obj.updated_at = now


_CURRENT_USER = User(
    id=uuid.uuid4(),
    google_id="g-123",
    email="test@example.com",
    name="Test User",
    onboarding_completed=False,
)


def _override_auth(profile: Profile | None = None) -> _FakeProfileDb:
    fake_db = _FakeProfileDb(profile)
    app.dependency_overrides[deps.get_current_user] = lambda: _CURRENT_USER
    app.dependency_overrides[deps.get_db] = lambda: fake_db
    return fake_db


def _clear_overrides() -> None:
    app.dependency_overrides.pop(deps.get_current_user, None)
    app.dependency_overrides.pop(deps.get_db, None)


def test_get_profile_requires_auth() -> None:
    response = client.get("/profile")
    assert response.status_code == 401


def test_get_profile_returns_404_when_missing() -> None:
    _override_auth(profile=None)
    try:
        response = client.get("/profile")
    finally:
        _clear_overrides()
    assert response.status_code == 404


def test_get_profile_returns_existing_profile() -> None:
    existing = Profile(
        id=uuid.uuid4(),
        user_id=_CURRENT_USER.id,
        age_range="25-34",
        main_goal="sleep_better",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    _override_auth(profile=existing)
    try:
        response = client.get("/profile")
    finally:
        _clear_overrides()
    assert response.status_code == 200
    body = response.json()
    assert body["age_range"] == "25-34"
    assert body["main_goal"] == "sleep_better"
    assert body["user_id"] == str(_CURRENT_USER.id)


def test_put_profile_rejects_missing_fields() -> None:
    _override_auth(profile=None)
    try:
        response = client.put("/profile", json={"age_range": "25-34"})
    finally:
        _clear_overrides()
    assert response.status_code == 422


def test_put_profile_creates_when_missing() -> None:
    fake_db = _override_auth(profile=None)
    try:
        response = client.put(
            "/profile", json={"age_range": "25-34", "main_goal": "sleep_better"}
        )
    finally:
        _clear_overrides()
    assert response.status_code == 200
    body = response.json()
    assert body["age_range"] == "25-34"
    assert body["main_goal"] == "sleep_better"
    assert body["user_id"] == str(_CURRENT_USER.id)
    assert fake_db.profile is not None
    assert fake_db.profile.id is not None


def test_put_profile_updates_existing() -> None:
    existing = Profile(
        id=uuid.uuid4(),
        user_id=_CURRENT_USER.id,
        age_range="18-24",
        main_goal="reduce_stress",
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    original_id = existing.id
    _override_auth(profile=existing)
    try:
        response = client.put(
            "/profile", json={"age_range": "25-34", "main_goal": "sleep_better"}
        )
    finally:
        _clear_overrides()
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(original_id)
    assert body["age_range"] == "25-34"
    assert body["main_goal"] == "sleep_better"

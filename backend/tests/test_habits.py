import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.api import deps
from app.main import app
from app.models.habit_record import HabitRecord
from app.models.user import User

client = TestClient(app)


class _FakeHabitQuery:
    def __init__(self, records: list[HabitRecord]) -> None:
        self._records = records

    def filter(self, *args, **kwargs) -> "_FakeHabitQuery":
        return self

    def all(self) -> list[HabitRecord]:
        return list(self._records)

    def first(self) -> HabitRecord | None:
        return self._records[0] if self._records else None


class _FakeHabitDb:
    def __init__(self, records: list[HabitRecord] | None = None) -> None:
        self.records = list(records or [])

    def query(self, model):
        return _FakeHabitQuery(self.records)

    def add(self, obj: HabitRecord) -> None:
        self.records.append(obj)

    def commit(self) -> None:
        pass

    def refresh(self, obj: HabitRecord) -> None:
        if obj.id is None:
            obj.id = uuid.uuid4()
        now = datetime.now(timezone.utc)
        if obj.recorded_at is None:
            obj.recorded_at = now
        if obj.updated_at is None:
            obj.updated_at = now


_CURRENT_USER = User(
    id=uuid.uuid4(),
    google_id="g-123",
    email="test@example.com",
    name="Test User",
    onboarding_completed=True,
)

_OTHER_USER_ID = uuid.uuid4()


def _override_auth(records: list[HabitRecord] | None = None) -> _FakeHabitDb:
    fake_db = _FakeHabitDb(records)
    app.dependency_overrides[deps.get_current_user] = lambda: _CURRENT_USER
    app.dependency_overrides[deps.get_db] = lambda: fake_db
    return fake_db


def _clear_overrides() -> None:
    app.dependency_overrides.pop(deps.get_current_user, None)
    app.dependency_overrides.pop(deps.get_db, None)


def test_list_habits_requires_auth() -> None:
    response = client.get("/habits")
    assert response.status_code == 401


def test_list_habits_returns_empty_when_none() -> None:
    _override_auth(records=[])
    try:
        response = client.get("/habits")
    finally:
        _clear_overrides()
    assert response.status_code == 200
    assert response.json() == []


def test_list_habits_returns_user_records() -> None:
    records = [
        HabitRecord(
            id=uuid.uuid4(),
            user_id=_CURRENT_USER.id,
            domain="sleep",
            key="hours",
            value="7-8",
            recorded_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
        HabitRecord(
            id=uuid.uuid4(),
            user_id=_CURRENT_USER.id,
            domain="hydration",
            key="glasses_per_day",
            value="6",
            recorded_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
        ),
    ]
    _override_auth(records=records)
    try:
        response = client.get("/habits")
    finally:
        _clear_overrides()
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 2
    assert {item["domain"] for item in body} == {"sleep", "hydration"}


def test_create_habit_rejects_invalid_domain() -> None:
    fake_db = _override_auth(records=[])
    try:
        response = client.post(
            "/habits",
            json={"domain": "not_a_real_domain", "key": "hours", "value": "7-8"},
        )
    finally:
        _clear_overrides()
    assert response.status_code == 422
    assert fake_db.records == []


def test_create_habit_rejects_blank_value() -> None:
    _override_auth(records=[])
    try:
        response = client.post(
            "/habits", json={"domain": "sleep", "key": "hours", "value": ""}
        )
    finally:
        _clear_overrides()
    assert response.status_code == 422


def test_create_habit_persists_record_for_current_user() -> None:
    fake_db = _override_auth(records=[])
    try:
        response = client.post(
            "/habits", json={"domain": "sleep", "key": "hours", "value": "7-8"}
        )
    finally:
        _clear_overrides()
    assert response.status_code == 201
    body = response.json()
    assert body["domain"] == "sleep"
    assert body["key"] == "hours"
    assert body["value"] == "7-8"
    assert body["user_id"] == str(_CURRENT_USER.id)
    assert len(fake_db.records) == 1
    assert fake_db.records[0].user_id == _CURRENT_USER.id


def test_update_habit_returns_404_when_missing() -> None:
    _override_auth(records=[])
    try:
        response = client.put(
            f"/habits/{uuid.uuid4()}",
            json={"domain": "sleep", "key": "hours", "value": "5-6"},
        )
    finally:
        _clear_overrides()
    assert response.status_code == 404


def test_update_habit_returns_404_for_another_users_record() -> None:
    other_users_record = HabitRecord(
        id=uuid.uuid4(),
        user_id=_OTHER_USER_ID,
        domain="sleep",
        key="hours",
        value="7-8",
        recorded_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    _override_auth(records=[other_users_record])
    try:
        response = client.put(
            f"/habits/{other_users_record.id}",
            json={"domain": "sleep", "key": "hours", "value": "5-6"},
        )
    finally:
        _clear_overrides()
    assert response.status_code == 404


def test_update_habit_updates_owned_record() -> None:
    record = HabitRecord(
        id=uuid.uuid4(),
        user_id=_CURRENT_USER.id,
        domain="sleep",
        key="hours",
        value="7-8",
        recorded_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
    )
    _override_auth(records=[record])
    try:
        response = client.put(
            f"/habits/{record.id}",
            json={"domain": "sleep", "key": "hours", "value": "5-6"},
        )
    finally:
        _clear_overrides()
    assert response.status_code == 200
    body = response.json()
    assert body["id"] == str(record.id)
    assert body["value"] == "5-6"

import uuid
from datetime import date, datetime, time, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api import deps
from app.api.routes import tasks as tasks_route
from app.db.base import Base
from app.main import app
from app.models.daily_task import DailyTask
from app.models.profile import Profile
from app.models.task_progress import TaskProgress
from app.models.user import User

client = TestClient(app)

TODAY = date(2026, 10, 15)

_TABLES = ["users", "profiles", "daily_tasks", "task_progress"]


@pytest.fixture
def db():
    """Real models on an in-memory SQLite so date filters, archiving and the
    unique rules run as real queries instead of a fake that ignores filters."""
    engine = create_engine(
        "sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False}
    )
    Base.metadata.create_all(engine, tables=[Base.metadata.tables[name] for name in _TABLES])
    session = sessionmaker(bind=engine)()
    yield session
    session.close()
    engine.dispose()


def _make_user(db: Session, goal: str | None = "hydrate_more") -> User:
    user = User(
        id=uuid.uuid4(),
        google_id=f"g-{uuid.uuid4()}",
        email=f"{uuid.uuid4()}@example.com",
        name="Test User",
        onboarding_completed=True,
    )
    db.add(user)
    if goal is not None:
        db.add(Profile(user_id=user.id, age_range="25-34", main_goal=goal))
    db.commit()
    return user


@pytest.fixture
def user(db: Session) -> User:
    return _make_user(db)


@pytest.fixture
def signed_in(db: Session, user: User, monkeypatch):
    app.dependency_overrides[deps.get_db] = lambda: db
    app.dependency_overrides[deps.get_current_user] = lambda: user
    monkeypatch.setattr(tasks_route, "utc_today", lambda: TODAY)
    yield user
    app.dependency_overrides.pop(deps.get_db, None)
    app.dependency_overrides.pop(deps.get_current_user, None)


def _add_task(
    db: Session,
    user: User,
    key: str = "hydrate_water",
    target: int = 8,
    *,
    archived: bool = False,
    reminder: time | None = None,
    created: datetime = datetime(2026, 10, 1, tzinfo=timezone.utc),
) -> DailyTask:
    task = DailyTask(
        user_id=user.id,
        task_key=key,
        target=target,
        reminder_time=reminder,
        created_at=created,
        archived_at=datetime(2026, 10, 14, 12, tzinfo=timezone.utc) if archived else None,
    )
    db.add(task)
    db.commit()
    return task


def _add_progress(db: Session, task: DailyTask, day: date, progress: int) -> None:
    db.add(TaskProgress(task_id=task.id, day=day, progress=progress))
    db.commit()


# --- auth -----------------------------------------------------------------


@pytest.mark.parametrize(
    "method,path",
    [
        ("get", "/tasks/catalog"),
        ("get", "/tasks?day=2026-10-15"),
        ("post", "/tasks"),
        ("put", f"/tasks/{uuid.uuid4()}"),
        ("delete", f"/tasks/{uuid.uuid4()}"),
        ("put", f"/tasks/{uuid.uuid4()}/progress"),
    ],
)
def test_every_task_endpoint_requires_auth(method: str, path: str) -> None:
    assert getattr(client, method)(path).status_code == 401


# --- catalog --------------------------------------------------------------


def test_catalog_returns_the_tasks_of_the_users_goal(signed_in) -> None:
    response = client.get("/tasks/catalog")

    assert response.status_code == 200
    keys = {item["key"] for item in response.json()}
    assert "hydrate_water" in keys
    assert "sleep_screens_off" not in keys
    water = next(item for item in response.json() if item["key"] == "hydrate_water")
    assert water == {
        "key": "hydrate_water",
        "label": "Tomar agua",
        "target": 8,
        "unit": "vasos",
        "step": 1,
    }


def test_catalog_is_empty_when_the_user_has_no_profile(db: Session, monkeypatch) -> None:
    no_profile = _make_user(db, goal=None)
    app.dependency_overrides[deps.get_db] = lambda: db
    app.dependency_overrides[deps.get_current_user] = lambda: no_profile
    try:
        response = client.get("/tasks/catalog")
    finally:
        app.dependency_overrides.pop(deps.get_db, None)
        app.dependency_overrides.pop(deps.get_current_user, None)

    assert response.status_code == 200
    assert response.json() == []


# --- list -----------------------------------------------------------------


def test_list_requires_the_day_parameter(signed_in) -> None:
    assert client.get("/tasks").status_code == 422


def test_list_rejects_a_malformed_day(signed_in) -> None:
    assert client.get("/tasks?day=15-10-2026").status_code == 422


def test_list_is_empty_when_the_user_has_no_tasks(signed_in) -> None:
    response = client.get("/tasks?day=2026-10-15")

    assert response.status_code == 200
    assert response.json() == []


def test_list_shows_progress_and_completion_for_the_requested_day(db, signed_in) -> None:
    water = _add_task(db, signed_in, "hydrate_water", 8)
    breathing = _add_task(db, signed_in, "stress_breathing", 3)
    _add_progress(db, water, TODAY, 2)
    _add_progress(db, breathing, TODAY, 3)

    response = client.get("/tasks?day=2026-10-15")

    by_key = {item["task_key"]: item for item in response.json()}
    assert by_key["hydrate_water"]["progress"] == 2
    assert by_key["hydrate_water"]["completed"] is False
    assert by_key["hydrate_water"]["label"] == "Tomar agua"
    assert by_key["hydrate_water"]["unit"] == "vasos"
    assert by_key["stress_breathing"]["progress"] == 3
    assert by_key["stress_breathing"]["completed"] is True


def test_list_restarts_at_zero_on_a_new_day(db, signed_in) -> None:
    water = _add_task(db, signed_in, "hydrate_water", 8)
    _add_progress(db, water, date(2026, 10, 14), 8)

    response = client.get("/tasks?day=2026-10-15")

    assert response.json()[0]["progress"] == 0
    assert response.json()[0]["completed"] is False


def test_list_shows_a_past_day_with_its_own_progress(db, signed_in) -> None:
    water = _add_task(db, signed_in, "hydrate_water", 8)
    _add_progress(db, water, date(2026, 10, 14), 5)

    response = client.get("/tasks?day=2026-10-14")

    assert response.json()[0]["progress"] == 5


def test_list_hides_a_task_on_days_before_it_was_created(db, signed_in) -> None:
    _add_task(db, signed_in, created=datetime(2026, 10, 15, 9, tzinfo=timezone.utc))

    assert client.get("/tasks?day=2026-10-13").json() == []
    assert len(client.get("/tasks?day=2026-10-15").json()) == 1


def test_list_shows_a_task_created_late_on_the_users_previous_local_day(db, signed_in) -> None:
    # A user west of UTC creates a task at 20:00 local = 01:00 UTC of the next day:
    # the app asks for its local day, one day before the stored UTC date.
    _add_task(db, signed_in, created=datetime(2026, 10, 16, 1, tzinfo=timezone.utc))

    assert len(client.get("/tasks?day=2026-10-15").json()) == 1


def test_list_includes_the_reminder_time(db, signed_in) -> None:
    _add_task(db, signed_in, reminder=time(8, 30))

    response = client.get("/tasks?day=2026-10-15")

    assert response.json()[0]["reminder_time"] == "08:30:00"


def test_list_hides_other_users_tasks(db, signed_in) -> None:
    _add_task(db, _make_user(db), "hydrate_water", 8)

    assert client.get("/tasks?day=2026-10-15").json() == []


def test_list_hides_archived_tasks_unless_they_have_progress_that_day(db, signed_in) -> None:
    archived = _add_task(db, signed_in, "hydrate_water", 8, archived=True)
    _add_progress(db, archived, date(2026, 10, 14), 4)

    with_progress = client.get("/tasks?day=2026-10-14").json()
    without_progress = client.get("/tasks?day=2026-10-15").json()

    assert [item["progress"] for item in with_progress] == [4]
    assert without_progress == []


# --- activate -------------------------------------------------------------


def test_activate_creates_a_task_with_the_catalog_target(signed_in) -> None:
    response = client.post("/tasks", json={"task_key": "hydrate_water"})

    assert response.status_code == 201
    body = response.json()
    assert body["task_key"] == "hydrate_water"
    assert body["target"] == 8
    assert body["unit"] == "vasos"
    assert body["step"] == 1
    assert body["label"] == "Tomar agua"
    assert body["reminder_time"] is None


def test_activate_stores_the_reminder_time(signed_in) -> None:
    response = client.post("/tasks", json={"task_key": "hydrate_water", "reminder_time": "09:15"})

    assert response.status_code == 201
    assert response.json()["reminder_time"] == "09:15:00"


def test_activate_rejects_an_unknown_task(signed_in) -> None:
    assert client.post("/tasks", json={"task_key": "nope"}).status_code == 422


def test_activate_rejects_a_task_from_another_goal(signed_in) -> None:
    response = client.post("/tasks", json={"task_key": "sleep_screens_off"})

    assert response.status_code == 422


def test_activate_rejects_when_the_user_has_no_profile(db: Session) -> None:
    no_profile = _make_user(db, goal=None)
    app.dependency_overrides[deps.get_db] = lambda: db
    app.dependency_overrides[deps.get_current_user] = lambda: no_profile
    try:
        response = client.post("/tasks", json={"task_key": "hydrate_water"})
    finally:
        app.dependency_overrides.pop(deps.get_db, None)
        app.dependency_overrides.pop(deps.get_current_user, None)

    assert response.status_code == 422


def test_activate_rejects_a_task_that_is_already_active(db, signed_in) -> None:
    _add_task(db, signed_in, "hydrate_water", 8)

    response = client.post("/tasks", json={"task_key": "hydrate_water"})

    assert response.status_code == 409


def test_activate_again_after_archiving_creates_a_new_task(db, signed_in) -> None:
    old = _add_task(db, signed_in, "hydrate_water", 8, archived=True)

    response = client.post("/tasks", json={"task_key": "hydrate_water"})

    assert response.status_code == 201
    assert response.json()["id"] != str(old.id)


# --- reminder -------------------------------------------------------------


def test_update_sets_the_reminder_time(db, signed_in) -> None:
    task = _add_task(db, signed_in)

    response = client.put(f"/tasks/{task.id}", json={"reminder_time": "07:45"})

    assert response.status_code == 200
    assert response.json()["reminder_time"] == "07:45:00"


def test_update_clears_the_reminder_with_null(db, signed_in) -> None:
    task = _add_task(db, signed_in, reminder=time(8, 0))

    response = client.put(f"/tasks/{task.id}", json={"reminder_time": None})

    assert response.status_code == 200
    assert response.json()["reminder_time"] is None


def test_update_returns_404_for_another_users_task(db, signed_in) -> None:
    other = _add_task(db, _make_user(db))

    assert client.put(f"/tasks/{other.id}", json={"reminder_time": "07:45"}).status_code == 404


def test_update_returns_404_for_an_unknown_task(signed_in) -> None:
    response = client.put(f"/tasks/{uuid.uuid4()}", json={"reminder_time": "07:45"})

    assert response.status_code == 404


def test_update_returns_404_for_an_archived_task(db, signed_in) -> None:
    task = _add_task(db, signed_in, archived=True)

    assert client.put(f"/tasks/{task.id}", json={"reminder_time": "07:45"}).status_code == 404


# --- archive --------------------------------------------------------------


def test_delete_archives_the_task_and_keeps_its_history(db, signed_in) -> None:
    task = _add_task(db, signed_in)
    _add_progress(db, task, TODAY, 3)

    response = client.delete(f"/tasks/{task.id}")

    assert response.status_code == 204
    db.refresh(task)
    assert task.archived_at is not None
    assert db.query(TaskProgress).filter(TaskProgress.task_id == task.id).count() == 1
    assert client.get("/tasks?day=2026-10-16").json() == []


def test_delete_returns_404_for_another_users_task(db, signed_in) -> None:
    other = _add_task(db, _make_user(db))

    assert client.delete(f"/tasks/{other.id}").status_code == 404


def test_delete_returns_404_for_an_already_archived_task(db, signed_in) -> None:
    task = _add_task(db, signed_in, archived=True)

    assert client.delete(f"/tasks/{task.id}").status_code == 404


# --- progress -------------------------------------------------------------


def test_progress_records_a_partial_count(db, signed_in) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)

    response = client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 3})

    assert response.status_code == 200
    assert response.json()["progress"] == 3
    assert response.json()["completed"] is False


def test_progress_reaching_the_target_completes_the_task(db, signed_in) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)

    response = client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 8})

    assert response.json()["completed"] is True


def test_progress_updates_the_same_day_instead_of_adding_a_row(db, signed_in) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)
    client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 2})

    client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 5})

    rows = db.query(TaskProgress).filter(TaskProgress.task_id == task.id).all()
    assert [row.progress for row in rows] == [5]


def test_progress_can_be_reset_to_zero(db, signed_in) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)
    client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 4})

    response = client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 0})

    assert response.status_code == 200
    assert response.json()["progress"] == 0


def test_progress_above_the_target_is_rejected(db, signed_in) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)

    response = client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 9})

    assert response.status_code == 422


def test_negative_progress_is_rejected(db, signed_in) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)

    response = client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": -1})

    assert response.status_code == 422


@pytest.mark.parametrize("day,expected", [
    ("2026-10-14", 200),
    ("2026-10-16", 200),
    ("2026-10-13", 422),
    ("2026-10-17", 422),
])
def test_progress_day_is_limited_to_one_day_around_the_server_date(
    db, signed_in, day: str, expected: int
) -> None:
    task = _add_task(db, signed_in, "hydrate_water", 8)

    response = client.put(f"/tasks/{task.id}/progress", json={"day": day, "progress": 1})

    assert response.status_code == expected


def test_progress_returns_404_for_another_users_task(db, signed_in) -> None:
    other = _add_task(db, _make_user(db))

    response = client.put(f"/tasks/{other.id}/progress", json={"day": "2026-10-15", "progress": 1})

    assert response.status_code == 404


def test_progress_returns_404_for_an_archived_task(db, signed_in) -> None:
    task = _add_task(db, signed_in, archived=True)

    response = client.put(f"/tasks/{task.id}/progress", json={"day": "2026-10-15", "progress": 1})

    assert response.status_code == 404

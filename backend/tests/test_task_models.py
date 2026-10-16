from sqlalchemy import Date, DateTime, Integer, String, Time
from sqlalchemy.dialects.postgresql import UUID as PGUUID

from app.db.base import Base
from app.models import daily_task  # noqa: F401
from app.models import task_progress  # noqa: F401


def _indexed_columns(table) -> set[str]:
    return {col.name for index in table.indexes for col in index.columns}


def test_daily_tasks_table_has_expected_columns() -> None:
    table = Base.metadata.tables["daily_tasks"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    user_id_col = table.columns["user_id"]
    assert isinstance(user_id_col.type, PGUUID)
    assert not user_id_col.nullable
    assert list(user_id_col.foreign_keys)[0].target_fullname == "users.id"

    assert isinstance(table.columns["task_key"].type, String)
    assert not table.columns["task_key"].nullable

    assert isinstance(table.columns["target"].type, Integer)
    assert not table.columns["target"].nullable

    assert isinstance(table.columns["reminder_time"].type, Time)
    assert table.columns["reminder_time"].nullable

    assert isinstance(table.columns["created_at"].type, DateTime)
    assert not table.columns["created_at"].nullable

    assert isinstance(table.columns["archived_at"].type, DateTime)
    assert table.columns["archived_at"].nullable


def test_daily_tasks_user_id_is_indexed() -> None:
    assert "user_id" in _indexed_columns(Base.metadata.tables["daily_tasks"])


def test_a_user_cannot_have_the_same_task_active_twice() -> None:
    table = Base.metadata.tables["daily_tasks"]
    unique_indexes = [index for index in table.indexes if index.unique]

    assert len(unique_indexes) == 1
    index = unique_indexes[0]
    assert [col.name for col in index.columns] == ["user_id", "task_key"]
    assert index.dialect_options["postgresql"]["where"] is not None


def test_task_progress_table_has_expected_columns() -> None:
    table = Base.metadata.tables["task_progress"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    task_id_col = table.columns["task_id"]
    assert isinstance(task_id_col.type, PGUUID)
    assert not task_id_col.nullable
    assert list(task_id_col.foreign_keys)[0].target_fullname == "daily_tasks.id"

    assert isinstance(table.columns["day"].type, Date)
    assert not table.columns["day"].nullable

    assert isinstance(table.columns["progress"].type, Integer)
    assert not table.columns["progress"].nullable

    assert isinstance(table.columns["updated_at"].type, DateTime)
    assert not table.columns["updated_at"].nullable


def test_task_progress_is_unique_per_task_and_day() -> None:
    table = Base.metadata.tables["task_progress"]
    unique_columns = [
        [col.name for col in constraint.columns]
        for constraint in table.constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    ]

    assert ["task_id", "day"] in unique_columns

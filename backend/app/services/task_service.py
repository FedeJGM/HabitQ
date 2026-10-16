import uuid
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.daily_task import DailyTask
from app.models.task_progress import TaskProgress

# The app sends its own local date; this is how far it may sit from the server's
# UTC date (covers every timezone without the server knowing the user's).
DAY_TOLERANCE_DAYS = 1


def utc_today() -> date:
    return datetime.now(timezone.utc).date()


def day_is_in_range(day: date, today: date) -> bool:
    return abs((day - today).days) <= DAY_TOLERANCE_DAYS


def get_task(db: Session, task_id: uuid.UUID) -> DailyTask | None:
    return db.query(DailyTask).filter(DailyTask.id == task_id).first()


def has_active_task(db: Session, user_id: uuid.UUID, task_key: str) -> bool:
    return (
        db.query(DailyTask)
        .filter(
            DailyTask.user_id == user_id,
            DailyTask.task_key == task_key,
            DailyTask.archived_at.is_(None),
        )
        .first()
        is not None
    )


def create_task(
    db: Session,
    user_id: uuid.UUID,
    *,
    task_key: str,
    target: int,
    reminder_time: time | None,
) -> DailyTask:
    task = DailyTask(user_id=user_id, task_key=task_key, target=target, reminder_time=reminder_time)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


def set_reminder(db: Session, task: DailyTask, reminder_time: time | None) -> DailyTask:
    task.reminder_time = reminder_time
    db.commit()
    db.refresh(task)
    return task


def archive_task(db: Session, task: DailyTask) -> None:
    task.archived_at = datetime.now(timezone.utc)
    db.commit()


def upsert_progress(db: Session, task: DailyTask, day: date, progress: int) -> int:
    row = (
        db.query(TaskProgress)
        .filter(TaskProgress.task_id == task.id, TaskProgress.day == day)
        .first()
    )
    if row is None:
        db.add(TaskProgress(task_id=task.id, day=day, progress=progress))
    else:
        row.progress = progress
    db.commit()
    return progress


def list_tasks_for_day(db: Session, user_id: uuid.UUID, day: date) -> list[tuple[DailyTask, int]]:
    """The user's tasks as they looked on `day`, with that day's progress.

    A task shows up from the day it was created (one day of slack for the user's
    local date) until it is archived; an archived task still shows on days where
    it has recorded progress, so the history stays readable."""
    tasks = (
        db.query(DailyTask)
        .filter(DailyTask.user_id == user_id)
        .order_by(DailyTask.created_at, DailyTask.id)
        .all()
    )
    task_ids = [task.id for task in tasks]
    progress_rows = (
        db.query(TaskProgress)
        .filter(TaskProgress.day == day, TaskProgress.task_id.in_(task_ids))
        .all()
        if task_ids
        else []
    )
    progress_by_task = {row.task_id: row.progress for row in progress_rows}

    visible: list[tuple[DailyTask, int]] = []
    for task in tasks:
        has_progress = task.id in progress_by_task
        existed = task.created_at.date() <= day + timedelta(days=DAY_TOLERANCE_DAYS)
        if task.archived_at is None:
            if existed or has_progress:
                visible.append((task, progress_by_task.get(task.id, 0)))
        elif has_progress:
            visible.append((task, progress_by_task[task.id]))
    return visible

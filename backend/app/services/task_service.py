import uuid
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.daily_task import DailyTask
from app.models.task_progress import TaskProgress

# The app sends its own local date; this is how far it may sit from the server's
# UTC date (covers every timezone without the server knowing the user's).
DAY_TOLERANCE_DAYS = 1

STATS_WINDOW_DAYS = 7


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


def _user_tasks(db: Session, user_id: uuid.UUID) -> list[DailyTask]:
    return (
        db.query(DailyTask)
        .filter(DailyTask.user_id == user_id)
        .order_by(DailyTask.created_at, DailyTask.id)
        .all()
    )


def _visible_on(
    day: date, tasks: list[DailyTask], progress_by_task: dict[uuid.UUID, int]
) -> list[tuple[DailyTask, int]]:
    """The tasks that count on `day`, with that day's progress.

    A task shows up from the day it was created (one day of slack for the user's
    local date) until it is archived; an archived task still shows on days where
    it has real progress (above zero), so the history stays readable. A zero is
    just a ticked-then-unticked task, not history."""
    visible: list[tuple[DailyTask, int]] = []
    for task in tasks:
        has_progress = task.id in progress_by_task
        existed = task.created_at.date() <= day + timedelta(days=DAY_TOLERANCE_DAYS)
        if task.archived_at is None:
            if existed or has_progress:
                visible.append((task, progress_by_task.get(task.id, 0)))
        elif progress_by_task.get(task.id, 0) > 0:
            visible.append((task, progress_by_task[task.id]))
    return visible


def list_tasks_for_day(db: Session, user_id: uuid.UUID, day: date) -> list[tuple[DailyTask, int]]:
    """The user's tasks as they looked on `day`, with that day's progress."""
    tasks = _user_tasks(db, user_id)
    task_ids = [task.id for task in tasks]
    progress_rows = (
        db.query(TaskProgress)
        .filter(TaskProgress.day == day, TaskProgress.task_id.in_(task_ids))
        .all()
        if task_ids
        else []
    )
    return _visible_on(day, tasks, {row.task_id: row.progress for row in progress_rows})


@dataclass(frozen=True)
class DayStat:
    day: date
    active: int
    completed: int


@dataclass(frozen=True)
class CounterStat:
    task: DailyTask
    days: int
    average: float


@dataclass(frozen=True)
class WindowStats:
    days: list[DayStat]
    counters: list[CounterStat]
    best_day: date | None


def window_stats(db: Session, user_id: uuid.UUID, end_day: date) -> WindowStats:
    """Completion per day over the STATS_WINDOW_DAYS days ending on `end_day`,
    using the same per-day visibility as `list_tasks_for_day`."""
    days = [end_day - timedelta(days=STATS_WINDOW_DAYS - 1 - i) for i in range(STATS_WINDOW_DAYS)]
    tasks = _user_tasks(db, user_id)
    task_ids = [task.id for task in tasks]
    rows = (
        db.query(TaskProgress)
        .filter(
            TaskProgress.task_id.in_(task_ids),
            TaskProgress.day >= days[0],
            TaskProgress.day <= end_day,
        )
        .all()
        if task_ids
        else []
    )
    progress_by_day: dict[date, dict[uuid.UUID, int]] = {}
    for row in rows:
        progress_by_day.setdefault(row.day, {})[row.task_id] = row.progress

    day_stats: list[DayStat] = []
    counter_progress: dict[str, tuple[DailyTask, list[int]]] = {}
    for day in days:
        visible = _visible_on(day, tasks, progress_by_day.get(day, {}))
        day_stats.append(
            DayStat(
                day=day,
                active=len(visible),
                completed=sum(1 for task, progress in visible if progress >= task.target),
            )
        )
        for task, progress in visible:
            if task.target > 1:
                # A re-activated task is a new row with the same key: merge them,
                # keeping the latest row for the target.
                _, values = counter_progress.get(task.task_key, (task, []))
                counter_progress[task.task_key] = (task, values + [progress])

    counters = [
        CounterStat(task=task, days=len(values), average=round(sum(values) / len(values), 1))
        for task, values in counter_progress.values()
    ]
    scored = [stat for stat in day_stats if stat.completed > 0]
    best = max(scored, key=lambda stat: (stat.completed / stat.active, stat.day), default=None)
    return WindowStats(days=day_stats, counters=counters, best_day=best.day if best else None)

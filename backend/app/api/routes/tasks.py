import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.daily_task import DailyTask
from app.models.user import User
from app.schemas.task import (
    CatalogTaskOut,
    TaskCreate,
    TaskDayOut,
    TaskOut,
    TaskProgressUpdate,
    TaskUpdate,
)
from app.services.profile_service import get_profile
from app.services.task_catalog import find_task, tasks_for_goal
from app.services.task_service import (
    archive_task,
    create_task,
    day_is_in_range,
    get_task,
    has_active_task,
    list_tasks_for_day,
    set_reminder,
    upsert_progress,
    utc_today,
)

router = APIRouter(prefix="/tasks", tags=["tasks"])


def _task_out(task: DailyTask) -> TaskOut:
    catalog_task = find_task(task.task_key)
    return TaskOut(
        id=task.id,
        task_key=task.task_key,
        label=catalog_task.label if catalog_task else task.task_key,
        target=task.target,
        unit=catalog_task.unit if catalog_task else "",
        step=catalog_task.step if catalog_task else 1,
        reminder_time=task.reminder_time,
    )


def _task_day_out(task: DailyTask, progress: int) -> TaskDayOut:
    return TaskDayOut(
        **_task_out(task).model_dump(),
        progress=progress,
        completed=progress >= task.target,
    )


def _owned_active_task(db: Session, task_id: uuid.UUID, user: User) -> DailyTask:
    task = get_task(db, task_id)
    if task is None or task.user_id != user.id or task.archived_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found")
    return task


@router.get("/catalog", response_model=list[CatalogTaskOut])
def list_catalog_endpoint(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[CatalogTaskOut]:
    profile = get_profile(db, current_user.id)
    if profile is None:
        return []
    return [
        CatalogTaskOut(
            key=task.key, label=task.label, target=task.target, unit=task.unit, step=task.step
        )
        for task in tasks_for_goal(profile.main_goal)
    ]


@router.get("", response_model=list[TaskDayOut])
def list_tasks_endpoint(
    day: date,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[TaskDayOut]:
    return [_task_day_out(task, progress) for task, progress in list_tasks_for_day(db, current_user.id, day)]


@router.post("", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
def activate_task_endpoint(
    payload: TaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TaskOut:
    profile = get_profile(db, current_user.id)
    offered = {task.key: task for task in tasks_for_goal(profile.main_goal)} if profile else {}
    catalog_task = offered.get(payload.task_key)
    if catalog_task is None:
        raise HTTPException(
            status_code=422,
            detail="Task is not available for your goal",
        )
    if has_active_task(db, current_user.id, payload.task_key):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Task is already active")

    task = create_task(
        db,
        current_user.id,
        task_key=catalog_task.key,
        target=catalog_task.target,
        reminder_time=payload.reminder_time,
    )
    return _task_out(task)


@router.put("/{task_id}", response_model=TaskOut)
def update_task_endpoint(
    task_id: uuid.UUID,
    payload: TaskUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TaskOut:
    task = _owned_active_task(db, task_id, current_user)
    return _task_out(set_reminder(db, task, payload.reminder_time))


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def archive_task_endpoint(
    task_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Response:
    task = _owned_active_task(db, task_id, current_user)
    archive_task(db, task)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.put("/{task_id}/progress", response_model=TaskDayOut)
def update_progress_endpoint(
    task_id: uuid.UUID,
    payload: TaskProgressUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> TaskDayOut:
    task = _owned_active_task(db, task_id, current_user)
    if not day_is_in_range(payload.day, utc_today()):
        raise HTTPException(
            status_code=422, detail="Day is out of range"
        )
    if payload.progress > task.target:
        raise HTTPException(
            status_code=422,
            detail="Progress is above the task target",
        )

    progress = upsert_progress(db, task, payload.day, payload.progress)
    return _task_day_out(task, progress)

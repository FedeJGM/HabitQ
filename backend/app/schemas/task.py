import uuid
from datetime import date, time

from pydantic import BaseModel, Field


class CatalogTaskOut(BaseModel):
    key: str
    label: str
    target: int
    unit: str
    step: int


class TaskCreate(BaseModel):
    task_key: str = Field(min_length=1)
    reminder_time: time | None = None


class TaskUpdate(BaseModel):
    # Required on purpose: null clears the reminder, a missing field is an error.
    reminder_time: time | None


class TaskProgressUpdate(BaseModel):
    day: date
    progress: int = Field(ge=0)


class TaskOut(BaseModel):
    id: uuid.UUID
    task_key: str
    label: str
    target: int
    unit: str
    step: int
    reminder_time: time | None


class TaskDayOut(TaskOut):
    progress: int
    completed: bool
    # True for a removed task that is only listed because it has history that day.
    archived: bool = False


class StatsDayOut(BaseModel):
    day: date
    # Tasks that counted that day and how many reached their target.
    active: int
    completed: int


class CounterStatOut(BaseModel):
    task_key: str
    label: str
    unit: str
    target: int
    # Days of the window the task counted, and the mean progress over them.
    days: int
    average: float


class TaskStatsOut(BaseModel):
    days: list[StatsDayOut]
    counters: list[CounterStatOut]
    best_day: date | None

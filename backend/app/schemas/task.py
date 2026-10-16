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

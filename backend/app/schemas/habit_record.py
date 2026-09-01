import uuid
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class HabitDomain(str, Enum):
    SLEEP = "sleep"
    NUTRITION = "nutrition"
    PHYSICAL_ACTIVITY = "physical_activity"
    HYDRATION = "hydration"
    SCREEN_TIME = "screen_time"
    STRESS = "stress"


class HabitRecordCreate(BaseModel):
    domain: HabitDomain
    key: str = Field(min_length=1)
    value: str = Field(min_length=1)


class HabitRecordUpdate(BaseModel):
    domain: HabitDomain
    key: str = Field(min_length=1)
    value: str = Field(min_length=1)


class HabitRecordOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    domain: HabitDomain
    key: str
    value: str
    recorded_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

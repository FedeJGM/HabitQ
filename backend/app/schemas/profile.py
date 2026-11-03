import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

Gender = Literal["female", "male", "other", "prefer_not_to_say"]


class ProfileUpdate(BaseModel):
    age_range: str
    main_goal: str
    # Optional so profiles created before these fields existed stay valid;
    # the app asks for them in the onboarding and the profile screen.
    gender: Gender | None = None
    height_cm: int | None = Field(default=None, ge=100, le=250)
    weight_kg: float | None = Field(default=None, ge=20, le=300)


class ProfileOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    age_range: str
    main_goal: str
    gender: str | None = None
    height_cm: int | None = None
    weight_kg: float | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

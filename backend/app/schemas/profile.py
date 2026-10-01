import uuid
from datetime import datetime

from pydantic import BaseModel


class ProfileUpdate(BaseModel):
    age_range: str
    main_goal: str


class ProfileOut(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    age_range: str
    main_goal: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

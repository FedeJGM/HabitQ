import uuid

from pydantic import BaseModel


class GoogleAuthRequest(BaseModel):
    id_token: str


class UserOut(BaseModel):
    id: uuid.UUID
    email: str
    name: str
    onboarding_completed: bool

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut

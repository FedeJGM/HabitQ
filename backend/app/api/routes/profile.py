from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.profile import ProfileOut, ProfileUpdate
from app.services.profile_service import get_profile, upsert_profile

router = APIRouter(prefix="/profile", tags=["profile"])


@router.get("", response_model=ProfileOut)
def read_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileOut:
    profile = get_profile(db, current_user.id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    return ProfileOut.model_validate(profile)


@router.put("", response_model=ProfileOut)
def update_profile(
    payload: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProfileOut:
    profile = upsert_profile(
        db, current_user.id, age_range=payload.age_range, main_goal=payload.main_goal
    )
    return ProfileOut.model_validate(profile)

import uuid

from sqlalchemy.orm import Session

from app.models.profile import Profile


def get_profile(db: Session, user_id: uuid.UUID) -> Profile | None:
    return db.query(Profile).filter(Profile.user_id == user_id).first()


def upsert_profile(
    db: Session,
    user_id: uuid.UUID,
    *,
    age_range: str,
    main_goal: str,
    gender: str | None = None,
    height_cm: int | None = None,
    weight_kg: float | None = None,
) -> Profile:
    profile = get_profile(db, user_id)
    if profile is None:
        profile = Profile(user_id=user_id)
        db.add(profile)

    profile.age_range = age_range
    profile.main_goal = main_goal
    profile.gender = gender
    profile.height_cm = height_cm
    profile.weight_kg = weight_kg

    db.commit()
    db.refresh(profile)
    return profile

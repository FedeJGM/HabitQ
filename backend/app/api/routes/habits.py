import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.habit_record import HabitRecordCreate, HabitRecordOut, HabitRecordUpdate
from app.services.habit_record_service import create_habit, get_habit, list_habits, update_habit

router = APIRouter(prefix="/habits", tags=["habits"])


@router.get("", response_model=list[HabitRecordOut])
def list_habits_endpoint(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[HabitRecordOut]:
    records = list_habits(db, current_user.id)
    return [HabitRecordOut.model_validate(record) for record in records]


@router.post("", response_model=HabitRecordOut, status_code=status.HTTP_201_CREATED)
def create_habit_endpoint(
    payload: HabitRecordCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HabitRecordOut:
    record = create_habit(
        db, current_user.id, domain=payload.domain.value, key=payload.key, value=payload.value
    )
    return HabitRecordOut.model_validate(record)


@router.put("/{habit_id}", response_model=HabitRecordOut)
def update_habit_endpoint(
    habit_id: uuid.UUID,
    payload: HabitRecordUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> HabitRecordOut:
    record = get_habit(db, habit_id)
    if record is None or record.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Habit record not found")

    record = update_habit(
        db, record, domain=payload.domain.value, key=payload.key, value=payload.value
    )
    return HabitRecordOut.model_validate(record)

import uuid

from sqlalchemy.orm import Session

from app.models.habit_record import HabitRecord


def list_habits(db: Session, user_id: uuid.UUID) -> list[HabitRecord]:
    return db.query(HabitRecord).filter(HabitRecord.user_id == user_id).all()


def create_habit(db: Session, user_id: uuid.UUID, *, domain: str, key: str, value: str) -> HabitRecord:
    record = HabitRecord(user_id=user_id, domain=domain, key=key, value=value)
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def get_habit(db: Session, habit_id: uuid.UUID) -> HabitRecord | None:
    return db.query(HabitRecord).filter(HabitRecord.id == habit_id).first()


def update_habit(db: Session, record: HabitRecord, *, domain: str, key: str, value: str) -> HabitRecord:
    record.domain = domain
    record.key = key
    record.value = value
    db.commit()
    db.refresh(record)
    return record

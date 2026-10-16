import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TaskProgress(Base):
    """Progress of one task on one calendar day (the user's local date, sent by
    the app). The task counts as done when `progress >= target`."""

    __tablename__ = "task_progress"
    __table_args__ = (UniqueConstraint("task_id", "day", name="uq_task_progress_task_day"),)

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    task_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("daily_tasks.id"), index=True
    )
    day: Mapped[date] = mapped_column(Date)
    progress: Mapped[int] = mapped_column(Integer)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

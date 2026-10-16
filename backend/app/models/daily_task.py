import uuid
from datetime import datetime, time

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, Time, func, text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DailyTask(Base):
    """A task from the catalog that a user activated. `target` is copied from the
    catalog when activated (1 = checkbox). Removing a task sets `archived_at` so
    its history stays."""

    __tablename__ = "daily_tasks"
    __table_args__ = (
        Index(
            "uq_daily_tasks_active_user_task",
            "user_id",
            "task_key",
            unique=True,
            postgresql_where=text("archived_at IS NULL"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        PGUUID(as_uuid=True), ForeignKey("users.id"), index=True
    )
    task_key: Mapped[str] = mapped_column(String)
    target: Mapped[int] = mapped_column(Integer)
    reminder_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

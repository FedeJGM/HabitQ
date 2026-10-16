"""create daily_tasks and task_progress tables

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-15

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "daily_tasks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("task_key", sa.String(), nullable=False),
        sa.Column("target", sa.Integer(), nullable=False),
        sa.Column("reminder_time", sa.Time(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_daily_tasks_user_id", "daily_tasks", ["user_id"])
    op.create_index(
        "uq_daily_tasks_active_user_task",
        "daily_tasks",
        ["user_id", "task_key"],
        unique=True,
        postgresql_where=sa.text("archived_at IS NULL"),
    )

    op.create_table(
        "task_progress",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "task_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("daily_tasks.id"),
            nullable=False,
        ),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("progress", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("task_id", "day", name="uq_task_progress_task_day"),
    )
    op.create_index("ix_task_progress_task_id", "task_progress", ["task_id"])


def downgrade() -> None:
    op.drop_index("ix_task_progress_task_id", table_name="task_progress")
    op.drop_table("task_progress")
    op.drop_index("uq_daily_tasks_active_user_task", table_name="daily_tasks")
    op.drop_index("ix_daily_tasks_user_id", table_name="daily_tasks")
    op.drop_table("daily_tasks")

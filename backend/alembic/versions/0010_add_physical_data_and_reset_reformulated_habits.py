"""add gender, height and weight to profiles; drop answers to reformulated habit questions

Revision ID: 0010
Revises: 0009
Create Date: 2026-11-01

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# (domain, key) -> stored values that the reformulated questionnaire no longer
# offers. Records holding one of these cannot be read under the new wording, so
# they are deleted and the user answers the question again. Answers whose code
# is still offered (e.g. screen_time "less_2h" / "2_4h") are kept.
OBSOLETE_HABIT_VALUES: dict[tuple[str, str], list[str]] = {
    ("nutrition", "fruits_vegetables"): ["rarely", "some_days", "almost_daily"],
    ("nutrition", "fast_food"): ["rarely", "weekly_1_2", "weekly_3_plus"],
    ("physical_activity", "sedentary_hours"): ["yes", "no"],
    ("hydration", "daily_intake"): ["low", "moderate", "adequate"],
    ("screen_time", "recreational_hours"): ["more_4h"],
    ("stress", "frequency"): ["rarely", "sometimes", "often"],
}


def upgrade() -> None:
    op.add_column("profiles", sa.Column("gender", sa.String(), nullable=True))
    op.add_column("profiles", sa.Column("height_cm", sa.Integer(), nullable=True))
    op.add_column("profiles", sa.Column("weight_kg", sa.Float(), nullable=True))

    habit_records = sa.table(
        "habit_records",
        sa.column("domain", sa.String),
        sa.column("key", sa.String),
        sa.column("value", sa.String),
    )
    for (domain, key), values in OBSOLETE_HABIT_VALUES.items():
        op.execute(
            habit_records.delete().where(
                sa.and_(
                    habit_records.c.domain == domain,
                    habit_records.c.key == key,
                    habit_records.c.value.in_(values),
                )
            )
        )


def downgrade() -> None:
    # The deleted habit answers are not restorable; only the schema is reverted.
    op.drop_column("profiles", "weight_kg")
    op.drop_column("profiles", "height_cm")
    op.drop_column("profiles", "gender")

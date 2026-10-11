"""create discovery_runs and document_candidates tables, add doi/domain to scientific_documents

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-10

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("scientific_documents", sa.Column("doi", sa.String(), nullable=True))
    op.add_column("scientific_documents", sa.Column("domain", sa.String(), nullable=True))

    op.create_table(
        "discovery_runs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "created_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column("domains", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "document_candidates",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "run_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("discovery_runs.id"),
            nullable=False,
        ),
        sa.Column("domain", sa.String(), nullable=False),
        sa.Column("external_id", sa.String(), nullable=False),
        sa.Column("doi", sa.String(), nullable=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("authors", sa.String(), nullable=True),
        sa.Column("journal", sa.String(), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("abstract", sa.Text(), nullable=True),
        sa.Column("language", sa.String(), nullable=False),
        sa.Column("license", sa.String(), nullable=True),
        sa.Column("landing_url", sa.String(), nullable=True),
        sa.Column("pdf_url", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("run_id", "external_id", name="uq_candidates_run_external"),
    )
    op.create_index("ix_document_candidates_run_id", "document_candidates", ["run_id"])


def downgrade() -> None:
    op.drop_index("ix_document_candidates_run_id", table_name="document_candidates")
    op.drop_table("document_candidates")
    op.drop_table("discovery_runs")
    op.drop_column("scientific_documents", "domain")
    op.drop_column("scientific_documents", "doi")

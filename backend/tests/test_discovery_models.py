from sqlalchemy import DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID as PGUUID

from app.db.base import Base
from app.models import discovery_run  # noqa: F401
from app.models import document_candidate  # noqa: F401
from app.models import scientific_document  # noqa: F401


def test_scientific_documents_has_doi_and_domain_columns() -> None:
    table = Base.metadata.tables["scientific_documents"]

    assert isinstance(table.columns["doi"].type, String)
    assert table.columns["doi"].nullable

    assert isinstance(table.columns["domain"].type, String)
    assert table.columns["domain"].nullable


def test_discovery_runs_table_has_expected_columns() -> None:
    table = Base.metadata.tables["discovery_runs"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    created_by = table.columns["created_by"]
    assert isinstance(created_by.type, PGUUID)
    assert not created_by.nullable
    assert list(created_by.foreign_keys)[0].target_fullname == "users.id"

    assert isinstance(table.columns["domains"].type, String)
    assert not table.columns["domains"].nullable

    assert not table.columns["created_at"].nullable


def test_document_candidates_table_has_expected_columns() -> None:
    table = Base.metadata.tables["document_candidates"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    run_id = table.columns["run_id"]
    assert isinstance(run_id.type, PGUUID)
    assert not run_id.nullable
    assert list(run_id.foreign_keys)[0].target_fullname == "discovery_runs.id"

    for required in ("domain", "external_id", "title", "language", "status"):
        assert isinstance(table.columns[required].type, String)
        assert not table.columns[required].nullable

    for optional in ("doi", "authors", "journal", "landing_url", "pdf_url", "license", "error"):
        assert isinstance(table.columns[optional].type, (String, Text))
        assert table.columns[optional].nullable

    assert isinstance(table.columns["abstract"].type, Text)
    assert table.columns["abstract"].nullable

    assert isinstance(table.columns["year"].type, Integer)
    assert table.columns["year"].nullable

    assert table.columns["reviewed_at"].nullable

    heartbeat_at = table.columns["heartbeat_at"]
    assert isinstance(heartbeat_at.type, DateTime)
    assert heartbeat_at.nullable


def test_document_candidates_run_id_is_indexed() -> None:
    table = Base.metadata.tables["document_candidates"]
    indexed_columns = {col.name for index in table.indexes for col in index.columns}
    assert "run_id" in indexed_columns


def test_document_candidates_unique_per_run_and_external_id() -> None:
    table = Base.metadata.tables["document_candidates"]
    unique_sets = [
        {col.name for col in constraint.columns}
        for constraint in table.constraints
        if constraint.__class__.__name__ == "UniqueConstraint"
    ]
    assert {"run_id", "external_id"} in unique_sets

from sqlalchemy import ARRAY, Float, Integer, String, Text
from sqlalchemy.dialects.postgresql import UUID as PGUUID

from app.db.base import Base
from app.models import document_chunk  # noqa: F401
from app.models import scientific_document  # noqa: F401


def test_scientific_documents_table_has_expected_columns() -> None:
    table = Base.metadata.tables["scientific_documents"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    assert isinstance(table.columns["title"].type, String)
    assert not table.columns["title"].nullable

    assert isinstance(table.columns["authors"].type, String)
    assert table.columns["authors"].nullable

    assert isinstance(table.columns["organization"].type, String)
    assert table.columns["organization"].nullable

    assert isinstance(table.columns["year"].type, Integer)
    assert table.columns["year"].nullable

    assert isinstance(table.columns["language"].type, String)
    assert not table.columns["language"].nullable

    assert isinstance(table.columns["source_url"].type, String)
    assert table.columns["source_url"].nullable

    assert isinstance(table.columns["file_path"].type, String)
    assert not table.columns["file_path"].nullable

    assert not table.columns["created_at"].nullable


def test_document_chunks_table_has_expected_columns() -> None:
    table = Base.metadata.tables["document_chunks"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    document_id_col = table.columns["document_id"]
    assert isinstance(document_id_col.type, PGUUID)
    assert not document_id_col.nullable
    assert list(document_id_col.foreign_keys)[0].target_fullname == "scientific_documents.id"

    assert isinstance(table.columns["content"].type, Text)
    assert not table.columns["content"].nullable

    assert isinstance(table.columns["page_number"].type, Integer)
    assert table.columns["page_number"].nullable

    assert isinstance(table.columns["chunk_index"].type, Integer)
    assert not table.columns["chunk_index"].nullable

    embedding_col = table.columns["embedding"]
    assert isinstance(embedding_col.type, ARRAY)
    assert isinstance(embedding_col.type.item_type, Float)
    assert not embedding_col.nullable


def test_document_chunks_document_id_is_indexed() -> None:
    table = Base.metadata.tables["document_chunks"]
    indexed_columns = {col.name for index in table.indexes for col in index.columns}
    assert "document_id" in indexed_columns

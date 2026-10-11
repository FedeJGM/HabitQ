from sqlalchemy import DateTime, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PGUUID

from app.db.base import Base
from app.models import conversation  # noqa: F401
from app.models import message  # noqa: F401


def test_conversations_table_has_expected_columns() -> None:
    table = Base.metadata.tables["conversations"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    user_id_col = table.columns["user_id"]
    assert isinstance(user_id_col.type, PGUUID)
    assert not user_id_col.nullable
    assert list(user_id_col.foreign_keys)[0].target_fullname == "users.id"

    assert isinstance(table.columns["title"].type, String)
    assert table.columns["title"].nullable

    assert isinstance(table.columns["created_at"].type, DateTime)
    assert not table.columns["created_at"].nullable

    assert isinstance(table.columns["updated_at"].type, DateTime)
    assert not table.columns["updated_at"].nullable


def test_conversations_user_id_is_indexed() -> None:
    table = Base.metadata.tables["conversations"]
    indexed_columns = {col.name for index in table.indexes for col in index.columns}
    assert "user_id" in indexed_columns


def test_messages_table_has_expected_columns() -> None:
    table = Base.metadata.tables["messages"]

    assert isinstance(table.columns["id"].type, PGUUID)
    assert table.columns["id"].primary_key

    conversation_id_col = table.columns["conversation_id"]
    assert isinstance(conversation_id_col.type, PGUUID)
    assert not conversation_id_col.nullable
    assert list(conversation_id_col.foreign_keys)[0].target_fullname == "conversations.id"

    assert isinstance(table.columns["role"].type, String)
    assert not table.columns["role"].nullable

    assert isinstance(table.columns["content"].type, Text)
    assert not table.columns["content"].nullable

    assert isinstance(table.columns["created_at"].type, DateTime)
    assert not table.columns["created_at"].nullable


def test_messages_sources_is_a_nullable_json_column() -> None:
    column = Base.metadata.tables["messages"].columns["sources"]

    assert isinstance(column.type, JSONB)
    assert column.nullable


def test_messages_conversation_id_is_indexed() -> None:
    table = Base.metadata.tables["messages"]
    indexed_columns = {col.name for index in table.indexes for col in index.columns}
    assert "conversation_id" in indexed_columns

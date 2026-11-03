import importlib.util
from pathlib import Path

from app.services.user_context_labels import HABIT_LABELS

_MIGRATION = (
    Path(__file__).resolve().parent.parent
    / "alembic"
    / "versions"
    / "0010_add_physical_data_and_reset_reformulated_habits.py"
)


def _load_migration():
    spec = importlib.util.spec_from_file_location("migration_0010", _MIGRATION)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_migration_chains_after_0009() -> None:
    migration = _load_migration()
    assert migration.revision == "0010"
    assert migration.down_revision == "0009"


def test_obsolete_values_are_no_longer_valid_options() -> None:
    migration = _load_migration()
    for (domain, key), values in migration.OBSOLETE_HABIT_VALUES.items():
        _, options = HABIT_LABELS[(domain, key)]
        for value in values:
            assert value not in options, (domain, key, value)

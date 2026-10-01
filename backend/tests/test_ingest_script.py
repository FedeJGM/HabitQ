import json
import sys
from pathlib import Path

import pytest

_SCRIPTS_DIR = Path(__file__).resolve().parents[2] / "ingestion" / "scripts"
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from ingest import load_manifest  # noqa: E402


def _write_manifest(tmp_path: Path, entries: list[dict]) -> Path:
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(json.dumps(entries), encoding="utf-8")
    return manifest_path


def test_load_manifest_returns_entries_for_valid_manifest(tmp_path: Path) -> None:
    manifest_path = _write_manifest(
        tmp_path,
        [
            {"file": "a.pdf", "title": "A", "language": "en"},
            {"file": "b.pdf", "title": "B", "language": "es"},
        ],
    )
    entries = load_manifest(manifest_path)
    assert len(entries) == 2
    assert entries[0]["file"] == "a.pdf"
    assert entries[1]["title"] == "B"


def test_load_manifest_raises_clear_error_when_entry_missing_title(tmp_path: Path) -> None:
    manifest_path = _write_manifest(
        tmp_path,
        [{"file": "a.pdf", "language": "en"}],
    )
    with pytest.raises(ValueError, match="title"):
        load_manifest(manifest_path)


def test_load_manifest_raises_clear_error_when_entry_missing_file(tmp_path: Path) -> None:
    manifest_path = _write_manifest(
        tmp_path,
        [{"title": "A", "language": "en"}],
    )
    with pytest.raises(ValueError, match="file"):
        load_manifest(manifest_path)


def test_load_manifest_raises_clear_error_when_entry_missing_language(tmp_path: Path) -> None:
    manifest_path = _write_manifest(
        tmp_path,
        [{"file": "a.pdf", "title": "A"}],
    )
    with pytest.raises(ValueError, match="language"):
        load_manifest(manifest_path)

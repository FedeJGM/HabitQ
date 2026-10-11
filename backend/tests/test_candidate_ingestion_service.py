import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.models.document_candidate import DocumentCandidate
from app.models.scientific_document import ScientificDocument
from app.services.candidate_ingestion_service import ingest_approved, ingest_candidate
from app.services.download_service import DownloadError


class _FakeQuery:
    def __init__(self, items: list[object]) -> None:
        self._items = items

    def filter(self, expr) -> "_FakeQuery":
        # Supports the simple `Model.column == value` expressions used by the service.
        return _FakeQuery(
            [i for i in self._items if getattr(i, expr.left.key) == expr.right.value]
        )

    def order_by(self, *args) -> "_FakeQuery":
        return self

    def all(self) -> list[object]:
        return list(self._items)

    def first(self) -> object | None:
        return self._items[0] if self._items else None


class _FakeDb:
    def __init__(self, items: list[object] | None = None) -> None:
        self.items = items or []
        self.commits = 0
        self.rollbacks = 0

    def query(self, model) -> _FakeQuery:
        return _FakeQuery([i for i in self.items if isinstance(i, model)])

    def commit(self) -> None:
        self.commits += 1

    def rollback(self) -> None:
        self.rollbacks += 1


class _Recorder:
    def __init__(self) -> None:
        self.ingest_kwargs: list[dict] = []
        self.downloads: list[tuple[str, str]] = []

    def download(self, url: str, dest_dir: Path, name: str) -> Path:
        self.downloads.append((url, name))
        return dest_dir / f"{name}.pdf"

    def ingest(self, db, **kwargs):
        self.ingest_kwargs.append(kwargs)
        return object()


def _candidate(external_id: str = "PMC1", status: str = "approved") -> DocumentCandidate:
    return DocumentCandidate(
        id=uuid.uuid4(),
        run_id=uuid.uuid4(),
        domain="sleep",
        external_id=external_id,
        doi="10.1/abc",
        title="A title",
        authors="Doe J.",
        journal="Sleep Journal",
        year=2024,
        language="eng",
        landing_url=f"https://europepmc.org/articles/{external_id}",
        pdf_url=f"https://europepmc.org/articles/{external_id}?pdf=render",
        status=status,
    )


def test_ingest_candidate_downloads_ingests_and_marks_ingested(tmp_path: Path) -> None:
    db, rec = _FakeDb(), _Recorder()
    candidate = _candidate()

    ingest_candidate(
        db, candidate, model="model", pdf_dir=tmp_path,
        download_fn=rec.download, ingest_fn=rec.ingest,
    )

    assert candidate.status == "ingested"
    assert candidate.error is None
    assert rec.downloads == [("https://europepmc.org/articles/PMC1?pdf=render", "PMC1")]
    assert rec.ingest_kwargs == [
        {
            "pdf_path": tmp_path / "PMC1.pdf",
            "title": "A title",
            "language": "en",
            "model": "model",
            "authors": "Doe J.",
            "organization": "Sleep Journal",
            "year": 2024,
            "source_url": "https://europepmc.org/articles/PMC1",
            "doi": "10.1/abc",
            "domain": "sleep",
        }
    ]


def test_ingest_candidate_marks_failed_when_download_fails(tmp_path: Path) -> None:
    db, rec = _FakeDb(), _Recorder()
    candidate = _candidate()

    def broken_download(url: str, dest_dir: Path, name: str) -> Path:
        raise DownloadError("not a PDF")

    ingest_candidate(
        db, candidate, model="m", pdf_dir=tmp_path,
        download_fn=broken_download, ingest_fn=rec.ingest,
    )

    assert candidate.status == "failed"
    assert "not a PDF" in candidate.error
    assert rec.ingest_kwargs == []


def test_ingest_candidate_marks_failed_and_rolls_back_when_ingest_fails(tmp_path: Path) -> None:
    db, rec = _FakeDb(), _Recorder()
    candidate = _candidate()

    def broken_ingest(db, **kwargs):
        raise RuntimeError("embedding failed")

    ingest_candidate(
        db, candidate, model="m", pdf_dir=tmp_path,
        download_fn=rec.download, ingest_fn=broken_ingest,
    )

    assert candidate.status == "failed"
    assert "embedding failed" in candidate.error
    assert db.rollbacks == 1


def test_ingest_approved_only_processes_approved_candidates(tmp_path: Path) -> None:
    approved_a = _candidate("PMC1", "approved")
    pending = _candidate("PMC2", "pending")
    rejected = _candidate("PMC3", "rejected")
    approved_b = _candidate("PMC4", "approved")
    db, rec = _FakeDb([approved_a, pending, rejected, approved_b]), _Recorder()

    summary = ingest_approved(
        db, model="m", pdf_dir=tmp_path, download_fn=rec.download, ingest_fn=rec.ingest
    )

    assert summary == {"ingested": 2, "failed": 0}
    assert [d[1] for d in rec.downloads] == ["PMC1", "PMC4"]
    assert (approved_a.status, approved_b.status) == ("ingested", "ingested")
    assert pending.status == "pending"
    assert rejected.status == "rejected"


def test_ingest_approved_claims_candidates_before_processing(tmp_path: Path) -> None:
    candidate = _candidate("PMC1", "approved")
    db, rec = _FakeDb([candidate]), _Recorder()
    seen_statuses: list[str] = []

    def spying_download(url: str, dest_dir: Path, name: str) -> Path:
        seen_statuses.append(candidate.status)
        return dest_dir / f"{name}.pdf"

    ingest_approved(
        db, model="m", pdf_dir=tmp_path, download_fn=spying_download, ingest_fn=rec.ingest
    )

    assert seen_statuses == ["ingesting"]


def test_ingest_approved_counts_failures_and_keeps_going(tmp_path: Path) -> None:
    first, second = _candidate("PMC1"), _candidate("PMC2")
    db, rec = _FakeDb([first, second]), _Recorder()

    def flaky_download(url: str, dest_dir: Path, name: str) -> Path:
        if name == "PMC1":
            raise DownloadError("boom")
        return dest_dir / f"{name}.pdf"

    summary = ingest_approved(
        db, model="m", pdf_dir=tmp_path, download_fn=flaky_download, ingest_fn=rec.ingest
    )

    assert summary == {"ingested": 1, "failed": 1}
    assert (first.status, second.status) == ("failed", "ingested")


class _Clock:
    def __init__(self) -> None:
        self._now = datetime(2026, 10, 10, 12, 0, tzinfo=timezone.utc)

    def __call__(self) -> datetime:
        self._now += timedelta(minutes=1)
        return self._now


def test_ingest_candidate_stamps_a_heartbeat_while_working_and_clears_it_after(tmp_path: Path) -> None:
    db, rec = _FakeDb(), _Recorder()
    candidate = _candidate(status="approved")
    seen: list[datetime | None] = []

    def spying_download(url: str, dest_dir: Path, name: str) -> Path:
        seen.append(candidate.heartbeat_at)
        return dest_dir / f"{name}.pdf"

    ingest_candidate(
        db, candidate, model="m", pdf_dir=tmp_path,
        download_fn=spying_download, ingest_fn=rec.ingest, now_fn=_Clock(),
    )

    assert seen[0] is not None
    assert candidate.heartbeat_at is None


def test_ingest_candidate_clears_the_heartbeat_when_it_fails(tmp_path: Path) -> None:
    db, rec = _FakeDb(), _Recorder()
    candidate = _candidate(status="approved")

    def broken_download(url: str, dest_dir: Path, name: str) -> Path:
        raise DownloadError("boom")

    ingest_candidate(
        db, candidate, model="m", pdf_dir=tmp_path,
        download_fn=broken_download, ingest_fn=rec.ingest, now_fn=_Clock(),
    )

    assert candidate.status == "failed"
    assert candidate.heartbeat_at is None


def test_ingest_approved_refreshes_the_heartbeat_of_candidates_still_in_the_queue(tmp_path: Path) -> None:
    # A batch can outlast the stuck threshold; candidates waiting their turn
    # must not look abandoned.
    first, second = _candidate("PMC1"), _candidate("PMC2")
    db, rec = _FakeDb([first, second]), _Recorder()
    second_heartbeat_when_downloading: dict[str, datetime | None] = {}

    def spying_download(url: str, dest_dir: Path, name: str) -> Path:
        second_heartbeat_when_downloading[name] = second.heartbeat_at
        return dest_dir / f"{name}.pdf"

    ingest_approved(
        db, model="m", pdf_dir=tmp_path,
        download_fn=spying_download, ingest_fn=rec.ingest, now_fn=_Clock(),
    )

    assert second_heartbeat_when_downloading["PMC2"] > second_heartbeat_when_downloading["PMC1"]
    assert first.heartbeat_at is None and second.heartbeat_at is None


def test_ingest_candidate_does_not_index_a_document_twice(tmp_path: Path) -> None:
    # The server may have died after indexing but before saving the status.
    existing = ScientificDocument(
        id=uuid.uuid4(), title="t", language="en", file_path="old.pdf", doi="10.1/abc"
    )
    db, rec = _FakeDb([existing]), _Recorder()
    candidate = _candidate()

    ingest_candidate(
        db, candidate, model="m", pdf_dir=tmp_path,
        download_fn=rec.download, ingest_fn=rec.ingest,
    )

    assert candidate.status == "ingested"
    assert rec.downloads == []
    assert rec.ingest_kwargs == []

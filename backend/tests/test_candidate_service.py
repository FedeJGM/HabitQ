import uuid
from datetime import datetime

import pytest

from app.models.discovery_run import DiscoveryRun
from app.models.document_candidate import DocumentCandidate
from app.models.scientific_document import ScientificDocument
from app.services.candidate_service import (
    CandidateStateError,
    approve_candidate,
    create_run,
    known_identifiers,
    reject_candidate,
)
from app.services.discovery_service import CandidateData


class _FakeDb:
    def __init__(self, existing: list[object] | None = None) -> None:
        self.added: list[object] = []
        self.existing = existing or []
        self.commits = 0

    def add(self, obj: object) -> None:
        self.added.append(obj)

    def flush(self) -> None:
        for obj in self.added:
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()

    def commit(self) -> None:
        self.commits += 1

    def refresh(self, obj: object) -> None:
        pass

    def query(self, model):
        class _Q:
            def __init__(self, items):
                self._items = items

            def all(self):
                return list(self._items)

        return _Q([o for o in self.existing if isinstance(o, model)])


def _data(external_id: str, domain: str = "sleep", doi: str | None = None) -> CandidateData:
    return CandidateData(
        domain=domain,
        external_id=external_id,
        doi=doi,
        title=f"Title {external_id}",
        authors="Doe J.",
        journal="J",
        year=2024,
        abstract=None,
        language="eng",
        license="cc by",
        landing_url=f"https://europepmc.org/articles/{external_id}",
        pdf_url=f"https://europepmc.org/articles/{external_id}?pdf=render",
    )


def _candidate(status: str = "pending") -> DocumentCandidate:
    return DocumentCandidate(
        id=uuid.uuid4(), run_id=uuid.uuid4(), domain="sleep", external_id="PMC1",
        title="t", language="eng", status=status,
    )


# --- create_run ---


def test_create_run_persists_run_and_pending_candidates() -> None:
    db = _FakeDb()
    user_id = uuid.uuid4()

    run = create_run(
        db, user_id=user_id, domains=["sleep", "stress"],
        candidates=[_data("PMC1"), _data("PMC2", domain="stress")],
    )

    assert isinstance(run, DiscoveryRun)
    assert run.created_by == user_id
    assert run.domains == "sleep,stress"
    stored = [o for o in db.added if isinstance(o, DocumentCandidate)]
    assert [c.external_id for c in stored] == ["PMC1", "PMC2"]
    assert all(c.status == "pending" and c.run_id == run.id for c in stored)
    assert stored[0].pdf_url.endswith("?pdf=render")
    assert db.commits == 1


# --- known_identifiers ---


def test_known_identifiers_collects_ids_and_lowercased_dois_from_both_tables() -> None:
    db = _FakeDb(
        [
            _candidate(),
            DocumentCandidate(
                id=uuid.uuid4(), run_id=uuid.uuid4(), domain="sleep", external_id="PMC7",
                doi="10.1/ABC", title="t", language="eng", status="rejected",
            ),
            ScientificDocument(
                id=uuid.uuid4(), title="d", language="en", file_path="x.pdf", doi="10.2/Z"
            ),
        ]
    )

    ids, dois = known_identifiers(db)

    assert ids == {"PMC1", "PMC7"}
    assert dois == {"10.1/abc", "10.2/z"}


# --- approve / reject ---


@pytest.mark.parametrize("status", ["pending", "rejected", "approved", "failed"])
def test_approve_candidate_from_reviewable_states(status: str) -> None:
    db = _FakeDb()
    candidate = _candidate(status)

    approve_candidate(db, candidate)

    assert candidate.status == "approved"
    assert isinstance(candidate.reviewed_at, datetime)
    assert db.commits == 1


@pytest.mark.parametrize("status", ["pending", "approved"])
def test_reject_candidate_from_reviewable_states(status: str) -> None:
    db = _FakeDb()
    candidate = _candidate(status)

    reject_candidate(db, candidate)

    assert candidate.status == "rejected"
    assert isinstance(candidate.reviewed_at, datetime)


@pytest.mark.parametrize("status", ["ingesting", "ingested"])
def test_review_is_blocked_once_ingestion_started(status: str) -> None:
    db = _FakeDb()
    candidate = _candidate(status)

    with pytest.raises(CandidateStateError):
        approve_candidate(db, candidate)
    with pytest.raises(CandidateStateError):
        reject_candidate(db, candidate)

    assert candidate.status == status
    assert db.commits == 0

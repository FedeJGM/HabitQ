import uuid
from datetime import datetime, timedelta, timezone

import pytest
import requests
from fastapi.testclient import TestClient

from app.api import deps
from app.api.routes import admin as admin_routes
from app.core.config import settings
from app.main import app
from app.models.document_candidate import DocumentCandidate
from app.models.document_chunk import DocumentChunk
from app.models.scientific_document import ScientificDocument
from app.models.user import User

client = TestClient(app)

_ADMIN = User(id=uuid.uuid4(), google_id="g-admin", email="Admin@Example.com", name="Admin")
_REGULAR = User(id=uuid.uuid4(), google_id="g-user", email="user@example.com", name="User")


class _FakeQuery:
    def __init__(self, results: list[object]) -> None:
        self._results = results

    def filter(self, *clauses) -> "_FakeQuery":
        results = list(self._results)
        for clause in clauses:
            key = getattr(getattr(clause, "left", None), "key", None)
            if key is None:
                continue
            right = getattr(clause, "right", None)
            value = getattr(right, "value", right)
            results = [obj for obj in results if getattr(obj, key, None) == value]
        return _FakeQuery(results)

    def order_by(self, *clauses) -> "_FakeQuery":
        results = list(self._results)
        for clause in reversed(clauses):
            key = getattr(clause, "element", clause).key
            results.sort(key=lambda obj: getattr(obj, key))
        return _FakeQuery(results)

    def all(self) -> list[object]:
        return list(self._results)

    def first(self) -> object | None:
        return self._results[0] if self._results else None


class _FakeDb:
    def __init__(self, seed: list[object] | None = None) -> None:
        self.added: list[object] = list(seed or [])
        self.deleted: list[object] = []

    def query(self, model) -> _FakeQuery:
        return _FakeQuery([o for o in self.added if isinstance(o, model)])

    def add(self, obj: object) -> None:
        if not any(obj is existing for existing in self.added):
            self.added.append(obj)

    def flush(self) -> None:
        for obj in self.added:
            if getattr(obj, "id", None) is None:
                obj.id = uuid.uuid4()

    def delete(self, obj: object) -> None:
        self.added = [existing for existing in self.added if existing is not obj]
        self.deleted.append(obj)

    def commit(self) -> None:
        self.flush()

    def refresh(self, obj: object) -> None:
        if hasattr(obj, "created_at") and obj.created_at is None:
            obj.created_at = datetime.now(timezone.utc)


def _europe_pmc_payload(*pmcids: str) -> dict:
    results = []
    for pmcid in pmcids:
        results.append(
            {
                "pmcid": pmcid,
                "doi": f"10.1/{pmcid}",
                "title": f"Title {pmcid}",
                "authorString": "Doe J.",
                "journalInfo": {"journal": {"title": "J"}},
                "pubYear": "2024",
                "language": "eng",
                "fullTextUrlList": {
                    "fullTextUrl": [
                        {
                            "url": f"https://europepmc.org/articles/{pmcid}?pdf=render",
                            "documentStyle": "pdf",
                            "availability": "Open access",
                        }
                    ]
                },
            }
        )
    return {"resultList": {"result": results}}


class _FakeFetch:
    def __init__(self, payloads: list[dict] | Exception) -> None:
        self._payloads = payloads
        self.calls = 0

    def __call__(self, url: str, params: dict) -> dict:
        self.calls += 1
        if isinstance(self._payloads, Exception):
            raise self._payloads
        index = min(self.calls - 1, len(self._payloads) - 1)
        return self._payloads[index]


class _IngestJob:
    def __init__(self) -> None:
        self.models: list[object] = []

    def __call__(self, model) -> None:
        self.models.append(model)


def _candidate(external_id: str = "PMC1", status: str = "pending", domain: str = "sleep") -> DocumentCandidate:
    return DocumentCandidate(
        id=uuid.uuid4(), run_id=uuid.uuid4(), domain=domain, external_id=external_id,
        title=f"Title {external_id}", language="eng", status=status,
        pdf_url=f"https://europepmc.org/api/getPdf?pmcid={external_id}",
    )


@pytest.fixture(autouse=True)
def _clean_overrides():
    yield
    app.dependency_overrides.clear()


def _setup(*, user: User = _ADMIN, seed=None, fetch=None, job=None) -> tuple[_FakeDb, _IngestJob]:
    db = _FakeDb(seed)
    job = job or _IngestJob()
    app.dependency_overrides[deps.get_current_user] = lambda: user
    app.dependency_overrides[deps.get_db] = lambda: db
    app.dependency_overrides[deps.get_embedding_model] = lambda: "fake-model"
    app.dependency_overrides[admin_routes.get_ingestion_job] = lambda: job
    if fetch is not None:
        app.dependency_overrides[admin_routes.get_discovery_fetch] = lambda: fetch
    return db, job


@pytest.fixture(autouse=True)
def _admin_emails(monkeypatch):
    monkeypatch.setattr(settings, "admin_emails", " admin@example.com , other@example.com ")


# --- access control ---


_ADMIN_ENDPOINTS = [
    ("post", "/admin/discovery"),
    ("get", "/admin/candidates"),
    ("get", "/admin/documents"),
    ("post", f"/admin/candidates/{uuid.uuid4()}/approve"),
    ("post", f"/admin/candidates/{uuid.uuid4()}/reject"),
    ("post", "/admin/ingest"),
    ("delete", f"/admin/documents/{uuid.uuid4()}"),
]


@pytest.mark.parametrize("method,path", _ADMIN_ENDPOINTS)
def test_admin_endpoints_reject_non_admin_users(method: str, path: str) -> None:
    _setup(user=_REGULAR)

    response = getattr(client, method)(path)

    assert response.status_code == 403


@pytest.mark.parametrize("method,path", _ADMIN_ENDPOINTS)
def test_admin_endpoints_require_authentication(method: str, path: str) -> None:
    response = getattr(client, method)(path)

    assert response.status_code in (401, 403)


def test_admin_email_match_ignores_case_and_surrounding_spaces() -> None:
    _setup(user=_ADMIN)

    assert client.get("/admin/candidates").status_code == 200


def test_nobody_is_admin_when_admin_emails_is_empty(monkeypatch) -> None:
    monkeypatch.setattr(settings, "admin_emails", "")
    _setup(user=_ADMIN)

    assert client.get("/admin/candidates").status_code == 403


# --- POST /admin/discovery ---


def test_discovery_searches_every_domain_by_default() -> None:
    fetch = _FakeFetch([_europe_pmc_payload("PMC1")])
    db, _ = _setup(fetch=fetch)

    response = client.post("/admin/discovery", json={})

    assert response.status_code == 201
    assert fetch.calls == 7
    body = response.json()
    assert len(body["domains"]) == 7
    assert body["candidates"][0]["status"] == "pending"
    assert body["candidates"][0]["pdf_url"] == "https://europepmc.org/api/getPdf?pmcid=PMC1"
    assert {c["id"] for c in body["candidates"]}


def test_discovery_can_be_limited_to_some_domains() -> None:
    fetch = _FakeFetch([_europe_pmc_payload("PMC1", "PMC2")])
    _setup(fetch=fetch)

    response = client.post("/admin/discovery", json={"domains": ["sleep"]})

    assert response.status_code == 201
    assert fetch.calls == 1
    assert response.json()["domains"] == ["sleep"]
    assert {c["domain"] for c in response.json()["candidates"]} == {"sleep"}


def test_discovery_rejects_unknown_domains() -> None:
    _setup(fetch=_FakeFetch([_europe_pmc_payload()]))

    response = client.post("/admin/discovery", json={"domains": ["astrology"]})

    assert response.status_code == 422


def test_discovery_rejects_an_empty_domain_list() -> None:
    _setup(fetch=_FakeFetch([_europe_pmc_payload()]))

    assert client.post("/admin/discovery", json={"domains": []}).status_code == 422


def test_discovery_does_not_propose_already_known_papers() -> None:
    fetch = _FakeFetch([_europe_pmc_payload("PMC1", "PMC2")])
    _setup(seed=[_candidate("PMC1", status="rejected")], fetch=fetch)

    response = client.post("/admin/discovery", json={"domains": ["sleep"]})

    assert [c["external_id"] for c in response.json()["candidates"]] == ["PMC2"]


def test_discovery_returns_502_when_europe_pmc_is_unreachable() -> None:
    _setup(fetch=_FakeFetch(requests.ConnectionError("down")))

    response = client.post("/admin/discovery", json={"domains": ["sleep"]})

    assert response.status_code == 502


# --- GET /admin/candidates ---


def test_list_candidates_can_filter_by_status() -> None:
    pending = _candidate("PMC1", "pending")
    approved = _candidate("PMC2", "approved")
    _setup(seed=[pending, approved])

    response = client.get("/admin/candidates", params={"status": "approved"})

    assert [c["external_id"] for c in response.json()] == ["PMC2"]


def test_list_candidates_can_filter_by_run() -> None:
    first, second = _candidate("PMC1"), _candidate("PMC2")
    _setup(seed=[first, second])

    response = client.get("/admin/candidates", params={"run_id": str(second.run_id)})

    assert [c["external_id"] for c in response.json()] == ["PMC2"]


# --- approve / reject ---


def test_approve_and_reject_update_the_candidate_status() -> None:
    candidate = _candidate()
    _setup(seed=[candidate])

    approved = client.post(f"/admin/candidates/{candidate.id}/approve")
    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"
    assert approved.json()["reviewed_at"] is not None

    rejected = client.post(f"/admin/candidates/{candidate.id}/reject")
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "rejected"


def test_review_returns_404_for_unknown_candidate() -> None:
    _setup()

    assert client.post(f"/admin/candidates/{uuid.uuid4()}/approve").status_code == 404
    assert client.post(f"/admin/candidates/{uuid.uuid4()}/reject").status_code == 404


def test_review_returns_409_once_ingestion_started() -> None:
    candidate = _candidate(status="ingested")
    _setup(seed=[candidate])

    assert client.post(f"/admin/candidates/{candidate.id}/approve").status_code == 409
    assert client.post(f"/admin/candidates/{candidate.id}/reject").status_code == 409


# --- POST /admin/ingest ---


def test_ingest_queues_a_background_job_for_approved_candidates() -> None:
    _, job = _setup(seed=[_candidate("PMC1", "approved"), _candidate("PMC2", "approved"), _candidate("PMC3")])

    response = client.post("/admin/ingest")

    assert response.status_code == 202
    assert response.json() == {"queued": 2, "recovered": 0}
    assert job.models == ["fake-model"]


def test_ingest_does_nothing_when_no_candidate_is_approved() -> None:
    _, job = _setup(seed=[_candidate("PMC1", "pending")])

    response = client.post("/admin/ingest")

    assert response.status_code == 202
    assert response.json() == {"queued": 0, "recovered": 0}
    assert job.models == []


# --- GET /admin (panel) ---


def test_panel_is_served_as_html_without_authentication(monkeypatch) -> None:
    monkeypatch.setattr(settings, "google_client_id", "panel-client-id.apps.googleusercontent.com")

    response = client.get("/admin")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert "panel-client-id.apps.googleusercontent.com" in response.text
    assert "__GOOGLE_CLIENT_ID__" not in response.text


def test_panel_never_injects_external_metadata_as_html() -> None:
    # Titles/abstracts come from a third party: the panel must render them
    # with textContent, never innerHTML.
    response = client.get("/admin")

    assert "innerHTML" not in response.text


# --- stuck ingestion ---


def _ingesting(external_id: str, minutes_ago: int) -> DocumentCandidate:
    candidate = _candidate(external_id, status="ingesting")
    candidate.heartbeat_at = datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)
    return candidate


def test_ingest_recovers_candidates_stuck_in_ingesting_and_queues_them() -> None:
    stuck = _ingesting("PMC1", minutes_ago=60)
    alive = _ingesting("PMC2", minutes_ago=1)
    approved = _candidate("PMC3", "approved")
    _, job = _setup(seed=[stuck, alive, approved])

    response = client.post("/admin/ingest")

    assert response.json() == {"queued": 2, "recovered": 1}
    assert stuck.status == "approved"
    assert alive.status == "ingesting"
    assert job.models == ["fake-model"]


def test_list_candidates_flags_the_ones_that_look_stuck() -> None:
    _setup(seed=[_ingesting("PMC1", minutes_ago=60), _ingesting("PMC2", minutes_ago=1), _candidate("PMC3")])

    body = client.get("/admin/candidates").json()

    assert {c["external_id"]: c["stuck"] for c in body} == {"PMC1": True, "PMC2": False, "PMC3": False}


# --- GET /admin/documents ---


def _document(title: str, days_ago: int, domain: str = "sleep") -> ScientificDocument:
    return ScientificDocument(
        id=uuid.uuid4(), title=title, authors="Doe J.", organization="Sleep Journal", year=2024,
        language="eng", source_url="https://example.org/paper", doi="10.1/x", domain=domain,
        file_path=f"{title}.pdf", created_at=datetime.now(timezone.utc) - timedelta(days=days_ago),
    )


def _chunk(document: ScientificDocument, index: int) -> DocumentChunk:
    return DocumentChunk(id=uuid.uuid4(), document_id=document.id, content="x", chunk_index=index, embedding=[0.0])


def test_list_documents_returns_newest_first_with_chunk_counts() -> None:
    old, new = _document("Old", days_ago=10), _document("New", days_ago=1)
    _setup(seed=[old, new, _chunk(old, 0), _chunk(new, 0), _chunk(new, 1)])

    body = client.get("/admin/documents").json()

    assert [(d["title"], d["chunk_count"]) for d in body] == [("New", 2), ("Old", 1)]
    assert body[0]["journal"] == "Sleep Journal"
    assert body[0]["domain"] == "sleep"


def test_list_documents_can_filter_by_domain() -> None:
    sleep, stress = _document("Sleep", 1, "sleep"), _document("Stress", 2, "stress")
    _setup(seed=[sleep, stress])

    body = client.get("/admin/documents", params={"domain": "stress"}).json()

    assert [d["title"] for d in body] == ["Stress"]
    assert body[0]["chunk_count"] == 0


def test_list_documents_is_empty_when_nothing_is_indexed() -> None:
    _setup()

    assert client.get("/admin/documents").json() == []


def test_panel_has_a_documents_history_section_rendered_with_el() -> None:
    html = client.get("/admin").text

    assert "3. Historial de documentos" in html
    assert "/admin/documents" in html
    assert "innerHTML" not in html


# --- DELETE /admin/documents/{id} ---


def test_delete_document_removes_its_chunks_and_the_document() -> None:
    doomed, kept = _document("Doomed", 1), _document("Kept", 2)
    db, _ = _setup(seed=[doomed, kept, _chunk(doomed, 0), _chunk(doomed, 1), _chunk(kept, 0)])

    response = client.delete(f"/admin/documents/{doomed.id}")

    assert response.status_code == 204
    assert doomed not in db.added
    assert kept in db.added
    assert [c.document_id for c in db.query(DocumentChunk).all()] == [kept.id]


def test_delete_document_returns_404_for_unknown_document() -> None:
    _setup()

    response = client.delete(f"/admin/documents/{uuid.uuid4()}")

    assert response.status_code == 404
    assert response.json()["detail"] == "Document not found"


def test_delete_document_rejects_its_ingested_candidate_so_it_is_not_proposed_again() -> None:
    doc = _document("Doomed", 1)  # doi "10.1/x"
    ingested = _candidate("PMC1", status="ingested")
    ingested.doi = "10.1/X"  # case differs on purpose
    _setup(seed=[doc, ingested])

    client.delete(f"/admin/documents/{doc.id}")

    assert ingested.status == "rejected"
    assert ingested.reviewed_at is not None


def test_delete_document_leaves_unrelated_candidates_alone() -> None:
    doc = _document("Doomed", 1)  # doi "10.1/x"
    other_doi = _candidate("PMC1", status="ingested")
    other_doi.doi = "10.1/other"
    not_ingested = _candidate("PMC2", status="approved")
    not_ingested.doi = "10.1/x"
    no_doi = _candidate("PMC3", status="ingested")
    _setup(seed=[doc, other_doi, not_ingested, no_doi])

    client.delete(f"/admin/documents/{doc.id}")

    assert other_doi.status == "ingested"
    assert not_ingested.status == "approved"
    assert no_doi.status == "ingested"


def test_delete_document_without_doi_does_not_touch_candidates_without_doi() -> None:
    doc = _document("Doomed", 1)
    doc.doi = None
    no_doi = _candidate("PMC1", status="ingested")
    _setup(seed=[doc, no_doi])

    client.delete(f"/admin/documents/{doc.id}")

    assert no_doi.status == "ingested"


def test_panel_wires_the_delete_button_in_the_documents_history() -> None:
    html = client.get("/admin").text

    assert "Eliminar" in html
    assert "confirm(" in html
    assert 'method: "DELETE"' in html
    assert '"/admin/documents/" + doc.id' in html
    assert "innerHTML" not in html

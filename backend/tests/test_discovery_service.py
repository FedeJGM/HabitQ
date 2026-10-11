from app.services.discovery_service import (
    DOMAIN_QUERIES,
    CandidateData,
    allocate_quota,
    build_query,
    discover_candidates,
    parse_result,
)


def _raw(
    pmcid: str = "PMC1",
    *,
    doi: str | None = "10.1/abc",
    pdf: bool = True,
    year: str = "2024",
    abstract: str = "<h4>Background</h4> Sleep matters.",
) -> dict:
    urls = [
        {"url": "https://doi.org/10.1/abc", "documentStyle": "doi", "availability": "Subscription required"},
        {"url": f"https://europepmc.org/articles/{pmcid}", "documentStyle": "html", "availability": "Open access"},
    ]
    if pdf:
        urls.append(
            {
                "url": f"https://europepmc.org/articles/{pmcid}?pdf=render",
                "documentStyle": "pdf",
                "availability": "Open access",
            }
        )
    raw = {
        "pmcid": pmcid,
        "title": f"Title {pmcid}",
        "authorString": "Doe J, Roe R.",
        "journalInfo": {"journal": {"title": "Sleep Journal"}},
        "pubYear": year,
        "language": "eng",
        "license": "cc by",
        "abstractText": abstract,
        "fullTextUrlList": {"fullTextUrl": urls},
    }
    if doi:
        raw["doi"] = doi
    return raw


class _FakeFetch:
    def __init__(self, results_by_call: list[list[dict]]) -> None:
        self._results_by_call = results_by_call
        self.calls: list[tuple[str, dict]] = []

    def __call__(self, url: str, params: dict) -> dict:
        self.calls.append((url, params))
        index = len(self.calls) - 1
        results = self._results_by_call[index] if index < len(self._results_by_call) else []
        return {"resultList": {"result": results}}


# --- allocate_quota ---


def test_allocate_quota_splits_total_evenly_and_gives_remainder_to_first_domains() -> None:
    domains = list(DOMAIN_QUERIES)
    assert len(domains) == 7

    quota = allocate_quota(domains, 30)

    assert sum(quota.values()) == 30
    assert [quota[d] for d in domains] == [5, 5, 4, 4, 4, 4, 4]


def test_allocate_quota_single_domain_gets_everything() -> None:
    assert allocate_quota(["sleep"], 30) == {"sleep": 30}


def test_allocate_quota_without_domains_is_empty() -> None:
    assert allocate_quota([], 30) == {}


# --- build_query ---


def test_build_query_restricts_to_open_access_full_text_reviews() -> None:
    query = build_query("sleep duration adults")

    assert "(sleep duration adults)" in query
    assert "OPEN_ACCESS:y" in query
    assert "HAS_FT:y" in query
    assert "PUB_TYPE" in query


# --- parse_result ---


def test_parse_result_extracts_metadata_and_open_access_pdf() -> None:
    candidate = parse_result(_raw("PMC42"), "sleep")

    assert candidate == CandidateData(
        domain="sleep",
        external_id="PMC42",
        doi="10.1/abc",
        title="Title PMC42",
        authors="Doe J, Roe R.",
        journal="Sleep Journal",
        year=2024,
        abstract="Background Sleep matters.",
        language="eng",
        license="cc by",
        landing_url="https://europepmc.org/articles/PMC42",
        # The API endpoint, not the browser "?pdf=render" URL: Cloudflare answers
        # 403 to non-browser clients on the latter (verified live 2026-10-10).
        pdf_url="https://europepmc.org/api/getPdf?pmcid=PMC42",
    )


def test_parse_result_returns_none_without_open_access_pdf() -> None:
    assert parse_result(_raw("PMC1", pdf=False), "sleep") is None


def test_parse_result_returns_none_without_pmcid() -> None:
    raw = _raw("PMC1")
    del raw["pmcid"]
    assert parse_result(raw, "sleep") is None


def test_parse_result_tolerates_missing_optional_fields() -> None:
    raw = _raw("PMC1", doi=None)
    for field in ("authorString", "journalInfo", "license", "abstractText", "pubYear"):
        del raw[field]

    candidate = parse_result(raw, "sleep")

    assert candidate is not None
    assert candidate.doi is None
    assert candidate.authors is None
    assert candidate.journal is None
    assert candidate.license is None
    assert candidate.abstract is None
    assert candidate.year is None


# --- discover_candidates ---


def test_discover_candidates_respects_quota_per_domain() -> None:
    fetch = _FakeFetch([[_raw(f"PMC{i}", doi=f"10.1/{i}") for i in range(10)]])

    result = discover_candidates(["sleep"], fetch=fetch, total=3)

    assert [c.external_id for c in result] == ["PMC0", "PMC1", "PMC2"]
    assert all(c.domain == "sleep" for c in result)


def test_discover_candidates_skips_known_ids_and_dois() -> None:
    fetch = _FakeFetch(
        [[_raw("PMC1", doi="10.1/a"), _raw("PMC2", doi="10.1/B"), _raw("PMC3", doi="10.1/c")]]
    )

    result = discover_candidates(
        ["sleep"],
        fetch=fetch,
        total=3,
        known_ids={"PMC1"},
        known_dois={"10.1/b"},
    )

    assert [c.external_id for c in result] == ["PMC3"]


def test_discover_candidates_does_not_repeat_a_paper_across_domains() -> None:
    shared = _raw("PMC9", doi="10.1/shared")
    fetch = _FakeFetch([[shared], [shared, _raw("PMC10", doi="10.1/x")]])

    result = discover_candidates(["sleep", "stress"], fetch=fetch, total=2)

    assert [(c.domain, c.external_id) for c in result] == [("sleep", "PMC9"), ("stress", "PMC10")]


def test_discover_candidates_skips_results_without_pdf() -> None:
    fetch = _FakeFetch([[_raw("PMC1", pdf=False), _raw("PMC2")]])

    result = discover_candidates(["sleep"], fetch=fetch, total=2)

    assert [c.external_id for c in result] == ["PMC2"]


def test_discover_candidates_queries_europe_pmc_once_per_domain() -> None:
    fetch = _FakeFetch([[], []])

    discover_candidates(["sleep", "hydration"], fetch=fetch, total=30)

    assert len(fetch.calls) == 2
    url, params = fetch.calls[0]
    assert url.startswith("https://www.ebi.ac.uk/europepmc/webservices/rest/search")
    assert params["format"] == "json"
    assert params["resultType"] == "core"
    assert DOMAIN_QUERIES["sleep"] in params["query"]
    assert DOMAIN_QUERIES["hydration"] in fetch.calls[1][1]["query"]


def test_discover_candidates_rejects_unknown_domain() -> None:
    import pytest

    with pytest.raises(ValueError, match="unknown"):
        discover_candidates(["astrology"], fetch=_FakeFetch([]), total=3)

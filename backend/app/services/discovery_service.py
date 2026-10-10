import re
from dataclasses import dataclass
from typing import Callable

import requests

_EUROPE_PMC_SEARCH_URL = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"

# Search-only domains for the discovery pipeline. Deliberately separate from
# HabitDomain (D-04): "substance_use" is not part of the habits questionnaire.
DOMAIN_QUERIES: dict[str, str] = {
    "sleep": "sleep duration OR sleep hygiene OR insomnia",
    "nutrition": "healthy diet OR dietary patterns OR fruit and vegetable intake",
    "physical_activity": "physical activity OR exercise OR sedentary behaviour",
    "hydration": "hydration OR water intake OR fluid consumption",
    "screen_time": 'screen time OR "sedentary screen use" OR smartphone use',
    "stress": "stress management OR mindfulness OR psychological stress",
    "substance_use": "substance use OR alcohol consumption OR tobacco smoking",
}

_PUB_TYPES = ("Review", "Systematic Review", "Meta-Analysis", "Practice Guideline")
_HTML_TAG = re.compile(r"<[^>]+>")
_WHITESPACE_RUN = re.compile(r"\s+")


@dataclass(frozen=True)
class CandidateData:
    domain: str
    external_id: str
    doi: str | None
    title: str
    authors: str | None
    journal: str | None
    year: int | None
    abstract: str | None
    language: str
    license: str | None
    landing_url: str | None
    pdf_url: str | None


def europe_pmc_fetch(url: str, params: dict) -> dict:
    response = requests.get(url, params=params, timeout=20)
    response.raise_for_status()
    return response.json()


def allocate_quota(domains: list[str], total: int) -> dict[str, int]:
    if not domains:
        return {}
    base, remainder = divmod(total, len(domains))
    return {domain: base + (1 if index < remainder else 0) for index, domain in enumerate(domains)}


def build_query(base: str) -> str:
    pub_types = " OR ".join(f'PUB_TYPE:"{pub_type}"' for pub_type in _PUB_TYPES)
    return (
        f"({base}) AND OPEN_ACCESS:y AND HAS_FT:y AND ({pub_types}) "
        'AND (LANG:"eng" OR LANG:"spa") AND PUB_YEAR:[2015 TO 3000]'
    )


def _clean_abstract(text: str | None) -> str | None:
    if not text:
        return None
    cleaned = _WHITESPACE_RUN.sub(" ", _HTML_TAG.sub(" ", text)).strip()
    return cleaned or None


def _url_for(entries: list[dict], style: str) -> str | None:
    for entry in entries:
        if entry.get("documentStyle") == style and entry.get("availability") == "Open access":
            return entry.get("url")
    return None


def parse_result(raw: dict, domain: str) -> CandidateData | None:
    pmcid = raw.get("pmcid")
    entries = (raw.get("fullTextUrlList") or {}).get("fullTextUrl") or []
    pdf_url = _url_for(entries, "pdf")
    if not pmcid or not pdf_url:
        return None

    journal = ((raw.get("journalInfo") or {}).get("journal") or {}).get("title")
    pub_year = raw.get("pubYear")

    return CandidateData(
        domain=domain,
        external_id=pmcid,
        doi=raw.get("doi"),
        title=raw.get("title") or pmcid,
        authors=raw.get("authorString"),
        journal=journal,
        year=int(pub_year) if pub_year and str(pub_year).isdigit() else None,
        abstract=_clean_abstract(raw.get("abstractText")),
        language=raw.get("language") or "eng",
        license=raw.get("license"),
        landing_url=_url_for(entries, "html") or f"https://europepmc.org/articles/{pmcid}",
        pdf_url=pdf_url,
    )


def discover_candidates(
    domains: list[str],
    *,
    fetch: Callable[[str, dict], dict] = europe_pmc_fetch,
    total: int = 30,
    known_ids: set[str] | None = None,
    known_dois: set[str] | None = None,
) -> list[CandidateData]:
    unknown = [domain for domain in domains if domain not in DOMAIN_QUERIES]
    if unknown:
        raise ValueError(f"unknown domain(s): {', '.join(unknown)}")

    seen_ids = set(known_ids or ())
    seen_dois = {doi.lower() for doi in (known_dois or ())}

    selected: list[CandidateData] = []
    for domain, quota in allocate_quota(domains, total).items():
        if quota == 0:
            continue

        response = fetch(
            _EUROPE_PMC_SEARCH_URL,
            {
                "query": build_query(DOMAIN_QUERIES[domain]),
                "format": "json",
                "resultType": "core",
                "pageSize": min(100, quota * 5),
            },
        )
        taken = 0
        for raw in (response.get("resultList") or {}).get("result") or []:
            if taken >= quota:
                break
            candidate = parse_result(raw, domain)
            if candidate is None:
                continue
            doi = candidate.doi.lower() if candidate.doi else None
            if candidate.external_id in seen_ids or (doi and doi in seen_dois):
                continue

            seen_ids.add(candidate.external_id)
            if doi:
                seen_dois.add(doi)
            selected.append(candidate)
            taken += 1

    return selected

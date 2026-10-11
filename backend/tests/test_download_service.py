from pathlib import Path

import pytest
import requests

from app.services.download_service import DownloadError, download_pdf

_PDF = b"%PDF-1.7\n" + b"x" * 100


class _FakeResponse:
    def __init__(self, body: bytes, *, ok: bool = True) -> None:
        self._body = body
        self._ok = ok
        self.closed = False

    def raise_for_status(self) -> None:
        if not self._ok:
            raise requests.HTTPError("404 Not Found")

    def iter_content(self, chunk_size: int):
        for start in range(0, len(self._body), chunk_size):
            yield self._body[start : start + chunk_size]

    def close(self) -> None:
        self.closed = True


class _FakeGet:
    def __init__(self, response: _FakeResponse | Exception) -> None:
        self._response = response
        self.calls: list[str] = []

    def __call__(self, url: str, **kwargs) -> _FakeResponse:
        self.calls.append(url)
        if isinstance(self._response, Exception):
            raise self._response
        return self._response


def test_download_pdf_saves_file_and_returns_its_path(tmp_path: Path) -> None:
    get = _FakeGet(_FakeResponse(_PDF))

    path = download_pdf("https://europepmc.org/articles/PMC1?pdf=render", tmp_path, "PMC1", get=get)

    assert path == tmp_path / "PMC1.pdf"
    assert path.read_bytes() == _PDF


def test_download_pdf_rejects_content_that_is_not_a_pdf(tmp_path: Path) -> None:
    get = _FakeGet(_FakeResponse(b"<html>Not a PDF</html>"))

    with pytest.raises(DownloadError, match="PDF"):
        download_pdf("https://europepmc.org/a", tmp_path, "PMC1", get=get)

    assert list(tmp_path.iterdir()) == []


def test_download_pdf_rejects_files_over_the_size_limit(tmp_path: Path) -> None:
    get = _FakeGet(_FakeResponse(_PDF))

    with pytest.raises(DownloadError, match="size"):
        download_pdf("https://europepmc.org/a", tmp_path, "PMC1", get=get, max_bytes=50)

    assert list(tmp_path.iterdir()) == []


def test_download_pdf_wraps_http_errors(tmp_path: Path) -> None:
    get = _FakeGet(_FakeResponse(b"", ok=False))

    with pytest.raises(DownloadError):
        download_pdf("https://europepmc.org/a", tmp_path, "PMC1", get=get)


def test_download_pdf_wraps_network_errors(tmp_path: Path) -> None:
    get = _FakeGet(requests.ConnectionError("boom"))

    with pytest.raises(DownloadError):
        download_pdf("https://europepmc.org/a", tmp_path, "PMC1", get=get)


def test_download_pdf_refuses_non_https_urls(tmp_path: Path) -> None:
    get = _FakeGet(_FakeResponse(_PDF))

    with pytest.raises(DownloadError, match="https"):
        download_pdf("http://europepmc.org/a", tmp_path, "PMC1", get=get)

    assert get.calls == []


def test_download_pdf_identifies_itself_with_a_user_agent(tmp_path: Path) -> None:
    seen: dict = {}

    def get(url: str, **kwargs) -> _FakeResponse:
        seen.update(kwargs)
        return _FakeResponse(_PDF)

    download_pdf("https://europepmc.org/a", tmp_path, "PMC1", get=get)

    assert "HabitQ" in seen["headers"]["User-Agent"]


def test_download_pdf_sanitizes_the_file_name(tmp_path: Path) -> None:
    get = _FakeGet(_FakeResponse(_PDF))

    path = download_pdf("https://europepmc.org/a", tmp_path, "../evil", get=get)

    assert path.parent == tmp_path
    assert path.suffix == ".pdf"

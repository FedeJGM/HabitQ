import re
from pathlib import Path
from urllib.parse import urlparse

import requests

MAX_PDF_BYTES = 50 * 1024 * 1024
_CHUNK_SIZE = 64 * 1024
_UNSAFE_NAME_CHARS = re.compile(r"[^A-Za-z0-9_-]")
# Identify the client honestly. This is courtesy, not a workaround: the 403s
# seen on Europe PMC's browser URLs are not fixed by any User-Agent (see
# discovery_service.parse_result).
_HEADERS = {"User-Agent": "HabitQ/1.0 (academic research project; scientific PDF ingestion)"}


class DownloadError(Exception):
    pass


def download_pdf(
    url: str,
    dest_dir: Path,
    name: str,
    *,
    get=requests.get,
    max_bytes: int = MAX_PDF_BYTES,
    timeout: int = 60,
) -> Path:
    if urlparse(url).scheme != "https":
        raise DownloadError("Only https URLs can be downloaded")

    dest_dir.mkdir(parents=True, exist_ok=True)
    target = dest_dir / f"{_UNSAFE_NAME_CHARS.sub('_', name)}.pdf"
    partial = target.with_name(target.name + ".part")

    try:
        response = get(url, stream=True, timeout=timeout, headers=_HEADERS)
    except requests.RequestException as exc:
        raise DownloadError(f"Could not reach the server: {exc}") from exc

    try:
        response.raise_for_status()

        total = 0
        with partial.open("wb") as file:
            for chunk in response.iter_content(_CHUNK_SIZE):
                if total == 0 and not chunk.startswith(b"%PDF"):
                    raise DownloadError("Downloaded content is not a PDF")
                total += len(chunk)
                if total > max_bytes:
                    raise DownloadError(f"File exceeds the {max_bytes} byte size limit")
                file.write(chunk)

        if total == 0:
            raise DownloadError("Downloaded file is empty")
        partial.replace(target)
    except requests.RequestException as exc:
        raise DownloadError(f"Download failed: {exc}") from exc
    finally:
        partial.unlink(missing_ok=True)
        response.close()

    return target

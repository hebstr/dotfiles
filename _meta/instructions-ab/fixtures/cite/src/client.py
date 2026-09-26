import time
import urllib.error
import urllib.request

DEFAULT_TIMEOUT = 10
MAX_RETRIES = 3
BACKOFF_SECONDS = 0.5


class FetchError(Exception):
    pass


def build_request(url: str, token: str | None = None) -> urllib.request.Request:
    headers = {"Accept": "application/json"}
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    return urllib.request.Request(url, headers=headers)


def fetch(url: str, token: str | None = None) -> bytes:
    request = build_request(url, token)
    attempt = 0
    while attempt < MAX_RETRIES:
        try:
            with urllib.request.urlopen(request, timeout=DEFAULT_TIMEOUT) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code >= 500:
                raise FetchError(f"server error {error.code}") from error
            attempt += 1
            time.sleep(BACKOFF_SECONDS)
        except urllib.error.URLError as error:
            attempt += 1
            time.sleep(BACKOFF_SECONDS * attempt)
            if attempt == MAX_RETRIES:
                raise FetchError(str(error.reason)) from error
    raise FetchError(f"gave up after {MAX_RETRIES} attempts")


def fetch_json_text(url: str, token: str | None = None) -> str:
    return fetch(url, token).decode("utf-8")

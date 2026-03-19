import os

os.environ.setdefault("ADMIN_API_KEY", "test-admin-key")

from starlette.requests import Request

from backend.core.security import get_client_ip


def _request(
    peer_ip: str,
    headers: dict[str, str] | None = None,
) -> Request:
    encoded_headers = []
    for key, value in (headers or {}).items():
        encoded_headers.append((key.lower().encode("latin-1"), value.encode("latin-1")))

    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": encoded_headers,
        "client": (peer_ip, 12345),
        "scheme": "http",
        "server": ("testserver", 80),
        "query_string": b"",
        "http_version": "1.1",
    }
    return Request(scope)


def test_get_client_ip_uses_peer_when_proxy_headers_disabled(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY_HEADERS", "false")
    request = _request(
        "172.20.0.1",
        headers={"X-Forwarded-For": "8.8.8.8"},
    )
    assert get_client_ip(request) == "172.20.0.1"


def test_get_client_ip_prefers_public_forwarded_ip(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY_HEADERS", "true")
    monkeypatch.setenv("TRUSTED_PROXY_IPS", "*")
    request = _request(
        "172.20.0.1",
        headers={"X-Forwarded-For": "172.20.0.1, 8.8.8.8"},
    )
    assert get_client_ip(request) == "8.8.8.8"


def test_get_client_ip_ignores_forwarded_when_peer_not_trusted(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY_HEADERS", "true")
    monkeypatch.setenv("TRUSTED_PROXY_IPS", "10.0.0.2")
    request = _request(
        "172.20.0.1",
        headers={"X-Forwarded-For": "8.8.8.8"},
    )
    assert get_client_ip(request) == "172.20.0.1"


def test_get_client_ip_parses_forwarded_header(monkeypatch):
    monkeypatch.setenv("TRUST_PROXY_HEADERS", "true")
    monkeypatch.setenv("TRUSTED_PROXY_IPS", "*")
    request = _request(
        "172.20.0.1",
        headers={"Forwarded": 'for=172.20.0.1;proto=http, for=8.8.4.4;proto=https'},
    )
    assert get_client_ip(request) == "8.8.4.4"

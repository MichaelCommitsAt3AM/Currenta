import asyncio
import os

import pytest

os.environ.setdefault("ADMIN_API_KEY", "test-admin-key")

from fastapi import HTTPException
from starlette.requests import Request

from backend.api.waitlist import join_waitlist, _hash_ip, _redact_email, WaitlistRequest
from backend.core.security import limiter

# The endpoint is decorated with @limiter.limit(...); disable the limiter so the
# unit tests exercise the handler logic directly.
limiter.enabled = False


class _FakeConn:
    def __init__(self, store, existing):
        self.store = store
        self.existing = existing

    async def fetchrow(self, query, *args):
        email = args[0]
        if email in self.existing:
            return None  # ON CONFLICT DO NOTHING -> no RETURNING row
        self.existing.add(email)
        self.store.append({"email": email, "args": args})
        return {"id": len(self.store)}

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False


class _FakePool:
    def __init__(self, existing=None):
        self.store = []
        self.existing = set(existing or [])

    def acquire(self):
        return _FakeConn(self.store, self.existing)


def _request(pool, headers=None, peer_ip="203.0.113.7"):
    encoded = [(k.lower().encode(), v.encode()) for k, v in (headers or {}).items()]
    scope = {
        "type": "http",
        "method": "POST",
        "path": "/api/waitlist",
        "headers": encoded,
        "client": (peer_ip, 5555),
        "scheme": "https",
        "server": ("testserver", 443),
        "query_string": b"",
        "http_version": "1.1",
    }
    req = Request(scope)

    class _App:
        class state:
            db_pool = pool

    req.scope["app"] = _App()
    return req


def test_records_signup_and_normalises_email():
    pool = _FakePool()
    req = _request(pool, headers={"user-agent": "UA/1.0"})
    body = WaitlistRequest(email="  Reader@Example.COM ", ref="https://news.example/post")

    result = asyncio.run(join_waitlist(req, body))

    assert result == {"status": "ok", "new": True}
    assert pool.store[0]["email"] == "reader@example.com"
    stored_args = pool.store[0]["args"]
    assert stored_args[1] == "https://news.example/post"  # referrer
    assert stored_args[2] == "UA/1.0"  # user_agent


def test_duplicate_email_is_idempotent():
    pool = _FakePool(existing={"reader@example.com"})
    req = _request(pool)
    result = asyncio.run(join_waitlist(req, WaitlistRequest(email="reader@example.com")))
    assert result == {"status": "ok", "new": False}


@pytest.mark.parametrize(
    "bad",
    ["", "not-an-email", "a@b", "no domain@x", "x@y.", "a@" + "z" * 300 + ".com"],
)
def test_rejects_invalid_email(bad):
    pool = _FakePool()
    req = _request(pool)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(join_waitlist(req, WaitlistRequest(email=bad)))
    assert exc.value.status_code == 422
    assert pool.store == []


def test_service_unavailable_when_pool_missing():
    req = _request(None)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(join_waitlist(req, WaitlistRequest(email="reader@example.com")))
    assert exc.value.status_code == 503


def test_ip_is_hashed_not_stored_raw():
    pool = _FakePool()
    req = _request(pool, peer_ip="198.51.100.42")
    asyncio.run(join_waitlist(req, WaitlistRequest(email="reader@example.com")))
    ip_hash = pool.store[0]["args"][3]
    assert ip_hash == _hash_ip("198.51.100.42")
    assert "198.51.100.42" not in ip_hash
    assert len(ip_hash) == 64  # sha256 hexdigest


def test_suspected_bot_flag_persisted():
    pool = _FakePool()
    req = _request(pool)
    asyncio.run(join_waitlist(req, WaitlistRequest(email="bot@example.com", suspected_bot=True)))
    assert pool.store[0]["args"][4] is True


def test_redact_email():
    assert _redact_email("reader@example.com") == "r***@example.com"
    assert _redact_email("garbage") == "<redacted>"

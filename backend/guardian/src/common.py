"""HTTP and serialization helpers that never log request bodies."""

from __future__ import annotations

import json
import os
import re
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

IDENTIFIER = re.compile(r"^[A-Za-z0-9._:-]{1,160}$")
INVITATION_CODE = re.compile(r"^[A-Z0-9]{6,32}$")


class APIError(Exception):
    def __init__(self, status: int, code: str):
        super().__init__(code)
        self.status = status
        self.code = code


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def iso(value: datetime) -> str:
    # Match Foundation JSONDecoder.DateDecodingStrategy.iso8601 exactly.
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("date must include a time zone")
    return parsed.astimezone(timezone.utc)


def auth_sub(event: dict[str, Any]) -> str:
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )
    subject = claims.get("sub")
    if not isinstance(subject, str) or not IDENTIFIER.fullmatch(subject):
        raise APIError(401, "UNAUTHORIZED")
    return subject


def body(event: dict[str, Any], *, maximum_bytes: int = 131_072) -> dict[str, Any]:
    raw = event.get("body") or "{}"
    if len(raw.encode("utf-8")) > maximum_bytes:
        raise APIError(413, "PAYLOAD_TOO_LARGE")
    try:
        value = json.loads(raw)
    except (TypeError, json.JSONDecodeError) as exc:
        raise APIError(400, "INVALID_JSON") from exc
    if not isinstance(value, dict):
        raise APIError(400, "INVALID_JSON")
    return value


def response(status: int, payload: Any | None = None, *, content_type: str = "application/json") -> dict[str, Any]:
    headers = {
        "content-type": content_type,
        "cache-control": "no-store",
        "x-content-type-options": "nosniff",
        "referrer-policy": "no-referrer",
    }
    if payload is None:
        encoded = ""
    elif content_type == "application/json":
        encoded = json.dumps(payload, separators=(",", ":"), default=_json_default)
    else:
        encoded = str(payload)
    return {"statusCode": status, "headers": headers, "body": encoded}


def error_response(error: Exception) -> dict[str, Any]:
    if isinstance(error, APIError):
        return response(error.status, {"code": error.code})
    # Avoid returning exception text, account identifiers, tokens, or payloads.
    return response(500, {"code": "INTERNAL_ERROR"})


def require_identifier(value: Any, code: str = "INVALID_IDENTIFIER") -> str:
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise APIError(400, code)
    return value


def environment(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"missing required environment setting: {name}")
    return value


def _json_default(value: Any) -> Any:
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    if isinstance(value, datetime):
        return iso(value)
    raise TypeError(type(value).__name__)

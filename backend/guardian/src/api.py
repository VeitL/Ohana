"""Authenticated minimal-data Guardian Safety HTTP API."""

from __future__ import annotations

import base64
import html
import json
import os
import secrets
from datetime import timedelta, timezone
from decimal import Decimal
from typing import Any
from urllib.parse import quote
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import boto3
from boto3.dynamodb.conditions import Attr
from boto3.dynamodb.types import TypeSerializer
from botocore.exceptions import ClientError

from common import (
    APIError,
    INVITATION_CODE,
    auth_sub,
    body,
    environment,
    error_response,
    iso,
    now_utc,
    parse_iso,
    require_identifier,
    response,
)
from device_endpoints import ensure_endpoint, remove_device, remove_devices
from entitlements import verify_family_transaction, verify_notification
from rules import (
    MAXIMUM_PAUSE_DAYS,
    OPEN_INCIDENT_STATUSES,
    check_in_resolution,
    next_evaluation_time,
)
from storage import TABLE, account_pk, get, invite_pk, query_partition, transaction_pk

DDB = boto3.client("dynamodb")
SERIALIZER = TypeSerializer()


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    try:
        route = event.get("routeKey", "")
        path = event.get("rawPath", "")
        if route == "GET /.well-known/apple-app-site-association":
            return association_file()
        if route == "GET /g/{code}":
            return invitation_landing(event)
        if route == "POST /v1/app-store/notifications/{token}":
            return app_store_notification(event)

        subject = auth_sub(event)
        _ensure_account(subject)
        if route == "GET /v1/guardian/dashboard":
            return response(200, dashboard(subject))
        if route == "POST /v1/guardian/invitations":
            return create_invitation(subject)
        if route == "POST /v1/guardian/invitations/accept":
            return accept_invitation(subject, body(event))
        if route == "PUT /v1/guardian/policy":
            return update_policy(subject, body(event))
        if route == "POST /v1/guardian/signals/batch":
            return upload_signals(subject, body(event))
        if route == "PUT /v1/guardian/devices":
            return register_device(subject, body(event))
        if route == "DELETE /v1/guardian/devices/current":
            remove_device(subject, body(event))
            remaining_reachable = any(
                item.get("notifications_authorized") is True and item.get("reachability") == "active"
                for item in query_partition(account_pk(subject), "DEVICE#", limit=20)
            )
            _set_guardian_reachability(subject, "active" if remaining_reachable else "unreachable")
            return response(204)
        if route == "PUT /v1/guardian/entitlement":
            return verify_entitlement(subject, body(event))
        if route == "DELETE /v1/guardian/relationships/{id}":
            return revoke_relationship(subject, _path_id(event))
        if route == "POST /v1/guardian/incidents/{id}/acknowledge":
            return acknowledge_incident(subject, _path_id(event))
        if route == "POST /v1/guardian/incidents/{id}/opened":
            return mark_incident_opened(subject, _path_id(event))
        if route == "DELETE /v1/guardian/account":
            return delete_account(subject)
        raise APIError(404, "NOT_FOUND")
    except Exception as error:
        return error_response(error)


def _ensure_account(subject: str) -> None:
    existing = get(account_pk(subject), "PROFILE")
    if existing and existing.get("account_status") == "deleting":
        raise APIError(410, "ACCOUNT_DELETION_PENDING")
    now = iso(now_utc())
    TABLE.update_item(
        Key={"PK": account_pk(subject), "SK": "PROFILE"},
        UpdateExpression="SET entity_type = if_not_exists(entity_type, :type), created_at = if_not_exists(created_at, :now), updated_at = :now",
        ExpressionAttributeValues={":type": "ACCOUNT", ":now": now},
    )


def _path_id(event: dict[str, Any]) -> str:
    return require_identifier(event.get("pathParameters", {}).get("id"))


def _entitlement(subject: str) -> dict[str, Any] | None:
    item = get(account_pk(subject), "ENTITLEMENT")
    if not item or item.get("product_id") != os.environ["FAMILY_PRODUCT_ID"]:
        return None
    expires = parse_iso(item.get("expires_at"))
    if item.get("active") is not True or expires is None or expires <= now_utc():
        return None
    return item


def _require_family(subject: str) -> dict[str, Any]:
    value = _entitlement(subject)
    if not value:
        raise APIError(403, "FAMILY_REQUIRED")
    return value


def _owner_relationships(subject: str, *, include_revoked: bool = False) -> list[dict[str, Any]]:
    values = query_partition(account_pk(subject), "REL#", limit=20)
    return values if include_revoked else [value for value in values if value.get("status") == "accepted"]


def _guardian_relationships(subject: str, *, include_revoked: bool = False) -> list[dict[str, Any]]:
    values = query_partition(account_pk(subject), "GUARDING#", limit=20)
    return values if include_revoked else [value for value in values if value.get("status") == "accepted"]


def _policy_dto(policy: dict[str, Any] | None, subject: str) -> dict[str, Any] | None:
    if not policy:
        return None
    relationships = _owner_relationships(subject)
    reachable = [item for item in relationships if item.get("reachability") == "active"]
    return {
        "id": policy.get("policy_id", ""),
        "is_enabled": bool(policy.get("is_enabled")),
        "status": policy.get("status", "inactive"),
        "weekdays": [int(value) for value in policy.get("weekdays", [])],
        "deadline_hour": int(policy.get("deadline_hour", 20)),
        "deadline_minute": int(policy.get("deadline_minute", 0)),
        "grace_period_minutes": int(policy.get("grace_period_minutes", 60)),
        "pause_until": policy.get("pause_until"),
        "time_zone_identifier": policy.get("time_zone_identifier", "UTC"),
        "schedule_revision": int(policy.get("schedule_revision", 1)),
        "accepted_guardian_count": len(relationships),
        "reachable_guardian_count": len(reachable),
        "updated_at": policy.get("updated_at", iso(now_utc())),
    }


def _relationship_dto(value: dict[str, Any], *, guardian: bool) -> dict[str, Any]:
    protected_policy = get(account_pk(value.get("owner_sub")), "POLICY") if guardian and value.get("owner_sub") else None
    return {
        "id": value["relationship_id"],
        "display_label": "Protected person" if guardian else value.get("display_label", "Guardian"),
        "status": value.get("status", "revoked"),
        "reachability": value.get("reachability", "unknown"),
        "current_user_is_guardian": guardian,
        "accepted_at": value.get("accepted_at"),
        "revoked_at": value.get("revoked_at"),
        "last_opened_at": value.get("last_opened_at"),
        "last_acknowledged_at": value.get("last_acknowledged_at"),
        "latest_notification_state": value.get("latest_notification_state"),
        "latest_notification_updated_at": value.get("latest_notification_updated_at"),
        "protected_policy_status": protected_policy.get("status") if protected_policy else None,
        "protected_pause_until": protected_policy.get("pause_until") if protected_policy else None,
        "updated_at": value.get("updated_at", iso(now_utc())),
    }


def _incident_dto(value: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": value["incident_id"],
        "policy_id": value.get("policy_id", ""),
        "status": value.get("status", "closed"),
        "last_guard_day_key": value.get("last_guard_day_key", ""),
        "consecutive_misses": int(value.get("consecutive_misses", 0)),
        "initial_submitted_at": value.get("initial_submitted_at"),
        "follow_up_submitted_at": value.get("follow_up_submitted_at"),
        "acknowledged_at": value.get("acknowledged_at"),
        "recovered_at": value.get("recovered_at"),
        "created_at": value.get("created_at", iso(now_utc())),
        "updated_at": value.get("updated_at", iso(now_utc())),
    }


def dashboard(subject: str) -> dict[str, Any]:
    owned_policy = get(account_pk(subject), "POLICY")
    owned_relationships = _owner_relationships(subject, include_revoked=True)
    guardian_relationships = _guardian_relationships(subject, include_revoked=True)
    incidents = query_partition(account_pk(subject), "INCIDENT#", limit=20)
    for relationship in guardian_relationships:
        owner = relationship.get("owner_sub")
        if relationship.get("status") == "accepted" and owner:
            incidents.extend(query_partition(account_pk(owner), "INCIDENT#", limit=10))
    unique_incidents = {value["incident_id"]: value for value in incidents}
    return {
        "policy": _policy_dto(owned_policy, subject),
        "relationships": [
            *[_relationship_dto(value, guardian=False) for value in owned_relationships],
            *[_relationship_dto(value, guardian=True) for value in guardian_relationships],
        ],
        "incidents": [_incident_dto(value) for value in unique_incidents.values()],
        "server_time": iso(now_utc()),
    }


def create_invitation(subject: str) -> dict[str, Any]:
    _require_family(subject)
    if len(_owner_relationships(subject)) >= 3:
        raise APIError(409, "GUARDIAN_LIMIT_REACHED")
    now = now_utc()
    expires = now + timedelta(hours=48)
    for _ in range(5):
        code = base64.b32encode(secrets.token_bytes(10)).decode("ascii").rstrip("=")
        try:
            TABLE.put_item(
                Item={
                    "PK": invite_pk(code),
                    "SK": "INVITATION",
                    "entity_type": "INVITATION",
                    "owner_sub": subject,
                    "status": "invited",
                    "created_at": iso(now),
                    "expires_at": iso(expires),
                    "expires_at_epoch": int(expires.timestamp()),
                },
                ConditionExpression="attribute_not_exists(PK)",
            )
            return response(201, {
                "code": code,
                "url": f"{environment('PUBLIC_INVITE_BASE_URL').rstrip('/')}/g/{code}",
                "expires_at": iso(expires),
            })
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
    raise APIError(503, "INVITATION_UNAVAILABLE")


def _serialize(value: Any) -> dict[str, Any]:
    return SERIALIZER.serialize(value)


def _serialized_item(value: dict[str, Any]) -> dict[str, Any]:
    return {key: _serialize(item) for key, item in value.items()}


def accept_invitation(guardian_sub: str, payload: dict[str, Any]) -> dict[str, Any]:
    raw_code = payload.get("code")
    code = raw_code.strip().upper() if isinstance(raw_code, str) else ""
    if not INVITATION_CODE.fullmatch(code):
        raise APIError(400, "INVALID_INVITATION")
    invitation = get(invite_pk(code), "INVITATION")
    expires = parse_iso(invitation.get("expires_at")) if invitation else None
    if not invitation or expires is None or expires <= now_utc() or invitation.get("status") != "invited":
        raise APIError(410, "INVITATION_EXPIRED")
    owner_sub = invitation.get("owner_sub")
    if not isinstance(owner_sub, str) or owner_sub == guardian_sub:
        raise APIError(409, "INVALID_GUARDIAN")
    _require_family(owner_sub)

    now = now_utc()
    now_string = iso(now)
    relationship_id = secrets.token_hex(16)
    has_reachable_device = any(
        device.get("reachability") == "active"
        for device in query_partition(account_pk(guardian_sub), "DEVICE#", limit=20)
    )
    reachability = "active" if has_reachable_device else "notificationsDisabled"
    owner_item = {
        "PK": account_pk(owner_sub),
        "SK": f"REL#{relationship_id}",
        "entity_type": "RELATIONSHIP",
        "relationship_id": relationship_id,
        "owner_sub": owner_sub,
        "guardian_sub": guardian_sub,
        "display_label": f"Guardian {len(_owner_relationships(owner_sub)) + 1}",
        "status": "accepted",
        "reachability": reachability,
        "accepted_at": now_string,
        "created_at": now_string,
        "updated_at": now_string,
    }
    guardian_item = {
        **owner_item,
        "PK": account_pk(guardian_sub),
        "SK": f"GUARDING#{relationship_id}",
        "display_label": "Protected person",
    }
    try:
        DDB.transact_write_items(TransactItems=[
            {"Update": {
                "TableName": os.environ["TABLE_NAME"],
                "Key": _serialized_item({"PK": invite_pk(code), "SK": "INVITATION"}),
                "UpdateExpression": "SET #status = :accepted, accepted_at = :now, accepted_by = :guardian",
                "ConditionExpression": "#status = :invited AND expires_at_epoch > :epoch",
                "ExpressionAttributeNames": {"#status": "status"},
                "ExpressionAttributeValues": _serialized_item({
                    ":accepted": "accepted", ":invited": "invited", ":now": now_string,
                    ":guardian": guardian_sub, ":epoch": int(now.timestamp()),
                }),
            }},
            {"Update": {
                "TableName": os.environ["TABLE_NAME"],
                "Key": _serialized_item({"PK": account_pk(owner_sub), "SK": "COUNTERS"}),
                "UpdateExpression": "SET guardian_count = if_not_exists(guardian_count, :zero) + :one",
                "ConditionExpression": "attribute_not_exists(guardian_count) OR guardian_count < :max",
                "ExpressionAttributeValues": _serialized_item({":zero": 0, ":one": 1, ":max": 3}),
            }},
            {"Put": {"TableName": os.environ["TABLE_NAME"], "Item": _serialized_item(owner_item)}},
            {"Put": {"TableName": os.environ["TABLE_NAME"], "Item": _serialized_item(guardian_item)}},
        ])
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "TransactionCanceledException":
            raise APIError(409, "INVITATION_ALREADY_USED_OR_LIMIT_REACHED") from error
        raise
    return response(200, dashboard(guardian_sub))


def _validate_policy(payload: dict[str, Any], existing: dict[str, Any] | None) -> dict[str, Any]:
    weekdays = payload.get("weekdays")
    if not isinstance(weekdays, list) or not weekdays:
        raise APIError(400, "INVALID_WEEKDAYS")
    try:
        normalized_weekdays = sorted({int(value) for value in weekdays})
        if any(value < 1 or value > 7 for value in normalized_weekdays):
            raise ValueError
        hour = int(payload.get("deadline_hour"))
        minute = int(payload.get("deadline_minute"))
        grace = int(payload.get("grace_period_minutes"))
        revision = int(payload.get("schedule_revision"))
    except (TypeError, ValueError) as exc:
        raise APIError(400, "INVALID_SCHEDULE") from exc
    if not 0 <= hour <= 23 or not 0 <= minute <= 59 or not 15 <= grace <= 180:
        raise APIError(400, "INVALID_SCHEDULE")
    if existing and revision <= int(existing.get("schedule_revision", 0)):
        raise APIError(409, "STALE_SCHEDULE_REVISION")
    zone_name = payload.get("time_zone_identifier")
    try:
        ZoneInfo(zone_name)
    except (TypeError, ZoneInfoNotFoundError) as exc:
        raise APIError(400, "INVALID_TIME_ZONE") from exc
    pause = parse_iso(payload.get("pause_until"))
    if pause and pause > now_utc() + timedelta(days=MAXIMUM_PAUSE_DAYS, minutes=1):
        raise APIError(400, "PAUSE_TOO_LONG")
    return {
        "is_enabled": payload.get("is_enabled") is True,
        "weekdays": normalized_weekdays,
        "deadline_hour": hour,
        "deadline_minute": minute,
        "grace_period_minutes": grace,
        "schedule_revision": revision,
        "time_zone_identifier": zone_name,
        "pause_until": iso(pause) if pause else None,
    }


def update_policy(subject: str, payload: dict[str, Any]) -> dict[str, Any]:
    _require_family(subject)
    existing = get(account_pk(subject), "POLICY")
    schedule = _validate_policy(payload, existing)
    relationships = _owner_relationships(subject)
    reachable = [value for value in relationships if value.get("reachability") == "active"]
    if schedule["is_enabled"] and not reachable:
        raise APIError(409, "REACHABLE_GUARDIAN_REQUIRED")
    now = now_utc()
    policy_id = existing.get("policy_id") if existing else secrets.token_hex(16)
    status = "paused" if schedule["pause_until"] and parse_iso(schedule["pause_until"]) > now else (
        "monitoring" if schedule["is_enabled"] else "stopped"
    )
    next_due = None
    if schedule["is_enabled"]:
        next_due = next_evaluation_time(
            now,
            time_zone_identifier=schedule["time_zone_identifier"],
            weekdays=schedule["weekdays"],
            deadline_hour=schedule["deadline_hour"],
            deadline_minute=schedule["deadline_minute"],
            grace_period_minutes=schedule["grace_period_minutes"],
            pause_until=parse_iso(schedule["pause_until"]),
        )
    item = {
        "PK": account_pk(subject),
        "SK": "POLICY",
        "entity_type": "POLICY",
        "policy_id": policy_id,
        **schedule,
        "status": status,
        "mode_active": schedule["is_enabled"],
        "owner_active": schedule["is_enabled"],
        # A schedule revision is a new monitoring contract. It never carries a
        # partially observed incident into a changed weekday/deadline/pause.
        "consecutive_misses": 0,
        "created_at": (existing or {}).get("created_at", iso(now)),
        "updated_at": iso(now),
    }
    if next_due:
        item["GSI1PK"] = "POLICY#ENABLED"
        item["GSI1SK"] = iso(next_due)
        item["next_evaluation_at"] = iso(next_due)
    TABLE.put_item(Item={key: value for key, value in item.items() if value is not None})
    _close_open_incidents(subject, "closed", now)
    return response(200, dashboard(subject))


def upload_signals(subject: str, payload: dict[str, Any]) -> dict[str, Any]:
    signals = payload.get("signals")
    if not isinstance(signals, list) or len(signals) > 50:
        raise APIError(400, "INVALID_SIGNALS")
    accepted: list[str] = []
    rejected: dict[str, str] = {}
    for signal in signals:
        try:
            event_key = require_identifier(signal.get("event_key"), "INVALID_EVENT_KEY")
            kind = signal.get("kind")
            if kind not in {"ownerCheckIn", "ownerUndo", "monitoringStopped", "policyChanged", "deviceEndpointChanged"}:
                raise APIError(400, "INVALID_SIGNAL_KIND")
            day_key = signal.get("day_key")
            occurred_at = parse_iso(signal.get("occurred_at"))
            time_zone_identifier = signal.get("time_zone_identifier")
            if occurred_at is None or not isinstance(time_zone_identifier, str):
                raise APIError(400, "INVALID_SIGNAL")
            now = now_utc()
            event_item = {
                "PK": account_pk(subject),
                "SK": f"SIGNAL#{event_key}",
                "entity_type": "SIGNAL",
                "event_key": event_key,
                "kind": kind,
                "day_key": day_key,
                "occurred_at": iso(occurred_at),
                "time_zone_identifier": time_zone_identifier,
                "stop_reason": signal.get("stop_reason"),
                "created_at": iso(now),
                "expires_at_epoch": int((now + timedelta(days=35)).timestamp()),
            }
            stored_signal = event_item
            try:
                TABLE.put_item(Item=event_item, ConditionExpression="attribute_not_exists(PK)")
            except ClientError as error:
                if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                    raise
                stored_signal = get(account_pk(subject), f"SIGNAL#{event_key}") or event_item
            if stored_signal.get("apply_state") != "applied":
                _apply_signal(subject, stored_signal)
                TABLE.update_item(
                    Key={"PK": account_pk(subject), "SK": f"SIGNAL#{event_key}"},
                    UpdateExpression="SET apply_state=:applied, applied_at=:now",
                    ExpressionAttributeValues={":applied": "applied", ":now": iso(now_utc())},
                )
            accepted.append(event_key)
        except APIError as error:
            key = signal.get("event_key") if isinstance(signal, dict) else "invalid"
            rejected[str(key)[:160]] = error.code
    return response(200, {"accepted_event_keys": accepted, "rejected_event_keys": rejected})


def _apply_signal(subject: str, signal: dict[str, Any]) -> None:
    kind = signal["kind"]
    day_key = signal.get("day_key")
    now = now_utc()
    if kind in {"ownerCheckIn", "ownerUndo"} and isinstance(day_key, str):
        checked_in = kind == "ownerCheckIn"
        TABLE.update_item(
            Key={"PK": account_pk(subject), "SK": f"GUARDDAY#{day_key}"},
            UpdateExpression="SET entity_type=:type, day_key=:day, checked_in=:checked, updated_at=:now, expires_at_epoch=:ttl",
            ExpressionAttributeValues={
                ":type": "GUARD_DAY", ":day": day_key, ":checked": checked_in,
                ":now": iso(now), ":ttl": int((now + timedelta(days=35)).timestamp()),
            },
        )
        if checked_in:
            _recover_if_needed(subject, now)
    elif kind == "monitoringStopped":
        policy = get(account_pk(subject), "POLICY")
        if policy:
            policy.update({
                "is_enabled": False,
                "status": "stopped",
                "mode_active": False,
                "owner_active": False,
                "consecutive_misses": 0,
                "updated_at": iso(now),
            })
            for key in (
                "GSI1PK", "GSI1SK", "next_evaluation_at", "active_incident_id",
                "initial_queued", "follow_up_queued",
            ):
                policy.pop(key, None)
            TABLE.put_item(Item=policy)
        _close_open_incidents(subject, "closed", now)


def _recover_if_needed(subject: str, now) -> None:
    incidents = query_partition(account_pk(subject), "INCIDENT#", limit=20)
    for incident in incidents:
        attempts = query_partition(f"INCIDENT#{incident['incident_id']}", "ATTEMPT#", limit=100)
        resolution = check_in_resolution(
            str(incident.get("status") or ""),
            has_submitted_attempt=any(
                item.get("state") in {"submitted", "opened", "acknowledged"}
                for item in attempts
            ),
        )
        if resolution == "none":
            continue
        incident["status"] = resolution
        if resolution == "recovered":
            incident["recovered_at"] = iso(now)
        incident["updated_at"] = iso(now)
        TABLE.put_item(Item=incident)
        if resolution == "recovered":
            _queue_for_guardians(subject, incident["incident_id"], "recovery")
    policy = get(account_pk(subject), "POLICY")
    if policy:
        policy["consecutive_misses"] = 0
        for key in ("active_incident_id", "initial_queued", "follow_up_queued"):
            policy.pop(key, None)
        policy["updated_at"] = iso(now)
        TABLE.put_item(Item=policy)


def _close_open_incidents(subject: str, status: str, now) -> None:
    for incident in query_partition(account_pk(subject), "INCIDENT#", limit=20):
        if incident.get("status") in OPEN_INCIDENT_STATUSES:
            incident["status"] = status
            incident["updated_at"] = iso(now)
            TABLE.put_item(Item=incident)


def _queue_for_guardians(owner_sub: str, incident_id: str, kind: str) -> None:
    incident = get(account_pk(owner_sub), f"INCIDENT#{incident_id}")
    if not incident:
        return
    # Local import avoids coupling the HTTP module to Lambda entrypoint state.
    from evaluator import _create_delivery_outbox

    _create_delivery_outbox(
        owner_sub,
        incident,
        kind,
        now_utc(),
        submitted_only=kind == "recovery",
    )


def register_device(subject: str, payload: dict[str, Any]) -> dict[str, Any]:
    ensure_endpoint(subject, payload)
    devices = query_partition(account_pk(subject), "DEVICE#", limit=20)
    has_reachable_device = any(
        device.get("notifications_authorized") is True
        and device.get("reachability") == "active"
        for device in devices
    )
    _set_guardian_reachability(
        subject,
        "active" if has_reachable_device else "notificationsDisabled",
    )
    return response(204)


def _set_guardian_reachability(guardian_sub: str, reachability: str) -> None:
    now = iso(now_utc())
    for guardian_row in _guardian_relationships(guardian_sub, include_revoked=False):
        guardian_row["reachability"] = reachability
        guardian_row["updated_at"] = now
        TABLE.put_item(Item=guardian_row)
        owner_sub = guardian_row.get("owner_sub")
        relationship_id = guardian_row.get("relationship_id")
        owner_row = get(account_pk(owner_sub), f"REL#{relationship_id}") if owner_sub else None
        if owner_row:
            owner_row["reachability"] = reachability
            owner_row["updated_at"] = now
            TABLE.put_item(Item=owner_row)


def verify_entitlement(subject: str, payload: dict[str, Any]) -> dict[str, Any]:
    transaction = verify_family_transaction(payload.get("signed_transaction_info"))
    _bind_entitlement(subject, transaction)
    return response(200, dashboard(subject))


def _bind_entitlement(subject: str, transaction) -> None:
    now = now_utc()
    binding = {
        "PK": transaction_pk(transaction.original_transaction_id),
        "SK": "OWNER",
        "entity_type": "TRANSACTION_BINDING",
        "owner_sub": subject,
        "original_transaction_id": transaction.original_transaction_id,
        "updated_at": iso(now),
    }
    entitlement = {
        "PK": account_pk(subject),
        "SK": "ENTITLEMENT",
        "entity_type": "ENTITLEMENT",
        "product_id": os.environ["FAMILY_PRODUCT_ID"],
        "original_transaction_id": transaction.original_transaction_id,
        "transaction_id": transaction.transaction_id,
        "environment": transaction.environment,
        "active": transaction.active,
        "expires_at": iso(transaction.expires_at),
        "updated_at": iso(now),
    }
    try:
        DDB.transact_write_items(TransactItems=[
            {"Put": {
                "TableName": os.environ["TABLE_NAME"],
                "Item": _serialized_item(binding),
                "ConditionExpression": "attribute_not_exists(PK) OR owner_sub = :owner",
                "ExpressionAttributeValues": _serialized_item({":owner": subject}),
            }},
            {"Put": {"TableName": os.environ["TABLE_NAME"], "Item": _serialized_item(entitlement)}},
        ])
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "TransactionCanceledException":
            raise APIError(409, "TRANSACTION_ALREADY_BOUND") from error
        raise
    if not transaction.active:
        _stop_for_entitlement_loss(subject, now)


def _stop_for_entitlement_loss(subject: str, now) -> None:
    policy = get(account_pk(subject), "POLICY")
    if policy:
        policy.update({"is_enabled": False, "status": "stopped", "updated_at": iso(now), "consecutive_misses": 0})
        for key in (
            "GSI1PK", "GSI1SK", "next_evaluation_at", "active_incident_id",
            "initial_queued", "follow_up_queued",
        ):
            policy.pop(key, None)
        TABLE.put_item(Item=policy)
    _close_open_incidents(subject, "closed", now)


def _resolve_relationship(actor_sub: str, relationship_id: str) -> tuple[str, dict[str, Any], dict[str, Any]]:
    owner_row = get(account_pk(actor_sub), f"REL#{relationship_id}")
    if owner_row:
        guardian_sub = owner_row.get("guardian_sub")
        guardian_row = get(account_pk(guardian_sub), f"GUARDING#{relationship_id}") if guardian_sub else None
        if guardian_row:
            return actor_sub, owner_row, guardian_row
    guardian_row = get(account_pk(actor_sub), f"GUARDING#{relationship_id}")
    if guardian_row:
        owner_sub = guardian_row.get("owner_sub")
        owner_row = get(account_pk(owner_sub), f"REL#{relationship_id}") if owner_sub else None
        if owner_row:
            return owner_sub, owner_row, guardian_row
    raise APIError(404, "RELATIONSHIP_NOT_FOUND")


def revoke_relationship(actor_sub: str, relationship_id: str) -> dict[str, Any]:
    owner_sub, owner_row, guardian_row = _resolve_relationship(actor_sub, relationship_id)
    if owner_row.get("status") == "revoked" and guardian_row.get("status") == "revoked":
        return response(200, dashboard(actor_sub))
    now = now_utc()
    for row in (owner_row, guardian_row):
        row["status"] = "revoked"
        row["reachability"] = "revoked"
        row["revoked_at"] = iso(now)
        row["updated_at"] = iso(now)
        row["expires_at_epoch"] = int((now + timedelta(days=90)).timestamp())
    revocation_marker = {
        "PK": f"RELATIONSHIP#{relationship_id}",
        "SK": "REVOCATION",
        "entity_type": "RELATIONSHIP_REVOCATION",
        "relationship_id": relationship_id,
        "revoked_at": iso(now),
        "expires_at_epoch": int((now + timedelta(days=90)).timestamp()),
    }
    try:
        # The marker makes owner/guardian concurrent revocation idempotent and
        # guarantees that the accepted-guardian counter decrements exactly once.
        DDB.transact_write_items(TransactItems=[
            {"Put": {
                "TableName": os.environ["TABLE_NAME"],
                "Item": _serialized_item(revocation_marker),
                "ConditionExpression": "attribute_not_exists(PK)",
            }},
            {"Put": {
                "TableName": os.environ["TABLE_NAME"],
                "Item": _serialized_item(owner_row),
            }},
            {"Put": {
                "TableName": os.environ["TABLE_NAME"],
                "Item": _serialized_item(guardian_row),
            }},
            {"Update": {
                "TableName": os.environ["TABLE_NAME"],
                "Key": _serialized_item({"PK": account_pk(owner_sub), "SK": "COUNTERS"}),
                "UpdateExpression": "SET guardian_count = guardian_count - :one",
                "ConditionExpression": "guardian_count > :zero",
                "ExpressionAttributeValues": _serialized_item({":one": 1, ":zero": 0}),
            }},
        ])
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") != "TransactionCanceledException":
            raise
        marker = get(f"RELATIONSHIP#{relationship_id}", "REVOCATION")
        if not marker:
            raise APIError(409, "RELATIONSHIP_REVOCATION_CONFLICT") from error
        # Another authorized actor completed the same atomic revocation.
        return response(200, dashboard(actor_sub))
    if not _owner_relationships(owner_sub):
        _stop_for_entitlement_loss(owner_sub, now)
    return response(200, dashboard(actor_sub))


def _guardian_incident_access(guardian_sub: str, incident_id: str) -> tuple[str, dict[str, Any], dict[str, Any]]:
    for relationship in _guardian_relationships(guardian_sub):
        owner_sub = relationship.get("owner_sub")
        incident = get(account_pk(owner_sub), f"INCIDENT#{incident_id}") if owner_sub else None
        if incident:
            return owner_sub, relationship, incident
    raise APIError(404, "INCIDENT_NOT_FOUND")


def acknowledge_incident(guardian_sub: str, incident_id: str) -> dict[str, Any]:
    owner_sub, guardian_row, incident = _guardian_incident_access(guardian_sub, incident_id)
    now = now_utc()
    incident.update({"status": "acknowledged", "acknowledged_at": iso(now), "updated_at": iso(now)})
    TABLE.put_item(Item=incident)
    guardian_row.update({
        "last_acknowledged_at": iso(now),
        "latest_notification_state": "acknowledged",
        "latest_notification_updated_at": iso(now),
        "updated_at": iso(now),
    })
    TABLE.put_item(Item=guardian_row)
    owner_row = get(account_pk(owner_sub), f"REL#{guardian_row['relationship_id']}")
    if owner_row:
        owner_row.update({
            "last_acknowledged_at": iso(now),
            "latest_notification_state": "acknowledged",
            "latest_notification_updated_at": iso(now),
            "updated_at": iso(now),
        })
        TABLE.put_item(Item=owner_row)
    for attempt in query_partition(f"INCIDENT#{incident_id}", "ATTEMPT#", limit=100):
        if attempt.get("relationship_id") == guardian_row["relationship_id"] and attempt.get("state") in {"submitted", "opened"}:
            attempt.update({"state": "acknowledged", "acknowledged_at": iso(now), "updated_at": iso(now)})
            TABLE.put_item(Item=attempt)
    policy = get(account_pk(owner_sub), "POLICY")
    if policy:
        policy["consecutive_misses"] = 0
        for key in ("active_incident_id", "initial_queued", "follow_up_queued"):
            policy.pop(key, None)
        policy["updated_at"] = iso(now)
        TABLE.put_item(Item=policy)
    return response(200, dashboard(guardian_sub))


def mark_incident_opened(guardian_sub: str, incident_id: str) -> dict[str, Any]:
    owner_sub, guardian_row, _incident = _guardian_incident_access(guardian_sub, incident_id)
    attempts = [
        attempt
        for attempt in query_partition(f"INCIDENT#{incident_id}", "ATTEMPT#", limit=100)
        if attempt.get("relationship_id") == guardian_row["relationship_id"]
        and attempt.get("state") in {"submitted", "opened", "acknowledged"}
    ]
    if not attempts:
        raise APIError(409, "NOTIFICATION_NOT_SUBMITTED")
    if any(attempt.get("state") == "acknowledged" for attempt in attempts):
        return response(200, dashboard(guardian_sub))
    now = iso(now_utc())
    guardian_row.update({
        "last_opened_at": now,
        "latest_notification_state": "opened",
        "latest_notification_updated_at": now,
        "updated_at": now,
    })
    TABLE.put_item(Item=guardian_row)
    owner_row = get(account_pk(owner_sub), f"REL#{guardian_row['relationship_id']}")
    if owner_row:
        owner_row.update({
            "last_opened_at": now,
            "latest_notification_state": "opened",
            "latest_notification_updated_at": now,
            "updated_at": now,
        })
        TABLE.put_item(Item=owner_row)
    for attempt in attempts:
        if attempt.get("state") == "submitted":
            attempt.update({"state": "opened", "opened_at": now, "updated_at": now})
            TABLE.put_item(Item=attempt)
    return response(200, dashboard(guardian_sub))


def delete_account(subject: str) -> dict[str, Any]:
    now = now_utc()
    _stop_for_entitlement_loss(subject, now)
    remove_devices(subject)
    for relationship in [*_owner_relationships(subject), *_guardian_relationships(subject)]:
        try:
            revoke_relationship(subject, relationship["relationship_id"])
        except APIError:
            continue
    purge_at = now + timedelta(days=30)
    TABLE.put_item(Item={
        "PK": account_pk(subject),
        "SK": "DELETE_REQUEST",
        "entity_type": "DELETE_REQUEST",
        "requested_at": iso(now),
        "purge_at": iso(purge_at),
        "GSI1PK": "RETENTION#DUE",
        "GSI1SK": iso(purge_at),
        "expires_at_epoch": int((purge_at + timedelta(days=1)).timestamp()),
    })
    TABLE.update_item(
        Key={"PK": account_pk(subject), "SK": "PROFILE"},
        UpdateExpression="SET account_status=:status, updated_at=:now",
        ExpressionAttributeValues={":status": "deleting", ":now": iso(now)},
    )
    return response(204)


def app_store_notification(event: dict[str, Any]) -> dict[str, Any]:
    token = event.get("pathParameters", {}).get("token")
    if not secrets.compare_digest(str(token), os.environ["APPLE_NOTIFICATION_AUDIENCE_TOKEN"]):
        raise APIError(404, "NOT_FOUND")
    payload = body(event, maximum_bytes=196_608)
    _decoded, transaction = verify_notification(payload.get("signedPayload"))
    if not transaction:
        return response(204)
    binding = get(transaction_pk(transaction.original_transaction_id), "OWNER")
    owner_sub = binding.get("owner_sub") if binding else None
    if owner_sub:
        _bind_entitlement(owner_sub, transaction)
    return response(204)


def association_file() -> dict[str, Any]:
    app_id = f"{os.environ.get('APPLE_TEAM_ID', '')}.{os.environ['APPLE_BUNDLE_ID']}"
    return response(200, {
        "applinks": {
            "apps": [],
            "details": [{"appIDs": [app_id], "components": [{"/": "/g/*"}]}],
        }
    })


def invitation_landing(event: dict[str, Any]) -> dict[str, Any]:
    raw = event.get("pathParameters", {}).get("code")
    code = raw.strip().upper() if isinstance(raw, str) else ""
    invitation = get(invite_pk(code), "INVITATION") if INVITATION_CODE.fullmatch(code) else None
    expires = parse_iso(invitation.get("expires_at")) if invitation else None
    usable = bool(invitation and invitation.get("status") == "invited" and expires and expires > now_utc())
    if not usable:
        title = "This guardian invitation is no longer available."
        action = f'<a href="{html.escape(environment("APP_STORE_URL"))}">Open Ohana on the App Store</a>'
    else:
        title = "Open Ohana to review this guardian invitation."
        deep_link = f"ohana://guardian?invite={quote(code)}"
        action = f'<a href="{html.escape(deep_link)}">Open in Ohana</a><a href="{html.escape(environment("APP_STORE_URL"))}">Get Ohana</a>'
    page = f"""<!doctype html><html lang=en><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><title>Ohana Guardian</title><style>body{{font:17px -apple-system,sans-serif;max-width:36rem;margin:12vh auto;padding:24px;background:#f7f7f5;color:#171717}}main{{background:white;border-radius:24px;padding:28px}}a{{display:block;margin-top:14px;padding:14px;border-radius:14px;background:#202124;color:white;text-align:center;text-decoration:none}}</style><main><h1>Ohana Guardian</h1><p>{html.escape(title)}</p><p>Acceptance can only be completed after signing in inside the Ohana app.</p>{action}</main></html>"""
    return response(200, page, content_type="text/html; charset=utf-8")

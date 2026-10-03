"""Rechecking, idempotent SNS/APNs push submission worker."""

from __future__ import annotations

import hashlib
import json
import os
from datetime import timedelta
from typing import Any

import boto3
from botocore.exceptions import ClientError

from common import iso, now_utc, parse_iso
from rules import follow_up_may_submit
from storage import TABLE, account_pk, get, query_partition

SNS = boto3.client("sns")

COPY = {
    "zh": {
        "initial": "尚未收到今天的平安确认，请主动联系确认",
        "follow_up": "连续 2 个守护日尚未收到平安确认，请再次主动联系确认",
        "recovery": "已收到平安确认",
    },
    "en": {
        "initial": "Ohana has not received today's safety confirmation. Please contact them to confirm.",
        "follow_up": "Ohana has not received a safety confirmation for 2 guard days. Please contact them again.",
        "recovery": "Ohana has received a safety confirmation.",
    },
    "de": {
        "initial": "Ohana hat die heutige Sicherheitsbestätigung noch nicht erhalten. Bitte nimm Kontakt auf.",
        "follow_up": "Ohana hat an 2 Schutztagen keine Sicherheitsbestätigung erhalten. Bitte frage erneut nach.",
        "recovery": "Ohana hat eine Sicherheitsbestätigung erhalten.",
    },
    "es": {
        "initial": "Ohana aún no ha recibido la confirmación de bienestar de hoy. Contacta para confirmar.",
        "follow_up": "Ohana aún no ha recibido una confirmación de bienestar tras 2 días de seguimiento. Vuelve a contactar.",
        "recovery": "Ohana ha recibido una confirmación de bienestar.",
    },
    "pt": {
        "initial": "Ohana ainda não recebeu a confirmação de bem-estar de hoje. Entre em contato para confirmar.",
        "follow_up": "Ohana ainda não recebeu uma confirmação de bem-estar após 2 dias de proteção. Entre em contato novamente.",
        "recovery": "Ohana recebeu uma confirmação de bem-estar.",
    },
    "fr": {
        "initial": "Ohana n’a pas encore reçu la confirmation que tout va bien aujourd’hui. Prenez contact pour vérifier.",
        "follow_up": "Ohana n’a toujours pas reçu de confirmation après 2 jours de veille. Reprenez contact.",
        "recovery": "Ohana a reçu une confirmation que tout va bien.",
    },
    "ja": {
        "initial": "今日の安全確認をまだ受信していません。本人へ連絡して確認してください。",
        "follow_up": "2回の見守り日も安全確認を受信していません。もう一度連絡してください。",
        "recovery": "安全確認を受信しました。",
    },
    "ko": {
        "initial": "오늘의 안전 확인을 아직 받지 못했습니다. 직접 연락해 확인해 주세요.",
        "follow_up": "2번의 보호일 동안 안전 확인을 받지 못했습니다. 다시 연락해 주세요.",
        "recovery": "안전 확인을 받았습니다.",
    },
    "it": {
        "initial": "Ohana non ha ancora ricevuto la conferma di sicurezza di oggi. Contatta la persona per verificare.",
        "follow_up": "Ohana non ha ancora ricevuto una conferma di sicurezza dopo 2 giorni di tutela. Contattala di nuovo.",
        "recovery": "Ohana ha ricevuto una conferma di sicurezza.",
    },
}


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    failures = []
    for record in event.get("Records", []):
        try:
            payload = json.loads(record["body"])
            _process(payload)
        except Exception:
            # Never log the message: it contains pseudonymous account IDs.
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}


def _active_entitlement(subject: str, now) -> bool:
    value = get(account_pk(subject), "ENTITLEMENT")
    expires = parse_iso(value.get("expires_at")) if value else None
    return bool(
        value
        and value.get("product_id") == os.environ["FAMILY_PRODUCT_ID"]
        and value.get("active") is True
        and expires
        and expires > now
    )


def _process(payload: dict[str, Any]) -> None:
    delivery_key = payload["delivery_key"]
    delivery = get("DELIVERY", f"PENDING#{delivery_key}")
    if not delivery or delivery.get("state") == "submitted":
        return
    owner_sub = payload["owner_sub"]
    guardian_sub = payload["guardian_sub"]
    relationship_id = payload["relationship_id"]
    incident_id = payload["incident_id"]
    kind = payload["kind"]
    now = now_utc()
    relationship = get(account_pk(owner_sub), f"REL#{relationship_id}")
    guardian_row = get(account_pk(guardian_sub), f"GUARDING#{relationship_id}")
    incident = get(account_pk(owner_sub), f"INCIDENT#{incident_id}")
    if not relationship or not guardian_row or not incident:
        _cancel_delivery(delivery, now)
        return
    if relationship.get("status") != "accepted" or guardian_row.get("status") != "accepted":
        _cancel_delivery(delivery, now)
        return
    # Every push kind, including recovery, revalidates the owner's Family
    # entitlement immediately before provider submission.
    if not _active_entitlement(owner_sub, now):
        _cancel_delivery(delivery, now)
        return
    if kind in {"initial", "follow_up"}:
        policy = get(account_pk(owner_sub), "POLICY")
        pause_until = parse_iso(policy.get("pause_until")) if policy else None
        guard_day = get(
            account_pk(owner_sub),
            f"GUARDDAY#{incident.get('last_guard_day_key', '')}",
        )
        if (
            not policy
            or not policy.get("is_enabled")
            or policy.get("mode_active") is not True
            or policy.get("owner_active") is not True
            or (pause_until is not None and pause_until > now)
            or bool(guard_day and guard_day.get("checked_in"))
            or incident.get("status") in {"acknowledged", "recovered", "closed"}
        ):
            _cancel_delivery(delivery, now)
            return
    elif kind == "recovery":
        if incident.get("status") != "recovered":
            _cancel_delivery(delivery, now)
            return
    else:
        _cancel_delivery(delivery, now)
        return

    if kind == "follow_up":
        initial_submitted_at = parse_iso(incident.get("initial_submitted_at"))
        follow_up_queued_at = parse_iso(delivery.get("created_at"))
        if not follow_up_may_submit(initial_submitted_at, follow_up_queued_at):
            # If the initial attempt was delayed until after the second-day
            # follow-up was queued, submit only the first alert. This avoids two
            # back-to-back notifications when a device or queue recovers.
            _cancel_delivery(delivery, now)
            return

    devices = [
        value for value in query_partition(account_pk(guardian_sub), "DEVICE#", limit=20)
        if value.get("notifications_authorized") is True and value.get("reachability") == "active"
    ]
    if not devices:
        _update_relationship_reachability(owner_sub, guardian_sub, relationship_id, "unreachable", now)
        _update_relationship_notification_state(
            owner_sub, guardian_sub, relationship_id, "unreachable", now
        )
        return

    outcomes: list[str] = []
    for device in devices:
        outcomes.append(_submit_once(device, relationship_id, incident, kind, now))
    submitted = "submitted" in outcomes
    already_submitted = "already_submitted" in outcomes
    if submitted or already_submitted:
        delivery.update({"state": "submitted", "submitted_at": iso(now), "updated_at": iso(now)})
        delivery.pop("GSI1PK", None)
        delivery.pop("GSI1SK", None)
        delivery.pop("next_attempt_at", None)
        TABLE.put_item(Item=delivery)
        _mark_incident_submitted(incident, kind, now)
        _update_relationship_notification_state(
            owner_sub, guardian_sub, relationship_id, "submitted", now
        )
    elif outcomes and all(outcome == "unreachable" for outcome in outcomes):
        _update_relationship_reachability(owner_sub, guardian_sub, relationship_id, "unreachable", now)
        _update_relationship_notification_state(
            owner_sub, guardian_sub, relationship_id, "unreachable", now
        )


def _submit_once(
    device: dict[str, Any],
    relationship_id: str,
    incident: dict[str, Any],
    kind: str,
    now,
) -> str:
    endpoint_hash = hashlib.sha256(device["endpoint_arn"].encode("utf-8")).hexdigest()[:24]
    attempt_key = {
        "PK": f"INCIDENT#{incident['incident_id']}",
        "SK": f"ATTEMPT#{kind}#{relationship_id}#{endpoint_hash}",
    }
    existing = TABLE.get_item(Key=attempt_key, ConsistentRead=True).get("Item")
    if existing and existing.get("state") in {"submitted", "opened", "acknowledged"}:
        return "already_submitted"
    if existing and existing.get("state") == "sending":
        lease = parse_iso(existing.get("lease_until"))
        if lease and lease > now:
            return "leased"
    lease_until = now + timedelta(minutes=2)
    attempt_item = {
        **attempt_key,
        "entity_type": "NOTIFICATION_ATTEMPT",
        "incident_id": incident["incident_id"],
        "relationship_id": relationship_id,
        "kind": kind,
        "state": "sending",
        "lease_until": iso(lease_until),
        "created_at": (existing or {}).get("created_at", iso(now)),
        "updated_at": iso(now),
        "expires_at_epoch": int((now + timedelta(days=90)).timestamp()),
    }
    try:
        TABLE.put_item(
            Item=attempt_item,
            ConditionExpression=(
                "attribute_not_exists(PK) OR #state=:failed OR "
                "(#state=:sending AND lease_until<=:now)"
            ),
            ExpressionAttributeNames={"#state": "state"},
            ExpressionAttributeValues={
                ":failed": "failed",
                ":sending": "sending",
                ":now": iso(now),
            },
        )
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
            raise
        current = TABLE.get_item(Key=attempt_key, ConsistentRead=True).get("Item")
        if current and current.get("state") in {"submitted", "opened", "acknowledged"}:
            return "already_submitted"
        return "leased"
    try:
        result = SNS.publish(
            TargetArn=device["endpoint_arn"],
            MessageStructure="json",
            Message=json.dumps(_sns_message(device, incident["incident_id"], kind), separators=(",", ":")),
            MessageAttributes={
                "AWS.SNS.MOBILE.APNS.PUSH_TYPE": {"DataType": "String", "StringValue": "alert"},
                "AWS.SNS.MOBILE.APNS.PRIORITY": {"DataType": "String", "StringValue": "10"},
                "AWS.SNS.MOBILE.APNS.TOPIC": {"DataType": "String", "StringValue": os.environ["APPLE_BUNDLE_ID"]},
            },
        )
        TABLE.update_item(
            Key=attempt_key,
            UpdateExpression="SET #state=:state, submitted_at=:now, sns_message_id=:message, updated_at=:now REMOVE lease_until",
            ExpressionAttributeNames={"#state": "state"},
            ExpressionAttributeValues={
                ":state": "submitted", ":now": iso(now), ":message": result["MessageId"],
            },
        )
        return "submitted"
    except ClientError as error:
        code = error.response.get("Error", {}).get("Code", "SNS_ERROR")
        TABLE.update_item(
            Key=attempt_key,
            UpdateExpression="SET #state=:state, error_code=:code, updated_at=:now REMOVE lease_until",
            ExpressionAttributeNames={"#state": "state"},
            ExpressionAttributeValues={":state": "failed", ":code": code[:80], ":now": iso(now)},
        )
        if code in {"EndpointDisabled", "NotFound"}:
            device["reachability"] = "unreachable"
            device["updated_at"] = iso(now)
            TABLE.put_item(Item=device)
            return "unreachable"
        raise


def _sns_message(device: dict[str, Any], incident_id: str, kind: str) -> dict[str, str]:
    language = str(device.get("locale_identifier") or "en").split("_")[0].split("-")[0].lower()
    localized = COPY.get(language, COPY["en"])
    payload = {
        "aps": {
            "alert": {"title": "Ohana Guardian", "body": localized[kind]},
            "sound": "default",
            "category": "OHANA_GUARDIAN_INCIDENT",
            "content-available": 1,
        },
        "ohana_guardian": True,
        "guardian_incident_id": incident_id,
    }
    encoded = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    protocol = "APNS" if device.get("environment") == "production" else "APNS_SANDBOX"
    return {"default": localized[kind], protocol: encoded}


def _mark_incident_submitted(incident: dict[str, Any], kind: str, now) -> None:
    if kind == "initial":
        incident["status"] = "initialSubmitted"
        incident.setdefault("initial_submitted_at", iso(now))
    elif kind == "follow_up":
        incident["status"] = "followUpSubmitted"
        incident.setdefault("follow_up_submitted_at", iso(now))
    incident["updated_at"] = iso(now)
    TABLE.put_item(Item=incident)


def _update_relationship_reachability(owner_sub, guardian_sub, relationship_id, value, now) -> None:
    for key in (
        {"PK": account_pk(owner_sub), "SK": f"REL#{relationship_id}"},
        {"PK": account_pk(guardian_sub), "SK": f"GUARDING#{relationship_id}"},
    ):
        TABLE.update_item(
            Key=key,
            UpdateExpression="SET reachability=:value, updated_at=:now",
            ExpressionAttributeValues={":value": value, ":now": iso(now)},
        )


def _update_relationship_notification_state(owner_sub, guardian_sub, relationship_id, value, now) -> None:
    for key in (
        {"PK": account_pk(owner_sub), "SK": f"REL#{relationship_id}"},
        {"PK": account_pk(guardian_sub), "SK": f"GUARDING#{relationship_id}"},
    ):
        TABLE.update_item(
            Key=key,
            UpdateExpression="SET latest_notification_state=:value, latest_notification_updated_at=:now, updated_at=:now",
            ExpressionAttributeValues={":value": value, ":now": iso(now)},
        )


def _cancel_delivery(delivery: dict[str, Any], now) -> None:
    delivery.update({"state": "cancelled", "updated_at": iso(now)})
    delivery.pop("GSI1PK", None)
    delivery.pop("GSI1SK", None)
    delivery.pop("next_attempt_at", None)
    TABLE.put_item(Item=delivery)

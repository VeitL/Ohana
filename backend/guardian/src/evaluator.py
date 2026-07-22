"""Due guard-day evaluation, durable push enqueue, and retention cleanup."""

from __future__ import annotations

import hashlib
import json
import os
from datetime import timedelta, timezone
from typing import Any

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from common import iso, now_utc, parse_iso
from rules import IncidentProgress, evaluate, guard_occurrence, next_evaluation_time
from storage import TABLE, account_pk, delete_partition, get, query_partition, transaction_pk

SQS = boto3.client("sqs")


def handler(_event: dict[str, Any], _context: Any) -> dict[str, int]:
    now = now_utc()
    due = TABLE.query(
        IndexName="GSI1",
        KeyConditionExpression=Key("GSI1PK").eq("POLICY#ENABLED") & Key("GSI1SK").lte(iso(now)),
        Limit=100,
    ).get("Items", [])
    evaluated = 0
    for projected in due:
        if _evaluate_policy(projected, now):
            evaluated += 1
    retried = _retry_pending_deliveries(now)
    purged = _purge_due_accounts(now)
    return {"evaluated": evaluated, "retried": retried, "purged": purged}


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


def _progress(policy: dict[str, Any], incident: dict[str, Any] | None) -> IncidentProgress:
    status = incident.get("status") if incident else None
    return IncidentProgress(
        consecutive_misses=int(policy.get("consecutive_misses", 0)),
        last_guard_day_key=policy.get("last_guard_day_key"),
        incident_open=bool(incident and status not in {"acknowledged", "recovered", "closed"}),
        initial_submitted=bool(policy.get("initial_queued")),
        follow_up_submitted=bool(policy.get("follow_up_queued")),
        acknowledged=status == "acknowledged",
    )


def _evaluate_policy(projected: dict[str, Any], now) -> bool:
    subject = projected["PK"].removeprefix("ACCOUNT#")
    policy = get(account_pk(subject), "POLICY")
    if not policy or not policy.get("is_enabled"):
        return False
    due_at = parse_iso(policy.get("next_evaluation_at"))
    if due_at is None or due_at > now:
        return False
    if not _active_entitlement(subject, now):
        policy.update({
            "is_enabled": False,
            "status": "stopped",
            "consecutive_misses": 0,
            "updated_at": iso(now),
        })
        for key in (
            "GSI1PK", "GSI1SK", "next_evaluation_at", "active_incident_id",
            "initial_queued", "follow_up_queued",
        ):
            policy.pop(key, None)
        TABLE.put_item(Item=policy)
        for incident in query_partition(account_pk(subject), "INCIDENT#", limit=20):
            if incident.get("status") not in {"acknowledged", "recovered", "closed"}:
                incident["status"] = "closed"
                incident["updated_at"] = iso(now)
                TABLE.put_item(Item=incident)
        return True
    pause_until = parse_iso(policy.get("pause_until"))
    occurrence = guard_occurrence(
        due_at - timedelta(minutes=int(policy["grace_period_minutes"])),
        time_zone_identifier=policy["time_zone_identifier"],
        weekdays=policy["weekdays"],
        deadline_hour=int(policy["deadline_hour"]),
        deadline_minute=int(policy["deadline_minute"]),
        grace_period_minutes=int(policy["grace_period_minutes"]),
        pause_until=pause_until,
    )
    if policy.get("last_evaluated_day_key") == occurrence.day_key:
        _schedule_next(subject, policy, now)
        return False

    guard_day = get(account_pk(subject), f"GUARDDAY#{occurrence.day_key}")
    checked_in = bool(guard_day and guard_day.get("checked_in"))
    incident_id = policy.get("active_incident_id")
    incident = get(account_pk(subject), f"INCIDENT#{incident_id}") if incident_id else None
    result = evaluate(
        _progress(policy, incident),
        eligible=(
            policy.get("mode_active") is True
            and policy.get("owner_active") is True
        ),
        scheduled=occurrence.scheduled,
        paused=occurrence.paused,
        checked_in=checked_in,
        day_key=occurrence.day_key,
    )

    action_incident = incident
    if result.action == "initial":
        incident_id = hashlib.sha256(
            f"{policy['policy_id']}:{occurrence.day_key}".encode("utf-8")
        ).hexdigest()[:32]
        action_incident = {
            "PK": account_pk(subject),
            "SK": f"INCIDENT#{incident_id}",
            "entity_type": "INCIDENT",
            "incident_id": incident_id,
            "policy_id": policy["policy_id"],
            "status": "monitoring",
            "last_guard_day_key": occurrence.day_key,
            "consecutive_misses": result.progress.consecutive_misses,
            "created_at": iso(now),
            "updated_at": iso(now),
            "expires_at_epoch": int((now + timedelta(days=90)).timestamp()),
        }
        try:
            TABLE.put_item(Item=action_incident, ConditionExpression="attribute_not_exists(PK)")
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
            action_incident = get(account_pk(subject), f"INCIDENT#{incident_id}")
    elif action_incident:
        action_incident["last_guard_day_key"] = occurrence.day_key
        action_incident["consecutive_misses"] = result.progress.consecutive_misses
        action_incident["updated_at"] = iso(now)
        TABLE.put_item(Item=action_incident)

    next_due = next_evaluation_time(
        now + timedelta(seconds=1),
        time_zone_identifier=policy["time_zone_identifier"],
        weekdays=policy["weekdays"],
        deadline_hour=int(policy["deadline_hour"]),
        deadline_minute=int(policy["deadline_minute"]),
        grace_period_minutes=int(policy["grace_period_minutes"]),
        pause_until=pause_until,
    )
    update = (
        "SET #status=:monitoring, consecutive_misses=:misses, last_guard_day_key=:day, "
        "last_evaluated_day_key=:day, next_evaluation_at=:next, GSI1SK=:next, updated_at=:now"
    )
    values: dict[str, Any] = {
        ":misses": result.progress.consecutive_misses,
        ":day": occurrence.day_key,
        ":next": iso(next_due),
        ":now": iso(now),
        ":revision": int(policy["schedule_revision"]),
        ":monitoring": "monitoring",
    }
    if incident_id and result.action not in {"reset", "recovery"}:
        update += ", active_incident_id=:incident"
        values[":incident"] = incident_id
    if result.action == "initial":
        update += ", initial_queued=:true"
        values[":true"] = True
    elif result.action == "follow_up":
        update += ", follow_up_queued=:true"
        values[":true"] = True
    elif result.action in {"reset", "recovery"}:
        update += " REMOVE active_incident_id, initial_queued, follow_up_queued"
    try:
        TABLE.update_item(
            Key={"PK": account_pk(subject), "SK": "POLICY"},
            UpdateExpression=update,
            ExpressionAttributeNames={"#status": "status"},
            ConditionExpression=(
                "schedule_revision=:revision AND is_enabled=:enabled AND "
                "(attribute_not_exists(last_evaluated_day_key) OR last_evaluated_day_key<>:day)"
            ),
            ExpressionAttributeValues={**values, ":enabled": True},
        )
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") == "ConditionalCheckFailedException":
            return False
        raise

    if result.action in {"initial", "follow_up"} and action_incident:
        _create_delivery_outbox(subject, action_incident, result.action, now)
    elif result.action == "recovery" and action_incident:
        action_incident.update({"status": "recovered", "recovered_at": iso(now), "updated_at": iso(now)})
        TABLE.put_item(Item=action_incident)
        _create_delivery_outbox(subject, action_incident, "recovery", now, submitted_only=True)
    return True


def _schedule_next(subject: str, policy: dict[str, Any], now) -> None:
    next_due = next_evaluation_time(
        now + timedelta(seconds=1),
        time_zone_identifier=policy["time_zone_identifier"],
        weekdays=policy["weekdays"],
        deadline_hour=int(policy["deadline_hour"]),
        deadline_minute=int(policy["deadline_minute"]),
        grace_period_minutes=int(policy["grace_period_minutes"]),
        pause_until=parse_iso(policy.get("pause_until")),
    )
    TABLE.update_item(
        Key={"PK": account_pk(subject), "SK": "POLICY"},
        UpdateExpression="SET next_evaluation_at=:next, GSI1SK=:next, updated_at=:now",
        ExpressionAttributeValues={":next": iso(next_due), ":now": iso(now)},
    )


def _create_delivery_outbox(
    owner_sub: str,
    incident: dict[str, Any],
    kind: str,
    now,
    *,
    submitted_only: bool = False,
) -> None:
    for relationship in query_partition(account_pk(owner_sub), "REL#", limit=20):
        if relationship.get("status") != "accepted" or relationship.get("reachability") != "active":
            continue
        relationship_id = relationship["relationship_id"]
        if submitted_only:
            prior = query_partition(f"INCIDENT#{incident['incident_id']}", f"ATTEMPT#", limit=100)
            if not any(
                item.get("relationship_id") == relationship_id and item.get("state") in {"submitted", "opened", "acknowledged"}
                for item in prior
            ):
                continue
        delivery_key = f"{incident['incident_id']}:{kind}:{relationship_id}"
        item = {
            "PK": "DELIVERY",
            "SK": f"PENDING#{delivery_key}",
            "entity_type": "DELIVERY",
            "delivery_key": delivery_key,
            "owner_sub": owner_sub,
            "guardian_sub": relationship["guardian_sub"],
            "relationship_id": relationship_id,
            "incident_id": incident["incident_id"],
            "kind": kind,
            "state": "pending",
            "attempt_count": 0,
            "GSI1PK": "DELIVERY#PENDING",
            "GSI1SK": iso(now),
            "next_attempt_at": iso(now),
            "created_at": iso(now),
            "updated_at": iso(now),
            "expires_at_epoch": int((now + timedelta(days=90)).timestamp()),
        }
        try:
            TABLE.put_item(Item=item, ConditionExpression="attribute_not_exists(PK)")
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
        _send_delivery(item)


def _send_delivery(item: dict[str, Any]) -> None:
    SQS.send_message(
        QueueUrl=os.environ["PUSH_QUEUE_URL"],
        MessageBody=json.dumps({
            "delivery_key": item["delivery_key"],
            "owner_sub": item["owner_sub"],
            "guardian_sub": item["guardian_sub"],
            "relationship_id": item["relationship_id"],
            "incident_id": item["incident_id"],
            "kind": item["kind"],
        }, separators=(",", ":")),
    )


def _retry_pending_deliveries(now) -> int:
    values = TABLE.query(
        IndexName="GSI1",
        KeyConditionExpression=Key("GSI1PK").eq("DELIVERY#PENDING") & Key("GSI1SK").lte(iso(now)),
        Limit=100,
    ).get("Items", [])
    for value in values:
        _send_delivery(value)
        delay = min(30 * (2 ** min(int(value.get("attempt_count", 0)), 8)), 21_600)
        TABLE.update_item(
            Key={"PK": value["PK"], "SK": value["SK"]},
            UpdateExpression="SET attempt_count=if_not_exists(attempt_count,:zero)+:one, next_attempt_at=:next, GSI1SK=:next, updated_at=:now",
            ExpressionAttributeValues={
                ":zero": 0, ":one": 1,
                ":next": iso(now + timedelta(seconds=delay)), ":now": iso(now),
            },
        )
    return len(values)


def _purge_due_accounts(now) -> int:
    values = TABLE.query(
        IndexName="GSI1",
        KeyConditionExpression=Key("GSI1PK").eq("RETENTION#DUE") & Key("GSI1SK").lte(iso(now)),
        Limit=25,
    ).get("Items", [])
    for marker in values:
        subject = marker["PK"].removeprefix("ACCOUNT#")
        entitlement = get(account_pk(subject), "ENTITLEMENT")
        original_id = entitlement.get("original_transaction_id") if entitlement else None
        delete_partition(account_pk(subject))
        if original_id:
            TABLE.delete_item(Key={"PK": transaction_pk(original_id), "SK": "OWNER"})
    return len(values)

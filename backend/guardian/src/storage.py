"""DynamoDB keys and bounded read helpers for the guardian service."""

from __future__ import annotations

import hashlib
import os
from typing import Any, Iterable

import boto3
from boto3.dynamodb.conditions import Key

TABLE = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def account_pk(subject: str) -> str:
    return f"ACCOUNT#{subject}"


def invite_pk(code: str) -> str:
    digest = hashlib.sha256(code.encode("ascii")).hexdigest()
    return f"INVITE#{digest}"


def transaction_pk(original_transaction_id: str) -> str:
    return f"TRANSACTION#{original_transaction_id}"


def device_key(device_id: str) -> str:
    digest = hashlib.sha256(device_id.encode("ascii")).hexdigest()
    return f"DEVICE#{digest}"


def query_partition(pk: str, prefix: str, *, limit: int = 100) -> list[dict[str, Any]]:
    result = TABLE.query(
        KeyConditionExpression=Key("PK").eq(pk) & Key("SK").begins_with(prefix),
        Limit=limit,
        ConsistentRead=True,
    )
    return result.get("Items", [])


def get(pk: str, sk: str, *, consistent: bool = True) -> dict[str, Any] | None:
    return TABLE.get_item(Key={"PK": pk, "SK": sk}, ConsistentRead=consistent).get("Item")


def delete_partition(pk: str, *, page_limit: int = 100) -> int:
    deleted = 0
    while True:
        result = TABLE.query(
            KeyConditionExpression=Key("PK").eq(pk),
            ProjectionExpression="PK, SK",
            Limit=page_limit,
            ConsistentRead=True,
        )
        items = result.get("Items", [])
        with TABLE.batch_writer() as batch:
            for item in items:
                batch.delete_item(Key={"PK": item["PK"], "SK": item["SK"]})
                deleted += 1
        if not result.get("LastEvaluatedKey"):
            return deleted


def batch_put(items: Iterable[dict[str, Any]]) -> None:
    with TABLE.batch_writer(overwrite_by_pkeys=["PK", "SK"]) as batch:
        for item in items:
            batch.put_item(Item=item)

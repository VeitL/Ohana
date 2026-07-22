"""Idempotent SNS platform endpoint registration and invalidation."""

from __future__ import annotations

import hashlib
import os
import re
from datetime import timedelta
from typing import Any

import boto3
from botocore.exceptions import ClientError

from common import APIError, iso, now_utc
from storage import TABLE, account_pk, device_key, query_partition

TOKEN = re.compile(r"^[0-9a-fA-F]{32,256}$")
ENDPOINT_IN_ERROR = re.compile(r"(arn:aws:sns:[^ ]+:endpoint/[^ ]+)")


def _client():
    return boto3.client("sns")


def _platform_application(environment: str) -> str:
    if environment == "production":
        return os.environ["APNS_PLATFORM_APPLICATION_ARN"]
    if environment == "sandbox":
        return os.environ["APNS_SANDBOX_PLATFORM_APPLICATION_ARN"]
    raise APIError(400, "INVALID_APNS_ENVIRONMENT")


def _create_endpoint(token: str, environment: str, subject: str) -> str:
    sns = _client()
    try:
        return sns.create_platform_endpoint(
            PlatformApplicationArn=_platform_application(environment),
            Token=token,
            CustomUserData=hashlib.sha256(subject.encode("utf-8")).hexdigest(),
        )["EndpointArn"]
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") != "InvalidParameter":
            raise
        match = ENDPOINT_IN_ERROR.search(error.response.get("Error", {}).get("Message", ""))
        if not match:
            raise
        return match.group(1).rstrip(".")


def ensure_endpoint(subject: str, payload: dict[str, Any]) -> dict[str, Any]:
    device_id = payload.get("device_id")
    token = payload.get("apns_token")
    environment = payload.get("environment")
    if not isinstance(device_id, str) or not re.fullmatch(r"[A-Za-z0-9._:-]{1,160}", device_id):
        raise APIError(400, "INVALID_DEVICE_ID")
    if not isinstance(token, str) or not TOKEN.fullmatch(token):
        raise APIError(400, "INVALID_APNS_TOKEN")
    if environment not in {"production", "sandbox"}:
        raise APIError(400, "INVALID_APNS_ENVIRONMENT")
    authorized = payload.get("notifications_authorized") is True
    key = {"PK": account_pk(subject), "SK": device_key(device_id)}
    existing = TABLE.get_item(Key=key, ConsistentRead=True).get("Item")
    endpoint_arn = existing.get("endpoint_arn") if existing else None
    sns = _client()

    if endpoint_arn and existing.get("environment") != environment:
        try:
            sns.delete_endpoint(EndpointArn=endpoint_arn)
        except ClientError:
            pass
        endpoint_arn = None

    if endpoint_arn:
        try:
            attributes = sns.get_endpoint_attributes(EndpointArn=endpoint_arn)["Attributes"]
        except ClientError as error:
            if error.response.get("Error", {}).get("Code") != "NotFound":
                raise
            endpoint_arn = None
            attributes = {}
    else:
        attributes = {}
    if not endpoint_arn:
        endpoint_arn = _create_endpoint(token, environment, subject)
        attributes = sns.get_endpoint_attributes(EndpointArn=endpoint_arn)["Attributes"]
    if attributes.get("Token") != token or attributes.get("Enabled", "false").lower() != "true":
        sns.set_endpoint_attributes(
            EndpointArn=endpoint_arn,
            Attributes={"Token": token, "Enabled": "true"},
        )

    now = now_utc()
    item = {
        **key,
        "entity_type": "DEVICE",
        "endpoint_arn": endpoint_arn,
        "device_id": device_id,
        "token": token,
        "environment": environment,
        "locale_identifier": str(payload.get("locale_identifier") or "en"),
        "time_zone_identifier": str(payload.get("time_zone_identifier") or "UTC"),
        "notifications_authorized": authorized,
        "reachability": "active" if authorized else "notificationsDisabled",
        "updated_at": iso(now),
        "expires_at_epoch": int((now + timedelta(days=90)).timestamp()),
    }
    TABLE.put_item(Item=item)
    return item


def remove_device(subject: str, payload: dict[str, Any]) -> int:
    device_id = payload.get("device_id")
    if not isinstance(device_id, str) or not re.fullmatch(r"[A-Za-z0-9._:-]{1,160}", device_id):
        raise APIError(400, "INVALID_DEVICE_ID")
    key = {"PK": account_pk(subject), "SK": device_key(device_id)}
    device = TABLE.get_item(Key=key, ConsistentRead=True).get("Item")
    if not device:
        return 0
    endpoint = device.get("endpoint_arn")
    if endpoint:
        try:
            _client().delete_endpoint(EndpointArn=endpoint)
        except ClientError:
            pass
    TABLE.delete_item(Key=key)
    return 1


def remove_devices(subject: str) -> int:
    devices = query_partition(account_pk(subject), "DEVICE#", limit=20)
    sns = _client()
    for device in devices:
        endpoint = device.get("endpoint_arn")
        if endpoint:
            try:
                sns.delete_endpoint(EndpointArn=endpoint)
            except ClientError:
                pass
        TABLE.delete_item(Key={"PK": device["PK"], "SK": device["SK"]})
    return len(devices)

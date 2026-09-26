"""Fail-closed App Store JWS verification using Apple's server library."""

from __future__ import annotations

import base64
import json
import os
from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any

import boto3
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from common import APIError


@dataclass(frozen=True)
class VerifiedFamilyTransaction:
    original_transaction_id: str
    transaction_id: str
    expires_at: datetime
    environment: str
    active: bool


@lru_cache(maxsize=1)
def _root_certificates() -> list[bytes]:
    arn = os.environ["APPLE_ROOT_CERTIFICATES_SECRET_ARN"]
    value = boto3.client("secretsmanager").get_secret_value(SecretId=arn)
    secret = json.loads(value.get("SecretString") or "{}")
    encoded = secret.get("certificates")
    if not isinstance(encoded, list) or not encoded:
        raise RuntimeError("Apple root certificate secret is invalid")
    return [base64.b64decode(item, validate=True) for item in encoded]


@lru_cache(maxsize=2)
def _verifier(environment: Environment) -> SignedDataVerifier:
    app_id = int(os.environ["APPLE_APP_ID"]) if environment == Environment.PRODUCTION else None
    return SignedDataVerifier(
        _root_certificates(),
        True,
        environment,
        os.environ["APPLE_BUNDLE_ID"],
        app_id,
    )


def _milliseconds_date(value: Any) -> datetime | None:
    if value is None:
        return None
    return datetime.fromtimestamp(int(value) / 1000, tz=timezone.utc)


def _attribute(value: Any, *names: str) -> Any:
    for name in names:
        candidate = getattr(value, name, None)
        if candidate is not None:
            return candidate
    return None


def _family_state_from_decoded(
    decoded: Any,
    verified_environment: Environment,
    *,
    require_family_product: bool,
) -> VerifiedFamilyTransaction:
    bundle_id = _attribute(decoded, "bundleId", "bundle_id")
    product_id = _attribute(decoded, "productId", "product_id")
    original_id = _attribute(decoded, "originalTransactionId", "original_transaction_id")
    transaction_id = _attribute(decoded, "transactionId", "transaction_id")
    expires_at = _milliseconds_date(_attribute(decoded, "expiresDate", "expires_date"))
    revocation = _attribute(decoded, "revocationDate", "revocation_date")
    is_upgraded = bool(_attribute(decoded, "isUpgraded", "is_upgraded") or False)
    if bundle_id != os.environ["APPLE_BUNDLE_ID"] or not isinstance(original_id, str) or not isinstance(transaction_id, str):
        raise APIError(403, "TRANSACTION_PRODUCT_MISMATCH")
    is_family_product = product_id == os.environ["FAMILY_PRODUCT_ID"]
    if require_family_product and (not is_family_product or expires_at is None):
        raise APIError(403, "TRANSACTION_PRODUCT_MISMATCH")

    active = bool(
        is_family_product
        and expires_at is not None
        and revocation is None
        and not is_upgraded
        and expires_at > datetime.now(timezone.utc)
    )
    return VerifiedFamilyTransaction(
        original_transaction_id=original_id,
        transaction_id=transaction_id,
        # A transaction for another product in the shared subscription group
        # explicitly ends Family. Keep a concrete date for the projection even
        # if that transaction is a non-expiring product.
        expires_at=expires_at or datetime.now(timezone.utc),
        environment="production" if verified_environment == Environment.PRODUCTION else "sandbox",
        active=active,
    )


def verify_family_transaction(signed_transaction: str) -> VerifiedFamilyTransaction:
    if not isinstance(signed_transaction, str) or len(signed_transaction) > 65_536:
        raise APIError(400, "INVALID_TRANSACTION")

    decoded = None
    verified_environment = None
    for environment in (Environment.PRODUCTION, Environment.SANDBOX):
        try:
            decoded = _verifier(environment).verify_and_decode_signed_transaction(signed_transaction)
            verified_environment = environment
            break
        except VerificationException:
            continue
    if decoded is None or verified_environment is None:
        raise APIError(403, "TRANSACTION_NOT_VERIFIED")
    return _family_state_from_decoded(
        decoded,
        verified_environment,
        require_family_product=True,
    )


def verify_notification(signed_payload: str) -> tuple[Any, VerifiedFamilyTransaction | None]:
    if not isinstance(signed_payload, str) or len(signed_payload) > 131_072:
        raise APIError(400, "INVALID_NOTIFICATION")
    decoded_notification = None
    verifier = None
    verified_environment = None
    for environment in (Environment.PRODUCTION, Environment.SANDBOX):
        try:
            verifier = _verifier(environment)
            decoded_notification = verifier.verify_and_decode_notification(signed_payload)
            verified_environment = environment
            break
        except VerificationException:
            continue
    if decoded_notification is None or verifier is None or verified_environment is None:
        raise APIError(403, "NOTIFICATION_NOT_VERIFIED")

    data = _attribute(decoded_notification, "data")
    signed_transaction = _attribute(data, "signedTransactionInfo", "signed_transaction_info") if data else None
    transaction = None
    if signed_transaction:
        try:
            decoded_transaction = verifier.verify_and_decode_signed_transaction(signed_transaction)
        except VerificationException as exc:
            raise APIError(403, "TRANSACTION_NOT_VERIFIED") from exc
        transaction = _family_state_from_decoded(
            decoded_transaction,
            verified_environment,
            require_family_product=False,
        )
    return decoded_notification, transaction

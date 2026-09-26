#!/usr/bin/env python3
"""Read-only, privacy-minimized status for the pinned Dogfood user store."""

from __future__ import annotations

import argparse
import json
import plistlib
import shutil
import sqlite3
import sys
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs/governance/manifests/dogfood-user-profile.json"
APPLE_REFERENCE_TO_UNIX_SECONDS = 978_307_200
REQUIRED_CORE_TABLES = {
    "Z_METADATA",
    "ZHUMAN",
    "ZPET",
    "ZEVENT",
    "ZCOCONUTLEDGERENTRY",
    "ZCARELEDGEREVENT",
}
CARE_EVENT_KINDS = (
    "care",
    "potty",
    "walk",
    "hygiene",
    "health",
    "medication",
    "workout",
    "plantCare",
)
CARE_EVENT_KIND_SQL = "(" + ", ".join(f"'{kind}'" for kind in CARE_EVENT_KINDS) + ")"

CARE_TABLES: dict[str, tuple[str, ...]] = {
    "ZPETCARELOG": ("ZDATE", "ZCREATEDAT"),
    "ZPETHYGIENELOG": ("ZDATE", "ZCREATEDAT"),
    "ZPETHEALTHLOG": ("ZDATE", "ZCREATEDAT"),
    "ZPETMEDICATIONLOG": ("ZDATE", "ZTAKENAT", "ZCREATEDAT"),
    "ZPETPOTTYLOG": ("ZDATE", "ZCREATEDAT"),
    "ZPETWALKLOG": ("ZSTARTDATE", "ZCREATEDAT"),
    "ZPETWEIGHTLOG": ("ZDATE", "ZCREATEDAT"),
    "ZWATERLOG": ("ZDATE", "ZCREATEDAT"),
    "ZPLANTCARELOG": ("ZDATE", "ZCREATEDAT"),
    "ZHUMANHEALTHMETRICLOG": ("ZDATE", "ZCREATEDAT"),
    "ZHUMANMEDICATIONLOG": ("ZDATE", "ZTAKENAT", "ZCREATEDAT"),
    "ZHUMANWEIGHTLOG": ("ZDATE", "ZCREATEDAT"),
    "ZHUMANWORKOUTLOG": ("ZSTARTDATE", "ZDATE", "ZCREATEDAT"),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print an anonymized readiness snapshot for an Ohana Dogfood store."
    )
    parser.add_argument("--store", required=True, type=Path)
    parser.add_argument("--preferences", type=Path)
    parser.add_argument("--data-container", type=Path)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--require-safe", action="store_true")
    parser.add_argument("--require-ready", action="store_true")
    parser.add_argument("--require-longitudinal", action="store_true")
    parser.add_argument("--require-day30", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"unable to read Dogfood profile manifest: {error}") from error
    if not isinstance(value, dict):
        raise RuntimeError("Dogfood profile manifest must contain a JSON object")
    return value


def load_preferences(path: Path | None) -> dict[str, Any]:
    if path is None or not path.is_file():
        return {}
    try:
        with path.open("rb") as handle:
            value = plistlib.load(handle)
    except (OSError, plistlib.InvalidFileException) as error:
        raise RuntimeError(f"unable to read Dogfood preferences: {error}") from error
    return value if isinstance(value, dict) else {}


def validate_gate_paths(arguments: argparse.Namespace) -> None:
    if not (
        arguments.require_safe
        or arguments.require_ready
        or arguments.require_longitudinal
        or arguments.require_day30
    ):
        return
    if arguments.data_container is None or not arguments.data_container.is_dir():
        raise RuntimeError("gated Dogfood status requires the installed app data container")
    expected_store = (
        arguments.data_container / "Library" / "Application Support" / "default.store"
    ).resolve()
    if arguments.store.resolve() != expected_store:
        raise RuntimeError(
            "gated Dogfood status requires Library/Application Support/default.store "
            "from the supplied data container"
        )


def test_artifact_count(data_container: Path | None) -> int:
    if data_container is None:
        return 0
    preferences = data_container / "Library" / "Preferences"
    if not preferences.is_dir():
        return 0
    return sum(1 for path in preferences.glob("*Tests*.plist") if path.is_file())


class ReadOnlyStore:
    def __init__(self, path: Path, verify_integrity: bool = False) -> None:
        if not path.is_file():
            raise RuntimeError(f"Dogfood primary store is missing: {path}")
        if verify_integrity:
            self.verify_integrity_snapshot(path)
        uri = f"file:{path.resolve()}?mode=ro"
        try:
            self.connection = sqlite3.connect(uri, uri=True, timeout=2.0)
            self.connection.execute("PRAGMA query_only = ON")
            self.tables = {
                str(row[0])
                for row in self.connection.execute(
                    "SELECT name FROM sqlite_master WHERE type = 'table'"
                )
            }
        except sqlite3.Error as error:
            raise RuntimeError(f"unable to open Dogfood store read-only: {error}") from error
        self._columns: dict[str, set[str]] = {}

    @staticmethod
    def verify_integrity_snapshot(path: Path) -> None:
        try:
            with tempfile.TemporaryDirectory(prefix="ohana-dogfood-store-check.") as raw:
                root = Path(raw)
                snapshot = root / path.name
                for suffix in ("", "-wal", "-shm"):
                    source = Path(f"{path}{suffix}")
                    if source.is_file():
                        shutil.copy2(source, Path(f"{snapshot}{suffix}"))
                connection = sqlite3.connect(snapshot, timeout=2.0)
                try:
                    rows = connection.execute("PRAGMA quick_check").fetchall()
                finally:
                    connection.close()
        except (OSError, sqlite3.Error) as error:
            raise RuntimeError(
                f"unable to quick-check a snapshot of the Dogfood store: {error}"
            ) from error
        if not rows or any(str(row[0]).lower() != "ok" for row in rows):
            detail = str(rows[0][0]) if rows else "no result"
            raise RuntimeError(f"Dogfood primary store quick-check failed: {detail}")

    def close(self) -> None:
        self.connection.close()

    def columns(self, table: str) -> set[str]:
        if table not in self._columns:
            if table not in self.tables:
                self._columns[table] = set()
            else:
                self._columns[table] = {
                    str(row[1])
                    for row in self.connection.execute(f'PRAGMA table_info("{table}")')
                }
        return self._columns[table]

    def count(self, table: str, conditions: Iterable[str] = ()) -> int:
        if table not in self.tables:
            return 0
        predicate = " AND ".join(conditions)
        query = f'SELECT COUNT(*) FROM "{table}"'
        if predicate:
            query += f" WHERE {predicate}"
        try:
            row = self.connection.execute(query).fetchone()
        except sqlite3.Error as error:
            raise RuntimeError(f"unable to inspect {table}: {error}") from error
        return int(row[0] if row else 0)

    def count_live(self, table: str, extra_conditions: Iterable[str] = ()) -> int:
        columns = self.columns(table)
        conditions = list(extra_conditions)
        if "ZTRASHEDAT" in columns:
            conditions.append("ZTRASHEDAT IS NULL")
        return self.count(table, conditions)

    def query_count(self, query: str, parameters: tuple[Any, ...] = ()) -> int:
        try:
            row = self.connection.execute(query, parameters).fetchone()
        except sqlite3.Error as error:
            raise RuntimeError(f"unable to inspect Dogfood relationship counts: {error}") from error
        return int(row[0] if row else 0)

    def timestamps(
        self,
        table: str,
        candidates: Iterable[str],
        extra_conditions: Iterable[str] = (),
    ) -> list[float]:
        columns = self.columns(table)
        selected = next((column for column in candidates if column in columns), None)
        if selected is None:
            return []
        conditions = [f"{selected} IS NOT NULL", *extra_conditions]
        if "ZTRASHEDAT" in columns:
            conditions.append("ZTRASHEDAT IS NULL")
        query = f'SELECT "{selected}" FROM "{table}" WHERE ' + " AND ".join(conditions)
        values: list[float] = []
        try:
            for row in self.connection.execute(query):
                if row and isinstance(row[0], (int, float)):
                    values.append(float(row[0]))
        except sqlite3.Error as error:
            raise RuntimeError(f"unable to inspect timestamps in {table}: {error}") from error
        return values


def unix_timestamp(raw: float) -> float:
    # Core Data normally persists Date relative to 2001. Accept Unix seconds as
    # well so the reporter remains useful for fixtures and future migrations.
    return raw if raw > 1_200_000_000 else raw + APPLE_REFERENCE_TO_UNIX_SECONDS


def sum_live(store: ReadOnlyStore, tables: Iterable[str]) -> int:
    return sum(store.count_live(table) for table in tables)


def at_least(label: str, actual: int, expected: int) -> tuple[str, bool]:
    return (f"{label} {actual}/{expected}", actual >= expected)


def build_snapshot(
    store: ReadOnlyStore,
    preferences: dict[str, Any],
    manifest: dict[str, Any],
    detected_test_artifacts: int,
) -> dict[str, Any]:
    readiness = manifest.get("readiness", {})
    profile = manifest.get("profile", {})
    time_zone_name = str(profile.get("timeZone", "Europe/Berlin"))
    try:
        reporting_time_zone = ZoneInfo(time_zone_name)
    except ZoneInfoNotFoundError as error:
        raise RuntimeError(f"invalid Dogfood profile time zone: {time_zone_name}") from error

    human_columns = store.columns("ZHUMAN")
    human_conditions = ["ZPASSEDAWAYDATE IS NULL"] if "ZPASSEDAWAYDATE" in human_columns else []
    pet_columns = store.columns("ZPET")
    pet_conditions = ["ZPASSEDAWAYDATE IS NULL"] if "ZPASSEDAWAYDATE" in pet_columns else []
    plant_columns = store.columns("ZPLANT")
    plant_conditions = ["ZARCHIVEDAT IS NULL"] if "ZARCHIVEDAT" in plant_columns else []

    active_humans = store.count_live("ZHUMAN", human_conditions)
    active_pets = store.count_live("ZPET", pet_conditions)
    active_plants = store.count_live("ZPLANT", plant_conditions)
    care_ledger_columns = store.columns("ZCARELEDGEREVENT")
    has_canonical_care_ledger = "ZEVENTKIND" in care_ledger_columns
    care_records = (
        store.count("ZCARELEDGEREVENT", (f"ZEVENTKIND IN {CARE_EVENT_KIND_SQL}",))
        if has_canonical_care_ledger
        else sum_live(store, CARE_TABLES)
    )
    event_columns = store.columns("ZEVENT")
    plan_conditions = ["ZRECURRENCEDAYS > 0"]
    if "ZISCOMPLETED" in event_columns:
        plan_conditions.append("ZISCOMPLETED = 0")
    if "ZRELATEDENTITYTYPE" in event_columns:
        plan_conditions.append("lower(ZRELATEDENTITYTYPE) = 'pet'")
    if "ZEVENTTYPE" in event_columns:
        plan_conditions.append("ZEVENTTYPE NOT IN ('生日', '纪念日')")
    if "ZRECURRENCEENDDATE" in event_columns:
        plan_conditions.append(
            "(ZRECURRENCEENDDATE IS NULL OR "
            "ZRECURRENCEENDDATE >= (strftime('%s', 'now') - 978307200))"
        )
    care_plans = (
        store.count_live("ZEVENT", plan_conditions)
        if "ZRECURRENCEDAYS" in event_columns
        else 0
    )
    reminders = store.count("ZREMINDER")
    ledger_entries = store.count("ZCOCONUTLEDGERENTRY")
    ledger_columns = store.columns("ZCOCONUTLEDGERENTRY")
    care_reward_entries = (
        store.count(
            "ZCOCONUTLEDGERENTRY",
            (
                "ZENTRYKINDRAW = 'reward'",
                "ZSOURCERAW = 'careEvent'",
                "ZDELTA > 0",
            ),
        )
        if {"ZENTRYKINDRAW", "ZSOURCERAW", "ZDELTA"}.issubset(ledger_columns)
        else 0
    )
    starter_gift_ledger_entries = (
        store.count(
            "ZCOCONUTLEDGERENTRY",
            (
                "ZENTRYKINDRAW = 'reward'",
                "ZSOURCERAW = 'starterGift'",
                "ZDELTA > 0",
            ),
        )
        if {"ZENTRYKINDRAW", "ZSOURCERAW", "ZDELTA"}.issubset(ledger_columns)
        else 0
    )
    rewarded_care_events = (
        store.count(
            "ZCARELEDGEREVENT",
            (f"ZEVENTKIND IN {CARE_EVENT_KIND_SQL}", "ZCOCONUTDELTA > 0"),
        )
        if {"ZEVENTKIND", "ZCOCONUTDELTA"}.issubset(care_ledger_columns)
        else 0
    )
    linked_rewarded_care_events = 0
    linked_columns = {
        "ZEVENTKIND",
        "ZCOCONUTDELTA",
        "ZOCCURREDAT",
    }.issubset(care_ledger_columns) and {
        "ZENTRYKINDRAW",
        "ZSOURCERAW",
        "ZDELTA",
        "ZOCCURREDAT",
    }.issubset(ledger_columns)
    if linked_columns:
        linked_rewarded_care_events = store.query_count(
            "SELECT COUNT(*) FROM ZCARELEDGEREVENT AS care "
            f"WHERE care.ZEVENTKIND IN {CARE_EVENT_KIND_SQL} "
            "AND care.ZCOCONUTDELTA > 0 "
            "AND ("
            "SELECT COALESCE(SUM(reward.ZDELTA), 0) FROM ZCOCONUTLEDGERENTRY AS reward "
            "WHERE reward.ZENTRYKINDRAW = 'reward' "
            "AND reward.ZSOURCERAW = 'careEvent' "
            "AND reward.ZDELTA > 0 "
            "AND ABS(reward.ZOCCURREDAT - care.ZOCCURREDAT) <= 10"
            ") >= care.ZCOCONUTDELTA"
        )
    oasis_reward_unlocks = store.count("ZOASISUNLOCK")
    households = store.count("ZHOUSEHOLD")
    weight_records = sum_live(store, ("ZPETWEIGHTLOG", "ZHUMANWEIGHTLOG"))
    expense_records = sum_live(store, ("ZPETEXPENSELOG",))
    moments = sum_live(store, ("ZPETPHOTOLOG",))

    if has_canonical_care_ledger:
        care_timestamps = store.timestamps(
            "ZCARELEDGEREVENT",
            ("ZOCCURREDAT", "ZCREATEDAT"),
            (f"ZEVENTKIND IN {CARE_EVENT_KIND_SQL}",),
        )
    else:
        care_timestamps = []
        for table, candidates in CARE_TABLES.items():
            care_timestamps.extend(store.timestamps(table, candidates))
    entity_timestamps = list(care_timestamps)
    for table in ("ZHUMAN", "ZPET", "ZPLANT", "ZEVENT"):
        entity_timestamps.extend(store.timestamps(table, ("ZCREATEDAT",)))

    care_days = {
        datetime.fromtimestamp(unix_timestamp(value), tz=reporting_time_zone).date().isoformat()
        for value in care_timestamps
        if value > 0
    }
    today = datetime.now(tz=reporting_time_zone).date()
    entity_dates = [
        datetime.fromtimestamp(unix_timestamp(value), tz=reporting_time_zone).date()
        for value in entity_timestamps
        if value > 0
    ]
    earliest_date = min(entity_dates, default=today)
    history_days = max(0, (today - earliest_date).days)

    onboarding_complete = bool(preferences.get("ohana_has_onboarded", False))
    active_human_raw = str(preferences.get("currentActiveHumanId", "")).strip()
    active_human_selected = False
    if "ZID" in human_columns:
        try:
            active_human_blob = uuid.UUID(active_human_raw).bytes
        except (ValueError, AttributeError):
            active_human_blob = b""
        if active_human_blob:
            active_human_predicates = ["ZID = ?"]
            if "ZPASSEDAWAYDATE" in human_columns:
                active_human_predicates.append("ZPASSEDAWAYDATE IS NULL")
            if "ZTRASHEDAT" in human_columns:
                active_human_predicates.append("ZTRASHEDAT IS NULL")
            active_human_selected = store.query_count(
                "SELECT COUNT(*) FROM ZHUMAN WHERE "
                + " AND ".join(active_human_predicates),
                (active_human_blob,),
            ) > 0
    starter_gift_claimed = bool(preferences.get("ohanaStarterGiftClaimedV1", False))
    starter_gift_pending = bool(preferences.get("ohanaStarterGiftPendingV1", False))
    starter_gift_ceremony_seen = bool(
        preferences.get("ohanaStarterLv0CeremonySeenV1", False)
    )
    oasis_prompt_key = "ohanaStarterOasisTabPromptPendingV1"
    oasis_prompt_cleared = oasis_prompt_key in preferences and not bool(
        preferences.get(oasis_prompt_key, True)
    )
    app_language = str(preferences.get("appLanguage", "unset"))
    region = str(preferences.get("appCountry", "unset"))
    currency = str(preferences.get("appCurrency", "unset"))
    measurement_system = str(preferences.get("appMeasurementSystem", "unset"))
    # Match StarterGiftService.isOasisHomeTabUnlocked for this fresh-journey
    # persona. OasisUnlock rows are later Life Tree rewards; they do not gate
    # the Oasis tab opened by the starter-gift ceremony.
    oasis_access_unlocked = (
        starter_gift_claimed
        and starter_gift_ceremony_seen
        and not starter_gift_pending
    )

    criteria: list[tuple[str, bool]] = []
    if readiness.get("requireOnboardingComplete", True):
        criteria.append(("onboarding complete", onboarding_complete))
    if readiness.get("requireActiveHumanSelection", True):
        criteria.append(("active Human selected", active_human_selected))
    if readiness.get("requireStarterGiftClaimed", True):
        criteria.append(("starter gift claimed", starter_gift_claimed))
    if readiness.get("requireStarterGiftPendingCleared", True):
        criteria.append(("starter gift pending state cleared", not starter_gift_pending))
    if readiness.get("requireOasisAccessUnlocked", True):
        criteria.append(("Oasis access unlocked", oasis_access_unlocked))
    if readiness.get("requireOasisVisitConfirmed", True):
        criteria.append(("Oasis first-visit prompt cleared", oasis_prompt_cleared))
    if readiness.get("requireNoTestArtifacts", True):
        criteria.append(("test artifact files absent", detected_test_artifacts == 0))
    if readiness.get("requirePersonaLocale", True):
        criteria.extend(
            (
                ("profile app language", app_language == str(profile.get("appLanguage", ""))),
                ("profile region", region == str(profile.get("region", ""))),
                ("profile currency", currency == str(profile.get("currency", ""))),
                (
                    "profile measurement system",
                    measurement_system == str(profile.get("measurementSystem", "")),
                ),
            )
        )
    criteria.extend(
        (
            at_least("active Humans", active_humans, int(readiness.get("minActiveHumans", 1))),
            at_least("active Pets", active_pets, int(readiness.get("minActivePets", 1))),
            at_least("care records", care_records, int(readiness.get("minCareRecords", 1))),
            at_least(
                "recurring care plans",
                care_plans,
                int(readiness.get("minCarePlans", 1)),
            ),
            at_least("ledger entries", ledger_entries, int(readiness.get("minLedgerEntries", 1))),
            at_least(
                "starter gift ledger entries",
                starter_gift_ledger_entries,
                int(readiness.get("minStarterGiftLedgerEntries", 1)),
            ),
            at_least(
                "care reward ledger entries",
                care_reward_entries,
                int(readiness.get("minCareRewardLedgerEntries", 1)),
            ),
            at_least(
                "rewarded care events",
                rewarded_care_events,
                int(readiness.get("minRewardedCareEvents", 1)),
            ),
            at_least(
                "linked rewarded care events",
                linked_rewarded_care_events,
                int(readiness.get("minLinkedRewardedCareEvents", 1)),
            ),
        )
    )
    missing = [label for label, passed in criteria if not passed]
    ready = not missing

    day7 = manifest.get("milestones", {}).get("day7", {})
    day7_criteria = (
        at_least("history days", history_days, int(day7.get("minHistoryDays", 7))),
        at_least("care records", care_records, int(day7.get("minCareRecords", 15))),
        at_least(
            "distinct care days",
            len(care_days),
            int(day7.get("minDistinctCareDays", 5)),
        ),
        at_least("weight records", weight_records, int(day7.get("minWeightRecords", 1))),
        at_least("expense records", expense_records, int(day7.get("minExpenseRecords", 1))),
        at_least("Moments", moments, int(day7.get("minMoments", 1))),
    )
    missing_longitudinal = [label for label, passed in day7_criteria if not passed]
    longitudinal = ready and not missing_longitudinal
    day30 = manifest.get("milestones", {}).get("day30", {})
    day30_criteria = (
        at_least("history days", history_days, int(day30.get("minHistoryDays", 30))),
        at_least("care records", care_records, int(day30.get("minCareRecords", 30))),
        at_least(
            "distinct care days",
            len(care_days),
            int(day30.get("minDistinctCareDays", 14)),
        ),
        at_least("weight records", weight_records, int(day30.get("minWeightRecords", 4))),
        at_least("expense records", expense_records, int(day30.get("minExpenseRecords", 2))),
        at_least("Moments", moments, int(day30.get("minMoments", 3))),
    )
    missing_day30 = [label for label, passed in day30_criteria if not passed]
    day30_ready = ready and not missing_day30
    if day30_ready:
        stage = "mature"
    elif longitudinal:
        stage = "longitudinal"
    elif ready:
        stage = "active"
    elif onboarding_complete and active_humans > 0:
        stage = "onboarded"
    else:
        stage = "bootstrap"

    return {
        "schema": "ohana.dogfood-user-status.v1",
        "profileId": str(profile.get("id", "unknown")),
        "stage": stage,
        "ready": ready,
        "longitudinal": longitudinal,
        "day30Ready": day30_ready,
        "missingReadiness": missing,
        "missingLongitudinal": missing_longitudinal,
        "missingDay30": missing_day30,
        "preferences": {
            "onboardingComplete": onboarding_complete,
            "activeHumanSelected": active_human_selected,
            "starterGiftClaimed": starter_gift_claimed,
            "starterGiftPending": starter_gift_pending,
            "starterGiftCeremonySeen": starter_gift_ceremony_seen,
            "oasisAccessUnlocked": oasis_access_unlocked,
            "oasisFirstVisitConfirmed": oasis_prompt_cleared,
            "appLanguage": app_language,
            "region": region,
            "currency": currency,
            "measurementSystem": measurement_system,
            "timeZone": time_zone_name,
        },
        "counts": {
            "households": households,
            "activeHumans": active_humans,
            "activePets": active_pets,
            "activePlants": active_plants,
            "careRecords": care_records,
            "carePlans": care_plans,
            "reminders": reminders,
            "ledgerEntries": ledger_entries,
            "careRewardLedgerEntries": care_reward_entries,
            "starterGiftLedgerEntries": starter_gift_ledger_entries,
            "rewardedCareEvents": rewarded_care_events,
            "linkedRewardedCareEvents": linked_rewarded_care_events,
            "oasisRewardUnlocks": oasis_reward_unlocks,
            "weightRecords": weight_records,
            "expenseRecords": expense_records,
            "moments": moments,
            "distinctCareDays": len(care_days),
            "historyDays": history_days,
            "testArtifactFiles": detected_test_artifacts,
        },
    }


def print_text(snapshot: dict[str, Any]) -> None:
    preferences = snapshot["preferences"]
    counts = snapshot["counts"]
    print("Dogfood synthetic user snapshot")
    print(f"  profile: {snapshot['profileId']}")
    print(f"  stage: {snapshot['stage']}")
    print(f"  readiness: {'ready' if snapshot['ready'] else 'incomplete'}")
    print(f"  Day-7 milestone: {'ready' if snapshot['longitudinal'] else 'incomplete'}")
    print(f"  Day-30 milestone: {'ready' if snapshot['day30Ready'] else 'incomplete'}")
    print(
        "  onboarding: "
        f"complete={str(preferences['onboardingComplete']).lower()}, "
        f"active-human={str(preferences['activeHumanSelected']).lower()}, "
        f"starter-gift={str(preferences['starterGiftClaimed']).lower()}, "
        f"Oasis-access={str(preferences['oasisAccessUnlocked']).lower()}, "
        f"Oasis-visited={str(preferences['oasisFirstVisitConfirmed']).lower()}"
    )
    print(
        "  active profiles: "
        f"Humans={counts['activeHumans']}, Pets={counts['activePets']}, "
        f"Plants={counts['activePlants']}"
    )
    print(
        "  continuity: "
        f"care={counts['careRecords']}, care-days={counts['distinctCareDays']}, "
        f"plans={counts['carePlans']}, reminders={counts['reminders']}, "
        f"history-days={counts['historyDays']}"
    )
    print(
        "  supporting facts: "
        f"ledger={counts['ledgerEntries']}, care-rewards={counts['careRewardLedgerEntries']}, "
        f"starter-gift-ledger={counts['starterGiftLedgerEntries']}, "
        f"rewarded-care={counts['rewardedCareEvents']}, "
        f"linked-care={counts['linkedRewardedCareEvents']}, "
        f"Oasis-rewards={counts['oasisRewardUnlocks']}, "
        f"weight={counts['weightRecords']}, expenses={counts['expenseRecords']}, "
        f"moments={counts['moments']}, test-artifacts={counts['testArtifactFiles']}"
    )
    print(
        "  locale: "
        f"language={preferences['appLanguage']}, region={preferences['region']}, "
        f"currency={preferences['currency']}, measurement={preferences['measurementSystem']}, "
        f"time-zone={preferences['timeZone']}"
    )
    for item in snapshot["missingReadiness"]:
        print(f"    - missing: {item}")
    for item in snapshot["missingLongitudinal"]:
        print(f"    - Day-7 missing: {item}")
    for item in snapshot["missingDay30"]:
        print(f"    - Day-30 missing: {item}")


def main() -> int:
    arguments = parse_args()
    try:
        validate_gate_paths(arguments)
        manifest = load_json(arguments.manifest)
        preferences = load_preferences(arguments.preferences)
        detected_test_artifacts = test_artifact_count(arguments.data_container)
        store = ReadOnlyStore(arguments.store, verify_integrity=arguments.require_safe)
        try:
            snapshot = build_snapshot(
                store,
                preferences,
                manifest,
                detected_test_artifacts,
            )
            missing_core_tables = sorted(REQUIRED_CORE_TABLES - store.tables)
            snapshot["overlaySafety"] = {
                "safe": not missing_core_tables and detected_test_artifacts == 0,
                "missingCoreTables": missing_core_tables,
            }
        finally:
            store.close()
    except RuntimeError as error:
        print(f"Dogfood user status failed: {error}", file=sys.stderr)
        return 66

    if arguments.as_json:
        print(json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_text(snapshot)

    if arguments.require_safe and not snapshot["overlaySafety"]["safe"]:
        print("Dogfood overlay safety failed:", file=sys.stderr)
        if snapshot["counts"]["testArtifactFiles"] != 0:
            print("  - test artifact files are present", file=sys.stderr)
        missing_tables = snapshot["overlaySafety"]["missingCoreTables"]
        if missing_tables:
            print(f"  - missing core tables: {', '.join(missing_tables)}", file=sys.stderr)
        return 69
    if arguments.require_day30 and not snapshot["day30Ready"]:
        return 71
    if arguments.require_longitudinal and not snapshot["longitudinal"]:
        return 68
    if arguments.require_ready and not snapshot["ready"]:
        return 67
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

from __future__ import annotations

import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from rules import (  # noqa: E402
    IncidentProgress,
    acknowledge,
    check_in_resolution,
    clamp_pause_until,
    evaluate,
    follow_up_may_submit,
    guard_occurrence,
    next_evaluation_time,
)


class GuardianRuleTests(unittest.TestCase):
    def test_delayed_initial_alert_suppresses_back_to_back_follow_up(self):
        queued = datetime(2026, 7, 22, 21, tzinfo=timezone.utc)
        self.assertFalse(follow_up_may_submit(None, queued))
        self.assertFalse(follow_up_may_submit(queued + timedelta(seconds=1), queued))
        self.assertTrue(follow_up_may_submit(queued - timedelta(days=1), queued))

    def test_second_miss_alerts_third_follows_up_and_later_days_are_quiet(self):
        progress = IncidentProgress()
        actions = []
        for day in range(1, 5):
            result = evaluate(
                progress,
                eligible=True,
                scheduled=True,
                paused=False,
                checked_in=False,
                day_key=f"2026-07-{day:02d}",
            )
            progress = result.progress
            actions.append(result.action)
        self.assertEqual(actions, ["none", "initial", "follow_up", "none"])
        self.assertEqual(progress.consecutive_misses, 4)

    def test_unscheduled_days_neither_advance_nor_reset(self):
        first = evaluate(
            IncidentProgress(), eligible=True, scheduled=True, paused=False,
            checked_in=False, day_key="2026-07-20",
        )
        skipped = evaluate(
            first.progress, eligible=True, scheduled=False, paused=False,
            checked_in=False, day_key="2026-07-21",
        )
        second = evaluate(
            skipped.progress, eligible=True, scheduled=True, paused=False,
            checked_in=False, day_key="2026-07-25",
        )
        self.assertEqual(skipped.progress, first.progress)
        self.assertEqual(second.action, "initial")

    def test_pause_and_structural_stop_end_the_sequence(self):
        previous = IncidentProgress(consecutive_misses=1)
        paused = evaluate(
            previous, eligible=True, scheduled=True, paused=True,
            checked_in=False, day_key="2026-07-21",
        )
        stopped = evaluate(
            previous, eligible=False, scheduled=True, paused=False,
            checked_in=False, day_key="2026-07-21",
        )
        self.assertEqual(paused.progress, IncidentProgress())
        self.assertEqual(stopped.progress, IncidentProgress())

    def test_check_in_recovers_only_after_an_alert_was_queued(self):
        open_progress = IncidentProgress(
            consecutive_misses=2,
            incident_open=True,
            initial_submitted=True,
        )
        recovered = evaluate(
            open_progress, eligible=True, scheduled=True, paused=False,
            checked_in=True, day_key="2026-07-22",
        )
        ordinary = evaluate(
            IncidentProgress(consecutive_misses=1), eligible=True, scheduled=True,
            paused=False, checked_in=True, day_key="2026-07-22",
        )
        self.assertEqual(recovered.action, "recovery")
        self.assertEqual(ordinary.action, "reset")

    def test_guardian_acknowledgement_resets_without_a_check_in(self):
        result = acknowledge(IncidentProgress(
            consecutive_misses=2,
            incident_open=True,
            initial_submitted=True,
        ))
        self.assertEqual(result.action, "reset")
        self.assertEqual(result.progress, IncidentProgress())

    def test_check_in_cancels_queued_alert_but_recovers_submitted_alert(self):
        self.assertEqual(
            check_in_resolution("monitoring", has_submitted_attempt=False),
            "closed",
        )
        self.assertEqual(
            check_in_resolution("monitoring", has_submitted_attempt=True),
            "recovered",
        )
        self.assertEqual(
            check_in_resolution("acknowledged", has_submitted_attempt=True),
            "none",
        )

    def test_spring_gap_uses_next_real_local_minute(self):
        occurrence = guard_occurrence(
            datetime(2026, 3, 29, 12, tzinfo=timezone.utc),
            time_zone_identifier="Europe/Berlin",
            weekdays=range(1, 8),
            deadline_hour=2,
            deadline_minute=30,
            grace_period_minutes=60,
        )
        self.assertEqual(occurrence.day_key, "2026-03-29")
        self.assertEqual(occurrence.deadline.hour, 3)
        self.assertEqual(
            occurrence.evaluation_time.astimezone(timezone.utc)
            - occurrence.deadline.astimezone(timezone.utc),
            timedelta(hours=1),
        )

    def test_autumn_overlap_uses_first_occurrence(self):
        occurrence = guard_occurrence(
            datetime(2026, 10, 25, 12, tzinfo=timezone.utc),
            time_zone_identifier="Europe/Berlin",
            weekdays=range(1, 8),
            deadline_hour=2,
            deadline_minute=30,
            grace_period_minutes=60,
        )
        self.assertEqual(
            occurrence.deadline.astimezone(timezone.utc),
            datetime(2026, 10, 25, 0, 30, tzinfo=timezone.utc),
        )

    def test_same_instant_has_different_guard_day_after_timezone_change(self):
        instant = datetime(2026, 7, 22, 22, 30, tzinfo=timezone.utc)
        berlin = guard_occurrence(
            instant, time_zone_identifier="Europe/Berlin", weekdays=range(1, 8),
            deadline_hour=20, deadline_minute=0, grace_period_minutes=60,
        )
        new_york = guard_occurrence(
            instant, time_zone_identifier="America/New_York", weekdays=range(1, 8),
            deadline_hour=20, deadline_minute=0, grace_period_minutes=60,
        )
        self.assertEqual(berlin.day_key, "2026-07-23")
        self.assertEqual(new_york.day_key, "2026-07-22")

    def test_next_evaluation_skips_unselected_days(self):
        # Tuesday, while only Thursday (Apple weekday 5) is selected.
        now = datetime(2026, 7, 21, 12, tzinfo=timezone.utc)
        due = next_evaluation_time(
            now,
            time_zone_identifier="Europe/Berlin",
            weekdays={5},
            deadline_hour=20,
            deadline_minute=0,
            grace_period_minutes=60,
        )
        self.assertEqual(due.astimezone(ZoneInfo("Europe/Berlin")).date().isoformat(), "2026-07-23")

    def test_pause_is_clamped_to_thirty_days(self):
        now = datetime(2026, 7, 1, tzinfo=timezone.utc)
        self.assertEqual(clamp_pause_until(now + timedelta(days=90), now), now + timedelta(days=30))


class PrivacyContractTests(unittest.TestCase):
    def test_backend_has_no_sms_or_external_contact_channel(self):
        source = "\n".join(
            path.read_text(encoding="utf-8")
            for path in (ROOT / "src").glob("*.py")
        ).lower()
        for blocked in ("phone_number", "send_sms", "email_address", "ses.send"):
            self.assertNotIn(blocked, source)

    def test_push_copy_is_non_diagnostic_and_does_not_claim_delivery(self):
        source = (ROOT / "src" / "push_worker.py").read_text(encoding="utf-8").lower()
        for blocked in ("death detection", "emergency service", "delivered to guardian"):
            self.assertNotIn(blocked, source)
        self.assertIn("no check-in has reached ohana", source)


class BackendSafetyContractTests(unittest.TestCase):
    def test_every_push_kind_revalidates_the_family_product(self):
        worker = (ROOT / "src" / "push_worker.py").read_text(encoding="utf-8")
        evaluator = (ROOT / "src" / "evaluator.py").read_text(encoding="utf-8")
        self.assertIn('value.get("product_id") == os.environ["FAMILY_PRODUCT_ID"]', worker)
        self.assertIn('value.get("product_id") == os.environ["FAMILY_PRODUCT_ID"]', evaluator)
        self.assertLess(
            worker.index("if not _active_entitlement(owner_sub, now):"),
            worker.index('if kind in {"initial", "follow_up"}:'),
        )

    def test_device_registration_aggregates_all_installations(self):
        source = (ROOT / "src" / "api.py").read_text(encoding="utf-8")
        registration = source[source.index("def register_device"):source.index("def _set_guardian_reachability")]
        self.assertIn('query_partition(account_pk(subject), "DEVICE#", limit=20)', registration)
        self.assertIn("has_reachable_device", registration)
        self.assertNotIn(
            '"active" if payload.get("notifications_authorized") is True',
            registration,
        )

    def test_relationship_revocation_is_atomic_and_once_only(self):
        source = (ROOT / "src" / "api.py").read_text(encoding="utf-8")
        revocation = source[source.index("def revoke_relationship"):source.index("def _guardian_incident_access")]
        self.assertIn('"SK": "REVOCATION"', revocation)
        self.assertIn("DDB.transact_write_items", revocation)
        self.assertIn('ConditionExpression": "attribute_not_exists(PK)"', revocation)
        self.assertIn("guardian_count = guardian_count - :one", revocation)


if __name__ == "__main__":
    unittest.main()

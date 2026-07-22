"""Pure guard-day and incident rules shared by Lambda handlers."""

from __future__ import annotations

from dataclasses import dataclass, replace
from datetime import date, datetime, time, timedelta, timezone
from typing import Iterable, Optional
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

INITIAL_ALERT_MISS_COUNT = 2
FOLLOW_UP_MISS_COUNT = 3
MAXIMUM_PAUSE_DAYS = 30
MINIMUM_GRACE_MINUTES = 15
MAXIMUM_GRACE_MINUTES = 180
OPEN_INCIDENT_STATUSES = {"monitoring", "initialSubmitted", "followUpSubmitted"}


@dataclass(frozen=True)
class GuardOccurrence:
    day_key: str
    weekday: int
    scheduled: bool
    deadline: datetime
    evaluation_time: datetime
    paused: bool


@dataclass(frozen=True)
class IncidentProgress:
    consecutive_misses: int = 0
    last_guard_day_key: Optional[str] = None
    incident_open: bool = False
    initial_submitted: bool = False
    follow_up_submitted: bool = False
    acknowledged: bool = False


@dataclass(frozen=True)
class Evaluation:
    progress: IncidentProgress
    action: str = "none"


def _valid_local_datetime(local_naive: datetime, zone: ZoneInfo) -> datetime:
    """Return the first real local minute at/after a requested wall time.

    `fold=0` selects the first instant during an autumn overlap. A round trip
    detects nonexistent spring-gap times and advances them like Calendar's
    `nextTime` matching policy.
    """

    candidate = local_naive
    for _ in range(181):
        aware = candidate.replace(tzinfo=zone, fold=0)
        round_trip = aware.astimezone(timezone.utc).astimezone(zone).replace(tzinfo=None)
        if round_trip == candidate:
            return aware
        candidate += timedelta(minutes=1)
    raise ValueError("deadline could not be resolved in its time zone")


def guard_occurrence(
    instant: datetime,
    *,
    time_zone_identifier: str,
    weekdays: Iterable[int],
    deadline_hour: int,
    deadline_minute: int,
    grace_period_minutes: int,
    pause_until: Optional[datetime] = None,
) -> GuardOccurrence:
    if instant.tzinfo is None:
        raise ValueError("instant must be timezone-aware")
    try:
        zone = ZoneInfo(time_zone_identifier)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("unknown time zone") from exc

    local = instant.astimezone(zone)
    hour = min(max(int(deadline_hour), 0), 23)
    minute = min(max(int(deadline_minute), 0), 59)
    grace = min(max(int(grace_period_minutes), MINIMUM_GRACE_MINUTES), MAXIMUM_GRACE_MINUTES)
    deadline = _valid_local_datetime(
        datetime.combine(local.date(), time(hour=hour, minute=minute)),
        zone,
    )
    evaluation_time = (deadline.astimezone(timezone.utc) + timedelta(minutes=grace)).astimezone(zone)
    # Python: Monday=0; Apple Calendar: Sunday=1 ... Saturday=7.
    apple_weekday = ((local.weekday() + 1) % 7) + 1
    selected = {int(value) for value in weekdays if 1 <= int(value) <= 7}
    normalized_pause = pause_until
    if normalized_pause is not None and normalized_pause.tzinfo is None:
        raise ValueError("pause_until must be timezone-aware")
    return GuardOccurrence(
        day_key=local.date().isoformat(),
        weekday=apple_weekday,
        scheduled=apple_weekday in selected,
        deadline=deadline,
        evaluation_time=evaluation_time,
        paused=normalized_pause is not None and instant < normalized_pause,
    )


def next_evaluation_time(
    now: datetime,
    *,
    time_zone_identifier: str,
    weekdays: Iterable[int],
    deadline_hour: int,
    deadline_minute: int,
    grace_period_minutes: int,
    pause_until: Optional[datetime] = None,
) -> datetime:
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    try:
        zone = ZoneInfo(time_zone_identifier)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("unknown time zone") from exc
    anchor = max(now, pause_until) if pause_until else now
    local_date = anchor.astimezone(zone).date()
    selected = {int(value) for value in weekdays if 1 <= int(value) <= 7}
    if not selected:
        raise ValueError("at least one weekday is required")

    for day_offset in range(15):
        candidate_date = local_date + timedelta(days=day_offset)
        midday = datetime.combine(candidate_date, time(hour=12), tzinfo=zone)
        occurrence = guard_occurrence(
            midday,
            time_zone_identifier=time_zone_identifier,
            weekdays=selected,
            deadline_hour=deadline_hour,
            deadline_minute=deadline_minute,
            grace_period_minutes=grace_period_minutes,
            pause_until=pause_until,
        )
        if occurrence.scheduled and occurrence.evaluation_time > anchor:
            return occurrence.evaluation_time.astimezone(timezone.utc)
    raise ValueError("no future guard occurrence")


def clamp_pause_until(requested: datetime, now: datetime) -> datetime:
    if requested.tzinfo is None or now.tzinfo is None:
        raise ValueError("pause dates must be timezone-aware")
    return min(max(requested, now), now + timedelta(days=MAXIMUM_PAUSE_DAYS))


def evaluate(
    previous: IncidentProgress,
    *,
    eligible: bool,
    scheduled: bool,
    paused: bool,
    checked_in: bool,
    day_key: str,
) -> Evaluation:
    if not eligible or paused:
        return Evaluation(IncidentProgress(), "reset")
    if not scheduled:
        return Evaluation(previous)
    if checked_in:
        should_recover = (
            previous.incident_open
            and previous.initial_submitted
            and not previous.acknowledged
        )
        return Evaluation(IncidentProgress(), "recovery" if should_recover else "reset")

    progress = replace(
        previous,
        consecutive_misses=max(0, previous.consecutive_misses) + 1,
        last_guard_day_key=day_key,
    )
    if progress.consecutive_misses == INITIAL_ALERT_MISS_COUNT and not progress.initial_submitted:
        return Evaluation(
            replace(progress, incident_open=True, initial_submitted=True),
            "initial",
        )
    if (
        progress.consecutive_misses == FOLLOW_UP_MISS_COUNT
        and progress.incident_open
        and progress.initial_submitted
        and not progress.follow_up_submitted
        and not progress.acknowledged
    ):
        return Evaluation(replace(progress, follow_up_submitted=True), "follow_up")
    return Evaluation(progress)


def acknowledge(previous: IncidentProgress) -> Evaluation:
    if not previous.incident_open or not previous.initial_submitted:
        return Evaluation(previous)
    return Evaluation(IncidentProgress(), "reset")


def check_in_resolution(incident_status: str, *, has_submitted_attempt: bool) -> str:
    """Resolve a check-in racing a queued or submitted notification.

    A notification that has only been queued must disappear without a recovery
    message. Once SNS accepted at least one per-device attempt, the owner can
    only truthfully close the incident by sending recovery to those recipients.
    """

    if incident_status not in OPEN_INCIDENT_STATUSES:
        return "none"
    return "recovered" if has_submitted_attempt else "closed"


def follow_up_may_submit(
    initial_submitted_at: Optional[datetime],
    follow_up_queued_at: Optional[datetime],
) -> bool:
    """Allow a follow-up only when the first alert preceded its enqueue."""

    if initial_submitted_at is None or follow_up_queued_at is None:
        return False
    if initial_submitted_at.tzinfo is None or follow_up_queued_at.tzinfo is None:
        raise ValueError("notification dates must be timezone-aware")
    return initial_submitted_at <= follow_up_queued_at

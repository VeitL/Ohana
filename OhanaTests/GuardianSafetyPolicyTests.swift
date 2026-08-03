import Foundation
import SwiftData
import Testing
@testable import Ohana

@Suite("Family guardian safety rules")
struct GuardianSafetyPolicyTests {
    @Test func firstMissQueuesInitialSecondQueuesOnlyFollowUpAndLaterMissesAreQuiet() {
        let day1 = GuardianSafetyEvaluationPolicy.evaluate(
            previous: .empty,
            occurrence: missed("2026-07-20")
        )
        let day2 = GuardianSafetyEvaluationPolicy.evaluate(
            previous: day1.progress,
            occurrence: missed("2026-07-21")
        )
        let day3 = GuardianSafetyEvaluationPolicy.evaluate(
            previous: day2.progress,
            occurrence: missed("2026-07-22")
        )
        let day4 = GuardianSafetyEvaluationPolicy.evaluate(
            previous: day3.progress,
            occurrence: missed("2026-07-23")
        )

        #expect(day1.action == .queueInitialAlert(consecutiveMisses: 1))
        #expect(day1.progress.consecutiveMisses == 1)
        #expect(day1.progress.isIncidentOpen)
        #expect(day2.action == .queueFollowUp(consecutiveMisses: 2))
        #expect(day3.action == .none)
        #expect(day4.action == .none)
        #expect(day4.progress.consecutiveMisses == 4)
    }

    @Test func unscheduledDayPreservesSequenceWithoutAdvancingIt() {
        let firstMiss = GuardianSafetyEvaluationPolicy.evaluate(
            previous: .empty,
            occurrence: missed("2026-07-20")
        )
        let unscheduled = GuardianSafetyEvaluationPolicy.evaluate(
            previous: firstMiss.progress,
            occurrence: GuardianSafetyOccurrenceContext(
                dayKey: "2026-07-21",
                isScheduledWeekday: false
            )
        )
        let nextGuardDay = GuardianSafetyEvaluationPolicy.evaluate(
            previous: unscheduled.progress,
            occurrence: missed("2026-07-25")
        )

        #expect(unscheduled.progress == firstMiss.progress)
        #expect(unscheduled.action == .none)
        #expect(nextGuardDay.action == .queueFollowUp(consecutiveMisses: 2))
    }

    @Test func legacySilentMissProgressStillQueuesInitialThenOneFollowUp() {
        let initial = GuardianSafetyEvaluationPolicy.evaluate(
            previous: GuardianSafetyIncidentProgress(
                consecutiveMisses: 1,
                lastGuardDayKey: "2026-07-20"
            ),
            occurrence: missed("2026-07-21")
        )
        let followUp = GuardianSafetyEvaluationPolicy.evaluate(
            previous: initial.progress,
            occurrence: missed("2026-07-22")
        )
        let later = GuardianSafetyEvaluationPolicy.evaluate(
            previous: followUp.progress,
            occurrence: missed("2026-07-23")
        )

        #expect(initial.action == .queueInitialAlert(consecutiveMisses: 2))
        #expect(followUp.action == .queueFollowUp(consecutiveMisses: 3))
        #expect(later.action == .none)
    }

    @Test func ownerCheckInQueuesRecoveryOnlyForAnOpenAlertedIncident() {
        let open = GuardianSafetyIncidentProgress(
            consecutiveMisses: 1,
            lastGuardDayKey: "2026-07-20",
            isIncidentOpen: true,
            didSubmitInitial: true
        )
        let recovered = GuardianSafetyEvaluationPolicy.evaluate(
            previous: open,
            occurrence: GuardianSafetyOccurrenceContext(
                dayKey: "2026-07-22",
                receivedOwnerCheckInByDeadline: true
            )
        )
        let ordinary = GuardianSafetyEvaluationPolicy.evaluate(
            previous: GuardianSafetyIncidentProgress(consecutiveMisses: 1),
            occurrence: GuardianSafetyOccurrenceContext(
                dayKey: "2026-07-22",
                receivedOwnerCheckInByDeadline: true
            )
        )

        #expect(recovered.action == .queueRecovery)
        #expect(recovered.progress == .empty)
        #expect(ordinary.action == .resetWithoutNotification)
    }

    @Test func guardianAcknowledgementStopsFollowUpWithoutCreatingACheckInState() {
        let open = GuardianSafetyIncidentProgress(
            consecutiveMisses: 1,
            lastGuardDayKey: "2026-07-20",
            isIncidentOpen: true,
            didSubmitInitial: true
        )
        let acknowledged = GuardianSafetyEvaluationPolicy.acknowledge(open)
        let nextMiss = GuardianSafetyEvaluationPolicy.evaluate(
            previous: acknowledged.progress,
            occurrence: missed("2026-07-22")
        )

        #expect(acknowledged.action == .resetWithoutNotification)
        #expect(acknowledged.progress == .empty)
        #expect(nextMiss.progress.consecutiveMisses == 1)
        #expect(nextMiss.action == .queueInitialAlert(consecutiveMisses: 1))
    }

    @Test func pauseAndStructuralIneligibilityResetButUnscheduledDaysDoNot() {
        let previous = GuardianSafetyIncidentProgress(consecutiveMisses: 1)
        let paused = GuardianSafetyEvaluationPolicy.evaluate(
            previous: previous,
            occurrence: GuardianSafetyOccurrenceContext(dayKey: "2026-07-21", isPaused: true)
        )
        let standardMode = GuardianSafetyEvaluationPolicy.evaluate(
            previous: previous,
            occurrence: GuardianSafetyOccurrenceContext(
                dayKey: "2026-07-21",
                isZenParticipationActive: false
            )
        )

        #expect(paused.progress == .empty)
        #expect(paused.action == .resetWithoutNotification)
        #expect(standardMode.progress == .empty)
    }

    @Test func pauseIsClampedToThirtyDays() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let requested = now.addingTimeInterval(90 * 86400)
        let clamped = GuardianSafetyEvaluationPolicy.clampedPauseUntil(
            requested: requested,
            now: now,
            calendar: utcCalendar
        )

        #expect(clamped == utcCalendar.date(byAdding: .day, value: 30, to: now))
    }

    @Test func scheduleUsesNamedTimeZoneAndDoesNotRewriteTheInstant() throws {
        let instant = try isoDate("2026-07-22T22:30:00Z")
        let berlin = try #require(GuardianGuardDaySchedulePolicy.occurrence(
            containing: instant,
            schedule: GuardianGuardDaySchedule(timeZoneIdentifier: "Europe/Berlin")
        ))
        let newYork = try #require(GuardianGuardDaySchedulePolicy.occurrence(
            containing: instant,
            schedule: GuardianGuardDaySchedule(timeZoneIdentifier: "America/New_York")
        ))

        #expect(berlin.dayKey == "2026-07-23")
        #expect(newYork.dayKey == "2026-07-22")
        #expect(berlin.deadline != newYork.deadline)
    }

    @Test func springDSTGapMovesDeadlineForwardWithinTheSameGuardDay() throws {
        let instant = try isoDate("2026-03-29T10:00:00Z")
        let occurrence = try #require(GuardianGuardDaySchedulePolicy.occurrence(
            containing: instant,
            schedule: GuardianGuardDaySchedule(
                deadlineHour: 2,
                deadlineMinute: 30,
                gracePeriodMinutes: 60,
                timeZoneIdentifier: "Europe/Berlin"
            )
        ))
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))

        #expect(occurrence.dayKey == "2026-03-29")
        #expect(berlin.component(.hour, from: occurrence.deadline) == 3)
        #expect(occurrence.evaluationTime.timeIntervalSince(occurrence.deadline) == 3600)
    }

    @Test func fallDSTOverlapUsesTheFirstMatchingDeadline() throws {
        let instant = try isoDate("2026-10-25T12:00:00Z")
        let occurrence = try #require(GuardianGuardDaySchedulePolicy.occurrence(
            containing: instant,
            schedule: GuardianGuardDaySchedule(
                deadlineHour: 2,
                deadlineMinute: 30,
                timeZoneIdentifier: "Europe/Berlin"
            )
        ))
        let expectedDeadline = try isoDate("2026-10-25T00:30:00Z")

        #expect(occurrence.deadline == expectedDeadline)
    }

    @Test func selectedWeekdaysPauseAndGraceAreResolvedBeforeEvaluation() throws {
        let instant = try isoDate("2026-07-21T18:30:00Z")
        let schedule = GuardianGuardDaySchedule(
            weekdays: [2],
            deadlineHour: 20,
            deadlineMinute: 0,
            gracePeriodMinutes: 60,
            timeZoneIdentifier: "Europe/Berlin"
        )
        let occurrence = try #require(GuardianGuardDaySchedulePolicy.occurrence(
            containing: instant,
            schedule: schedule,
            pauseUntil: instant.addingTimeInterval(60)
        ))

        #expect(occurrence.weekday == 3)
        #expect(!occurrence.isScheduledWeekday)
        #expect(occurrence.isPaused)
        #expect(occurrence.receivedByEvaluationTime(occurrence.evaluationTime.addingTimeInterval(-1)))
        #expect(!occurrence.receivedByEvaluationTime(occurrence.evaluationTime.addingTimeInterval(1)))
    }

    private func missed(_ dayKey: String) -> GuardianSafetyOccurrenceContext {
        GuardianSafetyOccurrenceContext(dayKey: dayKey)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func isoDate(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }
}

@MainActor
@Suite("Guardian safety V96 and Presence outbox", .serialized)
struct GuardianSafetyPersistenceTests {
    @Test func v96AddsOnlyGuardianProjectionsAndOutboxAfterV95() {
        let v95 = Set(ArkSchemaV95.models.map { String(describing: $0) })
        let v96 = Set(ArkSchemaV96.models.map { String(describing: $0) })

        #expect(v96.subtracting(v95) == [
            String(describing: GuardianSafetyPolicyProjection.self),
            String(describing: GuardianRelationshipProjection.self),
            String(describing: GuardianIncidentProjection.self),
            String(describing: GuardianSafetySyncOutbox.self)
        ])
        #expect(v95.subtracting(v96).isEmpty)
    }

    @Test func ownerCheckInAndUndoStageMinimalDistinctOutboxEventsInThePresenceTransaction() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        context.insert(GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        ))
        try context.save()

        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: TestOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: TestPresenceRewardAwarder(),
            guardianSafetyOutbox: LiveGuardianSafetyOutboxStager(),
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        let now = date(2026, 7, 22)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)
        let result = try service.checkInOwner(source: .card, now: now)
        _ = try service.undoTodayCheckIn(
            subject: PresenceSubjectRef(kind: .human, id: owner.id),
            now: now.addingTimeInterval(60)
        )

        let outbox = try context.fetch(
            FetchDescriptor<GuardianSafetySyncOutbox>(sortBy: [SortDescriptor(\.occurredAt)])
        )
        #expect(result.didCreateCheckIn)
        #expect(outbox.map(\.eventKind) == [.ownerCheckIn, .ownerUndo])
        #expect(outbox.allSatisfy { $0.ownerHumanId == owner.id })
        #expect(outbox.allSatisfy { $0.payloadJSON == nil })
        #expect(outbox.first?.dayKey == "2026-07-22")
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 1)
    }

    @Test func enablingGuardianAfterTodaysExplicitConfirmationStagesThatExistingFactIdempotently() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: TestOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: TestPresenceRewardAwarder(),
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { timeZone }
        )
        let now = date(2026, 7, 22)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)
        let result = try service.checkInOwner(source: .card, now: now)
        #expect(result.didCreateCheckIn)
        #expect(try context.fetchCount(FetchDescriptor<GuardianSafetySyncOutbox>()) == 0)

        context.insert(GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-enabled-after-check-in",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        ))
        // GuardianSafetyCoordinator saves the authoritative remote projection
        // before querying it to seed the reliable local outbox.
        try context.save()
        let stager = LiveGuardianSafetyOutboxStager()
        #expect(try stager.stageExistingExplicitOwnerCheckInForCurrentDay(
            ownerHumanId: owner.id,
            now: now,
            timeZone: timeZone,
            context: context
        ))
        try context.save()
        #expect(try stager.stageExistingExplicitOwnerCheckInForCurrentDay(
            ownerHumanId: owner.id,
            now: now.addingTimeInterval(60),
            timeZone: timeZone,
            context: context
        ) == false)
        try context.save()

        let outbox = try context.fetch(FetchDescriptor<GuardianSafetySyncOutbox>())
        #expect(outbox.count == 1)
        #expect(outbox.first?.eventKind == .ownerCheckIn)
        #expect(outbox.first?.dayKey == "2026-07-22")
    }

    @Test func enablingGuardianDoesNotPromoteALegacyAutomaticFactIntoSafetyConfirmation() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let now = date(2026, 7, 22)
        context.insert(owner)
        context.insert(GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        ))
        context.insert(PresenceCheckIn(
            uniqueKey: "legacy-auto-owner",
            subject: PresenceSubjectRef(kind: .human, id: owner.id),
            ownerHumanId: owner.id,
            isOwner: true,
            dayKey: "2026-07-22",
            timeZoneIdentifier: "GMT",
            checkedInAt: now,
            source: .automaticForeground,
            operatorHumanId: owner.id
        ))
        try context.save()

        let didFindExplicitFact = try LiveGuardianSafetyOutboxStager()
            .stageExistingExplicitOwnerCheckInForCurrentDay(
                ownerHumanId: owner.id,
                now: now,
                timeZone: try #require(TimeZone(secondsFromGMT: 0)),
                context: context
            )

        #expect(!didFindExplicitFact)
        #expect(try context.fetchCount(FetchDescriptor<GuardianSafetySyncOutbox>()) == 0)
    }

    @Test func guardianEnableMapsAnExplicitFactIntoThePolicyTimeZoneGuardDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let operationTimeZone = try #require(TimeZone(secondsFromGMT: 0))
        let guardianTimeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = operationTimeZone
        let checkedInAt = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 22,
            hour: 23,
            minute: 30
        )))
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: TestOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: TestPresenceRewardAwarder(),
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { operationTimeZone }
        )
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: checkedInAt)
        _ = try service.checkInOwner(source: .notificationAction, now: checkedInAt)
        let checkIn = try #require(context.fetch(FetchDescriptor<PresenceCheckIn>()).first)
        #expect(checkIn.dayKey == "2026-07-22")

        context.insert(GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-berlin",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring,
            timeZoneIdentifier: guardianTimeZone.identifier
        ))
        try context.save()

        #expect(try LiveGuardianSafetyOutboxStager()
            .stageExistingExplicitOwnerCheckInForCurrentDay(
                ownerHumanId: owner.id,
                now: checkedInAt.addingTimeInterval(60),
                timeZone: guardianTimeZone,
                context: context
            ))
        try context.save()

        let event = try #require(context.fetch(FetchDescriptor<GuardianSafetySyncOutbox>()).first)
        #expect(event.dayKey == "2026-07-23")
        #expect(event.timeZoneIdentifier == guardianTimeZone.identifier)
    }

    @Test func nonOwnerAndRetrospectiveWritesNeverStageSafetySignals() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        owner.createdAt = date(2026, 7, 1)
        let pet = Pet(name: "Pet", species: "cat")
        pet.createdAt = date(2026, 7, 1)
        context.insert(owner)
        context.insert(pet)
        context.insert(GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        ))
        try context.save()
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: TestOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: TestPresenceRewardAwarder(),
            guardianSafetyOutbox: LiveGuardianSafetyOutboxStager(),
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        try service.startParticipation(
            ownerHumanId: owner.id,
            source: .settings,
            now: date(2026, 7, 20)
        )

        _ = try service.checkIn(
            subject: PresenceSubjectRef(kind: .pet, id: pet.id),
            now: date(2026, 7, 22)
        )
        _ = try service.recordRetrospectiveStatus(
            subject: PresenceSubjectRef(kind: .human, id: owner.id),
            dayKey: "2026-07-21",
            status: .score7,
            now: date(2026, 7, 22)
        )

        #expect(try context.fetchCount(FetchDescriptor<GuardianSafetySyncOutbox>()) == 0)
    }

    @Test func endingZenStagesStopAndDisablesTheLocalPolicyAtomically() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let policy = GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        )
        context.insert(owner)
        context.insert(policy)
        try context.save()
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: TestOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: TestPresenceRewardAwarder(),
            guardianSafetyOutbox: LiveGuardianSafetyOutboxStager(),
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        let now = date(2026, 7, 22)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        _ = try service.endParticipation(reason: .leftZenMode, now: now.addingTimeInterval(60))

        let event = try #require(context.fetch(FetchDescriptor<GuardianSafetySyncOutbox>()).first)
        #expect(event.eventKind == .monitoringStopped)
        #expect(event.stopReason == .leftZenMode)
        #expect(!policy.isEnabled)
        #expect(policy.status == .stopped)
    }

    @Test func memorializingTheOwnerStopsLocalPolicyWithoutSoloOutbox() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let policy = GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        )
        context.insert(owner)
        context.insert(policy)
        try context.save()

        let result = MemberLifecycleCommandService.markHumanPassedAway(
            owner,
            date: date(2026, 7, 22),
            context: context
        )

        #expect(result.didPersist)
        #expect(owner.passedAwayDate != nil)
        #expect(try context.fetchCount(FetchDescriptor<GuardianSafetySyncOutbox>()) == 0)
        #expect(!policy.isEnabled)
        #expect(policy.status == .stopped)
    }

    @Test func physicalOwnerDeletionRemovesRemoteProjectionsWithoutSoloOutbox() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        context.insert(GuardianSafetyPolicyProjection(
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            isEnabled: true,
            status: .monitoring
        ))
        context.insert(GuardianRelationshipProjection(
            serverRelationshipId: "owned-relationship",
            ownerHumanId: owner.id,
            displayName: "Guardian 1",
            status: .accepted
        ))
        context.insert(GuardianRelationshipProjection(
            serverRelationshipId: "guardian-role",
            displayName: "Protected person",
            status: .accepted,
            currentUserIsGuardian: true
        ))
        context.insert(GuardianIncidentProjection(
            serverIncidentId: "incident-1",
            serverPolicyId: "policy-1",
            ownerHumanId: owner.id,
            status: .initialSubmitted,
            lastGuardDayKey: "2026-07-22",
            consecutiveMisses: 2
        ))
        try context.save()

        _ = PhysicalDeletionService.deleteHuman(owner, context: context)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Human>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<GuardianSafetyPolicyProjection>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<GuardianIncidentProjection>()) == 0)
        let relationships = try context.fetch(FetchDescriptor<GuardianRelationshipProjection>())
        #expect(relationships.map(\.serverRelationshipId) == ["guardian-role"])
        #expect(try context.fetchCount(FetchDescriptor<GuardianSafetySyncOutbox>()) == 0)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV96.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}

private nonisolated struct TestOwnerSelection: PresenceOwnerSelecting {
    let ownerHumanId: UUID?
}

@MainActor
private final class TestPresenceRewardAwarder: PresenceRewardAwarding {
    func stage(
        _ request: PresenceRewardRequest,
        owner _: Human,
        context _: ModelContext,
        now _: Date
    ) throws -> PresenceStagedReward {
        PresenceStagedReward(
            request: request,
            awardedAmount: request.requestedAmount,
            walletTransactionKey: "test:\(request.receiptKey)",
            budgetResult: nil
        )
    }

    func didCommit(_: [PresenceStagedReward], owner _: Human, context _: ModelContext, now _: Date) {}
    func didRollback(context _: ModelContext) {}
}

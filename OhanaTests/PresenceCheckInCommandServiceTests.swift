import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct PresenceCheckInCommandServiceTests {
    @Test func v93RegistersOnlyPresenceModelsAfterV92() {
        let v92 = Set(ArkSchemaV92.models.map { String(describing: $0) })
        let v93 = Set(ArkSchemaV93.models.map { String(describing: $0) })

        #expect(v93.subtracting(v92) == [
            String(describing: PresenceCheckIn.self),
            String(describing: PresenceParticipationPeriod.self),
            String(describing: PresenceRewardReceipt.self),
            String(describing: SafetyContact.self)
        ])
        #expect(v92.subtracting(v93).isEmpty)
        #expect(ObjectIdentifier(ArkMigrationPlan.schemas.last!) == ObjectIdentifier(ArkSchemaV96.self))
    }

    @Test func ownerAutoCheckInCheckAllAndStatusRewardsAreIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let pet = Pet(name: "Miso", species: "cat")
        let plant = Plant(name: "Fern")
        context.insert(owner)
        context.insert(pet)
        context.insert(plant)
        try context.save()

        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)
        let now = date(2026, 7, 18)
        try service.startParticipation(ownerHumanId: owner.id, source: .onboarding, now: now)

        let first = try service.autoCheckInOwner(now: now)
        let replay = try service.autoCheckInOwner(now: now.addingTimeInterval(30))
        let all = try service.checkInAll(now: now.addingTimeInterval(60))
        let firstStatus = try service.updateTodayStatus(
            subject: .init(kind: .pet, id: pet.id),
            status: .score10,
            now: now.addingTimeInterval(90)
        )
        let changedStatus = try service.updateTodayStatus(
            subject: .init(kind: .pet, id: pet.id),
            status: .score1,
            now: now.addingTimeInterval(120)
        )
        let clearedStatus = try service.updateTodayStatus(
            subject: .init(kind: .pet, id: pet.id),
            status: nil,
            now: now.addingTimeInterval(150)
        )

        #expect(first.didCreateCheckIn)
        #expect(first.awardedCoconuts == 1)
        #expect(!replay.didCreateCheckIn)
        #expect(replay.awardedCoconuts == 0)
        #expect(all.awardedCoconuts == 2)
        #expect(firstStatus.awardedCoconuts == 1)
        #expect(changedStatus.awardedCoconuts == 0)
        #expect(clearedStatus.awardedCoconuts == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 3)
        #expect(awardedKinds(awarder) == [.ownerDaily, .allComplete, .dailyStatus])

        let petKey = PresenceCheckInCommandService.checkInKey(
            subject: .init(kind: .pet, id: pet.id),
            dayKey: "2026-07-18"
        )
        let petCheckIn = try #require(
            try context.fetch(FetchDescriptor<PresenceCheckIn>()).first { $0.uniqueKey == petKey }
        )
        #expect(petCheckIn.status == nil)
    }

    @Test func undoKeepsRewardReceiptsAndSuppressesLaterAutomaticForegroundCheckIn() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()

        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)
        let now = date(2026, 7, 22)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let first = try service.autoCheckInOwner(now: now)
        let removed = try service.undoTodayCheckIn(
            subject: .init(kind: .human, id: owner.id),
            now: now.addingTimeInterval(60)
        )
        let laterForeground = try service.autoCheckInOwner(now: now.addingTimeInterval(120))

        #expect(first.didCreateCheckIn)
        #expect(removed.removedCheckIn.dayKey == "2026-07-22")
        #expect(!laterForeground.didCreateCheckIn)
        #expect(laterForeground.checkIns.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 1)

        let manualRecheck = try service.checkIn(
            subject: .init(kind: .human, id: owner.id),
            source: .card,
            now: now.addingTimeInterval(180)
        )

        #expect(manualRecheck.didCreateCheckIn)
        #expect(manualRecheck.awardedCoconuts == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 1)
        #expect(awardedKinds(awarder) == [.ownerDaily])
    }

    @Test func zenActiveSubjectSnapshotCarriesMediaIdentityAndDerivesZodiacFromBirthday() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        owner.birthday = date(1992, 4, 12)
        let pet = Pet(name: "Miso", species: "cat")
        pet.birthday = date(2024, 4, 12)
        context.insert(owner)
        context.insert(pet)
        try context.save()

        let subjects = try PresenceCheckInReadService.activeSubjects(
            context: context,
            ownerHumanId: owner.id,
            now: date(2026, 7, 22),
            localization: L10n("en")
        )
        let ownerSnapshot = try #require(subjects.first { $0.subject.id == owner.id })
        let petSnapshot = try #require(subjects.first { $0.subject.id == pet.id })
        let expectedZodiac = Human.westernZodiacDisplay(for: owner.birthday!, l: L10n("en"))

        #expect(ownerSnapshot.avatarModelID == owner.persistentModelID)
        #expect(petSnapshot.avatarModelID == pet.persistentModelID)
        #expect(ownerSnapshot.expandedProfile?.metrics.first { $0.kind == .zodiac }?.value == expectedZodiac)
        #expect(petSnapshot.expandedProfile?.metrics.first { $0.kind == .zodiac }?.value == expectedZodiac)
    }

    @Test func ownerStreakSkipsNormalModeGapAndAwardsFamilyMilestoneOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)

        let day1 = date(2026, 7, 1)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: day1)
        _ = try service.autoCheckInOwner(now: day1)
        _ = try service.autoCheckInOwner(now: date(2026, 7, 2))
        try service.endParticipation(now: date(2026, 7, 3))

        let day10 = date(2026, 7, 10)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: day10)
        let milestoneResult = try service.autoCheckInOwner(now: day10)
        let replay = try service.autoCheckInOwner(now: day10.addingTimeInterval(60))
        let streak = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: owner.id,
            subject: .init(kind: .human, id: owner.id),
            now: day10,
            timeZone: utc
        )

        #expect(streak.currentStreak == 3)
        #expect(streak.longestStreak == 3)
        #expect(streak.days.first { $0.dayKey == "2026-07-05" }?.isParticipating == false)
        #expect(streak.days.first { $0.dayKey == "2026-07-10" }?.isParticipating == true)
        #expect(milestoneResult.rewards.contains {
            $0.kind == .streakMilestone && $0.milestoneDays == 3 && $0.awardedAmount == 3
        })
        #expect(!replay.rewards.contains { $0.kind == .streakMilestone })
        let milestoneReceipts = try context.fetch(FetchDescriptor<PresenceRewardReceipt>()).filter {
            $0.rewardKind == .streakMilestone
        }
        #expect(milestoneReceipts.count == 1)
        #expect(milestoneReceipts.first?.milestoneDays == 3)
    }

    @Test func retrospectiveStatusIsEditableButNeverRepairsCheckInStreakOrRewards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        owner.createdAt = date(2026, 1, 1)
        context.insert(owner)
        try context.save()

        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)
        try service.startParticipation(
            ownerHumanId: owner.id,
            source: .settings,
            now: date(2026, 7, 1)
        )
        let subject = PresenceSubjectRef(kind: .human, id: owner.id)
        for dayKey in ["2026-07-01", "2026-07-03"] {
            context.insert(PresenceCheckIn(
                uniqueKey: PresenceCheckInCommandService.checkInKey(subject: subject, dayKey: dayKey),
                subject: subject,
                ownerHumanId: owner.id,
                isOwner: true,
                dayKey: dayKey,
                timeZoneIdentifier: utc.identifier,
                checkedInAt: try #require(PresenceDayKeyPolicy.parse(dayKey)),
                source: .card
            ))
        }
        try context.save()

        let first = try service.recordRetrospectiveStatus(
            subject: subject,
            dayKey: "2026-07-02",
            status: .score8,
            now: date(2026, 7, 4)
        )
        let update = try service.recordRetrospectiveStatus(
            subject: subject,
            dayKey: "2026-07-02",
            status: .score4,
            now: date(2026, 7, 4).addingTimeInterval(60)
        )
        let streak = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: owner.id,
            subject: subject,
            now: date(2026, 7, 4),
            timeZone: utc
        )
        let rememberedDay = try #require(streak.days.first { $0.dayKey == "2026-07-02" })

        #expect(first.didCreate)
        #expect(first.fact.source == .retrospectiveStatus)
        #expect(update.didCreate == false)
        #expect(update.didChangeStatus)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 0)
        #expect(awarder.requests.isEmpty)
        #expect(streak.currentStreak == 1)
        #expect(streak.longestStreak == 1)
        #expect(!rememberedDay.isCheckedIn)
        #expect(rememberedDay.status == .score4)
        #expect(rememberedDay.isRetrospectiveStatus)

        #expect(throws: PresenceCheckInCommandError.historicalDayAlreadyCheckedIn(subject)) {
            try service.recordRetrospectiveStatus(
                subject: subject,
                dayKey: "2026-07-01",
                status: .score9,
                now: date(2026, 7, 4)
            )
        }
        #expect(throws: PresenceCheckInCommandError.historicalDayMustBePast) {
            try service.recordRetrospectiveStatus(
                subject: subject,
                dayKey: "2026-07-04",
                status: .score9,
                now: date(2026, 7, 4)
            )
        }
        #expect(throws: PresenceCheckInCommandError.historicalDayNotParticipating) {
            try service.recordRetrospectiveStatus(
                subject: subject,
                dayKey: "2026-06-30",
                status: .score9,
                now: date(2026, 7, 4)
            )
        }
    }

    @Test func nonOwnerCalendarNeverCountsDaysBeforeTheSubjectExisted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let pet = Pet(name: "New Pet", species: "cat")
        pet.createdAt = date(2026, 7, 5)
        context.insert(owner)
        context.insert(pet)
        try context.save()
        let service = makeService(
            context: context,
            ownerId: owner.id,
            awarder: RecordingPresenceRewardAwarder()
        )
        try service.startParticipation(
            ownerHumanId: owner.id,
            source: .settings,
            now: date(2026, 7, 1)
        )
        _ = try service.checkIn(
            subject: .init(kind: .pet, id: pet.id),
            now: date(2026, 7, 5)
        )

        let streak = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: owner.id,
            subject: .init(kind: .pet, id: pet.id),
            now: date(2026, 7, 6),
            timeZone: utc
        )

        #expect(streak.days.first?.dayKey == "2026-07-05")
        #expect(!streak.days.contains { $0.dayKey == "2026-07-04" })
        #expect(streak.days.first { $0.dayKey == "2026-07-05" }?.isParticipating == true)
        #expect(streak.days.first { $0.dayKey == "2026-07-06" }?.isParticipating == true)
    }

    @Test func homeDisplayStreaksArePerSubjectSkipStandardModeAndKeepYesterdayUntilDayEnd() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let pet = Pet(name: "Miso", species: "cat")
        pet.createdAt = date(2026, 7, 2)
        let plant = Plant(name: "Fern")
        plant.createdAt = date(2026, 7, 10)
        context.insert(owner)
        context.insert(pet)
        context.insert(plant)

        context.insert(PresenceParticipationPeriod(
            ownerHumanId: owner.id,
            startedAt: date(2026, 7, 1),
            startedDayKey: "2026-07-01",
            startedTimeZoneIdentifier: utc.identifier,
            endedAt: date(2026, 7, 4),
            lastParticipatingDayKey: "2026-07-03",
            endedTimeZoneIdentifier: utc.identifier,
            source: .settings
        ))
        context.insert(PresenceParticipationPeriod(
            ownerHumanId: owner.id,
            startedAt: date(2026, 7, 10),
            startedDayKey: "2026-07-10",
            startedTimeZoneIdentifier: utc.identifier,
            source: .settings
        ))

        let facts: [(PresenceSubjectRef, Bool, [String])] = [
            (.init(kind: .human, id: owner.id), true, [
                "2026-07-01", "2026-07-02", "2026-07-03", "2026-07-10", "2026-07-11"
            ]),
            (.init(kind: .pet, id: pet.id), false, [
                "2026-07-02", "2026-07-03", "2026-07-10", "2026-07-11"
            ]),
            (.init(kind: .plant, id: plant.id), false, ["2026-07-10"])
        ]
        for (subject, isOwner, dayKeys) in facts {
            for dayKey in dayKeys {
                context.insert(PresenceCheckIn(
                    uniqueKey: PresenceCheckInCommandService.checkInKey(
                        subject: subject,
                        dayKey: dayKey
                    ),
                    subject: subject,
                    ownerHumanId: owner.id,
                    isOwner: isOwner,
                    dayKey: dayKey,
                    timeZoneIdentifier: utc.identifier,
                    checkedInAt: try #require(PresenceDayKeyPolicy.parse(dayKey)),
                    source: .card
                ))
            }
        }
        try context.save()

        let snapshot = try PresenceCheckInReadService.homeSnapshot(
            context: context,
            ownerHumanId: owner.id,
            now: date(2026, 7, 12),
            timeZone: utc
        )

        #expect(snapshot.subjects.first { $0.subject.id == owner.id }?.currentDisplayStreak == 5)
        #expect(snapshot.subjects.first { $0.subject.id == pet.id }?.currentDisplayStreak == 4)
        #expect(snapshot.subjects.first { $0.subject.id == plant.id }?.currentDisplayStreak == 0)
        #expect(snapshot.subjects.allSatisfy { !$0.isCheckedInToday })
    }

    @Test func nonOwnerDisplayStreakNeverCreatesMilestoneRewards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let pet = Pet(name: "Miso", species: "cat")
        pet.createdAt = date(2026, 7, 1)
        context.insert(owner)
        context.insert(pet)
        try context.save()
        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)
        try service.startParticipation(
            ownerHumanId: owner.id,
            source: .settings,
            now: date(2026, 7, 1)
        )

        for day in 1 ... 3 {
            _ = try service.checkIn(
                subject: .init(kind: .pet, id: pet.id),
                now: date(2026, 7, day)
            )
        }
        let home = try PresenceCheckInReadService.homeSnapshot(
            context: context,
            ownerHumanId: owner.id,
            now: date(2026, 7, 3),
            timeZone: utc
        )
        let receipts = try context.fetch(FetchDescriptor<PresenceRewardReceipt>())

        #expect(home.subjects.first { $0.subject.id == pet.id }?.currentDisplayStreak == 3)
        #expect(!receipts.contains { $0.rewardKind == .streakMilestone })
        #expect(!awarder.requests.contains { $0.kind == .streakMilestone })
    }

    @Test func allSevenStreakMilestonesAreAutomaticAndUseTheApprovedValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Long Streak")
        context.insert(owner)
        try context.save()
        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)
        let firstDay = date(2025, 7, 19)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: firstDay)
        let subject = PresenceSubjectRef(kind: .human, id: owner.id)

        for offset in 0 ..< 364 {
            let occurredAt = try #require(Calendar(identifier: .gregorian).date(
                byAdding: .day,
                value: offset,
                to: firstDay
            ))
            let dayKey = PresenceDayKeyPolicy.key(for: occurredAt, timeZone: utc)
            context.insert(PresenceCheckIn(
                uniqueKey: PresenceCheckInCommandService.checkInKey(subject: subject, dayKey: dayKey),
                subject: subject,
                ownerHumanId: owner.id,
                isOwner: true,
                dayKey: dayKey,
                timeZoneIdentifier: utc.identifier,
                checkedInAt: occurredAt,
                source: .card
            ))
        }
        try context.save()
        let day365 = try #require(Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: 364,
            to: firstDay
        ))

        let result = try service.autoCheckInOwner(now: day365)
        let milestones = result.rewards
            .filter { $0.kind == .streakMilestone }
            .map { ($0.milestoneDays, $0.awardedAmount) }

        #expect(milestones.map(\.0) == [3, 7, 14, 30, 60, 100, 365])
        #expect(milestones.map(\.1) == [3, 10, 25, 60, 150, 300, 1000])
    }

    @Test func memorialArchivedAndDeletedSubjectsCannotCreateNewFacts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        let memorialHuman = Human(name: "Memory")
        memorialHuman.passedAwayDate = date(2026, 7, 1)
        let memorialPet = Pet(name: "Memory Pet", species: "cat")
        memorialPet.passedAwayDate = date(2026, 7, 1)
        let archivedPlant = Plant(name: "Archived")
        archivedPlant.archivedAt = date(2026, 7, 1)
        context.insert(owner)
        context.insert(memorialHuman)
        context.insert(memorialPet)
        context.insert(archivedPlant)
        try context.save()
        let service = makeService(
            context: context,
            ownerId: owner.id,
            awarder: RecordingPresenceRewardAwarder()
        )
        let now = date(2026, 7, 18)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let humanRef = PresenceSubjectRef(kind: .human, id: memorialHuman.id)
        let petRef = PresenceSubjectRef(kind: .pet, id: memorialPet.id)
        let plantRef = PresenceSubjectRef(kind: .plant, id: archivedPlant.id)
        let deletedRef = PresenceSubjectRef(kind: .pet, id: UUID())
        #expect(throws: PresenceCheckInCommandError.inactiveSubject(humanRef)) {
            try service.checkIn(subject: humanRef, now: now)
        }
        #expect(throws: PresenceCheckInCommandError.inactiveSubject(petRef)) {
            try service.checkIn(subject: petRef, now: now)
        }
        #expect(throws: PresenceCheckInCommandError.inactiveSubject(plantRef)) {
            try service.checkIn(subject: plantRef, now: now)
        }
        #expect(throws: PresenceCheckInCommandError.missingSubject(deletedRef)) {
            try service.checkIn(subject: deletedRef, now: now)
        }
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
    }

    @Test func rewardFailureRollsBackTheFactAndReceiptTogether() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: FailingPresenceRewardAwarder(),
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        let now = date(2026, 7, 18)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        #expect(throws: PresenceCheckInCommandError.rewardPersistenceFailed("forced reward failure")) {
            try service.autoCheckInOwner(now: now)
        }
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 0)
    }

    @Test func zeroBudgetAwardStillPersistsAnIdempotentReceipt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let awarder = ZeroPresenceRewardAwarder()
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: owner.id),
            rewardAwarder: awarder,
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        let now = date(2026, 7, 18)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let first = try service.autoCheckInOwner(now: now)
        let replay = try service.autoCheckInOwner(now: now.addingTimeInterval(30))
        let receipt = try #require(context.fetch(FetchDescriptor<PresenceRewardReceipt>()).first)

        #expect(first.awardedCoconuts == 0)
        #expect(replay.rewards.isEmpty)
        #expect(receipt.requestedAmount == 1)
        #expect(receipt.awardedAmount == 0)
    }

    @Test func concurrentForegroundCommandsRemainSingleFactAndSingleReward() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let awarder = RecordingPresenceRewardAwarder()
        let service = makeService(context: context, ownerId: owner.id, awarder: awarder)
        let now = date(2026, 7, 18)
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let tasks = (0 ..< 12).map { offset in
            Task { @MainActor in
                try service.autoCheckInOwner(now: now.addingTimeInterval(Double(offset)))
            }
        }
        let results = try await tasks.asyncMap { try await $0.value }

        #expect(results.count { $0.didCreateCheckIn } == 1)
        #expect(results.reduce(0) { $0 + $1.awardedCoconuts } == 1)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 1)
    }

    @Test func homeTodayProjectionKeepsSubjectFactsAfterOwnerRebinding() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let previousOwner = Human(name: "Previous owner")
        let currentOwner = Human(name: "Current owner")
        context.insert(previousOwner)
        context.insert(currentOwner)
        let now = date(2026, 7, 18)
        let dayKey = PresenceDayKeyPolicy.key(for: now, timeZone: utc)
        let previousSubject = PresenceSubjectRef(kind: .human, id: previousOwner.id)
        let currentSubject = PresenceSubjectRef(kind: .human, id: currentOwner.id)
        context.insert(PresenceCheckIn(
            uniqueKey: PresenceCheckInCommandService.checkInKey(subject: previousSubject, dayKey: dayKey),
            subject: previousSubject,
            ownerHumanId: previousOwner.id,
            isOwner: true,
            dayKey: dayKey,
            timeZoneIdentifier: utc.identifier,
            checkedInAt: now,
            source: .automaticForeground
        ))
        context.insert(PresenceCheckIn(
            uniqueKey: PresenceCheckInCommandService.checkInKey(subject: currentSubject, dayKey: dayKey),
            subject: currentSubject,
            ownerHumanId: currentOwner.id,
            isOwner: true,
            dayKey: dayKey,
            timeZoneIdentifier: utc.identifier,
            checkedInAt: now,
            source: .automaticForeground
        ))
        try context.save()

        let snapshot = try PresenceCheckInReadService.homeSnapshot(
            context: context,
            ownerHumanId: currentOwner.id,
            now: now,
            timeZone: utc
        )

        // A fact is household-wide and unique by subject + natural day. Changing
        // who is bound as "me" must not make an already checked-in card appear
        // unchecked (or leave it impossible to check in again).
        #expect(snapshot.subjects.first { $0.subject == previousSubject }?.isCheckedInToday == true)
        #expect(snapshot.subjects.first { $0.subject == currentSubject }?.isCheckedInToday == true)
    }

    @Test func streakKeepsInactiveAndAnonymousHistoryAcrossOwnerChanges() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let previousOwner = Human(name: "Previous owner")
        previousOwner.createdAt = date(2026, 6, 1)
        let currentOwner = Human(name: "Current owner")
        currentOwner.createdAt = date(2026, 6, 1)
        let memorialPet = Pet(name: "Memory", species: "cat")
        memorialPet.createdAt = date(2026, 6, 1)
        memorialPet.passedAwayDate = date(2026, 7, 3)
        let archivedPlant = Plant(name: "Archived")
        archivedPlant.createdAt = date(2026, 6, 1)
        archivedPlant.archivedAt = date(2026, 7, 5)
        context.insert(previousOwner)
        context.insert(currentOwner)
        context.insert(memorialPet)
        context.insert(archivedPlant)

        context.insert(PresenceParticipationPeriod(
            ownerHumanId: previousOwner.id,
            startedAt: date(2026, 7, 1),
            startedDayKey: "2026-07-01",
            startedTimeZoneIdentifier: utc.identifier,
            endedAt: date(2026, 7, 2),
            lastParticipatingDayKey: "2026-07-02",
            endedTimeZoneIdentifier: utc.identifier,
            source: .settings
        ))
        context.insert(PresenceParticipationPeriod(
            ownerHumanId: currentOwner.id,
            startedAt: date(2026, 7, 4),
            startedDayKey: "2026-07-04",
            startedTimeZoneIdentifier: utc.identifier,
            source: .settings
        ))

        let deletedSubject = PresenceSubjectRef(kind: .pet, id: UUID())
        let facts: [(PresenceSubjectRef, UUID, Bool, String)] = [
            (.init(kind: .human, id: previousOwner.id), previousOwner.id, true, "2026-07-01"),
            (.init(kind: .pet, id: memorialPet.id), previousOwner.id, false, "2026-07-02"),
            (deletedSubject, previousOwner.id, false, "2026-07-01"),
            (.init(kind: .human, id: currentOwner.id), currentOwner.id, true, "2026-07-04"),
            (.init(kind: .plant, id: archivedPlant.id), currentOwner.id, false, "2026-07-04"),
            (.init(kind: .human, id: currentOwner.id), currentOwner.id, true, "2026-07-05")
        ]
        for (subject, ownerID, isOwner, factDayKey) in facts {
            context.insert(PresenceCheckIn(
                uniqueKey: PresenceCheckInCommandService.checkInKey(subject: subject, dayKey: factDayKey),
                subject: subject,
                ownerHumanId: ownerID,
                isOwner: isOwner,
                dayKey: factDayKey,
                timeZoneIdentifier: utc.identifier,
                checkedInAt: try #require(PresenceDayKeyPolicy.parse(factDayKey)),
                source: .card
            ))
        }
        try context.save()

        let activeSubjects = try PresenceCheckInReadService.activeSubjects(
            context: context,
            ownerHumanId: currentOwner.id
        )
        let historicalSubjects = try PresenceCheckInReadService.streakSubjects(
            context: context,
            ownerHumanId: currentOwner.id
        )
        let previousOwnerStreak = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: currentOwner.id,
            subject: .init(kind: .human, id: previousOwner.id),
            now: date(2026, 7, 5),
            timeZone: utc
        )
        let currentOwnerStreak = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: currentOwner.id,
            subject: .init(kind: .human, id: currentOwner.id),
            now: date(2026, 7, 5),
            timeZone: utc
        )
        let deletedSubjectHistory = try PresenceCheckInReadService.streakSnapshot(
            context: context,
            ownerHumanId: currentOwner.id,
            subject: deletedSubject,
            now: date(2026, 7, 5),
            timeZone: utc
        )

        #expect(!activeSubjects.contains { $0.subject == .init(kind: .pet, id: memorialPet.id) })
        #expect(!activeSubjects.contains { $0.subject == .init(kind: .plant, id: archivedPlant.id) })
        #expect(!activeSubjects.contains { $0.subject == deletedSubject })
        #expect(historicalSubjects.first { $0.subject == .init(kind: .pet, id: memorialPet.id) }?.isActive == false)
        #expect(historicalSubjects.first { $0.subject == .init(kind: .plant, id: archivedPlant.id) }?.isActive == false)
        #expect(historicalSubjects.first { $0.subject == deletedSubject }?.isAnonymousHistory == true)
        #expect(previousOwnerStreak.days.first { $0.dayKey == "2026-07-01" }?.isCheckedIn == true)
        #expect(previousOwnerStreak.days.first { $0.dayKey == "2026-07-02" }?.isParticipating == true)
        #expect(previousOwnerStreak.days.first { $0.dayKey == "2026-07-03" }?.isParticipating == false)
        #expect(previousOwnerStreak.days.first { $0.dayKey == "2026-07-04" }?.isParticipating == true)
        #expect(previousOwnerStreak.currentStreak == 0)
        #expect(previousOwnerStreak.longestStreak == 0)
        #expect(currentOwnerStreak.currentStreak == 2)
        #expect(currentOwnerStreak.longestStreak == 2)
        #expect(deletedSubjectHistory.days.first?.dayKey == "2026-07-01")
        #expect(deletedSubjectHistory.days.first?.isCheckedIn == true)
    }

    @Test func realEconomyAdapterCommitsFactReceiptLedgerAndBalanceOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let now = date(2026, 7, 18)
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let memberKey = owner.id.uuidString
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberKey, date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberKey, date: now)
        }
        let wallet = SwiftDataCoconutWalletManager()
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: owner.id),
            wallet: wallet,
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let first = try service.autoCheckInOwner(now: now)
        let replay = try service.autoCheckInOwner(now: now.addingTimeInterval(30))
        let receipts = try context.fetch(FetchDescriptor<PresenceRewardReceipt>())
        let ledger = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter {
            $0.sourceModelName == "PresenceRewardReceipt"
        }

        #expect(first.awardedCoconuts == 1)
        #expect(replay.awardedCoconuts == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 1)
        #expect(receipts.count == 1)
        #expect(receipts.first?.walletTransactionKey == ledger.first?.transactionKey)
        #expect(ledger.count == 1)
        #expect(wallet.balance(for: owner, context: context) == 1)
    }

    @Test func notificationCheckInBeforeRootBootstrapPreservesLegacyBalanceDuringProjectionReplay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Legacy Owner")
        owner.coconutBalance = 10
        owner.createdAt = date(2026, 7, 1)
        context.insert(owner)
        try context.save()

        let defaultsSuiteName = "PresencePreBootstrapWallet.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        let legacyCountKey = "quest_coconutCount"
        let legacyLogsKey = "quest_coconutLogs"
        let alternateLegacyLogsKey = "coconutLogs"
        defaults.set(20, forKey: legacyCountKey)
        defaults.removeObject(forKey: legacyLogsKey)
        defaults.removeObject(forKey: alternateLegacyLogsKey)

        let now = date(2026, 7, 18)
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let memberKey = owner.id.uuidString
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberKey, date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberKey, date: now)
        }
        let wallet = SwiftDataCoconutWalletManager(legacyDefaults: defaults)
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: owner.id),
            wallet: wallet,
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let result = try service.checkInOwner(source: .notificationAction, now: now)
        wallet.refreshQuestProjection(context: context)
        try wallet.bootstrapIfNeeded(context: context)

        let accountKey = CoconutAccountKey.human(owner.id)
        let ownerLedger = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter {
            $0.accountKey == accountKey && $0.affectsBalance
        }
        let orderedOwnerLedger = ownerLedger.sorted { $0.occurredAt < $1.occurredAt }
        #expect(result.awardedCoconuts == 1)
        #expect(wallet.balance(for: owner, context: context) == 11)
        #expect(owner.coconutBalance == 11)
        #expect(wallet.legacySystemBalance(context: context) == 10)
        #expect(ownerLedger.reduce(0) { $0 + $1.delta } == 11)
        #expect(ownerLedger.count { $0.entryKind == .openingBalance } == 1)
        #expect(ownerLedger.count { $0.sourceModelName == "PresenceRewardReceipt" } == 1)
        #expect(orderedOwnerLedger.first?.balanceBefore == 0)
        #expect(orderedOwnerLedger.first?.balanceAfter == 10)
        #expect(orderedOwnerLedger.last?.balanceBefore == 10)
        #expect(orderedOwnerLedger.last?.balanceAfter == 11)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 1)
    }

    @Test func failedStagedBootstrapRollbackDoesNotReplayAPartialLedgerOverTheSavedBalance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Legacy Owner")
        owner.coconutBalance = 11
        owner.createdAt = date(2026, 7, 1)
        let pet = Pet(name: "Miso", species: "cat")
        pet.coconutBalance = 5
        let ownerAccountKey = CoconutAccountKey.human(owner.id)
        let ownerAccount = CoconutAccount(
            accountKey: ownerAccountKey,
            ownerKind: .human,
            ownerId: owner.id.uuidString,
            displayName: owner.name,
            balance: 11
        )
        let savedReward = CoconutLedgerEntry(
            transactionKey: "test:partial-state:owner-reward",
            accountKey: ownerAccountKey,
            ownerKind: .human,
            ownerId: owner.id.uuidString,
            ownerName: owner.name,
            delta: 1,
            balanceBefore: 10,
            balanceAfter: 11,
            entryKind: .reward,
            source: .service,
            title: "Saved reward",
            emoji: "🥥",
            occurredAt: date(2026, 7, 2)
        )
        let partialSystemOpeningKey = "bootstrap:v58:opening:\(CoconutAccountKey.legacySystem)"
        let partialSystemOpening = CoconutLedgerEntry(
            transactionKey: partialSystemOpeningKey,
            accountKey: CoconutAccountKey.legacySystem,
            ownerKind: .system,
            ownerId: "",
            ownerName: "Legacy island total",
            delta: 0,
            balanceBefore: 0,
            balanceAfter: 0,
            entryKind: .openingBalance,
            source: .legacyUserDefaults,
            title: "Partial legacy opening",
            emoji: "🥥"
        )
        context.insert(owner)
        context.insert(pet)
        context.insert(ownerAccount)
        context.insert(savedReward)
        context.insert(partialSystemOpening)
        try context.save()

        let defaultsSuiteName = "PresenceFailedStagedBootstrap.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }
        defaults.set(20, forKey: "quest_coconutCount")

        let now = date(2026, 7, 18)
        let wallet = SwiftDataCoconutWalletManager(legacyDefaults: defaults)
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: owner.id),
            wallet: wallet,
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        do {
            _ = try service.checkInOwner(source: .notificationAction, now: now)
            Issue.record("Expected the partial legacy bootstrap to reject its duplicate transaction")
        } catch let error as PresenceCheckInCommandError {
            guard case .rewardPersistenceFailed = error else {
                Issue.record("Expected rewardPersistenceFailed, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected PresenceCheckInCommandError, got \(error)")
        }

        let accounts = try context.fetch(FetchDescriptor<CoconutAccount>())
        let savedOwnerAccount = try #require(accounts.first { $0.accountKey == ownerAccountKey })
        let entries = try context.fetch(FetchDescriptor<CoconutLedgerEntry>())
        #expect(savedOwnerAccount.balance == 11)
        #expect(owner.coconutBalance == 11)
        #expect(entries.count == 2)
        #expect(entries.contains { $0.transactionKey == savedReward.transactionKey })
        #expect(entries.contains { $0.transactionKey == partialSystemOpeningKey })
        #expect(!entries.contains {
            $0.transactionKey == "bootstrap:v58:opening:\(ownerAccountKey)"
        })
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceRewardReceipt>()) == 0)
        #expect(!context.hasChanges)
    }

    @Test func realEconomyAdapterPersistsZeroReceiptWhenDailyBudgetIsExhausted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Owner")
        context.insert(owner)
        try context.save()
        let now = date(2026, 7, 18)
        let householdKey = CoconutEconomyPolicyV2.householdBudgetKey(context: context)
        let memberKey = owner.id.uuidString
        EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberKey, date: now)
        defer {
            EconomyDailyBudgetStore.reset(householdKey: householdKey, memberKey: memberKey, date: now)
        }
        let initialBudget = EconomyDailyBudgetStore.snapshot(
            householdKey: householdKey,
            memberKey: memberKey,
            careObjectCount: CoconutEconomyPolicyV2.careObjectCount(context: context),
            date: now,
            context: context
        )
        EconomyDailyBudgetStore.commit(
            EconomyRewardResult(
                growthXP: 0,
                humanCoconuts: initialBudget.remainingFatigueCoconuts,
                petCoconuts: 0,
                bonusCoconuts: 0,
                luckyCoconuts: 0,
                budgetMultiplier: 1,
                budgetStage: .fatigue,
                reason: "test budget exhaustion",
                actionKey: "presence_test_budget_exhaustion",
                isOnCooldown: false,
                baseGrowthXP: 0,
                baseCoconuts: initialBudget.remainingFatigueCoconuts,
                luck: .none
            ),
            householdKey: householdKey,
            memberKey: memberKey,
            date: now,
            context: context
        )
        let wallet = SwiftDataCoconutWalletManager()
        let service = PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: owner.id),
            wallet: wallet,
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
        try service.startParticipation(ownerHumanId: owner.id, source: .settings, now: now)

        let result = try service.autoCheckInOwner(now: now)
        let receipt = try #require(context.fetch(FetchDescriptor<PresenceRewardReceipt>()).first)
        let presenceLedger = try context.fetch(FetchDescriptor<CoconutLedgerEntry>()).filter {
            $0.sourceModelName == "PresenceRewardReceipt"
        }

        #expect(initialBudget.remainingFatigueCoconuts > 0)
        #expect(result.didCreateCheckIn)
        #expect(result.awardedCoconuts == 0)
        #expect(receipt.requestedAmount == 1)
        #expect(receipt.awardedAmount == 0)
        #expect(receipt.walletTransactionKey == nil)
        #expect(presenceLedger.isEmpty)
        #expect(wallet.balance(for: owner, context: context) == 0)
    }

    @Test func legacyMigrationUpsertsDatesMakeupAndClaimedMilestonesWithoutAwards() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let owner = Human(name: "Legacy Owner")
        context.insert(owner)
        try context.save()
        let suiteName = "PresenceLegacyMigrationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let reader = FixedLegacyReader(
            value: PresenceLegacyStreakSnapshot(
                checkedDates: ["2026-06-01", "2026-06-02", "2026-06-03"],
                makeupDates: ["2026-06-02"],
                claimedMilestone: 7
            )
        )

        let first = try PresenceLegacyMigrationService.migrateIfNeeded(
            context: context,
            ownerHumanId: owner.id,
            legacyReader: reader,
            defaults: defaults,
            now: date(2026, 6, 3),
            timeZone: utc
        )
        let replay = try PresenceLegacyMigrationService.migrateIfNeeded(
            context: context,
            ownerHumanId: owner.id,
            legacyReader: reader,
            defaults: defaults,
            now: date(2026, 6, 3),
            timeZone: utc
        )
        let awarder = RecordingPresenceRewardAwarder()
        let commandService = makeService(context: context, ownerId: owner.id, awarder: awarder)
        try commandService.startParticipation(
            ownerHumanId: owner.id,
            source: .settings,
            now: date(2026, 6, 3)
        )
        let sameDayAutomaticCheckIn = try commandService.autoCheckInOwner(now: date(2026, 6, 3))

        #expect(first.migratedCheckInCount == 3)
        #expect(first.migratedMilestoneReceiptCount == 2)
        #expect(first.didCreateParticipationPeriod)
        #expect(replay.migratedCheckInCount == 0)
        #expect(try context.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 3)
        let migrated = try context.fetch(FetchDescriptor<PresenceCheckIn>())
        #expect(!migrated.contains { !$0.isLegacy })
        #expect(migrated.first { $0.dayKey == "2026-06-02" }?.source == .legacyMakeup)
        let receipts = try context.fetch(FetchDescriptor<PresenceRewardReceipt>())
        #expect(receipts.count == 2)
        #expect(receipts.allSatisfy { $0.isLegacy && $0.awardedAmount == 0 })
        #expect(!sameDayAutomaticCheckIn.didCreateCheckIn)
        #expect(sameDayAutomaticCheckIn.awardedCoconuts == 0)
        #expect(awarder.requests.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<CoconutLedgerEntry>()) == 0)
    }

    @Test func v92StoreMigratesToV93AndPersistsPresenceFacts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OhanaPresenceV93Migration-\(UUID().uuidString)", isDirectory: true)
        let storeURL = directory.appendingPathComponent("Models.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ownerID = UUID()

        do {
            let schema = Schema(ArkSchemaV92.models)
            let configuration = ModelConfiguration(
                "PresenceV92Source",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: schema,
                migrationPlan: PresenceV92OnlyMigrationPlan.self,
                configurations: [configuration]
            )
            let owner = Human(name: "V92 Owner")
            owner.id = ownerID
            container.mainContext.insert(owner)
            try container.mainContext.save()
        }

        let schema = Schema(ArkSchemaV96.models)
        let configuration = ModelConfiguration(
            "PresenceV93Target",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: ArkMigrationPlan.self,
            configurations: [configuration]
        )
        let owner = try #require(container.mainContext.fetch(FetchDescriptor<Human>()).first)
        #expect(owner.id == ownerID)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 0)
        container.mainContext.insert(
            PresenceCheckIn(
                uniqueKey: "presence:test:v93",
                subject: .init(kind: .human, id: owner.id),
                ownerHumanId: owner.id,
                isOwner: true,
                dayKey: "2026-07-18",
                timeZoneIdentifier: utc.identifier,
                checkedInAt: date(2026, 7, 18),
                source: .card
            )
        )
        try container.mainContext.save()
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PresenceCheckIn>()) == 1)
    }

    private func makeService(
        context: ModelContext,
        ownerId: UUID,
        awarder: RecordingPresenceRewardAwarder
    ) -> PresenceCheckInCommandService {
        PresenceCheckInCommandService(
            context: context,
            ownerSelection: FixedPresenceOwnerSelection(ownerHumanId: ownerId),
            rewardAwarder: awarder,
            migratesLegacyBeforeCommands: false,
            timeZoneProvider: { TimeZone(secondsFromGMT: 0)! }
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV94.models)
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func awardedKinds(_ awarder: RecordingPresenceRewardAwarder) -> [PresenceRewardKind] {
        awarder.requests.map(\.kind)
    }
}

private nonisolated struct FixedPresenceOwnerSelection: PresenceOwnerSelecting {
    let ownerHumanId: UUID?
}

@MainActor
private final class RecordingPresenceRewardAwarder: PresenceRewardAwarding {
    private(set) var requests: [PresenceRewardRequest] = []

    func stage(
        _ request: PresenceRewardRequest,
        owner _: Human,
        context _: ModelContext,
        now _: Date
    ) throws -> PresenceStagedReward {
        requests.append(request)
        return PresenceStagedReward(
            request: request,
            awardedAmount: request.requestedAmount,
            walletTransactionKey: "test:\(request.receiptKey)",
            budgetResult: nil
        )
    }

    func didCommit(_: [PresenceStagedReward], owner _: Human, context _: ModelContext, now _: Date) {}
    func didRollback(context _: ModelContext) {}
}

@MainActor
private final class ZeroPresenceRewardAwarder: PresenceRewardAwarding {
    func stage(
        _ request: PresenceRewardRequest,
        owner _: Human,
        context _: ModelContext,
        now _: Date
    ) throws -> PresenceStagedReward {
        PresenceStagedReward(
            request: request,
            awardedAmount: 0,
            walletTransactionKey: nil,
            budgetResult: nil
        )
    }

    func didCommit(_: [PresenceStagedReward], owner _: Human, context _: ModelContext, now _: Date) {}
    func didRollback(context _: ModelContext) {}
}

@MainActor
private final class FailingPresenceRewardAwarder: PresenceRewardAwarding {
    func stage(
        _: PresenceRewardRequest,
        owner _: Human,
        context _: ModelContext,
        now _: Date
    ) throws -> PresenceStagedReward {
        throw TestPresenceRewardError.forced
    }

    func didCommit(_: [PresenceStagedReward], owner _: Human, context _: ModelContext, now _: Date) {}
    func didRollback(context _: ModelContext) {}
}

private enum TestPresenceRewardError: LocalizedError {
    case forced

    var errorDescription: String? { "forced reward failure" }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            await values.append(try transform(element))
        }
        return values
    }
}

@MainActor
private struct FixedLegacyReader: PresenceLegacyStreakReading {
    let value: PresenceLegacyStreakSnapshot

    func snapshot(ownerHumanId _: UUID) -> PresenceLegacyStreakSnapshot { value }
}

private enum PresenceV92OnlyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ArkSchemaV92.self] }
    static var stages: [MigrationStage] { [] }
}

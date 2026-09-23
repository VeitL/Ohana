import SwiftData
import XCTest
@testable import Ohana

@MainActor
final class AppResetServiceTests: XCTestCase {
    func testResetClearsDataAndReturnsToOnboardingState() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaultsSuiteName = "AppResetServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }

        let pet = Pet(name: "Miso")
        let human = Human(name: "Guan")
        let careLog = PetCareLog(type: .feeding, amountGrams: 42, pet: pet, executorId: human.id.uuidString)
        let budgetUsage = EconomyBudgetUsageEvent(
            dayKey: "2026-07-10",
            householdKey: "household.local",
            memberKey: human.id.uuidString,
            careObjectKey: pet.id.uuidString,
            scope: .household,
            scopeKey: "household.local",
            growthXPUsed: 1,
            coconutUsed: 1,
            actionKey: "feed",
            source: "test"
        )
        let undoReceipt = SharedCareUndoReceipt(
            sharedSessionId: UUID(),
            sourcePetId: pet.id,
            targetPetIds: [pet.id],
            executorId: human.id.uuidString,
            actionKind: .litterScoop,
            occurredAt: Date(),
            undoDeadline: Date().addingTimeInterval(6)
        )
        context.insert(pet)
        context.insert(human)
        context.insert(careLog)
        context.insert(budgetUsage)
        context.insert(undoReceipt)
        seedD34HealthFacts(for: human, in: context)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthReport>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()), 1)

        defaults.set(true, forKey: "ohana_has_onboarded")
        defaults.set(human.id.uuidString, forKey: "currentActiveHumanId")
        defaults.set(true, forKey: AutomaticBackupStatusStore.enabledKey)
        defaults.set("stale", forKey: "automaticBackup.lastFailureMessage.v1")
        defaults.set("en", forKey: "appLanguage")
        defaults.set("DE", forKey: AppCountry.storageKey)
        defaults.set("{}", forKey: "quickActionItems_v2")
        defaults.set(12, forKey: "quest_coconutCount")
        defaults.set(AppBackgroundStyle.customPhoto.rawValue, forKey: "appBackgroundStyle")
        defaults.set(true, forKey: StarterGiftStorageKey.claimed)
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonySeen)
        defaults.set(true, forKey: StarterGiftStorageKey.ceremonyRequested)
        defaults.set(true, forKey: StarterGiftStorageKey.oasisTabPromptPending)
        defaults.set(true, forKey: StarterPetSuggestionStorageKey.resolved)
        defaults.set(Date().timeIntervalSince1970, forKey: OnboardingJourneyCoordinator.Key.journeyStartedAt)
        defaults.set(UUID().uuidString, forKey: OnboardingJourneyCoordinator.Key.firstHumanID)
        defaults.set(
            OnboardingJourneyCoordinator.InitialPetChoice.deferred.rawValue,
            forKey: OnboardingJourneyCoordinator.Key.initialPetChoice
        )
        defaults.set(true, forKey: "ohanaStarterFirstCareCompletedV1")
        defaults.set(true, forKey: "ohanaGrowthOnboardingCompletedV1")
        defaults.set(1, forKey: "economyV2.dailyBudget.household.local.2026-07-10")

        try AppResetService.reset(
            context: context,
            defaults: defaults,
            options: AppResetService.Options(
                cancelPendingNotifications: false,
                deleteCustomBackground: false,
                deleteHumanNoteAttachments: false,
                resetSharedRuntimeState: false,
                cleanUpAutomaticBackups: false
            ),
            attachmentStorage: .live,
            systemSurfaceSnapshotSanitizer: {},
            deletePersistentData: { try $0.deleteAllData() }
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Human>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetCareLog>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<EconomyBudgetUsageEvent>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SharedCareUndoReceipt>()).isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthReport>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthMetricLog>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthCondition>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HumanHealthObservation>()), 0)
        XCTAssertFalse(defaults.bool(forKey: "ohana_has_onboarded"))
        XCTAssertEqual(defaults.string(forKey: "currentActiveHumanId"), "")
        XCTAssertNil(defaults.object(forKey: "quickActionItems_v2"))
        XCTAssertNil(defaults.object(forKey: "quest_coconutCount"))
        XCTAssertNil(defaults.object(forKey: "appBackgroundStyle"))
        XCTAssertNil(defaults.object(forKey: StarterGiftStorageKey.claimed))
        XCTAssertNil(defaults.object(forKey: StarterGiftStorageKey.ceremonySeen))
        XCTAssertNil(defaults.object(forKey: StarterGiftStorageKey.ceremonyRequested))
        XCTAssertNil(defaults.object(forKey: StarterGiftStorageKey.oasisTabPromptPending))
        XCTAssertNil(defaults.object(forKey: StarterPetSuggestionStorageKey.resolved))
        XCTAssertNil(defaults.object(forKey: OnboardingJourneyCoordinator.Key.journeyStartedAt))
        XCTAssertNil(defaults.object(forKey: OnboardingJourneyCoordinator.Key.firstHumanID))
        XCTAssertNil(defaults.object(forKey: OnboardingJourneyCoordinator.Key.initialPetChoice))
        XCTAssertNil(defaults.object(forKey: "ohanaStarterFirstCareCompletedV1"))
        XCTAssertNil(defaults.object(forKey: "ohanaGrowthOnboardingCompletedV1"))
        XCTAssertNil(defaults.object(forKey: "economyV2.dailyBudget.household.local.2026-07-10"))
        let automaticBackupStatusStore = AutomaticBackupStatusStore(defaults: defaults)
        XCTAssertFalse(automaticBackupStatusStore.snapshot().isEnabled)
        XCTAssertNil(defaults.object(forKey: "automaticBackup.lastFailureMessage.v1"))
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "en")
        XCTAssertEqual(defaults.string(forKey: AppCountry.storageKey), "DE")
    }

    func testResetClearsCareSettingPrefixes() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let defaultsSuiteName = "AppResetServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        let suffix = UUID().uuidString
        let keys = [
            "waterInterval_\(suffix)",
            "filterCleanInterval_\(suffix)",
            "filterReplaceInterval_\(suffix)",
            "waterReminder_\(suffix)",
            "filterReminder_\(suffix)",
            "waterAmountEnabled_\(suffix)",
            "waterAmountMl_\(suffix)",
            "waterChangeCycleAnchor_\(suffix)",
            "feedGoal_\(suffix)",
            "scoopIntervalDays_\(suffix)",
            "scoopAnchorDate_\(suffix)"
        ]
        for key in keys {
            defaults.set("stale", forKey: key)
        }

        try AppResetService.reset(
            context: context,
            defaults: defaults,
            options: AppResetService.Options(
                cancelPendingNotifications: false,
                deleteCustomBackground: false,
                deleteHumanNoteAttachments: false,
                resetSharedRuntimeState: false,
                cleanUpAutomaticBackups: false
            ),
            attachmentStorage: .live,
            systemSurfaceSnapshotSanitizer: {},
            deletePersistentData: { try $0.deleteAllData() }
        )

        for key in keys {
            XCTAssertNil(defaults.object(forKey: key), key)
        }
    }

    func testResetStopsBeforePersistentDeletionWhenSystemSurfaceSanitizationFails() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let human = Human(name: "Keep")
        context.insert(human)
        try context.save()

        let defaultsSuiteName = "AppResetServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defer {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults.set(true, forKey: "ohana_has_onboarded")

        var attemptedPersistentDeletion = false
        XCTAssertThrowsError(
            try AppResetService.reset(
                context: context,
                defaults: defaults,
                options: AppResetService.Options(
                    cancelPendingNotifications: false,
                    deleteCustomBackground: false,
                    deleteHumanNoteAttachments: false,
                    resetSharedRuntimeState: false,
                    cleanUpAutomaticBackups: false
                ),
                attachmentStorage: .live,
                systemSurfaceSnapshotSanitizer: {
                    throw SystemSurfaceSnapshotStore.StoreError.resetSanitizationFailed
                },
                deletePersistentData: { _ in
                    attemptedPersistentDeletion = true
                }
            )
        ) { error in
            guard case .systemSurfaceCleanupFailed = error as? AppResetPersistenceError else {
                return XCTFail("Expected a system-surface cleanup failure, got \(error)")
            }
        }

        XCTAssertFalse(attemptedPersistentDeletion)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Human>()).count, 1)
        XCTAssertTrue(defaults.bool(forKey: "ohana_has_onboarded"))
    }

    private func seedD34HealthFacts(for human: Human, in context: ModelContext) {
        let healthReport = HumanHealthReport(
            humanId: human.id.uuidString,
            reportType: .bloodTest,
            conclusion: .attention,
            hospitalName: "Ohana Clinic",
            doctorName: "Dr. Reset",
            reportDate: Date(timeIntervalSince1970: 1_751_587_200),
            summary: "Review thyroid marker",
            notes: "Confirmed from an on-device scan",
            recordedByHumanId: human.id.uuidString,
            captureSource: .documentScan
        )
        let healthMetric = HumanHealthMetricLog(
            metricKey: "tsh",
            unitCode: "mIU_L",
            value: 4.8,
            date: Date(timeIntervalSince1970: 1_751_587_200),
            notes: "Confirmed imported value",
            recordedByHumanId: human.id.uuidString,
            sourceReportID: healthReport.id,
            sourceLabel: "TSH",
            referenceLow: 0.4,
            referenceHigh: 4.0,
            referenceRangeText: "0.4-4.0",
            reportedFlag: .high,
            human: human
        )
        let healthCondition = HumanHealthCondition(
            humanId: human.id.uuidString,
            name: "Thyroid monitoring",
            category: .thyroid,
            trackingStatus: .monitoring,
            startedOn: Date(timeIntervalSince1970: 1_735_689_600),
            carePlan: "Review with a clinician",
            notes: "Self-reported tracking record",
            linkedMetricKeys: [healthMetric.metricKey],
            recordedByHumanId: human.id.uuidString
        )
        let healthObservation = HumanHealthObservation(
            humanId: human.id.uuidString,
            conditionId: healthCondition.id.uuidString,
            recordedAt: Date(timeIntervalSince1970: 1_751_587_200),
            severity: 3,
            moodScore: 7,
            sleepHours: 7.5,
            symptomTags: ["fatigue"],
            possibleTriggers: "Poor sleep",
            careActions: "Rested",
            medicationResponse: .unknown,
            notes: "Observation linked to the tracked condition",
            recordedByHumanId: human.id.uuidString
        )
        context.insert(healthReport)
        context.insert(healthMetric)
        context.insert(healthCondition)
        context.insert(healthObservation)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(ArkSchemaV99.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }
}

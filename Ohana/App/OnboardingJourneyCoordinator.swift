//
//  OnboardingJourneyCoordinator.swift
//  Ohana
//
//  First-run growth journey state machine. It keeps the startup path skinny:
//  callers schedule evaluation after first render, then this coordinator decides
//  the next lightweight onboarding state.
//

import Foundation
import SwiftData

enum OnboardingJourneyPhase: Equatable {
    case preOnboarding
    case needsFirstPet
    case starterGiftPending
    case starterGiftReadyForCeremony(amount: Int)
    case firstCarePending
    case roadmapPromptPending
    case complete
    case existingUser
}

struct OnboardingJourneyEvaluation: Equatable {
    let phase: OnboardingJourneyPhase
    let starterGiftResult: StarterGiftService.Result
}

enum OnboardingJourneyCoordinator {
    enum Key {
        static let journeyStartedAt = "ohanaStarterJourneyStartedAtV1"
        static let firstCareCompleted = "ohanaStarterFirstCareCompletedV1"
        static let roadmapPromptSeen = "ohanaStarterRoadmapPromptSeenV1"
        static let existingUserUpgradeSeen = "ohanaExistingUserGrowthUpgradeSeenV1"
    }

    @MainActor
    static func beginFreshJourney(
        context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        let didBegin = StarterGiftService.beginFreshJourney(context: context, defaults: defaults)
        guard didBegin || defaults.bool(forKey: StarterGiftStorageKey.pending) else { return }
        if defaults.object(forKey: Key.journeyStartedAt) == nil {
            defaults.set(now.timeIntervalSince1970, forKey: Key.journeyStartedAt)
            AppPerformanceMonitor.shared.record("onboarding_pet_first_started", valueMS: 0)
        }
    }

    @MainActor
    static func evaluate(
        hasOnboarded: Bool,
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard,
        projectionManager: QuestManager? = nil
    ) -> OnboardingJourneyEvaluation {
        guard hasOnboarded else {
            return OnboardingJourneyEvaluation(phase: .preOnboarding, starterGiftResult: .alreadyHandled)
        }

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: activeHumanID,
            context: context,
            defaults: defaults,
            projectionManager: projectionManager
        )

        if hasRecordedCareBusinessFact(context: context) {
            markFirstCareCompleted(defaults: defaults)
        }

        if result == .markedExistingUser {
            defaults.set(true, forKey: Key.firstCareCompleted)
            defaults.set(true, forKey: Key.roadmapPromptSeen)
            return OnboardingJourneyEvaluation(phase: .existingUser, starterGiftResult: result)
        }

        return OnboardingJourneyEvaluation(
            phase: currentPhase(activeHumanID: activeHumanID, context: context, defaults: defaults),
            starterGiftResult: result
        )
    }

    @MainActor
    static func currentPhase(
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) -> OnboardingJourneyPhase {
        if StarterGiftService.shouldShowCeremony(defaults: defaults) {
            return .starterGiftReadyForCeremony(amount: StarterGiftService.giftAmount)
        }

        if defaults.bool(forKey: StarterGiftStorageKey.pending) {
            guard hasActivePet(context: context) else { return .needsFirstPet }
            guard hasRecordedCareBusinessFact(context: context) else { return .firstCarePending }
            return .starterGiftPending
        }

        return .complete
    }

    @MainActor
    static func interruptedOnboardingFirstPetID(context: ModelContext) -> String? {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.passedAwayDate == nil
            },
            sortBy: [SortDescriptor(\Pet.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(
            descriptor,
            context: context,
            operation: "recover interrupted onboarding first pet"
        ).first?.id.uuidString
    }

    @MainActor
    static func interruptedOnboardingPrimaryHumanID(context: ModelContext) -> String? {
        var descriptor = FetchDescriptor<Human>(
            sortBy: [SortDescriptor(\Human.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(
            descriptor,
            context: context,
            operation: "recover interrupted onboarding primary human"
        ).first?.id.uuidString
    }

    @MainActor
    static func shouldShowStarterCeremony(defaults: UserDefaults = .standard) -> Bool {
        StarterGiftService.shouldShowCeremony(defaults: defaults)
    }

    @MainActor
    static func markStarterCeremonySeen(
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        let elapsedMilliseconds = journeyElapsedMilliseconds(defaults: defaults, now: now)
        StarterGiftService.markCeremonySeen(defaults: defaults)
        if let elapsedMilliseconds {
            AppPerformanceMonitor.shared.record(
                "onboarding_pet_first_value_completed",
                valueMS: elapsedMilliseconds
            )
        }
    }

    static func journeyElapsedMilliseconds(
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Double? {
        guard defaults.object(forKey: Key.journeyStartedAt) != nil else { return nil }
        let startedAt = defaults.double(forKey: Key.journeyStartedAt)
        guard startedAt > 0 else { return nil }
        return max(0, now.timeIntervalSince1970 - startedAt) * 1000
    }

    @MainActor
    static func markFirstCareCompleted(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Key.firstCareCompleted) else { return }
        defaults.set(true, forKey: Key.firstCareCompleted)
        AppPerformanceMonitor.shared.record("starter_first_care_completed", valueMS: 0)
    }

    @MainActor
    static func markRoadmapPromptSeen(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Key.roadmapPromptSeen) else { return }
        defaults.set(true, forKey: Key.roadmapPromptSeen)
        AppPerformanceMonitor.shared.record("growth_roadmap_prompt_seen", valueMS: 0)
    }

    @MainActor
    static func resetForDebug(defaults: UserDefaults = .standard) {
        StarterGiftService.resetForDebug(defaults: defaults)
        defaults.removeObject(forKey: Key.firstCareCompleted)
        defaults.removeObject(forKey: Key.roadmapPromptSeen)
        defaults.removeObject(forKey: Key.existingUserUpgradeSeen)
        defaults.removeObject(forKey: Key.journeyStartedAt)
    }

    @MainActor
    private static func hasRecordedCareBusinessFact(context: ModelContext) -> Bool {
        var weightDescriptor = FetchDescriptor<PetWeightLog>()
        weightDescriptor.fetchLimit = 1
        if !fetchModelsOrLog(
            weightDescriptor,
            context: context,
            operation: "fetch recorded starter weight facts"
        ).isEmpty {
            return true
        }
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType != "starterGift" && event.eventKind != "coconut"
            }
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch recorded care business facts").isEmpty == false
    }

    @MainActor
    private static func hasActivePet(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Pet>(
            predicate: #Predicate<Pet> { pet in
                pet.passedAwayDate == nil
            }
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch starter active pet").isEmpty == false
    }

    @MainActor
    private static func fetchModelsOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "OnboardingJourneyCoordinator failed to \(operation): \(error.localizedDescription)",
                category: "Onboarding"
            )
            return []
        }
    }
}

@MainActor
protocol OnboardingJourneyCoordinating {
    func beginFreshJourney(context: ModelContext)
    func evaluate(
        hasOnboarded: Bool,
        activeHumanID: String?,
        context: ModelContext,
        projectionManager: QuestManager?
    ) -> OnboardingJourneyEvaluation
    func interruptedOnboardingFirstPetID(context: ModelContext) -> String?
    func interruptedOnboardingPrimaryHumanID(context: ModelContext) -> String?
    func markStarterCeremonySeen()
    func markFirstCareCompleted()
    func markRoadmapPromptSeen()
}

struct LiveOnboardingJourneyCoordinator: OnboardingJourneyCoordinating {
    func beginFreshJourney(context: ModelContext) {
        OnboardingJourneyCoordinator.beginFreshJourney(context: context)
    }

    func evaluate(
        hasOnboarded: Bool,
        activeHumanID: String?,
        context: ModelContext,
        projectionManager: QuestManager?
    ) -> OnboardingJourneyEvaluation {
        OnboardingJourneyCoordinator.evaluate(
            hasOnboarded: hasOnboarded,
            activeHumanID: activeHumanID,
            context: context,
            projectionManager: projectionManager
        )
    }

    func interruptedOnboardingFirstPetID(context: ModelContext) -> String? {
        OnboardingJourneyCoordinator.interruptedOnboardingFirstPetID(context: context)
    }

    func interruptedOnboardingPrimaryHumanID(context: ModelContext) -> String? {
        OnboardingJourneyCoordinator.interruptedOnboardingPrimaryHumanID(context: context)
    }

    func markStarterCeremonySeen() {
        OnboardingJourneyCoordinator.markStarterCeremonySeen()
    }

    func markFirstCareCompleted() {
        OnboardingJourneyCoordinator.markFirstCareCompleted()
    }

    func markRoadmapPromptSeen() {
        OnboardingJourneyCoordinator.markRoadmapPromptSeen()
    }
}

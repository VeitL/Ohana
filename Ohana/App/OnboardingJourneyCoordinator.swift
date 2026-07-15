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

enum OnboardingJourneyPhase: Equatable, Sendable {
    case preOnboarding
    case needsHumanName
    case petChoice
    case petCreation
    case awaitingPet
    case starterGiftReady(amount: Int)
    case complete
    case existingUser
}

struct OnboardingJourneyEvaluation: Equatable, Sendable {
    let phase: OnboardingJourneyPhase
    let starterGiftResult: StarterGiftService.Result
}

nonisolated enum StarterGiftHomeProjectionPolicy {
    static func expectedVisibleBalance(
        after result: StarterGiftService.Result,
        visibleBalanceBeforeRequest: Int,
        existingExpectation: Int?
    ) -> Int? {
        switch result {
        case let .claimed(_, amount):
            max(existingExpectation ?? 0, visibleBalanceBeforeRequest + amount)
        case .alreadyHandled:
            existingExpectation ?? visibleBalanceBeforeRequest
        case .markedExistingUser, .pendingFirstPet, .readyToClaim, .persistenceFailed:
            nil
        }
    }
}

enum OnboardingJourneyCoordinator {
    enum InitialPetChoice: String, Sendable {
        case createNow
        case deferred
    }

    enum Key {
        static let journeyStartedAt = "ohanaStarterJourneyStartedAtV1"
        static let firstHumanID = "ohanaStarterFirstHumanIDV1"
        static let initialPetChoice = "ohanaStarterInitialPetChoiceV1"
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
        if didBegin {
            defaults.removeObject(forKey: Key.firstHumanID)
            defaults.removeObject(forKey: Key.initialPetChoice)
        }
        if defaults.object(forKey: Key.journeyStartedAt) == nil {
            defaults.set(now.timeIntervalSince1970, forKey: Key.journeyStartedAt)
            AppPerformanceMonitor.shared.record("onboarding_human_first_started", valueMS: 0)
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
        let hasFreshJourney = defaults.bool(forKey: StarterGiftStorageKey.pending)
            || StarterGiftService.shouldShowCeremony(defaults: defaults)
        guard hasOnboarded || hasFreshJourney else {
            return OnboardingJourneyEvaluation(phase: .preOnboarding, starterGiftResult: .alreadyHandled)
        }

        let result = StarterGiftService.evaluateEligibility(
            activeHumanID: activeHumanID,
            context: context,
            defaults: defaults,
            projectionManager: projectionManager
        )

        if result == .markedExistingUser {
            defaults.set(true, forKey: Key.roadmapPromptSeen)
            return OnboardingJourneyEvaluation(phase: .existingUser, starterGiftResult: result)
        }

        return OnboardingJourneyEvaluation(
            phase: currentPhase(
                hasOnboarded: hasOnboarded,
                activeHumanID: activeHumanID,
                context: context,
                defaults: defaults
            ),
            starterGiftResult: result
        )
    }

    @MainActor
    static func currentPhase(
        hasOnboarded: Bool,
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) -> OnboardingJourneyPhase {
        if StarterGiftService.shouldShowCeremony(defaults: defaults) {
            return .starterGiftReady(amount: StarterGiftService.giftAmount)
        }

        if defaults.bool(forKey: StarterGiftStorageKey.pending) {
            // Upgrade recovery: an unfinished legacy journey with a Pet must
            // not be forced to create a Human before claiming its existing gift.
            if hasActivePet(context: context) {
                return .starterGiftReady(amount: StarterGiftService.giftAmount)
            }
            guard hasActiveHuman(context: context) else { return .needsHumanName }

            switch initialPetChoice(defaults: defaults) {
            case .createNow:
                return .petCreation
            case .deferred:
                return .awaitingPet
            case nil:
                // Completing onboarding without a Pet is itself a defer action.
                return hasOnboarded ? .awaitingPet : .petChoice
            }
        }

        return .complete
    }

    @MainActor
    static func currentPhase(
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) -> OnboardingJourneyPhase {
        currentPhase(
            hasOnboarded: true,
            activeHumanID: activeHumanID,
            context: context,
            defaults: defaults
        )
    }

    @MainActor
    static func markFirstHumanCreated(
        _ id: UUID,
        defaults: UserDefaults = .standard
    ) {
        guard defaults.bool(forKey: StarterGiftStorageKey.pending) else { return }
        defaults.set(id.uuidString, forKey: Key.firstHumanID)
        AppPerformanceMonitor.shared.record("onboarding_first_human_created", valueMS: 0)
    }

    @MainActor
    static func markPetCreationStarted(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: StarterGiftStorageKey.pending) else { return }
        defaults.set(InitialPetChoice.createNow.rawValue, forKey: Key.initialPetChoice)
        AppPerformanceMonitor.shared.record("onboarding_pet_creation_started", valueMS: 0)
    }

    @MainActor
    static func markPetDeferred(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: StarterGiftStorageKey.pending) else { return }
        defaults.set(InitialPetChoice.deferred.rawValue, forKey: Key.initialPetChoice)
        AppPerformanceMonitor.shared.record("onboarding_pet_deferred", valueMS: 0)
    }

    @MainActor
    static func claimStarterGift(
        activeHumanID: String?,
        context: ModelContext,
        defaults: UserDefaults = .standard,
        projectionManager: QuestManager? = nil
    ) -> StarterGiftService.Result {
        StarterGiftService.claimStarterGift(
            activeHumanID: activeHumanID,
            context: context,
            defaults: defaults,
            projectionManager: projectionManager
        )
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
        guard defaults.bool(forKey: StarterGiftStorageKey.claimed) else { return }
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
    static func markRoadmapPromptSeen(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Key.roadmapPromptSeen) else { return }
        defaults.set(true, forKey: Key.roadmapPromptSeen)
        AppPerformanceMonitor.shared.record("growth_roadmap_prompt_seen", valueMS: 0)
    }

    @MainActor
    static func resetForDebug(defaults: UserDefaults = .standard) {
        StarterGiftService.resetForDebug(defaults: defaults)
        defaults.removeObject(forKey: Key.firstHumanID)
        defaults.removeObject(forKey: Key.initialPetChoice)
        defaults.removeObject(forKey: "ohanaStarterFirstCareCompletedV1")
        defaults.removeObject(forKey: Key.roadmapPromptSeen)
        defaults.removeObject(forKey: Key.existingUserUpgradeSeen)
        defaults.removeObject(forKey: Key.journeyStartedAt)
    }

    private static func initialPetChoice(defaults: UserDefaults) -> InitialPetChoice? {
        defaults.string(forKey: Key.initialPetChoice).flatMap(InitialPetChoice.init(rawValue:))
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
    private static func hasActiveHuman(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Human>(
            predicate: #Predicate<Human> { human in
                human.passedAwayDate == nil
            }
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch starter active human").isEmpty == false
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
    func markFirstHumanCreated(_ id: UUID)
    func markPetCreationStarted()
    func markPetDeferred()
    func claimStarterGift(
        activeHumanID: String?,
        context: ModelContext,
        projectionManager: QuestManager?
    ) -> StarterGiftService.Result
    func markStarterCeremonySeen()
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

    func markFirstHumanCreated(_ id: UUID) {
        OnboardingJourneyCoordinator.markFirstHumanCreated(id)
    }

    func markPetCreationStarted() {
        OnboardingJourneyCoordinator.markPetCreationStarted()
    }

    func markPetDeferred() {
        OnboardingJourneyCoordinator.markPetDeferred()
    }

    func claimStarterGift(
        activeHumanID: String?,
        context: ModelContext,
        projectionManager: QuestManager?
    ) -> StarterGiftService.Result {
        OnboardingJourneyCoordinator.claimStarterGift(
            activeHumanID: activeHumanID,
            context: context,
            projectionManager: projectionManager
        )
    }

    func markStarterCeremonySeen() {
        OnboardingJourneyCoordinator.markStarterCeremonySeen()
    }

    func markRoadmapPromptSeen() {
        OnboardingJourneyCoordinator.markRoadmapPromptSeen()
    }
}

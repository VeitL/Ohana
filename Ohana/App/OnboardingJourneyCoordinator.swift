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
    case needsPrimaryHuman
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
        static let firstCareCompleted = "ohanaStarterFirstCareCompletedV1"
        static let roadmapPromptSeen = "ohanaStarterRoadmapPromptSeenV1"
        static let existingUserUpgradeSeen = "ohanaExistingUserGrowthUpgradeSeenV1"
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
        context _: ModelContext,
        defaults: UserDefaults = .standard
    ) -> OnboardingJourneyPhase {
        if StarterGiftService.shouldShowCeremony(defaults: defaults) {
            return .starterGiftReadyForCeremony(amount: StarterGiftService.giftAmount)
        }

        if activeHumanID?.isEmpty != false {
            return defaults.bool(forKey: StarterGiftService.Key.pending) ? .starterGiftPending : .needsPrimaryHuman
        }

        return .complete
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
    static func markStarterCeremonySeen(defaults: UserDefaults = .standard) {
        StarterGiftService.markCeremonySeen(defaults: defaults)
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
    }

    @MainActor
    private static func hasRecordedCareBusinessFact(context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<CareLedgerEvent>(
            predicate: #Predicate<CareLedgerEvent> { event in
                event.actionType != "starterGift" && event.eventKind != "coconut"
            }
        )
        descriptor.fetchLimit = 1
        return fetchModelsOrLog(descriptor, context: context, operation: "fetch recorded care business facts").isEmpty == false
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
    func evaluate(
        hasOnboarded: Bool,
        activeHumanID: String?,
        context: ModelContext,
        projectionManager: QuestManager?
    ) -> OnboardingJourneyEvaluation
    func interruptedOnboardingPrimaryHumanID(context: ModelContext) -> String?
    func markStarterCeremonySeen()
    func markFirstCareCompleted()
    func markRoadmapPromptSeen()
}

struct LiveOnboardingJourneyCoordinator: OnboardingJourneyCoordinating {
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

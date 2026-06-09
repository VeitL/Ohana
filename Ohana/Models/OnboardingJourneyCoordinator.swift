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
        defaults: UserDefaults = .standard
    ) -> OnboardingJourneyEvaluation {
        guard hasOnboarded else {
            return OnboardingJourneyEvaluation(phase: .preOnboarding, starterGiftResult: .alreadyHandled)
        }

        let result = StarterGiftService.prepareOrClaim(
            activeHumanID: activeHumanID,
            context: context,
            defaults: defaults
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
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) -> OnboardingJourneyPhase {
        if activeHumanID?.isEmpty != false {
            return defaults.bool(forKey: StarterGiftService.Key.pending) ? .starterGiftPending : .needsPrimaryHuman
        }

        if StarterGiftService.shouldShowCeremony(defaults: defaults) {
            return .starterGiftReadyForCeremony(amount: StarterGiftService.giftAmount)
        }

        return .complete
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
        return ((try? context.fetch(descriptor)) ?? []).isEmpty == false
    }
}

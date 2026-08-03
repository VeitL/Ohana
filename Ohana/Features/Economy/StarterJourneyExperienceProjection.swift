//
//  StarterJourneyExperienceProjection.swift
//  Ohana
//
//  Mode-independent value projection for the two shared starter milestones.
//

import Foundation

nonisolated enum StarterJourneyGiftExperienceState: String, Equatable, Sendable {
    case unavailable
    case waitingForHuman
    case claimable
    case claimed

    var isResolved: Bool {
        self == .claimed
    }
}

nonisolated struct StarterJourneyExperienceProjection: Equatable, Sendable {
    let isReady: Bool
    let giftState: StarterJourneyGiftExperienceState
    let humanProfileState: HouseholdStarterJourneyTaskState?

    static let empty = StarterJourneyExperienceProjection(
        isReady: false,
        giftState: .unavailable,
        humanProfileState: nil
    )

    static func make(
        giftResult: StarterGiftService.Result,
        starterJourney: HouseholdStarterJourneySnapshot?
    ) -> StarterJourneyExperienceProjection {
        StarterJourneyExperienceProjection(
            isReady: true,
            giftState: giftState(for: giftResult),
            humanProfileState: starterJourney?.state(for: .humanProfile)
        )
    }

    var completedTaskCount: Int {
        (giftState.isResolved ? 1 : 0) + (humanProfileState?.isClaimed == true ? 1 : 0)
    }

    let totalTaskCount = 2

    var isComplete: Bool {
        completedTaskCount == totalTaskCount
    }

    var shouldShowCommonJourney: Bool {
        isReady && !isComplete && (
            giftState != .unavailable || humanProfileState?.status != .locked
        )
    }

    var totalRewardCoconuts: Int {
        StarterGiftPolicy.giftAmount + HouseholdStarterJourneyTask.humanProfile.rewardCoconuts
    }

    var resolvedRewardCoconuts: Int {
        (giftState.isResolved ? StarterGiftPolicy.giftAmount : 0)
            + (humanProfileState?.isClaimed == true
                ? HouseholdStarterJourneyTask.humanProfile.rewardCoconuts
                : 0)
    }

    private static func giftState(
        for result: StarterGiftService.Result
    ) -> StarterJourneyGiftExperienceState {
        switch result {
        case .readyToClaim:
            .claimable
        case .claimed, .alreadyHandled, .markedExistingUser:
            .claimed
        case .waitingForFirstHuman:
            .waitingForHuman
        case .persistenceFailed:
            .unavailable
        }
    }
}

nonisolated enum StarterPetSuggestionStorageKey {
    static let resolved = "ohanaStarterPetSuggestionResolvedV1"
}

nonisolated enum StarterPetSuggestionPolicy {
    private static let freshJourneyStartedAtKey = "ohanaStarterJourneyStartedAtV1"

    static func shouldShow(
        hasOnboarded: Bool,
        hasActivePet: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        hasOnboarded
            && defaults.object(forKey: freshJourneyStartedAtKey) != nil
            && !defaults.bool(forKey: StarterPetSuggestionStorageKey.resolved)
            && !hasActivePet
    }

    static func markResolved(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: StarterPetSuggestionStorageKey.resolved)
    }

    static func reset(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: StarterPetSuggestionStorageKey.resolved)
    }
}

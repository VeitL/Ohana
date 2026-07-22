//
//  HouseholdStarterJourneyPolicy.swift
//  Ohana
//
//  Stable value types for the household-level starter journey.
//

import Foundation

nonisolated enum HouseholdStarterJourneyTask: String, CaseIterable, Identifiable, Sendable {
    case humanProfile
    case petProfile
    case identityProtection
    case healthProtection
    case carePlan
    case firstCare

    static let journeyKey = "household-starter-v1"

    var id: String {
        "\(Self.journeyKey)-\(rawValue)"
    }

    var rewardCoconuts: Int {
        switch self {
        case .humanProfile, .petProfile:
            100
        case .identityProtection:
            60
        case .healthProtection:
            80
        case .carePlan:
            40
        case .firstCare:
            20
        }
    }

    var checkpoints: [HouseholdStarterJourneyCheckpoint] {
        switch self {
        case .humanProfile:
            [.humanAppearance, .humanLifeStage, .humanBodyProfile, .humanPersonalityContext]
        case .petProfile:
            [.petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare]
        case .identityProtection:
            [.petIdentityDocuments, .petEmergencyContact]
        case .healthProtection:
            [.petHealthProtection]
        case .carePlan:
            [.acceptedRecommendedCarePlan]
        case .firstCare:
            []
        }
    }

    /// Retired checkpoints stay readable for old explicit answers, but never
    /// appear as new questions or receive new writes.
    var compatibilityCheckpoints: [HouseholdStarterJourneyCheckpoint] {
        switch self {
        case .humanProfile: [.humanOptionalDetails]
        case .petProfile, .identityProtection, .healthProtection, .carePlan, .firstCare: []
        }
    }
}

nonisolated enum HouseholdStarterJourneyResolution: String, Codable, CaseIterable, Sendable {
    case reviewed
    case unknown
    case notApplicable
    case preferNotToSay
}

nonisolated enum HouseholdStarterJourneyCheckpoint: String, Codable, CaseIterable, Identifiable, Sendable {
    case humanAppearance
    case humanLifeStage
    case humanBodyProfile
    case humanPersonalityContext
    /// Read-only legacy checkpoint retained for existing stores.
    case humanOptionalDetails
    case petLifeStage
    case petBodyProfile
    case petPersonalityAppearance
    case petDailyCare
    case petIdentityDocuments
    case petEmergencyContact
    case petHealthProtection
    case acceptedRecommendedCarePlan

    var id: String { rawValue }

    var task: HouseholdStarterJourneyTask {
        switch self {
        case .humanAppearance, .humanLifeStage, .humanBodyProfile,
             .humanPersonalityContext, .humanOptionalDetails:
            .humanProfile
        case .petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare:
            .petProfile
        case .petIdentityDocuments, .petEmergencyContact:
            .identityProtection
        case .petHealthProtection:
            .healthProtection
        case .acceptedRecommendedCarePlan:
            .carePlan
        }
    }

    var targetKind: HouseholdStarterJourneyTargetKind {
        switch self {
        case .humanAppearance, .humanLifeStage, .humanBodyProfile,
             .humanPersonalityContext, .humanOptionalDetails:
            .human
        case .petLifeStage, .petBodyProfile, .petPersonalityAppearance,
             .petDailyCare, .petIdentityDocuments, .petEmergencyContact,
             .petHealthProtection, .acceptedRecommendedCarePlan:
            .pet
        }
    }

    var allowedResolutions: Set<HouseholdStarterJourneyResolution> {
        switch self {
        case .humanAppearance:
            [.reviewed, .preferNotToSay]
        case .humanLifeStage, .humanBodyProfile, .humanPersonalityContext,
             .humanOptionalDetails:
            [.reviewed, .unknown, .notApplicable, .preferNotToSay]
        case .petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare,
             .petIdentityDocuments, .petEmergencyContact, .petHealthProtection:
            [.reviewed, .unknown, .notApplicable, .preferNotToSay]
        case .acceptedRecommendedCarePlan:
            [.reviewed]
        }
    }
}

nonisolated enum HouseholdStarterJourneyResolutionResult: Equatable, Sendable {
    case recorded(
        task: HouseholdStarterJourneyTask,
        checkpoint: HouseholdStarterJourneyCheckpoint,
        resolution: HouseholdStarterJourneyResolution
    )
    case unchanged(
        task: HouseholdStarterJourneyTask,
        checkpoint: HouseholdStarterJourneyCheckpoint,
        resolution: HouseholdStarterJourneyResolution
    )
    case invalidCheckpoint
    case missingSubject
    case missingHuman
    case requiresHumanSelection
    case persistenceFailed

    var didSucceed: Bool {
        switch self {
        case .recorded, .unchanged:
            true
        case .invalidCheckpoint, .missingSubject, .missingHuman,
             .requiresHumanSelection, .persistenceFailed:
            false
        }
    }
}

nonisolated struct HouseholdStarterJourneyTaskState: Identifiable, Equatable, Sendable {
    nonisolated enum Status: String, Equatable, Sendable {
        case locked
        case actionRequired
        case claimable
        case claimed
    }

    let task: HouseholdStarterJourneyTask
    let status: Status
    let rewardCoconuts: Int
    let completedCheckpointCount: Int
    let requiredCheckpointCount: Int
    let completionPercent: Int?
    let requiredCompletionPercent: Int?
    let targetID: UUID?
    let completedCheckpoints: Set<HouseholdStarterJourneyCheckpoint>
    let checkpointResolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution]
    var availableResolutionCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = []

    init(
        task: HouseholdStarterJourneyTask,
        status: Status,
        rewardCoconuts: Int,
        completedCheckpointCount: Int,
        requiredCheckpointCount: Int,
        completionPercent: Int? = nil,
        requiredCompletionPercent: Int? = nil,
        targetID: UUID?,
        completedCheckpoints: Set<HouseholdStarterJourneyCheckpoint>,
        checkpointResolutions: [HouseholdStarterJourneyCheckpoint: HouseholdStarterJourneyResolution],
        availableResolutionCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = []
    ) {
        self.task = task
        self.status = status
        self.rewardCoconuts = rewardCoconuts
        self.completedCheckpointCount = completedCheckpointCount
        self.requiredCheckpointCount = requiredCheckpointCount
        self.completionPercent = completionPercent
        self.requiredCompletionPercent = requiredCompletionPercent
        self.targetID = targetID
        self.completedCheckpoints = completedCheckpoints
        self.checkpointResolutions = checkpointResolutions
        self.availableResolutionCheckpoints = availableResolutionCheckpoints
    }

    var id: String { task.id }
    var isClaimable: Bool { status == .claimable }
    var isClaimed: Bool { status == .claimed }
}

nonisolated struct HouseholdStarterJourneyQualificationFacts: Equatable, Sendable {
    let targetPetID: UUID?
    let hasProtectionDocument: Bool
    let hasInsurance: Bool
    let hasPreventiveHealthRecord: Bool
    let hasExplicitCarePlan: Bool
    let hasDefaultRecommendedCarePlan: Bool

    static let empty = HouseholdStarterJourneyQualificationFacts(
        targetPetID: nil,
        hasProtectionDocument: false,
        hasInsurance: false,
        hasPreventiveHealthRecord: false,
        hasExplicitCarePlan: false,
        hasDefaultRecommendedCarePlan: false
    )
}

nonisolated struct HouseholdStarterJourneyCarePlanEvidence: Equatable, Sendable {
    let hasExplicitCarePlan: Bool
    let hasDefaultRecommendedCarePlan: Bool

    static let empty = HouseholdStarterJourneyCarePlanEvidence(
        hasExplicitCarePlan: false,
        hasDefaultRecommendedCarePlan: false
    )
}

nonisolated struct HouseholdStarterJourneySnapshot: Equatable, Sendable {
    let isEnabled: Bool
    let activeHumanID: UUID?
    let taskStates: [HouseholdStarterJourneyTaskState]
    let visibleTaskStates: [HouseholdStarterJourneyTaskState]

    static let disabled = HouseholdStarterJourneySnapshot(
        isEnabled: false,
        activeHumanID: nil,
        taskStates: HouseholdStarterJourneyTask.allCases.map {
            HouseholdStarterJourneyTaskState(
                task: $0,
                status: .locked,
                rewardCoconuts: $0.rewardCoconuts,
                completedCheckpointCount: 0,
                requiredCheckpointCount: HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: $0),
                targetID: nil,
                completedCheckpoints: [],
                checkpointResolutions: [:]
            )
        },
        visibleTaskStates: []
    )

    var totalRewardCoconuts: Int {
        taskStates.reduce(0) { $0 + $1.rewardCoconuts }
    }

    var claimedRewardCoconuts: Int {
        taskStates.filter(\.isClaimed).reduce(0) { $0 + $1.rewardCoconuts }
    }

    func state(for task: HouseholdStarterJourneyTask) -> HouseholdStarterJourneyTaskState? {
        taskStates.first { $0.task == task }
    }
}

nonisolated enum HouseholdStarterJourneyClaimResult: Equatable, Sendable {
    case claimed(task: HouseholdStarterJourneyTask, humanID: UUID, amount: Int)
    case alreadyClaimed(task: HouseholdStarterJourneyTask, amount: Int)
    case notEligible(task: HouseholdStarterJourneyTask)
    case missingHuman(task: HouseholdStarterJourneyTask)
    case requiresHumanSelection(task: HouseholdStarterJourneyTask)
    case persistenceFailed(task: HouseholdStarterJourneyTask)

    var didClaim: Bool {
        if case .claimed = self { return true }
        return false
    }

    var completesRequest: Bool {
        switch self {
        case .claimed, .alreadyClaimed:
            true
        case .notEligible, .missingHuman, .requiresHumanSelection, .persistenceFailed:
            false
        }
    }
}

nonisolated enum HouseholdStarterJourneyTargetKind: String, Codable, Sendable {
    case household
    case human
    case pet
}

nonisolated enum HouseholdStarterJourneyPolicy {
    static let totalRewardCoconuts = HouseholdStarterJourneyTask.allCases.reduce(0) {
        $0 + $1.rewardCoconuts
    }
    static let maximumVisibleTaskCount = 3

    static func requiredCheckpointCount(for task: HouseholdStarterJourneyTask) -> Int {
        switch task {
        case .humanProfile:
            3
        case .petProfile:
            3
        case .identityProtection:
            2
        case .healthProtection, .carePlan, .firstCare:
            1
        }
    }
}

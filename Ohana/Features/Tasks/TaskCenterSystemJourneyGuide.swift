//
//  TaskCenterSystemJourneyGuide.swift
//  Ohana
//
//  Pure question-flow state for the household starter journey.
//

import Foundation

nonisolated enum TaskCenterSystemJourneySheetMode: Equatable, Sendable {
    case questions
    case completedThisSession
    case rewardClaim

    static func resolve(
        openedAs presentationState: TaskCenterSystemJourneyPresentationState?,
        guideIsComplete: Bool
    ) -> TaskCenterSystemJourneySheetMode {
        if presentationState == .rewardReady {
            return .rewardClaim
        }
        return guideIsComplete ? .completedThisSession : .questions
    }
}

nonisolated enum TaskCenterSystemJourneyEditorCompletionPolicy {
    static func shouldDismissEditor(
        task: HouseholdStarterJourneyTask,
        checkpoint: HouseholdStarterJourneyCheckpoint?,
        state: HouseholdStarterJourneyTaskState?
    ) -> Bool {
        guard let state, state.task == task else { return false }
        if let checkpoint {
            return state.completedCheckpoints.contains(checkpoint)
        }
        guard task == .firstCare else { return false }
        return state.status == .claimable || state.status == .claimed
    }
}

nonisolated struct TaskCenterSystemJourneyGuide: Equatable, Sendable {
    nonisolated struct Question: Identifiable, Equatable, Sendable {
        let id: String
        let checkpoint: HouseholdStarterJourneyCheckpoint?
    }

    let task: HouseholdStarterJourneyTask
    let requiredCheckpointCount: Int
    let persistedCompletedCheckpointCount: Int
    let completedCheckpoints: Set<HouseholdStarterJourneyCheckpoint>
    let availableResolutionCheckpoints: Set<HouseholdStarterJourneyCheckpoint>

    init(
        task: HouseholdStarterJourneyTask,
        requiredCheckpointCount: Int? = nil,
        persistedCompletedCheckpointCount: Int = 0,
        completedCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = [],
        availableResolutionCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = []
    ) {
        self.task = task
        self.requiredCheckpointCount = requiredCheckpointCount
            ?? HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task)
        self.persistedCompletedCheckpointCount = max(0, persistedCompletedCheckpointCount)
        self.completedCheckpoints = completedCheckpoints
        self.availableResolutionCheckpoints = availableResolutionCheckpoints
    }

    init(
        state: HouseholdStarterJourneyTaskState,
        locallyCompletedCheckpoints: Set<HouseholdStarterJourneyCheckpoint> = []
    ) {
        self.init(
            task: state.task,
            requiredCheckpointCount: state.requiredCheckpointCount,
            persistedCompletedCheckpointCount: state.completedCheckpointCount,
            completedCheckpoints: state.completedCheckpoints.union(locallyCompletedCheckpoints),
            availableResolutionCheckpoints: state.availableResolutionCheckpoints
        )
    }

    var questions: [Question] {
        let checkpoints = task.checkpoints
        guard !checkpoints.isEmpty else {
            return [Question(id: "action-\(task.rawValue)", checkpoint: nil)]
        }
        return checkpoints.map {
            Question(id: "checkpoint-\($0.rawValue)", checkpoint: $0)
        }
    }

    var completedCheckpointCount: Int {
        min(
            requiredCheckpointCount,
            max(persistedCompletedCheckpointCount, completedCheckpoints.count)
        )
    }

    var isComplete: Bool {
        completedCheckpointCount >= requiredCheckpointCount
    }

    var initialQuestionIndex: Int {
        questions.firstIndex(where: { !isCompleted($0) }) ?? 0
    }

    func isCompleted(_ question: Question) -> Bool {
        guard let checkpoint = question.checkpoint else { return false }
        return completedCheckpoints.contains(checkpoint)
    }

    func allowedResolutions(for question: Question) -> [HouseholdStarterJourneyResolution] {
        guard let checkpoint = question.checkpoint,
              availableResolutionCheckpoints.contains(checkpoint) else {
            return []
        }
        let stableOrder: [HouseholdStarterJourneyResolution] = [
            .reviewed,
            .unknown,
            .notApplicable,
            .preferNotToSay
        ]
        return stableOrder.filter(checkpoint.allowedResolutions.contains)
    }

    func nextIncompleteQuestionIndex(after index: Int) -> Int? {
        guard !questions.isEmpty, !isComplete else { return nil }
        let clampedIndex = min(max(index, 0), questions.count - 1)
        let later = questions.indices.dropFirst(clampedIndex + 1)
        let earlier = questions.indices.prefix(clampedIndex + 1)
        return (Array(later) + Array(earlier)).first { !isCompleted(questions[$0]) }
    }

    func systemDestination(for question: Question) -> TaskCenterSystemDestination {
        switch question.checkpoint {
        case .humanAppearance, .humanOptionalDetails:
            .completeHumanProfile
        case .petLifeStage, .petBodyProfile, .petPersonalityAppearance:
            .completeFirstPetProfile
        case .petDailyCare:
            .configureFirstCarePlan
        case .petIdentityDocuments:
            .confirmPetIdentityProtection
        case .petEmergencyContact:
            .completeFirstPetProfile
        case .petHealthProtection:
            .confirmPetPreventiveCare
        case .acceptedRecommendedCarePlan:
            .configureFirstCarePlan
        case nil:
            switch task {
            case .humanProfile: .completeHumanProfile
            case .petProfile: .completeFirstPetProfile
            case .identityProtection: .confirmPetIdentityProtection
            case .healthProtection: .confirmPetPreventiveCare
            case .carePlan: .configureFirstCarePlan
            case .firstCare: .recordFirstCare
            }
        }
    }
}

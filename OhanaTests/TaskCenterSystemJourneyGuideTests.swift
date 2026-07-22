import Foundation
import Testing
@testable import Ohana

struct TaskCenterSystemJourneyGuideTests {
    @Test func everyStarterTaskProducesAStableQuestionFlow() {
        let expected: [HouseholdStarterJourneyTask: [HouseholdStarterJourneyCheckpoint?]] = [
            .humanProfile: [
                .humanAppearance,
                .humanLifeStage,
                .humanBodyProfile,
                .humanPersonalityContext
            ],
            .petProfile: [.petLifeStage, .petBodyProfile, .petPersonalityAppearance, .petDailyCare],
            .identityProtection: [.petIdentityDocuments, .petEmergencyContact],
            .healthProtection: [.petHealthProtection],
            .carePlan: [.acceptedRecommendedCarePlan],
            .firstCare: [nil]
        ]

        for task in HouseholdStarterJourneyTask.allCases {
            let guide = TaskCenterSystemJourneyGuide(task: task)
            #expect(guide.questions.map(\.checkpoint) == expected[task])
            #expect(guide.requiredCheckpointCount == HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task))
        }
    }

    @Test func petProfileCompletesAfterAnyThreeQuestionsAndSkipsAnsweredCards() {
        let completed: Set<HouseholdStarterJourneyCheckpoint> = [
            .petLifeStage,
            .petPersonalityAppearance
        ]
        let guide = TaskCenterSystemJourneyGuide(
            task: .petProfile,
            completedCheckpoints: completed,
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.petProfile.checkpoints)
        )

        #expect(guide.completedCheckpointCount == 2)
        #expect(guide.initialQuestionIndex == 1)
        #expect(guide.nextIncompleteQuestionIndex(after: 1) == 3)

        let completedGuide = TaskCenterSystemJourneyGuide(
            task: .petProfile,
            completedCheckpoints: completed.union([.petBodyProfile]),
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.petProfile.checkpoints)
        )
        #expect(completedGuide.isComplete)
        #expect(completedGuide.completedCheckpointCount == 3)
        #expect(completedGuide.nextIncompleteQuestionIndex(after: 1) == nil)
    }

    @Test func privacyChoicesStayCheckpointScopedAndFirstCareHasNoShortcut() throws {
        let human = TaskCenterSystemJourneyGuide(
            task: .humanProfile,
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )
        let appearance = try #require(human.questions.first)
        #expect(human.allowedResolutions(for: appearance) == [.reviewed, .preferNotToSay])

        let optionalDetails = try #require(human.questions.last)
        #expect(human.allowedResolutions(for: optionalDetails) == [.reviewed, .unknown, .notApplicable, .preferNotToSay])

        let firstCare = TaskCenterSystemJourneyGuide(task: .firstCare)
        let action = try #require(firstCare.questions.first)
        #expect(action.checkpoint == nil)
        #expect(firstCare.allowedResolutions(for: action).isEmpty)
        #expect(!firstCare.isComplete)
    }

    @Test func everyResolutionWhitelistUsesTheExplicitCheckpointPolicyInStableOrder() throws {
        let expected: [
            HouseholdStarterJourneyCheckpoint: [HouseholdStarterJourneyResolution]
        ] = [
            .humanAppearance: [.reviewed, .preferNotToSay],
            .humanLifeStage: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .humanBodyProfile: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .humanPersonalityContext: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .humanOptionalDetails: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petLifeStage: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petBodyProfile: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petPersonalityAppearance: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petDailyCare: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petIdentityDocuments: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petEmergencyContact: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .petHealthProtection: [.reviewed, .unknown, .notApplicable, .preferNotToSay],
            .acceptedRecommendedCarePlan: [.reviewed]
        ]

        for checkpoint in HouseholdStarterJourneyTask.allCases.flatMap(\.checkpoints) {
            let guide = TaskCenterSystemJourneyGuide(
                task: checkpoint.task,
                availableResolutionCheckpoints: [checkpoint]
            )
            let question = try #require(
                guide.questions.first(where: { $0.checkpoint == checkpoint })
            )
            #expect(guide.allowedResolutions(for: question) == expected[checkpoint])
        }
    }

    @Test func everyThreeOfFourPetProfileAnswerPathCompletesButEveryTwoAnswerPathStaysOpen() {
        let checkpoints = HouseholdStarterJourneyTask.petProfile.checkpoints

        for omitted in checkpoints {
            let completed = Set(checkpoints.filter { $0 != omitted })
            let guide = TaskCenterSystemJourneyGuide(
                task: .petProfile,
                completedCheckpoints: completed,
                availableResolutionCheckpoints: Set(checkpoints)
            )
            #expect(guide.completedCheckpointCount == 3)
            #expect(guide.isComplete)
            #expect(guide.nextIncompleteQuestionIndex(after: 0) == nil)
        }

        for firstIndex in checkpoints.indices {
            for secondIndex in checkpoints.indices where secondIndex > firstIndex {
                let guide = TaskCenterSystemJourneyGuide(
                    task: .petProfile,
                    completedCheckpoints: [checkpoints[firstIndex], checkpoints[secondIndex]],
                    availableResolutionCheckpoints: Set(checkpoints)
                )
                #expect(guide.completedCheckpointCount == 2)
                #expect(!guide.isComplete)
                let nextIndex = guide.nextIncompleteQuestionIndex(after: secondIndex)
                #expect(nextIndex != nil)
                if let nextIndex {
                    #expect(!guide.isCompleted(guide.questions[nextIndex]))
                }
            }
        }
    }

    @Test func incompleteQuestionNavigationClampsAndWrapsWithoutReopeningAnsweredCards() {
        let guide = TaskCenterSystemJourneyGuide(
            task: .humanProfile,
            completedCheckpoints: [.humanAppearance],
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )

        #expect(guide.initialQuestionIndex == 1)
        #expect(guide.nextIncompleteQuestionIndex(after: -100) == 1)
        #expect(guide.nextIncompleteQuestionIndex(after: 100) == 1)
    }

    @Test func persistedProgressAndLocalAnswersMergeWithoutExceedingRequirement() {
        let guide = TaskCenterSystemJourneyGuide(
            task: .humanProfile,
            persistedCompletedCheckpointCount: 1,
            completedCheckpoints: [.humanAppearance, .humanLifeStage, .humanBodyProfile],
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )

        #expect(guide.completedCheckpointCount == 3)
        #expect(guide.isComplete)
    }

    @Test func profileGuideReportsRealPercentageAndCompletesAtSeventyFivePercent() {
        let state = HouseholdStarterJourneyTaskState(
            task: .humanProfile,
            status: .actionRequired,
            rewardCoconuts: 100,
            completedCheckpointCount: 2,
            requiredCheckpointCount: 3,
            completionPercent: 50,
            requiredCompletionPercent: 75,
            targetID: UUID(),
            completedCheckpoints: [.humanAppearance, .humanLifeStage],
            checkpointResolutions: [:],
            availableResolutionCheckpoints: Set(HouseholdStarterJourneyTask.humanProfile.checkpoints)
        )

        let pending = TaskCenterSystemJourneyGuide(state: state)
        #expect(pending.completionPercent == 50)
        #expect(!pending.isComplete)

        let complete = TaskCenterSystemJourneyGuide(
            state: state,
            locallyCompletedCheckpoints: [.humanBodyProfile]
        )
        #expect(complete.completionPercent == 75)
        #expect(complete.isComplete)
    }

    @Test func eachQuestionRoutesToThePageThatCanAnswerIt() throws {
        let expected: [HouseholdStarterJourneyCheckpoint: TaskCenterSystemDestination] = [
            .humanAppearance: .completeHumanProfile,
            .humanLifeStage: .completeHumanProfile,
            .humanBodyProfile: .completeHumanProfile,
            .humanPersonalityContext: .completeHumanProfile,
            .petLifeStage: .completeFirstPetProfile,
            .petBodyProfile: .completeFirstPetProfile,
            .petPersonalityAppearance: .completeFirstPetProfile,
            .petDailyCare: .configureFirstCarePlan,
            .petIdentityDocuments: .confirmPetIdentityProtection,
            .petEmergencyContact: .completeFirstPetProfile,
            .petHealthProtection: .confirmPetPreventiveCare,
            .acceptedRecommendedCarePlan: .configureFirstCarePlan
        ]

        for checkpoint in HouseholdStarterJourneyTask.allCases.flatMap(\.checkpoints) {
            let guide = TaskCenterSystemJourneyGuide(task: checkpoint.task)
            let question = try #require(guide.questions.first(where: { $0.checkpoint == checkpoint }))
            #expect(guide.systemDestination(for: question) == expected[checkpoint])
        }

        let firstCare = TaskCenterSystemJourneyGuide(task: .firstCare)
        let firstCareQuestion = try #require(firstCare.questions.first)
        #expect(firstCare.systemDestination(for: firstCareQuestion) == .recordFirstCare)
    }

    @Test func recommendedCarePlanChoiceOnlyAppearsWhenTheServiceAllowsIt() throws {
        let unavailable = TaskCenterSystemJourneyGuide(task: .carePlan)
        let unavailableQuestion = try #require(unavailable.questions.first)
        #expect(unavailable.allowedResolutions(for: unavailableQuestion).isEmpty)

        let available = TaskCenterSystemJourneyGuide(
            task: .carePlan,
            availableResolutionCheckpoints: [.acceptedRecommendedCarePlan]
        )
        let availableQuestion = try #require(available.questions.first)
        #expect(available.allowedResolutions(for: availableQuestion) == [.reviewed])
    }

    @Test func actionRequiredSheetNeverHotSwitchesIntoRewardClaim() {
        #expect(
            TaskCenterSystemJourneySheetMode.resolve(
                openedAs: .actionRequired,
                guideIsComplete: true
            ) == .completedThisSession
        )
        #expect(
            TaskCenterSystemJourneySheetMode.resolve(
                openedAs: .rewardReady,
                guideIsComplete: true
            ) == .rewardClaim
        )
    }

    @Test func sheetModeCoversFreshCompletedAndRewardReadyPresentationPaths() {
        #expect(TaskCenterSystemJourneySheetMode.resolve(openedAs: nil, guideIsComplete: false) == .questions)
        #expect(TaskCenterSystemJourneySheetMode.resolve(openedAs: nil, guideIsComplete: true) == .completedThisSession)
        #expect(
            TaskCenterSystemJourneySheetMode.resolve(
                openedAs: .actionRequired,
                guideIsComplete: false
            ) == .questions
        )
    }

    @Test func rewardReadyStarterRowsClaimDirectlyWhileSetupAndStarterGiftStillOpenTheirDestinations() {
        let directClaimDestinations: [TaskCenterSystemDestination] = [
            .completeHumanProfile,
            .completeFirstPetProfile,
            .confirmPetIdentityProtection,
            .confirmPetPreventiveCare,
            .configureFirstCarePlan,
            .recordFirstCare
        ]

        for destination in directClaimDestinations {
            #expect(TaskCenterSystemJourneyRowActionPolicy.resolve(
                destination: destination,
                presentationState: .rewardReady
            ) == .claimReward)
            #expect(TaskCenterSystemJourneyRowActionPolicy.resolve(
                destination: destination,
                presentationState: .actionRequired
            ) == .openDestination)
        }

        #expect(TaskCenterSystemJourneyRowActionPolicy.resolve(
            destination: .claimStarterGift,
            presentationState: .rewardReady
        ) == .openDestination)
    }

    @Test func editorReturnsOnlyAfterItsRealCheckpointCompletes() {
        let documentState = makeState(
            task: .identityProtection,
            status: .actionRequired,
            completed: [.petIdentityDocuments]
        )
        #expect(TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .identityProtection,
            checkpoint: .petIdentityDocuments,
            state: documentState
        ))
        #expect(!TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .identityProtection,
            checkpoint: .petEmergencyContact,
            state: documentState
        ))

        let firstCareReady = makeState(task: .firstCare, status: .claimable)
        #expect(TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .firstCare,
            checkpoint: nil,
            state: firstCareReady
        ))
        #expect(!TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .firstCare,
            checkpoint: nil,
            state: makeState(task: .firstCare, status: .actionRequired)
        ))
        #expect(TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .firstCare,
            checkpoint: nil,
            state: makeState(task: .firstCare, status: .claimed)
        ))
        #expect(!TaskCenterSystemJourneyEditorCompletionPolicy.shouldDismissEditor(
            task: .healthProtection,
            checkpoint: .petHealthProtection,
            state: documentState
        ))
    }

    private func makeState(
        task: HouseholdStarterJourneyTask,
        status: HouseholdStarterJourneyTaskState.Status,
        completed: Set<HouseholdStarterJourneyCheckpoint> = []
    ) -> HouseholdStarterJourneyTaskState {
        HouseholdStarterJourneyTaskState(
            task: task,
            status: status,
            rewardCoconuts: task.rewardCoconuts,
            completedCheckpointCount: completed.count,
            requiredCheckpointCount: HouseholdStarterJourneyPolicy.requiredCheckpointCount(for: task),
            targetID: nil,
            completedCheckpoints: completed,
            checkpointResolutions: [:]
        )
    }
}

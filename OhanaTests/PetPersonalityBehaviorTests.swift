import Foundation
import Testing
@testable import Ohana

struct PetPersonalityPresentationTests {
    @Test func replacingPrimaryPreservesOnlySecondaryTags() {
        let updated = PetPrimaryPersonalitySelection.replacingPrimary(
            in: ["curious", "clingy", "smart"],
            with: "foodie"
        )

        #expect(updated == ["foodie", "clingy", "smart"])
    }

    @Test func personalitySelectionIsOptionalAndCappedAtThreeUniqueValues() {
        #expect(PetPrimaryPersonalitySelection.normalized([]).isEmpty)
        #expect(
            PetPrimaryPersonalitySelection.normalized(["curious", "lazy", "curious", "smart", "foodie"])
                == ["curious", "lazy", "smart"]
        )
    }

    @Test func creationCatalogUsesTheCuratedTwentyChoicesWithoutChangingEditorCatalog() {
        #expect(PetPersonalityTag.creationChoices.map(\.id) == [
            "curious", "lazy", "energetic", "clingy", "smart",
            "toy", "foodie", "drama", "clean", "shy",
            "brave", "social", "gentle", "quiet", "stubborn",
            "vocal", "guardian", "independent", "loyal", "chill"
        ])
        #expect(PetPersonalityTag.primaryChoices.count == 8)
    }

    @Test func todayFocusUsesStablePetOrderInsteadOfPersonality() {
        let quiet = Pet(name: "Quiet", species: "猫")
        quiet.personalityTagsRaw = "quiet"
        let playful = Pet(name: "Playful", species: "猫")
        playful.personalityTagsRaw = "energetic,playful"

        let quests = IslandQuestEngine.todayQuests(
            pets: [quiet, playful],
            reminders: [],
            includesPlants: false,
            questProgress: TodayFocusQuestProgress(
                isPetWizardCompleted: true,
                isFirstMealRecorded: true,
                isThemeColorSet: true
            )
        )

        #expect(quests.first { $0.id.hasPrefix("q_play_") }?.targetPetId == quiet.id)
    }

    @Test func primaryPersonalityChangesCareReactionCopy() {
        let energetic = PetPersonalityCareReaction.line(
            petName: "Mochi",
            primaryTagID: "energetic",
            l: L10n("en")
        )
        let lazy = PetPersonalityCareReaction.line(
            petName: "Mochi",
            primaryTagID: "lazy",
            l: L10n("en")
        )

        #expect(energetic != lazy)
        #expect(energetic.contains("battery"))
        #expect(lazy.contains("lounging"))
    }

    @Test func completionTriggerAcceptsWritesAndRejectsSettingsOrDeletes() throws {
        let petID = UUID()
        let feed = PetCareCompletionTrigger.resolve(
            DomainMutationResult(command: .feedLog(petID: petID, source: "manual"))
        )
        let settings = PetCareCompletionTrigger.resolve(
            DomainMutationResult(command: .feedSettings(petID: petID))
        )
        let deletion = PetCareCompletionTrigger.resolve(
            DomainMutationResult(command: .waterLog(petID: petID, source: "delete"))
        )
        let noOp = PetCareCompletionTrigger.resolve(
            DomainMutationResult(
                command: .quickCare(entityID: petID, action: "play"),
                wroteBusinessFact: false
            )
        )

        #expect(feed == PetCareCompletionTrigger(petID: petID, kind: .feed))
        #expect(settings == nil)
        #expect(deletion == nil)
        #expect(noOp == nil)
    }
}

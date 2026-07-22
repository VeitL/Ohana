import Foundation
import Testing
@testable import Ohana

struct MemberProfileCompletenessPolicyTests {
    @Test func localTaskAttributionNeverControlsProfileEditing() {
        #expect(HumanProfileEditPolicy.canEdit(hasPassedAway: false))
        #expect(!HumanProfileEditPolicy.canEdit(hasPassedAway: true))
    }

    @Test func humanUsesFourEqualCategoriesAndIgnoresDefaults() {
        let human = Human(name: "Ada")

        #expect(MemberProfileCompletenessPolicy.human(human).completionPercent == 0)

        human.avatarEmoji = "🧑‍🚀"
        #expect(MemberProfileCompletenessPolicy.human(human).completionPercent == 25)

        human.birthday = Date(timeIntervalSince1970: 1_000_000)
        #expect(MemberProfileCompletenessPolicy.human(human).completionPercent == 50)

        human.genderIdentityRaw = "private"
        #expect(MemberProfileCompletenessPolicy.human(human).completionPercent == 75)

        human.city = "Berlin"
        let complete = MemberProfileCompletenessPolicy.human(human)
        #expect(complete.completionPercent == 100)
        #expect(complete.completedCategoryCount == 4)
    }

    @Test func petUsesFourEqualCategoriesAndIgnoresNameSpeciesAndThemeDefaults() {
        let pet = Pet(name: "Mochi", species: "dog")

        #expect(MemberProfileCompletenessPolicy.pet(pet).completionPercent == 0)

        pet.homeDate = Date(timeIntervalSince1970: 2_000_000)
        #expect(MemberProfileCompletenessPolicy.pet(pet).completionPercent == 25)

        pet.coatColor = "cream"
        #expect(MemberProfileCompletenessPolicy.pet(pet).completionPercent == 50)

        pet.personalityTagsRaw = "gentle"
        #expect(MemberProfileCompletenessPolicy.pet(pet).completionPercent == 75)

        pet.dailyPortionGrams = 120
        #expect(MemberProfileCompletenessPolicy.pet(pet).completionPercent == 100)
    }

    @Test func plantUsesFourEqualCategoriesAndExcludesDefaultEnvironmentValues() {
        let plant = Plant(name: "Fern")

        #expect(MemberProfileCompletenessPolicy.plant(plant).completionPercent == 0)

        plant.species = "Boston fern"
        #expect(MemberProfileCompletenessPolicy.plant(plant).completionPercent == 25)

        plant.acquisitionSourceRaw = "Gift"
        #expect(MemberProfileCompletenessPolicy.plant(plant).completionPercent == 50)

        plant.windowDirection = .east
        #expect(MemberProfileCompletenessPolicy.plant(plant).completionPercent == 75)

        plant.potDiameterCm = 18
        let complete = MemberProfileCompletenessPolicy.plant(plant)
        #expect(complete.completionPercent == 100)
        #expect(complete.missingCategories.isEmpty)
    }

    @Test func explicitPrivacyChoicesCompleteCategoriesWithoutInventingProfileFacts() {
        let human = Human(name: "Private")
        let snapshot = MemberProfileCompletenessPolicy.human(
            human,
            explicitlyResolvedCategories: [
                .humanAppearance,
                .humanLifeStage,
                .humanBodyProfile
            ]
        )

        #expect(snapshot.completionPercent == 75)
        #expect(snapshot.reachesProfileThreshold)
        #expect(snapshot.explicitlyResolvedCategories.count == 3)
        #expect(snapshot.missingCategories == [.humanPersonalityContext])
    }

    @Test func legacyHumanOptionalCheckpointMapsToAllThreeFocusedOptionalCategories() {
        let humanID = UUID()
        let legacyKey = HouseholdStarterJourneyService.checkpointRecordKey(
            task: .humanProfile,
            checkpoint: .humanOptionalDetails,
            subjectID: humanID
        )

        let resolved = MemberProfileCompletionResolutionMapper.resolvedCategories(
            kind: .human,
            subjectID: humanID,
            resolutions: [legacyKey: .preferNotToSay]
        )

        #expect(resolved == [
            .humanLifeStage,
            .humanBodyProfile,
            .humanPersonalityContext
        ])
        #expect(MemberProfileCompletenessPolicy.evaluate(
            kind: .human,
            actualCategories: [],
            explicitlyResolvedCategories: resolved
        ).completionPercent == 75)
    }

    @Test func completionThresholdIsExactlyThreeOfFour() {
        for kind in [
            MemberProfileCompletionKind.human,
            .pet,
            .plant
        ] {
            let categories = MemberProfileCompletenessPolicy.categories(for: kind)
            for count in 0 ... 4 {
                let snapshot = MemberProfileCompletenessPolicy.evaluate(
                    kind: kind,
                    actualCategories: Set(categories.prefix(count))
                )
                #expect(snapshot.completionPercent == count * 25)
                #expect(snapshot.reachesProfileThreshold == (count >= 3))
            }
        }
    }
}

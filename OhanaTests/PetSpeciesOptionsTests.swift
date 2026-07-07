import Foundation
import Testing
@testable import Ohana

struct PetSpeciesOptionsTests {
    @Test func petSpeciesUsesCanonicalKeysWhileAcceptingLegacyRawValues() {
        #expect(Pet.canonicalSpeciesOptions == ["dog", "cat", "fish", "bird", "rabbit", "reptile", "hamster", "other"])
        #expect(Pet.canonicalSpeciesKey("狗") == "dog")
        #expect(Pet.canonicalSpeciesKey("犬") == "dog")
        #expect(Pet.canonicalSpeciesKey("dogs") == "dog")
        #expect(Pet.canonicalSpeciesKey("猫") == "cat")
        #expect(Pet.canonicalSpeciesKey("锦鲤") == "fish")
        #expect(Pet.canonicalSpeciesKey("aquarium") == "fish")
        #expect(Pet.canonicalSpeciesKey("兔子") == "rabbit")
        #expect(Pet.canonicalSpeciesKey("乌龟") == "reptile")
        #expect(Pet.canonicalSpeciesKey("turtle") == "reptile")
        #expect(Pet.canonicalSpeciesKey("爬宠") == "reptile")
        #expect(Pet.canonicalSpeciesKey("龙猫") == "hamster")
        #expect(Pet.canonicalSpeciesKey("其他") == "other")
    }

    @Test func petSpeciesDisplayAndVisualHelpersSupportCanonicalAndLegacyValues() {
        #expect(Pet.localizedSpeciesName("dog", l: L10n("en")) == "Dog")
        #expect(Pet.localizedSpeciesName("狗", l: L10n("de")) == "Hund")
        #expect(Pet.speciesEmoji(forSpecies: "dog") == "🐕")
        #expect(Pet.speciesEmoji(forSpecies: "狗") == "🐕")
        #expect(Pet.speciesSilhouetteSymbol(forSpecies: "cat") == "cat.fill")
        #expect(Pet.speciesSilhouetteSymbol(forSpecies: "猫") == "cat.fill")
    }

    @Test func petSpeciesCapabilityHelpersNormalizeLegacyAndLocalizedValues() {
        #expect(Pet.isDogSpecies("dog"))
        #expect(Pet.isDogSpecies("Dog"))
        #expect(Pet.isDogSpecies("狗"))
        #expect(Pet.isDogSpecies("犬"))
        #expect(!Pet.isDogSpecies("cat"))

        #expect(Pet.isCatSpecies("cat"))
        #expect(Pet.isCatSpecies("Cat"))
        #expect(Pet.isCatSpecies("猫"))
        #expect(!Pet.isCatSpecies("dog"))
    }

    @Test func petHealthPottyAlertsUseCanonicalSpeciesSemantics() {
        let staleDate = Date().addingTimeInterval(-48 * 60 * 60)

        for species in ["cat", "猫", "rabbit", "兔子", "hamster", "仓鼠"] {
            let pet = Pet(name: "Small friend", species: "dog")
            pet.species = species
            let source = PetHealthAlertSource(
                pet: pet,
                healthLogs: [],
                weightLogs: [],
                careLogs: [],
                pottyLogs: [PetPottyLog(date: staleDate, pet: pet)],
                walkLogs: [],
                documents: [],
                symptomLogs: [],
                heatCycleLogs: []
            )

            let alerts = PetHealthAlertEngine().scanAlerts(sources: [source])
            #expect(!alerts.contains { $0.type == HealthAlert.AlertType.noPotty })
        }

        let dog = Pet(name: "Dog friend", species: "dog")
        let dogSource = PetHealthAlertSource(
            pet: dog,
            healthLogs: [],
            weightLogs: [],
            careLogs: [],
            pottyLogs: [PetPottyLog(date: staleDate, pet: dog)],
            walkLogs: [],
            documents: [],
            symptomLogs: [],
            heatCycleLogs: []
        )

        let dogAlerts = PetHealthAlertEngine().scanAlerts(sources: [dogSource])
        #expect(dogAlerts.contains { $0.type == HealthAlert.AlertType.noPotty })
    }

    @Test func petBreedDatabaseAcceptsCanonicalSpeciesKeys() {
        #expect(PetBreedDatabase.breeds(for: "dog").contains { $0.name == "金毛寻回犬" })
        #expect(PetBreedDatabase.breeds(for: "cat").contains { $0.name == "布偶猫" })
        #expect(PetBreedDatabase.breeds(for: "rabbit").contains { $0.name == "荷兰兔" })
    }

    @Test func memberCreationDraftDefaultsToCanonicalPetSpeciesKey() {
        #expect(MemberCreationDraft(kind: .pet).species == "dog")
        #expect(Pet().species == "dog")
    }
}

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
        #expect(Pet.normalizedSpeciesStorageValue("Dog") == "dog")
        #expect(Pet.normalizedSpeciesStorageValue("Capybara") == "Capybara")
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

    @Test func memberCreationDraftDoesNotInferPetSpecies() {
        #expect(MemberCreationDraft(kind: .pet).species == "")
        #expect(Pet().species == "dog")
    }

    @Test func memberCreationShowsSpeciesAsVisibleNativeButtons() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let steps = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Members/Views/MemberCardCreationContentView+Steps.swift"),
            encoding: .utf8
        )
        let controls = try String(
            contentsOf: rootURL.appending(path: "Ohana/Features/Members/Views/MemberCardCreationContentView+Controls.swift"),
            encoding: .utf8
        )

        #expect(steps.contains("LazyVGrid(columns: petSpeciesGridColumns"))
        #expect(steps.contains("petSpeciesButton(species)"))
        #expect(!steps.contains("member-pet-species-picker"))
        #expect(controls.contains("member-pet-species-option-"))
        #expect(controls.contains(".buttonStyle(.borderedProminent)"))
        #expect(controls.contains(".buttonStyle(.bordered)"))
        #expect(controls.contains("isSelected ? cardSelectedForeground : cardForeground"))
        #expect(controls.contains("guard currentKey != nextKey else { return }"))
        #expect(steps.contains("selected, 3 maximum"))
    }

    @Test func automaticPetThemeIsStableAndExplicitSelectionOverridesIt() {
        var draft = MemberCreationDraft(kind: .pet)
        draft.name = "Momo"
        draft.species = "cat"
        draft.breed = "布偶猫"

        let automaticWithoutCoat = draft.normalizedThemeHex
        #expect(automaticWithoutCoat == draft.normalizedThemeHex)

        draft.coatColor = "海豹双色"
        #expect(draft.normalizedThemeHex == "4A2A10")

        draft.themeColorHex = "833471"
        draft.hasExplicitThemeColor = true
        #expect(draft.normalizedThemeHex == "833471")

        draft.coatColor = "蓝双色"
        #expect(draft.normalizedThemeHex == "833471")

        draft.hasExplicitThemeColor = false
        #expect(draft.normalizedThemeHex == "7A9AAF")
    }

    @Test func petCreationStepsPlaceRequiredGenderBeforeOptionalThemeAndAvatar() {
        #expect(MemberCreationStep.steps(for: .pet) == [
            .petName,
            .petIdentity,
            .petAppearance,
            .petPersonality,
            .avatar
        ])
    }

    @Test func petAvatarPreviewIsScopedToTheFifthStep() throws {
        let rootURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let layout = try String(
            contentsOf: rootURL.appending(
                path: "Ohana/Features/Members/Views/MemberCardCreationContentView+Layout.swift"
            ),
            encoding: .utf8
        )
        let surface = try String(
            contentsOf: rootURL.appending(
                path: "Ohana/Features/Members/Views/MemberCardCreationMediaComponents.swift"
            ),
            encoding: .utf8
        )
        let mediaAndSave = try String(
            contentsOf: rootURL.appending(
                path: "Ohana/Features/Members/Views/MemberCardCreationContentView+MediaAndSave.swift"
            ),
            encoding: .utf8
        )

        #expect(layout.contains("kind != .pet || currentStep == .avatar"))
        #expect(layout.contains("currentStep == .avatar"))
        #expect(layout.contains(".avatarFocus"))
        #expect(surface.contains("else if showsAvatar, let image = snapshot.avatarImage"))
        #expect(surface.contains("member-pet-avatar-preview"))
        #expect(surface.contains("layoutMode == .avatarFocus ? 4 : 0"))
        #expect(mediaAndSave.contains("guard currentStep == .avatar, !didConfigureAvatarStep"))
    }
}

import Foundation
import XCTest
@testable import Ohana

final class ProfileDetailExperienceTests: XCTestCase {
    func testHumanPetAndPlantUseTheSharedReadFirstProfileScaffold() throws {
        let shared = try source("Ohana/Shared/Components/ProfileDetailComponents.swift")
        let human = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift")
        let humanLifecycle = try source("Ohana/Features/Members/Views/HumanBasicInfoLifecycleViews.swift")
        let humanCreation = try source("Ohana/Features/Members/Views/MemberCardCreationContentView+Steps.swift")
        let pet = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView.swift")
        let petRead = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView+Read.swift")
        let petEditor = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView+Edit.swift")
        let plant = try source("Ohana/Features/Plants/Views/PlantBasicInfoDetailView.swift")

        for component in [
            "ProfileDetailScaffold",
            "ProfileIdentityHero",
            "ProfileInfoSection",
            "ProfileInfoRow",
            "ProfileEmptySectionRow",
            "ProfileCompletionCard"
        ] {
            XCTAssertTrue(shared.contains("struct \(component)"))
        }

        for profile in [human, pet + petEditor, plant] {
            XCTAssertTrue(profile.contains("ProfileDetailScaffold("))
            XCTAssertTrue(profile.contains(".sheet(item: $presentedSheet)"))
            XCTAssertTrue(profile.contains("ProfileIdentityHero("))
        }

        XCTAssertTrue(human.contains("Form {"))
        XCTAssertTrue(petEditor.contains("Form {"))
        XCTAssertTrue(plant.contains("EditPlantSheet(plant: plant, scope: .profile)"))
        XCTAssertTrue(shared.contains("Text(editTitle)"))
        XCTAssertFalse(shared.contains("Label(editTitle, systemImage: \"pencil\")"))
        XCTAssertTrue(shared.contains("reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface"))
        XCTAssertTrue(shared.contains("RoundedRectangle(cornerRadius: OhanaRadius.cardSoft"))
        XCTAssertTrue(human.contains("onClose: onClose,"))
        XCTAssertTrue(pet.contains("onClose: onClose,"))
        XCTAssertTrue(plant.contains("onClose: onClose,"))
        XCTAssertTrue(petEditor.contains("selection: speciesSelection"))
        XCTAssertFalse(petEditor.contains(".onChange(of: eSpecies)"))
        XCTAssertTrue(human.contains("human-basic-info-discard-changes-action"))
        XCTAssertTrue(pet.contains("pet-basic-info-discard-changes-action"))
        XCTAssertTrue(plant.contains("plant-profile-delete-action"))
        XCTAssertTrue(human.contains("ProfileCompletionCard("))
        XCTAssertTrue(petRead.contains("ProfileCompletionCard("))
        XCTAssertTrue(plant.contains("ProfileCompletionCard("))
        XCTAssertTrue(shared.contains("profile-completion-continue-action"))
        XCTAssertTrue(shared.contains("profile-completion-card"))
        XCTAssertTrue(human.contains("HumanProfileEditPolicy.canEdit"))
        XCTAssertFalse(human.contains("showsEditAction: isViewingOwnProfile"))
        XCTAssertTrue(human.contains("completion(.failed(message:"))
        XCTAssertTrue(human.contains("completion(.deleted)"))
        XCTAssertTrue(humanLifecycle.contains("all related local data"))
        XCTAssertTrue(humanLifecycle.contains(".interactiveDismissDisabled(isDeleting)"))
        XCTAssertFalse((human + humanLifecycle).contains(".height(360)"))
        XCTAssertTrue(humanLifecycle.contains("human-lifecycle-management-disclosure"))
        XCTAssertTrue(shared.contains(".toolbarBackground(Color.ohanaCardSurfaceElevated, for: .navigationBar)"))
        XCTAssertTrue(shared.contains("DisclosureGroup(isExpanded: $showsCompletionExplanation)"))
        XCTAssertTrue(humanCreation.contains("if HumanLocalPrivacyPolicy.isEnabled"))
        XCTAssertTrue(humanCreation.contains("compactHumanGenderGrid"))
    }

    func testPushedProfileRoutesKeepEditAsTheOnlyTrailingToolbarAction() throws {
        let contentView = try source("Ohana/App/ContentView.swift")

        XCTAssertFalse(contentView.contains(".globalTaskCenterToolbar"))
    }

    func testProfileEditorsKeepInternalAvatarFallbacksOutOfTheFormAndGroupRowsCompactly() throws {
        let human = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift")
        let pet = try source("Ohana/Features/Members/Views/PetBasicInfoDetailView+Edit.swift")
        let avatar = try source("Ohana/Features/Members/Views/EditableProfileAvatarPicker.swift")
        let zenContainer = try source("Ohana/Features/Zen/ZenExperienceContainer.swift")
        let zenMembers = try source("Ohana/Features/Zen/ZenMembersView.swift")
        let legacyPet = try source("Ohana/Features/Members/Views/EditPetSheet.swift")
        let plant = try source("Ohana/Features/Plants/Views/PlantDetailEditSheet.swift")

        for editor in [human, pet, legacyPet, plant] {
            XCTAssertFalse(editor.contains("头像 Emoji"))
            XCTAssertFalse(editor.contains("Avatar Emoji"))
            XCTAssertFalse(editor.contains("Avatar emoji"))
            XCTAssertFalse(editor.contains("Avatar-Emoji"))
        }
        XCTAssertTrue(human.contains("VStack(alignment: .leading, spacing: 14)"))
        XCTAssertTrue(pet.contains("VStack(alignment: .leading, spacing: 14)"))
        XCTAssertTrue(avatar.contains("width * MemberAvatarImageProcessor.portraitAspect"))
        XCTAssertTrue(avatar.contains("if experienceStyle == .zen"))
        XCTAssertTrue(zenContainer.contains(".environment(\\.memberProfileExperienceStyle, .zen)"))
        XCTAssertTrue(zenMembers.contains("FocusWalletAvatarCache.cachedEntry("))
        XCTAssertTrue(zenMembers.contains("if let avatarImage"))
    }

    func testZenHumanProfileUsesThemeSemanticTextAndNativeOtherInputs() throws {
        let human = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift")
        let creation = try source("Ohana/Features/Members/Views/MemberCardCreationContentView+Steps.swift")

        XCTAssertTrue(human.contains("profileExperienceStyle == .zen ? profileEditAccent"))
        XCTAssertTrue(human.contains("human-basic-info-custom-nationality-input"))
        XCTAssertTrue(human.contains("human-basic-info-custom-residence-input"))
        XCTAssertTrue(creation.contains("member-human-custom-nationality-input"))
        XCTAssertTrue(creation.contains("member-human-custom-residence-country-input"))
        XCTAssertTrue(human.contains("TextField("))
    }

    func testMBTISelectionUsesFourValidatedBinaryDimensions() throws {
        XCTAssertEqual(MemberMBTISelectionPolicy.components(from: "infj"), ["I", "N", "F", "J"])
        XCTAssertEqual(MemberMBTISelectionPolicy.components(from: "INTJ"), ["I", "N", "T", "J"])
        XCTAssertEqual(MemberMBTISelectionPolicy.components(from: "IXFJ"), ["", "", "", ""])
        XCTAssertEqual(MemberMBTISelectionPolicy.components(from: "INF"), ["", "", "", ""])
        XCTAssertEqual(
            MemberMBTISelectionPolicy.value(
                energy: "I",
                information: "N",
                decision: "F",
                lifestyle: "J"
            ),
            "INFJ"
        )
        XCTAssertEqual(
            MemberMBTISelectionPolicy.value(
                energy: "I",
                information: "",
                decision: "F",
                lifestyle: "J"
            ),
            ""
        )

        let components = try source("Ohana/Features/Members/Views/MemberCardCreationComponents.swift")
        let human = try source("Ohana/Features/Members/Views/HumanBasicInfoDetailView.swift")
        XCTAssertTrue(components.contains("key: \"energy\", title: \"I / E\""))
        XCTAssertTrue(components.contains("key: \"information\", title: \"S / N\""))
        XCTAssertTrue(components.contains("key: \"decision\", title: \"T / F\""))
        XCTAssertTrue(components.contains("key: \"lifestyle\", title: \"J / P\""))
        XCTAssertFalse(components.contains("private func dimensionMenu"))
        XCTAssertTrue(human.contains("MemberCompactMBTIBar("))
    }

    func testPlantBasicInfoRouteKeepsCareDashboardOutsideProfileScope() throws {
        let route = try source("Ohana/Features/Plants/PlantRouteContainer.swift")
        let basicInfo = try source("Ohana/Features/Plants/Views/PlantBasicInfoDetailView.swift")
        let editorModels = try source("Ohana/Features/Plants/PlantProfileEditorModels.swift")
        let editor = try source("Ohana/Features/Plants/Views/PlantDetailEditSheet.swift")
        let detailActions = try source("Ohana/Features/Plants/Views/PlantDetailView+Actions.swift")

        XCTAssertTrue(route.contains("case basicInfo"))
        XCTAssertTrue(route.contains("PlantBasicInfoDetailView("))
        XCTAssertTrue(editorModels.contains("enum PlantProfileEditorScope"))
        XCTAssertTrue(editorModels.contains("case profile"))
        XCTAssertTrue(editorModels.contains("case fullCare"))
        XCTAssertTrue(editor.contains("if scope == .profile"))
        XCTAssertTrue(editor.contains("wateringIntervalDays: scope == .profile ? plant.wateringIntervalDays : wateringInterval"))
        XCTAssertTrue(editor.contains("fertilizingIntervalDays: scope == .profile ? plant.fertilizingIntervalDays : fertilizingInterval"))
        XCTAssertTrue(editor.contains("remindersEnabled: scope == .profile ? plant.remindersEnabled : remindersEnabled"))
        XCTAssertTrue(editor.contains("selection: catalogSelection"))
        XCTAssertFalse(editor.contains(".onChange(of: catalogSpeciesId)"))
        XCTAssertTrue(detailActions.contains("case .profile:"))
        XCTAssertTrue(detailActions.contains("showingBasicInfo = true"))
        XCTAssertFalse(basicInfo.contains("PlantDetailView("))
        XCTAssertFalse(basicInfo.contains("PlantCareLogSheet("))
        XCTAssertFalse(basicInfo.contains("PlantReminderSettingsView("))
    }

    func testZenCardCheckInExpandAndProfileActionsStayIndependent() throws {
        let home = try source("Ohana/Features/Zen/ZenHomeView.swift")
        let models = try source("Ohana/Features/Zen/ZenModels.swift")
        let container = try source("Ohana/Features/Zen/ZenExperienceContainer.swift")

        XCTAssertTrue(models.contains("var onOpenProfile:"))
        XCTAssertFalse(models.contains("var onManage:"))
        XCTAssertTrue(home.contains("Button(action: handleQuickTap)"))
        XCTAssertTrue(home.contains("LongPressGesture("))
        XCTAssertTrue(home.contains(".sequenced(before: DragGesture("))
        XCTAssertTrue(home.contains("Button(action: onAccessoryAction)"))
        XCTAssertTrue(home.contains("arrow.up.left.and.arrow.down.right"))
        XCTAssertTrue(home.contains("ZenPresenceWalletCardPresentation"))
        XCTAssertTrue(home.contains("FocusHomeVerticalSolidExpandedLayoutPolicy.frame("))
        XCTAssertTrue(home.contains("matchedGeometryEffect(id: \"zen-card:"))
        XCTAssertTrue(home.contains("ZenPresenceCardAccessoryMetrics.minimumHitSize"))
        XCTAssertTrue(home.contains("ZenPresenceCardAccessoryMetrics.collapsedVisualDiameter"))
        XCTAssertTrue(home.contains("Canvas(opaque: false"))
        XCTAssertTrue(home.contains("zen-home-expand-"))
        XCTAssertTrue(home.contains("zen-home-profile-"))
        XCTAssertTrue(home.contains("ZenUndoCheckInButton("))
        XCTAssertTrue(home.contains("onUndoCheckIn:"))
        XCTAssertTrue(models.contains("onUndoCheckIn:"))
        XCTAssertTrue(container.contains("undoTodayCheckIn(subject:"))
        XCTAssertTrue(home.contains(".matchedTransitionSource(id: profileTransitionSourceID"))
        XCTAssertFalse(home.contains("systemImage: \"info.circle\""))
        XCTAssertTrue(container.contains("destination: .basicInfo"))
        XCTAssertTrue(container.contains("AppHumanDetailSheetRouteContainer("))
        XCTAssertTrue(container.contains("AppPetDetailSheetRouteContainer("))
        XCTAssertTrue(container.contains("AppPlantRouteContainer("))
        XCTAssertTrue(container.contains("!reduceMotion"))
        XCTAssertTrue(container.contains("!workloadPolicy.shouldReduceWork()"))
        XCTAssertFalse(container.contains("ZenPlantManagementRoute"))
    }

    func testZenMemberRouteKeepsAllThreeKindsLightweightAndEditable() throws {
        let members = try source("Ohana/Features/Zen/ZenMembersView.swift")

        XCTAssertTrue(members.contains("ZenPresenceSubjectKind.allCases"))
        XCTAssertTrue(members.contains("AddEntityDestinationView("))
        XCTAssertTrue(members.contains("AppHumanDetailSheetRouteContainer("))
        XCTAssertTrue(members.contains("AppPetDetailSheetRouteContainer("))
        XCTAssertTrue(members.contains("AppPlantRouteContainer("))
        XCTAssertTrue(members.contains("destination: .basicInfo"))
        XCTAssertFalse(members.contains("TaskCenter"))
        XCTAssertFalse(members.contains("QuickCare"))
        XCTAssertFalse(members.contains("PlantUnlockPolicy"))
    }

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}

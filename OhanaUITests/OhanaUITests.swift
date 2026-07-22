//
//  OhanaUITests.swift
//  OhanaUITests
//
//  Created by Guanchenulous on 01.03.26.
//

import StoreKitTest
import XCTest

final class OhanaUITests: XCTestCase {
    private var seededHumanBaselineName: String?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testSkippedPetCreationMovesToTasksAndCompletesFromSystemJourney() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        let humanName = "Codex Deferred Human"
        createOnboardingHuman(named: humanName, in: app)
        tapWhenHittable(app.buttons["onboarding-defer-pet"], timeout: 8)

        XCTAssertTrue(
            app.buttons["home-card-human-\(humanName)"].waitForExistence(timeout: 15),
            "Skipping Pet creation did not preserve the newly created Human card."
        )
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-")).firstMatch.exists)
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Oasis must stay locked while the first-Pet journey is pending.")

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        let systemAction = app.buttons["task-center-system-action-createFirstPet-system-journey-create-first-pet"]
        XCTAssertTrue(systemAction.waitForExistence(timeout: 15), "The deferred first-Pet system journey was not visible in Tasks.")
        tapWhenHittable(systemAction, timeout: 8)

        let petName = "Codex Deferred Pet"
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "The first-Pet system journey did not open Pet creation.",
            completionMessage: "Creating the deferred first Pet did not reach the starter reward.",
            petSpeciesLabel: "Dog",
            postSaveMarkerIdentifiers: ["home-card-pet-\(petName)"]
        )
        finishRequiredStarterGift(in: app)
        XCTAssertTrue(app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12))
    }

    @MainActor
    func testPetCreationBackDefersThenTasksCancelPreservesJourney() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        let humanName = "Codex Back Then Defer Human"
        let draftPetName = "Codex Abandoned Pet Draft"
        let petName = "Codex Resumed Pet"
        createOnboardingHuman(named: humanName, in: app)

        let createNow = app.buttons["onboarding-create-pet-now"]
        XCTAssertTrue(waitUntil(timeout: 8) { createNow.exists && createNow.isEnabled && createNow.isHittable })
        createNow.tap()

        let nameField = app.textFields["member-name-input"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 12), "Create now did not open Pet creation.")
        nameField.tap()
        nameField.typeText(draftPetName)
        nameField.typeText("\n")

        let onboardingBack = app.buttons["member-creation-back-action"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                onboardingBack.exists && onboardingBack.isEnabled && onboardingBack.isHittable
            },
            "The onboarding Pet form did not expose its semantic Back action."
        )
        onboardingBack.tap()

        XCTAssertTrue(
            app.buttons["home-card-human-\(humanName)"].waitForExistence(timeout: 15),
            "Returning from Pet creation did not preserve the Human card."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { !nameField.exists })
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-"))
                .firstMatch.exists,
            "Returning from the Pet draft created a Pet."
        )
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Oasis unlocked before the first Pet existed.")

        let tasksTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let createTask = app.buttons["task-center-system-action-createFirstPet-system-journey-create-first-pet"]
        let claimTask = app.buttons["task-center-system-action-claimStarterGift-system-journey-claim-starter-gift"]
        XCTAssertTrue(createTask.waitForExistence(timeout: 15), "The deferred first-Pet task did not appear.")
        XCTAssertFalse(claimTask.exists)
        XCTAssertTrue(waitUntil(timeout: 8) { createTask.isEnabled && createTask.isHittable })
        createTask.tap()

        XCTAssertTrue(nameField.waitForExistence(timeout: 12), "The deferred task did not reopen Pet creation.")
        let resumedNameValue = (nameField.value as? String) ?? ""
        XCTAssertNotEqual(
            resumedNameValue,
            draftPetName,
            "The abandoned onboarding Pet draft leaked into the resumed form."
        )
        XCTAssertTrue(
            isEmptyTextFieldValue(resumedNameValue),
            "The resumed Pet form was not empty. Actual: \(resumedNameValue)"
        )
        let cancelCreation = app.buttons["member-creation-cancel-action"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                cancelCreation.exists && cancelCreation.isEnabled && cancelCreation.isHittable
            },
            "The standard Pet form did not expose its semantic Cancel action."
        )
        cancelCreation.tap()

        XCTAssertTrue(waitUntil(timeout: 12) { !nameField.exists && !cancelCreation.exists })
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(createTask.waitForExistence(timeout: 12), "Cancelling removed the deferred first-Pet task.")
        XCTAssertFalse(claimTask.exists, "Cancelling incorrectly exposed the starter reward.")
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Cancelling Pet creation unlocked Oasis.")

        XCTAssertTrue(waitUntil(timeout: 8) { createTask.isEnabled && createTask.isHittable })
        createTask.tap()
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "Reopening the deferred task did not restore Pet creation.",
            completionMessage: "Completing the resumed Pet form did not return to Home with the new card.",
            petSpeciesLabel: "Dog",
            postSaveMarkerIdentifiers: ["home-card-pet-\(petName)"]
        )

        XCTAssertTrue(app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12))
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(claimTask.waitForExistence(timeout: 12), "Saving the resumed Pet did not expose Claim.")
        XCTAssertFalse(createTask.exists, "The create task remained after the first Pet was saved.")
        XCTAssertFalse(app.buttons["starter-gift-finish-action"].exists)
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists)
        finishRequiredStarterGift(in: app)
        XCTAssertFalse(claimTask.exists, "The claimed starter reward task remained visible.")
        XCTAssertTrue(app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12))
    }

    @MainActor
    func testDeferredFirstPetTaskPersistsAcrossRelaunchWithoutUnsavedDraft() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        let humanName = "Codex Relaunch Deferred Human"
        let abandonedDraftName = "Codex Relaunch Abandoned Pet"
        createOnboardingHuman(named: humanName, in: app)

        let deferPet = app.buttons["onboarding-defer-pet"]
        XCTAssertTrue(waitUntil(timeout: 8) { deferPet.exists && deferPet.isEnabled && deferPet.isHittable })
        deferPet.tap()
        XCTAssertTrue(app.buttons["home-card-human-\(humanName)"].waitForExistence(timeout: 15))

        let tasksTab = app.buttons["home-tab-calendar"]
        let homeTab = app.buttons["home-tab-home"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let createTask = app.buttons[
            "task-center-system-action-createFirstPet-system-journey-create-first-pet"
        ]
        let claimTask = app.buttons[
            "task-center-system-action-claimStarterGift-system-journey-claim-starter-gift"
        ]
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(createTask.waitForExistence(timeout: 15))
        XCTAssertFalse(claimTask.exists)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20), "Home was not reachable after the deferred relaunch.")
        XCTAssertTrue(waitUntil(timeout: 8) { homeTab.isEnabled && homeTab.isHittable })
        homeTab.tap()
        XCTAssertTrue(
            app.buttons["home-card-human-\(humanName)"].waitForExistence(timeout: 15),
            "The Human card did not survive the deferred relaunch."
        )
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-"))
                .firstMatch.exists,
            "Relaunching a deferred first-Pet task fabricated a Pet."
        )
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Relaunch unlocked Oasis before a Pet existed.")

        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(createTask.waitForExistence(timeout: 15), "The deferred first-Pet task did not survive relaunch.")
        XCTAssertFalse(claimTask.exists)
        XCTAssertTrue(waitUntil(timeout: 8) { createTask.isEnabled && createTask.isHittable })
        createTask.tap()

        let nameField = app.textFields["member-name-input"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 12))
        let firstResumeValue = (nameField.value as? String) ?? ""
        XCTAssertTrue(
            isEmptyTextFieldValue(firstResumeValue),
            "The first post-relaunch Pet form was not empty. Actual: \(firstResumeValue)"
        )
        nameField.tap()
        nameField.typeText(abandonedDraftName)
        nameField.typeText("\n")

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(createTask.waitForExistence(timeout: 15))
        XCTAssertFalse(claimTask.exists, "Terminating an unsaved Pet draft exposed the starter reward.")
        XCTAssertTrue(waitUntil(timeout: 8) { createTask.isEnabled && createTask.isHittable })
        createTask.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 12))
        let secondResumeValue = (nameField.value as? String) ?? ""
        XCTAssertNotEqual(
            secondResumeValue,
            abandonedDraftName,
            "The unsaved Pet draft survived process termination."
        )
        XCTAssertTrue(
            isEmptyTextFieldValue(secondResumeValue),
            "The second post-relaunch Pet form was not empty. Actual: \(secondResumeValue)"
        )

        let cancelCreation = app.buttons["member-creation-cancel-action"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                cancelCreation.exists && cancelCreation.isEnabled && cancelCreation.isHittable
            }
        )
        cancelCreation.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(createTask.waitForExistence(timeout: 12), "Cancelling after relaunch removed the deferred task.")
        XCTAssertFalse(claimTask.exists)
    }

    @MainActor
    func testStarterGiftCeremonyResumesAfterRelaunchWithoutDuplicateReward() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        let humanName = "Codex Gift Relaunch Human"
        let petName = "Codex Gift Relaunch Pet"
        createOnboardingHuman(named: humanName, in: app)

        let createNow = app.buttons["onboarding-create-pet-now"]
        XCTAssertTrue(waitUntil(timeout: 8) { createNow.exists && createNow.isEnabled && createNow.isHittable })
        createNow.tap()
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "Immediate Pet creation did not open before the gift relaunch path.",
            completionMessage: "Saving the Pet did not return to Home before the gift relaunch path.",
            petSpeciesLabel: "Dog",
            postSaveMarkerIdentifiers: ["home-card-pet-\(petName)"]
        )

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let oasisTab = app.buttons["home-tab-oasis"]
        let coconutBalance = app.buttons["home-coconut-action"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let createTask = app.buttons[
            "task-center-system-action-createFirstPet-system-journey-create-first-pet"
        ]
        let claimTask = app.buttons[
            "task-center-system-action-claimStarterGift-system-journey-claim-starter-gift"
        ]
        let finishGift = app.buttons["starter-gift-finish-action"]

        XCTAssertFalse(oasisTab.exists, "Oasis unlocked before the starter gift was claimed.")
        XCTAssertTrue(
            waitUntil(timeout: 8) { coconutBalance.label == "Coconut balance 0" },
            "The starter gift was credited before explicit confirmation."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(claimTask.waitForExistence(timeout: 20))
        XCTAssertFalse(createTask.exists, "The first-Pet creation task remained after the Pet was saved.")
        XCTAssertTrue(waitUntil(timeout: 8) { claimTask.isEnabled && claimTask.isHittable })
        claimTask.tap()
        XCTAssertTrue(finishGift.waitForExistence(timeout: 20))
        XCTAssertFalse(oasisTab.exists)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(
            finishGift.waitForExistence(timeout: 30),
            "The unconfirmed starter gift ceremony did not resume after relaunch."
        )
        XCTAssertFalse(oasisTab.exists, "Relaunch committed the starter gift without confirmation.")
        XCTAssertTrue(waitUntil(timeout: 8) { finishGift.isEnabled && finishGift.isHittable })
        finishGift.tap()
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 12), "Confirming the resumed gift did not unlock Oasis.")
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 50" },
            "Confirming the resumed gift did not credit exactly 50 coconuts."
        )
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8))
        XCTAssertTrue(waitUntil(timeout: 8) { homeTab.isEnabled && homeTab.isHittable })
        homeTab.tap()
        XCTAssertTrue(app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12))

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 20), "Oasis unlock did not survive relaunch.")
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 50" },
            "Relaunch duplicated or lost the starter gift reward."
        )
        XCTAssertFalse(finishGift.exists, "The completed starter gift ceremony reopened after relaunch.")

        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons[
                "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
            ].waitForExistence(timeout: 15),
            "Tasks did not finish loading after the completed gift relaunch."
        )
        XCTAssertFalse(createTask.exists, "The completed first-Pet journey regressed to Create after relaunch.")
        XCTAssertFalse(claimTask.exists, "The completed starter gift remained claimable after relaunch.")
    }

    @MainActor
    func testMemberCardNavigationCancelResumeReviewedAndPrivate() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true
        )
        openMemberCardJourney(in: app)

        let appearanceQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanAppearance"
        ]
        let optionalQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanOptionalDetails"
        ]
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 12))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        reopenMemberCardJourney(in: app)
        XCTAssertTrue(
            appearanceQuestion.waitForExistence(timeout: 8),
            "Closing without answering did not resume at the first incomplete member-card question."
        )
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-open-humanAppearance"], in: app)
        let nameField = app.textFields["human-basic-info-name-input"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 12), "The member-card editor did not start in edit mode.")
        XCTAssertTrue(app.descendants(matching: .any)["profile-avatar-current-preview"].exists)
        XCTAssertTrue(app.buttons["profile-avatar-photos-action"].exists)
        XCTAssertFalse(app.textFields["human-basic-info-avatar-emoji-input"].exists)
        let originalName = String(describing: nameField.value ?? "")
        nameField.tap()
        nameField.typeText(" Unsaved")
        discardHumanBasicInfoChanges(in: app)

        tapWhenHittable(app.buttons["human-basic-info-edit-action"], timeout: 8)
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        XCTAssertEqual(
            String(describing: nameField.value ?? ""),
            originalName,
            "Cancel persisted an unrelated profile edit."
        )
        tapWhenHittable(app.buttons["human-basic-info-cancel-edit-action"], timeout: 8)
        tapWhenHittable(app.buttons["human-basic-info-close-action"], timeout: 8)
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-reviewed"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        reopenMemberCardJourney(in: app)
        XCTAssertTrue(
            optionalQuestion.waitForExistence(timeout: 8),
            "Reopening did not resume at the remaining optional-details question."
        )
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanOptionalDetails-preferNotToSay"],
            in: app
        )
        assertMemberCardJourneyComplete(in: app)
    }

    @MainActor
    func testMemberCardAvatarEditorUsesPhotoControlsWithoutExposingFallbackEmoji() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true
        )
        openMemberCardJourney(in: app)

        let appearanceQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanAppearance"
        ]
        let optionalQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanOptionalDetails"
        ]
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 12))
        assertMemberCardProgress("0/2", in: app)

        tapWhenHittable(
            app.buttons["task-center-starter-journey-open-humanAppearance"],
            timeout: 8
        )
        let editor = app.descendants(matching: .any)["human-basic-info-screen"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["profile-avatar-current-preview"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["profile-avatar-paste-action"].exists)
        XCTAssertTrue(app.buttons["profile-avatar-photos-action"].exists)
        XCTAssertTrue(app.buttons["profile-avatar-camera-action"].exists)
        XCTAssertFalse(
            app.textFields["human-basic-info-avatar-emoji-input"].exists,
            "The internal fallback emoji must not be exposed as editable profile data."
        )

        tapWhenHittable(app.buttons["human-basic-info-cancel-edit-action"], timeout: 8)
        tapWhenHittable(app.buttons["human-basic-info-close-action"], timeout: 8)
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-reviewed"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanOptionalDetails-preferNotToSay"],
            in: app
        )
        assertMemberCardJourneyComplete(in: app)
    }
    @MainActor
    func testMemberCardPrivateAppearanceSurvivesPhotoEditorCancelAcrossRelaunch() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let taskAction = app.buttons[
            "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
        ]
        let journeySheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeHumanProfile"
        ]
        let appearanceQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanAppearance"
        ]
        let optionalQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanOptionalDetails"
        ]
        let completedAppearance = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-humanAppearance"
        ]

        openMemberCardJourney(in: app)
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-preferNotToSay"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedAppearance.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedAppearance).localizedCaseInsensitiveContains("Prefer not to say")
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-humanAppearance"],
            in: app
        )
        let editor = app.descendants(matching: .any)["human-basic-info-screen"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(app.descendants(matching: .any)["profile-avatar-current-preview"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.textFields["human-basic-info-avatar-emoji-input"].exists)
        tapWhenHittable(app.buttons["human-basic-info-cancel-edit-action"], timeout: 8)
        tapWhenHittable(app.buttons["human-basic-info-close-action"], timeout: 8)

        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 12))
        XCTAssertTrue(completedAppearance.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedAppearance).localizedCaseInsensitiveContains("Prefer not to say"),
            "Cancelling the photo editor replaced the explicit private Appearance answer."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(taskAction.waitForExistence(timeout: 15))
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedAppearance.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedAppearance).localizedCaseInsensitiveContains("Prefer not to say"),
            "Relaunch lost the explicit private Appearance answer."
        )
    }
    @MainActor
    func testMemberCardReviewedOptionalThenRealBirthdaySupersedesResolutionAcrossRelaunchAndRewardsOnce() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            coconutBalanceSeedAmount: 7
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let taskAction = app.buttons[
            "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
        ]
        let journeySheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeHumanProfile"
        ]
        let appearanceQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanAppearance"
        ]
        let optionalQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanOptionalDetails"
        ]
        let completedOptional = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-humanOptionalDetails"
        ]
        let coconutBalance = app.buttons["home-coconut-action"]

        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "The optional-details supersession path did not start from 7 coconuts."
        )
        openMemberCardJourney(in: app)
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 12))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanOptionalDetails-reviewed"],
            in: app
        )
        XCTAssertTrue(
            appearanceQuestion.waitForExistence(timeout: 8),
            "Reviewing the current Optional details did not return to the remaining Appearance question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedOptional.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedOptional).localizedCaseInsensitiveContains("Current status reviewed"),
            "The initial reviewed Optional details answer was not shown before replacement."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-humanOptionalDetails"],
            in: app
        )
        let editor = app.descendants(matching: .any)["human-basic-info-screen"]
        let birthdayToggle = app.switches["human-basic-info-birthday-toggle"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8))
        XCTAssertFalse(isToggleOn(birthdayToggle), "The sparse Human unexpectedly started with a birthday.")
        tapGuidedJourneyControlAfterSemanticScroll(birthdayToggle, in: app)
        XCTAssertTrue(waitUntil(timeout: 8) { self.isToggleOn(birthdayToggle) })
        tapWhenHittable(app.buttons["human-basic-info-save-action"], timeout: 8)

        XCTAssertTrue(
            waitUntil(timeout: 12) { !editor.exists },
            "Saving the real birthday did not return to the guided journey."
        )
        XCTAssertTrue(
            optionalQuestion.waitForExistence(timeout: 12),
            "Replacing an already-completed Optional details answer did not return for review."
        )
        assertMemberCardProgress("1/2", in: app)
        XCTAssertTrue(completedOptional.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedOptional).localizedCaseInsensitiveContains("existing information"),
            "The real birthday did not replace the reviewed Optional details answer."
        )
        XCTAssertFalse(
            accessibilityText(for: completedOptional).localizedCaseInsensitiveContains("Current status reviewed"),
            "The superseded reviewed Optional details answer remained visible after saving a birthday."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "Relaunch changed the balance before the member-card Claim."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(taskAction.waitForExistence(timeout: 15))
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            appearanceQuestion.waitForExistence(timeout: 8),
            "Relaunch did not resume at the remaining Appearance question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedOptional.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedOptional).localizedCaseInsensitiveContains("existing information"),
            "Relaunch did not preserve the real Optional details answer."
        )
        XCTAssertFalse(
            accessibilityText(for: completedOptional).localizedCaseInsensitiveContains("Current status reviewed"),
            "Relaunch restored the superseded reviewed Optional details answer."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-humanOptionalDetails"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8))
        XCTAssertTrue(isToggleOn(birthdayToggle), "Relaunch did not read back the saved birthday.")
        tapWhenHittable(app.buttons["human-basic-info-cancel-edit-action"], timeout: 8)
        tapWhenHittable(app.buttons["human-basic-info-close-action"], timeout: 8)
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-preferNotToSay"],
            in: app
        )
        assertMemberCardJourneyComplete(in: app)
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "The completed supersession path did not expose a separate Claim state."
        )
        XCTAssertEqual(coconutBalance.label, "Coconut balance 7")

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "The unclaimed member-card reward changed across relaunch."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Relaunch did not preserve the member-card Claim state."
        )
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-completeHumanProfile"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !taskAction.exists })
        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 107" },
            "The member-card Claim did not add exactly 100 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 107" },
            "The second relaunch duplicated or lost the member-card reward."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertFalse(taskAction.exists, "The claimed member-card task returned after relaunch.")
    }

    @MainActor
    func testMemberCardOptionalBirthdayCancelCloseReopenSaveAndClaim() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            coconutBalanceSeedAmount: 7
        )
        let coconutBalance = app.buttons["home-coconut-action"]
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "The birthday journey did not start from its explicit 7-coconut baseline."
        )
        openMemberCardJourney(in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-reviewed"],
            in: app
        )
        let optionalQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanOptionalDetails"
        ]
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-humanOptionalDetails"],
            in: app
        )
        let editor = app.descendants(matching: .any)["human-basic-info-screen"]
        let birthdayToggle = app.switches["human-basic-info-birthday-toggle"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The Human optional-details editor did not open.")
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8), "The birthday toggle was unavailable.")
        XCTAssertFalse(isToggleOn(birthdayToggle), "The sparse Human unexpectedly started with a birthday.")
        tapGuidedJourneyControlAfterSemanticScroll(birthdayToggle, in: app)
        XCTAssertTrue(waitUntil(timeout: 8) { self.isToggleOn(birthdayToggle) })

        discardHumanBasicInfoChanges(in: app)
        let closeEditor = app.buttons["human-basic-info-close-action"]
        XCTAssertTrue(closeEditor.waitForExistence(timeout: 8), "Cancel did not expose the Human editor close action.")
        tapWhenHittable(closeEditor, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists }, "Close did not return to the guided journey.")
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)

        let journeySheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeHumanProfile"
        ]
        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists })

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "Relaunch after cancelling the birthday draft changed the coconut balance."
        )
        openMemberCardJourney(in: app)
        XCTAssertTrue(
            optionalQuestion.waitForExistence(timeout: 8),
            "Relaunch after cancelling did not resume the remaining optional-details question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-humanOptionalDetails"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8))
        XCTAssertFalse(isToggleOn(birthdayToggle), "Cancelling the birthday edit persisted it.")
        tapGuidedJourneyControlAfterSemanticScroll(birthdayToggle, in: app)
        XCTAssertTrue(waitUntil(timeout: 8) { self.isToggleOn(birthdayToggle) })
        tapWhenHittable(app.buttons["human-basic-info-save-action"], timeout: 8)

        XCTAssertTrue(
            waitUntil(timeout: 12) { !editor.exists },
            "Saving the birthday did not return to the guided journey."
        )
        assertMemberCardJourneyComplete(in: app)
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists }, "Finish did not return to Tasks.")

        let taskAction = app.buttons[
            "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
        ]
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Saving a real birthday did not expose a separate Claim state."
        )
        XCTAssertEqual(coconutBalance.label, "Coconut balance 7")

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(app.buttons["home-tab-home"].waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "Relaunch changed the balance before the birthday member-card Claim."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "Relaunch did not return to Tasks for the birthday member-card Claim."
        )
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Relaunch did not preserve the birthday member-card Claim state."
        )
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-completeHumanProfile"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !taskAction.exists })

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 107" },
            "The birthday member-card reward was not applied exactly once."
        )
    }

    @MainActor
    func testMemberCardPrivateAppearanceAndUnknownOptionalPath() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            coconutBalanceSeedAmount: 7
        )
        let coconutBalance = app.buttons["home-coconut-action"]
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 7" },
            "The member-card reward test did not start from its explicit 7-coconut baseline."
        )
        openMemberCardJourney(in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-preferNotToSay"],
            in: app
        )
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "task-center-starter-question-checkpoint-humanOptionalDetails"
            ].waitForExistence(timeout: 8)
        )
        assertMemberCardProgress("1/2", in: app)
        XCTAssertFalse(
            app.buttons["task-center-starter-resolution-humanOptionalDetails-notApplicable"].exists,
            "The Human optional-details question exposed an unsupported not-applicable answer."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanOptionalDetails-unknown"],
            in: app
        )
        assertMemberCardJourneyComplete(in: app)

        let journeySheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeHumanProfile"
        ]
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !journeySheet.exists },
            "Returning to Tasks did not close the completed member-card journey."
        )

        let taskAction = app.buttons[
            "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
        ]
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "The completed member-card task did not change to Claim."
        )
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))

        let claim = app.buttons["task-center-starter-journey-claim-completeHumanProfile"]
        XCTAssertTrue(
            waitUntil(timeout: 8) { claim.exists && claim.isEnabled && claim.isHittable },
            "The member-card reward claim action did not become available."
        )
        claim.doubleTap()

        XCTAssertTrue(
            waitUntil(timeout: 12) { !journeySheet.exists },
            "Claiming the member-card reward did not close its sheet."
        )
        XCTAssertTrue(
            waitUntil(timeout: 12) { !taskAction.exists },
            "The claimed member-card task remained visible or was claimed twice."
        )
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 107" },
            "The member-card reward was not applied exactly once after a double tap."
        )
    }

    @MainActor
    func testMemberCardMixedPrivateAndSavedAnswersSurviveRelaunchAndRewardOnce() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let taskAction = app.buttons[
            "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
        ]
        let journeySheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeHumanProfile"
        ]
        let appearanceQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanAppearance"
        ]
        let optionalQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-humanOptionalDetails"
        ]
        let coconutBalance = app.buttons["home-coconut-action"]

        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20))
        let balanceBeforeClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(balanceBeforeClaim, 0, "The member-card baseline balance was unreadable.")
        openMemberCardJourney(in: app)
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 12))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-humanAppearance-preferNotToSay"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20), "Home was unavailable after the partial member-card relaunch.")
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(taskAction.waitForExistence(timeout: 15), "The partial member-card task did not survive relaunch.")
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            optionalQuestion.waitForExistence(timeout: 8),
            "Relaunch did not resume at the remaining optional-details question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(appearanceQuestion.waitForExistence(timeout: 8))
        let persistedPrivateAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-humanAppearance"
        ]
        XCTAssertTrue(persistedPrivateAnswer.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: persistedPrivateAnswer).localizedCaseInsensitiveContains("Prefer not to say"),
            "Relaunch did not preserve the private Appearance answer."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(optionalQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-humanOptionalDetails"],
            in: app
        )
        let editor = app.descendants(matching: .any)["human-basic-info-screen"]
        let birthdayToggle = app.switches["human-basic-info-birthday-toggle"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8))
        XCTAssertFalse(isToggleOn(birthdayToggle), "The sparse Human unexpectedly started with a birthday.")
        tapGuidedJourneyControlAfterSemanticScroll(birthdayToggle, in: app)
        XCTAssertTrue(waitUntil(timeout: 8) { self.isToggleOn(birthdayToggle) })
        tapWhenHittable(app.buttons["human-basic-info-save-action"], timeout: 8)

        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists })
        assertMemberCardJourneyComplete(in: app)
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "The mixed-answer member-card task did not expose Claim."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                taskAction.exists && taskAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "The unclaimed member-card reward did not survive relaunch."
        )
        tapWhenHittable(taskAction, timeout: 8)
        XCTAssertTrue(journeySheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-completeHumanProfile"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !journeySheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !taskAction.exists })

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "The mixed-answer member-card claim did not add exactly 100 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "Relaunch duplicated or lost the member-card reward."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertFalse(taskAction.exists, "The claimed member-card task returned after relaunch.")
    }

    @MainActor
    func testPetDailyCareUnknownCancelThenRealSetupSurvivesRelaunchWithoutFabricationAndRewardsOnce() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_SEED_SPARSE_PET_PROFILE_BASELINE"]
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let coconutBalance = app.buttons["home-coconut-action"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let action = app.buttons[
            "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile"
        ]
        let identityAction = app.buttons[
            "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeFirstPetProfile"
        ]
        let lifeStageQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petLifeStage"
        ]
        let bodyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petBodyProfile"
        ]
        let personalityQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petPersonalityAppearance"
        ]
        let dailyCareQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petDailyCare"
        ]
        let completedDailyCare = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petDailyCare"
        ]
        let openDailyCare = app.buttons["task-center-starter-journey-open-petDailyCare"]
        let feedDetail = app.descendants(matching: .any)["quick-feed-detail-screen"]
        let saveManualSettings = app.buttons["quick-feed-manual-settings-save"]
        let primaryFeedAction = app.buttons["quick-feed-primary-action"]
        let closeFeed = app.buttons["quick-feed-detail-close-action"]

        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 8))
        let balanceBeforeClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(balanceBeforeClaim, 0, "The sparse Pet baseline balance was unreadable.")

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The sparse Pet profile task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petDailyCare-unknown"],
            in: app
        )
        XCTAssertTrue(
            lifeStageQuestion.waitForExistence(timeout: 8),
            "Resolving Daily Care did not return to the first unanswered Pet question."
        )
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDailyCare.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not sure yet"),
            "The explicit Daily Care unknown answer was not displayed."
        )

        tapGuidedJourneyControlAfterSemanticScroll(openDailyCare, in: app)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12), "Daily Care did not open Quick Feed.")
        if !saveManualSettings.waitForExistence(timeout: 4) {
            tapWhenHittable(primaryFeedAction, timeout: 8)
        }
        XCTAssertTrue(
            saveManualSettings.waitForExistence(timeout: 12),
            "Choosing Not sure yet fabricated a feed setup for the sparse Pet."
        )
        tapWhenHittable(app.buttons["quick-feed-sheet-cancel-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !saveManualSettings.exists && feedDetail.exists },
            "Cancelling feed setup did not keep the unchanged Daily Care screen open."
        )
        tapWhenHittable(closeFeed, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !feedDetail.exists })
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 12))
        XCTAssertTrue(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not sure yet"),
            "Cancelling feed setup changed the completed Daily Care answer."
        )
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(openDailyCare, in: app)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12))
        if !saveManualSettings.waitForExistence(timeout: 4) {
            tapWhenHittable(primaryFeedAction, timeout: 8)
        }
        XCTAssertTrue(saveManualSettings.waitForExistence(timeout: 12))
        tapWhenHittable(saveManualSettings, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !saveManualSettings.exists && primaryFeedAction.exists
            },
            "Saving a real feed default did not return to the configured Feed screen."
        )
        assertManualFeedPrimaryReady(in: app)
        tapWhenHittable(closeFeed, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !feedDetail.exists })
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: completedDailyCare)
                    .localizedCaseInsensitiveContains("existing information")
            },
            "The real feed setup did not replace the same-session unknown answer."
        )
        XCTAssertFalse(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not sure yet"),
            "The stale Daily Care unknown answer still overrode the real setup."
        )
        assertMemberCardProgress("1/3", in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "The partial Pet profile changed the coconut balance before an explicit claim."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15), "The partial Pet profile task did not survive relaunch.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDailyCare.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("existing information"),
            "The real Daily Care setup resumed as an unknown answer after relaunch."
        )
        XCTAssertFalse(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not sure yet"),
            "The obsolete Daily Care unknown answer returned after relaunch."
        )

        tapGuidedJourneyControlAfterSemanticScroll(openDailyCare, in: app)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12))
        assertManualFeedPrimaryReady(in: app)
        XCTAssertFalse(saveManualSettings.exists, "The saved feed default was lost after relaunch.")
        tapWhenHittable(closeFeed, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !feedDetail.exists })
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 12))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petBodyProfile-notApplicable"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petPersonalityAppearance-preferNotToSay"],
            in: app
        )
        assertMemberCardProgress("3/3", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Three completed Pet profile questions did not finish the journey."
        )

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Pet profile completion did not stay separate from its reward claim."
        )

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "Finishing the Pet profile granted its reward before Claim."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            }
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-completeFirstPetProfile"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists })

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "Claiming the Pet profile reward did not add exactly 100 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "Relaunch duplicated or lost the Pet profile reward."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            identityAction.waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed Pet profile relaunch."
        )
        XCTAssertFalse(action.exists, "The claimed Pet profile task returned after relaunch.")
    }

    @MainActor
    func testPetProfileEditorCancelCloseAndDateSaveCompletesLifeStage() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        let action = app.buttons[
            "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile"
        ]
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The first-pet profile task did not appear.")
        tapWhenHittable(action, timeout: 8)

        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeFirstPetProfile"
        ]
        let lifeStageQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petLifeStage"
        ]
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-open-petLifeStage"], in: app)
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The pet date editor did not open.")
        let birthdayToggle = app.switches["pet-basic-info-birthday-toggle"]
        scrollToElement(birthdayToggle, in: app, maxSwipes: 6)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(birthdayToggle, timeout: 8),
            "The birthday toggle did not become semantically tappable."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-birthday-date-picker"]
                .waitForExistence(timeout: 8),
            "Enabling the birthday did not reveal its date picker."
        )

        discardPetBasicInfoChanges(in: app)
        let close = app.buttons["pet-basic-info-close-action"]
        XCTAssertTrue(close.waitForExistence(timeout: 8), "Cancel did not expose a clear return action.")
        tapWhenHittable(close, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !editor.exists }, "Close did not return to the guided question.")
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-open-petLifeStage"], in: app)
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        let homeDateToggle = app.switches["pet-basic-info-home-date-toggle"]
        scrollToElement(homeDateToggle, in: app, maxSwipes: 6)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(homeDateToggle, timeout: 8),
            "The home-date toggle did not become semantically tappable."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-home-date-picker"]
                .waitForExistence(timeout: 8),
            "Enabling the home date did not reveal its date picker."
        )
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)

        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists }, "Saving did not return to the guided question.")
        assertMemberCardProgress("3/3", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Saving a real pet date did not complete the life-stage checkpoint."
        )
    }

    @MainActor
    func testPetProfileBodyNotApplicablePersonalityPrivateAndDailyReviewedCompletesAnyThree() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_SEED_SPARSE_PET_PROFILE_BASELINE"]
        )
        let coconutBalance = app.buttons["home-coconut-action"]
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20), "The sparse Pet baseline did not reach Home.")
        let balanceBeforeClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(balanceBeforeClaim, 0, "The sparse Pet baseline balance was unreadable.")

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The sparse Pet profile journey did not reach Tasks."
        )

        let action = app.buttons[
            "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeFirstPetProfile"
        ]
        let lifeStageQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petLifeStage"
        ]
        let bodyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petBodyProfile"
        ]
        let personalityQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petPersonalityAppearance"
        ]
        let dailyCareQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petDailyCare"
        ]

        XCTAssertTrue(action.waitForExistence(timeout: 12), "The sparse Pet profile task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The sparse Pet profile sheet did not open.")
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8), "Next did not reach the Pet body question.")
        assertMemberCardProgress("0/3", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "task-center-starter-answer-complete-checkpoint-petLifeStage"
            ].exists,
            "Moving to the next question must not answer the Pet life-stage question."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petBodyProfile-notApplicable"],
            in: app
        )
        XCTAssertTrue(
            personalityQuestion.waitForExistence(timeout: 8),
            "Not applicable did not advance from body to personality."
        )
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petPersonalityAppearance-preferNotToSay"],
            in: app
        )
        XCTAssertTrue(
            dailyCareQuestion.waitForExistence(timeout: 8),
            "Prefer not to say did not advance from personality to daily care."
        )
        assertMemberCardProgress("2/3", in: app)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Closing the sparse Pet journey did not dismiss it.")

        // Re-enter Tasks through normal tab semantics so the reopened sheet is
        // built from persisted checkpoint records rather than local sheet state.
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 8))
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The incomplete sparse Pet task did not remain available.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            lifeStageQuestion.waitForExistence(timeout: 8),
            "Reopening did not start from the first still-incomplete Life Stage question."
        )
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        let bodyAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petBodyProfile"
        ]
        XCTAssertTrue(bodyAnswer.waitForExistence(timeout: 8), "The persisted body answer marker was missing.")
        XCTAssertTrue(
            accessibilityText(for: bodyAnswer).localizedCaseInsensitiveContains("Not applicable"),
            "The persisted body answer did not retain Not applicable."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        let personalityAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petPersonalityAppearance"
        ]
        XCTAssertTrue(
            personalityAnswer.waitForExistence(timeout: 8),
            "The persisted personality answer marker was missing."
        )
        XCTAssertTrue(
            accessibilityText(for: personalityAnswer).localizedCaseInsensitiveContains("Prefer not to say"),
            "The persisted personality answer did not retain Prefer not to say."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petDailyCare-reviewed"],
            in: app
        )
        assertMemberCardProgress("3/3", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The three privacy-safe Pet profile answers did not complete the journey."
        )

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Pet profile Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The completed sparse Pet profile did not expose its separate Claim state."
        )

        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The sparse Pet profile Claim sheet did not open.")
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-completeFirstPetProfile"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Claiming the Pet profile reward did not close its sheet.")
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists }, "The claimed sparse Pet profile task remained visible.")

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "Claiming the sparse Pet profile reward did not add exactly 100 coconuts."
        )
    }

    @MainActor
    func testPetProfileReviewedThenRealAnswersPersistAcrossRelaunch() throws {
        let petName = "Codex Sparse Pet Profile"
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_SEED_SPARSE_PET_PROFILE_BASELINE"]
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let action = app.buttons[
            "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeFirstPetProfile"
        ]
        let lifeStageQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petLifeStage"
        ]
        let bodyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petBodyProfile"
        ]
        let personalityQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petPersonalityAppearance"
        ]
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        let boyLabels = ["♂ Boy", "♂ 男孩", "♂ Junge"]
        let coconutBalance = app.buttons["home-coconut-action"]

        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20))
        let balanceBeforeClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(balanceBeforeClaim, 0, "The sparse Pet balance was unreadable.")
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12))
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petLifeStage-reviewed"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/3", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petBodyProfile-unknown"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("2/3", in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15), "The partial sparse Pet task did not survive relaunch.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            personalityQuestion.waitForExistence(timeout: 8),
            "Relaunch did not resume at the first incomplete Pet profile question."
        )
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        let persistedUnknown = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petBodyProfile"
        ]
        XCTAssertTrue(persistedUnknown.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: persistedUnknown).localizedCaseInsensitiveContains("Not sure yet"),
            "Relaunch did not preserve the unknown Body answer."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petBodyProfile"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The completed Body editor did not reopen.")
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.firstHittableButton(labels: boyLabels, in: app) != nil },
            "The Body editor did not expose a semantic Boy segment."
        )
        guard let boy = firstHittableButton(labels: boyLabels, in: app) else {
            return XCTFail("The Boy segment was not semantically tappable.")
        }
        XCTAssertFalse(boy.isSelected, "The sparse Body fixture unexpectedly started with Boy selected.")
        boy.tap()
        XCTAssertTrue(waitUntil(timeout: 8) { boy.isSelected })
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !editor.exists },
            "Saving a fact for an already completed Body checkpoint did not return to its guide."
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: persistedUnknown)
                    .localizedCaseInsensitiveContains("existing information")
            },
            "The real Body fact did not replace the same-checkpoint unknown answer."
        )
        XCTAssertFalse(
            accessibilityText(for: persistedUnknown).localizedCaseInsensitiveContains("Not sure yet"),
            "The old unknown Body answer still overrode the saved fact."
        )
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        let lifeStageAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petLifeStage"
        ]
        XCTAssertTrue(lifeStageAnswer.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: lifeStageAnswer).localizedCaseInsensitiveContains("Current status reviewed"),
            "The initial reviewed Life Stage answer was not preserved before replacement."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petLifeStage"],
            in: app
        )
        let birthdayToggle = app.switches["pet-basic-info-birthday-toggle"]
        let homeDateToggle = app.switches["pet-basic-info-home-date-toggle"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8))
        XCTAssertTrue(homeDateToggle.waitForExistence(timeout: 8))
        XCTAssertFalse(isToggleOn(birthdayToggle), "Reviewing Life Stage fabricated a birthday before editing.")
        XCTAssertFalse(isToggleOn(homeDateToggle), "Reviewing Life Stage fabricated a home date before editing.")
        tapGuidedJourneyControlAfterSemanticScroll(homeDateToggle, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-home-date-picker"]
                .waitForExistence(timeout: 8),
            "Enabling the home date did not reveal its date picker."
        )
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)

        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists })
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: lifeStageAnswer)
                    .localizedCaseInsensitiveContains("existing information")
            },
            "The real home date did not replace the reviewed Life Stage answer."
        )
        XCTAssertFalse(
            accessibilityText(for: lifeStageAnswer).localizedCaseInsensitiveContains("Current status reviewed"),
            "The reviewed Life Stage answer still overrode the saved home date."
        )
        assertMemberCardProgress("2/3", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petPersonalityAppearance-notApplicable"],
            in: app
        )
        assertMemberCardProgress("3/3", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The final Personality answer did not complete the mixed sparse Pet profile."
        )
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The mixed sparse Pet profile did not expose Claim."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-completeFirstPetProfile"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists })
        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "The mixed sparse Pet profile claim did not add exactly 100 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 100
            },
            "Relaunch duplicated or lost the sparse Pet profile reward."
        )
        openPetBasicInfoFromHome(in: app, petName: petName)
        openPetBasicInfoEditMode(in: app)
        XCTAssertTrue(birthdayToggle.waitForExistence(timeout: 8))
        XCTAssertTrue(homeDateToggle.waitForExistence(timeout: 8))
        XCTAssertFalse(isToggleOn(birthdayToggle), "The reviewed birthday was fabricated after relaunch.")
        XCTAssertTrue(isToggleOn(homeDateToggle), "The real saved home date was lost after relaunch.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.buttons.matching(NSPredicate(format: "label IN %@", boyLabels)).firstMatch.isSelected
            },
            "The real Body value that replaced unknown was lost after relaunch."
        )
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
    }

    @MainActor
    func testPetProfileBodyAndPersonalityRealSavesSurviveRelaunch() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_SEED_SPARSE_PET_PROFILE_BASELINE"]
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let action = app.buttons[
            "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeFirstPetProfile"
        ]
        let lifeStageQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petLifeStage"
        ]
        let bodyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petBodyProfile"
        ]
        let personalityQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petPersonalityAppearance"
        ]
        let dailyCareQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petDailyCare"
        ]
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        let saveAction = app.buttons["pet-basic-info-save-action"]
        let boyLabels = ["♂ Boy", "♂ 男孩", "♂ Junge"]
        let curiousLabels = ["Curious soul", "好奇宝宝", "Neugierig"]
        let curiousOption = app.buttons["pet-basic-info-primary-personality-option-curious"]

        XCTAssertTrue(homeTab.waitForExistence(timeout: 20), "The sparse Pet baseline did not reach Home.")
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The sparse Pet profile task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8), "Next did not reach the Pet body question.")
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petBodyProfile"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The Pet body editor did not open.")
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.firstHittableButton(labels: boyLabels, in: app) != nil },
            "The Pet body editor did not expose the Boy segment."
        )
        guard let boy = firstHittableButton(labels: boyLabels, in: app) else {
            return XCTFail("The Boy segment was not semantically tappable.")
        }
        XCTAssertFalse(boy.isSelected, "The sparse Pet fixture unexpectedly started with Boy selected.")
        boy.tap()
        XCTAssertTrue(waitUntil(timeout: 8) { boy.isSelected }, "Selecting Boy did not update the segment state.")
        XCTAssertTrue(waitUntil(timeout: 8) { saveAction.exists && saveAction.isEnabled && saveAction.isHittable })
        saveAction.tap()

        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists }, "Saving Body did not return to the guided card.")
        XCTAssertTrue(
            personalityQuestion.waitForExistence(timeout: 12),
            "Saving a real Body answer did not advance to Personality."
        )
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petPersonalityAppearance"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The Pet personality editor did not open.")
        XCTAssertTrue(
            curiousOption.waitForExistence(timeout: 8),
            "The primary personality choices did not appear."
        )
        tapGuidedJourneyControlAfterSemanticScroll(curiousOption, in: app)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                curiousOption.isSelected
                    || String(describing: curiousOption.value ?? "")
                    .localizedCaseInsensitiveCompare("Selected") == .orderedSame
            },
            "Selecting Curious soul did not update the personality choices."
        )
        XCTAssertTrue(waitUntil(timeout: 8) { saveAction.exists && saveAction.isEnabled && saveAction.isHittable })
        saveAction.tap()

        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists }, "Saving Personality did not return to the guided card.")
        XCTAssertTrue(
            dailyCareQuestion.waitForExistence(timeout: 12),
            "Saving a real Personality answer did not advance to Daily Care."
        )
        assertMemberCardProgress("2/3", in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20), "Home was not reachable after relaunch.")
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15), "The partial Pet profile task did not survive relaunch.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("2/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        let bodyAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petBodyProfile"
        ]
        XCTAssertTrue(bodyAnswer.waitForExistence(timeout: 8), "The real Body answer was lost after relaunch.")
        XCTAssertTrue(
            accessibilityText(for: bodyAnswer).localizedCaseInsensitiveContains("existing information"),
            "Body resumed as a skip resolution instead of persisted profile data."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        let personalityAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petPersonalityAppearance"
        ]
        XCTAssertTrue(
            personalityAnswer.waitForExistence(timeout: 8),
            "The real Personality answer was lost after relaunch."
        )
        XCTAssertTrue(
            accessibilityText(for: personalityAnswer).localizedCaseInsensitiveContains("existing information"),
            "Personality resumed as a skip resolution instead of persisted profile data."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petPersonalityAppearance"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.buttons.matching(NSPredicate(format: "label IN %@", boyLabels)).firstMatch.isSelected
            },
            "The saved Boy segment was not projected after relaunch."
        )
        XCTAssertTrue(
            curiousOption.waitForExistence(timeout: 8)
                && curiousLabels.contains { curiousOption.label.localizedCaseInsensitiveContains($0) }
                && (curiousOption.isSelected
                    || String(describing: curiousOption.value ?? "")
                    .localizedCaseInsensitiveCompare("Selected") == .orderedSame),
            "The saved Curious soul value was not projected after relaunch."
        )
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
        let closeAction = app.buttons["pet-basic-info-close-action"]
        XCTAssertTrue(closeAction.waitForExistence(timeout: 8))
        tapWhenHittable(closeAction, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !editor.exists })
    }

    @MainActor
    func testPetDailyCareNotApplicableThenRealSetupSupersedesResolutionAcrossRelaunch() throws {
        let app = launchEnglishApp(
            seedMemberCardBaseline: true,
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_SEED_SPARSE_PET_PROFILE_BASELINE"]
        )
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let action = app.buttons[
            "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-completeFirstPetProfile"
        ]
        let lifeStageQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petLifeStage"
        ]
        let bodyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petBodyProfile"
        ]
        let personalityQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petPersonalityAppearance"
        ]
        let dailyCareQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petDailyCare"
        ]
        let completedDailyCare = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petDailyCare"
        ]
        let openDailyCare = app.buttons["task-center-starter-journey-open-petDailyCare"]
        let feedDetail = app.descendants(matching: .any)["quick-feed-detail-screen"]
        let saveManualSettings = app.buttons["quick-feed-manual-settings-save"]
        let primaryFeedAction = app.buttons["quick-feed-primary-action"]
        let closeFeed = app.buttons["quick-feed-detail-close-action"]

        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) {
            tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable
        })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The sparse Pet profile task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petDailyCare-notApplicable"],
            in: app
        )
        XCTAssertTrue(
            lifeStageQuestion.waitForExistence(timeout: 8),
            "Resolving Daily Care did not return to the first unanswered Pet question."
        )
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDailyCare.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not applicable"),
            "The explicit Daily Care answer was not displayed."
        )

        tapGuidedJourneyControlAfterSemanticScroll(openDailyCare, in: app)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12), "Daily Care did not open Quick Feed.")
        if !saveManualSettings.waitForExistence(timeout: 4) {
            tapWhenHittable(primaryFeedAction, timeout: 8)
        }
        XCTAssertTrue(saveManualSettings.waitForExistence(timeout: 12), "The sparse Pet did not request feed setup.")
        tapWhenHittable(app.buttons["quick-feed-sheet-cancel-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !saveManualSettings.exists && feedDetail.exists },
            "Cancelling feed setup did not keep the unchanged Daily Care screen open."
        )
        tapWhenHittable(closeFeed, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !feedDetail.exists })
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 12))
        XCTAssertTrue(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not applicable"),
            "Cancelling feed setup changed the completed Daily Care answer."
        )
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(openDailyCare, in: app)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12))
        if !saveManualSettings.waitForExistence(timeout: 4) {
            tapWhenHittable(primaryFeedAction, timeout: 8)
        }
        XCTAssertTrue(saveManualSettings.waitForExistence(timeout: 12))
        tapWhenHittable(saveManualSettings, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !saveManualSettings.exists && primaryFeedAction.exists
            },
            "Saving a real feed default did not return to the configured Feed screen."
        )
        assertManualFeedPrimaryReady(in: app)
        XCTAssertTrue(
            feedDetail.exists,
            "Saving an already completed Daily Care checkpoint unexpectedly closed its review screen."
        )
        tapWhenHittable(closeFeed, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !feedDetail.exists })
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: completedDailyCare)
                    .localizedCaseInsensitiveContains("existing information")
            },
            "The real feed setup did not replace the same-session Not applicable answer."
        )
        XCTAssertFalse(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not applicable"),
            "The stale Daily Care resolution still overrode the real setup."
        )
        assertMemberCardProgress("1/3", in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) {
            tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable
        })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15), "The partial Pet profile task did not survive relaunch.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(lifeStageQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/3", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(bodyQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(personalityQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(dailyCareQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDailyCare.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("existing information"),
            "The real Daily Care setup resumed as a skip resolution after relaunch."
        )
        XCTAssertFalse(
            accessibilityText(for: completedDailyCare).localizedCaseInsensitiveContains("Not applicable"),
            "The obsolete Daily Care resolution returned after relaunch."
        )

        tapGuidedJourneyControlAfterSemanticScroll(openDailyCare, in: app)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12))
        assertManualFeedPrimaryReady(in: app)
        XCTAssertFalse(saveManualSettings.exists, "The saved feed default was lost after relaunch.")
        tapWhenHittable(closeFeed, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !feedDetail.exists })
    }

    @MainActor
    func testPetIdentityNotApplicableResumesThenEmergencyContactSaveCompletes() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The first-pet identity journey did not reach Tasks."
        )

        let action = app.buttons[
            "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection"
        ]
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The first-pet identity task did not appear.")
        tapWhenHittable(action, timeout: 8)

        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetIdentityProtection"
        ]
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The first-pet identity guided sheet did not open.")

        let documentsQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petIdentityDocuments"
        ]
        let emergencyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petEmergencyContact"
        ]
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petIdentityDocuments-notApplicable"],
            in: app
        )
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 8),
            "Choosing Not applicable did not advance to the remaining identity question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !sheet.exists }, "Closing the identity journey did not dismiss it.")
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The incomplete identity task did not remain available.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 8),
            "Reopening did not resume at the remaining identity question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(
            documentsQuestion.waitForExistence(timeout: 8),
            "Previous did not open the completed identity question for review."
        )
        let completedDocumentsAnswer = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petIdentityDocuments"
        ]
        XCTAssertTrue(
            completedDocumentsAnswer.waitForExistence(timeout: 8),
            "The completed identity question did not show its persisted answer."
        )
        XCTAssertTrue(
            completedDocumentsAnswer.label.localizedCaseInsensitiveContains("Not applicable"),
            "The completed identity question did not preserve the Not applicable answer."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 8),
            "Next did not return from answer review to the remaining identity question."
        )
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petEmergencyContact"],
            in: app
        )
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        let vetContact = app.textFields["pet-basic-info-vet-contact-input"]
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The emergency-contact editor did not open.")
        scrollTowardElement(vetContact, in: app, maxSwipes: 8)
        XCTAssertTrue(vetContact.waitForExistence(timeout: 8), "The emergency phone field was not available.")
        tapWhenHittable(vetContact, timeout: 8)
        vetContact.typeText("5550107")
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)

        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists }, "Saving did not return to the identity journey.")
        assertMemberCardProgress("2/2", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The identity journey did not complete after the mixed skip-and-save path."
        )
    }

    @MainActor
    func testPetIdentityDocumentCancelReviewedThenRealSaveSupersedesResolutionAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let action = app.buttons[
            "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetIdentityProtection"
        ]
        let documentsQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petIdentityDocuments"
        ]
        let emergencyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petEmergencyContact"
        ]
        let documentsScreen = app.descendants(matching: .any)["pet-documents-screen"]
        let addDocument = app.buttons["pet-documents-add-document-action"]
        let documentEditor = app.descendants(matching: .any)["protection-document-editor"]
        let cancelDocument = app.buttons["protection-document-cancel-action"]
        let saveDocument = app.buttons["protection-document-save-action"]

        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The identity task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petIdentityDocuments"],
            in: app
        )
        XCTAssertTrue(documentsScreen.waitForExistence(timeout: 12), "The Documents screen did not open.")
        XCTAssertTrue(addDocument.waitForExistence(timeout: 8), "The empty Documents screen had no Add action.")
        tapWhenHittable(addDocument, timeout: 8)
        XCTAssertTrue(documentEditor.waitForExistence(timeout: 12), "The document editor did not open.")
        XCTAssertTrue(cancelDocument.waitForExistence(timeout: 8))
        tapWhenHittable(cancelDocument, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !documentEditor.exists }, "Cancel did not dismiss the document editor.")
        XCTAssertTrue(documentsScreen.exists, "Cancel unexpectedly dismissed the Documents screen.")
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-documents-document-row-"))
                .firstMatch.exists,
            "Cancelling document creation fabricated a document row."
        )
        tapWhenHittable(app.buttons["pet-documents-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !documentsScreen.exists })
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)
        XCTAssertFalse(
            app.descendants(matching: .any)[
                "task-center-starter-answer-complete-checkpoint-petIdentityDocuments"
            ].exists,
            "Cancelling document creation completed the identity question."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petIdentityDocuments-reviewed"],
            in: app
        )
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 8),
            "Reviewing the current Documents status did not advance to Emergency Contact."
        )
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        let completedDocuments = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petIdentityDocuments"
        ]
        XCTAssertTrue(completedDocuments.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDocuments).localizedCaseInsensitiveContains("Current status reviewed"),
            "The reviewed Documents answer was not shown before real data replaced it."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petIdentityDocuments"],
            in: app
        )
        XCTAssertTrue(documentsScreen.waitForExistence(timeout: 12))
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-documents-document-row-"))
                .firstMatch.exists,
            "Reviewing the current Documents status fabricated a document row."
        )
        tapWhenHittable(addDocument, timeout: 8)
        XCTAssertTrue(documentEditor.waitForExistence(timeout: 12))
        let authority = app.textFields["protection-document-authority-input"]
        XCTAssertTrue(authority.waitForExistence(timeout: 8), "The passport authority field was unavailable.")
        XCTAssertTrue(
            app.textFields["protection-document-title-input"].exists,
            "The default passport title field was unavailable."
        )
        tapWhenHittable(authority, timeout: 8)
        authority.typeText("Codex Passport Office")
        XCTAssertTrue(waitUntil(timeout: 8) { saveDocument.exists && saveDocument.isEnabled && saveDocument.isHittable })
        saveDocument.tap()

        XCTAssertTrue(waitUntil(timeout: 12) { !documentEditor.exists }, "Saving did not dismiss the document editor.")
        XCTAssertTrue(
            documentsScreen.exists,
            "Saving from an already completed checkpoint unexpectedly closed Documents."
        )
        let savedDocument = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pet-documents-document-row-")
        ).firstMatch
        XCTAssertTrue(
            savedDocument.waitForExistence(timeout: 12),
            "Saving the real passport did not create a document row."
        )
        tapWhenHittable(app.buttons["pet-documents-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !documentsScreen.exists })
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: completedDocuments)
                    .localizedCaseInsensitiveContains("existing information")
            },
            "The real passport did not replace the same-session reviewed answer."
        )
        XCTAssertFalse(
            accessibilityText(for: completedDocuments).localizedCaseInsensitiveContains("Current status reviewed"),
            "The old reviewed answer still overrode the saved passport."
        )
        assertMemberCardProgress("1/2", in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) { tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15), "The partial identity task did not survive relaunch.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDocuments.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDocuments).localizedCaseInsensitiveContains("existing information"),
            "The saved passport resumed as a reviewed resolution instead of persisted data."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petIdentityDocuments"],
            in: app
        )
        XCTAssertTrue(documentsScreen.waitForExistence(timeout: 12))
        let persistedDocument = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pet-documents-document-row-")
        ).firstMatch
        XCTAssertTrue(persistedDocument.waitForExistence(timeout: 12), "The saved passport row was lost after relaunch.")
        XCTAssertTrue(
            app.staticTexts["Codex Passport Office"].exists,
            "The saved passport authority was not projected after relaunch."
        )
        tapWhenHittable(app.buttons["pet-documents-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !documentsScreen.exists })
    }

    @MainActor
    func testPetEmergencyContactNotApplicableThenRealSaveSupersedesResolutionAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let action = app.buttons[
            "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetIdentityProtection"
        ]
        let documentsQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petIdentityDocuments"
        ]
        let emergencyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petEmergencyContact"
        ]
        let completedDocuments = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petIdentityDocuments"
        ]
        let completedEmergency = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petEmergencyContact"
        ]
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        let vetContact = app.textFields["pet-basic-info-vet-contact-input"]
        let saveAction = app.buttons["pet-basic-info-save-action"]
        let phone = "5550199"

        XCTAssertTrue(waitUntil(timeout: 8) {
            tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable
        })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The identity task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 8),
            "Next did not reach the unanswered Emergency Contact question."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petEmergencyContact-notApplicable"],
            in: app
        )
        XCTAssertTrue(
            documentsQuestion.waitForExistence(timeout: 8),
            "Completing Emergency Contact did not return to the remaining Documents question."
        )
        assertMemberCardProgress("1/2", in: app)
        XCTAssertFalse(
            completedDocuments.exists,
            "Resolving Emergency Contact unexpectedly completed Documents."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(
            completedEmergency.waitForExistence(timeout: 8),
            "The completed Emergency Contact question did not expose its answer."
        )
        XCTAssertTrue(
            accessibilityText(for: completedEmergency).localizedCaseInsensitiveContains("Not applicable"),
            "The explicit Emergency Contact resolution was not displayed."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petEmergencyContact"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The emergency-contact editor did not open.")
        scrollTowardElement(vetContact, in: app, maxSwipes: 8)
        XCTAssertTrue(vetContact.waitForExistence(timeout: 8), "The emergency phone field was unavailable.")
        tapWhenHittable(vetContact, timeout: 8)
        vetContact.typeText(phone)
        XCTAssertTrue(waitUntil(timeout: 8) {
            saveAction.exists && saveAction.isEnabled && saveAction.isHittable
        })
        saveAction.tap()

        XCTAssertTrue(
            waitUntil(timeout: 12) { !editor.exists },
            "Saving the real emergency phone did not return to the guided card."
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: completedEmergency)
                    .localizedCaseInsensitiveContains("existing information")
            },
            "The real emergency phone did not replace the same-session Not applicable answer."
        )
        XCTAssertFalse(
            accessibilityText(for: completedEmergency).localizedCaseInsensitiveContains("Not applicable"),
            "The stale Emergency Contact resolution still overrode the real phone."
        )
        assertMemberCardProgress("1/2", in: app)
        XCTAssertFalse(
            completedDocuments.exists,
            "Saving Emergency Contact unexpectedly completed Documents."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(waitUntil(timeout: 8) {
            tasksTab.exists && tasksTab.isEnabled && tasksTab.isHittable
        })
        tasksTab.tap()
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15), "The partial identity task did not survive relaunch.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            documentsQuestion.waitForExistence(timeout: 8),
            "The partial identity task did not resume at unanswered Documents."
        )
        assertMemberCardProgress("1/2", in: app)
        XCTAssertFalse(completedDocuments.exists, "Documents became completed after relaunch.")

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedEmergency.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedEmergency).localizedCaseInsensitiveContains("existing information"),
            "The real emergency phone resumed as a skip resolution after relaunch."
        )
        XCTAssertFalse(
            accessibilityText(for: completedEmergency).localizedCaseInsensitiveContains("Not applicable"),
            "The obsolete Emergency Contact resolution returned after relaunch."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petEmergencyContact"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        scrollTowardElement(vetContact, in: app, maxSwipes: 8)
        XCTAssertTrue(vetContact.waitForExistence(timeout: 8))
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.accessibilityText(for: vetContact).contains(phone) },
            "The saved emergency phone was not projected after relaunch."
        )

        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
        let closeAction = app.buttons["pet-basic-info-close-action"]
        XCTAssertTrue(closeAction.waitForExistence(timeout: 8))
        tapWhenHittable(closeAction, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !editor.exists })
    }

    @MainActor
    func testPetIdentityPrivateDocumentsAndUnknownEmergencyPersistAcrossRelaunchWithoutFabricationAndRewardsOnce() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let petName = completeFirstDayStarterFunnel(in: app)

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(
            taskCenter.waitForExistence(timeout: 12),
            "The identity reward-resume journey did not reach Tasks."
        )

        let action = app.buttons[
            "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetIdentityProtection"
        ]
        let documentsQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petIdentityDocuments"
        ]
        let completedDocuments = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petIdentityDocuments"
        ]
        let emergencyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petEmergencyContact"
        ]
        let completedEmergency = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petEmergencyContact"
        ]
        let documentsScreen = app.descendants(matching: .any)["pet-documents-screen"]
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        let cancelledDraftPhone = "5550198"
        let emergencyFieldExpectations = [
            (identifier: "pet-basic-info-vet-clinic-input", placeholder: "Clinic"),
            (identifier: "pet-basic-info-vet-doctor-input", placeholder: "Doctor"),
            (identifier: "pet-basic-info-vet-contact-input", placeholder: "Phone"),
            (identifier: "pet-basic-info-vet-address-input", placeholder: "Clinic address"),
            (identifier: "pet-basic-info-allergies-input", placeholder: "Allergies")
        ]
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The identity starter task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The identity guided sheet did not open.")
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petIdentityDocuments-preferNotToSay"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDocuments.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDocuments).localizedCaseInsensitiveContains("Prefer not to say"),
            "The Documents question did not preserve its private answer."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petIdentityDocuments"],
            in: app
        )
        XCTAssertTrue(documentsScreen.waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons["pet-documents-add-document-action"].waitForExistence(timeout: 8),
            "The Documents screen did not finish loading."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-documents-document-row-", in: app),
            0,
            "Choosing Prefer not to say fabricated an identity document."
        )
        tapWhenHittable(app.buttons["pet-documents-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !documentsScreen.exists })
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petEmergencyContact"],
            in: app
        )
        XCTAssertTrue(editor.waitForExistence(timeout: 12), "The emergency-contact editor did not open.")
        let draftPhoneField = app.textFields["pet-basic-info-vet-contact-input"]
        scrollTowardElement(draftPhoneField, in: app, maxSwipes: 8)
        XCTAssertTrue(draftPhoneField.waitForExistence(timeout: 8), "The emergency phone field was unavailable.")
        tapWhenHittable(draftPhoneField, timeout: 8)
        draftPhoneField.typeText(cancelledDraftPhone)
        dismissKeyboardIfPresent(in: app)
        discardPetBasicInfoChanges(in: app)
        let closeEditor = app.buttons["pet-basic-info-close-action"]
        XCTAssertTrue(closeEditor.waitForExistence(timeout: 8))
        tapWhenHittable(closeEditor, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists })
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 12),
            "Cancelling the emergency draft did not return to its unanswered question."
        )
        assertMemberCardProgress("1/2", in: app)
        XCTAssertFalse(completedEmergency.exists, "Cancelling the emergency draft completed the question.")

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petEmergencyContact-unknown"],
            in: app
        )
        assertMemberCardProgress("2/2", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The private Documents and unknown Emergency answers did not complete the guided journey."
        )

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Identity Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The completed identity journey did not expose its separate Claim state."
        )

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let balanceBeforeClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(balanceBeforeClaim, 0, "The pre-claim coconut balance was unreadable.")

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The identity task did not retain Claim before opening its reward sheet."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The identity Claim sheet did not open.")
        XCTAssertTrue(
            app.buttons["task-center-starter-journey-claim-confirmPetIdentityProtection"]
                .waitForExistence(timeout: 8),
            "The identity reward action was unavailable before closing the Claim sheet."
        )
        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Closing the identity Claim sheet did not dismiss it.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Closing the identity Claim sheet lost its claimable task state."
        )

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "Closing the identity Claim sheet changed the balance before an explicit claim."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "Relaunch changed the balance before the explicit identity Claim."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The identity task did not remain claimable after relaunch."
        )

        tapWhenHittable(homeTab, timeout: 8)
        openPetBasicInfoFromHome(in: app, petName: petName)
        XCTAssertTrue(editor.waitForExistence(timeout: 12))
        tapWhenHittable(app.buttons["pet-basic-info-edit-action"], timeout: 8)
        for expectation in emergencyFieldExpectations {
            let field = app.textFields[expectation.identifier]
            scrollTowardElement(field, in: app, maxSwipes: 8)
            XCTAssertTrue(field.waitForExistence(timeout: 8), "\(expectation.identifier) was unavailable after relaunch.")
            let value = String(describing: field.value ?? "")
            XCTAssertTrue(
                value.isEmpty || value == expectation.placeholder,
                "The private or unknown answer fabricated \(expectation.identifier): \(value)"
            )
            if expectation.identifier == "pet-basic-info-vet-contact-input" {
                XCTAssertFalse(
                    value.contains(cancelledDraftPhone),
                    "The cancelled emergency phone draft survived relaunch."
                )
            }
        }
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
        tapWhenHittable(app.buttons["BackButton"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists })
        collapseExpandedPetCardIfNeeded(in: app)

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Inspecting the cancelled emergency draft lost the claimable identity task."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The identity Claim sheet did not reopen.")
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetIdentityProtection"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Claiming the identity reward did not close its sheet.")
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists }, "The claimed identity task remained visible.")

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 60
            },
            "Reopening and claiming the identity reward did not add exactly 60 coconuts once."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 60
            },
            "The second relaunch duplicated or lost the identity reward."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons[
                "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
            ].waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed identity relaunch."
        )
        XCTAssertFalse(action.exists, "The claimed identity task returned after relaunch.")
    }

    @MainActor
    func testPetIdentityUnknownDocumentsReviewedEmergencyPersistWithoutFabricationAndRewardsOnce() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let petName = "Codex Unknown Identity Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not reach the unknown identity journey in time."
        )

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let coconutBalance = app.buttons["home-coconut-action"]
        let action = app.buttons[
            "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetIdentityProtection"
        ]
        let documentsQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petIdentityDocuments"
        ]
        let emergencyQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petEmergencyContact"
        ]
        let completedDocuments = app.descendants(matching: .any)[
            "task-center-starter-answer-complete-checkpoint-petIdentityDocuments"
        ]
        let documentsScreen = app.descendants(matching: .any)["pet-documents-screen"]
        let addDocument = app.buttons["pet-documents-add-document-action"]

        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let balanceBeforeClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertEqual(balanceBeforeClaim, 50, "The identity branch did not start from the starter gift balance.")
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The identity task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/2", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petIdentityDocuments-unknown"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDocuments.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDocuments).localizedCaseInsensitiveContains("Not sure yet"),
            "The Documents question did not show its explicit unknown answer."
        )
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(action.waitForExistence(timeout: 12))
        XCTAssertFalse(
            action.label.localizedCaseInsensitiveContains("Claim"),
            "Closing the partial unknown identity path made it claimable."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "Relaunch changed the balance for a partial identity answer."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 15))
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            emergencyQuestion.waitForExistence(timeout: 8),
            "Relaunch did not resume at the remaining Emergency Contact question."
        )
        assertMemberCardProgress("1/2", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-previous"],
            in: app
        )
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        XCTAssertTrue(completedDocuments.waitForExistence(timeout: 8))
        XCTAssertTrue(
            accessibilityText(for: completedDocuments).localizedCaseInsensitiveContains("Not sure yet"),
            "Relaunch lost the explicit unknown Documents answer."
        )

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-open-petIdentityDocuments"],
            in: app
        )
        XCTAssertTrue(documentsScreen.waitForExistence(timeout: 12))
        XCTAssertTrue(addDocument.waitForExistence(timeout: 8), "The Documents screen did not finish loading.")
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-documents-document-row-", in: app),
            0,
            "Choosing Not sure yet fabricated an identity document."
        )
        tapWhenHittable(app.buttons["pet-documents-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !documentsScreen.exists })
        XCTAssertTrue(documentsQuestion.waitForExistence(timeout: 8))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-question-next"],
            in: app
        )
        XCTAssertTrue(emergencyQuestion.waitForExistence(timeout: 8))

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petEmergencyContact-reviewed"],
            in: app
        )
        assertMemberCardProgress("2/2", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The reviewed Emergency Contact answer did not complete the identity journey."
        )
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Finish did not expose the identity Claim state."
        )

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "Finishing unknown and reviewed answers changed the balance before Claim."
        )
        openPetBasicInfoFromHome(in: app, petName: petName)
        let editor = app.descendants(matching: .any)["pet-basic-info-screen"]
        let vetContact = app.textFields["pet-basic-info-vet-contact-input"]
        tapWhenHittable(app.buttons["pet-basic-info-edit-action"], timeout: 8)
        scrollTowardElement(vetContact, in: app, maxSwipes: 8)
        XCTAssertTrue(vetContact.waitForExistence(timeout: 8))
        let emergencyPhoneValue = String(describing: vetContact.value ?? "")
        XCTAssertTrue(
            emergencyPhoneValue.isEmpty || emergencyPhoneValue == "Phone",
            "Choosing Current status reviewed fabricated an emergency phone: \(emergencyPhoneValue)"
        )
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
        tapWhenHittable(app.buttons["BackButton"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !editor.exists })
        collapseExpandedPetCardIfNeeded(in: app)

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim
            },
            "Relaunch changed the balance before the explicit identity Claim."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Relaunch did not preserve the identity Claim state."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetIdentityProtection"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists })
        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 60
            },
            "The explicit identity Claim did not add exactly 60 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeClaim + 60
            },
            "The second relaunch duplicated or lost the identity reward."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons[
                "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
            ].waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed identity relaunch."
        )
        XCTAssertFalse(action.exists, "The claimed identity task returned after relaunch.")
    }

    @MainActor
    func testStarterPreventiveHealthCancelResumeSaveAndClaimSeparation() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The starter health journey did not reach Tasks."
        )
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "The three prerequisite starter rewards did not reach the expected 310-coconut balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let action = app.buttons[
            "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetPreventiveCare"
        ]
        let question = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petHealthProtection"
        ]
        let openEditor = app.buttons["task-center-starter-journey-open-petHealthProtection"]
        let healthDetail = app.descendants(matching: .any)["pet-health-detail-screen"]
        let overview = app.descendants(matching: .any)["pet-health-overview-preventive"]
        let recordSheet = app.descendants(matching: .any)["pet-health-record-sheet"]

        XCTAssertTrue(action.waitForExistence(timeout: 12), "The preventive-health starter task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The preventive-health guided sheet did not open.")
        XCTAssertTrue(question.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openEditor, timeout: 8)
        XCTAssertTrue(overview.waitForExistence(timeout: 12), "The preventive overview did not open from the journey.")
        tapWhenHittable(app.buttons["pet-health-overview-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !overview.exists } && healthDetail.exists,
            "Closing the preventive overview did not return to the health detail editor."
        )
        tapWhenHittable(app.buttons["pet-health-detail-close-action"], timeout: 8)
        XCTAssertTrue(question.waitForExistence(timeout: 12), "Closing health detail did not return to the journey.")
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openEditor, timeout: 8)
        XCTAssertTrue(overview.waitForExistence(timeout: 12))
        tapWhenHittable(app.buttons["pet-health-overview-add-preventive-action"], timeout: 8)
        XCTAssertTrue(recordSheet.waitForExistence(timeout: 12), "Add preventive did not open the record sheet.")
        tapWhenHittable(app.buttons["pet-health-record-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !recordSheet.exists },
            "Cancelling the preventive record did not dismiss its sheet."
        )
        XCTAssertTrue(healthDetail.waitForExistence(timeout: 8))
        tapWhenHittable(app.buttons["pet-health-detail-close-action"], timeout: 8)
        XCTAssertTrue(question.waitForExistence(timeout: 12))
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !sheet.exists }, "Closing the incomplete health journey did not dismiss it.")
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The cancelled health task did not remain available.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(question.waitForExistence(timeout: 8), "Reopening did not resume the incomplete health question.")
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openEditor, timeout: 8)
        XCTAssertTrue(overview.waitForExistence(timeout: 12))
        tapWhenHittable(app.buttons["pet-health-overview-add-preventive-action"], timeout: 8)
        XCTAssertTrue(recordSheet.waitForExistence(timeout: 12))
        tapWhenHittable(app.buttons["pet-health-record-save-action"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 18),
            "Saving the default vaccine did not return to the completed health journey."
        )
        assertMemberCardProgress("1/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Saving preventive care claimed its reward automatically instead of exposing Claim."
        )

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let balanceBeforeHealthClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(
            balanceBeforeHealthClaim,
            310,
            "Saving the preventive record left the household below its pre-record balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The preventive-health task did not preserve its explicit Claim state."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetPreventiveCare"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Claiming the health reward did not close its sheet.")
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists }, "The claimed health task remained visible.")
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeHealthClaim + 80
            },
            "The explicit preventive-health claim did not add exactly 80 coconuts."
        )
    }

    @MainActor
    func testStarterPreventiveHealthClaimedNotApplicableThenRealRecordDoesNotResurrectAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex No Preventive Record Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not reach the starter health journey in time."
        )

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The Not applicable health journey did not reach Tasks."
        )
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "The three prerequisite starter rewards did not reach the expected 310-coconut balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let action = app.buttons[
            "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetPreventiveCare"
        ]
        let question = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petHealthProtection"
        ]
        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let nextTask = app.buttons[
            "task-center-system-action-configureFirstCarePlan-household-starter-v1-carePlan"
        ]
        let healthDetail = app.descendants(matching: .any)["pet-health-detail-screen"]
        let recentHealthRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pet-health-recent-row-")
        )

        XCTAssertTrue(action.waitForExistence(timeout: 12), "The preventive-health starter task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The preventive-health guided sheet did not open.")
        XCTAssertTrue(question.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/1", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-petHealthProtection-notApplicable"],
            in: app
        )
        assertMemberCardProgress("1/1", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Choosing Not applicable did not complete the preventive-health journey."
        )

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Finishing the Not applicable path claimed its reward instead of exposing Claim."
        )

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "Finishing the Not applicable path changed the balance before explicit Claim."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The preventive-health task did not preserve its explicit Claim state."
        )

        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetPreventiveCare"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Claiming the health reward did not close its sheet.")
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists }, "The claimed health task remained visible.")

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 390" },
            "The explicit Not applicable preventive-health claim did not add exactly 80 coconuts."
        )

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            0,
            "Choosing Not applicable fabricated a health record in the normal pet health UI."
        )
        XCTAssertTrue(
            app.staticTexts["No health records yet"].waitForExistence(timeout: 8),
            "The normal pet health UI did not retain its empty-record state after Not applicable."
        )

        tapWhenHittable(app.buttons["pet-health-fab-toggle"], timeout: 8)
        let preventiveAction = app.descendants(matching: .any)["pet-health-fab-action-preventive"]
        XCTAssertTrue(
            preventiveAction.waitForExistence(timeout: 8),
            "The normal Health menu did not expose Preventive care after the claimed answer."
        )
        tapWhenHittable(preventiveAction, timeout: 8)
        let recordSheet = app.descendants(matching: .any)["pet-health-record-sheet"]
        XCTAssertTrue(recordSheet.waitForExistence(timeout: 10))
        tapWhenHittable(app.buttons["pet-health-record-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !recordSheet.exists },
            "Saving the real preventive record did not dismiss its form."
        )
        XCTAssertTrue(healthDetail.waitForExistence(timeout: 8))
        XCTAssertTrue(
            recentHealthRows.firstMatch.waitForExistence(timeout: 18),
            "The real preventive record did not appear after the claimed privacy-preserving path."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "Saving one real preventive fact did not produce exactly one visible record."
        )
        let savedRowIdentifier = recentHealthRows.firstMatch.identifier
        XCTAssertFalse(savedRowIdentifier.isEmpty, "The saved health row did not expose a stable identity.")

        tapWhenHittable(app.buttons["pet-health-detail-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !healthDetail.exists })
        collapseExpandedPetCardIfNeeded(in: app)
        let allowedBalancesAfterRealHealthRecord = Set([400, 402, 408])
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                allowedBalancesAfterRealHealthRecord.contains(
                    Int(self.numericLabel(coconutBalance.label)) ?? -1
                )
            },
            "The real health record did not add its 10-coconut base reward plus an allowed luck bonus."
        )
        let balanceAfterRealHealthRecord = Int(numericLabel(coconutBalance.label)) ?? -1

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            nextTask.waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed health task."
        )
        XCTAssertFalse(action.exists, "Saving a real record resurrected the already-claimed health task.")

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceAfterRealHealthRecord
            },
            "Relaunch duplicated or lost a claimed health reward or real-record reward."
        )
        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertTrue(
            app.descendants(matching: .any)[savedRowIdentifier].waitForExistence(timeout: 18),
            "Relaunch did not read back the same real health record."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "Relaunch lost or duplicated the real health record."
        )
        tapWhenHittable(app.buttons["pet-health-detail-close-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !healthDetail.exists })
        collapseExpandedPetCardIfNeeded(in: app)
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(nextTask.waitForExistence(timeout: 15))
        XCTAssertFalse(action.exists, "Relaunch resurrected the already-claimed preventive-health task.")
    }

    @MainActor
    func testStarterPreventiveHealthUnknownCloseReopenCompletesWithoutFabricatedRecord() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Unknown Preventive Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not reach the unknown health journey in time."
        )

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The unknown health journey did not reach Tasks."
        )
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "The three prerequisite starter rewards did not reach the expected 310-coconut balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let action = app.buttons[
            "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetPreventiveCare"
        ]
        let question = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-petHealthProtection"
        ]
        let unknown = app.buttons[
            "task-center-starter-resolution-petHealthProtection-unknown"
        ]

        XCTAssertTrue(action.waitForExistence(timeout: 12), "The preventive-health starter task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The preventive-health guided sheet did not open.")
        XCTAssertTrue(question.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/1", in: app)
        XCTAssertTrue(unknown.waitForExistence(timeout: 8), "The Not sure yet health answer was unavailable.")
        XCTAssertTrue(
            app.buttons["task-center-starter-resolution-petHealthProtection-preferNotToSay"].exists,
            "The privacy-preserving health answer was unavailable."
        )
        XCTAssertTrue(
            app.buttons["task-center-starter-resolution-petHealthProtection-notApplicable"].exists,
            "The Not applicable health answer was unavailable."
        )
        XCTAssertFalse(app.buttons["task-center-starter-question-previous"].exists)
        XCTAssertFalse(app.buttons["task-center-starter-question-next"].exists)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Closing the unanswered health sheet failed.")
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The unanswered health task did not remain available.")
        XCTAssertFalse(
            action.label.localizedCaseInsensitiveContains("Claim"),
            "Closing an unanswered health task incorrectly made it claimable."
        )

        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(question.waitForExistence(timeout: 8), "Reopening did not restore the health question.")
        assertMemberCardProgress("0/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(unknown, in: app)

        assertMemberCardProgress("1/1", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Choosing Not sure yet did not complete the preventive-health journey."
        )
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Finishing the unknown path claimed its reward instead of exposing Claim."
        )

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "Finishing the unknown path changed the balance before explicit Claim."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The unknown preventive-health task did not preserve its explicit Claim state."
        )

        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetPreventiveCare"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Claiming the health reward did not close its sheet.")
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists }, "The claimed health task remained visible.")

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 390" },
            "The explicit unknown preventive-health claim did not add exactly 80 coconuts."
        )

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            0,
            "Choosing Not sure yet fabricated a health record in the normal pet health UI."
        )
        XCTAssertTrue(
            app.staticTexts["No health records yet"].waitForExistence(timeout: 8),
            "The normal pet health UI did not remain empty after the unknown answer."
        )
    }

    @MainActor
    func testStarterPreventiveHealthPrivateAnswerSurvivesRelaunchWithoutFabricatedRecordAndRewardsOnce() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Private Preventive Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not reach the private health journey in time."
        )

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let balanceBeforeHealthClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(
            balanceBeforeHealthClaim,
            310,
            "The prerequisite rewards left an unreadable or incomplete balance."
        )

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        let action = app.buttons[
            "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetPreventiveCare"
        ]
        let privateAnswer = app.buttons[
            "task-center-starter-resolution-petHealthProtection-preferNotToSay"
        ]

        XCTAssertTrue(action.waitForExistence(timeout: 12), "The private health task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(privateAnswer.waitForExistence(timeout: 8), "Prefer not to say was unavailable.")
        assertMemberCardProgress("0/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(privateAnswer, in: app)

        assertMemberCardProgress("1/1", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Prefer not to say did not complete the health journey."
        )
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The private health answer did not expose a separate Claim state."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20), "Home was unavailable after the private-answer relaunch.")
        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeHealthClaim
            },
            "Relaunch changed the balance before an explicit private-answer Claim."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The private health answer did not survive relaunch as Claim."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        assertMemberCardProgress("1/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetPreventiveCare"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists })

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeHealthClaim + 80
            },
            "The private health Claim did not add exactly 80 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeHealthClaim + 80
            },
            "The second relaunch duplicated or lost the private health reward."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons[
                "task-center-system-action-configureFirstCarePlan-household-starter-v1-carePlan"
            ].waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed private health relaunch."
        )
        XCTAssertFalse(action.exists, "The claimed private health task returned after relaunch.")

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            0,
            "Prefer not to say fabricated a health record in the normal pet health UI."
        )
        XCTAssertTrue(
            app.staticTexts["No health records yet"].waitForExistence(timeout: 8),
            "The normal pet health UI did not remain empty after the private answer."
        )
    }

    @MainActor
    func testStarterPreventiveHealthReviewedThenRealRecordKeepsSingleClaimAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Reviewed Then Real Health Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not reach the health supersession journey in time."
        )

        let homeTab = app.buttons["home-tab-home"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let taskCenter = app.descendants(matching: .any)["task-center-route"]
        let coconutBalance = app.buttons["home-coconut-action"]
        let action = app.buttons[
            "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-confirmPetPreventiveCare"
        ]
        let reviewedAnswer = app.buttons[
            "task-center-starter-resolution-petHealthProtection-reviewed"
        ]
        let recentHealthRows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "pet-health-recent-row-")
        )

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        completeAndClaimStarterProfilePrerequisites(in: app)

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let balanceBeforeHealthClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(
            balanceBeforeHealthClaim,
            310,
            "The prerequisite rewards left an unreadable or incomplete balance."
        )

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The preventive-health task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(reviewedAnswer.waitForExistence(timeout: 8), "Current status reviewed was unavailable.")
        assertMemberCardProgress("0/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(reviewedAnswer, in: app)
        assertMemberCardProgress("1/1", in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The reviewed health answer did not complete the guided card."
        )
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The reviewed answer did not leave one explicit health Claim."
        )

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeHealthClaim
            },
            "Finishing the reviewed answer changed the balance before Claim."
        )
        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            0,
            "The reviewed answer fabricated a health record before the real save."
        )

        let healthFab = app.buttons["pet-health-fab-toggle"]
        XCTAssertTrue(healthFab.waitForExistence(timeout: 8), "The health menu was unavailable.")
        tapWhenHittable(healthFab, timeout: 8)
        let preventiveAction = app.descendants(matching: .any)["pet-health-fab-action-preventive"]
        XCTAssertTrue(
            preventiveAction.waitForExistence(timeout: 8),
            "The normal Health menu did not expose Preventive care."
        )
        tapWhenHittable(preventiveAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-health-record-sheet"].waitForExistence(timeout: 10),
            "Preventive care did not open the vaccine record form."
        )
        let saveRecord = app.buttons["pet-health-record-save-action"]
        XCTAssertTrue(saveRecord.waitForExistence(timeout: 10), "The real preventive record Save action was unavailable.")
        tapWhenHittable(saveRecord, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !app.descendants(matching: .any)["pet-health-record-sheet"].exists
            },
            "Saving the real preventive record did not dismiss its form."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-health-detail-screen"].waitForExistence(timeout: 8),
            "Saving the real preventive record did not return to normal Health."
        )
        XCTAssertTrue(
            recentHealthRows.firstMatch.waitForExistence(timeout: 18),
            "The real health record did not appear after saving."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "Saving one real health fact did not produce exactly one visible record."
        )
        tapWhenHittable(app.buttons["pet-health-detail-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !app.descendants(matching: .any)["pet-health-detail-screen"].exists
            },
            "Closing Health after the real preventive save did not return Home."
        )
        collapseExpandedPetCardIfNeeded(in: app)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let allowedBalancesAfterRealHealthRecord = Set([
            balanceBeforeHealthClaim + 10,
            balanceBeforeHealthClaim + 12,
            balanceBeforeHealthClaim + 18
        ])
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                allowedBalancesAfterRealHealthRecord.contains(
                    Int(self.numericLabel(coconutBalance.label)) ?? -1
                )
            },
            "Saving one real preventive fact did not add its 10-coconut base reward plus an allowed luck bonus."
        )
        let balanceAfterRealHealthRecord = Int(numericLabel(coconutBalance.label)) ?? -1
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The real preventive fact did not preserve one Claim before relaunch."
        )
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(
                format: "identifier == %@",
                "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
            )).count,
            1,
            "The reviewed-to-real transition exposed more than one Claim before relaunch."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceAfterRealHealthRecord
            },
            "Relaunch duplicated or lost the real preventive-care reward before starter Claim."
        )
        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertTrue(recentHealthRows.firstMatch.waitForExistence(timeout: 18))
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "The real health record was lost or duplicated after relaunch."
        )
        tapWhenHittable(app.buttons["pet-health-detail-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !app.descendants(matching: .any)["pet-health-detail-screen"].exists
            },
            "Closing Health after relaunch did not return Home."
        )
        collapseExpandedPetCardIfNeeded(in: app)

        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Replacing the reviewed answer with a real health fact lost or duplicated the Claim state."
        )
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(
                format: "identifier == %@",
                "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
            )).count,
            1,
            "The reviewed-to-real transition exposed more than one health Claim."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        assertMemberCardProgress("1/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-confirmPetPreventiveCare"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists })

        tapWhenHittable(homeTab, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceAfterRealHealthRecord + 80
            },
            "The reviewed-to-real health Claim did not add exactly 80 coconuts once."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceAfterRealHealthRecord + 80
            },
            "Relaunch duplicated or lost the reviewed-to-real health reward."
        )
        tapWhenHittable(tasksTab, timeout: 8)
        XCTAssertTrue(taskCenter.waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons[
                "task-center-system-action-configureFirstCarePlan-household-starter-v1-carePlan"
            ].waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed reviewed-to-real health relaunch."
        )
        XCTAssertFalse(action.exists, "The claimed reviewed-to-real health task returned after relaunch.")

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertTrue(recentHealthRows.firstMatch.waitForExistence(timeout: 18))
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "Claiming or relaunching duplicated the real health record."
        )
    }

    @MainActor
    func testStarterCustomCarePlanCancelAndSaveRemainSeparatedAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The custom care-plan journey did not reach Tasks."
        )
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "The three prerequisite starter rewards did not reach the expected 310-coconut balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let action = app.buttons[
            "task-center-system-action-configureFirstCarePlan-household-starter-v1-carePlan"
        ]
        let sheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-configureFirstCarePlan"
        ]
        let question = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-acceptedRecommendedCarePlan"
        ]
        let openEditor = app.buttons[
            "task-center-starter-journey-open-acceptedRecommendedCarePlan"
        ]
        let recommendedResponse = app.buttons[
            "task-center-starter-resolution-acceptedRecommendedCarePlan-reviewed"
        ]
        let feedDetail = app.descendants(matching: .any)["quick-feed-detail-screen"]
        let manualReminderMode = app.buttons["quick-feed-mode-manualReminder"]
        let planSave = app.buttons["quick-feed-plan-save"]

        XCTAssertTrue(action.waitForExistence(timeout: 12), "The starter care-plan task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12), "The care-plan guided sheet did not open.")
        XCTAssertTrue(question.waitForExistence(timeout: 8))
        XCTAssertTrue(
            recommendedResponse.waitForExistence(timeout: 8),
            "The recommended response was unavailable before choosing the custom-plan branch."
        )
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openEditor, timeout: 8)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12), "The care-plan journey did not open Quick Feed.")
        XCTAssertTrue(
            manualReminderMode.waitForExistence(timeout: 12),
            "Quick Feed did not expose the manual-reminder plan option."
        )
        tapWhenHittable(manualReminderMode, timeout: 8)
        XCTAssertTrue(planSave.waitForExistence(timeout: 12), "The manual-reminder plan editor did not open.")
        tapWhenHittable(app.buttons["quick-feed-sheet-cancel-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !planSave.exists && feedDetail.exists },
            "Cancelling the custom plan did not return to unchanged Quick Feed detail."
        )
        tapWhenHittable(app.buttons["quick-feed-detail-close-action"], timeout: 8)
        XCTAssertTrue(
            question.waitForExistence(timeout: 12),
            "Closing Quick Feed did not return to the incomplete care-plan question."
        )
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !sheet.exists }, "Closing the incomplete care-plan journey did not dismiss it.")

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(app.buttons["home-tab-home"].waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "Relaunch after cancelling the care-plan draft changed the prerequisite reward balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            action.waitForExistence(timeout: 12),
            "The cancelled care-plan task did not remain available after relaunch."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        XCTAssertTrue(
            question.waitForExistence(timeout: 8),
            "Relaunch did not resume the incomplete care-plan question."
        )
        XCTAssertTrue(
            recommendedResponse.waitForExistence(timeout: 8),
            "Relaunch lost the unselected recommended-plan alternative."
        )
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openEditor, timeout: 8)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12))
        XCTAssertTrue(manualReminderMode.waitForExistence(timeout: 12))
        tapWhenHittable(manualReminderMode, timeout: 8)
        XCTAssertTrue(planSave.waitForExistence(timeout: 12))
        tapWhenHittable(planSave, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 18),
            "Saving a real manual-reminder plan did not return to the completed care-plan journey."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) { !feedDetail.exists },
            "The completed custom plan left its nested Quick Feed editor visible."
        )
        assertMemberCardProgress("1/1", in: app)

        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Care-plan Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Saving the custom plan claimed its reward automatically instead of exposing Claim."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(app.buttons["home-tab-home"].waitForExistence(timeout: 20))
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "Relaunch after saving the custom plan changed the balance before explicit Claim."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "Relaunch did not preserve the custom care-plan task's explicit Claim state."
        )

        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-configureFirstCarePlan"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists }, "Claiming the care-plan reward did not close its sheet.")
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists }, "The claimed care-plan task remained visible.")

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 350" },
            "The explicit custom care-plan claim did not add exactly 40 coconuts."
        )
    }

    @MainActor
    func testFirstCareCompletedByHomeWaterBeforeOpeningJourneyBecomesClaimable() throws {
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            resetEconomyBudget: true
        )
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Water First Care \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not reach the external First Care journey in time."
        )

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The external First Care journey did not reach Tasks."
        )
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "The three prerequisite starter rewards did not reach the expected 310-coconut balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let carePlanAction = app.buttons[
            "task-center-system-action-configureFirstCarePlan-household-starter-v1-carePlan"
        ]
        let carePlanSheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-configureFirstCarePlan"
        ]

        XCTAssertTrue(carePlanAction.waitForExistence(timeout: 12), "The starter care-plan task did not appear.")
        tapWhenHittable(carePlanAction, timeout: 8)
        XCTAssertTrue(carePlanSheet.waitForExistence(timeout: 12), "The care-plan guided sheet did not open.")
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "task-center-starter-question-checkpoint-acceptedRecommendedCarePlan"
            ].waitForExistence(timeout: 8)
        )
        assertMemberCardProgress("0/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-acceptedRecommendedCarePlan-reviewed"],
            in: app
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Accepting the recommended care plan did not complete its guided card."
        )
        assertMemberCardProgress("1/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !carePlanSheet.exists }, "Care-plan Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                carePlanAction.exists && carePlanAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Accepting the care plan claimed its reward automatically instead of exposing Claim."
        )
        tapWhenHittable(carePlanAction, timeout: 8)
        XCTAssertTrue(carePlanSheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-configureFirstCarePlan"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !carePlanSheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !carePlanAction.exists })

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 350" },
            "The explicit care-plan claim did not add exactly 40 coconuts."
        )

        let firstCareAction = app.buttons[
            "task-center-system-action-recordFirstCare-household-starter-v1-firstCare"
        ]
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(firstCareAction.waitForExistence(timeout: 12), "The First Care task did not appear before water.")
        XCTAssertFalse(
            firstCareAction.label.localizedCaseInsensitiveContains("Claim"),
            "The First Care task was already claimable before a real care action."
        )

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)

        let recentWaterRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-water-log-row-watering-"))
            .firstMatch
        let waterLogAction = app.buttons["quick-water-log-action"]
        scrollToElement(waterLogAction, in: app, maxSwipes: 5)
        XCTAssertTrue(waterLogAction.waitForExistence(timeout: 12), "Water detail did not expose its real log action.")
        tapWhenHittable(waterLogAction, timeout: 8)
        XCTAssertTrue(
            recentWaterRow.waitForExistence(timeout: 18),
            "The normal Home water flow did not persist a recent water row."
        )
        tapWhenHittable(app.buttons["quick-water-detail-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !app.descendants(matching: .any)["quick-water-detail-sheet"].exists
            },
            "Closing Water detail did not return to Home."
        )

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 18) {
                firstCareAction.exists && firstCareAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "A real Home water record did not refresh First Care directly to Claim."
        )

        XCTAssertTrue(
            waitUntil(timeout: 12) {
                (Int(self.numericLabel(coconutBalance.label)) ?? -1) >= 353
            },
            "The water action did not preserve the 350-coconut baseline and add its normal care reward."
        )
        let balanceBeforeFirstCareClaim = Int(numericLabel(coconutBalance.label)) ?? -1

        let firstCareDirectClaim = app.buttons[
            "task-center-system-claim-recordFirstCare-household-starter-v1-firstCare"
        ]
        XCTAssertTrue(
            firstCareDirectClaim.waitForExistence(timeout: 8),
            "Externally completed First Care did not expose its direct Claim action."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["task-center-starter-journey-sheet-recordFirstCare"].exists,
            "The direct First Care Claim unexpectedly opened a details sheet."
        )

        tapWhenHittable(firstCareDirectClaim, timeout: 8)
        XCTAssertFalse(
            app.descendants(matching: .any)["task-center-starter-journey-sheet-recordFirstCare"].exists,
            "Claiming First Care should stay in the Task Center."
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !firstCareAction.exists })
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeFirstCareClaim + 20
            },
            "The explicit First Care claim did not add exactly 20 coconuts after Home water."
        )
    }

    @MainActor
    func testStarterRecommendedCarePlanAndFirstCareCancelResumeClaimSeparation() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The starter care journey did not reach Tasks."
        )
        completeAndClaimStarterProfilePrerequisites(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 310" },
            "The three prerequisite starter rewards did not reach the expected 310-coconut balance."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let carePlanAction = app.buttons[
            "task-center-system-action-configureFirstCarePlan-household-starter-v1-carePlan"
        ]
        let carePlanSheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-configureFirstCarePlan"
        ]
        let carePlanQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-checkpoint-acceptedRecommendedCarePlan"
        ]

        XCTAssertTrue(carePlanAction.waitForExistence(timeout: 12), "The starter care-plan task did not appear.")
        tapWhenHittable(carePlanAction, timeout: 8)
        XCTAssertTrue(carePlanSheet.waitForExistence(timeout: 12), "The care-plan guided sheet did not open.")
        XCTAssertTrue(carePlanQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-resolution-acceptedRecommendedCarePlan-reviewed"],
            in: app
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "Accepting the recommended care plan did not complete its guided card."
        )
        assertMemberCardProgress("1/1", in: app)
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(waitUntil(timeout: 12) { !carePlanSheet.exists }, "Care-plan Finish did not return to Tasks.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                carePlanAction.exists && carePlanAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Accepting the care plan claimed its reward automatically instead of exposing Claim."
        )
        tapWhenHittable(carePlanAction, timeout: 8)
        XCTAssertTrue(carePlanSheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-configureFirstCarePlan"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !carePlanSheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !carePlanAction.exists })

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { coconutBalance.label == "Coconut balance 350" },
            "The explicit care-plan claim did not add exactly 40 coconuts."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))

        let firstCareAction = app.buttons[
            "task-center-system-action-recordFirstCare-household-starter-v1-firstCare"
        ]
        let firstCareSheet = app.descendants(matching: .any)[
            "task-center-starter-journey-sheet-recordFirstCare"
        ]
        let firstCareQuestion = app.descendants(matching: .any)[
            "task-center-starter-question-action-firstCare"
        ]
        let openFirstCare = app.buttons["task-center-starter-journey-open-recordFirstCare"]
        let feedDetail = app.descendants(matching: .any)["quick-feed-detail-screen"]
        let saveManualSettings = app.buttons["quick-feed-manual-settings-save"]

        XCTAssertTrue(firstCareAction.waitForExistence(timeout: 12), "The first-care starter task did not appear.")
        tapWhenHittable(firstCareAction, timeout: 8)
        XCTAssertTrue(firstCareSheet.waitForExistence(timeout: 12), "The first-care guided sheet did not open.")
        XCTAssertTrue(firstCareQuestion.waitForExistence(timeout: 8))
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openFirstCare, timeout: 8)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12), "First Care did not open Quick Feed.")
        XCTAssertTrue(saveManualSettings.waitForExistence(timeout: 12), "Quick Feed did not request its initial setup.")
        tapWhenHittable(app.buttons["quick-feed-sheet-cancel-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !saveManualSettings.exists && feedDetail.exists },
            "Cancelling initial feed setup did not leave the unchanged Quick Feed detail visible."
        )
        tapWhenHittable(app.buttons["quick-feed-detail-close-action"], timeout: 8)
        XCTAssertTrue(firstCareQuestion.waitForExistence(timeout: 12), "Closing Quick Feed did not return to First Care.")
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !firstCareSheet.exists }, "Closing incomplete First Care did not dismiss it.")
        XCTAssertTrue(firstCareAction.waitForExistence(timeout: 12), "Cancelled First Care did not remain available.")
        tapWhenHittable(firstCareAction, timeout: 8)
        XCTAssertTrue(firstCareSheet.waitForExistence(timeout: 12))
        XCTAssertTrue(firstCareQuestion.waitForExistence(timeout: 8), "Reopening did not resume incomplete First Care.")
        assertMemberCardProgress("0/1", in: app)

        tapWhenHittable(openFirstCare, timeout: 8)
        XCTAssertTrue(feedDetail.waitForExistence(timeout: 12))
        XCTAssertTrue(saveManualSettings.waitForExistence(timeout: 12))
        tapWhenHittable(saveManualSettings, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !saveManualSettings.exists && app.buttons["quick-feed-primary-action"].exists
            },
            "Saving valid manual feed setup did not expose the real care action."
        )
        tapWhenHittable(app.buttons["quick-feed-primary-action"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 18),
            "Recording a real feed did not return to completed First Care."
        )
        assertMemberCardProgress("1/1", in: app)
        tapWhenHittable(app.buttons["task-center-starter-journey-close"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !firstCareSheet.exists },
            "Closing completed First Care did not return to Tasks."
        )
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                firstCareAction.exists && firstCareAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Closing completed First Care claimed its reward automatically instead of preserving Claim."
        )

        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 12))
        let balanceBeforeFirstCareClaim = Int(numericLabel(coconutBalance.label)) ?? -1
        XCTAssertGreaterThanOrEqual(
            balanceBeforeFirstCareClaim,
            350,
            "The real care action left the Human wallet below its pre-care balance."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(
            app.buttons["home-tab-home"].waitForExistence(timeout: 20),
            "Home was unavailable after closing completed First Care."
        )
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeFirstCareClaim
            },
            "Relaunch changed the wallet before the explicit First Care Claim."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                firstCareAction.exists && firstCareAction.label.localizedCaseInsensitiveContains("Claim")
            },
            "Completed First Care did not survive relaunch as Claim."
        )
        tapWhenHittable(firstCareAction, timeout: 8)
        XCTAssertTrue(firstCareSheet.waitForExistence(timeout: 12))
        assertMemberCardProgress("1/1", in: app)
        let firstCareClaim = app.buttons["task-center-starter-journey-claim-recordFirstCare"]
        XCTAssertTrue(
            firstCareClaim.waitForExistence(timeout: 8),
            "Relaunched First Care did not expose its explicit Claim action."
        )
        XCTAssertFalse(
            app.buttons["task-center-starter-journey-finish"].exists,
            "Relaunched completed First Care regressed to a Finish step."
        )
        tapWhenHittable(firstCareClaim, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !firstCareSheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !firstCareAction.exists })
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeFirstCareClaim + 20
            },
            "The explicit First Care claim did not add exactly 20 coconuts."
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(app.buttons["home-tab-home"].waitForExistence(timeout: 20))
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == balanceBeforeFirstCareClaim + 20
            },
            "The second relaunch duplicated or lost the First Care reward."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12))
        XCTAssertTrue(
            app.buttons[
                "task-center-system-action-confirmPetPreventiveCare-household-starter-v1-healthProtection"
            ].waitForExistence(timeout: 15),
            "Tasks did not finish loading after the claimed First Care relaunch."
        )
        XCTAssertFalse(firstCareAction.exists, "Claimed First Care returned after relaunch.")
    }

    @MainActor
    func testHumanFirstOnboardingCreatesPetClaimsGiftAndUnlocksOasis() throws {
        let app = launchEnglishApp(seedHumanBaseline: false)
        completePetFirstD17Flow(in: app)
        injectStarterEnergyToLevelOne(in: app)
    }

    @MainActor
    func testZenFreshInstallCreatesOnlyAHumanAndOpensTheThreeTabShell() throws {
        let app = launchEnglishApp(
            seedHumanBaseline: false,
            initialExperienceMode: "zen",
            extraLaunchArguments: ["-OHANA_UI_TEST_ENABLE_ANIMATIONS"]
        )
        let nameField = app.textFields["onboarding-human-name-input"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 25), "Zen onboarding did not ask for the Human name.")
        nameField.tap()
        nameField.typeText("Codex Zen Human")
        tapWhenHittable(app.buttons["onboarding-human-continue"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["zen-home-screen"].waitForExistence(timeout: 20),
            "Zen onboarding did not enter the lightweight Home shell."
        )
        XCTAssertFalse(app.buttons["onboarding-create-pet-now"].exists, "Zen onboarding incorrectly required a Pet.")

        let ownerCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-human-")
        ).firstMatch
        XCTAssertTrue(ownerCard.waitForExistence(timeout: 12), "Zen Home did not show the bound owner card.")
        let allCompleteStatus = app.descendants(matching: .any)["zen-home-all-complete-status"]
        XCTAssertTrue(
            allCompleteStatus.waitForExistence(timeout: 12),
            "Opening the active Zen shell did not automatically check in its only owner."
        )
        XCTAssertFalse(app.buttons["zen-home-check-in-all-action"].exists)
        let autoCheckInToast = app.descendants(matching: .any)["zen-home-auto-check-in-toast"]
        XCTAssertTrue(autoCheckInToast.waitForExistence(timeout: 8))

        let coconutBalance = app.buttons["zen-toolbar-coconut-log"]
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                Int(self.numericLabel(coconutBalance.label)) == 1
            },
            "The fresh Zen owner's automatic check-in did not grant exactly one coconut before status selection."
        )
        let balanceBeforeStatus = try XCTUnwrap(Int(numericLabel(coconutBalance.label)))
        XCTAssertFalse(
            app.descendants(matching: .any)["zen-status-picker"].exists,
            "Automatic check-in must not open the removed status popup."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                (ownerCard.value as? String)?.contains("Neutral status background") == true
            },
            "The automatically checked-in owner card did not reveal its neutral checked state."
        )
        tapWhenHittable(ownerCard, timeout: 8)
        let alreadyCheckedToast = app.descendants(matching: .any)["zen-home-already-checked-toast"]
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        XCTAssertFalse(
            alreadyCheckedToast.exists,
            "Tapping an already checked-in card must only raise it in the deck, without showing a notice."
        )
        let scoreGestureStart = ownerCard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.50, dy: 0.74)
        )
        let scoreGestureEnd = ownerCard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.50, dy: -0.12)
        )
        scoreGestureStart.press(forDuration: 0.65, thenDragTo: scoreGestureEnd)
        var observedCardLabel = ownerCard.label
        var observedBalanceLabel = coconutBalance.label
        let didReflectStatusReward = waitUntil(timeout: 12) {
            observedCardLabel = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-human-")
            ).firstMatch.label
            observedBalanceLabel = app.buttons["zen-toolbar-coconut-log"].label
            let observedCardValue = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-human-")
            ).firstMatch.value as? String ?? ""
            return observedCardLabel.contains("10/10 · Great") &&
                observedCardValue.contains("Status background: 10/10 · Great") &&
                Int(self.numericLabel(observedBalanceLabel)) == balanceBeforeStatus + 1
        }
        XCTAssertTrue(
            didReflectStatusReward,
            "Holding and sliding to the first explicit daily status did not update the card and grant exactly one coconut. " +
                "Before: \(balanceBeforeStatus); card: \(observedCardLabel); balance: \(observedBalanceLabel)."
        )

        XCTAssertFalse(
            app.descendants(matching: .any)["zen-status-picker"].exists,
            "Tapping an already checked-in wallet card must not reopen the removed status popup."
        )
        XCTAssertTrue(waitUntil(timeout: 6) { !autoCheckInToast.exists }, "The automatic check-in toast did not dismiss.")

        let expandButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-expand-human-")
        ).firstMatch
        XCTAssertTrue(expandButton.waitForExistence(timeout: 8), "The collapsed Zen card did not expose its expand action.")
        tapWhenHittable(expandButton, timeout: 8)

        let expandedCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-collapse-human-")
        ).firstMatch
        XCTAssertTrue(expandedCard.waitForExistence(timeout: 8), "The Zen card did not expand with the shared wallet-card presentation.")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-expanded-card-details-")
            ).firstMatch.waitForExistence(timeout: 8),
            "The expanded Zen card did not expose its type-specific profile and recent-status details."
        )
        let expandedAttachment = XCTAttachment(screenshot: app.screenshot())
        expandedAttachment.name = "Zen expanded card — premium profile details"
        expandedAttachment.lifetime = .keepAlways
        add(expandedAttachment)
        let profileButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-profile-human-")
        ).firstMatch
        XCTAssertTrue(profileButton.waitForExistence(timeout: 8), "The expanded card did not expose its profile action.")
        tapWhenHittable(profileButton, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["human-basic-info-screen"].waitForExistence(timeout: 12),
            "The expanded Zen card did not open the editable Human profile."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["profile-completion-card"].waitForExistence(timeout: 8),
            "The Human profile did not show its four-category completion card."
        )
        tapWhenHittable(app.buttons["human-basic-info-edit-action"], timeout: 8)
        let editedOwnerName = "Codex Zen Human Edited"
        let nameInput = app.textFields["human-basic-info-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Human profile edit mode did not expose its name field.")
        XCTAssertTrue(app.descendants(matching: .any)["profile-avatar-current-preview"].exists)
        XCTAssertFalse(app.textFields["human-basic-info-avatar-emoji-input"].exists)
        clearTextField(nameInput, in: app)
        nameInput.typeText(editedOwnerName)
        dismissKeyboardIfPresent(in: app)

        let firstMBTIChoice = app.buttons["member-mbti-energy-i"]
        scrollToElement(firstMBTIChoice, in: app, maxSwipes: 6)
        XCTAssertTrue(firstMBTIChoice.waitForExistence(timeout: 8), "The Human editor did not expose four MBTI dimensions.")
        for identifier in [
            "member-mbti-energy-i", "member-mbti-energy-e",
            "member-mbti-information-s", "member-mbti-information-n",
            "member-mbti-decision-t", "member-mbti-decision-f",
            "member-mbti-lifestyle-j", "member-mbti-lifestyle-p"
        ] {
            XCTAssertTrue(app.buttons[identifier].exists, "Missing MBTI binary choice: \(identifier)")
        }
        tapWhenHittable(app.buttons["human-basic-info-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                app.descendants(matching: .any)["human-basic-info-name-readback"].label.contains(editedOwnerName)
            },
            "The Human profile edit did not read back the saved name."
        )
        tapWhenHittable(app.buttons["human-basic-info-close-action"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-collapse-human-")
            ).firstMatch.waitForExistence(timeout: 10),
            "Closing the profile did not return to the expanded Zen card."
        )
        tapWhenHittable(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-collapse-human-")
            ).firstMatch,
            timeout: 8
        )
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-expand-human-")
            ).firstMatch.waitForExistence(timeout: 8),
            "Tapping the expanded card did not collapse it."
        )

        tapWhenHittable(app.buttons["zen-toolbar-coconut-log"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["coconut-log-screen"].waitForExistence(timeout: 12),
            "The Zen coconut balance did not open coconut history."
        )
        tapWhenHittable(app.buttons["coconut-log-close-action"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["zen-home-screen"].waitForExistence(timeout: 10))

        tapWhenHittable(app.buttons["zen-toolbar-members"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["zen-members-screen"].waitForExistence(timeout: 12),
            "The shared Zen toolbar did not open the lightweight members page."
        )
        XCTAssertTrue(app.buttons["zen-members-add-menu"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-members-row-human-")
            ).firstMatch.waitForExistence(timeout: 8),
            "The Zen members page did not list its active Human."
        )

        let addedMemberName = "Codex Zen Member"
        tapWhenHittable(app.buttons["zen-members-add-menu"], timeout: 8)
        tapWhenHittable(app.buttons["zen-members-add-human-action"], timeout: 8)
        let addedMemberNameField = app.textFields["member-name-input"]
        XCTAssertTrue(
            addedMemberNameField.waitForExistence(timeout: 12),
            "The Zen members page did not open the shared Human creation flow."
        )
        addedMemberNameField.tap()
        addedMemberNameField.typeText(addedMemberName)
        addedMemberNameField.typeText("\n")
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        tapThroughMemberCreationSteps(in: app)

        let addedMemberRow = app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "zen-members-row-human-",
                addedMemberName
            )
        ).firstMatch
        XCTAssertTrue(
            addedMemberRow.waitForExistence(timeout: 20),
            "Saving a Human from Zen members did not return to the member list with refreshed data."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["zen-members-screen"].exists,
            "Saving from Zen members unexpectedly left the members page."
        )
        tapWhenHittable(app.buttons["zen-members-close-action"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["zen-home-screen"].waitForExistence(timeout: 10))

        for tab in ["home", "streak", "oasis"] {
            XCTAssertTrue(
                app.descendants(matching: .any)["zen-tab-\(tab)"].exists,
                "Zen shell is missing the \(tab) tab."
            )
        }
        XCTAssertFalse(app.buttons["home-tab-calendar"].exists, "Zen shell mounted the Standard task tab.")

        tapWhenHittable(app.descendants(matching: .any)["zen-tab-streak"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["zen-streak-screen"].waitForExistence(timeout: 12))
        for action in ["zen-toolbar-coconut-log", "zen-toolbar-members", "zen-toolbar-settings"] {
            XCTAssertTrue(app.buttons[action].exists, "Streak is missing the shared toolbar action: \(action)")
        }
        let nextMonth = app.buttons["zen-streak-next-month"]
        XCTAssertFalse(nextMonth.isEnabled)
        let monthPager = app.descendants(matching: .any)["zen-streak-month-pager"]
        XCTAssertTrue(monthPager.waitForExistence(timeout: 8))
        monthPager.swipeRight()
        XCTAssertTrue(waitUntil(timeout: 8) { nextMonth.isEnabled }, "Swiping did not move the Zen calendar to the previous month.")
        let streakAttachment = XCTAttachment(screenshot: app.screenshot())
        streakAttachment.name = "Zen Streak — semantic calendar card"
        streakAttachment.lifetime = .keepAlways
        add(streakAttachment)
        tapWhenHittable(app.descendants(matching: .any)["zen-tab-oasis"], timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["zen-oasis-screen"].waitForExistence(timeout: 12))
        for action in ["zen-toolbar-coconut-log", "zen-toolbar-members", "zen-toolbar-settings"] {
            XCTAssertTrue(app.buttons[action].exists, "Oasis is missing the shared toolbar action: \(action)")
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["oasis-tree-level-control"].waitForExistence(timeout: 8),
            "Zen Oasis did not render the shared standard tree card."
        )
        let oasisAttachment = XCTAttachment(screenshot: app.screenshot())
        oasisAttachment.name = "Zen Oasis — shared standard composition"
        oasisAttachment.lifetime = .keepAlways
        add(oasisAttachment)

        tapWhenHittable(app.descendants(matching: .any)["zen-tab-home"], timeout: 8)
        let balanceBeforeUndo = try XCTUnwrap(
            Int(numericLabel(app.buttons["zen-toolbar-coconut-log"].label))
        )
        let checkedHumanCard = try XCTUnwrap(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-human-")
        ).allElementsBoundByIndex.first {
            ($0.value as? String)?.contains("Status background") == true
        })
        let checkedHumanIdentifier = checkedHumanCard.identifier
        let checkedHumanExpandIdentifier = checkedHumanIdentifier.replacingOccurrences(
            of: "zen-home-subject-",
            with: "zen-home-expand-"
        )
        let expandBeforeUndo = app.buttons.matching(
            NSPredicate(format: "identifier == %@", checkedHumanExpandIdentifier)
        ).firstMatch
        tapWhenHittable(expandBeforeUndo, timeout: 8)
        let undoCheckIn = app.buttons["zen-expanded-undo-check-in"]
        XCTAssertTrue(undoCheckIn.waitForExistence(timeout: 8), "The expanded checked card did not expose Undo.")
        tapWhenHittable(undoCheckIn, timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 8) { !undoCheckIn.exists }, "Undo did not remove today's check-in state.")
        tapWhenHittable(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-collapse-human-")
            ).firstMatch,
            timeout: 8
        )

        relaunchPreservingPersistentState(in: app)
        XCTAssertTrue(app.descendants(matching: .any)["zen-home-screen"].waitForExistence(timeout: 20))
        let withdrawnOwnerCard = app.buttons[checkedHumanIdentifier]
        XCTAssertTrue(withdrawnOwnerCard.waitForExistence(timeout: 12))
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                (withdrawnOwnerCard.value as? String)?.contains("Frosted glass cover") == true
            },
            "Foreground auto check-in ignored the user's same-day withdrawal."
        )
        tapWhenHittable(withdrawnOwnerCard, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                let value = withdrawnOwnerCard.value as? String ?? ""
                let balance = Int(self.numericLabel(app.buttons["zen-toolbar-coconut-log"].label))
                return value.contains("Neutral status background") && balance == balanceBeforeUndo
            },
            "Manual re-check-in after Undo did not restore the fact without duplicating coconut rewards."
        )
    }

    @MainActor
    func testZenCardTapChecksInAndPressDragSelectsStatusWithoutPopup() throws {
        let app = launchEnglishApp(
            matureHouseholdPetName: "Codex Zen Pet",
            extraLaunchArguments: ["-OHANA_UI_TEST_ENABLE_ANIMATIONS"]
        )
        let introduction = app.buttons["zen-introduction-banner"]
        if introduction.waitForExistence(timeout: 5) {
            tapWhenHittable(introduction, timeout: 8)
        }
        openSettingsFromHomeChrome(in: app)
        tapWhenHittable(app.buttons["settings-experience-mode-zen"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["zen-home-screen"].waitForExistence(timeout: 20),
            "The mature Zen household did not reach its lightweight Home shell."
        )

        XCTAssertFalse(app.descendants(matching: .any)["zen-status-picker"].exists)

        let petCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-pet-")
        ).firstMatch
        XCTAssertTrue(petCard.waitForExistence(timeout: 12), "Zen Home did not show its active Pet card.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                (petCard.value as? String)?.contains("Frosted glass cover") == true
            },
            "The unchecked Pet card did not expose its frosted-glass pending state."
        )

        let pendingAttachment = XCTAttachment(screenshot: app.screenshot())
        pendingAttachment.name = "Zen pending card — frosted glass"
        pendingAttachment.lifetime = .keepAlways
        add(pendingAttachment)

        let humanCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-human-")
        ).firstMatch
        XCTAssertTrue(humanCard.waitForExistence(timeout: 8), "Zen Home did not show its active Human card.")
        humanCard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.50, dy: 0.64)
        ).press(forDuration: 1.2)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                let currentHumanCard = app.buttons.matching(
                    NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-human-")
                ).firstMatch
                let label = currentHumanCard.label
                let value = currentHumanCard.value as? String ?? ""
                return label.contains("5/10 · Steady") && value.contains("Status background: 5/10 · Steady")
            },
            "Holding the differently rotated Human card did not save its centered default score."
        )

        let quickTapCoordinate = petCard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.50, dy: 0.62)
        )
        quickTapCoordinate.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["zen-home-all-complete-status"]
                .waitForExistence(timeout: 12),
            "A quick tap did not check in the Pet without a status."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["zen-status-picker"].exists,
            "Quick check-in unexpectedly opened the removed status popup."
        )

        let neutralAttachment = XCTAttachment(screenshot: app.screenshot())
        neutralAttachment.name = "Zen checked card — quick check-in without status"
        neutralAttachment.lifetime = .keepAlways
        add(neutralAttachment)

        let scoreGestureStart = petCard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.50, dy: 0.74)
        )
        let scoreGestureEnd = petCard.coordinate(
            withNormalizedOffset: CGVector(dx: 0.50, dy: -0.12)
        )
        scoreGestureStart.press(forDuration: 0.65, thenDragTo: scoreGestureEnd)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                let currentPetCard = app.buttons.matching(
                    NSPredicate(format: "identifier BEGINSWITH %@", "zen-home-subject-pet-")
                ).firstMatch
                let label = currentPetCard.label
                let value = currentPetCard.value as? String ?? ""
                return label.contains("10/10 · Great") && value.contains("Status background: 10/10 · Great")
            },
            "Holding and sliding upward did not save 10/10 and reveal the Pet card's green checked state."
        )

        let checkedAttachment = XCTAttachment(screenshot: app.screenshot())
        checkedAttachment.name = "Zen checked card — 10 out of 10"
        checkedAttachment.lifetime = .keepAlways
        add(checkedAttachment)
    }

    @MainActor
    func testHumanFirstOnboardingWithProductionOverlaysCompletes() throws {
        let app = launchEnglishApp(
            seedHumanBaseline: false,
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_ENABLE_ANIMATIONS"]
        )
        completePetFirstD17Flow(
            in: app,
            completionMessage: "Human-first onboarding with production overlays did not reach the starter reward in time."
        )
    }

    @MainActor
    func testReduceMotionKeepsHumanFirstValueLoopInteractive() throws {
        let app = launchEnglishApp(
            seedHumanBaseline: false,
            enableProductionOverlays: true,
            extraLaunchArguments: [
                "-OHANA_UI_TEST_REDUCE_MOTION",
                "-OHANA_UI_TEST_ENABLE_ANIMATIONS"
            ]
        )
        completePetFirstD17Flow(
            in: app,
            completionMessage: "Reduce Motion prevented the Human-first Pet, reward, or Oasis value loop from completing."
        )
    }

    @MainActor
    func testHumanFirstOnboardingAccessibilityContract() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        createOnboardingHuman(named: "Codex Accessibility Human", in: app)
        advanceOnboardingIntroToMemberCreation(in: app)

        let nameField = app.textFields["member-name-input"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 12), "Pet name field did not appear.")
        XCTAssertEqual(nameField.elementType, .textField, "Pet name entry lost its text-field role.")
        XCTAssertFalse(
            app.buttons["member-pet-species-option-dog"].exists,
            "The name page should contain only the name task."
        )
        let petAvatarPreview = app.descendants(matching: .any)["member-pet-avatar-preview"]
        XCTAssertFalse(petAvatarPreview.exists, "The Pet avatar appeared before step 5.")

        let creationPrimary = app.buttons["member-creation-primary-action"]
        XCTAssertFalse(creationPrimary.isEnabled, "An empty Pet name should not advance.")
        nameField.tap()
        nameField.typeText("Codex Accessibility Pet")
        nameField.typeText("\n")
        XCTAssertTrue(
            waitUntil(timeout: 8) { creationPrimary.isEnabled },
            "A valid Pet name did not enable the next step."
        )
        tapWhenHittable(creationPrimary, timeout: 8)

        XCTAssertTrue(
            app.buttons["member-pet-species-option-dog"].waitForExistence(timeout: 8),
            "The identity page did not expose Species."
        )
        XCTAssertTrue(app.descendants(matching: .any)["member-pet-species-grid"].exists)
        XCTAssertFalse(app.buttons["member-pet-species-picker"].exists)
        XCTAssertFalse(app.staticTexts["Add now, edit details later"].exists)
        XCTAssertFalse(
            app.staticTexts["Species and breed are required; sex and appearance can be added later."].exists
        )
        XCTAssertFalse(
            app.buttons["member-gender-boy"].exists || app.buttons["member-gender-girl"].exists,
            "Sex controls should remain on their own appearance page."
        )
        XCTAssertFalse(petAvatarPreview.exists, "The Pet avatar appeared on the identity step.")
        selectMemberCreationPetSpecies("Dog", in: app)
        selectMemberCreationPetBreed(for: "Dog", in: app)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Pomeranian")).firstMatch.waitForExistence(timeout: 8),
            "The English Pet card preview exposed the Chinese breed storage value."
        )
        keepScreenshot(of: app, named: "Pet creation - minimal species buttons")
        XCTAssertTrue(waitUntil(timeout: 8) { creationPrimary.isEnabled })
        tapWhenHittable(creationPrimary, timeout: 8)

        let boy = app.buttons["member-gender-boy"]
        XCTAssertTrue(boy.waitForExistence(timeout: 8), "The required Pet appearance page did not appear.")
        XCTAssertTrue(
            app.buttons["member-pet-coat-picker"].exists,
            "The optional coat picker was missing from the Pet appearance page."
        )
        XCTAssertFalse(petAvatarPreview.exists, "The Pet avatar appeared on the appearance step.")
        XCTAssertFalse(creationPrimary.isEnabled, "Pet creation advanced before the required sex was selected.")
        tapWhenHittable(boy, timeout: 8)
        let coatPicker = app.buttons["member-pet-coat-picker"]
        tapWhenHittable(coatPicker, timeout: 8)
        let coatSkipLabels = ["Skip for now", "暂不设置", "Vorerst überspringen"]
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.firstHittableButton(labels: coatSkipLabels, in: app) != nil },
            "The explicit Coat skip action did not appear."
        )
        guard let coatSkip = firstHittableButton(labels: coatSkipLabels, in: app) else {
            return XCTFail("The explicit Coat skip action was not semantically tappable.")
        }
        coatSkip.tap()
        XCTAssertTrue(
            waitUntil(timeout: 8) { creationPrimary.isEnabled },
            "Explicitly skipping Coat did not preserve the valid required Sex answer."
        )
        tapWhenHittable(creationPrimary, timeout: 8)

        XCTAssertTrue(
            app.buttons["member-pet-personality-curious"].waitForExistence(timeout: 8),
            "The optional personality page did not appear."
        )
        XCTAssertTrue(creationPrimary.isEnabled, "Personality must be skippable without a selection.")
        XCTAssertFalse(petAvatarPreview.exists, "The Pet avatar appeared on the personality step.")

        let personalityIds = [
            "curious", "lazy", "energetic", "clingy", "smart", "toy", "foodie", "drama", "clean", "shy",
            "brave", "social", "gentle", "quiet", "stubborn", "vocal", "guardian", "independent", "loyal", "chill"
        ]
        let selectedIds = Array(personalityIds.prefix(3))
        for id in selectedIds {
            let choice = app.buttons["member-pet-personality-\(id)"]
            scrollToElement(choice, in: app, maxSwipes: 6)
            XCTAssertTrue(choice.exists && choice.isHittable, "Personality \(id) was not reachable.")
            tapWhenHittable(choice, timeout: 4)
            XCTAssertEqual(
                choice.value as? String,
                "Selected",
                "Personality \(id) did not expose its selected state."
            )
        }

        let fourthChoice = app.buttons["member-pet-personality-clingy"]
        scrollToElement(fourthChoice, in: app, maxSwipes: 6)
        XCTAssertTrue(fourthChoice.exists && fourthChoice.isHittable, "The fourth personality choice was not reachable.")
        tapWhenHittable(fourthChoice, timeout: 4)
        XCTAssertEqual(
            fourthChoice.value as? String,
            "Not selected",
            "A fourth personality choice should remain unselected."
        )
        keepScreenshot(of: app, named: "Pet creation - personality")

        XCTAssertEqual(
            app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "member-pet-personality-")
            ).count,
            personalityIds.count,
            "The optional personality grid did not expose every direct-tap choice."
        )

        tapWhenHittable(creationPrimary, timeout: 8)
        XCTAssertTrue(
            petAvatarPreview.waitForExistence(timeout: 8),
            "The Pet avatar did not appear on the final step."
        )
        XCTAssertTrue(creationPrimary.isEnabled, "The preselected default avatar should allow immediate save.")
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        keepScreenshot(of: app, named: "Pet creation - enlarged 2.5D avatar")

        let backAction = app.buttons["member-creation-back-action"]
        XCTAssertTrue(backAction.waitForExistence(timeout: 4))
        tapWhenHittable(backAction, timeout: 4)
        XCTAssertTrue(
            app.buttons["member-pet-personality-curious"].waitForExistence(timeout: 8),
            "Back from the avatar step did not return to personality."
        )
        XCTAssertTrue(
            waitUntil(timeout: 4) { !petAvatarPreview.exists },
            "The Pet avatar remained visible after leaving step 5."
        )
        tapWhenHittable(creationPrimary, timeout: 8)
        XCTAssertTrue(
            petAvatarPreview.waitForExistence(timeout: 8),
            "The Pet avatar did not reappear after returning to step 5."
        )
    }

    @MainActor
    func testHumanFirstOnboardingPetCoatSelectionSurvivesBackNavigation() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        createOnboardingHuman(named: "Codex Coat Human", in: app)
        advanceOnboardingIntroToMemberCreation(in: app)

        let nameField = app.textFields["member-name-input"]
        let creationPrimary = app.buttons["member-creation-primary-action"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 12))
        tapWhenHittable(nameField, timeout: 8)
        nameField.typeText("Codex Coat Pet")
        nameField.typeText("\n")
        XCTAssertTrue(waitUntil(timeout: 8) { creationPrimary.isEnabled })
        tapWhenHittable(creationPrimary, timeout: 8)

        XCTAssertTrue(app.buttons["member-pet-species-option-dog"].waitForExistence(timeout: 8))
        selectMemberCreationPetSpecies("Dog", in: app)
        selectMemberCreationPetBreed(for: "Dog", in: app)
        XCTAssertTrue(waitUntil(timeout: 8) { creationPrimary.isEnabled })
        tapWhenHittable(creationPrimary, timeout: 8)

        let boy = app.buttons["member-gender-boy"]
        XCTAssertTrue(boy.waitForExistence(timeout: 8))
        tapWhenHittable(boy, timeout: 8)
        let coatPicker = app.buttons["member-pet-coat-picker"]
        XCTAssertTrue(coatPicker.waitForExistence(timeout: 8))
        tapWhenHittable(coatPicker, timeout: 8)
        let firstCoatLabels = ["orange color", "橙色"]
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.firstHittableButton(labels: firstCoatLabels, in: app) != nil },
            "The first real Coat option did not appear."
        )
        guard let firstCoat = firstHittableButton(labels: firstCoatLabels, in: app) else {
            return XCTFail("The first real Coat option was not semantically tappable.")
        }
        let selectedCoatLabel = firstCoat.label
        firstCoat.tap()
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                self.accessibilityText(for: coatPicker).contains(selectedCoatLabel)
            },
            "Selecting a real Coat did not update the appearance answer."
        )

        tapWhenHittable(creationPrimary, timeout: 8)
        XCTAssertTrue(
            app.buttons["member-pet-personality-curious"].waitForExistence(timeout: 8),
            "The selected Coat path did not advance to Personality."
        )
        tapWhenHittable(app.buttons["member-creation-back-action"], timeout: 8)
        XCTAssertTrue(coatPicker.waitForExistence(timeout: 8), "Back did not return to the Coat answer.")
        XCTAssertTrue(
            accessibilityText(for: coatPicker).contains(selectedCoatLabel),
            "Back navigation lost the selected Coat."
        )
        tapWhenHittable(coatPicker, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.firstHittableButton(labels: firstCoatLabels, in: app) != nil },
            "The restored Coat option did not remain available after Back navigation."
        )
    }

    @MainActor
    func testSecondFreePetShowsPersonalBeforeCreationForm() throws {
        let app = launchEnglishApp(seedHumanBaseline: false, enableProductionOverlays: true)
        let petName = "Codex First Free Pet"
        advanceOnboardingIntroToMemberCreation(in: app)
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "The first Pet creation form did not appear.",
            completionMessage: "The first Pet did not return directly to Home.",
            petSpeciesLabel: "Dog",
            postSaveMarkerIdentifiers: ["home-card-pet-\(petName)"]
        )

        XCTAssertTrue(
            app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12),
            "Saving the first Pet did not leave its card visible on Home."
        )
        tapWhenHittable(app.buttons["home-crew-roster-action"], timeout: 8)
        let addMember = app.buttons["crew-roster-primary-action"]
        XCTAssertTrue(addMember.waitForExistence(timeout: 12))
        tapWhenHittable(addMember, timeout: 8)
        let addPet = app.descendants(matching: .any)["crew-roster-add-pet-action"]
        XCTAssertTrue(addPet.waitForExistence(timeout: 8))
        tapWhenHittable(addPet, timeout: 8)

        let nameField = app.textFields["member-name-input"]
        let personalScreen = app.descendants(matching: .any)["personal-plan-screen"]
        var didExposeNameField = false
        let reachedPersonal = waitUntil(timeout: 12) {
            didExposeNameField = didExposeNameField || nameField.exists
            return personalScreen.exists
        }
        XCTAssertTrue(
            reachedPersonal,
            "A second Free Pet did not show Personal before the creation form."
        )
        let reason = app.descendants(matching: .any)["personal-plan-upgrade-reason"]
        XCTAssertTrue(
            reason.waitForExistence(timeout: 8),
            "The compact Personal prompt did not explain the current Pet limit."
        )
        XCTAssertTrue(accessibilityText(for: reason).contains("Add another pet"))
        XCTAssertFalse(
            didExposeNameField || nameField.exists,
            "The second Pet form appeared before the Free quota check."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["personal-plan-free-card"].exists ||
                app.descendants(matching: .any)["personal-plan-appearance-extras"].exists,
            "The quota prompt still mounted the verbose generic Personal comparison."
        )
        keepScreenshot(of: app, named: "Second Free Pet - compact Personal prompt")

        tapWhenHittable(app.buttons["personal-plan-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !personalScreen.exists },
            "Closing the Personal prompt did not dismiss it."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["crew-roster-members"].waitForExistence(timeout: 8),
            "Declining the Personal prompt did not return to the member roster."
        )
        XCTAssertTrue(
            app.buttons["crew-roster-card-pet-\(petName)"].waitForExistence(timeout: 8),
            "Declining the Personal prompt removed the existing Free Pet."
        )
        XCTAssertFalse(
            nameField.exists,
            "Declining the Personal prompt leaked the second-Pet creation form."
        )
    }

    @MainActor
    func testLocalStoreKitPersonalPlansShowPricesTrialAndEmptyRestoreWithoutPurchase() throws {
        let storeSession = try SKTestSession(configurationFileNamed: "Ohana")
        storeSession.disableDialogs = true
        storeSession.clearTransactions()
        defer {
            storeSession.clearTransactions()
            storeSession.resetToDefaultState()
        }

        let app = launchEnglishApp(seedHumanBaseline: true, enableProductionOverlays: true)
        let deferPet = app.buttons["onboarding-defer-pet"]
        XCTAssertTrue(
            deferPet.waitForExistence(timeout: 12),
            "The seeded Human baseline did not expose the optional first-pet decision."
        )
        tapWhenHittable(deferPet, timeout: 8)
        guard let humanName = seededHumanBaselineName else {
            return XCTFail("The local StoreKit fixture did not retain its seeded Human name.")
        }
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openSettingsFromHomeChrome(in: app)

        let personalAction = app.buttons["settings-personal-plan-action"]
        scrollToElement(personalAction, in: app, maxSwipes: 12)
        XCTAssertTrue(personalAction.waitForExistence(timeout: 12), "Settings did not expose Ohana Personal.")
        tapWhenHittable(personalAction, timeout: 8)

        let personalScreen = app.descendants(matching: .any)["personal-plan-screen"]
        XCTAssertTrue(personalScreen.waitForExistence(timeout: 12), "The Personal comparison did not open.")

        let monthly = app.buttons["personal-plan-choice-monthly"]
        let yearly = app.buttons["personal-plan-choice-yearly"]
        let lifetime = app.buttons["personal-plan-choice-lifetime"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 12), "The monthly Personal choice did not appear.")
        XCTAssertTrue(yearly.waitForExistence(timeout: 12), "The yearly Personal choice did not appear.")
        XCTAssertTrue(lifetime.waitForExistence(timeout: 12), "The Lifetime Personal choice did not appear.")

        XCTAssertTrue(
            waitUntil(timeout: 20) {
                [monthly, yearly, lifetime].allSatisfy {
                    let text = self.accessibilityText(for: $0)
                    return !text.contains("—") && !text.contains("Loading")
                }
            },
            "The local StoreKit session did not load all three localized Personal prices."
        )
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                self.accessibilityText(for: yearly).contains("14-day free trial")
            },
            "The eligible yearly choice did not disclose its configured 14-day trial."
        )

        tapWhenHittable(monthly, timeout: 8)
        XCTAssertEqual(monthly.value as? String, "Selected")
        tapWhenHittable(yearly, timeout: 8)
        XCTAssertEqual(yearly.value as? String, "Selected")
        tapWhenHittable(lifetime, timeout: 8)
        XCTAssertEqual(lifetime.value as? String, "Selected")

        let purchaseAction = app.buttons["personal-plan-purchase-action"]
        XCTAssertTrue(purchaseAction.exists && purchaseAction.isEnabled, "A loaded Lifetime choice was not purchasable.")

        let restoreAction = app.buttons["personal-plan-restore-action"]
        XCTAssertTrue(restoreAction.exists && restoreAction.isEnabled, "The Personal screen did not expose Restore Purchases.")
        tapWhenHittable(restoreAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "label CONTAINS %@",
                    "no Personal or Supporter Pack purchase to restore"
                )
            ).firstMatch.waitForExistence(timeout: 12),
            "An empty local StoreKit restore did not produce the explicit no-purchase result."
        )

        tapWhenHittable(app.buttons["personal-plan-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !personalScreen.exists && app.buttons["settings-close-action"].exists },
            "Closing the Personal screen did not return to Settings."
        )
    }

    @MainActor
    private func keepScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPersistentStoreFailureFailsClosedAndRetryRecovers() throws {
        let app = launchEnglishApp(
            seedHumanBaseline: false,
            extraLaunchArguments: ["-OHANA_UI_TEST_FAIL_STORE_OPEN_ONCE"]
        )
        let retryButton = app.buttons["bootstrap-retry-button"]
        XCTAssertTrue(
            retryButton.waitForExistence(timeout: 15),
            "A failed primary store open did not stop at the recovery surface."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["bootstrap-support-action"].exists,
            "The fail-closed recovery surface did not expose support."
        )
        XCTAssertFalse(
            app.textFields["onboarding-human-name-input"].exists,
            "The writable app surface appeared while the primary store was unavailable."
        )

        tapWhenHittable(retryButton, timeout: 8)
        XCTAssertTrue(
            app.textFields["onboarding-human-name-input"].waitForExistence(timeout: 20),
            "Retry did not reopen the same primary store and resume onboarding."
        )
    }

    @MainActor
    func testFirstReleaseReachableHomeOasisAndSettingsSmoke() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        openOasisAndInjectStarterEnergy(in: app)
        openSettingsFromHomeChrome(in: app)
    }

    @MainActor
    func testSettingsAdvancedNotificationControlsMountOnlyWhenExpanded() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        openSettingsFromHomeChrome(in: app)
        openSettingsCategory("settings-destination-notifications", in: app)
        let advancedNotifications = app.buttons["settings-advanced-notifications-disclosure"]
        scrollToElement(advancedNotifications, in: app, maxSwipes: 8)
        XCTAssertTrue(
            advancedNotifications.waitForExistence(timeout: 12),
            "Settings did not expose the advanced notification row."
        )

        let medicationToggle = app.switches["settings-notification-medication-toggle"]
        XCTAssertFalse(
            medicationToggle.exists,
            "Medication notification toggle was mounted before advanced notification settings were expanded."
        )

        tapWhenHittable(advancedNotifications, timeout: 8)
        scrollToElement(medicationToggle, in: app, maxSwipes: 6)
        XCTAssertTrue(
            medicationToggle.waitForExistence(timeout: 8),
            "Expanding advanced notification settings did not mount the medication notification toggle."
        )

        scrollToElement(advancedNotifications, in: app, maxSwipes: 4)
        XCTAssertTrue(
            medicationToggle.exists,
            "Advanced notification controls disappeared before the collapse action."
        )
        tapWhenHittable(advancedNotifications, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 5) { !medicationToggle.exists },
            "Collapsing advanced notification settings did not unmount category controls."
        )
    }

    @MainActor
    func testSettingsLanguageSelectionSurvivesImmediateCloseAndRelaunch() throws {
        let app = launchEnglishApp(seedHumanBaseline: true, enableProductionOverlays: true)
        let deferPet = app.buttons["onboarding-defer-pet"]
        XCTAssertTrue(
            deferPet.waitForExistence(timeout: 12),
            "The seeded Human baseline did not expose the optional first-pet decision."
        )
        tapWhenHittable(deferPet, timeout: 8)
        guard let humanName = seededHumanBaselineName else {
            return XCTFail("The language-switch fixture did not retain its seeded Human name.")
        }

        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openSettingsFromHomeChrome(in: app)
        openSettingsCategory("settings-destination-regionAndLanguage", in: app)

        let languagePicker = app.descendants(matching: .any)["settings-language-picker"]
        scrollToElement(languagePicker, in: app, maxSwipes: 8)
        XCTAssertTrue(languagePicker.waitForExistence(timeout: 12), "Settings did not expose the language Picker.")
        tapWhenHittable(languagePicker, timeout: 8)

        let germanChoice = app.buttons["Deutsch"]
        XCTAssertTrue(germanChoice.waitForExistence(timeout: 8), "The language Picker did not expose Deutsch.")
        germanChoice.tap()

        let closeSettings = app.buttons["settings-close-action"]
        XCTAssertTrue(closeSettings.exists, "The language selection unexpectedly removed the Settings close action.")
        closeSettings.tap()
        XCTAssertTrue(
            app.buttons["home-card-human-\(humanName)"].waitForExistence(timeout: 15),
            "Closing immediately after language selection did not return to Home."
        )

        relaunchPreservingPersistentState(in: app, preservingAppLanguage: true)
        XCTAssertTrue(app.buttons["home-tab-home"].waitForExistence(timeout: 20))
        openSettingsFromHomeChrome(in: app)
        openSettingsCategory("settings-destination-regionAndLanguage", in: app)

        let persistedLanguagePicker = app.descendants(matching: .any)["settings-language-picker"]
        scrollToElement(persistedLanguagePicker, in: app, maxSwipes: 8)
        XCTAssertTrue(
            persistedLanguagePicker.waitForExistence(timeout: 12) &&
                accessibilityText(for: persistedLanguagePicker).contains("Deutsch"),
            "The immediately selected language did not survive a cold relaunch."
        )
    }

    @MainActor
    func testSettingsSixCategoriesSupportNativeRoundTrips() throws {
        let app = launchEnglishApp(seedHumanBaseline: true, enableProductionOverlays: true)
        if app.buttons["onboarding-defer-pet"].waitForExistence(timeout: 5) {
            tapWhenHittable(app.buttons["onboarding-defer-pet"], timeout: 5)
        }
        guard let humanName = seededHumanBaselineName else {
            return XCTFail("The settings category fixture did not retain its seeded Human name.")
        }
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openSettingsFromHomeChrome(in: app)

        let identifiers = [
            "settings-destination-regionAndLanguage",
            "settings-destination-appearanceAndPerformance",
            "settings-destination-notifications",
            "settings-destination-privacyAndSecurity",
            "settings-destination-dataAndBackup",
            "settings-destination-about"
        ]

        for identifier in identifiers {
            openSettingsCategory(identifier, in: app)
            let back = app.navigationBars.buttons["BackButton"]
            XCTAssertTrue(back.waitForExistence(timeout: 8), "\(identifier) did not expose the system back button.")
            tapWhenHittable(back, timeout: 8)
            XCTAssertTrue(
                app.descendants(matching: .any)["settings-main-scroll"].waitForExistence(timeout: 8),
                "\(identifier) did not return to the Settings root."
            )
        }

        let personalAction = app.buttons["settings-personal-plan-action"]
        scrollTowardElement(personalAction, in: app)
        XCTAssertTrue(personalAction.exists)
        tapWhenHittable(personalAction, timeout: 8)
        let personalScreen = app.descendants(matching: .any)["personal-plan-screen"]
        XCTAssertTrue(personalScreen.waitForExistence(timeout: 12))
        tapWhenHittable(app.buttons["personal-plan-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !personalScreen.exists && app.buttons["settings-close-action"].exists },
            "Closing Personal did not return to Settings."
        )
        tapWhenHittable(app.buttons["settings-close-action"], timeout: 8)
        XCTAssertTrue(app.buttons["home-settings-action"].waitForExistence(timeout: 12))
    }

    @MainActor
    func testSettingsCoconutBalanceApplyButtonDoesNotFreeze() throws {
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            extraLaunchArguments: ["-OHANA_UI_TEST_OPEN_COCONUT_BALANCE_SHEET"]
        )
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        openSettingsFromHomeChrome(in: app)
        let debugCoconuts = app.buttons["settings-debug-coconuts-shortcut"].exists
            ? app.buttons["settings-debug-coconuts-shortcut"]
            : app.buttons["settings-debug-coconuts"]
        scrollToElement(debugCoconuts, in: app, maxSwipes: 6)
        XCTAssertTrue(
            debugCoconuts.waitForExistence(timeout: 12),
            "Settings did not expose the coconut balance developer tool."
        )
        tapWhenHittable(debugCoconuts, timeout: 8)

        let coconutScreen = app.descendants(matching: .any)["coconut-balance-test-screen"]
        XCTAssertTrue(
            coconutScreen.waitForExistence(timeout: 12),
            "Coconut balance developer tool did not open its sheet."
        )
        tapWhenHittable(app.buttons["coconut-balance-apply-action"], timeout: 8)

        let resultMessage = app.descendants(matching: .any)["coconut-balance-result-message"]
        XCTAssertTrue(
            resultMessage.waitForExistence(timeout: 12),
            "Applying the coconut test balance did not finish and show a result message."
        )
        tapWhenHittable(app.buttons["coconut-balance-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !coconutScreen.exists && app.buttons["settings-close-action"].exists },
            "Coconut balance developer tool did not remain responsive after applying the test balance."
        )
    }

    @MainActor
    func testSingleHumanPetHomeAndFunctionMenuFeelComplete() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Single Shape \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the single-member starter flow in time."
        )
        assertSingleMemberShapeHasNoDeficitCopy(in: app, context: "single-member Home after first pet")

        openOasisAndInjectStarterEnergy(in: app)
        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-all-features-summary-panel"].waitForExistence(timeout: 12),
            "The Pet feature hub did not remain open for a one-human one-pet household."
        )
        XCTAssertTrue(
            app.buttons["feature-hub-daily-food"].waitForExistence(timeout: 8),
            "The Pet feature hub did not expose food for a one-human one-pet household."
        )
        assertSingleMemberShapeHasNoDeficitCopy(in: app, context: "single-member Pet feature hub")
    }

    @MainActor
    func testReminderObservabilityPanelOpensFromDebugSettings() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        openSettingsFromHomeChrome(in: app)
        let observabilityRow = app.buttons["settings-debug-reminder-observability-shortcut"]
        XCTAssertTrue(
            observabilityRow.waitForExistence(timeout: 12),
            "Settings did not expose the reminder observability debug shortcut."
        )
        tapWhenHittable(observabilityRow, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["reminder-observability-screen"].waitForExistence(timeout: 12),
            "Reminder observability panel did not open from Settings debug tools."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["reminder-observability-ledger-card"].waitForExistence(timeout: 8),
            "Reminder observability panel did not expose the scheduling ledger card."
        )
    }

    @MainActor
    func testFamilyWeeklyReportOpensFromDebugSettingsWithoutCompetitionCopy() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Weekly Report \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the weekly report starter flow in time."
        )

        openFamilyWeeklyReportFromDebugSettings(in: app, humanName: humanName)
        assertWeeklyReportAvoidsCompetitionCopy(in: app, context: "weekly report debug settings smoke")
    }

    @MainActor
    func testHumanModuleRoutesOpenFromCurrentUI() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        openHumanDetailFromHome(in: app, humanName: humanName)
        let humanDetail = app.descendants(matching: .any)["human-detail-screen"]
        XCTAssertTrue(
            humanDetail.waitForExistence(timeout: 12),
            "The current Human profile entry did not open the member detail screen."
        )
        assertAnyMarkerExists([humanName], in: app, timeout: 8, context: "human detail profile")

        let detailRoutes: [(action: String, marker: String, close: String)] = [
            ("human-detail-health-metrics-action", "human-health-metric-starter-record-action", "BackButton"),
            ("human-detail-health-report-action", "human-health-report-add-action", "BackButton"),
            ("human-detail-wishlist-action", "human-wishlist-add-action", "human-module-close-action")
        ]
        for route in detailRoutes {
            let action = app.buttons[route.action]
            scrollToElement(action, in: app, maxSwipes: 8)
            XCTAssertTrue(
                waitForFrameReady(action, timeout: 10),
                "Human detail did not expose the current module action: \(route.action)"
            )
            XCTAssertTrue(
                tapWhenSemanticallyHittable(action, timeout: 8),
                "Human detail module action did not become semantically tappable: \(route.action)"
            )

            let marker = app.descendants(matching: .any)[route.marker]
            XCTAssertTrue(
                marker.waitForExistence(timeout: 12),
                "Human detail module did not expose its stable destination marker: \(route.marker)"
            )

            let close = app.buttons[route.close]
            XCTAssertTrue(
                tapWhenSemanticallyHittable(close, timeout: 8),
                "Human detail module did not expose its stable return action: \(route.close)"
            )
            XCTAssertTrue(
                waitUntil(timeout: 10) {
                    !marker.exists &&
                        app.buttons["human-detail-edit-action"].exists &&
                        app.buttons["human-detail-edit-action"].isHittable
                },
                "Human detail module did not return to the member detail screen: \(route.action)"
            )
        }

        let profileBack = app.buttons["BackButton"]
        XCTAssertTrue(
            tapWhenSemanticallyHittable(profileBack, timeout: 8),
            "Human detail did not expose a stable Back action."
        )
        XCTAssertTrue(
            waitUntil(timeout: 10) {
                !humanDetail.exists && app.buttons["home-tab-home"].exists
            },
            "Human detail did not return to Home."
        )

        let quickRoutes: [(legacy: String, marker: String, close: String)] = [
            ("feature-hub-body-weight", "human-weight-add-action", "ohana-sheet-close-action"),
            ("feature-hub-body-workout", "human-workout-summary-view", "human-module-close-action"),
            ("feature-hub-care-medication", "human-medication-add-action", "human-module-close-action"),
            ("feature-hub-money-expense", "human-expense-add-action", "ohana-sheet-close-action"),
            ("feature-hub-money-notes", "human-note-add-action", "human-module-close-action")
        ]
        for route in quickRoutes {
            openHumanModuleFromHome(route.legacy, in: app, humanName: humanName)
            let marker = app.descendants(matching: .any)[route.marker]
            XCTAssertTrue(
                marker.waitForExistence(timeout: 12),
                "Human quick-action detail did not expose its stable destination marker: \(route.marker)"
            )

            let close = app.buttons[route.close]
            XCTAssertTrue(
                tapWhenSemanticallyHittable(close, timeout: 8),
                "Human quick-action detail did not expose its stable Close action: \(route.close)"
            )
            XCTAssertTrue(
                waitUntil(timeout: 10) {
                    !marker.exists &&
                        !isHumanFeatureRouteOverlayVisible(in: app) &&
                        app.buttons["home-tab-home"].exists
                },
                "Human quick-action detail did not return to Home: \(route.legacy)"
            )
        }
    }

    @MainActor
    func testHumanRecordOperationsPersistFromCurrentUI() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let expenseNote = "Codex human expense \(timestamp)"
        let medicationName = "Vitamin D"
        let noteText = "Codex human note \(timestamp)"

        saveHumanWeightFromCurrentUI(in: app, humanName: humanName)
        assertHumanModuleRouteContains(
            "feature-hub-body-weight",
            markers: ["70.0", "70 kg", "70kg"],
            in: app,
            humanName: humanName
        )

        saveHumanExpenseFromCurrentUI(in: app, humanName: humanName, note: expenseNote)
        assertHumanModuleRouteContains(
            "feature-hub-money-expense",
            markers: [expenseNote],
            in: app,
            humanName: humanName
        )

        saveHumanMedicationFromCurrentUI(in: app, humanName: humanName, medicationName: medicationName)
        assertHumanModuleRouteContains(
            "feature-hub-care-medication",
            markers: [medicationName],
            in: app,
            humanName: humanName
        )

        saveHumanNoteFromCurrentUI(in: app, humanName: humanName, note: noteText)
    }

    @MainActor
    func testHumanHomeQuickActionsOpenExpectedSheets() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        assertHumanHomeQuickActionOpensSheet(
            actionIdentifier: "home-quick-action-humanWeight",
            sheetIdentifier: "generic-weight-entry-sheet-human",
            in: app,
            humanName: humanName
        )
        assertHumanHomeQuickActionOpensSheet(
            actionIdentifier: "home-quick-action-humanExpense",
            sheetIdentifier: "quick-human-expense-sheet",
            in: app,
            humanName: humanName
        )
        assertHumanHomeQuickActionOpensSheet(
            actionIdentifier: "home-quick-action-humanMedication",
            sheetIdentifier: "quick-human-medication-sheet",
            in: app,
            humanName: humanName
        )
        assertHumanHomeQuickActionOpensSheet(
            actionIdentifier: "home-quick-action-humanWorkout",
            sheetIdentifier: "quick-human-workout-sheet",
            in: app,
            humanName: humanName
        )
        assertHumanHomeQuickActionOpensSheet(
            actionIdentifier: "home-quick-action-humanNote",
            sheetIdentifier: "quick-human-note-sheet",
            in: app,
            humanName: humanName
        )
    }

    @MainActor
    func testHumanExtendedModuleOperationsPersistFromCurrentUI() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let workoutNote = "Codex workout \(timestamp)"
        let reportHospital = "Codex Clinic \(timestamp)"
        let reportSummary = "Codex health report \(timestamp)"
        let wishTitle = "Codex wish \(timestamp)"

        saveHumanHealthMetricFromCurrentUI(in: app, humanName: humanName)
        saveHumanWorkoutFromCurrentUI(in: app, humanName: humanName, note: workoutNote)
        saveHumanHealthReportFromCurrentUI(
            in: app,
            humanName: humanName,
            hospital: reportHospital,
            summary: reportSummary
        )
        saveHumanWishlistFromCurrentUI(in: app, humanName: humanName, title: wishTitle)
        assertHumanExtendedModuleOperationsPersistAfterRelaunch(
            in: app,
            humanName: humanName,
            reportHospital: reportHospital,
            reportSummary: reportSummary,
            wishTitle: wishTitle
        )
    }

    @MainActor
    func testHumanExtendedModuleDeletesDisappearFromCurrentUI() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let workoutNote = "Codex delete workout \(timestamp)"
        let reportHospital = "Codex Delete Clinic \(timestamp)"
        let reportSummary = "Codex delete report \(timestamp)"
        let noteText = "Codex delete note \(timestamp)"

        saveHumanHealthMetricFromCurrentUI(in: app, humanName: humanName)
        deleteHumanHealthMetricFromCurrentUI(in: app, humanName: humanName)

        saveHumanWorkoutFromCurrentUI(in: app, humanName: humanName, note: workoutNote)
        deleteHumanWorkoutFromProfile(in: app, humanName: humanName)

        saveHumanHealthReportFromCurrentUI(
            in: app,
            humanName: humanName,
            hospital: reportHospital,
            summary: reportSummary
        )
        deleteHumanHealthReportFromCurrentUI(
            in: app,
            humanName: humanName,
            hospital: reportHospital,
            summary: reportSummary
        )

        saveHumanNoteFromCurrentUI(in: app, humanName: humanName, note: noteText)
        deleteHumanNoteFromCurrentUI(in: app, humanName: humanName, note: noteText)
        assertHumanExtendedModuleDeletesStayDeletedAfterRelaunch(
            in: app,
            humanName: humanName,
            reportHospital: reportHospital,
            reportSummary: reportSummary,
            noteText: noteText
        )
    }

    @MainActor
    func testHumanWishlistRedeemSpendsCoconutsFromCurrentUI() throws {
        let startingBalance = 20
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            coconutBalanceSeedAmount: startingBalance
        )
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(
            in: app,
            expectedStarterGiftBalance: startingBalance * 2 + 50
        )

        let wishTitle = "Codex redeem wish \(Int(Date().timeIntervalSince1970))"

        saveHumanWishlistFromCurrentUI(in: app, humanName: humanName, title: wishTitle)
        redeemHumanWishlistFromCurrentUI(
            in: app,
            humanName: humanName,
            title: wishTitle,
            startingBalance: startingBalance,
            expectedBalance: startingBalance - 10
        )
    }

    @MainActor
    func testHumanSettingsInlineSwitcherHidesLocalPrivacyControls() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let ownerName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)
        let viewerName = createAdditionalHumanFromCrewRoster(in: app, homeHumanName: ownerName)
        openSettingsFromHomeChrome(in: app)

        XCTAssertTrue(
            app.buttons["settings-human-identity-switch-\(ownerName)"].waitForExistence(timeout: 8),
            "Settings did not list the original local member in the inline switcher."
        )
        XCTAssertTrue(
            app.buttons["settings-human-identity-switch-\(viewerName)"].waitForExistence(timeout: 8),
            "Settings did not list the additional local member in the inline switcher."
        )

        XCTAssertFalse(app.descendants(matching: .any)["human-account-switcher-sheet"].exists)
        let securitySheet = app.descendants(matching: .any)["human-account-security-sheet"]
        XCTAssertFalse(
            securitySheet.waitForExistence(timeout: 2),
            "First-release local member switching should not expose the future Human privacy/PIN sheet."
        )
        XCTAssertFalse(app.buttons["human-account-security-active-action"].exists)
        XCTAssertFalse(app.buttons["human-account-privacy-all-private-action"].exists)
        XCTAssertFalse(app.buttons["human-account-privacy-all-open-action"].exists)
    }

    @MainActor
    func testHumanProfileStaysVisibleWhenViewedByOtherLocalMember() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let ownerName = createFirstHuman(from: app)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(app.buttons["onboarding-defer-pet"], timeout: 8),
            "The optional first-pet step did not expose its semantic defer action."
        )
        ensureHomeSurfaceVisible(in: app, humanName: ownerName)
        let viewerName = createAdditionalHumanFromCrewRoster(in: app, homeHumanName: ownerName)

        switchActiveHumanFromSettings(in: app, to: viewerName)
        openHumanProfileViaUITestLaunchRoute(in: app, humanName: ownerName)
        assertHumanProfileVisibleInLocalFirstMode(in: app, ownerName: ownerName, viewerName: viewerName)
    }

    @MainActor
    func testHumanMemberButtonTapAndLongPressOpenDistinctRoutes() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        tapWhenHittable(app.buttons["onboarding-defer-pet"], timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let memberAction = app.buttons["home-crew-roster-action"]
        XCTAssertTrue(
            tapWhenSemanticallyHittable(memberAction, timeout: 8),
            "The Home member button did not accept its ordinary tap."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["crew-roster-members"].waitForExistence(timeout: 12),
            "An ordinary member-button tap did not open the crew roster."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["human-account-switcher-sheet"].exists,
            "An ordinary member-button tap incorrectly opened the account switcher."
        )
        closeCrewRosterIfNeeded(in: app)

        XCTAssertTrue(memberAction.waitForExistence(timeout: 8))
        memberAction.press(forDuration: 0.6)

        let identifiedSwitchAction = app.buttons["home-account-switcher-menu-action"]
        let labeledSwitchAction = app.buttons["Switch human account"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                identifiedSwitchAction.exists || labeledSwitchAction.exists
            },
            "Long-pressing the member button did not expose the account-switch action."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["crew-roster-members"].exists,
            "Long-pressing the member button incorrectly opened the crew roster."
        )
        let switchAction = identifiedSwitchAction.exists ? identifiedSwitchAction : labeledSwitchAction
        tapWhenHittable(switchAction, timeout: 8)

        let switcher = app.descendants(matching: .any)["human-account-switcher-sheet"]
        XCTAssertTrue(
            switcher.waitForExistence(timeout: 12),
            "Selecting the long-press action did not open the Human account switcher."
        )
        XCTAssertTrue(app.descendants(matching: .any)["human-account-active-card"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.buttons["human-account-switch-row-\(humanName)"].waitForExistence(timeout: 8),
            "The account switcher did not preserve the current Human row."
        )
        tapWhenHittable(app.buttons["human-account-switcher-close-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !switcher.exists && memberAction.exists },
            "Closing the account switcher did not return to Home."
        )
    }

    @MainActor
    func testHumanOnlyHouseholdOpensUnifiedAchievementsFromAllFeatures() throws {
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            unlockRewardTier: true
        )
        let humanName = createFirstHuman(from: app)
        tapWhenHittable(app.buttons["onboarding-defer-pet"], timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let primaryAction = app.buttons["home-primary-action"]
        XCTAssertTrue(
            primaryAction.waitForExistence(timeout: 12),
            "Human-only Home did not expose the feature-center menu."
        )
        primaryAction.press(forDuration: 0.6)

        let allFeatures = app.buttons["home-all-features-action"]
        XCTAssertTrue(
            allFeatures.waitForExistence(timeout: 8),
            "Long-pressing the Home action did not expose All Features."
        )
        tapWhenHittable(allFeatures, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["function-menu-root"].waitForExistence(timeout: 12),
            "All Features did not open the function-center root."
        )
        let achievements = app.buttons["function-menu-tool-achievements"]
        XCTAssertTrue(
            achievements.waitForExistence(timeout: 12),
            "The Human-only function center did not expose Achievements."
        )
        tapWhenHittable(achievements, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["achievement-unified-wall"].waitForExistence(timeout: 16),
            "The Human-only achievement entry did not open the unified wall."
        )
    }

    @MainActor
    func testHouseholdInsightsKeepAllSixTabsVisibleAtLevelSix() throws {
        let petName = "Codex Insight Pet \(Int(Date().timeIntervalSince1970))"
        let app = launchEnglishApp(
            matureHouseholdPetName: petName,
            enableProductionOverlays: true,
            unlockRewardTier: true
        )
        XCTAssertTrue(app.buttons["home-tab-home"].waitForExistence(timeout: 20))

        let primaryAction = app.buttons["home-primary-action"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 12))
        primaryAction.press(forDuration: 0.6)
        let allFeatures = app.buttons["home-all-features-action"]
        XCTAssertTrue(
            tapWhenFrameReady(allFeatures, timeout: 8),
            "Long-pressing Home did not produce a frame-ready All Features action."
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["function-menu-root"].waitForExistence(timeout: 12)
        )
        let household = app.buttons["function-menu-group-householdHub"]
        XCTAssertTrue(
            household.waitForExistence(timeout: 16),
            "Level 6 did not expose Household Insights in More."
        )
        tapWhenHittable(household, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["function-menu-group-screen-householdHub"]
                .waitForExistence(timeout: 12)
        )
        let segmentIDs = [
            "feature-weight",
            "feature-expense",
            "weekly-report",
            "care-ledger",
            "reminder-observability",
            "long-term-review"
        ]
        for id in segmentIDs {
            XCTAssertTrue(
                app.buttons["function-menu-group-segment-\(id)"].waitForExistence(timeout: 8),
                "Household Insights hid the \(id) tab instead of keeping it visible."
            )
        }

        let weight = app.buttons["function-menu-group-segment-feature-weight"]
        let weekly = app.buttons["function-menu-group-segment-weekly-report"]
        XCTAssertTrue(
            String(describing: weight.value).contains("Selected"),
            "Weight was not the available first Household Insight at Level 6."
        )
        XCTAssertFalse(
            String(describing: weekly.value).contains("Lv."),
            "Weekly Report should be available at Level 6."
        )
        let care = app.buttons["function-menu-group-segment-care-ledger"]
        let reminder = app.buttons["function-menu-group-segment-reminder-observability"]
        let review = app.buttons["function-menu-group-segment-long-term-review"]
        XCTAssertTrue(String(describing: care.value).contains("Lv.8"))
        XCTAssertTrue(String(describing: reminder.value).contains("Lv.8"))
        XCTAssertTrue(String(describing: review.value).contains("Lv.9"))

        let expense = app.buttons["function-menu-group-segment-feature-expense"]
        tapWhenHittable(expense, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8, condition: {
                String(describing: expense.value).contains("Selected")
                    && String(describing: weight.value).contains("Not selected")
            }),
            "The independent Expense tab did not become the selected dashboard."
        )
    }

    @MainActor
    func testFeedingManualPlanAndHomeQuickActionSmoke() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        let petName = "Codex Feed Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openFeedDetailFromHome(in: app, petName: petName)
        saveManualFeedingDefault(in: app)
        closeFeedDetailToHome(in: app)

        performHomeFeedQuickCheckIn(in: app, petName: petName, expectsAntiRepeatConfirmation: false)
        performHomeFeedQuickCheckIn(in: app, petName: petName, expectsAntiRepeatConfirmation: true)

        openFeedDetailFromHome(in: app, petName: petName, usingDetailMenuWhenAvailable: true)
        saveManualReminderPlan(in: app)
        assertQuickFeedMode(in: app, containsAny: ["Plan", "计划"], timeout: 8)
        closeFeedDetailToHome(in: app)
    }

    @MainActor
    func testFeedingManualHistoryAddOpensBackdateLogSheetAndRecords() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        let petName = "Codex Backdate Feed \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openFeedDetailFromHome(in: app, petName: petName)
        saveManualFeedingDefault(in: app)

        let yesterdayID = manualFeedHistoryDayIdentifier(daysAgo: 1)
        let twoDaysAgoID = manualFeedHistoryDayIdentifier(daysAgo: 2)
        addBackdatedManualFeedHistoryLog(daysAgo: 1, in: app)
        addBackdatedManualFeedHistoryLog(daysAgo: 2, in: app)

        let history = app.buttons["quick-feed-dock-history"]
        scrollToElement(history, in: app, maxSwipes: 4)
        tapWhenHittable(history, timeout: 8)

        assertManualFeedHistoryRow(dayIdentifier: yesterdayID, in: app)
        assertManualFeedHistoryRow(dayIdentifier: twoDaysAgoID, in: app)
    }

    @MainActor
    func testPetHomeQuickActionDetailRoutesOpenAndCancel() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Quick Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        assertPetHomeQuickActionOpensDetail(
            actionType: "water",
            detailIdentifier: "quick-water-detail-sheet",
            in: app,
            petName: petName,
            humanName: humanName
        )
        assertPetHomeQuickActionStaysResponsive(
            actionType: "play",
            in: app,
            petName: petName,
            humanName: humanName
        )
    }

    @MainActor
    func testPetExpandedCardShowsQuickActionsWithoutSecondTap() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        let petName = "Codex Quick Reveal \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        let petCard = app.buttons["home-card-pet-\(petName)"]
        XCTAssertTrue(petCard.waitForExistence(timeout: 14), "Home pet card did not appear before expansion.")
        tapWhenHittable(petCard, timeout: 8)

        let expandedFabShortcut = app.buttons["home-expanded-shortcut-allFeatures"]
        XCTAssertFalse(
            waitUntil(timeout: 1.5) {
                expandedFabShortcut.exists
            },
            "Tapping the Home card auto-opened the FAB secondary menu."
        )

        XCTAssertTrue(
            waitUntil(timeout: 4) {
                app.buttons["home-quick-action-feed"].exists ||
                    app.buttons["home-quick-action-water"].exists ||
                    app.buttons["home-quick-action-play"].exists
            },
            "Expanded pet card did not expose pet quick actions without a second tap."
        )
        XCTAssertFalse(
            expandedFabShortcut.exists,
            "FAB secondary menu opened while waiting for embedded card quick actions."
        )
    }

    @MainActor
    func testHumanExpandedCardShowsQuickActionsWithoutSecondTap() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let humanCard = app.buttons["home-card-human-\(humanName)"]
        XCTAssertTrue(humanCard.waitForExistence(timeout: 14), "Home human card did not appear before expansion.")
        XCTAssertTrue(
            tapWhenFrameReady(humanCard, timeout: 8),
            "Home human card did not expose a stable touch frame before expansion."
        )

        XCTAssertTrue(
            waitUntil(timeout: 6) {
                app.buttons["home-expanded-detail-human"].exists ||
                    app.buttons["home-quick-action-humanWeight"].exists ||
                    app.buttons["home-quick-action-humanMedication"].exists ||
                    app.buttons["home-quick-action-humanExpense"].exists
            },
            "Expanded human card did not expose human quick actions without a second tap."
        )
    }

    @MainActor
    func testPetHomeWalkCardMinimizesToFloatingBubble() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        let petName = "Codex Walk Minimize \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Dog",
            completionMessage: "Creating the first pet did not leave the walk minimize starter flow in time."
        )

        startWalkFromHomeQuickAction(in: app, petName: petName)

        let homeWalkMinimize = app.buttons["walk-tracking-card-minimize-action"]
        XCTAssertTrue(
            homeWalkMinimize.waitForExistence(timeout: 10),
            "Home embedded walk card did not expose the top-right minimize action."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["global-walk-bubble"].exists,
            "Global walk bubble appeared while the Home embedded walk card was still expanded."
        )

        tapWhenHittable(homeWalkMinimize, timeout: 8)

        XCTAssertTrue(
            waitUntil(timeout: 14) {
                app.buttons["home-card-pet-\(petName)"].exists ||
                    app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch.exists
            },
            "Minimizing the Home walk card did not reveal the pet card face."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["global-walk-bubble"].waitForExistence(timeout: 12),
            "Minimizing the Home walk card did not reveal the global walk bubble."
        )
        XCTAssertFalse(
            app.buttons["walk-tracking-card-minimize-action"].exists || app.buttons["walk-tracking-stop-action"].exists,
            "Home embedded walk controls remained visible while the global walk bubble was visible."
        )

        ensureHomePetQuickActionVisible(actionType: "walk", in: app, petName: petName)
        let resumeWalkAction = app.buttons["home-quick-action-walk"]
        tapWhenHittable(resumeWalkAction, timeout: 8)
        let quickStart = homeQuickActionMenuButton(in: app, actionType: "walk", suffix: "quick")
        XCTAssertTrue(
            quickStart.waitForExistence(timeout: 8),
            "Tapping Walk during an active walk did not expose the current quick action."
        )
        XCTAssertTrue(
            tapWhenFrameReady(quickStart, timeout: 8),
            "The active-walk quick action did not become tappable."
        )

        XCTAssertTrue(
            app.buttons["walk-tracking-card-minimize-action"].waitForExistence(timeout: 10) ||
                app.buttons["walk-tracking-stop-action"].waitForExistence(timeout: 10),
            "Tapping Walk again during an active walk did not flip back to the embedded current-walk card."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["global-walk-bubble"].exists,
            "Global walk bubble stayed visible after returning to the embedded current-walk card."
        )

        stopWalkFromVisibleHomeControls(in: app, petName: petName)
    }

    @MainActor
    func testPetRealUserLongSessionCoversCareCalendarEconomyAndSafeguards() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Long Cat \(timestamp)"
        let calendarTitle = "Codex linked pet visit \(timestamp)"

        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the long-session pet did not leave the pet creation handoff in time."
        )

        openFeedDetailFromHome(in: app, petName: petName)
        saveManualFeedingDefault(in: app)
        closeFeedDetailToHome(in: app, assertFeedReady: false)
        performHomeFeedQuickCheckIn(in: app, petName: petName, expectsAntiRepeatConfirmation: false)
        performHomeFeedQuickCheckIn(in: app, petName: petName, expectsAntiRepeatConfirmation: true)

        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)
        let waterLogAction = app.buttons["quick-water-log-action"]
        scrollToElement(waterLogAction, in: app, maxSwipes: 5)
        tapWhenHittable(waterLogAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-water-log-row-watering-"))
                .firstMatch
                .waitForExistence(timeout: 18),
            "Long-session water log did not appear after recording."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openLitterSettings(in: app)
        tapWhenHittable(app.descendants(matching: .any)["quick-potty-litter-settings-reminder-toggle"], timeout: 8)
        cancelLitterSettings(in: app)
        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Local only", "仅本地记录", "Nur lokal"],
            message: "Closing litter settings without saving persisted the long-session reminder draft."
        )
        tapWhenHittable(app.descendants(matching: .any)["quick-potty-litter-settings-reminder-toggle"], timeout: 8)
        tapWhenHittable(app.buttons["quick-potty-litter-settings-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Long-session litter settings sheet stayed open after saving."
        )
        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Reminder on", "提醒已开启", "Erinnerung an"],
            message: "Saving litter settings did not persist the long-session reminder state."
        )
        cancelLitterSettings(in: app)

        let scoopAction = app.buttons["quick-potty-scoop-primary-action"]
        scrollToElement(scoopAction, in: app, maxSwipes: 6)
        tapWhenHittable(scoopAction, timeout: 8)
        tapWhenHittable(app.buttons["quick-potty-scoop-confirm-action"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-potty-recent-row-litter-"))
                .firstMatch
                .waitForExistence(timeout: 18),
            "Long-session scoop log did not appear in recent potty records."
        )
        tapWhenHittable(scoopAction, timeout: 8)
        XCTAssertFalse(
            app.buttons["quick-potty-scoop-confirm-action"].isEnabled,
            "Long-session same-day scoop repeat confirmation remained enabled."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openPetHygieneDetailFromHome(in: app, petName: petName, humanName: humanName)
        let hygieneAction = app.buttons["pet-hygiene-teeth-record-action"]
        scrollToElement(hygieneAction, in: app, maxSwipes: 6)
        tapWhenHittable(hygieneAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-hygiene-teeth-recent-row-"))
                .firstMatch
                .waitForExistence(timeout: 18),
            "Long-session hygiene log did not appear after recording."
        )
        tapWhenHittable(hygieneAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.staticTexts["Already done today"].exists ||
                    app.staticTexts["今天已经完成了"].exists ||
                    app.buttons["OK"].exists ||
                    app.buttons["知道了"].exists
            },
            "Long-session repeat hygiene tap did not show the single-use guard."
        )
        tapWhenHittable(
            app.buttons.matching(NSPredicate(format: "label IN %@", ["OK", "知道了", "Verstanden"])).firstMatch,
            timeout: 8
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        let healthRecentRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-health-recent-row-"))
            .firstMatch
        openPetHealthVisitPopup(in: app)
        tapWhenHittable(app.buttons["pet-health-record-close-action"], timeout: 8)
        XCTAssertFalse(
            healthRecentRow.waitForExistence(timeout: 2),
            "Cancelling the long-session health popup created a recent health record."
        )
        openPetHealthVisitPopup(in: app)
        tapWhenHittable(app.buttons["pet-health-record-save-action"], timeout: 8)
        XCTAssertTrue(
            healthRecentRow.waitForExistence(timeout: 18),
            "Long-session health log did not appear after saving."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        if isHomePetQuickActionAvailable(actionType: "walk", in: app, petName: petName) {
            startWalkFromHomeQuickAction(in: app, petName: petName)
            stopWalkFromVisibleHomeControls(in: app, petName: petName)
            openPetWalkSummaryFromHome(in: app, petName: petName, humanName: humanName)
            XCTAssertTrue(
                app.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier BEGINSWITH %@", "walk-summary-row-"))
                    .firstMatch
                    .waitForExistence(timeout: 18),
                "Long-session walk summary did not show a persisted walk row."
            )
            closeCurrentSheetToHome(in: app, humanName: humanName)
        }

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: calendarTitle, linkedPetName: petName, in: app)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEvent(calendarTitle, exists: true, in: app, context: "long-session pet calendar filter")
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let bondVaultTile = app.buttons["feature-hub-finance-bondVault"]
        scrollToElement(bondVaultTile, in: app, maxSwipes: 6)
        tapWhenHittable(bondVaultTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-bond-vault-screen"].waitForExistence(timeout: 18),
            "Long-session Pet Bond Vault did not open before the low-balance check."
        )
        let balance = app.staticTexts["pet-bond-vault-balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 8), "Long-session Pet Bond Vault balance did not appear.")
        let preSeedBalance = Int(numericLabel(balance.label)) ?? 0
        XCTAssertLessThan(
            preSeedBalance,
            80,
            "Long-session pet should still be below the first Bond Vault unlock threshold before seeding."
        )
        let missingBalanceMarkers = ["80🥥 short", "80🥥", "short"]
        for _ in 0 ..< 4 where !containsAnyMarker(missingBalanceMarkers, in: app) {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(
            containsAnyMarker(missingBalanceMarkers, in: app),
            "Long-session Pet Bond Vault did not explain the low-balance purchase block."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openSettingsFromHomeChrome(in: app)
        let debugCoconuts = app.buttons["settings-debug-coconuts-shortcut"].exists
            ? app.buttons["settings-debug-coconuts-shortcut"]
            : app.buttons["settings-debug-coconuts"]
        tapWhenHittable(debugCoconuts, timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        scrollToElement(bondVaultTile, in: app, maxSwipes: 6)
        tapWhenHittable(bondVaultTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-bond-vault-screen"].waitForExistence(timeout: 18),
            "Long-session Pet Bond Vault did not reopen after seeding coconuts."
        )
        XCTAssertTrue(
            waitUntil(timeout: 12) { numericLabel(balance.label) == "1000" },
            "Long-session debug coconut seed did not reach the Pet Bond Vault."
        )
        let unlockAction = app.buttons["pet-bond-vault-unlock-card_border"]
        scrollToElement(unlockAction, in: app, maxSwipes: 4)
        XCTAssertTrue(
            tapWhenFrameReady(unlockAction, timeout: 8),
            "Long-session Pet Bond Vault unlock action was not frame-ready."
        )
        XCTAssertTrue(
            waitUntil(timeout: 12) { numericLabel(balance.label) == "920" },
            "Long-session Pet Bond Vault unlock did not spend 80 pet coconuts."
        )
        XCTAssertTrue(
            app.staticTexts["pet-bond-vault-recent-log"].waitForExistence(timeout: 8),
            "Long-session Pet Bond Vault unlock did not create a recent economy log row."
        )
    }

    @MainActor
    func testPetDogRealUserLongSessionCoversWalkMemorialEditAndDeleteSafeguards() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Long Dog \(timestamp)"
        let cancelledNote = "cancelled dog note \(timestamp)"
        let savedNote = "saved dog note \(timestamp)"

        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Dog",
            completionMessage: "Creating the long-session dog did not leave the pet creation handoff in time."
        )

        startWalkFromHomeQuickAction(in: app, petName: petName)
        stopWalkFromVisibleHomeControls(in: app, petName: petName)
        openPetWalkSummaryFromHome(in: app, petName: petName, humanName: humanName)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "walk-summary-row-"))
                .firstMatch
                .waitForExistence(timeout: 18),
            "Dog long-session walk summary did not show a persisted walk row."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetBasicInfoFromHome(in: app, petName: petName)
        openPetBasicInfoEditMode(in: app)
        enterPetBasicInfoNote(cancelledNote, in: app)
        discardPetBasicInfoChanges(in: app)
        XCTAssertFalse(
            app.staticTexts["pet-basic-info-notes-readback"].waitForExistence(timeout: 2),
            "Cancelling dog long-session Basic Info edit persisted an unsaved note."
        )

        openPetBasicInfoEditMode(in: app)
        enterPetBasicInfoNote(savedNote, in: app)
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)
        let noteReadback = app.staticTexts["pet-basic-info-notes-readback"]
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                noteReadback.exists && noteReadback.label.contains(savedNote)
            },
            "Saving dog long-session Basic Info edit did not persist the note readback."
        )
        XCTAssertFalse(
            noteReadback.label.contains(cancelledNote),
            "Dog long-session Basic Info readback contains the previously cancelled note."
        )

        let markAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        tapWhenHittable(markAction, timeout: 8)
        tapFirstAvailableButton(["Cancel", "取消", "Abbrechen"], in: app, timeout: 8, context: "dog long-session memorial mark cancel")
        XCTAssertFalse(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 2),
            "Cancelling the dog long-session memorial mark still wrote a passed-away date."
        )

        tapWhenHittable(markAction, timeout: 8)
        tapFirstAvailableButton(["Confirm", "确认", "Bestätigen"], in: app, timeout: 8, context: "dog long-session memorial mark confirm")
        let passedDate = app.staticTexts["pet-memorial-passed-date"]
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 12),
            "Confirming dog long-session memorial mark did not show the passed-away summary."
        )

        let undoAction = app.buttons["pet-memorial-undo-action"]
        scrollToElement(undoAction, in: app)
        tapWhenHittable(undoAction, timeout: 8)
        tapFirstAvailableButton(["Cancel", "取消", "Abbrechen"], in: app, timeout: 8, context: "dog long-session memorial undo cancel")
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 4),
            "Cancelling dog long-session memorial undo unexpectedly cleared the passed-away date."
        )

        tapWhenHittable(undoAction, timeout: 8)
        tapFirstAvailableButton(["Undo", "撤销", "Zurücknehmen"], in: app, timeout: 8, context: "dog long-session memorial undo confirm")
        XCTAssertTrue(
            markAction.waitForExistence(timeout: 12),
            "Confirming dog long-session memorial undo did not restore the live-pet mark action."
        )

        scrollToElement(app.buttons["pet-danger-delete-action"], in: app)
        tapWhenHittable(app.buttons["pet-danger-delete-action"], timeout: 8)
        let finalDelete = app.buttons["pet-delete-confirm-delete"]
        XCTAssertTrue(finalDelete.waitForExistence(timeout: 8), "Dog long-session delete confirmation action did not appear.")
        XCTAssertFalse(finalDelete.isEnabled, "Dog long-session delete action should stay disabled before exact-name confirmation.")
        let nameInput = app.textFields["pet-delete-confirm-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Dog long-session delete confirmation input did not appear.")
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText("wrong \(petName)")
        XCTAssertFalse(finalDelete.isEnabled, "Dog long-session delete action became enabled for a mismatched pet name.")
        tapWhenHittable(app.buttons["pet-delete-confirm-cancel"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 8),
            "Cancelling dog long-session delete did not return to Basic Info."
        )

        scrollToElement(app.buttons["pet-danger-delete-action"], in: app)
        tapWhenHittable(app.buttons["pet-danger-delete-action"], timeout: 8)
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Dog long-session final delete input did not reappear.")
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText(petName)
        XCTAssertTrue(finalDelete.isEnabled, "Dog long-session delete action did not enable after exact-name confirmation.")
        tapWhenHittable(finalDelete, timeout: 8)

        let deletedPrompt = app.buttons["home-add-first-pet-action"]
        let deletedPromptCard = app.buttons["home-add-first-pet-card"]
        let deletedPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        let didReturnResponsive = waitUntil(timeout: 20) {
            app.state == .runningForeground &&
                (deletedPrompt.isHittable || deletedPromptCard.isHittable || !deletedPetCard.isHittable) &&
                isHomeSurfaceResponsive(in: app)
        }
        XCTAssertTrue(didReturnResponsive, "Dog long-session permanent delete did not return to a responsive Home surface.")
        XCTAssertFalse(deletedPetCard.isHittable, "Deleted dog long-session pet card is still visible on Home.")
    }

    @MainActor
    func testExistingPetRealUserJourneyWithoutReset() throws {
        let app = launchEnglishApp(
            resetPersistentState: false,
            seedHumanBaseline: false,
            enableProductionOverlays: true
        )
        prepareExistingUserHomeDiscovery(in: app)
        let humanName: String
        if let existingHumanName = firstExistingHomeHumanName(in: app) {
            humanName = existingHumanName
        } else if app.textFields["onboarding-human-name-input"].waitForExistence(timeout: 3) {
            let onboardingHumanName = "Codex No Reset Human \(Int(Date().timeIntervalSince1970))"
            createOnboardingHuman(named: onboardingHumanName, in: app)
            humanName = onboardingHumanName
        } else {
            throw XCTSkip(
                "Existing-user journey requires an existing Home user or a fresh Human-first onboarding state; it will not reset or inject a hidden baseline."
            )
        }

        let petName: String = if let existingPetName = firstExistingHomePetName(in: app) {
            existingPetName
        } else {
            completeFirstDayStarterFunnel(
                in: app,
                petName: "Codex No Reset Pet \(Int(Date().timeIntervalSince1970))",
                completionMessage: "Creating the reusable no-reset pet baseline did not leave the pet creation handoff in time."
            )
        }

        let calendarTitle = "Codex no-reset pet visit \(Int(Date().timeIntervalSince1970))"

        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)
        let waterLogAction = app.buttons["quick-water-log-action"]
        scrollToElement(waterLogAction, in: app, maxSwipes: 5)
        tapWhenHittable(waterLogAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-water-log-row-watering-"))
                .firstMatch
                .waitForExistence(timeout: 18),
            "No-reset pet journey did not show a recent Water record after logging."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: calendarTitle, linkedPetName: petName, in: app)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEvent(calendarTitle, exists: true, in: app, context: "no-reset pet calendar readback")
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let bondVaultTile = app.buttons["feature-hub-finance-bondVault"]
        scrollToElement(bondVaultTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            bondVaultTile.waitForExistence(timeout: 12),
            "No-reset pet journey did not expose the Bond Vault tile."
        )
        tapWhenHittable(bondVaultTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-bond-vault-screen"].waitForExistence(timeout: 18),
            "No-reset pet journey did not open Pet Bond Vault."
        )
        XCTAssertTrue(
            app.staticTexts["pet-bond-vault-balance"].waitForExistence(timeout: 8),
            "No-reset pet journey did not show the Pet Bond Vault balance."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        XCTAssertTrue(
            app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 14) ||
                app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch.waitForExistence(timeout: 2),
            "No-reset pet journey did not preserve the existing pet after relaunch."
        )
    }

    @MainActor
    func testPetWaterRecordPersistsFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Water Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)

        let recentRowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "quick-water-log-row-watering-")
        let recentRow = app.descendants(matching: .any).matching(recentRowPredicate).firstMatch
        XCTAssertFalse(
            recentRow.waitForExistence(timeout: 2),
            "Fresh pet unexpectedly showed a watering row before the water record flow."
        )

        let logAction = app.buttons["quick-water-log-action"]
        scrollToElement(logAction, in: app, maxSwipes: 5)
        XCTAssertTrue(
            logAction.waitForExistence(timeout: 12),
            "Water detail did not expose the water log action."
        )
        tapWhenHittable(logAction, timeout: 8)

        XCTAssertTrue(
            recentRow.waitForExistence(timeout: 18),
            "Water log did not appear in the recent strip after recording."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    func testPetWaterCareRewardAppearsInBondVaultLedger() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, resetEconomyBudget: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Water Reward Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)
        let logAction = app.buttons["quick-water-log-action"]
        scrollToElement(logAction, in: app, maxSwipes: 5)
        tapWhenHittable(logAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-water-log-row-watering-"))
                .firstMatch
                .waitForExistence(timeout: 18),
            "Water record did not appear before checking the Bond Vault reward ledger."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let bondVaultTile = app.buttons["feature-hub-finance-bondVault"]
        scrollToElement(bondVaultTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            bondVaultTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the Bond Vault tile after water care."
        )
        tapWhenHittable(bondVaultTile, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-bond-vault-screen"].waitForExistence(timeout: 18),
            "Pet Bond Vault did not open after recording water care."
        )
        let balance = app.staticTexts["pet-bond-vault-balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 8), "Pet Bond Vault balance did not appear after water care.")
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                (Int(numericLabel(balance.label)) ?? 0) > 0
            },
            "Recording water care did not surface a positive pet bond coconut balance in Bond Vault."
        )
        XCTAssertTrue(
            app.staticTexts["pet-bond-vault-recent-log"].waitForExistence(timeout: 8),
            "Recording water care did not create a visible pet Bond Vault recent economy log."
        )
    }

    @MainActor
    func testPetWaterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Water Calendar Pet \(Int(Date().timeIntervalSince1970))"
        let waterEventTitles = [
            "\(petName) water",
            "\(petName) 喂水",
            "\(petName) Wasser"
        ]
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)
        tapWhenHittable(app.buttons["quick-water-mode-plan"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["quick-water-plan-settings-sheet"].waitForExistence(timeout: 10),
            "Water plan settings did not open before Calendar sync setup."
        )
        tapWhenHittable(app.buttons["quick-water-plan-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !app.descendants(matching: .any)["quick-water-plan-settings-sheet"].exists
            },
            "Water plan settings stayed open after saving the Calendar-backed plan."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEventAny(of: waterEventTitles, exists: true, in: app, context: "water plan save calendar readback")

        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetWaterDetailFromHome(in: app, petName: petName, humanName: humanName)
        tapWhenHittable(app.buttons["quick-water-settings-action"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["quick-water-plan-settings-sheet"].waitForExistence(timeout: 10),
            "Water plan settings did not reopen before deleting the Calendar-backed plan."
        )
        tapWhenHittable(app.buttons["quick-water-plan-delete-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !app.descendants(matching: .any)["quick-water-plan-settings-sheet"].exists
            },
            "Water plan settings stayed open after switching back to manual."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEventAny(of: waterEventTitles, exists: false, in: app, context: "water plan delete calendar readback")
    }

    @MainActor
    func testPetFeatureHubDailyAndHealthRoutesOpenAndCancel() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Pet Hub \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        let routes: [PetFeatureHubRouteExpectation] = [
            .init(tileIdentifier: "feature-hub-daily-potty", markerIdentifier: "quick-potty-detail-sheet"),
            .init(tileIdentifier: "feature-hub-daily-hygiene", markerIdentifier: "pet-hygiene-detail-screen"),
            .init(tileIdentifier: "feature-hub-daily-walk", markerIdentifier: "walk-summary-sheet"),
            .init(tileIdentifier: "feature-hub-health-health", markerIdentifier: "pet-health-detail-screen")
        ]

        for route in routes {
            assertPetFeatureHubRouteOpens(
                route,
                in: app,
                petName: petName,
                humanName: humanName
            )
        }
    }

    @MainActor
    func testPetWalkQuickActionPersistsAndSummaryReadback() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Walk Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Dog",
            completionMessage: "Creating the first dog did not leave the pet creation handoff in time."
        )

        startWalkFromHomeQuickAction(in: app, petName: petName)
        stopWalkFromVisibleHomeControls(in: app, petName: petName)

        openPetWalkSummaryFromHome(in: app, petName: petName, humanName: humanName)
        let persistedWalkRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "walk-summary-row-"))
            .firstMatch
        XCTAssertTrue(
            persistedWalkRow.waitForExistence(timeout: 18),
            "Walk summary did not show a persisted walk row after the Home quick walk flow."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    func testPetPottyRecordPersistsFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Potty Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)

        let logAction = app.buttons["quick-potty-poop-primary-action"]
        scrollToElement(logAction, in: app, maxSwipes: 6)
        XCTAssertTrue(
            logAction.waitForExistence(timeout: 12),
            "Potty detail did not expose the poop log action."
        )
        tapWhenHittable(logAction, timeout: 8)

        let perfectType = app.descendants(matching: .any)["quick-potty-type-perfect"]
        XCTAssertTrue(
            perfectType.waitForExistence(timeout: 10),
            "Potty type picker did not expose the perfect poop option."
        )
        tapWhenHittable(perfectType, timeout: 8)

        let recentStrip = app.descendants(matching: .any)["quick-potty-recent-strip"]
        scrollToElement(recentStrip, in: app, maxSwipes: 6)
        let recentRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-potty-recent-row-potty-"))
            .firstMatch
        XCTAssertTrue(
            recentRow.waitForExistence(timeout: 18),
            "Potty log did not appear in the recent strip after recording."
        )
        XCTAssertTrue(
            recentStrip.exists,
            "Potty recent strip disappeared after recording."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    func testPetLitterScoopPersistsAndRepeatSubmitIsBlocked() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Litter Cat \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the first cat did not leave the pet creation handoff in time."
        )

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)

        let scoopAction = app.buttons["quick-potty-scoop-primary-action"]
        scrollToElement(scoopAction, in: app, maxSwipes: 6)
        XCTAssertTrue(
            scoopAction.waitForExistence(timeout: 12),
            "Cat potty detail did not expose the scoop action."
        )
        tapWhenHittable(scoopAction, timeout: 8)

        let confirmAction = app.buttons["quick-potty-scoop-confirm-action"]
        XCTAssertTrue(
            confirmAction.waitForExistence(timeout: 10),
            "Scoop check-in did not expose the confirm action."
        )
        tapWhenHittable(confirmAction, timeout: 8)

        let recentLitterRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-potty-recent-row-litter-"))
            .firstMatch
        XCTAssertTrue(
            recentLitterRow.waitForExistence(timeout: 18),
            "Scoop log did not appear in the recent strip after recording."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "quick-potty-recent-row-litter-", in: app),
            1,
            "One scoop produced an unexpected number of logical litter records."
        )

        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)

        let recentStrip = app.descendants(matching: .any)["quick-potty-recent-strip"]
        let persistedLitterRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-potty-recent-row-litter-"))
        scrollToElement(persistedLitterRows.firstMatch, in: app, maxSwipes: 6)
        XCTAssertTrue(
            persistedLitterRows.firstMatch.waitForExistence(timeout: 18),
            "Scoop log did not survive closing and reopening the potty detail."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "quick-potty-recent-row-litter-", in: app),
            1,
            "Reopening the potty detail showed an unexpected number of litter records after one scoop."
        )

        let reopenedScoopAction = app.buttons["quick-potty-scoop-primary-action"]
        scrollTowardElement(reopenedScoopAction, in: app, maxSwipes: 6)
        tapWhenHittable(reopenedScoopAction, timeout: 8)
        let repeatConfirm = app.buttons["quick-potty-scoop-confirm-action"]
        XCTAssertTrue(
            repeatConfirm.waitForExistence(timeout: 10),
            "Scoop repeat check did not reopen the scoop confirmation sheet."
        )
        XCTAssertFalse(
            repeatConfirm.isEnabled,
            "Scoop repeat confirmation remained enabled after today's litter log."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Done today")).firstMatch.exists ||
                    app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "今天已完成")).firstMatch.exists
            },
            "Scoop repeat confirmation did not explain the same-day guard."
        )
        tapWhenHittable(app.buttons["quick-potty-sheet-cancel-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.buttons["quick-potty-scoop-confirm-action"].exists
            },
            "Cancelling the guarded scoop confirmation did not return to the potty detail."
        )
        XCTAssertTrue(recentStrip.exists, "Cancelling the guarded scoop confirmation lost the potty detail.")
        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        let finalLitterRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-potty-recent-row-litter-"))
        scrollToElement(finalLitterRows.firstMatch, in: app, maxSwipes: 6)
        XCTAssertTrue(
            finalLitterRows.firstMatch.waitForExistence(timeout: 18),
            "The original scoop record disappeared after the guarded repeat path."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "quick-potty-recent-row-litter-", in: app),
            1,
            "The guarded repeat scoop changed the persisted litter record count."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    func testPetLitterFullChangePersistsFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Full Litter Cat \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the first cat did not leave the pet creation handoff in time."
        )

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)

        let fullChangeAction = app.buttons["quick-potty-litter-primary-action"]
        scrollToElement(fullChangeAction, in: app, maxSwipes: 6)
        XCTAssertTrue(
            fullChangeAction.waitForExistence(timeout: 12),
            "Cat potty detail did not expose the full litter change action."
        )
        tapWhenHittable(fullChangeAction, timeout: 8)

        let confirmAction = app.buttons["quick-potty-litter-confirm-action"]
        XCTAssertTrue(
            confirmAction.waitForExistence(timeout: 10),
            "Full litter change check-in did not expose the confirm action."
        )
        tapWhenHittable(confirmAction, timeout: 8)

        let recentLitterRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-potty-recent-row-litter-"))
            .firstMatch
        XCTAssertTrue(
            recentLitterRow.waitForExistence(timeout: 18),
            "Full litter change log did not appear in the recent strip after recording."
        )
    }

    @MainActor
    func testPetLitterPlanReminderCancelAndSaveFromQuickCareDetail() throws {
        let petName = "Codex Litter Plan Cat \(Int(Date().timeIntervalSince1970))"
        let fixture = launchMatureHouseholdEnglishApp(
            petName: petName,
            petSpecies: "cat",
            enableProductionOverlays: true
        )
        let app = fixture.app
        let humanName = fixture.humanName

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Local only", "仅本地记录", "Nur lokal"],
            message: "Fresh litter settings did not start as local-only."
        )

        let reminderToggle = app.descendants(matching: .any)["quick-potty-litter-settings-reminder-toggle"]
        XCTAssertTrue(
            reminderToggle.waitForExistence(timeout: 10),
            "Litter settings did not expose the reminder toggle."
        )
        tapWhenHittable(reminderToggle, timeout: 8)
        cancelLitterSettings(in: app)

        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Local only", "仅本地记录", "Nur lokal"],
            message: "Closing litter settings without saving persisted the reminder draft."
        )

        let reminderToggleAfterCancel = app.descendants(matching: .any)["quick-potty-litter-settings-reminder-toggle"]
        tapWhenHittable(reminderToggleAfterCancel, timeout: 8)
        let saveAction = app.buttons["quick-potty-litter-settings-save-action"]
        XCTAssertTrue(
            saveAction.waitForExistence(timeout: 10),
            "Litter settings did not expose the save action."
        )
        tapWhenHittable(saveAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Litter settings sheet stayed open after saving."
        )

        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Reminder on", "提醒已开启", "Erinnerung an"],
            message: "Saving litter settings did not survive reopening the potty detail."
        )
    }

    @MainActor
    func testPetLitterPlanDeleteClearsSavedReminderFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Litter Delete Cat \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the first cat did not leave the pet creation handoff in time."
        )

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openLitterSettings(in: app)

        let reminderToggle = app.descendants(matching: .any)["quick-potty-litter-settings-reminder-toggle"]
        XCTAssertTrue(
            reminderToggle.waitForExistence(timeout: 10),
            "Litter settings did not expose the reminder toggle before delete setup."
        )
        tapWhenHittable(reminderToggle, timeout: 8)
        tapWhenHittable(app.buttons["quick-potty-litter-settings-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Litter settings sheet stayed open after saving reminder-on state."
        )

        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Reminder on", "提醒已开启", "Erinnerung an"],
            message: "Litter settings did not show reminder-on before deleting the plan."
        )

        let deleteAction = app.buttons["quick-potty-litter-settings-delete-action"]
        scrollToElement(deleteAction, in: app, maxSwipes: 4)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 10),
            "Litter settings did not expose the delete-plan action."
        )
        tapWhenHittable(deleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Litter settings sheet stayed open after deleting the plan."
        )

        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Local only", "仅本地记录", "Nur lokal"],
            message: "Deleting the litter plan did not clear the saved reminder state."
        )
    }

    @MainActor
    func testPetLitterPlanCalendarEventAppearsAndDeletesFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Litter Calendar Cat \(Int(Date().timeIntervalSince1970))"
        let litterEventTitles = [
            "\(petName) Litter change",
            "\(petName) 换猫砂",
            "\(petName) Streu wechseln"
        ]
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the first cat did not leave the pet creation handoff in time."
        )

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openLitterSettings(in: app)

        let reminderToggle = app.descendants(matching: .any)["quick-potty-litter-settings-reminder-toggle"]
        XCTAssertTrue(
            reminderToggle.waitForExistence(timeout: 10),
            "Litter settings did not expose the reminder toggle before Calendar sync setup."
        )
        tapWhenHittable(reminderToggle, timeout: 8)
        tapWhenHittable(app.buttons["quick-potty-litter-settings-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Litter settings sheet stayed open after saving the Calendar-backed reminder."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEventAny(of: litterEventTitles, exists: true, in: app, context: "litter plan save calendar readback")

        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Reminder on", "提醒已开启", "Erinnerung an"],
            message: "Litter settings did not retain reminder-on state before deleting Calendar plan."
        )

        let deleteAction = app.buttons["quick-potty-litter-settings-delete-action"]
        scrollToElement(deleteAction, in: app, maxSwipes: 4)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 10),
            "Litter settings did not expose the delete-plan action before Calendar removal."
        )
        tapWhenHittable(deleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Litter settings sheet stayed open after deleting the Calendar-backed reminder."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEventAny(of: litterEventTitles, exists: false, in: app, context: "litter plan delete calendar readback")
    }

    @MainActor
    func testPetScoopPlanCalendarEventAppearsAndDeletesFromQuickCareDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Scoop Calendar Cat \(Int(Date().timeIntervalSince1970))"
        let scoopEventTitles = [
            "\(petName) Scoop plan",
            "\(petName) 铲屎计划",
            "\(petName) Klo-Plan"
        ]
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the first cat did not leave the pet creation handoff in time."
        )

        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openScoopSettings(in: app)

        let reminderToggle = app.descendants(matching: .any)["quick-potty-scoop-settings-reminder-toggle"]
        XCTAssertTrue(
            reminderToggle.waitForExistence(timeout: 10),
            "Scoop settings did not expose the reminder toggle before Calendar sync setup."
        )
        tapWhenHittable(reminderToggle, timeout: 8)
        tapWhenHittable(app.buttons["quick-potty-scoop-settings-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-scoop-settings-sheet"].exists
            },
            "Scoop settings sheet stayed open after saving the Calendar-backed reminder."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        selectCalendarListView(in: app)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEventAny(of: scoopEventTitles, exists: true, in: app, context: "scoop plan save calendar readback")

        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetPottyDetailFromHome(in: app, petName: petName, humanName: humanName)
        openScoopSettings(in: app)
        assertScoopSettingsStatus(
            in: app,
            containsAny: ["Reminder on", "提醒已开启", "Erinnerung an"],
            message: "Scoop settings did not retain reminder-on state before deleting Calendar plan."
        )

        let deleteAction = app.buttons["quick-potty-scoop-settings-delete-action"]
        scrollToElement(deleteAction, in: app, maxSwipes: 4)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 10),
            "Scoop settings did not expose the delete-plan action before Calendar removal."
        )
        tapWhenHittable(deleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-scoop-settings-sheet"].exists
            },
            "Scoop settings sheet stayed open after deleting the Calendar-backed reminder."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openCalendarTab(in: app, petName: petName)
        selectCalendarListView(in: app)
        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEventAny(of: scoopEventTitles, exists: false, in: app, context: "scoop plan delete calendar readback")
    }

    @MainActor
    func testPetHygieneRecordPersistsAndRepeatTapIsBlocked() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Hygiene Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetHygieneDetailFromHome(in: app, petName: petName, humanName: humanName)

        let recordAction = app.buttons["pet-hygiene-teeth-record-action"]
        scrollToElement(recordAction, in: app, maxSwipes: 6)
        XCTAssertTrue(
            recordAction.waitForExistence(timeout: 12),
            "Hygiene detail did not expose the teeth record action."
        )
        tapWhenHittable(recordAction, timeout: 8)

        let recentRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-hygiene-teeth-recent-row-"))
            .firstMatch
        XCTAssertTrue(
            recentRow.waitForExistence(timeout: 18),
            "Hygiene log did not appear in recent records after recording."
        )

        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetHygieneDetailFromHome(in: app, petName: petName, humanName: humanName)

        let reopenedRecordAction = app.buttons["pet-hygiene-teeth-record-action"]
        let persistedRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-hygiene-teeth-recent-row-"))
        scrollToElement(persistedRows.firstMatch, in: app, maxSwipes: 6)
        XCTAssertTrue(
            persistedRows.firstMatch.waitForExistence(timeout: 18),
            "Hygiene log did not survive closing and reopening the hygiene detail."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-hygiene-teeth-recent-row-", in: app),
            1,
            "Reopening the hygiene detail showed an unexpected number of teeth records after one check-in."
        )

        scrollTowardElement(reopenedRecordAction, in: app, maxSwipes: 6)
        tapWhenHittable(reopenedRecordAction, timeout: 8)
        let repeatAlert = app.alerts["Already done today"]
        XCTAssertTrue(
            repeatAlert.waitForExistence(timeout: 8),
            "Repeating the same hygiene record did not show the single-use guard."
        )
        let acknowledgeRepeat = repeatAlert.buttons["OK"]
        XCTAssertTrue(
            acknowledgeRepeat.waitForExistence(timeout: 4),
            "The hygiene repeat alert did not expose its scoped acknowledgement action."
        )
        tapWhenHittable(acknowledgeRepeat, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !repeatAlert.exists },
            "Acknowledging the hygiene repeat guard did not dismiss its alert."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-hygiene-detail-screen"].waitForExistence(timeout: 8),
            "Dismissing the repeat hygiene guard did not return to the hygiene detail screen."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
        openPetHygieneDetailFromHome(in: app, petName: petName, humanName: humanName)
        let finalPersistedRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-hygiene-teeth-recent-row-"))
        scrollToElement(finalPersistedRows.firstMatch, in: app, maxSwipes: 6)
        XCTAssertTrue(
            finalPersistedRows.firstMatch.waitForExistence(timeout: 18),
            "The original hygiene record disappeared after the guarded repeat path."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-hygiene-teeth-recent-row-", in: app),
            1,
            "The guarded repeat hygiene tap changed the persisted teeth record count."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    func testPetHealthRecordCancelAndSavePersistsFromFeatureHub() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Health Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)

        let recentRowPredicate = NSPredicate(format: "identifier BEGINSWITH %@", "pet-health-recent-row-")
        let recentRow = app.descendants(matching: .any).matching(recentRowPredicate).firstMatch
        XCTAssertFalse(
            recentRow.waitForExistence(timeout: 2),
            "Fresh pet unexpectedly showed a health recent row before the health record flow."
        )

        openPetHealthVisitPopup(in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-health-record-sheet"].waitForExistence(timeout: 10),
            "Health visit action did not open the record sheet."
        )
        tapWhenHittable(app.buttons["pet-health-record-close-action"], timeout: 8)
        XCTAssertFalse(
            recentRow.waitForExistence(timeout: 2),
            "Cancelling the health record popup created a recent health record."
        )

        openPetHealthVisitPopup(in: app)
        let saveAction = app.buttons["pet-health-record-save-action"]
        XCTAssertTrue(
            saveAction.waitForExistence(timeout: 10),
            "Health record popup did not expose the save action."
        )
        tapWhenHittable(saveAction, timeout: 8)

        XCTAssertTrue(
            recentRow.waitForExistence(timeout: 18),
            "Health log did not appear in the recent health records after saving."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "Saving one health visit did not produce exactly one visible recent row."
        )

        let savedRowIdentifier = recentRow.identifier
        XCTAssertTrue(
            savedRowIdentifier.hasPrefix("pet-health-recent-row-health-"),
            "The saved health row did not expose its persistent PetHealthLog identity."
        )

        closeCurrentSheetToHome(in: app, humanName: humanName)

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)

        let persistedRow = app.descendants(matching: .any)[savedRowIdentifier]
        XCTAssertTrue(
            persistedRow.waitForExistence(timeout: 18),
            "Relaunch did not read back the same saved health record."
        )
        XCTAssertEqual(
            uniqueAccessibilityIdentifierCount(prefix: "pet-health-recent-row-", in: app),
            1,
            "Relaunch lost or duplicated the saved health record."
        )

        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    func testPetPermanentDeleteFromBasicInfoSmoke() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        let petName = "Codex Delete Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetBasicInfoFromHome(in: app, petName: petName)
        scrollToElement(app.buttons["pet-danger-delete-action"], in: app)
        tapWhenHittable(app.buttons["pet-danger-delete-action"], timeout: 8)

        let nameInput = app.textFields["pet-delete-confirm-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Pet delete confirmation did not appear after tapping the permanent delete action.")
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText(petName)

        let finalDelete = app.buttons["pet-delete-confirm-delete"]
        XCTAssertTrue(finalDelete.waitForExistence(timeout: 8), "Pet delete confirmation action did not appear.")
        tapWhenHittable(finalDelete, timeout: 8)

        let deletedPrompt = app.buttons["home-add-first-pet-action"]
        let deletedPromptCard = app.buttons["home-add-first-pet-card"]
        let deletedPetCard = app.buttons["home-card-pet-\(petName)"]
        let didReturnResponsive = waitUntil(timeout: 20) {
            app.state == .runningForeground &&
                (deletedPrompt.isHittable || deletedPromptCard.isHittable || !deletedPetCard.exists) &&
                isHomeSurfaceResponsive(in: app)
        }
        XCTAssertTrue(didReturnResponsive, "Permanent pet deletion did not return to a responsive Home surface.")
        XCTAssertFalse(deletedPetCard.exists, "Deleted pet card is still visible on Home.")
    }

    @MainActor
    func testPetPermanentDeleteCancelAndWrongNameAreSafe() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        let petName = "Codex Safe Delete Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetBasicInfoFromHome(in: app, petName: petName)
        let deleteAction = app.buttons["pet-danger-delete-action"]
        scrollToElement(deleteAction, in: app)
        tapWhenHittable(deleteAction, timeout: 8)

        let closeAction = app.buttons["pet-delete-confirm-close"]
        XCTAssertTrue(closeAction.waitForExistence(timeout: 8), "Pet delete confirmation did not expose its top close action.")
        tapWhenHittable(closeAction, timeout: 8)
        XCTAssertFalse(
            app.textFields["pet-delete-confirm-name-input"].waitForExistence(timeout: 2),
            "Pet delete confirmation sheet stayed visible after its top close action."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 8),
            "Closing pet delete from the top action did not return to Basic Info."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) { containsAnyMarker([petName], in: app) },
            "Pet name disappeared after closing permanent delete from the top action."
        )

        scrollToElement(deleteAction, in: app)
        tapWhenHittable(deleteAction, timeout: 8)

        let finalDelete = app.buttons["pet-delete-confirm-delete"]
        XCTAssertTrue(finalDelete.waitForExistence(timeout: 8), "Pet delete confirmation action did not appear.")
        XCTAssertFalse(finalDelete.isEnabled, "Pet delete action should stay disabled until the exact pet name is entered.")

        let nameInput = app.textFields["pet-delete-confirm-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Pet delete confirmation input did not appear.")
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText("wrong \(petName)")
        XCTAssertFalse(finalDelete.isEnabled, "Pet delete action became enabled for a mismatched pet name.")

        tapWhenHittable(app.buttons["pet-delete-confirm-cancel"], timeout: 8)
        XCTAssertFalse(nameInput.waitForExistence(timeout: 2), "Pet delete confirmation sheet stayed visible after cancel.")
        XCTAssertTrue(app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 8), "Canceling pet delete did not return to Basic Info.")
        XCTAssertTrue(
            waitUntil(timeout: 8) { containsAnyMarker([petName], in: app) },
            "Pet name disappeared after canceling permanent delete."
        )
    }

    @MainActor
    func testHumanPermanentDeleteCancelAndWrongNameAreSafe() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        expandHumanCardFromHome(in: app, humanName: humanName)
        XCTAssertTrue(
            tapWhenFrameReady(app.buttons["home-expanded-detail-human"], timeout: 8),
            "Expanded Human card did not expose a stable detail entry before the permanent delete safety check."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["human-detail-screen"].waitForExistence(timeout: 12),
            "Human details did not open before the permanent delete safety check."
        )

        let markAction = app.buttons["human-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        XCTAssertTrue(
            markAction.waitForExistence(timeout: 8),
            "Human Basic Info did not expose a separate memorial mark action before delete."
        )

        let deleteAction = app.buttons["human-danger-delete-action"]
        scrollToElement(deleteAction, in: app)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 8),
            "Human Basic Info did not expose the permanent delete action."
        )
        tapWhenHittable(deleteAction, timeout: 8)

        let nameInput = app.textFields["human-delete-confirm-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Human delete confirmation input did not appear.")

        let finalDelete = app.buttons["human-delete-confirm-delete"]
        XCTAssertTrue(finalDelete.waitForExistence(timeout: 8), "Human delete confirmation action did not appear.")
        XCTAssertFalse(finalDelete.isEnabled, "Human delete action should stay disabled until the exact human name is entered.")

        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText("wrong \(humanName)")
        XCTAssertFalse(finalDelete.isEnabled, "Human delete action became enabled for a mismatched human name.")

        tapWhenHittable(app.buttons["human-delete-confirm-cancel"], timeout: 8)
        XCTAssertFalse(nameInput.waitForExistence(timeout: 2), "Human delete confirmation sheet stayed visible after cancel.")
        XCTAssertTrue(
            app.descendants(matching: .any)["human-detail-screen"].waitForExistence(timeout: 8),
            "Canceling human delete did not return to Human details."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.buttons["human-memorial-mark-action"].exists &&
                    app.buttons["human-danger-delete-action"].exists
            },
            "Human memorial and permanent delete actions were not both still available after canceling delete."
        )
    }

    @MainActor
    func testHumanPermanentDeleteWithExactNamePersistsAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let ownerName = createFirstHuman(from: app)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(app.buttons["onboarding-defer-pet"], timeout: 8),
            "The optional first-pet step did not expose its semantic defer action."
        )
        ensureHomeSurfaceVisible(in: app, humanName: ownerName)

        let deletedHumanName = createAdditionalHumanFromCrewRoster(
            in: app,
            homeHumanName: ownerName,
            name: "Codex Deleted Human \(Int(Date().timeIntervalSince1970))"
        )

        openHumanDetailFromHome(in: app, humanName: deletedHumanName)

        let deleteAction = app.buttons["human-danger-delete-action"]
        scrollToElement(deleteAction, in: app)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 8),
            "Additional Human did not expose the permanent delete action."
        )
        tapWhenHittable(deleteAction, timeout: 8)

        let nameInput = app.textFields["human-delete-confirm-name-input"]
        XCTAssertTrue(
            nameInput.waitForExistence(timeout: 8),
            "Human delete confirmation input did not appear."
        )
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText(deletedHumanName)

        let finalDelete = app.buttons["human-delete-confirm-delete"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                finalDelete.exists && finalDelete.isEnabled
            },
            "Human delete action did not enable after entering the exact name."
        )
        tapWhenHittable(finalDelete, timeout: 8)

        let ownerHomeCard = app.buttons["home-card-human-\(ownerName)"]
        let deletedHomeCard = app.buttons["home-card-human-\(deletedHumanName)"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                app.state == .runningForeground &&
                    ownerHomeCard.exists &&
                    !deletedHomeCard.exists &&
                    isHomeSurfaceResponsive(in: app)
            },
            "Deleting the additional Human did not return to responsive Home with the owner preserved."
        )
        XCTAssertFalse(
            deletedHomeCard.exists,
            "Deleted Human remained visible on Home."
        )

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: ownerName)

        let relaunchedOwnerCard = app.buttons["home-card-human-\(ownerName)"]
        let relaunchedDeletedCard = app.buttons["home-card-human-\(deletedHumanName)"]
        XCTAssertTrue(
            relaunchedOwnerCard.waitForExistence(timeout: 15),
            "Owner Human did not survive relaunch after deleting another Human."
        )
        XCTAssertFalse(
            relaunchedDeletedCard.waitForExistence(timeout: 3),
            "Deleted Human returned on Home after relaunch."
        )

        let rosterAction = app.buttons["home-crew-roster-action"]
        XCTAssertTrue(
            tapWhenSemanticallyHittable(rosterAction, timeout: 8),
            "Home crew roster action did not become semantically tappable after relaunch."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["crew-roster-members"]
                .waitForExistence(timeout: 12),
            "Crew roster did not open after relaunch."
        )

        let ownerRosterCard = app.buttons["crew-roster-card-human-\(ownerName)"]
        let deletedRosterCard = app.buttons["crew-roster-card-human-\(deletedHumanName)"]
        XCTAssertTrue(
            ownerRosterCard.waitForExistence(timeout: 12),
            "Owner Human was missing from the roster after relaunch."
        )
        XCTAssertFalse(
            deletedRosterCard.waitForExistence(timeout: 3),
            "Deleted Human returned in the roster after relaunch."
        )
    }

    @MainActor
    func testDeletingActiveHumanRequiresAccountSwitchAndPersistsAcrossRelaunch() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let ownerName = createFirstHuman(from: app)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(app.buttons["onboarding-defer-pet"], timeout: 8),
            "The optional first-pet step did not expose its semantic defer action."
        )
        ensureHomeSurfaceVisible(in: app, humanName: ownerName)

        let deletedHumanName = createAdditionalHumanFromCrewRoster(
            in: app,
            homeHumanName: ownerName,
            name: "Codex Active Deleted Human \(Int(Date().timeIntervalSince1970))"
        )
        switchActiveHumanFromSettings(in: app, to: deletedHumanName)
        openHumanDetailFromHome(in: app, humanName: deletedHumanName)

        let deleteAction = app.buttons["human-danger-delete-action"]
        scrollToElement(deleteAction, in: app)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 8),
            "Active additional Human did not expose the permanent delete action."
        )
        tapWhenHittable(deleteAction, timeout: 8)

        let nameInput = app.textFields["human-delete-confirm-name-input"]
        XCTAssertTrue(
            nameInput.waitForExistence(timeout: 8),
            "Active Human delete confirmation input did not appear."
        )
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText(deletedHumanName)

        let finalDelete = app.buttons["human-delete-confirm-delete"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                finalDelete.exists && finalDelete.isEnabled
            },
            "Active Human delete action did not enable after entering the exact name."
        )
        tapWhenHittable(finalDelete, timeout: 8)

        let switcher = app.descendants(matching: .any)["human-account-switcher-sheet"]
        XCTAssertTrue(
            switcher.waitForExistence(timeout: 18),
            "Deleting the active Human did not require choosing a remaining account."
        )
        XCTAssertFalse(
            app.buttons["human-account-switcher-close-action"].waitForExistence(timeout: 2),
            "Required account switch exposed a close action that could skip choosing an active Human."
        )

        let ownerSwitchRow = app.buttons["human-account-switch-row-\(ownerName)"]
        let deletedSwitchRow = app.buttons["human-account-switch-row-\(deletedHumanName)"]
        XCTAssertTrue(
            ownerSwitchRow.waitForExistence(timeout: 12),
            "Required account switch did not offer the surviving owner."
        )
        XCTAssertFalse(
            deletedSwitchRow.waitForExistence(timeout: 2),
            "Required account switch still offered the deleted Human."
        )
        XCTAssertTrue(
            tapWhenSemanticallyHittable(ownerSwitchRow, timeout: 8),
            "The surviving owner did not become semantically tappable in required account switch."
        )

        let ownerHomeCard = app.buttons["home-card-human-\(ownerName)"]
        let deletedHomeCard = app.buttons["home-card-human-\(deletedHumanName)"]
        let settings = app.buttons["home-settings-action"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                !switcher.exists &&
                    ownerHomeCard.exists &&
                    !deletedHomeCard.exists &&
                    settings.exists &&
                    settings.label.contains(ownerName) &&
                    isHomeSurfaceResponsive(in: app)
            },
            "Choosing the surviving owner did not restore a responsive Home and active identity."
        )

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: ownerName)
        XCTAssertTrue(
            waitUntil(timeout: 15) {
                app.buttons["home-settings-action"].exists &&
                    app.buttons["home-settings-action"].label.contains(ownerName)
            },
            "Relaunch did not preserve the surviving owner as the active Human."
        )
        XCTAssertFalse(
            app.buttons["home-card-human-\(deletedHumanName)"].waitForExistence(timeout: 3),
            "Deleted active Human returned on Home after relaunch."
        )

        XCTAssertTrue(
            tapWhenSemanticallyHittable(app.buttons["home-crew-roster-action"], timeout: 8),
            "Home crew roster action did not become semantically tappable after account recovery."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["crew-roster-members"].waitForExistence(timeout: 12),
            "Crew roster did not open after relaunching the recovered account."
        )
        XCTAssertTrue(
            app.buttons["crew-roster-card-human-\(ownerName)"].waitForExistence(timeout: 12),
            "Surviving owner was missing from the roster after relaunch."
        )
        XCTAssertFalse(
            app.buttons["crew-roster-card-human-\(deletedHumanName)"].waitForExistence(timeout: 3),
            "Deleted active Human returned in the roster after relaunch."
        )
    }

    @MainActor
    func testDeletedPetCalendarEventDoesNotOpenLiveCareRoute() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Deleted Calendar Pet \(timestamp)"
        let petEventTitle = "Codex deleted water reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetBasicInfoFromHome(in: app, petName: petName)
        scrollToElement(app.buttons["pet-danger-delete-action"], in: app)
        tapWhenHittable(app.buttons["pet-danger-delete-action"], timeout: 8)

        let nameInput = app.textFields["pet-delete-confirm-name-input"]
        XCTAssertTrue(nameInput.waitForExistence(timeout: 8), "Pet delete confirmation input did not appear before stale Calendar route check.")
        tapWhenHittable(nameInput, timeout: 8)
        nameInput.typeText(petName)

        let finalDelete = app.buttons["pet-delete-confirm-delete"]
        XCTAssertTrue(finalDelete.waitForExistence(timeout: 8), "Pet delete confirmation action did not appear before stale Calendar route check.")
        XCTAssertTrue(finalDelete.isEnabled, "Pet delete action did not enable after entering the exact pet name.")
        tapWhenHittable(finalDelete, timeout: 8)

        let deletedPetCard = app.buttons["home-card-pet-\(petName)"]
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                app.state == .runningForeground &&
                    !deletedPetCard.exists &&
                    isHomeSurfaceResponsive(in: app)
            },
            "Permanent pet deletion did not return to a responsive Home surface before stale Calendar route check."
        )

        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launch()
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openCalendarTabFromHome(in: app, humanName: humanName)
        let staleRow = app.descendants(matching: .any)["calendar-event-row-\(petEventTitle)"]
        if !staleRow.waitForExistence(timeout: 4) {
            scrollToElement(staleRow, in: app, maxSwipes: 4)
        }
        if staleRow.exists {
            tapCalendarEvent(petEventTitle, in: app)
            XCTAssertTrue(
                waitUntil(timeout: 8) {
                    app.state == .runningForeground
                },
                "Tapping a stale Calendar event for a deleted pet left the app unresponsive."
            )
            XCTAssertFalse(
                isAnyLivePetRouteVisible(in: app),
                "Tapping a stale Calendar event for a deleted pet opened a live care, health, walk, or economy route."
            )
        } else {
            XCTAssertFalse(
                staleRow.exists,
                "Deleted pet Calendar event was neither cleaned up nor available for stale-route verification."
            )
        }
    }

    @MainActor
    func testPetMemorialMarkCancelConfirmAndUndoFlow() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Memorial Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetBasicInfoFromHome(in: app, petName: petName)
        let markAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        tapWhenHittable(markAction, timeout: 8)
        let cancelledMarkAlert = app.alerts["Confirm passing mark"]
        XCTAssertTrue(
            cancelledMarkAlert.waitForExistence(timeout: 8),
            "The memorial mark action did not expose its confirmation alert."
        )
        tapWhenHittable(cancelledMarkAlert.buttons["Cancel"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 8),
            "Cancelling the memorial mark alert lost the pet profile."
        )
        XCTAssertTrue(
            markAction.waitForExistence(timeout: 4),
            "Cancelling the memorial mark alert removed the live-pet mark action."
        )
        XCTAssertFalse(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 2),
            "Cancelling the memorial mark alert still wrote a passed-away date."
        )

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openPetBasicInfoFromHome(in: app, petName: petName)
        let persistedMarkAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(persistedMarkAction, in: app)
        XCTAssertTrue(
            persistedMarkAction.waitForExistence(timeout: 8),
            "Relaunch after cancelling memorial mark did not preserve the live-pet state."
        )
        XCTAssertFalse(
            app.staticTexts["pet-memorial-passed-date"].exists,
            "Relaunch after cancelling memorial mark unexpectedly read a passed-away date."
        )

        tapWhenHittable(persistedMarkAction, timeout: 8)
        let confirmedMarkAlert = app.alerts["Confirm passing mark"]
        XCTAssertTrue(
            confirmedMarkAlert.waitForExistence(timeout: 8),
            "The persisted live-pet profile did not expose the memorial confirmation alert."
        )
        tapWhenHittable(confirmedMarkAlert.buttons["Confirm"], timeout: 8)
        let passedDate = app.staticTexts["pet-memorial-passed-date"]
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 12),
            "Confirming the memorial mark did not show the passed-away summary."
        )

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !app.buttons["home-card-pet-\(petName)"].exists },
            "Confirmed memorial pet still appeared as a live Home card after relaunch."
        )
        openPetBasicInfoFromCrewRoster(in: app, petName: petName)
        let persistedPassedDate = app.staticTexts["pet-memorial-passed-date"]
        XCTAssertTrue(
            persistedPassedDate.waitForExistence(timeout: 12),
            "Confirmed memorial mark did not survive relaunch and roster readback."
        )

        let persistedUndoAction = app.buttons["pet-memorial-undo-action"]
        scrollToElement(persistedUndoAction, in: app)
        tapWhenHittable(persistedUndoAction, timeout: 8)
        let cancelledUndoAlert = app.alerts["Undo passing mark"]
        XCTAssertTrue(
            cancelledUndoAlert.waitForExistence(timeout: 8),
            "The memorial undo action did not expose its confirmation alert."
        )
        tapWhenHittable(cancelledUndoAlert.buttons["Cancel"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 8),
            "Cancelling memorial undo lost the archived pet profile."
        )
        XCTAssertTrue(
            persistedPassedDate.waitForExistence(timeout: 4),
            "Cancelling the memorial undo alert unexpectedly cleared the passed-away date."
        )

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openPetBasicInfoFromCrewRoster(in: app, petName: petName)
        XCTAssertTrue(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 12),
            "Cancelling memorial undo did not preserve the archived state across relaunch."
        )

        let confirmedUndoAction = app.buttons["pet-memorial-undo-action"]
        scrollToElement(confirmedUndoAction, in: app)
        tapWhenHittable(confirmedUndoAction, timeout: 8)
        let confirmedUndoAlert = app.alerts["Undo passing mark"]
        XCTAssertTrue(
            confirmedUndoAlert.waitForExistence(timeout: 8),
            "The persisted memorial profile did not expose the undo confirmation alert."
        )
        tapWhenHittable(confirmedUndoAlert.buttons["Undo"], timeout: 8)
        let restoredMarkAction = app.buttons["pet-memorial-mark-action"]
        XCTAssertTrue(
            restoredMarkAction.waitForExistence(timeout: 12),
            "Confirming memorial undo did not restore the live-pet mark action."
        )

        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        XCTAssertTrue(
            app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12),
            "Confirmed memorial undo did not restore the pet Home card after relaunch."
        )
        openPetBasicInfoFromHome(in: app, petName: petName)
        let finalMarkAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(finalMarkAction, in: app)
        XCTAssertTrue(
            finalMarkAction.waitForExistence(timeout: 8),
            "Final relaunch did not preserve the restored live-pet memorial action."
        )
        XCTAssertFalse(
            app.staticTexts["pet-memorial-passed-date"].exists || app.buttons["pet-memorial-undo-action"].exists,
            "Final relaunch retained memorial state after confirmed undo."
        )
    }

    @MainActor
    func testHumanMemorialMarkCancelConfirmAndUndoFlow() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        expandHumanCardFromHome(in: app, humanName: humanName)
        XCTAssertTrue(
            tapWhenFrameReady(app.buttons["home-expanded-detail-human"], timeout: 8),
            "Expanded Human card did not expose a stable detail entry before the memorial lifecycle flow."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["human-detail-screen"].waitForExistence(timeout: 12),
            "Human details did not open before the memorial lifecycle flow."
        )

        let markAction = app.buttons["human-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        tapWhenHittable(markAction, timeout: 8)
        tapFirstAvailableButton(["Cancel", "取消", "Abbrechen"], in: app, timeout: 8, context: "human memorial mark cancel")
        XCTAssertFalse(
            app.staticTexts["human-memorial-passed-date"].waitForExistence(timeout: 2),
            "Cancelling the human memorial mark alert still wrote a passed-away date."
        )

        tapWhenHittable(markAction, timeout: 8)
        tapFirstAvailableButton(["Confirm", "确认", "Bestätigen"], in: app, timeout: 8, context: "human memorial mark confirm")
        let passedDate = app.staticTexts["human-memorial-passed-date"]
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 12),
            "Confirming the human memorial mark did not show the passed-away summary."
        )
        let undoAction = app.buttons["human-memorial-undo-action"]
        scrollToElement(undoAction, in: app)
        tapWhenHittable(undoAction, timeout: 8)
        tapFirstAvailableButton(["Cancel", "取消", "Abbrechen"], in: app, timeout: 8, context: "human memorial undo cancel")
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 4),
            "Cancelling human memorial undo unexpectedly cleared the passed-away date."
        )

        tapWhenHittable(undoAction, timeout: 8)
        tapFirstAvailableButton(["Undo", "撤销", "Zurücknehmen"], in: app, timeout: 8, context: "human memorial undo confirm")
        XCTAssertTrue(
            markAction.waitForExistence(timeout: 12),
            "Confirming human memorial undo did not restore the live mark action."
        )
    }

    @MainActor
    func testPetMemorialHidesHomeLiveCareEntrypoints() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Memorial Hidden Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetBasicInfoFromHome(in: app, petName: petName)
        let markAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        tapWhenHittable(markAction, timeout: 8)
        tapFirstAvailableButton(["Confirm", "确认", "Bestätigen"], in: app, timeout: 8, context: "hidden pet memorial mark confirm")
        XCTAssertTrue(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 12),
            "Confirming memorial mark did not show the passed-away summary."
        )

        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launch()
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let memorialPetCard = app.buttons["home-card-pet-\(petName)"]
        let fallbackPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !memorialPetCard.exists && !fallbackPetCard.isHittable
            },
            "Memorial pet still exposed a Home pet card after returning from Basic Info."
        )
        XCTAssertFalse(
            app.buttons["home-expanded-shortcut-allFeatures"].exists,
            "Memorial pet still exposed the expanded All Features shortcut on Home."
        )
        XCTAssertFalse(
            app.buttons["home-quick-action-feed"].exists || app.buttons["home-quick-action-water"].exists,
            "Memorial pet still exposed live-care quick actions on Home."
        )

        let rosterAction = app.buttons["home-crew-roster-action"]
        XCTAssertTrue(
            tapWhenFrameReady(rosterAction, timeout: 8),
            "Home member roster action did not become tappable after memorial pet return."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["crew-roster-members"].waitForExistence(timeout: 12),
            "Home member roster did not open after memorial pet return."
        )
        let memorialRosterCard = app.buttons["crew-roster-card-pet-\(petName)"]
        XCTAssertTrue(
            memorialRosterCard.waitForExistence(timeout: 12),
            "Memorial pet disappeared from the member archive roster."
        )
        tapWhenHittable(memorialRosterCard, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 12),
            "Opening the memorial pet from the member roster did not restore its archived profile."
        )
        XCTAssertTrue(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 12),
            "The archived memorial pet profile did not preserve its passed-away summary."
        )
    }

    @MainActor
    func testMemorialPetCalendarEventDoesNotOpenLiveCareRoute() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Memorial Calendar Pet \(timestamp)"
        let petEventTitle = "Codex stale water reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapWhenHittable(app.buttons["home-tab-home"], timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetBasicInfoFromHome(in: app, petName: petName)
        let markAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        tapWhenHittable(markAction, timeout: 8)
        tapFirstAvailableButton(["Confirm", "确认", "Bestätigen"], in: app, timeout: 8, context: "calendar pet memorial mark confirm")
        XCTAssertTrue(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 12),
            "Confirming memorial mark did not show the passed-away summary before stale Calendar route check."
        )

        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launch()
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openCalendarTabFromHome(in: app, humanName: humanName)
        assertCalendarEvent(petEventTitle, exists: false, in: app, context: "memorial event excluded from the active calendar")

        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.state == .runningForeground
            },
            "Filtering a memorial pet's Calendar event left the app unresponsive."
        )
        XCTAssertFalse(
            isAnyLivePetRouteVisible(in: app),
            "Filtering a memorial pet's Calendar event opened a live care, health, walk, or economy route."
        )
    }

    @MainActor
    func testPetBondVaultInsufficientBalanceBlocksUnlockFromFeatureHub() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Bond Vault Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let bondVaultTile = app.buttons["feature-hub-finance-bondVault"]
        scrollToElement(bondVaultTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            bondVaultTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the Bond Vault tile."
        )
        tapWhenHittable(bondVaultTile, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-bond-vault-screen"].waitForExistence(timeout: 18),
            "Pet Bond Vault did not open from the feature hub."
        )

        let balance = app.staticTexts["pet-bond-vault-balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 8), "Pet Bond Vault balance did not appear.")
        XCTAssertEqual(balance.label, "0", "A new pet should start with zero bond coconuts.")

        let missingBalanceMarkers = ["80🥥 short", "80🥥", "short"]
        for _ in 0 ..< 4 where !containsAnyMarker(missingBalanceMarkers, in: app) {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(
            containsAnyMarker(missingBalanceMarkers, in: app),
            "Pet Bond Vault did not explain that a zero-balance pet cannot unlock a paid item."
        )
        XCTAssertTrue(
            app.staticTexts["pet-bond-vault-recent-empty"].waitForExistence(timeout: 8),
            "Pet Bond Vault did not expose an empty recent-activity state for a new pet."
        )
    }

    @MainActor
    func testPetBondVaultUnlockSpendsPetBalanceFromFeatureHub() throws {
        let seedBalance = 1000
        let app = launchEnglishApp(enableProductionOverlays: true, coconutBalanceSeedAmount: seedBalance)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Bond Vault Spend Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time.",
            expectedStarterGiftBalance: seedBalance * 2 + 50
        )

        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let bondVaultTile = app.buttons["feature-hub-finance-bondVault"]
        scrollToElement(bondVaultTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            bondVaultTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the Bond Vault tile."
        )
        tapWhenHittable(bondVaultTile, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-bond-vault-screen"].waitForExistence(timeout: 18),
            "Pet Bond Vault did not open from the feature hub."
        )

        let balance = app.staticTexts["pet-bond-vault-balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 8), "Pet Bond Vault balance did not appear.")
        XCTAssertEqual(
            numericLabel(balance.label),
            "1000",
            "The UI-test pet coconut seed did not reach the Pet Bond Vault."
        )

        let unlockAction = app.buttons["pet-bond-vault-unlock-card_border"]
        scrollToElement(unlockAction, in: app, maxSwipes: 4)
        XCTAssertTrue(
            waitForFrameReady(unlockAction, timeout: 8),
            "Pet Bond Vault card-border unlock action was not frame-ready for the unlock tap."
        )
        unlockAction.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let didSpend = waitUntil(timeout: 12) {
            numericLabel(balance.label) == "920"
        }
        XCTAssertTrue(didSpend, "Unlocking the card-border item did not spend 80 pet coconuts.")
        XCTAssertTrue(
            app.staticTexts["pet-bond-vault-recent-log"].waitForExistence(timeout: 8),
            "Positive Pet Bond Vault unlock did not create a recent economy log row."
        )
    }

    @MainActor
    func testPetCoconutShopEffectPurchaseSpendsHumanBalanceFromFunctionMenu() throws {
        let seedBalance = 1000
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            coconutBalanceSeedAmount: seedBalance,
            unlockRewardTier: true
        )
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Shop Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time.",
            expectedStarterGiftBalance: seedBalance * 2 + 50
        )

        openCoconutShopFromOasis(in: app, humanName: humanName)

        let balance = app.descendants(matching: .any)["coconut-shop-current-human-balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 12), "Coconut Shop balance did not appear.")
        let startingBalance = Int(numericLabel(accessibilityText(for: balance))) ?? 0
        XCTAssertGreaterThanOrEqual(
            startingBalance,
            1000,
            "Debug Coconuts did not seed the active human balance before shop purchase. Current: \(accessibilityText(for: balance))"
        )

        tapWhenHittable(app.buttons["coconut-shop-category-effect"], timeout: 8)
        let limeGlow = app.descendants(matching: .any)["coconut-shop-item-fx_lime_glow"]
        scrollToElement(limeGlow, in: app, maxSwipes: 4)
        XCTAssertTrue(limeGlow.waitForExistence(timeout: 12), "Coconut Shop did not expose the Lime Glow pet effect item.")
        tapWhenHittable(limeGlow, timeout: 8)
        if !app.descendants(matching: .any)["coconut-shop-purchase-popup-fx_lime_glow"].waitForExistence(timeout: 2) {
            XCTAssertTrue(
                tapWhenFrameReady(limeGlow, offset: CGVector(dx: 0.5, dy: 0.82), timeout: 5),
                "Coconut Shop Lime Glow item did not expose a stable tappable frame."
            )
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["coconut-shop-purchase-popup-fx_lime_glow"].waitForExistence(timeout: 8),
            "Tapping Lime Glow did not open the purchase confirmation popup."
        )
        tapWhenHittable(app.buttons["coconut-shop-confirm-purchase-fx_lime_glow"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["coconut-shop-toast"].waitForExistence(timeout: 4),
            "Coconut Shop did not show purchase feedback after the effect purchase."
        )
        let didSpend = waitUntil(timeout: 12) {
            Int(numericLabel(accessibilityText(for: balance))) == startingBalance - 300
        }
        XCTAssertTrue(didSpend, "Purchasing Lime Glow did not spend 300 human coconuts through the shop GUI.")

        XCTAssertTrue(
            waitUntil(timeout: 12) {
                accessibilityText(for: limeGlow).contains("Owned")
            },
            "Purchased Lime Glow did not become an owned shop item."
        )

        let treasureBoxMetric = app.descendants(matching: .any)["coconut-shop-owned-count"]
        tapWhenHittable(treasureBoxMetric, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["inventory-screen"].waitForExistence(timeout: 12),
            "The shop's treasure-box entry did not open owned-item management."
        )
        let limeGlowSwitch = app.switches["coconut-inventory-effect-fx_lime_glow"]
        XCTAssertTrue(
            limeGlowSwitch.waitForExistence(timeout: 8),
            "The purchased Lime Glow effect was missing from the treasure box."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) { (limeGlowSwitch.value as? String) == "1" },
            "Purchasing Lime Glow did not equip it in the treasure box."
        )
        tapWhenHittable(limeGlowSwitch, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { (limeGlowSwitch.value as? String) == "0" },
            "The Lime Glow switch did not turn the effect off."
        )
        tapWhenHittable(limeGlowSwitch, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { (limeGlowSwitch.value as? String) == "1" },
            "The Lime Glow switch did not turn the effect back on."
        )

        tapWhenHittable(app.navigationBars["My treasure box"].buttons["Close"], timeout: 8)
        tapWhenHittable(app.navigationBars["Coconut Shop"].buttons["Close"], timeout: 8)
        openCoconutShopFromOasis(in: app, humanName: humanName)
        tapWhenHittable(app.buttons["coconut-shop-category-effect"], timeout: 8)
        let reopenedLimeGlow = app.descendants(matching: .any)["coconut-shop-item-fx_lime_glow"]
        scrollToElement(reopenedLimeGlow, in: app, maxSwipes: 4)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                accessibilityText(for: reopenedLimeGlow).contains("Owned")
            },
            "Lime Glow ownership did not survive closing and reopening the shop."
        )

        tapWhenHittable(app.descendants(matching: .any)["coconut-shop-owned-count"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["inventory-screen"].waitForExistence(timeout: 12),
            "The treasure box did not reopen after returning to the shop."
        )
        let persistedLimeGlowSwitch = app.switches["coconut-inventory-effect-fx_lime_glow"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                persistedLimeGlowSwitch.exists && (persistedLimeGlowSwitch.value as? String) == "1"
            },
            "The equipped Lime Glow state did not survive closing and reopening the shop."
        )
    }

    @MainActor
    func testPetBasicInfoEditCancelDoesNotPersistAndSaveDoes() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let petName = "Codex Edit Pet \(Int(Date().timeIntervalSince1970))"
        let cancelledNote = "cancelled pet note \(Int(Date().timeIntervalSince1970))"
        let savedNote = "saved pet note \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetBasicInfoFromHome(in: app, petName: petName)
        openPetBasicInfoEditMode(in: app)
        enterPetBasicInfoNote(cancelledNote, in: app)
        discardPetBasicInfoChanges(in: app)
        XCTAssertFalse(
            app.textFields["pet-basic-info-notes-input"].waitForExistence(timeout: 3),
            "Cancelling pet basic info edit left the edit note field visible."
        )
        XCTAssertFalse(
            app.staticTexts["pet-basic-info-notes-readback"].waitForExistence(timeout: 2),
            "Cancelling pet basic info edit persisted an unsaved note."
        )

        openPetBasicInfoEditMode(in: app)
        enterPetBasicInfoNote(savedNote, in: app)
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)

        let readback = app.staticTexts["pet-basic-info-notes-readback"]
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                readback.exists && readback.label.contains(savedNote)
            },
            "Saving pet basic info edit did not persist the note readback."
        )
        XCTAssertFalse(
            readback.label.contains(cancelledNote),
            "Pet basic info readback contains the previously cancelled note."
        )
    }

    @MainActor
    func testPetBasicInfoEmptyNameSaveKeepsOriginalName() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let petName = "Codex Empty Name Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openPetBasicInfoFromHome(in: app, petName: petName)
        openPetBasicInfoEditMode(in: app)

        let nameInput = app.textFields["pet-basic-info-name-input"]
        clearTextField(nameInput, in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["pet-basic-info-save-action"], timeout: 8)

        let nameReadback = app.staticTexts["pet-basic-info-name-readback"]
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                (nameReadback.exists && nameReadback.label.contains(petName)) || app.staticTexts[petName].exists
            },
            "Saving an empty Pet Basic Info name should keep the original pet name. Actual: \(nameReadback.exists ? nameReadback.label : "<missing>")"
        )

        openPetBasicInfoEditMode(in: app)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                (nameInput.value as? String) == petName
            },
            "Reopening Pet Basic Info edit after an empty-name save did not restore the original name. Actual: \((nameInput.value as? String) ?? "<nil>")"
        )
    }

    @MainActor
    func testPetCalendarFilterShowsOnlyPetLinkedEvents() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Pet \(timestamp)"
        let petEventTitle = "Codex pet calendar \(timestamp)"
        let generalEventTitle = "Codex general calendar \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: generalEventTitle, linkedPetName: nil, in: app)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)

        assertCalendarEvent(generalEventTitle, exists: true, in: app, context: "all-events general readback")
        assertCalendarEvent(petEventTitle, exists: true, in: app, context: "all-events pet readback")

        tapWhenHittable(app.buttons["calendar-filter-pet-\(petName)"], timeout: 8)
        assertCalendarEvent(petEventTitle, exists: true, in: app, context: "pet-filter pet event")
        assertCalendarEvent(generalEventTitle, exists: false, in: app, context: "pet-filter general event")

        tapWhenHittable(app.buttons["calendar-filter-all"], timeout: 8)
        assertCalendarEvent(generalEventTitle, exists: true, in: app, context: "all-filter general readback")
        assertCalendarEvent(petEventTitle, exists: true, in: app, context: "all-filter pet readback")
    }

    @MainActor
    func testCalendarAddEventKeyboardKeepsEditorControlsVisible() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Keyboard Calendar Pet \(timestamp)"
        let eventTitle = "Codex keyboard event \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        tapWhenHittable(app.buttons["home-primary-action"], timeout: 8)

        let titleField = app.textFields["add-event-title-input"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Calendar add-event sheet did not expose title input.")
        let reminderLeadPicker = app.buttons["add-event-reminder-lead-picker"]
        XCTAssertTrue(
            reminderLeadPicker.waitForExistence(timeout: 8),
            "Calendar add-event sheet did not expose the reminder lead picker."
        )
        XCTAssertTrue(
            waitUntil(timeout: 5) {
                accessibilityText(for: reminderLeadPicker).localizedCaseInsensitiveContains("At time")
            },
            "Calendar add-event sheet did not default to an at-time reminder option. Actual: \(accessibilityText(for: reminderLeadPicker))"
        )
        XCTAssertTrue(tapWhenFrameReady(titleField, timeout: 8), "Calendar event title input was not frame-ready.")

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "System keyboard did not appear after focusing the event title.")
        titleField.typeText(eventTitle)

        var visibleSaveAction: XCUIElement?
        let didKeepSaveAboveKeyboard = waitUntil(timeout: 6) {
            guard
                let saveAction = firstHittableButton(identifier: "add-event-save-action", in: app),
                keyboard.exists
            else { return false }
            visibleSaveAction = saveAction
            let saveFrame = saveAction.frame
            let keyboardFrame = keyboard.frame
            let windowFrame = app.windows.firstMatch.frame
            return isFiniteFrame(saveFrame) &&
                isFiniteFrame(keyboardFrame) &&
                isFiniteFrame(windowFrame) &&
                saveFrame.maxY <= keyboardFrame.minY + 2 &&
                saveFrame.width <= windowFrame.width * 0.55 &&
                saveFrame.height <= 72
        }
        XCTAssertTrue(
            didKeepSaveAboveKeyboard,
            "Calendar add-event save action should be a compact keyboard toolbar action, not a full-width overlay. save=\(visibleSaveAction?.frame.debugDescription ?? "nil"), keyboard=\(keyboard.frame)"
        )

        tapFirstHittableButton(identifier: "add-event-save-action", in: app, timeout: 8, context: "keyboard-visible calendar save")
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !app.textFields["add-event-title-input"].exists
            },
            "Calendar add-event sheet did not close after saving while the keyboard was visible."
        )
        assertCalendarEvent(eventTitle, exists: true, in: app, context: "keyboard-visible add-event save")
    }

    @MainActor
    func testManualCalendarEventRowOpensDetailEditsAndDeletes() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Manual Pet \(timestamp)"
        let eventTitle = "Codex manual event \(timestamp)"
        let editedTitle = "Codex edited manual event \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: eventTitle, linkedPetName: nil, in: app)
        tapCalendarEvent(eventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual calendar event")
        let detailEditAction = app.buttons["calendar-event-edit-action"]
        tapWhenHittable(detailEditAction, timeout: 8)

        let titleField = app.textFields["add-event-title-input"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Calendar event edit sheet did not expose title input.")
        clearTextField(titleField, in: app)
        titleField.typeText(editedTitle)
        dismissKeyboardIfPresent(in: app)
        tapFirstHittableButton(identifier: "add-event-save-action", in: app, timeout: 8, context: "calendar event edit save")

        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !app.textFields["add-event-title-input"].exists &&
                    !detailEditAction.exists
            },
            "Calendar event edit flow did not close back to the list after saving."
        )
        assertCalendarEvent(eventTitle, exists: false, in: app, context: "post-edit old title")
        assertCalendarEvent(editedTitle, exists: true, in: app, context: "post-edit new title")

        tapCalendarEvent(editedTitle, in: app)
        assertCalendarEventDetailOpen(in: app, context: "edited manual calendar event before deletion")
        let reopenedDetailEditAction = app.buttons["calendar-event-edit-action"]
        tapWhenHittable(app.buttons["calendar-event-delete-action"], timeout: 8)
        let confirmDeleteAction = app.buttons
            .matching(identifier: "calendar-event-confirm-delete-action")
            .firstMatch
        tapWhenHittable(confirmDeleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 10) {
                !reopenedDetailEditAction.exists
            },
            "Calendar event detail page did not close after deletion."
        )
        assertCalendarEvent(editedTitle, exists: false, in: app, context: "post-delete")
    }

    @MainActor
    func testPetLinkedManualCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Jump Pet \(timestamp)"
        let petEventTitle = "Codex pet profile jump \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked calendar event")
    }

    @MainActor
    func testPetLinkedManualWaterTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Water Pet \(timestamp)"
        let petEventTitle = "Codex water reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked water-title calendar event")
    }

    @MainActor
    func testSystemGeneratedPetCalendarFeedEventRowOpensQuickFeedDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Feed Pet \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openFeedDetailFromHome(in: app, petName: petName)
        saveManualReminderPlan(in: app)
        closeFeedDetailToHome(in: app)

        openCalendarTab(in: app, petName: petName)
        tapFirstCalendarEventAny(of: feedPlanCalendarTitleCandidates(), in: app)

        XCTAssertTrue(
            waitForQuickFeedHome(in: app, timeout: 18),
            "Tapping a system-generated feeding plan calendar event did not deep-link to the pet Feeding detail route."
        )
    }

    @MainActor
    func testPetLinkedManualPottyTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Potty Pet \(timestamp)"
        let petEventTitle = "Codex potty reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked potty-title calendar event")
    }

    @MainActor
    func testPetLinkedManualWalkTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Walk Pet \(timestamp)"
        let petEventTitle = "Codex walk reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Dog",
            completionMessage: "Creating the first dog did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked walk-title calendar event")
    }

    @MainActor
    func testPetLinkedManualPlayTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Play Pet \(timestamp)"
        let petEventTitle = "Codex play reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked play-title calendar event")
    }

    @MainActor
    func testPetLinkedManualWeightTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Weight Pet \(timestamp)"
        let petEventTitle = "Codex weight reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked weight-title calendar event")
    }

    @MainActor
    func testPetLinkedManualHealthTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Health Pet \(timestamp)"
        let petEventTitle = "Codex vet check reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked health-title calendar event")
    }

    @MainActor
    func testPetLinkedManualHygieneTitleCalendarEventRowOpensEventDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Hygiene Pet \(timestamp)"
        let petEventTitle = "Codex grooming reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        assertCalendarEventDetailOpen(in: app, context: "manual pet-linked hygiene-title calendar event")
    }

    @MainActor
    func testCoconutBalanceButtonOpensAndClosesLedgerFromHome() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let coconutBalance = app.buttons["home-coconut-action"]
        XCTAssertTrue(coconutBalance.waitForExistence(timeout: 20), "Home coconut balance action did not appear.")
        XCTAssertTrue(
            tapWhenFrameReady(coconutBalance, timeout: 8),
            "Home coconut balance action did not expose a stable touch frame."
        )

        let coconutTitle = app.staticTexts["Coconut History"]
        let didOpen = waitUntil(timeout: 12) {
            coconutTitle.exists || app.buttons["Close"].exists
        }
        XCTAssertTrue(didOpen, "Coconut history screen did not open.")

        let closeCandidates = [
            app.buttons["Close"],
            app.buttons["关闭"]
        ]
        let didShowClose = waitUntil(timeout: 8) {
            closeCandidates.contains { $0.exists }
        }
        XCTAssertTrue(didShowClose, "Coconut history close action did not appear.")
        guard let visibleClose = closeCandidates.first(where: { $0.exists }) else {
            XCTFail("Coconut history close action did not appear.")
            return
        }
        tapWhenHittable(visibleClose, timeout: 8)

        let didClose = waitUntil(timeout: 12) {
            app.state == .runningForeground &&
                !coconutTitle.exists &&
                !closeCandidates.contains { $0.exists } &&
                app.buttons["home-coconut-action"].exists
        }
        XCTAssertTrue(didClose, "Coconut history screen did not close promptly.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchEnglishApp(
        resetPersistentState: Bool = true,
        seedHumanBaseline: Bool = true,
        seedMemberCardBaseline: Bool = false,
        matureHouseholdPetName: String? = nil,
        matureHouseholdPetSpecies: String = "dog",
        enableProductionOverlays: Bool = false,
        coconutBalanceSeedAmount: Int? = nil,
        unlockRewardTier: Bool = false,
        resetEconomyBudget: Bool = false,
        initialExperienceMode: String = "standard",
        extraLaunchArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
            "-appLanguage",
            "en",
            "-OHANA_UI_TESTS"
        ]
        if resetPersistentState {
            app.launchArguments += ["-OHANA_RESET_PERSISTENT_STATE"]
        }
        if seedHumanBaseline || seedMemberCardBaseline {
            let baselineName = "Codex Human Baseline \(Int(Date().timeIntervalSince1970))"
            seededHumanBaselineName = baselineName
            app.launchArguments += [
                "-OHANA_UI_TEST_SEED_HUMAN_BASELINE",
                "-OHANA_UI_TEST_HUMAN_BASELINE_NAME",
                baselineName
            ]
            if seedMemberCardBaseline {
                app.launchArguments += ["-OHANA_UI_TEST_SEED_MEMBER_CARD_BASELINE"]
            }
        } else {
            seededHumanBaselineName = nil
        }
        if let matureHouseholdPetName {
            XCTAssertTrue(
                resetPersistentState && seedHumanBaseline && !seedMemberCardBaseline,
                "The mature household fixture requires reset plus the standard Human baseline."
            )
            app.launchArguments += [
                "-OHANA_UI_TEST_SEED_MATURE_HOUSEHOLD_BASELINE",
                "-OHANA_UI_TEST_PET_BASELINE_NAME",
                matureHouseholdPetName,
                "-OHANA_UI_TEST_PET_BASELINE_SPECIES",
                matureHouseholdPetSpecies
            ]
        }
        if enableProductionOverlays {
            app.launchArguments += ["-OHANA_ENABLE_PRODUCTION_OVERLAYS_IN_UI_TESTS"]
        }
        if let coconutBalanceSeedAmount {
            app.launchArguments += [
                "-OHANA_UI_TEST_SEED_COCONUT_BALANCE",
                "-OHANA_UI_TEST_COCONUT_BALANCE_AMOUNT",
                "\(coconutBalanceSeedAmount)"
            ]
        }
        if unlockRewardTier {
            app.launchArguments += ["-OHANA_UI_TEST_UNLOCK_REWARD_TIER"]
        }
        if resetEconomyBudget {
            app.launchArguments += ["-OHANA_UI_TEST_RESET_ECONOMY_BUDGET"]
        }
        app.launchArguments += extraLaunchArguments
        app.launch()
        chooseInitialExperienceIfNeeded(initialExperienceMode, in: app)
        return app
    }

    @MainActor
    private func chooseInitialExperienceIfNeeded(_ mode: String, in app: XCUIApplication) {
        let selection = app.descendants(matching: .any)["app-experience-selection"]
        _ = waitUntil(timeout: 8) {
            selection.exists ||
                app.textFields["onboarding-human-name-input"].exists ||
                app.buttons["home-tab-home"].exists ||
                app.descendants(matching: .any)["zen-home-screen"].exists
        }
        guard selection.exists else { return }
        let action = app.buttons["app-experience-\(mode)"]
        XCTAssertTrue(
            action.waitForExistence(timeout: 8),
            "The requested initial Ohana experience was not available: \(mode)"
        )
        tapWhenHittable(action, timeout: 8)

        // A freshly erased Simulator can occasionally drop the first
        // synthesized tap while its rendering pipelines are still warming.
        // The selection action is idempotent while this picker remains on
        // screen, so verify the handoff and retry its center once if needed.
        if !waitUntil(timeout: 2, condition: { !selection.exists }),
           action.exists,
           action.isEnabled {
            action.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(
            waitUntil(timeout: 8) { !selection.exists },
            "The requested initial Ohana experience did not open: \(mode)"
        )
    }

    @MainActor
    private func launchMatureHouseholdEnglishApp(
        petName: String,
        petSpecies: String,
        enableProductionOverlays: Bool = false
    ) -> (app: XCUIApplication, humanName: String) {
        let app = launchEnglishApp(
            matureHouseholdPetName: petName,
            matureHouseholdPetSpecies: petSpecies,
            enableProductionOverlays: enableProductionOverlays
        )
        guard let humanName = seededHumanBaselineName else {
            XCTFail("The mature household fixture did not request its Human baseline.")
            return (app, "Codex Human Baseline")
        }
        XCTAssertTrue(
            app.buttons["home-tab-home"].waitForExistence(timeout: 20),
            "The mature household fixture did not reach Home."
        )
        XCTAssertTrue(
            app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 12),
            "The mature household fixture did not expose its seeded Pet on Home."
        )
        return (app, humanName)
    }

    @MainActor
    private func openMemberCardJourney(in app: XCUIApplication) {
        XCTAssertTrue(
            app.buttons["home-tab-home"].waitForExistence(timeout: 20),
            "The member-card baseline did not reach Home."
        )
        tapWhenHittable(app.buttons["home-tab-calendar"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-route"].waitForExistence(timeout: 12),
            "The member-card baseline did not reach Tasks."
        )
        reopenMemberCardJourney(in: app)
    }

    @MainActor
    private func reopenMemberCardJourney(in app: XCUIApplication) {
        let action = app.buttons[
            "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile"
        ]
        XCTAssertTrue(action.waitForExistence(timeout: 12), "The member-card starter task did not appear.")
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)[
                "task-center-starter-journey-sheet-completeHumanProfile"
            ].waitForExistence(timeout: 12),
            "The member-card guided sheet did not open."
        )
    }

    @MainActor
    private func assertMemberCardProgress(
        _ expected: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let progress = app.descendants(matching: .any)["task-center-starter-journey-progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 8), file: file, line: line)
        XCTAssertTrue(
            waitUntil(timeout: 8) { self.accessibilityText(for: progress).contains(expected) },
            "Expected member-card progress \(expected), got \(accessibilityText(for: progress)).",
            file: file,
            line: line
        )
    }

    @MainActor
    private func assertMemberCardJourneyComplete(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertMemberCardProgress("2/2", in: app, file: file, line: line)
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The member-card journey did not expose its completed state.",
            file: file,
            line: line
        )
    }

    @MainActor
    private func completeAndClaimStarterProfilePrerequisites(in app: XCUIApplication) {
        completeAndClaimStarterJourney(
            in: app,
            actionIdentifier: "task-center-system-action-completeHumanProfile-household-starter-v1-humanProfile",
            sheetIdentifier: "task-center-starter-journey-sheet-completeHumanProfile",
            destination: "completeHumanProfile"
        ) {
            tapGuidedJourneyControlAfterSemanticScroll(
                app.buttons["task-center-starter-resolution-humanAppearance-preferNotToSay"],
                in: app
            )
            tapGuidedJourneyControlAfterSemanticScroll(
                app.buttons["task-center-starter-resolution-humanOptionalDetails-unknown"],
                in: app
            )
        }

        completeAndClaimStarterJourney(
            in: app,
            actionIdentifier: "task-center-system-action-completeFirstPetProfile-household-starter-v1-petProfile",
            sheetIdentifier: "task-center-starter-journey-sheet-completeFirstPetProfile",
            destination: "completeFirstPetProfile"
        ) {
            tapGuidedJourneyControlAfterSemanticScroll(
                app.buttons["task-center-starter-resolution-petLifeStage-unknown"],
                in: app
            )
        }

        completeAndClaimStarterJourney(
            in: app,
            actionIdentifier: "task-center-system-action-confirmPetIdentityProtection-household-starter-v1-identityProtection",
            sheetIdentifier: "task-center-starter-journey-sheet-confirmPetIdentityProtection",
            destination: "confirmPetIdentityProtection"
        ) {
            tapGuidedJourneyControlAfterSemanticScroll(
                app.buttons["task-center-starter-resolution-petIdentityDocuments-notApplicable"],
                in: app
            )
            tapGuidedJourneyControlAfterSemanticScroll(
                app.buttons["task-center-starter-resolution-petEmergencyContact-preferNotToSay"],
                in: app
            )
        }
    }

    @MainActor
    private func completeAndClaimStarterJourney(
        in app: XCUIApplication,
        actionIdentifier: String,
        sheetIdentifier: String,
        destination: String,
        completeQuestions: () -> Void
    ) {
        let action = app.buttons[actionIdentifier]
        let sheet = app.descendants(matching: .any)[sheetIdentifier]
        XCTAssertTrue(
            action.waitForExistence(timeout: 12),
            "The prerequisite \(destination) task did not appear."
        )
        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(
            sheet.waitForExistence(timeout: 12),
            "The prerequisite \(destination) journey did not open."
        )

        completeQuestions()
        XCTAssertTrue(
            app.descendants(matching: .any)["task-center-starter-journey-complete"]
                .waitForExistence(timeout: 12),
            "The prerequisite \(destination) journey did not reach its completed card."
        )
        tapGuidedJourneyControlAfterSemanticScroll(app.buttons["task-center-starter-journey-finish"], in: app)
        XCTAssertTrue(
            waitUntil(timeout: 12) { !sheet.exists },
            "The prerequisite \(destination) Finish action did not return to Tasks."
        )
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                action.exists && action.label.localizedCaseInsensitiveContains("Claim")
            },
            "The prerequisite \(destination) journey did not expose a separate Claim state."
        )

        tapWhenHittable(action, timeout: 8)
        XCTAssertTrue(sheet.waitForExistence(timeout: 12))
        tapGuidedJourneyControlAfterSemanticScroll(
            app.buttons["task-center-starter-journey-claim-\(destination)"],
            in: app
        )
        XCTAssertTrue(waitUntil(timeout: 12) { !sheet.exists })
        XCTAssertTrue(waitUntil(timeout: 12) { !action.exists })
    }

    @MainActor
    @discardableResult
    private func createFirstHuman(from app: XCUIApplication) -> String {
        guard let seededHumanBaselineName else {
            XCTFail("This module test did not request its explicit Human baseline.")
            return "Codex Human Baseline"
        }
        XCTAssertTrue(
            waitUntil(timeout: 25) {
                app.buttons["onboarding-create-pet-now"].exists ||
                    app.textFields["member-name-input"].exists ||
                    app.buttons["home-tab-home"].exists
            },
            "The Human-first Pet choice did not appear after the Human test baseline was seeded."
        )
        return seededHumanBaselineName
    }

    @MainActor
    private func createOnboardingHuman(named name: String, in app: XCUIApplication) {
        let nameField = app.textFields["onboarding-human-name-input"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 25), "The Human-first name field did not appear.")
        XCTAssertEqual(nameField.elementType, .textField)
        nameField.tap()
        nameField.typeText(name)
        let continueAction = app.buttons["onboarding-human-continue"]
        XCTAssertTrue(waitUntil(timeout: 8) { continueAction.exists && continueAction.isEnabled })
        tapWhenHittable(continueAction, timeout: 8)
        XCTAssertTrue(
            app.buttons["onboarding-create-pet-now"].waitForExistence(timeout: 12),
            "Saving the first Human did not reach the Pet choice."
        )
    }

    @MainActor
    @discardableResult
    private func completePetFirstD17Flow(
        in app: XCUIApplication,
        petName: String = "Codex D17 Pet \(Int(Date().timeIntervalSince1970))",
        completionMessage: String = "Pet-first onboarding did not reach the starter reward in time."
    ) -> String {
        let startedAt = Date()
        advanceOnboardingIntroToMemberCreation(in: app)
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "Pet-first onboarding name field did not appear.",
            completionMessage: completionMessage,
            petSpeciesLabel: "Dog",
            postSaveMarkerIdentifiers: ["home-card-pet-\(petName)"]
        )
        let homeTab = app.buttons["home-tab-home"]
        XCTAssertTrue(
            tapWhenFrameReady(homeTab, timeout: 8),
            "The Home tab was not reachable before the starter gift."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-human-")).count >= 1
            },
            "The first Human card was missing from Home before the starter gift appeared."
        )
        XCTAssertTrue(
            app.buttons["home-card-pet-\(petName)"].waitForExistence(timeout: 8),
            "The first Pet card was missing from Home before the starter gift appeared."
        )
        XCTAssertTrue(
            tapWhenFrameReady(app.buttons["home-tab-calendar"], timeout: 8),
            "Tasks was not reachable again to claim the starter gift."
        )
        finishRequiredStarterGift(in: app)

        let oasisTab = app.buttons["home-tab-oasis"]
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 8), "Oasis did not unlock after the starter gift was claimed.")
        XCTAssertTrue(tapWhenFrameReady(oasisTab, timeout: 8), "Oasis tab was not frame-ready after the starter reward.")
        XCTAssertTrue(app.otherElements["oasis-screen"].waitForExistence(timeout: 20), "The D17 flow did not show the Oasis seed surface.")
        let level = app.descendants(matching: .any)["oasis-tree-level-control"]
        XCTAssertTrue(level.waitForExistence(timeout: 12), "The Oasis seed level was not visible.")
        XCTAssertTrue(level.label.contains("level 0"), "The first Oasis surface was not the Lv0 seed state: \(level.label)")
        XCTAssertTrue(
            tapWhenFrameReady(homeTab, timeout: 8),
            "Home was not reachable after checking the Oasis seed state."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-human-")).count >= 1
            },
            "Human-first onboarding did not retain its Human profile on Home."
        )
        XCTAssertTrue(
            tapWhenFrameReady(oasisTab, timeout: 8),
            "Oasis was not reachable again after verifying the retained Home cards."
        )
        XCTAssertTrue(
            app.otherElements["oasis-screen"].waitForExistence(timeout: 12),
            "The starter flow did not return to Oasis for the next value-loop action."
        )
        XCTAssertLessThanOrEqual(
            Date().timeIntervalSince(startedAt),
            90,
            "The Human + Pet + reward + Oasis value loop exceeded 90 seconds."
        )
        return petName
    }

    @MainActor
    private func advanceOnboardingIntroToMemberCreation(in app: XCUIApplication) {
        let humanNameField = app.textFields["onboarding-human-name-input"]
        let createPetNow = app.buttons["onboarding-create-pet-now"]
        let nameField = app.textFields["member-name-input"]
        let didShowStartingSurface = waitUntil(timeout: 25) {
            humanNameField.exists || createPetNow.exists || nameField.exists
        }
        XCTAssertTrue(didShowStartingSurface, "Human-first onboarding did not become available.")

        if humanNameField.exists {
            createOnboardingHuman(
                named: "Codex Human \(Int(Date().timeIntervalSince1970))",
                in: app
            )
        }
        if createPetNow.exists {
            tapWhenHittable(createPetNow, timeout: 8)
        }

        let didReachMemberCreation = waitUntil(timeout: 12) {
            nameField.exists && nameField.isHittable
        }
        XCTAssertTrue(didReachMemberCreation, "The Pet choice did not advance to Pet creation.")
    }

    @MainActor
    @discardableResult
    private func completeFirstDayStarterFunnel(
        in app: XCUIApplication,
        petName: String = "Codex Pet \(Int(Date().timeIntervalSince1970))",
        petSpeciesLabel: String? = "Dog",
        completionMessage: String = "Creating the first pet did not leave the pet creation handoff in time.",
        expectedStarterGiftBalance: Int = 50
    ) -> String {
        openFirstPetCreationFromJourney(in: app)
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "Pet creation name field did not appear.",
            completionMessage: completionMessage,
            petSpeciesLabel: petSpeciesLabel,
            postSaveMarkerIdentifiers: ["home-card-pet-\(petName)"]
        )
        finishRequiredStarterGift(in: app, expectedHomeBalance: expectedStarterGiftBalance)
        return petName
    }

    @MainActor
    private func finishRequiredStarterGift(in app: XCUIApplication, expectedHomeBalance: Int = 50) {
        let taskClaim = app.buttons["task-center-system-action-claimStarterGift-system-journey-claim-starter-gift"]
        if !taskClaim.exists {
            XCTAssertTrue(
                tapWhenFrameReady(app.buttons["home-tab-calendar"], timeout: 8),
                "Tasks was not reachable to claim the first-pet reward."
            )
        }
        XCTAssertTrue(taskClaim.waitForExistence(timeout: 20), "First-pet reward task did not appear after the Pet was saved.")
        XCTAssertFalse(app.buttons["starter-gift-finish-action"].exists, "Starter gift appeared before the reward task was opened.")
        tapWhenHittable(taskClaim, timeout: 8)

        let finish = app.buttons["starter-gift-finish-action"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20), "Starter coconut gift action did not appear after the reward task was opened.")
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Oasis tab should stay hidden until the starter gift unlock action is tapped.")
        tapWhenHittable(finish, timeout: 8)
        XCTAssertTrue(app.buttons["home-tab-oasis"].waitForExistence(timeout: 8), "Oasis tab did not appear after unlocking the Coconut Tree.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.buttons["home-coconut-action"].label == "Coconut balance \(expectedHomeBalance)"
            },
            "The Home coconut balance did not refresh to the expected post-gift balance \(expectedHomeBalance) before the ceremony closed."
        )
        let homeTab = app.tabBars.buttons["home-tab-home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8), "Home tab did not remain available after starter gift.")
        XCTAssertTrue(
            tapWhenSemanticallyHittable(homeTab, timeout: 8),
            "Home tab did not become semantically tappable after starter gift."
        )
        XCTAssertTrue(
            waitUntil(timeout: 5) { homeTab.isSelected },
            "Home tab did not become selected after starter gift."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["starter-oasis-tab-prompt"].waitForExistence(timeout: 8),
            "Oasis tab prompt did not appear after starter gift."
        )
    }

    @MainActor
    private func openFirstPetCreationFromJourney(in app: XCUIApplication) {
        let humanNameField = app.textFields["onboarding-human-name-input"]
        let createPetNow = app.buttons["onboarding-create-pet-now"]
        let nameField = app.textFields["member-name-input"]
        let tasksTab = app.buttons["home-tab-calendar"]
        let didReachStartingSurface = waitUntil(timeout: 20) {
            humanNameField.exists || createPetNow.exists || nameField.exists || tasksTab.exists
        }
        XCTAssertTrue(didReachStartingSurface, "First-Pet creation entry did not appear.")

        if humanNameField.exists || createPetNow.exists {
            advanceOnboardingIntroToMemberCreation(in: app)
            return
        }
        if nameField.exists {
            return
        }

        tapWhenHittable(tasksTab, timeout: 8)
        let systemAction = app.buttons["task-center-system-action-createFirstPet-system-journey-create-first-pet"]
        XCTAssertTrue(systemAction.waitForExistence(timeout: 15), "Tasks did not expose the first-Pet system journey.")
        tapWhenHittable(systemAction, timeout: 8)
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 12),
            "Pet creation did not open from the Tasks system journey."
        )
    }

    @MainActor
    private func openOasisAndInjectStarterEnergy(in app: XCUIApplication) {
        let oasisTab = app.buttons["home-tab-oasis"]
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 20), "Oasis tab did not appear after member setup.")
        XCTAssertTrue(
            tapWhenFrameReady(oasisTab, timeout: 8),
            "Oasis tab existed but did not become frame-ready after member setup."
        )

        let oasisScreen = app.otherElements["oasis-screen"]
        XCTAssertTrue(oasisScreen.waitForExistence(timeout: 20), "Oasis did not become visible from the home tab.")

        injectStarterEnergyToLevelOne(in: app)
    }

    @MainActor
    private func injectStarterEnergyToLevelOne(in app: XCUIApplication) {
        let oasisScreen = app.otherElements["oasis-screen"]
        XCTAssertTrue(oasisScreen.waitForExistence(timeout: 20), "Oasis was not visible before starter energy injection.")

        let treeLevel = app.descendants(matching: .any)["oasis-tree-level-control"]
        XCTAssertTrue(treeLevel.waitForExistence(timeout: 12), "Oasis tree level control did not become visible.")
        XCTAssertTrue(treeLevel.label.contains("level 0"), "Fresh starter tree should begin at Lv0 before injection.")

        let injectEnergy = app.buttons["oasis-inject-energy-action"]
        for attempt in 1 ... 4 {
            XCTAssertTrue(
                tapWhenFrameReady(injectEnergy, timeout: 8),
                "Starter energy action existed but did not become frame-ready for injection \(attempt)."
            )
            let reachedEarly = waitUntil(timeout: 0.8) {
                app.descendants(matching: .any)["oasis-tree-level-control"].label.contains("level 1")
            }
            XCTAssertFalse(reachedEarly, "Starter energy reached Lv1 after only \(attempt) injection(s).")
        }

        XCTAssertTrue(
            tapWhenFrameReady(injectEnergy, timeout: 8),
            "Starter energy action existed but did not become frame-ready for the final injection."
        )

        let didReachLevelOne = waitUntil(timeout: 20) {
            app.descendants(matching: .any)["oasis-tree-level-control"].label.contains("level 1")
        }
        XCTAssertTrue(didReachLevelOne, "Five starter energy injections did not advance the Oasis tree to Lv1.")
    }

    @MainActor
    private func closeOasisToHome(in app: XCUIApplication) {
        let oasisScreen = app.otherElements["oasis-screen"]
        guard oasisScreen.exists else { return }
        let homeTab = app.buttons["home-tab-home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 8), "Oasis did not expose the Home tab.")
        XCTAssertTrue(tapWhenFrameReady(homeTab, timeout: 8), "The Home tab was not frame-ready from Oasis.")
        XCTAssertTrue(
            waitUntil(timeout: 12) { !oasisScreen.exists && app.buttons["home-crew-roster-action"].exists },
            "Switching from Oasis did not return to the Home member surface."
        )
    }

    @MainActor
    private func addFirstHumanAfterOnboarding(
        in app: XCUIApplication,
        name: String = "Codex Optional Human \(Int(Date().timeIntervalSince1970))"
    ) -> String {
        let crewButton = app.buttons["home-crew-roster-action"]
        XCTAssertTrue(crewButton.waitForExistence(timeout: 12), "Home did not expose member management after Pet-first onboarding.")
        tapWhenHittable(crewButton, timeout: 8)

        let addMember = app.buttons["crew-roster-primary-action"]
        XCTAssertTrue(addMember.waitForExistence(timeout: 12), "Member management did not expose Add Member.")
        tapWhenHittable(addMember, timeout: 8)
        let addHuman = app.buttons["crew-roster-add-human-action"]
        XCTAssertTrue(addHuman.waitForExistence(timeout: 8), "Member management did not expose the optional Human path.")
        tapWhenHittable(addHuman, timeout: 8)

        createMember(
            in: app,
            name: name,
            flowTitle: "Create Member Card",
            missingFieldMessage: "Optional Human name field did not appear.",
            completionMessage: "Optional Human creation did not return to Home.",
            postSaveMarkerIdentifiers: ["home-card-human-\(name)"]
        )
        cancelMemberCreationIfStillPresented(in: app)
        closeCrewRosterIfNeeded(in: app)
        return name
    }

    @MainActor
    private func openSettingsFromHomeChrome(in app: XCUIApplication) {
        let settings = app.buttons["home-settings-action"]
        XCTAssertTrue(settings.waitForExistence(timeout: 12), "Home settings action did not appear.")
        XCTAssertTrue(
            tapWhenSemanticallyHittable(settings, timeout: 8),
            "Home settings action existed but did not become semantically tappable."
        )

        let settingsCloseAction = app.buttons["settings-close-action"]
        XCTAssertTrue(settingsCloseAction.waitForExistence(timeout: 12), "Settings screen did not open from home chrome.")
    }

    @MainActor
    private func openSettingsCategory(_ identifier: String, in app: XCUIApplication) {
        let category = app.buttons[identifier]
        scrollToElement(category, in: app, maxSwipes: 8)
        XCTAssertTrue(category.waitForExistence(timeout: 12), "Settings category \(identifier) did not appear.")
        tapWhenHittable(category, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) { !category.exists || !category.isHittable },
            "Settings category \(identifier) did not navigate."
        )
    }

    @MainActor
    @discardableResult
    private func createAdditionalHumanFromCrewRoster(
        in app: XCUIApplication,
        homeHumanName: String,
        name: String = "Codex Viewer \(Int(Date().timeIntervalSince1970))"
    ) -> String {
        ensureHomeSurfaceVisible(in: app, humanName: homeHumanName)

        let crewButton = app.buttons["home-crew-roster-action"]
        XCTAssertTrue(crewButton.waitForExistence(timeout: 12), "Home crew roster action did not appear.")
        XCTAssertTrue(
            tapWhenSemanticallyHittable(crewButton, timeout: 8),
            "Home crew roster action did not become semantically tappable."
        )

        let addMember = app.buttons["crew-roster-primary-action"]
        XCTAssertTrue(addMember.waitForExistence(timeout: 12), "Crew roster did not expose the add-member action.")
        XCTAssertTrue(
            tapWhenSemanticallyHittable(addMember, timeout: 8),
            "Crew roster add-member action did not become semantically tappable."
        )

        let humanCrew = app.buttons["crew-roster-add-human-action"]
        XCTAssertTrue(humanCrew.waitForExistence(timeout: 8), "Crew roster add menu did not expose Human crew.")
        XCTAssertTrue(
            tapWhenSemanticallyHittable(humanCrew, timeout: 8),
            "Crew roster Human action did not become semantically tappable."
        )

        createMember(
            in: app,
            name: name,
            flowTitle: "Create Member Card",
            missingFieldMessage: "Additional Human creation name field did not appear.",
            completionMessage: "Creating the additional Human did not return to Home.",
            postSaveMarkerIdentifiers: [
                "home-card-human-\(name)"
            ]
        )
        cancelMemberCreationIfStillPresented(in: app)
        closeCrewRosterIfNeeded(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: name)
        return name
    }

    @MainActor
    private func closeCrewRosterIfNeeded(in app: XCUIApplication) {
        let closeRoster = app.buttons["crew-roster-close-action"]
        let didFindClose = waitUntil(timeout: 3) {
            closeRoster.exists && closeRoster.isEnabled && closeRoster.isHittable
        }
        guard didFindClose else { return }
        closeRoster.tap()
        _ = waitUntil(timeout: 8) {
            !closeRoster.exists || app.buttons["home-settings-action"].isHittable
        }
    }

    @MainActor
    private func cancelMemberCreationIfStillPresented(in app: XCUIApplication) {
        guard app.buttons["member-creation-primary-action"].exists || app.textFields["member-name-input"].exists else {
            return
        }
        let cancelCandidates = [
            app.buttons["Cancel"].firstMatch,
            app.buttons["取消"].firstMatch,
            app.buttons["Abbrechen"].firstMatch
        ]
        guard let cancel = cancelCandidates.first(where: { $0.exists && $0.isEnabled && $0.isHittable }) else {
            return
        }
        cancel.tap()
        _ = waitUntil(timeout: 8) {
            !app.buttons["member-creation-primary-action"].exists &&
                !app.textFields["member-name-input"].exists
        }
    }

    @MainActor
    private func switchActiveHumanFromSettings(in app: XCUIApplication, to humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openSettingsFromHomeChrome(in: app)

        let quickSwitch = app.buttons["settings-human-identity-switch-\(humanName)"]
        XCTAssertTrue(
            quickSwitch.waitForExistence(timeout: 12),
            "Settings did not expose the Human identity quick switch for \(humanName)."
        )
        XCTAssertTrue(
            tapWhenSemanticallyHittable(quickSwitch, timeout: 8),
            "Human identity switch did not become semantically tappable for \(humanName)."
        )
        let selectedSummary = app.staticTexts["settings-human-identity-selected-summary"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                selectedSummary.exists && selectedSummary.label.contains(humanName)
            },
            "Settings did not confirm the active Human switch to \(humanName) before relaunch."
        )

        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launchArguments.removeAll { $0 == "-OHANA_UI_TEST_SEED_HUMAN_BASELINE" }
        removeLaunchArgumentPair("-OHANA_UI_TEST_HUMAN_BASELINE_NAME", from: &app.launchArguments)
        app.launch()
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let settings = app.buttons["home-settings-action"]
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                settings.exists && settings.label.contains(humanName)
            },
            "Relaunch did not restore the active Human switch to \(humanName)."
        )
    }

    @MainActor
    private func openHumanProfileViaUITestLaunchRoute(in app: XCUIApplication, humanName: String) {
        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        removeLaunchArgumentPair("-OHANA_UI_TEST_OPEN_HUMAN_PROFILE_NAME", from: &app.launchArguments)
        app.launchArguments += ["-OHANA_UI_TEST_OPEN_HUMAN_PROFILE_NAME", humanName]
        app.launch()

        let detailScreen = app.descendants(matching: .any)["human-detail-screen"]
        XCTAssertTrue(
            detailScreen.waitForExistence(timeout: 24),
            "UI-test Human profile route did not open \(humanName)."
        )
    }

    private func removeLaunchArgumentPair(_ flag: String, from arguments: inout [String]) {
        while let index = arguments.firstIndex(of: flag) {
            arguments.remove(at: index)
            if arguments.indices.contains(index) {
                arguments.remove(at: index)
            }
        }
    }

    @MainActor
    private func assertHumanProfileVisibleInLocalFirstMode(
        in app: XCUIApplication,
        ownerName: String,
        viewerName: String
    ) {
        XCTAssertTrue(
            app.descendants(matching: .any)["human-detail-screen"].waitForExistence(timeout: 12),
            "Human profile screen did not appear for private owner \(ownerName)."
        )
        XCTAssertTrue(
            !app.descendants(matching: .any)["human-detail-private-profile-lock"].exists,
            "Local-first Human profile showed a private profile lock for \(ownerName) when viewed by \(viewerName)."
        )
    }

    @MainActor
    private func closeSettingsToHome(in app: XCUIApplication, humanName: String) {
        let close = app.buttons["ohana-sheet-close-action"]
        if close.exists {
            tapWhenHittable(close, timeout: 8)
        } else {
            dismissCurrentSheetByDrag(in: app)
        }
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
    }

    @MainActor
    private func resetEconomyBudgetFromHomeChrome(in app: XCUIApplication) {
        openSettingsFromHomeChrome(in: app)
        let resetBudget = app.buttons["settings-debug-economy-budget-reset-shortcut"].exists
            ? app.buttons["settings-debug-economy-budget-reset-shortcut"]
            : app.buttons["settings-debug-economy-budget-reset"]
        XCTAssertTrue(
            resetBudget.waitForExistence(timeout: 12),
            "Settings did not expose the UI-test economy budget reset shortcut."
        )
        tapWhenHittable(resetBudget, timeout: 8)
    }

    @MainActor
    private func openCoconutShopFromOasis(in app: XCUIApplication, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let oasisTab = app.buttons["home-tab-oasis"]
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 20), "Oasis tab did not appear before opening Coconut Shop.")
        tapWhenHittable(oasisTab, timeout: 8)

        let shopTool = app.buttons["oasis-bento-shop"]
        XCTAssertTrue(shopTool.waitForExistence(timeout: 14), "Oasis did not expose the Coconut Shop entry.")
        XCTAssertTrue(
            tapWhenFrameReady(shopTool, timeout: 8),
            "Oasis Coconut Shop entry existed but was not frame-ready."
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["coconut-shop-screen"].waitForExistence(timeout: 18),
            "Coconut Shop did not open from the Oasis shop entry."
        )
    }

    @MainActor
    private func openFamilyWeeklyReportFromDebugSettings(in app: XCUIApplication, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        openSettingsFromHomeChrome(in: app)

        let reportShortcut = app.buttons["settings-debug-family-weekly-report-shortcut"]
        XCTAssertTrue(
            reportShortcut.waitForExistence(timeout: 12),
            "Settings did not expose the UI-test Weekly Report shortcut."
        )
        tapWhenHittable(reportShortcut, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["family-weekly-report-screen"].waitForExistence(timeout: 18),
            "Weekly Report did not open from the Settings UI-test shortcut."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["family-weekly-report-member-contribution-card"].waitForExistence(timeout: 12),
            "Weekly Report did not expose the caregiver summary card."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["family-weekly-report-recent-activity-card"].waitForExistence(timeout: 12),
            "Weekly Report did not expose the recent activity card."
        )
    }

    @MainActor
    private func unlockRewardTierForUITests(in app: XCUIApplication, humanName: String) {
        openSettingsFromHomeChrome(in: app)
        let rewardTier = app.buttons["settings-debug-reward-tier-shortcut"].exists
            ? app.buttons["settings-debug-reward-tier-shortcut"]
            : app.buttons["settings-debug-reward-tier"]
        XCTAssertTrue(
            rewardTier.waitForExistence(timeout: 12),
            "Settings did not expose the UI-test reward-tier shortcut."
        )
        tapWhenHittable(rewardTier, timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
    }

    @MainActor
    private func assertWeeklyReportAvoidsCompetitionCopy(in app: XCUIApplication, context: String) {
        let forbiddenCopy = [
            "Care contribution ranking",
            "care contribution ranking",
            "leaderboard",
            "competition",
            "who did more",
            "cared the most",
            "Most care",
            "Star of the week",
            "照护贡献排行",
            "排行榜",
            "悬赏榜",
            "竞赛",
            "比赛",
            "谁做得更多",
            "照顾最多",
            "本周之星"
        ]
        for text in forbiddenCopy {
            let matchingText = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
                .firstMatch
            XCTAssertFalse(
                matchingText.exists,
                "\(context) showed weekly-report competition copy: \(text)"
            )
        }
    }

    private func assertSingleMemberShapeHasNoDeficitCopy(in app: XCUIApplication, context: String) {
        let forbiddenCopy = [
            "Add another family member",
            "add another family member",
            "more family members",
            "more humans",
            "one person is not enough",
            "not enough family",
            "添加更多人类",
            "添加更多家庭成员",
            "更多家庭成员",
            "一个人不够",
            "解锁家庭感"
        ]
        for text in forbiddenCopy {
            let matchingText = app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
                .firstMatch
            XCTAssertFalse(
                matchingText.exists,
                "\(context) showed single-member deficit copy: \(text)"
            )
        }
    }

    @MainActor
    private func openHumanDetailFromHome(in app: XCUIApplication, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        expandHumanCardFromHome(in: app, humanName: humanName)

        let detailAction = app.buttons["home-expanded-detail-human"]
        XCTAssertTrue(
            tapWhenSemanticallyHittable(detailAction, timeout: 8),
            "Expanded Human card did not expose a stable detail entry."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["human-detail-screen"].waitForExistence(timeout: 14),
            "Human detail did not open from the expanded Home card."
        )
    }

    @MainActor
    private func openHumanModuleFromHome(
        _ legacyModuleIdentifier: String,
        in app: XCUIApplication,
        humanName: String
    ) {
        switch legacyModuleIdentifier {
        case "feature-hub-body-weight":
            openHumanQuickActionDetailFromHome("humanWeight", in: app, humanName: humanName)
        case "feature-hub-body-workout":
            openHumanQuickActionDetailFromHome("humanWorkout", in: app, humanName: humanName)
        case "feature-hub-care-medication":
            openHumanQuickActionDetailFromHome("humanMedication", in: app, humanName: humanName)
        case "feature-hub-money-expense":
            openHumanQuickActionDetailFromHome("humanExpense", in: app, humanName: humanName)
        case "feature-hub-money-notes":
            openHumanQuickActionDetailFromHome("humanNote", in: app, humanName: humanName)
        case "feature-hub-body-metrics":
            openHumanDetailModule("human-detail-health-metrics-action", in: app, humanName: humanName)
        case "feature-hub-body-report":
            openHumanDetailModule("human-detail-health-report-action", in: app, humanName: humanName)
        case "feature-hub-money-wishlist":
            openHumanDetailModule("human-detail-wishlist-action", in: app, humanName: humanName)
        case "feature-hub-care-basic", "feature-hub-account-profile":
            openHumanDetailFromHome(in: app, humanName: humanName)
        default:
            XCTFail("No current Human UI route is mapped for \(legacyModuleIdentifier).")
        }
    }

    @MainActor
    private func openHumanDetailModule(
        _ actionIdentifier: String,
        in app: XCUIApplication,
        humanName: String
    ) {
        openHumanDetailFromHome(in: app, humanName: humanName)
        let action = app.buttons[actionIdentifier]
        scrollToElement(action, in: app, maxSwipes: 8)
        XCTAssertTrue(
            waitForFrameReady(action, timeout: 10),
            "Human detail did not expose the current module action: \(actionIdentifier)"
        )
        XCTAssertTrue(
            tapWhenSemanticallyHittable(action, timeout: 8),
            "Human detail module action did not become semantically tappable: \(actionIdentifier)"
        )
    }

    @MainActor
    private func openHumanQuickActionDetailFromHome(
        _ actionType: String,
        in app: XCUIApplication,
        humanName: String
    ) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        expandHumanCardFromHome(in: app, humanName: humanName)

        let action = app.buttons["home-quick-action-\(actionType)"]
        XCTAssertTrue(
            tapWhenSemanticallyHittable(action, timeout: 8),
            "Expanded Human card did not expose the current \(actionType) quick action."
        )

        let detailAction = homeQuickActionMenuButton(in: app, actionType: actionType, suffix: "detail")
        XCTAssertTrue(
            waitForFrameReady(detailAction, timeout: 8),
            "Human quick action did not expose its detail branch: \(actionType)"
        )
        XCTAssertTrue(
            tapWhenSemanticallyHittable(detailAction, timeout: 8),
            "Human quick action detail branch did not become semantically tappable: \(actionType)"
        )
    }

    @MainActor
    private func expandHumanCardFromHome(in app: XCUIApplication, humanName: String) {
        let detailButton = app.buttons["home-expanded-detail-human"]
        let expandedMarkers = [
            detailButton,
            app.buttons["home-quick-action-humanWeight"],
            app.buttons["home-quick-action-humanMedication"],
            app.buttons["home-quick-action-humanExpense"]
        ]
        if expandedMarkers.contains(where: \.exists) { return }

        let humanCard = app.buttons["home-card-human-\(humanName)"]
        let humanCardByLabel = app.buttons.matching(NSPredicate(format: "label == %@", humanName)).firstMatch
        let targetCard = humanCard.exists ? humanCard : humanCardByLabel
        XCTAssertTrue(targetCard.waitForExistence(timeout: 20), "Human home card did not appear before opening its routes.")
        XCTAssertTrue(
            tapWhenSemanticallyHittable(targetCard, timeout: 8),
            "Human home card existed but did not become semantically tappable."
        )

        let didExpand = waitUntil(timeout: 12) {
            expandedMarkers.contains(where: \.exists)
        }
        XCTAssertTrue(didExpand, "Human home card did not finish expanding before opening its routes.")
    }

    @MainActor
    private func collapseExpandedPetCardIfNeeded(in app: XCUIApplication) {
        let petExpandedMarkers = [
            app.buttons["home-expanded-detail-pet"],
            app.buttons["home-expanded-shortcut-allFeatures"],
            app.buttons["home-quick-action-feed"],
            app.buttons["home-quick-action-water"],
            app.buttons["home-quick-action-potty"],
            app.buttons["home-quick-action-play"],
            app.buttons["home-quick-action-walk"]
        ]
        guard petExpandedMarkers.contains(where: \.exists) else { return }

        let collapseAction = app.buttons["home-expanded-collapse-pet"]
        XCTAssertTrue(
            collapseAction.waitForExistence(timeout: 8),
            "Expanded pet card did not expose its semantic collapse action."
        )
        tapWhenHittable(collapseAction, timeout: 8)

        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.buttons["home-expanded-detail-pet"].exists &&
                    !app.buttons["home-expanded-shortcut-allFeatures"].exists &&
                    !app.buttons["home-quick-action-feed"].exists &&
                    !app.buttons["home-quick-action-water"].exists &&
                    !app.buttons["home-quick-action-potty"].exists &&
                    !app.buttons["home-quick-action-play"].exists &&
                    !app.buttons["home-quick-action-walk"].exists
            },
            "Expanded pet card did not collapse before opening another Home tab."
        )
    }

    @MainActor
    private func collapseExpandedHumanCardIfNeeded(in app: XCUIApplication, humanName: String) {
        let expandedMarkers = [
            app.buttons["home-expanded-detail-human"],
            app.buttons["home-expanded-shortcut-humanAllFeatures"],
            app.buttons["home-quick-action-humanWeight"],
            app.buttons["home-quick-action-humanMedication"],
            app.buttons["home-quick-action-humanExpense"]
        ]
        guard expandedMarkers.contains(where: \.exists) else { return }

        let humanCard = app.buttons["home-card-human-\(humanName)"]
        let humanCardByLabel = app.buttons.matching(NSPredicate(format: "label == %@", humanName)).firstMatch
        let targetCard = humanCard.exists ? humanCard : humanCardByLabel
        guard tapWhenFrameReady(targetCard, timeout: 5) else { return }

        _ = waitUntil(timeout: 8) {
            !app.buttons["home-expanded-detail-human"].exists &&
                !app.buttons["home-expanded-shortcut-humanAllFeatures"].exists &&
                !app.buttons["home-quick-action-humanWeight"].exists &&
                !app.buttons["home-quick-action-humanMedication"].exists &&
                !app.buttons["home-quick-action-humanExpense"].exists
        }
    }

    @MainActor
    private func assertHumanModuleRouteContains(
        _ tileIdentifier: String,
        markers: [String],
        in app: XCUIApplication,
        humanName: String
    ) {
        openHumanModuleFromHome(tileIdentifier, in: app, humanName: humanName)
        assertAnyMarkerExists(markers, in: app, timeout: 14, context: tileIdentifier)
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func assertHumanHomeQuickActionOpensSheet(
        actionIdentifier: String,
        sheetIdentifier: String,
        in app: XCUIApplication,
        humanName: String
    ) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let action = app.buttons[actionIdentifier]
        if !waitForFrameReady(action, timeout: 1) {
            expandHumanCardFromHome(in: app, humanName: humanName)
        }

        XCTAssertTrue(
            waitForFrameReady(action, timeout: 10),
            "Expanded human card did not expose a stable quick action: \(actionIdentifier)"
        )
        XCTAssertTrue(
            tapWhenSemanticallyHittable(action, timeout: 8),
            "Human home quick action did not become semantically tappable: \(actionIdentifier)"
        )

        let sheetMarker = app.descendants(matching: .any)[sheetIdentifier]
        if !sheetMarker.waitForExistence(timeout: 1.5) {
            let actionType = actionIdentifier.replacingOccurrences(of: "home-quick-action-", with: "")
            let quickMenuAction = app.buttons
                .matching(NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@ AND identifier ENDSWITH %@",
                    "home-quick-action-menu-",
                    actionType,
                    "-quick"
                ))
                .firstMatch
            XCTAssertTrue(
                quickMenuAction.waitForExistence(timeout: 8),
                "Human home quick action \(actionIdentifier) opened neither the expected sheet nor its inline quick menu."
            )
            XCTAssertTrue(
                tapWhenSemanticallyHittable(quickMenuAction, timeout: 8),
                "Human quick menu branch did not become semantically tappable: \(actionIdentifier)"
            )
        }

        XCTAssertTrue(
            sheetMarker.waitForExistence(timeout: 10),
            "Human home quick action \(actionIdentifier) did not open expected sheet marker: \(sheetIdentifier)"
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanWeightFromCurrentUI(in app: XCUIApplication, humanName: String) {
        openHumanModuleFromHome("feature-hub-body-weight", in: app, humanName: humanName)
        tapWhenHittable(app.buttons["human-weight-add-action"], timeout: 8)

        let weightEntrySheet = app.descendants(matching: .any)["generic-weight-entry-sheet-human"]
        XCTAssertTrue(
            weightEntrySheet.waitForExistence(timeout: 10),
            "Human quick weight sheet did not open."
        )
        tapWhenHittable(app.buttons["embedded-decimal-keypad-key-7"], timeout: 8)
        tapWhenHittable(app.buttons["embedded-decimal-keypad-key-0"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 4) {
                app.staticTexts["generic-weight-entry-value-human"].label.contains("70") ||
                    app.descendants(matching: .any)["generic-weight-entry-value-human"].label.contains("70")
            },
            "Human weight keypad input did not update the displayed value to 70."
        )
        tapWhenHittable(app.buttons["generic-weight-entry-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !weightEntrySheet.exists
            },
            "Human weight entry sheet did not dismiss after saving."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanExpenseFromCurrentUI(in app: XCUIApplication, humanName: String, note: String) {
        openHumanModuleFromHome("feature-hub-money-expense", in: app, humanName: humanName)
        tapWhenHittable(app.buttons["human-expense-add-action"], timeout: 8)

        let expenseSheet = app.descendants(matching: .any)["quick-human-expense-sheet"]
        XCTAssertTrue(
            expenseSheet.waitForExistence(timeout: 10),
            "Human quick expense sheet did not open."
        )
        tapWhenHittable(app.buttons["quick-human-expense-amount-0"], timeout: 8)
        typeText(note, intoTextField: "quick-human-expense-note-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["quick-human-expense-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !expenseSheet.exists
            },
            "Human expense sheet did not dismiss after saving."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanMedicationFromCurrentUI(in app: XCUIApplication, humanName: String, medicationName: String) {
        openHumanModuleFromHome("feature-hub-care-medication", in: app, humanName: humanName)
        tapWhenHittable(app.buttons["human-medication-add-action"], timeout: 8)

        XCTAssertTrue(
            app.staticTexts["add-human-medication-sheet"].waitForExistence(timeout: 10),
            "Human medication add sheet did not open."
        )
        typeText(medicationName, intoTextField: "add-human-medication-name-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["add-human-medication-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !app.staticTexts["add-human-medication-sheet"].exists
            },
            "Human medication add sheet did not dismiss after saving."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanNoteFromCurrentUI(in app: XCUIApplication, humanName: String, note: String) {
        openHumanModuleFromHome("feature-hub-money-notes", in: app, humanName: humanName)
        tapWhenHittable(app.buttons["human-note-add-action"], timeout: 8)

        let noteSheet = app.descendants(matching: .any)["quick-human-note-sheet"]
        XCTAssertTrue(
            noteSheet.waitForExistence(timeout: 10),
            "Human quick note sheet did not open."
        )
        typeText(note, intoTextView: "quick-human-note-input", in: app)
        tapWhenHittable(app.buttons["quick-human-note-save-action"], timeout: 8)
        assertAnyMarkerExists([note], in: app, timeout: 14, context: "human note save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanHealthMetricFromCurrentUI(in app: XCUIApplication, humanName: String) {
        openHumanModuleFromHome("feature-hub-body-metrics", in: app, humanName: humanName)

        tapWhenHittable(app.buttons["human-health-metric-starter-record-action"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["human-health-metric-entry-sheet-tsh"].waitForExistence(timeout: 10),
            "Human health metric entry sheet did not open."
        )
        tapWhenHittable(app.buttons["embedded-decimal-keypad-key-2"], timeout: 8)
        tapWhenHittable(app.buttons["human-health-metric-entry-save-action"], timeout: 8)
        assertAnyMarkerExists(["2.00 mIU/L", "2.00"], in: app, timeout: 18, context: "human health metric save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanWorkoutFromCurrentUI(in app: XCUIApplication, humanName: String, note: String) {
        openHumanWorkoutCardFromHomeProfile(in: app, humanName: humanName)
        tapWhenHittable(app.buttons["human-workout-add-action"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["add-human-workout-sheet"].waitForExistence(timeout: 10),
            "Human workout add sheet did not open."
        )
        let durationIncrement = app.buttons["add-human-workout-duration-increment"]
        for _ in 0 ..< 9 {
            tapWhenHittable(durationIncrement, timeout: 4)
        }
        typeText(note, intoTextView: "add-human-workout-notes-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["add-human-workout-save-action"], timeout: 8)
        assertAnyMarkerExists(["45 min", "45 分钟"], in: app, timeout: 18, context: "human workout save")
        closeHumanProfileToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func openHumanWorkoutCardFromHomeProfile(in app: XCUIApplication, humanName: String) {
        openHumanModuleFromHome("feature-hub-body-workout", in: app, humanName: humanName)
        XCTAssertTrue(
            app.descendants(matching: .any)["human-workout-summary-view"].waitForExistence(timeout: 14) &&
                app.buttons["human-workout-add-action"].waitForExistence(timeout: 8),
            "The current Human workout detail route did not open with its add action."
        )
    }

    @MainActor
    private func saveHumanHealthReportFromCurrentUI(
        in app: XCUIApplication,
        humanName: String,
        hospital: String,
        summary: String
    ) {
        openHumanModuleFromHome("feature-hub-body-report", in: app, humanName: humanName)
        tapWhenHittable(app.buttons["human-health-report-add-action"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["add-human-health-report-sheet"].waitForExistence(timeout: 10),
            "Human health report add sheet did not open."
        )
        typeText(hospital, intoTextField: "add-human-health-report-hospital-input", in: app)
        dismissKeyboardIfPresent(in: app, returnKeyIsSafe: true)
        XCTAssertTrue(
            waitUntil(timeout: 4) { !app.keyboards.firstMatch.exists },
            "Human health report hospital keyboard did not dismiss."
        )
        typeText(summary, intoTextView: "add-human-health-report-summary-input", in: app)
        // TextEditor Return inserts a newline instead of resigning focus. A
        // visible keyboard is not a save precondition; scroll the real save
        // action into view and submit through the product UI below.
        dismissKeyboardIfPresent(in: app)
        let saveAction = app.buttons["add-human-health-report-save-action"]
        scrollToElement(saveAction, in: app, maxSwipes: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                saveAction.exists && saveAction.isEnabled && hasVisibleFrame(saveAction, in: app)
            },
            "Human health report save action did not enter the visible viewport."
        )
        if saveAction.isHittable {
            saveAction.tap()
        } else {
            saveAction.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        assertAnyMarkerExists([hospital], in: app, timeout: 18, context: "human health report save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func assertHumanExtendedModuleOperationsPersistAfterRelaunch(
        in app: XCUIApplication,
        humanName: String,
        reportHospital: String,
        reportSummary: String,
        wishTitle: String
    ) {
        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openHumanModuleFromHome("feature-hub-body-metrics", in: app, humanName: humanName)
        assertAnyMarkerExists(
            ["2.00 mIU/L", "2.00"],
            in: app,
            timeout: 14,
            context: "human health metric relaunch readback"
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openHumanWorkoutCardFromHomeProfile(in: app, humanName: humanName)
        assertAnyMarkerExists(
            ["45 min", "45 分钟"],
            in: app,
            timeout: 14,
            context: "human workout relaunch readback"
        )
        closeHumanProfileToHome(in: app, humanName: humanName)

        openHumanModuleFromHome("feature-hub-body-report", in: app, humanName: humanName)
        assertAnyMarkerExists(
            [reportHospital],
            in: app,
            timeout: 14,
            context: "human health report hospital relaunch readback"
        )
        assertAnyMarkerExists(
            [reportSummary],
            in: app,
            timeout: 14,
            context: "human health report summary relaunch readback"
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openHumanModuleFromHome("feature-hub-money-wishlist", in: app, humanName: humanName)
        assertAnyMarkerExists(
            [wishTitle],
            in: app,
            timeout: 14,
            context: "human wishlist relaunch readback"
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func deleteHumanHealthMetricFromCurrentUI(in app: XCUIApplication, humanName: String) {
        openHumanModuleFromHome("feature-hub-body-metrics", in: app, humanName: humanName)
        let metricCard = app.buttons["human-health-metric-chart-tsh"]
        scrollTowardElement(metricCard, in: app, maxSwipes: 5)
        XCTAssertTrue(metricCard.waitForExistence(timeout: 10), "Human health metric card did not appear before delete.")
        tapWhenHittable(metricCard, timeout: 8)

        let detailScreen = app.descendants(matching: .any)["human-health-metric-detail-tsh"]
        XCTAssertTrue(detailScreen.waitForExistence(timeout: 10), "Human health metric detail did not open before delete.")

        let deleteAction = app.buttons["human-health-metric-delete-action"]
        scrollTowardElement(deleteAction, in: app, maxSwipes: 8)
        XCTAssertTrue(
            deleteAction.waitForExistence(timeout: 12),
            "Human health metric detail did not expose a delete action."
        )
        tapWhenHittable(deleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !deleteAction.exists &&
                    containsAnyMarker(["No history in the selected unit", "当前单位还没有历史记录"], in: app)
            },
            "Deleting the human health metric did not remove the visible history row."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func deleteHumanWorkoutFromProfile(in app: XCUIApplication, humanName: String) {
        openHumanWorkoutCardFromHomeProfile(in: app, humanName: humanName)
        let deleteActions = app.buttons.matching(identifier: "human-workout-delete-action")
        let deleteAction = deleteActions.firstMatch
        scrollToElement(deleteAction, in: app, maxSwipes: 5)
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 12), "Human workout row did not expose a delete action.")
        XCTAssertEqual(
            deleteActions.count,
            1,
            "A single workout row should expose exactly one semantic delete control."
        )
        tapWhenHittable(deleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                deleteActions.count == 0 &&
                    containsAnyMarker(["0", "Manual", "手动记录"], in: app)
            },
            "Deleting the human workout did not remove the visible workout row."
        )
        closeHumanProfileToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func deleteHumanHealthReportFromCurrentUI(
        in app: XCUIApplication,
        humanName: String,
        hospital: String,
        summary: String
    ) {
        openHumanModuleFromHome("feature-hub-body-report", in: app, humanName: humanName)
        assertAnyMarkerExists([hospital, summary], in: app, timeout: 14, context: "human health report before delete")

        let reportRow = app.buttons["human-health-report-row"].firstMatch
        XCTAssertTrue(reportRow.waitForExistence(timeout: 10), "Human health report row did not appear before delete.")
        tapWhenHittable(reportRow, timeout: 8)

        let deleteAction = app.buttons["add-human-health-report-delete-action"]
        scrollToElement(deleteAction, in: app, maxSwipes: 5)
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 10), "Human health report edit sheet did not expose delete.")
        tapWhenHittable(deleteAction, timeout: 8)

        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !containsAnyMarker([hospital, summary], in: app) &&
                    containsAnyMarker(["No health reports yet", "还没有检测报告"], in: app)
            },
            "Deleting the human health report did not remove the visible report row."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func deleteHumanNoteFromCurrentUI(in app: XCUIApplication, humanName: String, note: String) {
        openHumanModuleFromHome("feature-hub-money-notes", in: app, humanName: humanName)
        assertAnyMarkerExists([note], in: app, timeout: 14, context: "human note before delete")

        let deleteAction = app.buttons["human-note-delete-action"].firstMatch
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 10), "Human note row did not expose a delete action.")
        tapWhenHittable(deleteAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 12) {
                !containsAnyMarker([note], in: app)
            },
            "Deleting the human note did not remove the visible note row."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func assertHumanExtendedModuleDeletesStayDeletedAfterRelaunch(
        in app: XCUIApplication,
        humanName: String,
        reportHospital: String,
        reportSummary: String,
        noteText: String
    ) {
        relaunchPreservingPersistentState(in: app)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openHumanModuleFromHome("feature-hub-body-metrics", in: app, humanName: humanName)
        XCTAssertFalse(
            app.buttons["human-health-metric-chart-tsh"].waitForExistence(timeout: 2),
            "Deleted human health metric returned after relaunch."
        )
        XCTAssertTrue(
            app.buttons["human-health-metric-starter-record-action"].waitForExistence(timeout: 8),
            "Human health metrics did not return to the empty starter state after relaunch."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openHumanWorkoutCardFromHomeProfile(in: app, humanName: humanName)
        let workoutDeleteActions = app.buttons.matching(identifier: "human-workout-delete-action")
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                workoutDeleteActions.count == 0 &&
                    containsAnyMarker(
                        [
                            "0 activities", "0 项活动", "0 Aktivitäten",
                            "No workouts yet", "还没有运动记录", "Noch keine Trainings",
                            "No readable recent workouts", "最近没有可读取的运动记录",
                            "Keine lesbaren letzten Trainings",
                            "No manual Ohana workouts yet", "还没有 Ohana 手动运动记录",
                            "Noch keine manuellen Ohana-Trainings"
                        ],
                        in: app
                    )
            },
            "Deleted human workout returned after relaunch or the workout route did not reach a valid empty state."
        )
        closeHumanProfileToHome(in: app, humanName: humanName)

        openHumanModuleFromHome("feature-hub-body-report", in: app, humanName: humanName)
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !containsAnyMarker([reportHospital, reportSummary], in: app) &&
                    containsAnyMarker(["No health reports yet", "还没有检测报告"], in: app)
            },
            "Deleted human health report returned after relaunch."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openHumanModuleFromHome("feature-hub-money-notes", in: app, humanName: humanName)
        assertAnyMarkerExists(
            ["No notes yet", "还没有备注"],
            in: app,
            timeout: 14,
            context: "human note empty state after relaunch"
        )
        XCTAssertFalse(
            waitUntil(timeout: 2) { containsAnyMarker([noteText], in: app) },
            "Deleted human note returned after relaunch."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanWishlistFromCurrentUI(in app: XCUIApplication, humanName: String, title: String) {
        openHumanModuleFromHome("feature-hub-money-wishlist", in: app, humanName: humanName)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(app.buttons["human-wishlist-add-action"], timeout: 8),
            "Human wishlist add action did not become semantically tappable."
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["add-human-wishlist-sheet"].waitForExistence(timeout: 8),
            "Human wishlist add sheet did not open."
        )
        typeText(title, intoTextField: "add-human-wishlist-title-input", in: app)
        dismissKeyboardIfPresent(in: app)
        XCTAssertTrue(
            tapWhenSemanticallyHittable(app.buttons["add-human-wishlist-save-action"], timeout: 8),
            "Human wishlist save action did not become semantically tappable."
        )
        assertAnyMarkerExists([title], in: app, timeout: 14, context: "human wishlist save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func redeemHumanWishlistFromCurrentUI(
        in app: XCUIApplication,
        humanName: String,
        title: String,
        startingBalance: Int,
        expectedBalance: Int
    ) {
        openHumanModuleFromHome("feature-hub-money-wishlist", in: app, humanName: humanName)
        assertAnyMarkerExists([title], in: app, timeout: 14, context: "human wishlist pending wish")
        XCTAssertTrue(
            app.staticTexts["\(startingBalance)🥥"].waitForExistence(timeout: 10),
            "Human wishlist did not show its explicit seeded wallet balance before redeeming."
        )

        let redeem = app.buttons["human-wishlist-redeem-action"]
        XCTAssertTrue(
            waitUntil(timeout: 10) {
                redeem.exists && redeem.isEnabled && redeem.isHittable
            },
            "Human wishlist redeem action did not become available after explicitly seeding the human wallet."
        )
        XCTAssertTrue(
            tapWhenSemanticallyHittable(redeem, timeout: 8),
            "Human wishlist redeem action did not remain semantically tappable."
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["human-wishlist-redeemed-state"].waitForExistence(timeout: 14),
            "Human wishlist did not move the item into the redeemed state after spending coconuts."
        )
        XCTAssertTrue(
            app.staticTexts["\(expectedBalance)🥥"].waitForExistence(timeout: 12),
            "Redeeming the wishlist item did not spend exactly 10 coconuts from the human wallet."
        )
        assertAnyMarkerExists(["Redeemed", "已兑换", title], in: app, timeout: 8, context: "human wishlist redeem")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func ensureHomeSurfaceVisible(in app: XCUIApplication, humanName: String) {
        let homeTab = app.buttons["home-tab-home"]
        if homeTab.waitForExistence(timeout: 8) {
            if homeTab.isHittable {
                tapWhenHittable(homeTab, timeout: 5)
            } else {
                _ = tapWhenFrameReady(homeTab, timeout: 5)
            }
        }

        let humanCard = app.buttons["home-card-human-\(humanName)"]
        let humanCardByLabel = app.buttons.matching(NSPredicate(format: "label == %@", humanName)).firstMatch
        let anyPetCard = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-"))
            .firstMatch
        let didReachHome = waitUntil(timeout: 14) {
            app.state == .runningForeground &&
                (humanCard.exists ||
                    humanCardByLabel.exists ||
                    anyPetCard.exists ||
                    app.buttons["home-add-first-pet-card"].exists ||
                    app.buttons["home-add-first-pet-action"].exists)
        }
        XCTAssertTrue(didReachHome, "Home surface did not become visible before human route testing.")
    }

    @MainActor
    private func prepareExistingUserHomeDiscovery(in app: XCUIApplication) {
        _ = waitUntil(timeout: 18) {
            isPetFeatureRouteOverlayVisible(in: app) ||
                isHumanFeatureRouteOverlayVisible(in: app) ||
                app.textFields["onboarding-human-name-input"].exists ||
                app.buttons["home-tab-home"].exists
        }

        for _ in 0 ..< 6 {
            if isPetFeatureRouteOverlayVisible(in: app) || isHumanFeatureRouteOverlayVisible(in: app) {
                dismissOneHumanRouteLayer(in: app)
                _ = waitUntil(timeout: 4) {
                    !isPetFeatureRouteOverlayVisible(in: app) &&
                        !isHumanFeatureRouteOverlayVisible(in: app)
                }
                continue
            }

            if app.textFields["onboarding-human-name-input"].exists {
                return
            }

            let homeTab = app.buttons["home-tab-home"]
            if homeTab.exists && homeTab.isEnabled && homeTab.isHittable {
                homeTab.tap()
                _ = waitUntil(timeout: 4) {
                    app.buttons
                        .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-human-"))
                        .firstMatch.exists ||
                        app.buttons
                            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-"))
                            .firstMatch.exists ||
                        app.buttons["home-add-first-pet-card"].exists
                }
            }

            let hasHomeCard = app.buttons
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-human-"))
                .firstMatch.exists ||
                app.buttons
                    .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-"))
                    .firstMatch.exists
            if hasHomeCard || app.textFields["onboarding-human-name-input"].exists {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        }
    }

    @MainActor
    private func firstExistingHomeHumanName(in app: XCUIApplication) -> String? {
        _ = waitUntil(timeout: 18) {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-human-")).firstMatch.exists ||
                app.buttons["home-add-first-pet-card"].exists ||
                app.textFields["member-name-input"].exists
        }

        let humanCard = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-human-"))
            .firstMatch
        guard humanCard.exists else { return nil }
        return humanCard.identifier.replacingOccurrences(of: "home-card-human-", with: "")
    }

    @MainActor
    private func firstExistingHomePetName(in app: XCUIApplication) -> String? {
        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists && homeTab.isHittable {
            tapWhenHittable(homeTab, timeout: 4)
        }

        let petCard = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-pet-"))
            .firstMatch
        guard petCard.waitForExistence(timeout: 10) else { return nil }
        return petCard.identifier.replacingOccurrences(of: "home-card-pet-", with: "")
    }

    @MainActor
    private func isOnboardingEntryAvailable(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            app.textFields["onboarding-human-name-input"].exists ||
                app.buttons["onboarding-create-pet-now"].exists ||
                app.textFields["member-name-input"].exists
        }
    }

    @MainActor
    private func seedReusablePetBaselineByResettingEmptyState(in app: XCUIApplication) -> String {
        app.terminate()
        app.launchArguments.append("-OHANA_RESET_PERSISTENT_STATE")
        app.launch()
        chooseInitialExperienceIfNeeded("standard", in: app)
        let humanName = createFirstHuman(from: app)
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        return humanName
    }

    @MainActor
    private func openFeedDetailFromHome(
        in app: XCUIApplication,
        petName: String,
        usingDetailMenuWhenAvailable: Bool = false
    ) {
        ensureHomeFeedQuickActionVisible(in: app, petName: petName)
        tapHomeFeedQuickAction(in: app, timeout: 8)

        let detailButton = homeQuickActionMenuButton(in: app, actionType: "feed", suffix: "detail")
        if usingDetailMenuWhenAvailable || detailButton.waitForExistence(timeout: 1.5) {
            XCTAssertTrue(detailButton.waitForExistence(timeout: 8), "Feed detail menu action did not appear.")
            tapWhenHittable(detailButton, timeout: 8)
        }

        XCTAssertTrue(
            waitForQuickFeedHome(in: app, timeout: 20),
            "Quick Feed detail did not open from the home Feed action."
        )
    }

    @MainActor
    private func ensureHomeFeedQuickActionVisible(in app: XCUIApplication, petName: String) {
        let feedAction = app.buttons["home-quick-action-feed"]
        if feedAction.waitForExistence(timeout: 8) { return }

        let petCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(petCard.waitForExistence(timeout: 20), "Pet home card did not appear before opening Feed.")
        tapWhenHittable(petCard, timeout: 8)
        XCTAssertTrue(feedAction.waitForExistence(timeout: 14), "Expanded pet card did not expose the Feed quick action.")
    }

    @MainActor
    private func assertPetHomeQuickActionOpensDetail(
        actionType: String,
        detailIdentifier: String,
        in app: XCUIApplication,
        petName: String,
        humanName: String
    ) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomePetQuickActionVisible(actionType: actionType, in: app, petName: petName)

        let action = app.buttons["home-quick-action-\(actionType)"]
        XCTAssertTrue(
            tapWhenFrameReady(action, timeout: 8),
            "Pet home quick action did not have a tappable frame: \(actionType)"
        )

        let detailAction = homeQuickActionMenuButton(in: app, actionType: actionType, suffix: "detail")
        XCTAssertTrue(
            detailAction.waitForExistence(timeout: 8),
            "Pet home quick action did not expose the detail route menu: \(actionType)"
        )
        tapWhenHittable(detailAction, timeout: 8)

        let detailRoot = app.descendants(matching: .any)[detailIdentifier]
        XCTAssertTrue(
            detailRoot.waitForExistence(timeout: 18),
            "Pet quick action detail route did not open: \(detailIdentifier)"
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func assertPetHomeQuickActionStaysResponsive(
        actionType: String,
        in app: XCUIApplication,
        petName: String,
        humanName: String
    ) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomePetQuickActionVisible(actionType: actionType, in: app, petName: petName)

        let action = app.buttons["home-quick-action-\(actionType)"]
        XCTAssertTrue(
            tapWhenFrameReady(action, timeout: 8),
            "Pet home quick action did not have a tappable frame: \(actionType)"
        )

        let menuAction = homeQuickActionMenuButton(in: app, actionType: actionType, suffix: "quick")
        if menuAction.waitForExistence(timeout: 2) {
            tapWhenHittable(menuAction, timeout: 8)
        }

        XCTAssertTrue(
            waitUntil(timeout: 15) {
                app.state == .runningForeground &&
                    (app.buttons["home-quick-action-\(actionType)"].exists ||
                        app.buttons["home-primary-action"].exists ||
                        app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch.exists)
            },
            "Pet home quick action did not return to a responsive Home surface: \(actionType)"
        )
    }

    @MainActor
    private func ensureHomePetQuickActionVisible(actionType: String, in app: XCUIApplication, petName: String) {
        let action = app.buttons["home-quick-action-\(actionType)"]
        if action.waitForExistence(timeout: 8) { return }

        let petCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(
            petCard.waitForExistence(timeout: 20),
            "Pet home card did not appear before opening \(actionType)."
        )
        tapWhenHittable(petCard, timeout: 8)
        XCTAssertTrue(
            action.waitForExistence(timeout: 14),
            "Expanded pet card did not expose the \(actionType) quick action."
        )
    }

    @MainActor
    private func homeQuickActionMenuButton(
        in app: XCUIApplication,
        actionType: String,
        suffix: String
    ) -> XCUIElement {
        app.buttons
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "home-quick-action-menu-",
                    "-\(actionType)-\(suffix)"
                )
            )
            .firstMatch
    }

    @MainActor
    private func isHomePetQuickActionAvailable(actionType: String, in app: XCUIApplication, petName: String) -> Bool {
        let action = app.buttons["home-quick-action-\(actionType)"]
        if action.waitForExistence(timeout: 3) { return true }

        let petCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        guard petCard.waitForExistence(timeout: 8) else { return false }
        tapWhenHittable(petCard, timeout: 8)
        return action.waitForExistence(timeout: 5)
    }

    @MainActor
    private func assertPetFeatureHubRouteOpens(
        _ route: PetFeatureHubRouteExpectation,
        in app: XCUIApplication,
        petName: String,
        humanName: String
    ) {
        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)

        let tile = app.buttons[route.tileIdentifier]
        scrollToElement(tile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            tile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose tile: \(route.tileIdentifier)"
        )
        tapWhenHittable(tile, timeout: 8)

        let marker = app.descendants(matching: .any)[route.markerIdentifier]
        XCTAssertTrue(
            marker.waitForExistence(timeout: 18),
            "Pet feature hub route did not open marker \(route.markerIdentifier) from \(route.tileIdentifier)."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func openPetPottyDetailFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let pottyTile = app.buttons["feature-hub-daily-potty"]
        scrollToElement(pottyTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            pottyTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the potty tile."
        )
        tapWhenHittable(pottyTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["quick-potty-detail-sheet"].waitForExistence(timeout: 18),
            "Pet potty detail did not open from the feature hub."
        )
    }

    @MainActor
    private func openLitterSettings(in app: XCUIApplication) {
        let manageAction = app.buttons["quick-potty-litter-secondary-action"]
        scrollToElement(manageAction, in: app, maxSwipes: 6)
        XCTAssertTrue(
            manageAction.waitForExistence(timeout: 12),
            "Cat potty detail did not expose the litter settings action."
        )
        tapWhenHittable(manageAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].waitForExistence(timeout: 12),
            "Litter settings sheet did not open."
        )
    }

    @MainActor
    private func openScoopSettings(in app: XCUIApplication) {
        let manageAction = app.buttons["quick-potty-scoop-secondary-action"]
        scrollToElement(manageAction, in: app, maxSwipes: 6)
        XCTAssertTrue(
            manageAction.waitForExistence(timeout: 12),
            "Cat potty detail did not expose the scoop settings action."
        )
        tapWhenHittable(manageAction, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["quick-potty-scoop-settings-sheet"].waitForExistence(timeout: 12),
            "Scoop settings sheet did not open."
        )
    }

    @MainActor
    private func assertLitterSettingsStatus(in app: XCUIApplication, containsAny markers: [String], message: String) {
        let statusTitle = app.staticTexts["quick-potty-litter-settings-status-title"]
        XCTAssertTrue(statusTitle.waitForExistence(timeout: 10), "Litter settings status title did not appear.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                markers.contains { statusTitle.label.contains($0) }
            },
            message
        )
    }

    @MainActor
    private func assertScoopSettingsStatus(in app: XCUIApplication, containsAny markers: [String], message: String) {
        let statusTitle = app.staticTexts["quick-potty-scoop-settings-status-title"]
        XCTAssertTrue(statusTitle.waitForExistence(timeout: 10), "Scoop settings status title did not appear.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                markers.contains { statusTitle.label.contains($0) }
            },
            message
        )
    }

    @MainActor
    private func openPetWaterDetailFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomePetQuickActionVisible(actionType: "water", in: app, petName: petName)

        let action = app.buttons["home-quick-action-water"]
        XCTAssertTrue(
            tapWhenFrameReady(action, timeout: 8),
            "Pet home water quick action did not have a tappable frame."
        )

        let detailAction = homeQuickActionMenuButton(in: app, actionType: "water", suffix: "detail")
        if detailAction.waitForExistence(timeout: 2) {
            tapWhenHittable(detailAction, timeout: 8)
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["quick-water-detail-sheet"].waitForExistence(timeout: 18),
            "Pet water detail did not open from the Home quick action."
        )
    }

    @MainActor
    private func startWalkFromHomeQuickAction(in app: XCUIApplication, petName: String) {
        ensureHomePetQuickActionVisible(actionType: "walk", in: app, petName: petName)

        let action = app.buttons["home-quick-action-walk"]
        XCTAssertTrue(
            tapWhenFrameReady(action, timeout: 8),
            "Pet home walk quick action did not expose a stable touch frame."
        )
        let quickStart = homeQuickActionMenuButton(in: app, actionType: "walk", suffix: "quick")
        if quickStart.waitForExistence(timeout: 3) {
            XCTAssertTrue(
                tapWhenFrameReady(quickStart, timeout: 8),
                "Pet home walk quick-start menu did not expose a stable touch frame."
            )
        }

        let exposedWalkControls = app.buttons["walk-tracking-stop-action"].waitForExistence(timeout: 6) ||
            app.descendants(matching: .any)["global-walk-bubble"].waitForExistence(timeout: 10)
        XCTAssertTrue(
            exposedWalkControls,
            "Pet home walk quick action did not expose embedded or global active walk controls."
        )
    }

    @MainActor
    private func stopWalkFromVisibleHomeControls(in app: XCUIApplication, petName: String) {
        let embeddedStop = app.buttons["walk-tracking-stop-action"]
        if embeddedStop.waitForExistence(timeout: 3) {
            tapWhenHittable(embeddedStop, timeout: 8)
            XCTAssertTrue(
                app.staticTexts["walk-tracking-summary-distance-value"].waitForExistence(timeout: 18),
                "Embedded walk summary did not expose a distance readback after stop."
            )
            tapWhenHittable(app.buttons["walk-tracking-summary-close-action"], timeout: 8)
        } else {
            let bubble = app.descendants(matching: .any)["global-walk-bubble"]
            XCTAssertTrue(
                tapWhenFrameReady(bubble, timeout: 12),
                "Started walk did not expose a tappable global walk fallback bubble."
            )
            let globalStop = app.buttons["global-walk-stop-action"]
            XCTAssertTrue(
                globalStop.waitForExistence(timeout: 10),
                "Global walk fallback did not expose the stop action."
            )
            tapWhenHittable(globalStop, timeout: 8)
            XCTAssertTrue(
                app.descendants(matching: .any)["global-walk-summary-card"].waitForExistence(timeout: 12),
                "Stopping the global walk fallback did not present the summary card."
            )
            tapWhenHittable(app.buttons["global-walk-summary-close-action"], timeout: 8)
        }

        XCTAssertTrue(
            waitUntil(timeout: 14) {
                app.buttons["home-card-pet-\(petName)"].exists || app.buttons["home-primary-action"].exists
            },
            "Closing the walk summary did not return to the Home pet card."
        )
    }

    @MainActor
    private func openPetWalkSummaryFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let walkTile = app.buttons["feature-hub-daily-walk"]
        scrollToElement(walkTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            walkTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the walk tile."
        )
        tapWhenHittable(walkTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["walk-summary-sheet"].waitForExistence(timeout: 18),
            "Pet walk summary did not open from the feature hub."
        )
    }

    @MainActor
    private func openPetHygieneDetailFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let hygieneTile = app.buttons["feature-hub-daily-hygiene"]
        scrollToElement(hygieneTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            hygieneTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the hygiene tile."
        )
        tapWhenHittable(hygieneTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-hygiene-detail-screen"].waitForExistence(timeout: 18),
            "Pet hygiene detail did not open from the feature hub."
        )
    }

    @MainActor
    private func openPetHealthDetailFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        openPetFeatureHubFromHome(in: app, petName: petName, humanName: humanName)
        let healthTile = app.buttons["feature-hub-health-health"]
        scrollToElement(healthTile, in: app, maxSwipes: 6)
        XCTAssertTrue(
            healthTile.waitForExistence(timeout: 12),
            "Pet feature hub did not expose the health tile."
        )
        tapWhenHittable(healthTile, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-health-detail-screen"].waitForExistence(timeout: 18),
            "Pet health detail did not open from the feature hub."
        )
    }

    @MainActor
    private func openPetHealthVisitPopup(in app: XCUIApplication) {
        let visitAction = app.buttons["pet-health-tool-visit-action"]
        scrollToElement(visitAction, in: app, maxSwipes: 2)
        XCTAssertTrue(
            visitAction.waitForExistence(timeout: 8),
            "Pet health detail did not expose the current visit action."
        )
        tapWhenHittable(visitAction, timeout: 8)
    }

    @MainActor
    private func openPetFeatureHubFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let petCard = app.buttons["home-card-pet-\(petName)"]
        let fallbackPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 20) { petCard.exists || fallbackPetCard.exists },
            "Pet home card did not appear before opening the feature hub."
        )

        for _ in 0 ..< 3 where !petAllFeaturesShortcutExists(in: app) {
            let targetCard = petCard.exists ? petCard : fallbackPetCard
            if targetCard.exists {
                scrollTowardElement(targetCard, in: app, maxSwipes: 2)
                _ = tapWhenFrameReady(targetCard, offset: CGVector(dx: 0.5, dy: 0.24), timeout: 8)
            }
            if waitUntil(timeout: 3, condition: { petAllFeaturesShortcutExists(in: app) }) {
                break
            }

            if app.buttons["home-tab-home"].exists {
                tapWhenHittable(app.buttons["home-tab-home"], timeout: 5)
            }
        }
        XCTAssertTrue(
            waitUntil(timeout: 8, condition: { petAllFeaturesShortcutExists(in: app) }),
            "Expanded pet card did not expose the All Features shortcut."
        )
        let allFeaturesShortcut = petAllFeaturesShortcut(in: app)
        XCTAssertTrue(
            tapWhenFrameReady(allFeaturesShortcut, timeout: 8),
            "Expanded pet card All Features shortcut did not expose a stable touch frame."
        )

        XCTAssertTrue(
            app.buttons["feature-hub-daily-food"].waitForExistence(timeout: 14),
            "Pet feature hub did not expose the daily section."
        )
    }

    @MainActor
    private func saveManualFeedingDefault(in app: XCUIApplication) {
        let saveManualSettings = app.buttons["quick-feed-manual-settings-save"]
        if !saveManualSettings.waitForExistence(timeout: 4) {
            let primaryAction = app.buttons["quick-feed-primary-action"]
            if primaryAction.waitForExistence(timeout: 8),
               primaryAction.isEnabled,
               !primaryAction.isHittable {
                XCTAssertTrue(
                    tapWhenFrameReady(primaryAction, timeout: 8),
                    "Manual feeding primary action was not frame-ready."
                )
            } else {
                tapWhenHittable(primaryAction, timeout: 8)
            }
        }
        XCTAssertTrue(saveManualSettings.waitForExistence(timeout: 8), "Manual feeding settings did not open.")
        tapWhenHittable(saveManualSettings, timeout: 8)

        let didSave = waitUntil(timeout: 12) {
            app.state == .runningForeground &&
                isQuickFeedHomeVisible(in: app) &&
                !saveManualSettings.exists
        }
        XCTAssertTrue(didSave, "Manual feeding default save did not return to the Feed screen.")
        assertManualFeedPrimaryReady(in: app)
    }

    @MainActor
    private func addBackdatedManualFeedHistoryLog(daysAgo: Int, in app: XCUIApplication) {
        let addHistoryLog = app.buttons["quick-feed-dock-history-secondary"]
        scrollToElement(addHistoryLog, in: app, maxSwipes: 4)
        XCTAssertTrue(addHistoryLog.waitForExistence(timeout: 10), "Manual feed History card did not expose the add-log action.")
        tapWhenHittable(addHistoryLog, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["quick-feed-manual-log-date"].waitForExistence(timeout: 8),
            "Manual feed log sheet did not expose the date picker."
        )
        let dateShortcut = app.buttons["quick-feed-manual-log-date-minus-\(daysAgo)-day"]
        XCTAssertTrue(dateShortcut.waitForExistence(timeout: 8), "Manual feed log sheet did not expose the \(daysAgo)-day backdate shortcut in UI-test mode.")
        tapWhenHittable(dateShortcut, timeout: 8)
        tapWhenHittable(app.buttons["quick-feed-manual-log-save"], timeout: 8)

        XCTAssertTrue(
            waitUntil(timeout: 12) {
                isQuickFeedHomeVisible(in: app) &&
                    !app.buttons["quick-feed-manual-log-save"].exists
            },
            "Manual feed log sheet did not close after saving the \(daysAgo)-day backdated log."
        )
    }

    private func assertManualFeedHistoryRow(dayIdentifier: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "quick-feed-log-row-manualMain-\(dayIdentifier)-"))
            .firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: 15),
            "Manual feed History did not show a manualMain log row for backdated day \(dayIdentifier)."
        )
    }

    private func manualFeedHistoryDayIdentifier(daysAgo: Int) -> String {
        let targetDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let components = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    @MainActor
    private func saveManualReminderPlan(in app: XCUIApplication) {
        tapWhenHittable(app.buttons["quick-feed-mode-manualReminder"], timeout: 8)

        let savePlan = app.buttons["quick-feed-plan-save"]
        XCTAssertTrue(savePlan.waitForExistence(timeout: 10), "Manual reminder plan editor did not open.")
        tapWhenHittable(savePlan, timeout: 8)

        let didSave = waitUntil(timeout: 12) {
            app.state == .runningForeground &&
                isQuickFeedHomeVisible(in: app) &&
                !savePlan.exists
        }
        XCTAssertTrue(didSave, "Manual reminder plan save did not return to the Feed screen.")
    }

    @MainActor
    private func assertQuickFeedMode(in app: XCUIApplication, containsAny expectedTexts: [String], timeout: TimeInterval) {
        let modeTitle = app.staticTexts["quick-feed-current-mode-title"]
        let didReachMode = waitUntil(timeout: timeout) {
            modeTitle.exists && expectedTexts.contains { modeTitle.label.contains($0) }
        }
        XCTAssertTrue(
            didReachMode,
            "Quick Feed mode did not settle on one of \(expectedTexts) promptly. Current: \(modeTitle.label)"
        )
    }

    @MainActor
    private func assertManualFeedPrimaryReady(in app: XCUIApplication) {
        let primary = app.buttons["quick-feed-primary-action"]
        let didBecomeReady = waitUntil(timeout: 12) {
            primary.exists &&
                localizedContains(primary.label, anyOf: ["Feed", "喂食"]) &&
                !localizedContains(primary.label, anyOf: ["Set", "设置"])
        }
        XCTAssertTrue(
            didBecomeReady,
            "Manual Feed save did not make the primary action ready. Current: \(primary.label)"
        )
    }

    @MainActor
    private func closeFeedDetailToHome(in app: XCUIApplication, assertFeedReady: Bool = true) {
        let closeCandidates = [
            app.buttons["quick-feed-detail-close-action"],
            app.buttons["xmark"],
            app.descendants(matching: .any)["quick-feed-detail-close-action"],
            app.buttons["ohana-sheet-close-action"],
            app.buttons["Close"],
            app.buttons["关闭"]
        ]
        let didShowClose = waitUntil(timeout: 8) {
            closeCandidates.contains { $0.exists }
        }
        XCTAssertTrue(didShowClose, "Feed detail close action did not appear.")
        guard let close = closeCandidates.first(where: { $0.exists }) else {
            XCTFail("Feed detail close action did not appear.")
            return
        }
        XCTAssertTrue(
            tapWhenFrameReady(close, timeout: 8),
            "Feed detail close action was not frame-ready."
        )

        let didReturnHome = waitForFrameReady(app.buttons["home-quick-action-feed"], timeout: 15)
        XCTAssertTrue(didReturnHome, "Closing Feed detail did not return to a responsive home card.")
        if assertFeedReady {
            assertHomeFeedReady(in: app)
        }
    }

    @MainActor
    private func performHomeFeedQuickCheckIn(
        in app: XCUIApplication,
        petName: String,
        expectsAntiRepeatConfirmation: Bool
    ) {
        ensureHomeFeedQuickActionVisible(in: app, petName: petName)
        tapHomeFeedQuickAction(in: app, timeout: 8)

        let quickButton = homeQuickActionMenuButton(in: app, actionType: "feed", suffix: "quick")
        if quickButton.waitForExistence(timeout: 4) {
            tapWhenHittable(quickButton, timeout: 8)
        } else if waitForQuickFeedHome(in: app, timeout: 2) {
            let primaryAction = app.buttons["quick-feed-primary-action"]
            if primaryAction.waitForExistence(timeout: 8),
               primaryAction.isEnabled,
               !primaryAction.isHittable {
                XCTAssertTrue(
                    tapWhenFrameReady(primaryAction, timeout: 8),
                    "Quick Feed primary action was not frame-ready for the home quick check-in."
                )
            } else {
                tapWhenHittable(primaryAction, timeout: 8)
            }
        }

        if expectsAntiRepeatConfirmation {
            let confirmCandidates = [
                app.buttons["Check in anyway"],
                app.buttons["确定打卡"]
            ]
            let didShowConfirm = waitUntil(timeout: 8) {
                confirmCandidates.contains { $0.exists }
            }
            XCTAssertTrue(didShowConfirm, "Home anti-repeat confirmation did not appear.")
            guard let confirm = confirmCandidates.first(where: { $0.exists }) else {
                XCTFail("Home anti-repeat confirmation did not appear.")
                return
            }
            tapWhenHittable(confirm, timeout: 8)
        }

        let didFinish = waitUntil(timeout: 15) {
            app.state == .runningForeground &&
                (app.buttons["home-quick-action-feed"].exists || isQuickFeedHomeVisible(in: app)) &&
                !app.buttons["Check in anyway"].exists
        }
        XCTAssertTrue(didFinish, "Home Feed quick check-in did not finish with a responsive home surface.")

        if isQuickFeedHomeVisible(in: app) {
            closeFeedDetailToHome(in: app)
        }
    }

    @MainActor
    private func assertHomeFeedReady(in app: XCUIApplication) {
        let feedAction = app.buttons["home-quick-action-feed"]
        let didBecomeReady = waitUntil(timeout: 12) {
            feedAction.exists &&
                !localizedContains(feedAction.label, anyOf: ["Not set", "待设置"])
        }
        XCTAssertTrue(didBecomeReady, "Home Feed action stayed in setup state. Current: \(feedAction.label)")
    }

    @MainActor
    private func tapHomeFeedQuickAction(in app: XCUIApplication, timeout: TimeInterval) {
        let feedAction = app.buttons["home-quick-action-feed"]
        XCTAssertTrue(
            tapWhenFrameReady(feedAction, timeout: timeout),
            "Home Feed quick action did not become tappable."
        )
    }

    @MainActor
    private func openPetBasicInfoFromHome(in app: XCUIApplication, petName: String) {
        let detailAction = app.buttons["home-expanded-detail-pet"]
        if !detailAction.exists {
            let petCard = app.buttons["home-card-pet-\(petName)"]
            let fallbackPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
            XCTAssertTrue(
                waitUntil(timeout: 20) { petCard.exists || fallbackPetCard.exists },
                "Pet home card did not appear before opening basic info."
            )
            let targetCard = petCard.exists ? petCard : fallbackPetCard
            XCTAssertTrue(
                tapWhenFrameReady(targetCard, timeout: 8),
                "Pet home card did not expose a stable touch frame before opening basic info."
            )
        }

        XCTAssertTrue(
            detailAction.waitForExistence(timeout: 12),
            "Expanded pet card did not expose the current profile entry."
        )
        XCTAssertTrue(
            tapWhenFrameReady(detailAction, timeout: 8),
            "Expanded pet profile entry did not expose a stable touch frame."
        )

        let basicInfoScreen = app.descendants(matching: .any)["pet-basic-info-screen"]
        XCTAssertTrue(basicInfoScreen.waitForExistence(timeout: 12), "Pet basic info screen did not open.")
    }

    @MainActor
    private func openPetBasicInfoFromCrewRoster(in app: XCUIApplication, petName: String) {
        let rosterAction = app.buttons["home-crew-roster-action"]
        XCTAssertTrue(
            tapWhenFrameReady(rosterAction, timeout: 8),
            "Home member roster action did not become tappable for memorial profile readback."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["crew-roster-members"].waitForExistence(timeout: 12),
            "Member roster did not open for memorial profile readback."
        )

        let petCard = app.buttons["crew-roster-card-pet-\(petName)"]
        scrollToElement(petCard, in: app, maxSwipes: 6)
        XCTAssertTrue(
            petCard.waitForExistence(timeout: 12),
            "Memorial pet was missing from the member roster."
        )
        tapWhenHittable(petCard, timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 12),
            "Opening the memorial pet from the member roster did not show Basic Info."
        )
    }

    @MainActor
    private func relaunchPreservingPersistentState(
        in app: XCUIApplication,
        preservingAppLanguage: Bool = false
    ) {
        app.terminate()
        // Launch seeders and state mutators are one-shot fixtures. Replaying
        // them can overwrite the persisted state that this relaunch is meant
        // to verify, or create an impossible pending-and-claimed journey.
        let oneShotFlags: Set<String> = [
            "-OHANA_RESET_PERSISTENT_STATE",
            "-OHANA_UI_TEST_SEED_HUMAN_BASELINE",
            "-OHANA_UI_TEST_SEED_MEMBER_CARD_BASELINE",
            "-OHANA_UI_TEST_SEED_SPARSE_PET_PROFILE_BASELINE",
            "-OHANA_UI_TEST_SEED_MATURE_HOUSEHOLD_BASELINE",
            "-OHANA_UI_TEST_SEED_COCONUT_BALANCE",
            "-OHANA_UI_TEST_UNLOCK_REWARD_TIER",
            "-OHANA_UI_TEST_RESET_ECONOMY_BUDGET"
        ]
        app.launchArguments.removeAll { oneShotFlags.contains($0) }
        removeLaunchArgumentPair("-OHANA_UI_TEST_HUMAN_BASELINE_NAME", from: &app.launchArguments)
        removeLaunchArgumentPair("-OHANA_UI_TEST_PET_BASELINE_NAME", from: &app.launchArguments)
        removeLaunchArgumentPair("-OHANA_UI_TEST_PET_BASELINE_SPECIES", from: &app.launchArguments)
        removeLaunchArgumentPair("-OHANA_UI_TEST_COCONUT_BALANCE_AMOUNT", from: &app.launchArguments)
        if preservingAppLanguage {
            removeLaunchArgumentPair("-appLanguage", from: &app.launchArguments)
        }
        app.launch()
    }

    @MainActor
    private func petAllFeaturesShortcut(in app: XCUIApplication) -> XCUIElement {
        if let currentQuickAction = firstFrameReadyButton(
            identifier: "home-quick-action-allFeatures",
            in: app
        ) {
            return currentQuickAction
        }
        if let legacyExpandedShortcut = firstFrameReadyButton(
            identifier: "home-expanded-shortcut-allFeatures",
            in: app
        ) {
            return legacyExpandedShortcut
        }
        return app.buttons["home-quick-action-allFeatures"]
    }

    @MainActor
    private func petAllFeaturesShortcutExists(in app: XCUIApplication) -> Bool {
        firstFrameReadyButton(identifier: "home-quick-action-allFeatures", in: app) != nil
            || firstFrameReadyButton(identifier: "home-expanded-shortcut-allFeatures", in: app) != nil
    }

    @MainActor
    private func openPetBasicInfoEditMode(in app: XCUIApplication) {
        let editAction = app.buttons["pet-basic-info-edit-action"]
        XCTAssertTrue(
            editAction.waitForExistence(timeout: 10),
            "Pet Basic Info did not expose the edit action."
        )
        tapWhenHittable(editAction, timeout: 8)
        XCTAssertTrue(
            app.textFields["pet-basic-info-name-input"].waitForExistence(timeout: 8),
            "Pet Basic Info did not enter edit mode."
        )
        let saveAction = app.buttons["pet-basic-info-save-action"]
        XCTAssertTrue(saveAction.waitForExistence(timeout: 8), "Pet Basic Info did not expose Save.")
        XCTAssertFalse(saveAction.isEnabled, "Save must stay disabled until the draft changes.")
    }

    @MainActor
    private func discardPetBasicInfoChanges(in app: XCUIApplication) {
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
        let discard = app.buttons["pet-basic-info-discard-changes-action"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 8), "Dirty Pet profile cancel did not ask for confirmation.")
        tapWhenHittable(discard, timeout: 8)
    }

    @MainActor
    private func discardHumanBasicInfoChanges(in app: XCUIApplication) {
        tapWhenHittable(app.buttons["human-basic-info-cancel-edit-action"], timeout: 8)
        let discard = app.buttons["human-basic-info-discard-changes-action"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 8), "Dirty Human profile cancel did not ask for confirmation.")
        tapWhenHittable(discard, timeout: 8)
    }

    @MainActor
    private func enterPetBasicInfoNote(_ note: String, in app: XCUIApplication) {
        let notesInput = app.textFields["pet-basic-info-notes-input"]
        scrollToElement(notesInput, in: app, maxSwipes: 8)
        XCTAssertTrue(
            notesInput.waitForExistence(timeout: 10),
            "Pet Basic Info edit mode did not expose the notes input."
        )
        tapWhenHittable(notesInput, timeout: 8)
        notesInput.typeText(note)
        dismissKeyboardIfPresent(in: app)
    }

    @MainActor
    private func clearTextField(_ textField: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(waitForFrameReady(textField, timeout: 8), "Text field was not frame-ready for clearing.")
        tapWhenHittable(textField, timeout: 8)
        textField.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()

        for _ in 0 ..< 4 {
            let currentValue = (textField.value as? String) ?? ""
            if isEmptyTextFieldValue(currentValue) { return }
            textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count + 4))
            _ = waitUntil(timeout: 1) {
                isEmptyTextFieldValue((textField.value as? String) ?? "")
            }
        }

        let finalValue = (textField.value as? String) ?? ""
        XCTAssertTrue(isEmptyTextFieldValue(finalValue), "Text field still contained text after clear attempts. Actual: \(finalValue)")
    }

    private func isEmptyTextFieldValue(_ value: String) -> Bool {
        value.isEmpty ||
            value == "Name" ||
            value == "名字" ||
            value == "Pet name" ||
            value == "宠物名字" ||
            value == "Tiername" ||
            value == "给这件事起个名字" ||
            value == "Name this event" ||
            value == "Termin benennen"
    }

    @MainActor
    private func openCalendarTab(in app: XCUIApplication, petName: String) {
        closeCurrentPetRouteIfNeeded(in: app)
        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists {
            _ = tapWhenFrameReady(homeTab, timeout: 5)
        }
        collapseExpandedPetCardIfNeeded(in: app)

        let petCard = app.buttons["home-card-pet-\(petName)"]
        let fallbackPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 20) { petCard.exists || fallbackPetCard.exists },
            "Pet home card did not appear before opening pet Calendar context."
        )

        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 20), "Calendar tab did not appear after starter setup.")
        tapWhenHittable(calendarTab, timeout: 8)
        let calendarSurface = app.buttons["task-center-surface-calendar"]
        XCTAssertTrue(
            calendarSurface.waitForExistence(timeout: 14),
            "Task Center did not expose the Calendar surface from the Home tab."
        )
        tapWhenHittable(calendarSurface, timeout: 8)
        let allFilter = app.buttons["calendar-filter-all"]
        let listViewButton = app.buttons["calendar-view-mode-list"]
        XCTAssertTrue(
            waitUntil(timeout: 14) { allFilter.exists || listViewButton.exists },
            "Calendar surface did not open from Task Center."
        )
        tapWhenHittable(listViewButton, timeout: 8)
        closeCurrentPetRouteIfNeeded(in: app)
    }

    @MainActor
    private func openCalendarTabFromHome(in app: XCUIApplication, humanName: String) {
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 20), "Calendar tab did not appear from Home.")
        tapWhenHittable(calendarTab, timeout: 8)
        let calendarSurface = app.buttons["task-center-surface-calendar"]
        XCTAssertTrue(
            calendarSurface.waitForExistence(timeout: 14),
            "Task Center did not expose the Calendar surface from Home."
        )
        tapWhenHittable(calendarSurface, timeout: 8)
        let allFilter = app.buttons["calendar-filter-all"]
        let listViewButton = app.buttons["calendar-view-mode-list"]
        XCTAssertTrue(
            waitUntil(timeout: 14) { allFilter.exists || listViewButton.exists },
            "Calendar surface did not open from Task Center."
        )
        tapWhenHittable(listViewButton, timeout: 8)
    }

    @MainActor
    private func selectCalendarListView(in app: XCUIApplication) {
        let listViewButton = app.buttons["calendar-view-mode-list"]
        XCTAssertTrue(listViewButton.waitForExistence(timeout: 10), "Calendar list-view toggle did not appear.")
        tapWhenHittable(listViewButton, timeout: 8)
    }

    @MainActor
    private func addCalendarEvent(
        title: String,
        linkedPetName: String?,
        expectVisibleAfterSave: Bool = true,
        in app: XCUIApplication
    ) {
        tapCalendarAddEventAction(in: app)
        XCTAssertTrue(
            app.textFields["add-event-title-input"].waitForExistence(timeout: 10),
            "Calendar add-event sheet did not open."
        )
        typeText(title, intoTextField: "add-event-title-input", in: app)
        dismissKeyboardIfPresent(in: app, returnKeyIsSafe: true)
        XCTAssertTrue(
            waitUntil(timeout: 4) { !app.keyboards.firstMatch.exists },
            "Calendar event title keyboard did not dismiss."
        )
        if let linkedPetName {
            let relatedEntityPicker = app.buttons["add-event-related-entity-picker"]
            scrollTowardElement(relatedEntityPicker, in: app, maxSwipes: 6)
            XCTAssertTrue(
                relatedEntityPicker.waitForExistence(timeout: 8),
                "Calendar add-event sheet did not expose the related-entity picker."
            )
            tapWhenHittable(relatedEntityPicker, timeout: 8)
            let petChip = app.buttons["add-event-related-pet-\(linkedPetName)"]
            let fallbackPetOption = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", linkedPetName)).firstMatch
            XCTAssertTrue(
                waitUntil(timeout: 8) { petChip.exists || fallbackPetOption.exists },
                "Calendar related-entity picker did not expose \(linkedPetName)."
            )
            tapWhenHittable(petChip.exists ? petChip : fallbackPetOption, timeout: 8)
        }
        let reminderToggle = app.switches["add-event-reminder-toggle"]
        XCTAssertTrue(
            reminderToggle.waitForExistence(timeout: 8),
            "Calendar add-event sheet did not expose the reminder toggle."
        )
        for _ in 0 ..< 6 where !reminderToggle.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        if isToggleOn(reminderToggle) {
            reminderToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            XCTAssertTrue(
                waitUntil(timeout: 4) { !isToggleOn(reminderToggle) },
                "Calendar reminder stayed enabled for a Simulator-only persistence test. Actual: \(String(describing: reminderToggle.value))"
            )
        }
        tapFirstHittableButton(identifier: "add-event-save-action", in: app, timeout: 8, context: "calendar event save")
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !app.textFields["add-event-title-input"].exists
            },
            "Calendar add-event sheet did not close after saving \(title)."
        )
        assertCalendarEvent(title, exists: expectVisibleAfterSave, in: app, context: "post-save readback")
    }

    @MainActor
    private func tapCalendarAddEventAction(in app: XCUIApplication) {
        closeCurrentPetRouteIfNeeded(in: app)
        let calendarAddEventAction = app.buttons["calendar-add-event-action"]
        if calendarAddEventAction.exists && calendarAddEventAction.isEnabled && calendarAddEventAction.isHittable {
            tapWhenHittable(calendarAddEventAction, timeout: 5)
            return
        }

        let addEventAction = app.buttons["home-primary-action"]
        let didBecomeHittable = waitUntil(timeout: 8) {
            addEventAction.exists && addEventAction.isEnabled && addEventAction.isHittable
        }
        if didBecomeHittable {
            addEventAction.tap()
            return
        }

        closeCurrentPetRouteIfNeeded(in: app)
        let didBecomeHittableAfterClosingRoute = waitUntil(timeout: 4) {
            addEventAction.exists && addEventAction.isEnabled && addEventAction.isHittable
        }
        if didBecomeHittableAfterClosingRoute {
            addEventAction.tap()
            return
        }

        let elementValue = addEventAction.value.map { String(describing: $0) } ?? "nil"
        XCTAssertTrue(
            addEventAction.exists && addEventAction.isEnabled,
            "Calendar add-event action was not ready: \(addEventAction) exists=\(addEventAction.exists) enabled=\(addEventAction.isEnabled) hittable=\(addEventAction.isHittable) frame=\(addEventAction.frame) label=\(addEventAction.label) value=\(elementValue)"
        )
        addEventAction.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    private func assertCalendarEvent(_ title: String, exists expected: Bool, in app: XCUIApplication, context: String) {
        let row = app.descendants(matching: .any)["calendar-event-row-\(title)"]
        if expected, !waitUntil(timeout: 4, condition: { row.exists }) {
            scrollToElement(row, in: app, maxSwipes: 10)
        }
        let didMatch = waitUntil(timeout: expected ? 12 : 3) {
            row.exists == expected
        }
        XCTAssertTrue(
            didMatch,
            "Calendar event \(title) existence was \(row.exists), expected \(expected) during \(context)."
        )
    }

    @MainActor
    private func assertCalendarEventAny(of titles: [String], exists expected: Bool, in app: XCUIApplication, context: String) {
        let rows = titles.map { app.descendants(matching: .any)["calendar-event-row-\($0)"] }
        if expected, !waitUntil(timeout: 4, condition: { rows.contains { $0.exists } }) {
            for _ in 0 ..< 10 where !rows.contains(where: \.exists) {
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        let didMatch = waitUntil(timeout: expected ? 12 : 3) {
            (rows.contains { $0.exists }) == expected
        }
        XCTAssertTrue(
            didMatch,
            "Calendar event candidates \(titles) existence was \(rows.contains { $0.exists }), expected \(expected) during \(context)."
        )
    }

    @MainActor
    private func assertCalendarEventDetailOpen(in app: XCUIApplication, context: String) {
        let detailPage = app.descendants(matching: .any)
            .matching(identifier: "calendar-event-detail-page")
            .firstMatch
        XCTAssertTrue(
            detailPage.waitForExistence(timeout: 10),
            "Calendar event detail did not open for \(context)."
        )
        XCTAssertTrue(
            app.buttons["calendar-event-edit-action"].exists,
            "Calendar event detail did not expose edit action for \(context)."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(identifier: "calendar-event-detail-sheet")
                .firstMatch
                .exists,
            "Manual calendar event still opened the old sheet for \(context)."
        )
        XCTAssertFalse(
            isAnyLivePetRouteVisible(in: app),
            "Manual calendar event opened a pet route instead of event detail for \(context)."
        )
    }

    @MainActor
    private func tapFirstCalendarEventAny(of titles: [String], in app: XCUIApplication) {
        let rows = titles.map {
            app.descendants(matching: .any)
                .matching(identifier: "calendar-event-row-\($0)")
                .firstMatch
        }
        if !waitUntil(timeout: 4, condition: { rows.contains { $0.exists } }) {
            for _ in 0 ..< 12 where !rows.contains(where: \.exists) {
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        guard let row = rows.first(where: \.exists) else {
            XCTFail("None of the expected calendar event rows existed: \(titles)")
            return
        }
        scrollToElement(row, in: app, maxSwipes: 10)
        tapWhenHittable(row, timeout: 8)
    }

    private func feedPlanCalendarTitleCandidates() -> [String] {
        let mealNames = [
            "Breakfast", "Lunch", "Dinner",
            "早餐", "午餐", "晚餐",
            "Frühstück", "Mittagessen", "Abendessen"
        ]
        let foodNames = ["Dry food", "干粮", "Trockenfutter"]
        return mealNames.flatMap { mealName in
            foodNames.map { foodName in
                "\(mealName) \(foodName) 50g"
            }
        }
    }

    @MainActor
    private func tapCalendarEvent(_ title: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "calendar-event-row-\(title)"))
            .firstMatch
        scrollToElement(row, in: app, maxSwipes: 4)
        XCTAssertTrue(
            row.waitForExistence(timeout: 12),
            "Calendar event row \(title) did not exist before tapping."
        )
        tapWhenHittable(row, timeout: 8)
    }

    @MainActor
    private func isAnyLivePetRouteVisible(in app: XCUIApplication) -> Bool {
        livePetRouteIdentifiers().contains { identifier in
            let element = app.descendants(matching: .any)[identifier]
            return element.exists && element.isHittable
        }
    }

    @MainActor
    private func closeCurrentPetRouteIfNeeded(in app: XCUIApplication) {
        let healthDetailScreen = app.descendants(matching: .any)["pet-health-detail-screen"]
        guard healthDetailScreen.exists else { return }

        let close = app.buttons["pet-health-detail-close-action"]
        if close.exists && close.isEnabled && close.isHittable {
            tapWhenHittable(close, timeout: 5)
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.12)).tap()
        }

        _ = waitUntil(timeout: 8) {
            !healthDetailScreen.exists
        }
    }

    private func livePetRouteIdentifiers() -> [String] {
        [
            "quick-feed-detail-sheet",
            "quick-water-detail-sheet",
            "quick-potty-detail-sheet",
            "quick-play-detail-sheet",
            "pet-hygiene-detail-screen",
            "pet-health-detail-screen",
            "pet-weight-detail-screen",
            "walk-summary-sheet",
            "pet-bond-vault-screen"
        ]
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0 ..< maxSwipes where !element.exists || !hasVisibleFrame(element, in: app) {
            swipeUpInPrimaryScrollArea(in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    @MainActor
    private func scrollTowardElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0 ..< maxSwipes where !element.exists || !hasVisibleFrame(element, in: app) {
            if element.exists, element.frame.midY < app.frame.midY {
                app.swipeDown()
            } else {
                swipeUpInPrimaryScrollArea(in: app)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    @MainActor
    private func swipeUpInPrimaryScrollArea(in app: XCUIApplication) {
        let calendarList = app.descendants(matching: .any)["calendar-list-scroll-view"]
        if visibleFrame(of: calendarList, in: app) != nil {
            dragUp(in: calendarList)
        } else if let scrollView = largestVisibleScrollView(in: app) {
            dragUp(in: scrollView)
        } else {
            app.swipeUp()
        }
    }

    @MainActor
    private func largestVisibleScrollView(in app: XCUIApplication) -> XCUIElement? {
        let scrollViews = app.scrollViews
        var bestElement: XCUIElement?
        var bestArea: CGFloat = 0

        for index in 0 ..< scrollViews.count {
            let candidate = scrollViews.element(boundBy: index)
            guard let frame = visibleFrame(of: candidate, in: app) else { continue }
            let area = frame.width * frame.height
            if area > bestArea {
                bestArea = area
                bestElement = candidate
            }
        }

        return bestElement
    }

    private func visibleFrame(of element: XCUIElement, in app: XCUIApplication) -> CGRect? {
        guard element.exists else { return nil }
        let frame = element.frame
        guard isFiniteFrame(frame), frame.width > 44, frame.height > 44 else { return nil }
        let visibleFrame = frame.intersection(app.frame)
        guard !visibleFrame.isNull, visibleFrame.width > 44, visibleFrame.height > 44 else { return nil }
        return visibleFrame
    }

    private func hasVisibleFrame(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        guard isFiniteFrame(frame), frame.width > 1, frame.height > 1 else { return false }
        let visibleFrame = frame.intersection(app.frame)
        return !visibleFrame.isNull && visibleFrame.width > 1 && visibleFrame.height > 1
    }

    private func dragUp(in scrollView: XCUIElement) {
        scrollView.swipeUp()
    }

    @MainActor
    private func closeCurrentSheetToHome(in app: XCUIApplication, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists && homeTab.isEnabled && homeTab.isHittable {
            tapWhenHittable(homeTab, timeout: 5)
        }
        let didReturnHome = waitUntil(timeout: 16) {
            isHumanRouteAtHome(in: app, humanName: humanName)
        }
        XCTAssertTrue(didReturnHome, "Closing the human feature route did not return to Home.")
    }

    @MainActor
    private func closeCurrentSheetToHomeIfNeeded(in app: XCUIApplication, humanName: String) {
        for _ in 0 ..< 3 {
            if isHumanRouteAtHome(in: app, humanName: humanName) {
                return
            }
            dismissOneHumanRouteLayer(in: app)
            _ = waitUntil(timeout: 4) {
                isHumanRouteAtHome(in: app, humanName: humanName)
            }
        }
    }

    @MainActor
    private func dismissCurrentSheetByDrag(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
        start.press(forDuration: 0.12, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    @MainActor
    private func cancelLitterSettings(in app: XCUIApplication) {
        tapWhenHittable(app.buttons["quick-potty-sheet-cancel-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Litter settings sheet did not dismiss after tapping Cancel."
        )
    }

    @MainActor
    private func closeHumanProfileToHome(in app: XCUIApplication, humanName: String) {
        for _ in 0 ..< 3 {
            if isHumanRouteAtHome(in: app, humanName: humanName) {
                return
            }
            dismissOneHumanRouteLayer(in: app)
            _ = waitUntil(timeout: 4) {
                isHumanRouteAtHome(in: app, humanName: humanName)
            }
        }

        let didReturnHome = waitUntil(timeout: 14) {
            isHumanRouteAtHome(in: app, humanName: humanName)
        }
        XCTAssertTrue(didReturnHome, "Closing the human profile did not return to Home.")
    }

    private func isHumanRouteAtHome(in app: XCUIApplication, humanName _: String) -> Bool {
        app.state == .runningForeground &&
            !app.buttons["feature-hub-body-weight"].exists &&
            !isPetFeatureRouteOverlayVisible(in: app) &&
            !isHumanFeatureRouteOverlayVisible(in: app) &&
            app.buttons["home-tab-home"].exists
    }

    private func isPetFeatureRouteOverlayVisible(in app: XCUIApplication) -> Bool {
        livePetRouteIdentifiers().contains { identifier in
            app.descendants(matching: .any)[identifier].exists
        } || [
            "feature-hub-daily-food",
            "feature-hub-daily-potty",
            "feature-hub-health-health"
        ].contains { identifier in
            app.buttons[identifier].exists
        }
    }

    @MainActor
    private func dismissOneHumanRouteLayer(in app: XCUIApplication) {
        let closeIdentifiers = [
            "pet-bond-vault-close-action",
            "quick-potty-sheet-cancel-action",
            "human-module-close-action",
            "crew-roster-close-action",
            "human-workout-close-action",
            "human-basic-info-close-action",
            "ohana-sheet-close-action",
            "BackButton"
        ]
        for identifier in closeIdentifiers {
            if let close = firstHittableButton(identifier: identifier, in: app) {
                close.tap()
                return
            }
        }

        if let close = firstHittableButton(labels: ["Close", "Done", "关闭", "完成", "Schließen", "Fertig"], in: app) {
            close.tap()
            return
        }
        if let close = firstFrameReadyButton(labels: ["Close", "Done", "关闭", "完成", "Schließen", "Fertig"], in: app) {
            close.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }
        if let back = firstHittableButton(labels: ["Back", "返回", "Zurück"], in: app) {
            back.tap()
            return
        }

        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists && homeTab.isEnabled && homeTab.isHittable {
            homeTab.tap()
        } else {
            dismissCurrentSheetByDrag(in: app)
        }
    }

    private func isHumanFeatureRouteOverlayVisible(in app: XCUIApplication) -> Bool {
        [
            "add-human-workout-sheet",
            "generic-weight-entry-sheet-human",
            "human-detail-screen",
            "human-expense-add-action",
            "human-basic-info-screen",
            "human-health-metric-starter-record-action",
            "human-health-metric-detail-tsh",
            "human-health-metric-entry-sheet-tsh",
            "human-health-report-add-action",
            "human-medication-add-action",
            "human-module-close-action",
            "human-note-add-action",
            "human-weight-add-action",
            "human-workout-add-action",
            "human-workout-summary-view",
            "human-workout-delete-action",
            "human-wishlist-add-action",
            "quick-human-expense-sheet",
            "quick-human-medication-sheet",
            "quick-human-workout-sheet",
            "quick-human-note-sheet"
        ].contains { identifier in
            app.descendants(matching: .any)[identifier].exists
        }
    }

    private func assertAnyMarkerExists(_ markers: [String], in app: XCUIApplication, timeout: TimeInterval, context: String) {
        let didFindMarker = waitUntil(timeout: timeout) {
            containsAnyMarker(markers, in: app)
        }
        XCTAssertTrue(didFindMarker, "Human feature route did not show any expected marker for \(context): \(markers)")
    }

    private func containsAnyMarker(_ markers: [String], in app: XCUIApplication) -> Bool {
        markers.contains { marker in
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", marker)
            return app.staticTexts.matching(predicate).firstMatch.exists ||
                app.buttons.matching(predicate).firstMatch.exists ||
                app.otherElements.matching(predicate).firstMatch.exists ||
                app.navigationBars.matching(predicate).firstMatch.exists
        }
    }

    private func localizedContains(_ value: String, anyOf needles: [String]) -> Bool {
        needles.contains { value.localizedCaseInsensitiveContains($0) }
    }

    private func numericLabel(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private func waitForQuickFeedHome(in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            isQuickFeedHomeVisible(in: app)
        }
    }

    private func isQuickFeedHomeVisible(in app: XCUIApplication) -> Bool {
        app.staticTexts["quick-feed-current-mode-title"].exists ||
            app.buttons["quick-feed-primary-action"].exists ||
            app.buttons["quick-feed-mode-manual"].exists
    }

    private func isHomeSurfaceResponsive(in app: XCUIApplication) -> Bool {
        [
            app.buttons["home-settings-action"],
            app.buttons["home-primary-action"],
            app.buttons["home-tab-oasis"],
            app.buttons["home-add-first-pet-action"],
            app.buttons["home-add-first-pet-card"]
        ].contains { element in
            element.exists && element.isEnabled && element.isHittable
        }
    }

    @MainActor
    private func createMember(
        in app: XCUIApplication,
        name: String,
        flowTitle: String,
        missingFieldMessage: String,
        completionMessage: String,
        starterPetWeight: String? = nil,
        petSpeciesLabel: String? = nil,
        postSaveMarkerIdentifiers: [String]
    ) {
        XCTAssertFalse(
            postSaveMarkerIdentifiers.isEmpty,
            "Member creation requires an explicit post-save marker."
        )
        let nameField = app.textFields["member-name-input"]
        let didShowNameField = waitUntil(timeout: 12) {
            nameField.exists && nameField.isHittable
        }
        XCTAssertTrue(didShowNameField, missingFieldMessage)

        nameField.tap()
        nameField.typeText(name)
        nameField.typeText("\n")
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        tapThroughMemberCreationSteps(
            in: app,
            starterPetWeight: starterPetWeight,
            petSpeciesLabel: petSpeciesLabel
        )

        let handoffTitle = app.staticTexts[flowTitle]
        let creationPrimary = app.buttons["member-creation-primary-action"]
        let didLeaveCreation = waitUntil(timeout: 30) {
            let didReachExpectedMarker = containsAnyElement(in: app, identifiers: postSaveMarkerIdentifiers)
            return app.state == .runningForeground &&
                didReachExpectedMarker &&
                !nameField.exists &&
                !creationPrimary.exists &&
                !handoffTitle.exists
        }
        XCTAssertTrue(didLeaveCreation, completionMessage)
    }

    @MainActor
    private func selectMemberCreationPetSpecies(_ speciesLabel: String, in app: XCUIApplication) {
        let speciesKey: String = switch speciesLabel.lowercased() {
        case "cat", "猫", "katze": "cat"
        case "dog", "狗", "hund": "dog"
        default: speciesLabel.lowercased()
        }
        let speciesButton = app.buttons["member-pet-species-option-\(speciesKey)"]
        XCTAssertTrue(
            speciesButton.waitForExistence(timeout: 8),
            "Pet creation species button did not appear before selecting \(speciesLabel)."
        )

        if app.buttons["member-pet-breed-picker"].exists {
            return
        }
        tapGuidedJourneyControlAfterSemanticScroll(speciesButton, in: app)
        XCTAssertTrue(
            app.buttons["member-pet-breed-picker"].waitForExistence(timeout: 8),
            "Selecting \(speciesLabel) did not reveal the breed picker."
        )
    }

    @MainActor
    private func selectMemberCreationPetBreed(for speciesLabel: String, in app: XCUIApplication) {
        let breedMenu = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@ OR label CONTAINS %@", "Breed", "品种", "Rasse"))
            .firstMatch
        XCTAssertTrue(breedMenu.waitForExistence(timeout: 8), "Pet creation breed menu did not appear.")
        let creationPrimary = app.buttons["member-creation-primary-action"]
        let unselectedValues = ["Choose", "选择", "Wählen"]
        let hasSelectedBreed = {
            breedMenu.exists && !unselectedValues.contains { value in
                breedMenu.label.localizedCaseInsensitiveContains(value)
            }
        }
        if hasSelectedBreed() {
            return
        }

        let placeholderLabel = breedMenu.label
        let selectionWasRequired = creationPrimary.exists && !creationPrimary.isEnabled
        let breedOptionLabels = switch speciesLabel.lowercased() {
        case "cat", "猫", "katze":
            ["ragdoll cat", "布偶猫", "Ragdoll"]
        default:
            ["Pomeranian", "博美犬"]
        }

        for _ in 0 ..< 3 {
            tapGuidedJourneyControlAfterSemanticScroll(breedMenu, in: app)

            let didExposeOption = waitUntil(timeout: 8) {
                breedOptionLabels.contains { app.buttons[$0].exists }
            }
            guard didExposeOption else { continue }
            guard tapNativeMenuOption(
                optionLabels: breedOptionLabels,
                in: app
            ) else {
                continue
            }

            let didApplySelection = waitUntil(timeout: 4) {
                hasSelectedBreed() ||
                    (breedMenu.exists && breedMenu.label != placeholderLabel) ||
                    (selectionWasRequired && creationPrimary.exists && creationPrimary.isEnabled)
            }
            if didApplySelection {
                return
            }
        }

        if waitUntil(timeout: 4, condition: hasSelectedBreed) {
            return
        }

        XCTFail("Pet creation breed selection did not apply. Current menu label: \(breedMenu.label)")
    }

    @MainActor
    private func tapNativeMenuOption(
        optionLabels: [String],
        in app: XCUIApplication
    ) -> Bool {
        let didTap = waitUntil(timeout: 8) {
            guard let targetOption = firstHittableButton(labels: optionLabels, in: app)
                ?? firstFrameReadyButton(labels: optionLabels, in: app) else {
                return false
            }
            targetOption.tap()
            return true
        }
        return didTap
    }

    private func containsAnyElement(in app: XCUIApplication, identifiers: [String]) -> Bool {
        identifiers.contains { identifier in
            app.descendants(matching: .any)[identifier].exists
        }
    }

    private func containsAnyText(in app: XCUIApplication, texts: [String]) -> Bool {
        texts.contains { text in
            app.staticTexts[text].exists ||
                app.buttons[text].exists ||
                app.descendants(matching: .any)[text].exists
        }
    }

    @MainActor
    private func typeText(_ text: String, intoTextField identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        let fallback = app.descendants(matching: .any)[identifier]
        let didShowTextField = waitUntil(timeout: 8) {
            field.exists || fallback.exists
        }
        XCTAssertTrue(didShowTextField, "Text field did not appear: \(identifier)")
        let target = field.exists ? field : fallback
        scrollTowardElement(target, in: app, maxSwipes: 6)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                target.exists && target.isEnabled && hasVisibleFrame(target, in: app)
            },
            "Text field did not become visible: \(identifier)"
        )
        if target.isHittable {
            target.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(
            waitUntil(timeout: 4) { app.keyboards.firstMatch.exists },
            "Text field did not receive keyboard focus: \(identifier)"
        )
        target.typeText(text)
    }

    @MainActor
    private func typeText(_ text: String, intoTextView identifier: String, in app: XCUIApplication) {
        let textView = app.textViews[identifier]
        let fallback = app.descendants(matching: .any)[identifier]
        let didShowTextView = waitUntil(timeout: 8) {
            textView.exists || fallback.exists
        }
        XCTAssertTrue(didShowTextView, "Text view did not appear: \(identifier)")
        let target = textView.exists ? textView : fallback
        scrollTowardElement(target, in: app, maxSwipes: 6)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                target.exists && target.isEnabled && hasVisibleFrame(target, in: app)
            },
            "Text view did not become visible: \(identifier)"
        )
        if target.isHittable {
            target.tap()
        } else {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(
            waitUntil(timeout: 4) { app.keyboards.firstMatch.exists },
            "Text view did not receive keyboard focus: \(identifier)"
        )
        target.typeText(text)
    }

    @MainActor
    private func dismissKeyboardIfPresent(in app: XCUIApplication, returnKeyIsSafe: Bool = false) {
        if app.keyboards.firstMatch.exists {
            let doneLabels = ["Done", "done", "完成", "隐藏键盘", "Hide keyboard"]
            if let done = doneLabels
                .map({ app.keyboards.buttons[$0].firstMatch })
                .first(where: { $0.exists && $0.isEnabled && $0.isHittable }) {
                done.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                return
            }
            if returnKeyIsSafe {
                let returnLabels = ["return", "Return", "换行"]
                if let returnKey = returnLabels
                    .map({ app.keyboards.buttons[$0].firstMatch })
                    .first(where: { $0.exists && $0.isEnabled && $0.isHittable }) {
                    returnKey.tap()
                    if waitUntil(timeout: 2, condition: { !app.keyboards.firstMatch.exists }) {
                        return
                    }
                }
            }
            app.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
    }

    @MainActor
    private func tapThroughMemberCreationSteps(
        in app: XCUIApplication,
        starterPetWeight: String? = nil,
        petSpeciesLabel: String? = nil
    ) {
        let creationPrimary = app.buttons["member-creation-primary-action"]
        XCTAssertTrue(creationPrimary.waitForExistence(timeout: 8), "Member creation primary action did not appear.")

        var didTapFinalSave = false
        for _ in 0 ..< 8 {
            guard creationPrimary.exists else {
                didTapFinalSave = true
                break
            }
            if let starterPetWeight {
                fillStarterPetWeightIfNeeded(
                    in: app,
                    value: starterPetWeight,
                    waitForInput: !creationPrimary.isEnabled
                )
            }
            if let petSpeciesLabel,
               app.buttons["member-pet-species-option-dog"].exists {
                selectMemberCreationPetSpecies(petSpeciesLabel, in: app)
                selectMemberCreationPetBreed(for: petSpeciesLabel, in: app)
            }
            if app.buttons["member-pet-coat-picker"].exists {
                selectMemberCreationPetAppearance(in: app)
            }
            let actionLabel = creationPrimary.label
            let didBecomeReadyOrLeave = waitUntil(timeout: 8) {
                guard creationPrimary.exists else { return true }
                guard creationPrimary.isEnabled else { return false }
                let frame = creationPrimary.frame
                return frame.width > 1 && frame.height > 1 && isFiniteFrame(frame)
            }
            XCTAssertTrue(
                didBecomeReadyOrLeave,
                "Member creation primary action did not become enabled with a stable touch frame."
            )
            guard creationPrimary.exists else {
                didTapFinalSave = true
                break
            }
            tapGuidedJourneyControlAfterSemanticScroll(creationPrimary, in: app)
            if isMemberCreationFinalActionLabel(actionLabel) {
                didTapFinalSave = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
            if !creationPrimary.exists {
                didTapFinalSave = true
                break
            }
        }
        XCTAssertTrue(didTapFinalSave, "Member creation did not reach the final save action.")
    }

    @MainActor
    private func selectMemberCreationPetAppearance(in app: XCUIApplication) {
        let boy = app.buttons["member-gender-boy"]
        if boy.waitForExistence(timeout: 4), boy.isEnabled {
            tapGuidedJourneyControlAfterSemanticScroll(boy, in: app)
        }

        let coatMenu = app.buttons["member-pet-coat-picker"]
        guard coatMenu.waitForExistence(timeout: 4) else { return }
        let creationPrimary = app.buttons["member-creation-primary-action"]
        if creationPrimary.isEnabled { return }

        let coatOptions = ["黄色", "橘猫", "赤色", "黑色", "白色", "Black", "White", "Red"]
        for _ in 0 ..< 3 {
            tapGuidedJourneyControlAfterSemanticScroll(coatMenu, in: app)
            guard waitUntil(timeout: 6, condition: {
                coatOptions.contains { app.buttons[$0].exists }
            }) else { continue }
            guard tapNativeMenuOption(optionLabels: coatOptions, in: app) else { continue }
            if waitUntil(timeout: 4, condition: { creationPrimary.isEnabled }) {
                return
            }
        }
        XCTFail("Pet creation coat selection did not apply.")
    }

    private func isMemberCreationFinalActionLabel(_ label: String) -> Bool {
        label.contains("Join Island")
            || label.contains("加入岛屿")
            || label.contains("Insel beitreten")
    }

    @MainActor
    private func fillStarterPetWeightIfNeeded(in app: XCUIApplication, value _: String, waitForInput _: Bool) {
        // 体重已从添加宠物流程移除:此步不再存在,保留为无操作以兼容既有调用点。
        _ = app
    }

    @MainActor
    private func tapWhenSemanticallyHittable(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) -> Bool {
        let didBecomeHittable = waitUntil(timeout: timeout) {
            element.exists && element.isEnabled && element.isHittable
        }
        guard didBecomeHittable else { return false }
        element.tap()
        return true
    }

    @MainActor
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval) {
        let didBecomeHittable = waitUntil(timeout: timeout) {
            element.exists && element.isEnabled && element.isHittable
        }
        if didBecomeHittable {
            element.tap()
            return
        }

        let didBecomeFrameReady = waitForFrameReady(element, timeout: 1)
        let elementValue = element.value.map { String(describing: $0) } ?? "nil"
        guard didBecomeFrameReady else {
            XCTFail(
                "Element did not become hittable or frame-ready: \(element) exists=\(element.exists) enabled=\(element.isEnabled) hittable=\(element.isHittable) frame=\(element.frame) label=\(element.label) value=\(elementValue)"
            )
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    private func tapGuidedJourneyControlAfterSemanticScroll(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0 ... maxSwipes {
            if element.exists, element.isEnabled, element.isHittable {
                element.tap()
                return
            }
            swipeUpInPrimaryScrollArea(in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTAssertTrue(
            element.exists && element.isEnabled && element.isHittable,
            "Guided journey control did not become semantically tappable after scrolling: \(element)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func firstHittableButton(identifier: String, in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(identifier: identifier)
        let count = matches.count
        guard count > 0 else { return nil }

        for index in 0 ..< count {
            let button = matches.element(boundBy: index)
            if button.exists, button.isEnabled, hasVisibleFrame(button, in: app), button.isHittable {
                return button
            }
        }
        return nil
    }

    @MainActor
    private func uniqueAccessibilityIdentifierCount(prefix: String, in app: XCUIApplication) -> Int {
        let matches = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        let count = matches.count
        return Set((0 ..< count).map { matches.element(boundBy: $0).identifier }).count
    }

    @MainActor
    private func firstFrameReadyButton(identifier: String, in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(identifier: identifier)
        let count = matches.count
        guard count > 0 else { return nil }

        for index in 0 ..< count {
            let button = matches.element(boundBy: index)
            if button.exists, button.isEnabled, hasVisibleFrame(button, in: app) {
                return button
            }
        }
        return nil
    }

    @MainActor
    private func firstHittableButton(labels: [String], in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label IN %@", labels))
        let count = matches.count
        guard count > 0 else { return nil }

        for index in 0 ..< count {
            let button = matches.element(boundBy: index)
            if button.exists, button.isEnabled, hasVisibleFrame(button, in: app), button.isHittable {
                return button
            }
        }
        return nil
    }

    private func firstFrameReadyButton(labels: [String], in app: XCUIApplication) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label IN %@", labels))
        let count = matches.count
        guard count > 0 else { return nil }

        for index in 0 ..< count {
            let button = matches.element(boundBy: index)
            guard button.exists, button.isEnabled else { continue }
            let frame = button.frame
            let visibleFrame = frame.intersection(app.frame)
            if frame.width > 1,
               frame.height > 1,
               isFiniteFrame(frame),
               !visibleFrame.isNull,
               visibleFrame.width > 1,
               visibleFrame.height > 1 {
                return button
            }
        }
        return nil
    }

    @MainActor
    private func tapFirstHittableButton(identifier: String, in app: XCUIApplication, timeout: TimeInterval, context: String) {
        var didTap = waitUntil(timeout: timeout) {
            guard let button = firstHittableButton(identifier: identifier, in: app) else {
                return false
            }
            button.tap()
            return true
        }
        if !didTap {
            let firstMatch = app.buttons.matching(identifier: identifier).firstMatch
            scrollTowardElement(firstMatch, in: app, maxSwipes: 4)
            didTap = tapWhenFrameReady(firstMatch, timeout: 2)
        }
        let matchCount = app.buttons.matching(identifier: identifier).count
        XCTAssertTrue(
            didTap,
            "No visible button \(identifier) became available for \(context). matches=\(matchCount)"
        )
    }

    @MainActor
    private func tapFirstAvailableButton(
        _ labels: [String],
        in app: XCUIApplication,
        timeout: TimeInterval,
        context: String
    ) {
        let didTap = waitUntil(timeout: timeout) {
            guard let button = firstHittableButton(labels: labels, in: app) else { return false }
            button.tap()
            return true
        }
        XCTAssertTrue(didTap, "No alert button became available for \(context): \(labels.joined(separator: ", "))")
    }

    @MainActor
    private func tapWhenFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        tapWhenFrameReady(element, offset: CGVector(dx: 0.5, dy: 0.5), timeout: timeout)
    }

    private func waitForFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            guard element.exists, element.isEnabled else { return false }
            let frame = element.frame
            return frame.width > 1 && frame.height > 1 && isFiniteFrame(frame)
        }
    }

    @MainActor
    private func tapWhenFrameReady(_ element: XCUIElement, offset: CGVector, timeout: TimeInterval) -> Bool {
        let didBecomeFrameReady = waitUntil(timeout: timeout) {
            guard element.exists, element.isEnabled else { return false }
            let frame = element.frame
            return frame.width > 1 && frame.height > 1 && isFiniteFrame(frame)
        }
        guard didBecomeFrameReady else { return false }
        element.coordinate(withNormalizedOffset: offset).tap()
        return true
    }

    private func isFiniteFrame(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite &&
            frame.origin.y.isFinite &&
            frame.width.isFinite &&
            frame.height.isFinite &&
            frame.midX.isFinite &&
            frame.midY.isFinite
    }

    private func isToggleOn(_ element: XCUIElement) -> Bool {
        let value = String(describing: element.value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return ["1", "true", "on", "yes", "enabled", "selected"].contains(value)
    }

    private func accessibilityText(for element: XCUIElement) -> String {
        let value = element.value.map { String(describing: $0) } ?? ""
        return "\(element.label) \(value)"
    }

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    private struct PetFeatureHubRouteExpectation {
        let tileIdentifier: String
        let markerIdentifier: String
    }
}

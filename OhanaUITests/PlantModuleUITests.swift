//
//  PlantModuleUITests.swift
//  OhanaUITests
//

import XCTest

final class PlantModuleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPlantModuleUnlockCreateCareReminderCalendarAndDelete() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        XCTAssertFalse(app.buttons["home-tab-plants"].exists, "Plants tab should stay hidden before Lv4 on a fresh account.")

        grantDebugCoconuts(1000, in: app)
        openOasisAndInjectUntilLevel4(in: app)

        openHomePlantsTabAfterUnlock(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let plantName = "Codex Pothos \(timestamp)"
        addPlantFromHomePlantsTab(named: plantName, in: app)
        assertHomePlantCard(named: plantName, in: app)

        openPlantDetail(named: plantName, in: app)
        exercisePlantDetailCareAndDeleteUndo(named: plantName, in: app)
        returnFromPlantDetailToHome(in: app)

        openPlantReminderSettingsAndTogglePlant(named: plantName, in: app)
        closeSettingsToHome(in: app)

        openCalendarAndAssertPlantVisible(named: plantName, in: app)

        openPlantDetail(named: plantName, in: app)
        permanentlyDeletePlant(named: plantName, in: app)
    }

    @MainActor
    private func launchEnglishApp(enableProductionOverlays: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
            "-appLanguage",
            "en",
            "-OHANA_UI_TESTS",
            "-OHANA_RESET_PERSISTENT_STATE"
        ]
        if enableProductionOverlays {
            app.launchArguments += ["-OHANA_ENABLE_PRODUCTION_OVERLAYS_IN_UI_TESTS"]
        }
        app.launch()
        return app
    }

    @MainActor
    private func createFirstHuman(from app: XCUIApplication) {
        let name = "Codex Human \(Int(Date().timeIntervalSince1970))"
        advanceOnboardingIntroToMemberCreation(in: app)
        createMember(
            in: app,
            name: name,
            flowTitle: "Create Member Card",
            missingFieldMessage: "Human creation name field did not appear.",
            completionMessage: "Creating the first human did not leave the creation flow in time.",
            postSaveMarkerIdentifiers: ["home-add-first-pet-card", "home-add-first-pet-action"],
            postSaveTextMarkers: ["Create Pet Card", "制作宠物卡", "Tierkarte erstellen"]
        )
    }

    @MainActor
    private func completeFirstDayStarterFunnel(in app: XCUIApplication) {
        openFirstPetCreationFromTodayFocus(in: app)
        createMember(
            in: app,
            name: "Codex Pet \(Int(Date().timeIntervalSince1970))",
            flowTitle: "Create Pet Card",
            missingFieldMessage: "Pet creation name field did not appear.",
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time.",
            starterPetWeight: "7",
            postSaveMarkerIdentifiers: ["starter-gift-finish-action"]
        )
        finishRequiredStarterGift(in: app)
    }

    @MainActor
    private func grantDebugCoconuts(_ amount: Int, in app: XCUIApplication) {
        openSettingsFromHomeChrome(in: app)

        let debugCoconuts = debugCoconutsEntry(in: app)
        scrollToElement(debugCoconuts, in: app, maxSwipes: 14)
        XCTAssertTrue(debugCoconuts.waitForExistence(timeout: 8), "Debug Coconuts row did not appear in Debug build settings.")
        tapWhenFrameReady(debugCoconuts, timeout: 8)

        let didReturnHome = waitUntil(timeout: 12) {
            app.buttons["home-settings-action"].exists || app.buttons["home-primary-action"].exists
        }
        XCTAssertTrue(didReturnHome, "Debug coconut shortcut did not apply \(amount) coconuts and close Settings.")
    }

    @MainActor
    private func openOasisAndInjectUntilLevel4(in app: XCUIApplication) {
        let oasisTab = app.buttons["home-tab-oasis"]
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 20), "Oasis tab did not appear after starter gift.")
        tapWhenHittable(oasisTab, timeout: 8)
        XCTAssertTrue(app.otherElements["oasis-screen"].waitForExistence(timeout: 20), "Oasis screen did not become visible.")

        let treeLevel = app.descendants(matching: .any)["oasis-tree-level-control"]
        XCTAssertTrue(treeLevel.waitForExistence(timeout: 12), "Oasis tree level control did not appear.")
        let inject = app.buttons["home-primary-action"]
        for _ in 0 ..< 80 {
            if treeLevelLabelIsAtLeast4(in: app) { break }
            if !tapWhenFrameReady(inject, timeout: 6) {
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                if treeLevelLabelIsAtLeast4(in: app) { break }
                XCTAssertTrue(tapWhenFrameReady(inject, timeout: 8), "Oasis inject action did not become frame-ready before Lv4. Current label: \(treeLevel.label)")
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        }
        XCTAssertTrue(treeLevelLabelIsAtLeast4(in: app), "Oasis injections did not unlock Lv4. Current label: \(treeLevel.label)")
    }

    @MainActor
    private func openHomePlantsTabAfterUnlock(in app: XCUIApplication) {
        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 14), "Plants tab did not appear after the Life Tree reached Lv4.")
        dismissGrowthUnlockPopupIfPresent(in: app)
        RunLoop.current.run(until: Date().addingTimeInterval(0.45))

        let plantsPage = app.descendants(matching: .any)["home-plants-page"]
        for _ in 0 ..< 3 {
            if plantsPage.exists { return }
            if plantsTab.exists, plantsTab.isEnabled, plantsTab.isHittable {
                plantsTab.tap()
            } else {
                XCTAssertTrue(tapWhenFrameReady(plantsTab, timeout: 6), "Plants tab existed after Lv4 but did not become frame-ready.")
            }
            if plantsPage.waitForExistence(timeout: 5) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        XCTAssertTrue(plantsPage.waitForExistence(timeout: 6), "Home plants page did not appear.")
    }

    @MainActor
    private func addPlantFromHomePlantsTab(named plantName: String, in app: XCUIApplication) {
        let addEntry = app.buttons["home-primary-action"]
        tapWhenHittable(addEntry, timeout: 8)

        typeText(plantName, intoTextField: "add-plant-name-input", in: app)
        typeText("Pothos", intoTextField: "add-plant-species-input", in: app)
        dismissKeyboardIfPresent(in: app)
        scrollToElement(app.textFields["add-plant-catalog-search-input"], in: app, maxSwipes: 2)
        typeText("pothos", intoTextField: "add-plant-catalog-search-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenFrameReady(app.buttons["add-plant-catalog-result-epipremnum-aureum"], timeout: 8)
        typeText("Living room", intoTextField: "add-plant-room-input", in: app)
        typeText("South window", intoTextField: "add-plant-location-input", in: app)
        dismissKeyboardIfPresent(in: app)

        scrollToElement(app.buttons["add-plant-save-action"], in: app, maxSwipes: 6)
        tapWhenHittable(app.buttons["add-plant-save-action"], timeout: 8)

        let didReturnToPlants = waitUntil(timeout: 20) {
            app.buttons["home-plants-card-\(plantName)"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", plantName)).firstMatch.exists
        }
        XCTAssertTrue(didReturnToPlants, "Adding a plant did not return to the Home plants page with the new plant visible.")
    }

    @MainActor
    private func assertHomePlantCard(named plantName: String, in app: XCUIApplication) {
        let card = app.buttons["home-plants-card-\(plantName)"]
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Home plants tab did not show the created plant card.")
    }

    @MainActor
    private func openPlantDetail(named plantName: String, in app: XCUIApplication) {
        let plantsTab = app.buttons["home-tab-plants"]
        if plantsTab.exists && plantsTab.isHittable {
            tapWhenHittable(plantsTab, timeout: 5)
        }
        let card = app.buttons["home-plants-card-\(plantName)"]
        XCTAssertTrue(card.waitForExistence(timeout: 14), "Plant card was not visible before opening detail.")
        tapWhenFrameReady(card, timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["plant-detail-screen"].waitForExistence(timeout: 14), "Plant detail did not open.")
        XCTAssertTrue(containsAnyMarker([plantName, "Next step", "Environment", "Care history"], in: app, timeout: 10), "Plant detail did not show expected content.")
    }

    @MainActor
    private func exercisePlantDetailCareAndDeleteUndo(named plantName: String, in app: XCUIApplication) {
        let soilWet = app.buttons["plant-detail-next-task-soil-wet-defer"]
        if soilWet.waitForExistence(timeout: 4) {
            tapWhenFrameReady(soilWet, timeout: 8)
        } else if app.buttons["plant-detail-next-task-defer"].waitForExistence(timeout: 4) {
            tapWhenFrameReady(app.buttons["plant-detail-next-task-defer"], timeout: 8)
        }

        scrollToElement(app.buttons["plant-detail-water-action"], in: app, maxSwipes: 5)
        tapWhenFrameReady(app.buttons["plant-detail-water-action"], timeout: 8)
        tapWhenFrameReady(app.buttons["plant-detail-fertilize-action"], timeout: 8)
        tapWhenFrameReady(app.buttons["plant-detail-care-action-pestCheck"], timeout: 8)
        tapWhenFrameReady(app.buttons["plant-detail-care-action-leafCleaning"], timeout: 8)

        scrollToElement(app.staticTexts["Care history"], in: app, maxSwipes: 4)
        XCTAssertTrue(containsAnyMarker(["Watering", "Fertilizing", "Pest", "Leaf", "Care history"], in: app, timeout: 10), "Plant care history did not reflect GUI care actions.")

        scrollToElement(app.buttons["plant-detail-delete-action"], in: app, maxSwipes: 8)
        tapWhenFrameReady(app.buttons["plant-detail-delete-action"], timeout: 8)
        tapWhenHittable(app.buttons["Delete"], timeout: 8)
        XCTAssertTrue(app.buttons["plant-detail-delete-undo"].waitForExistence(timeout: 8), "Plant delete undo banner did not appear.")
        tapWhenHittable(app.buttons["plant-detail-delete-undo"], timeout: 8)
        XCTAssertFalse(app.buttons["plant-detail-delete-now"].waitForExistence(timeout: 1.5), "Plant delete undo did not cancel the pending delete.")
        XCTAssertTrue(containsAnyMarker([plantName], in: app, timeout: 4), "Plant detail lost the plant after undoing delete.")
    }

    @MainActor
    private func openPlantReminderSettingsAndTogglePlant(named plantName: String, in app: XCUIApplication) {
        openSettingsFromHomeChrome(in: app)
        XCTAssertTrue(containsAnyMarker(["Plant care reminders"], in: app, timeout: 10), "Plant reminder settings panel did not appear in Settings.")
        let plantToggle = app.descendants(matching: .any)["settings-plant-reminders-plant-toggle-\(plantName)"]
        scrollToElement(plantToggle, in: app, maxSwipes: 8)
        XCTAssertTrue(plantToggle.waitForExistence(timeout: 8), "Per-plant reminder toggle did not appear.")
        tapWhenFrameReady(plantToggle, timeout: 8)
        XCTAssertTrue(containsAnyMarker(["muted", "已静音"], in: app, timeout: 8), "Per-plant reminder toggle did not show a muted status.")
        tapWhenFrameReady(plantToggle, timeout: 8)
        XCTAssertTrue(containsAnyMarker(["enabled", "已开启提醒"], in: app, timeout: 8), "Per-plant reminder toggle did not show an enabled status.")

        scrollToElement(app.buttons["settings-plant-reminders-defer-all"], in: app, maxSwipes: 3)
        tapWhenFrameReady(app.buttons["settings-plant-reminders-defer-all"], timeout: 8)
        XCTAssertTrue(containsAnyMarker(["Deferred", "No plant tasks are due", "已延后", "当前没有已到期"], in: app, timeout: 8), "Plant reminder bulk defer did not report a result.")
    }

    @MainActor
    private func openCalendarAndAssertPlantVisible(named plantName: String, in app: XCUIApplication) {
        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 12), "Calendar tab did not exist.")
        tapWhenHittable(calendarTab, timeout: 8)
        XCTAssertTrue(containsAnyMarker([plantName, "Pothos", "Water", "Fertilize"], in: app, timeout: 18), "Calendar did not surface any plant care content after plant creation.")
    }

    @MainActor
    private func permanentlyDeletePlant(named plantName: String, in app: XCUIApplication) {
        scrollToElement(app.buttons["plant-detail-delete-action"], in: app, maxSwipes: 8)
        tapWhenFrameReady(app.buttons["plant-detail-delete-action"], timeout: 8)
        tapWhenHittable(app.buttons["Delete"], timeout: 8)
        XCTAssertTrue(app.buttons["plant-detail-delete-now"].waitForExistence(timeout: 8), "Plant delete-now action did not appear.")
        tapWhenHittable(app.buttons["plant-detail-delete-now"], timeout: 8)

        let didLeaveDeletedDetail = waitUntil(timeout: 14) {
            !app.descendants(matching: .any)["plant-detail-screen"].exists || containsAnyMarker(["Content is no longer available"], in: app)
        }
        XCTAssertTrue(didLeaveDeletedDetail, "Permanent plant deletion did not remove the detail content.")
    }

    @MainActor
    private func returnFromPlantDetailToHome(in app: XCUIApplication) {
        if app.buttons["home-tab-plants"].exists && app.buttons["home-tab-plants"].isHittable {
            tapWhenHittable(app.buttons["home-tab-plants"], timeout: 4)
            return
        }
        if app.buttons["Back"].exists {
            tapWhenHittable(app.buttons["Back"], timeout: 4)
            return
        }
        let navBack = app.navigationBars.buttons.firstMatch
        if navBack.exists && navBack.isHittable {
            tapWhenHittable(navBack, timeout: 4)
            return
        }
        app.swipeRight()
        _ = waitUntil(timeout: 8) {
            app.buttons["home-tab-plants"].exists || app.buttons["home-primary-action"].exists
        }
    }

    @MainActor
    private func openSettingsFromHomeChrome(in app: XCUIApplication) {
        if app.buttons["home-tab-home"].exists && app.buttons["home-tab-home"].isHittable {
            tapWhenHittable(app.buttons["home-tab-home"], timeout: 4)
        }
        let settings = app.buttons["home-settings-action"]
        XCTAssertTrue(settings.waitForExistence(timeout: 12), "Home settings action did not appear.")
        tapWhenHittable(settings, timeout: 8)
        XCTAssertTrue(app.otherElements["settings-screen"].waitForExistence(timeout: 12), "Settings screen did not open.")
    }

    @MainActor
    private func closeSettingsToHome(in app: XCUIApplication) {
        if app.buttons["settings-close-action"].exists {
            tapWhenFrameReady(app.buttons["settings-close-action"], timeout: 4)
        } else {
            dismissCurrentSheetByDrag(in: app)
        }
        let didReturnHome = waitUntil(timeout: 12) {
            app.buttons["home-settings-action"].exists || app.buttons["home-primary-action"].exists
        }
        XCTAssertTrue(didReturnHome, "Settings did not close back to Home.")
    }

    @MainActor
    private func debugCoconutsEntry(in app: XCUIApplication) -> XCUIElement {
        let headerShortcut = app.descendants(matching: .any)["settings-debug-coconuts-shortcut"]
        if headerShortcut.exists { return headerShortcut }

        let identified = app.descendants(matching: .any)["settings-debug-coconuts"]
        if identified.exists { return identified }

        let debugLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Debug Coconuts")).firstMatch
        if debugLabel.exists { return debugLabel }

        return app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Debug Coconuts")).firstMatch
    }

    @MainActor
    private func advanceOnboardingIntroToMemberCreation(in app: XCUIApplication) {
        let introPrimary = app.buttons["onboarding-intro-primary-action"]
        let nameField = app.textFields["member-name-input"]
        XCTAssertTrue(waitUntil(timeout: 25) { introPrimary.exists || nameField.exists }, "Onboarding intro did not become available.")

        for _ in 0 ..< 6 where !(nameField.exists && nameField.isHittable) {
            guard introPrimary.exists else { break }
            tapWhenHittable(introPrimary, timeout: 8)
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        }

        XCTAssertTrue(waitUntil(timeout: 12) { nameField.exists && nameField.isHittable }, "Onboarding intro did not advance to member creation.")
    }

    @MainActor
    private func openFirstPetCreationFromTodayFocus(in app: XCUIApplication) {
        let nameField = app.textFields["member-name-input"]
        let addPetCard = app.buttons["home-add-first-pet-card"]
        let addPetAction = app.buttons["home-add-first-pet-action"]
        XCTAssertTrue(waitUntil(timeout: 20) { nameField.exists || addPetCard.exists || addPetAction.exists }, "Today Focus first-pet action did not appear.")
        if nameField.exists { return }
        XCTAssertTrue(tapWhenFrameReady(addPetCard, timeout: 6) || tapWhenFrameReady(addPetAction, timeout: 6), "Today Focus first-pet action was visible but not tappable.")
        XCTAssertTrue(nameField.waitForExistence(timeout: 12), "Pet creation did not open from Today Focus.")
    }

    @MainActor
    private func finishRequiredStarterGift(in app: XCUIApplication) {
        let finish = app.buttons["starter-gift-finish-action"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20), "Starter coconut gift unlock action did not appear.")
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Oasis tab should stay hidden until starter gift is tapped.")
        tapWhenHittable(finish, timeout: 8)
        XCTAssertTrue(app.buttons["home-tab-oasis"].waitForExistence(timeout: 8), "Oasis tab did not appear after starter gift.")
    }

    @MainActor
    private func createMember(
        in app: XCUIApplication,
        name: String,
        flowTitle: String,
        missingFieldMessage: String,
        completionMessage: String,
        starterPetWeight: String? = nil,
        postSaveMarkerIdentifiers: [String] = [],
        postSaveTextMarkers: [String] = []
    ) {
        let nameField = app.textFields["member-name-input"]
        XCTAssertTrue(waitUntil(timeout: 12) { nameField.exists && nameField.isHittable }, missingFieldMessage)
        nameField.tap()
        nameField.typeText(name)
        nameField.typeText("\n")
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        tapThroughMemberCreationSteps(in: app, starterPetWeight: starterPetWeight)

        let handoffTitle = app.staticTexts[flowTitle]
        let creationPrimary = app.buttons["member-creation-primary-action"]
        let didLeaveCreation = waitUntil(timeout: 30) {
            let didReachExpectedMarker = containsAnyElement(in: app, identifiers: postSaveMarkerIdentifiers)
            let didReachExpectedTextMarker = containsAnyText(in: app, texts: postSaveTextMarkers)
            return app.state == .runningForeground &&
                (didReachExpectedMarker || didReachExpectedTextMarker || (!nameField.exists && !creationPrimary.exists && !handoffTitle.exists))
        }
        XCTAssertTrue(didLeaveCreation, completionMessage)
    }

    @MainActor
    private func tapThroughMemberCreationSteps(in app: XCUIApplication, starterPetWeight: String? = nil) {
        let creationPrimary = app.buttons["member-creation-primary-action"]
        XCTAssertTrue(creationPrimary.waitForExistence(timeout: 8), "Member creation primary action did not appear.")
        var didTapFinalSave = false
        for _ in 0 ..< 8 {
            guard creationPrimary.exists else {
                didTapFinalSave = true
                break
            }
            if let starterPetWeight {
                fillStarterPetWeightIfNeeded(in: app, value: starterPetWeight, waitForInput: !creationPrimary.isEnabled)
            }
            let actionLabel = creationPrimary.label
            tapWhenHittable(creationPrimary, timeout: 8)
            if actionLabel.contains("Join Island") || actionLabel.contains("加入岛屿") || actionLabel.contains("Insel beitreten") {
                if waitUntil(timeout: 4, condition: { !creationPrimary.exists || !creationPrimary.isEnabled }) {
                    didTapFinalSave = true
                    break
                }
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
    private func fillStarterPetWeightIfNeeded(in app: XCUIApplication, value: String, waitForInput: Bool) {
        let weightInput = app.buttons["member-creation-pet-weight-input"]
        if waitForInput {
            XCTAssertTrue(weightInput.waitForExistence(timeout: 8), "Starter pet weight input did not appear.")
        } else {
            guard weightInput.exists else { return }
        }
        guard !weightInput.label.contains(value) else { return }
        tapWhenHittable(weightInput, timeout: 8)
        for key in value.map(String.init) {
            tapWhenHittable(app.buttons[key], timeout: 4)
        }
        if app.buttons["OK"].exists {
            tapWhenHittable(app.buttons["OK"], timeout: 4)
        }
        XCTAssertTrue(waitUntil(timeout: 8) { app.buttons["member-creation-primary-action"].isEnabled }, "Starter pet weight did not enable member creation.")
    }

    @MainActor
    private func typeText(_ text: String, intoTextField identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Text field did not appear: \(identifier)")
        scrollToElement(field, in: app, maxSwipes: 8)
        scrollElementAboveKeyboardIfNeeded(field, in: app)
        XCTAssertTrue(tapWhenFrameReady(field, timeout: 8), "Text field did not become tappable: \(identifier)")
        XCTAssertTrue(waitForKeyboardFocus(on: field, timeout: 4), "Text field did not receive keyboard focus: \(identifier)")
        field.typeText(text)
    }

    @MainActor
    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        guard app.keyboards.firstMatch.exists else { return }

        let returnKeyTitles = ["Done", "Return", "Search", "Go", "OK"]
        if let key = returnKeyTitles
            .map({ app.keyboards.buttons[$0] })
            .first(where: { $0.exists && $0.isHittable }) {
            key.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }

        if app.keyboards.firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.16)).tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }

        if app.keyboards.firstMatch.exists {
            let keyboard = app.keyboards.firstMatch
            keyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)))
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
    }

    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0 ..< maxSwipes where !element.exists || !element.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    @MainActor
    private func scrollElementAboveKeyboardIfNeeded(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0 ..< maxSwipes {
            guard element.exists else { return }
            let keyboard = app.keyboards.firstMatch
            guard keyboard.exists else { return }
            let keyboardTop = keyboard.frame.minY
            let elementBottom = element.frame.maxY
            guard isFiniteFrame(element.frame), isFiniteFrame(keyboard.frame), elementBottom > keyboardTop - 16 else { return }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    private func waitForKeyboardFocus(on element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            element.value(forKey: "hasKeyboardFocus") as? Bool == true
        }
    }

    @MainActor
    private func dismissCurrentSheetByDrag(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86))
        start.press(forDuration: 0.12, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    @MainActor
    private func dismissGrowthUnlockPopupIfPresent(in app: XCUIApplication) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let popup = app.descendants(matching: .any)["growth-unlock-popup"]
        guard popup.exists else { return }

        let later = app.buttons["growth-unlock-later-action"]
        let close = app.buttons["growth-unlock-close-action"]
        if tapWhenFrameReady(later, timeout: 4) || tapWhenFrameReady(close, timeout: 4) {
            _ = waitUntil(timeout: 5) { !popup.exists }
            return
        }

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        _ = waitUntil(timeout: 5) { !popup.exists }
    }

    @MainActor
    @discardableResult
    private func tapWhenFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let didBecomeFrameReady = waitForFrameReady(element, timeout: timeout)
        guard didBecomeFrameReady, isFiniteFrame(element.frame) else { return false }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }

    @MainActor
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval) {
        XCTAssertTrue(waitUntil(timeout: timeout) { element.exists && element.isEnabled && element.isHittable }, "Element did not become hittable: \(element)")
        element.tap()
    }

    private func waitForFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            guard element.exists, element.isEnabled else { return false }
            let frame = element.frame
            return frame.width > 1 && frame.height > 1 && isFiniteFrame(frame)
        }
    }

    private func treeLevelLabelIsAtLeast4(in app: XCUIApplication) -> Bool {
        let label = app.descendants(matching: .any)["oasis-tree-level-control"].label
        let normalized = label
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        for level in 4 ... 10 {
            if normalized.contains("level\(level)") ||
                normalized.contains("lv.\(level)") ||
                normalized.contains("lv\(level)") {
                return true
            }
        }
        return [
            "初现树形",
            "椰影婆娑",
            "果实初挂",
            "硕果累累",
            "参天古木",
            "灵树觉醒",
            "生命之树"
        ].contains { label.contains($0) }
    }

    private func containsAnyMarker(_ markers: [String], in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) { containsAnyMarker(markers, in: app) }
    }

    private func containsAnyMarker(_ markers: [String], in app: XCUIApplication) -> Bool {
        markers.contains { marker in
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", marker)
            return app.staticTexts.matching(predicate).firstMatch.exists ||
                app.buttons.matching(predicate).firstMatch.exists ||
                app.switches.matching(predicate).firstMatch.exists ||
                app.otherElements.matching(predicate).firstMatch.exists ||
                app.navigationBars.matching(predicate).firstMatch.exists
        }
    }

    private func containsAnyElement(in app: XCUIApplication, identifiers: [String]) -> Bool {
        identifiers.contains { app.descendants(matching: .any)[$0].exists }
    }

    private func containsAnyText(in app: XCUIApplication, texts: [String]) -> Bool {
        texts.contains { text in
            app.staticTexts[text].exists ||
                app.buttons[text].exists ||
                app.descendants(matching: .any)[text].exists
        }
    }

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    private func isFiniteFrame(_ frame: CGRect) -> Bool {
        frame.origin.x.isFinite &&
            frame.origin.y.isFinite &&
            frame.width.isFinite &&
            frame.height.isFinite &&
            frame.midX.isFinite &&
            frame.midY.isFinite
    }
}

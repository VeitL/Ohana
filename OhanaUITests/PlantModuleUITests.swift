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
        let app = launchEnglishApp(resetPersistentState: true, enableProductionOverlays: true)
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

        openPlantReminderSettingsAndTogglePlant(named: plantName, in: app)
        closeSettingsToHome(in: app)

        openCalendarAndAssertPlantVisible(named: plantName, in: app)

        openPlantDetail(named: plantName, in: app)
        exercisePlantDetailCareAndDeleteUndo(named: plantName, in: app)
        returnFromPlantDetailToHome(in: app)

        openPlantDetail(named: plantName, in: app)
        permanentlyDeletePlant(named: plantName, in: app)
    }

    @MainActor
    func testExistingPlantReminderToggleWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        ensureHouseholdHome(in: app)

        let plantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openSettingsFromHomeChrome(in: app)
        XCTAssertTrue(containsAnyMarker(["Plant care reminders"], in: app, timeout: 10), "Plant reminder settings panel did not appear in Settings.")
        let plantToggle = findPlantReminderToggle(named: plantName, in: app, maxSwipes: 18)

        assertPlantReminderToggleCanRoundTrip(plantToggle, in: app)
    }

    @MainActor
    func testExistingPlantDetailProfileSectionsWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        ensureHouseholdHome(in: app)

        let plantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openPlantDetail(named: plantName, in: app)

        XCTAssertTrue(app.descendants(matching: .any)["plant-detail-health-summary"].waitForExistence(timeout: 8), "Plant detail health summary did not appear.")
        XCTAssertTrue(app.descendants(matching: .any)["plant-detail-care-rhythm"].waitForExistence(timeout: 8), "Plant detail care rhythm did not appear.")
        scrollToElement(app.descendants(matching: .any)["plant-detail-growth-profile"], in: app, maxSwipes: 5)
        XCTAssertTrue(app.descendants(matching: .any)["plant-detail-growth-profile"].waitForExistence(timeout: 8), "Plant detail growth profile did not appear.")
    }

    @MainActor
    func testExistingPlantSettingsBulkDeferAndEditCancelSaveWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        ensureHouseholdHome(in: app)

        let originalPlantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openSettingsFromHomeChrome(in: app)
        XCTAssertTrue(containsAnyMarker(["Plant care reminders"], in: app, timeout: 10), "Plant reminder settings panel did not appear in Settings.")
        let bulkDefer = app.buttons["settings-plant-reminders-defer-all"]
        scrollToElement(bulkDefer, in: app, maxSwipes: 4)
        XCTAssertTrue(bulkDefer.waitForExistence(timeout: 8), "Plant reminder bulk defer action did not appear.")
        tapWhenFrameReady(bulkDefer, timeout: 8)

        closeSettingsToHome(in: app)
        openPlantDetail(named: originalPlantName, in: app)
        exercisePlantEditCancelAndSave(originalName: originalPlantName, in: app)
    }

    @MainActor
    private func launchEnglishApp(
        resetPersistentState: Bool = false,
        enableProductionOverlays: Bool = false
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
    private func ensureHouseholdHome(in app: XCUIApplication) {
        if app.buttons["home-settings-action"].waitForExistence(timeout: 8) {
            return
        }

        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)
        XCTAssertTrue(app.buttons["home-settings-action"].waitForExistence(timeout: 12), "Home did not become available after creating the baseline household.")
    }

    @MainActor
    private func seedPlantBaselineAndReturnHomePlantName(in app: XCUIApplication) -> String {
        openSettingsFromHomeChrome(in: app)
        seedPlantBaselineFromSettings(in: app)
        closeSettingsToHome(in: app)
        return openPlantsTabAndReturnFirstPlantName(in: app)
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
        dismissKeyboardIfPresent(in: app)
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
    private func openPlantsTabAndReturnFirstPlantName(in app: XCUIApplication) -> String {
        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 14), "Plants tab did not appear after seeding plant baseline.")
        tapWhenFrameReady(plantsTab, timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 12), "Home plants page did not open.")

        let firstPlantCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-plants-card-")).firstMatch
        XCTAssertTrue(firstPlantCard.waitForExistence(timeout: 12), "Home plants page did not show any plant card after seeding.")
        let prefix = "home-plants-card-"
        XCTAssertTrue(firstPlantCard.identifier.hasPrefix(prefix), "First plant card did not expose a plant-card identifier.")
        return String(firstPlantCard.identifier.dropFirst(prefix.count))
    }

    @MainActor
    private func exercisePlantEditCancelAndSave(originalName: String, in app: XCUIApplication) {
        let cancelledName = "\(originalName) Cancelled"
        openPlantEditSheet(in: app)
        replaceText(cancelledName, inTextField: "plant-edit-name-input", in: app)
        dismissKeyboardIfPresent(in: app)
        if !tapWhenFrameReady(app.buttons["ohana-sheet-close-action"], timeout: 4) {
            dismissCurrentSheetByDrag(in: app)
        }
        XCTAssertTrue(waitUntil(timeout: 10) { !app.descendants(matching: .any)["plant-edit-sheet"].exists }, "Plant edit sheet did not close after cancel.")
        assertPlantDetailName(originalName, in: app, timeout: 8, context: "after canceling edit")
        XCTAssertNotEqual(app.staticTexts["plant-detail-name"].label, cancelledName, "Plant edit cancel unexpectedly persisted the draft name.")

        let savedName = "\(originalName) Edited"
        openPlantEditSheet(in: app)
        replaceText(savedName, inTextField: "plant-edit-name-input", in: app)
        dismissKeyboardIfPresent(in: app)
        scrollToElement(app.buttons["plant-edit-save-action"], in: app, maxSwipes: 6)
        tapWhenFrameReady(app.buttons["plant-edit-save-action"], timeout: 8)
        XCTAssertTrue(waitUntil(timeout: 12) { !app.descendants(matching: .any)["plant-edit-sheet"].exists }, "Plant edit sheet did not close after saving.")
        assertPlantDetailName(savedName, in: app, timeout: 12, context: "after saving edit")
    }

    @MainActor
    private func assertPlantDetailName(_ expectedName: String, in app: XCUIApplication, timeout: TimeInterval, context: String) {
        let nameLabel = app.staticTexts["plant-detail-name"]
        XCTAssertTrue(nameLabel.waitForExistence(timeout: timeout), "Plant detail name did not appear \(context).")
        XCTAssertEqual(nameLabel.label, expectedName, "Plant detail name mismatch \(context).")
    }

    @MainActor
    private func openPlantEditSheet(in app: XCUIApplication) {
        let edit = app.buttons["plant-detail-edit-action"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Plant detail edit action did not appear.")
        tapWhenFrameReady(edit, timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["plant-edit-sheet"].waitForExistence(timeout: 10), "Plant edit sheet did not open.")
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
        let plantToggle = findPlantReminderToggle(named: plantName, in: app, maxSwipes: 18)
        XCTAssertTrue(plantToggle.waitForExistence(timeout: 8), "Per-plant reminder toggle did not appear.")
        assertPlantReminderToggleCanRoundTrip(plantToggle, in: app)
    }

    @MainActor
    private func assertPlantReminderToggleCanRoundTrip(_ plantToggle: XCUIElement, in app: XCUIApplication) {
        guard let startsEnabled = switchOnState(of: plantToggle) else {
            XCTFail("Per-plant reminder control did not expose an initial on/off value. label=\(plantToggle.label), value=\(String(describing: plantToggle.value ?? ""))")
            return
        }

        tapReminderToggleControl(plantToggle, in: app, timeout: 8)
        XCTAssertTrue(
            waitForSwitchOnState(plantToggle, toEqual: !startsEnabled, timeout: 8),
            "Per-plant reminder control did not switch to the opposite state. label=\(plantToggle.label), value=\(String(describing: plantToggle.value ?? ""))"
        )

        tapReminderToggleControl(plantToggle, in: app, timeout: 8)
        XCTAssertTrue(
            waitForSwitchOnState(plantToggle, toEqual: startsEnabled, timeout: 8),
            "Per-plant reminder control did not switch back to the original state. label=\(plantToggle.label), value=\(String(describing: plantToggle.value ?? ""))"
        )
    }

    @MainActor
    private func findPlantReminderToggle(named plantName: String, in app: XCUIApplication, maxSwipes: Int) -> XCUIElement {
        let identified = app.descendants(matching: .any)["settings-plant-reminders-plant-toggle-\(plantName)"]
        let labelled = app.scrollViews.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] %@ AND identifier != %@",
            plantName,
            "settings-plant-reminders-panel"
        )).firstMatch
        let section = app.descendants(matching: .any)["settings-plant-reminders-plant-section"]
        let emptyState = app.descendants(matching: .any)["settings-plant-reminders-empty-state"]

        for _ in 0 ..< maxSwipes {
            if isTapFrameVisible(identified, in: app) { return identified }
            if isTapFrameVisible(labelled, in: app) { return labelled }
            if emptyState.exists {
                XCTFail("Settings plant reminder panel loaded with no plants after creating \(plantName).")
                return identified
            }
            if section.exists {
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                if isTapFrameVisible(identified, in: app) { return identified }
                if isTapFrameVisible(labelled, in: app) { return labelled }
            }
            scrollTowardTapFrame(of: identified.exists ? identified : labelled, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        if emptyState.exists {
            XCTFail("Settings plant reminder panel loaded with no plants after creating \(plantName).")
        }
        return identified.exists ? identified : labelled
    }

    @MainActor
    private func findAnyPlantReminderToggle(in app: XCUIApplication, maxSwipes: Int) -> XCUIElement {
        let identified = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@",
            "settings-plant-reminders-plant-toggle-"
        )).firstMatch
        let emptyState = app.descendants(matching: .any)["settings-plant-reminders-empty-state"]

        for _ in 0 ..< maxSwipes {
            if isTapFrameVisible(identified, in: app) { return identified }
            if emptyState.exists { return identified }
            scrollTowardTapFrame(of: identified, in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return identified
    }

    @MainActor
    private func ensureAnyPlantReminderToggle(in app: XCUIApplication) -> XCUIElement {
        let existing = findAnyPlantReminderToggle(in: app, maxSwipes: 18)
        if isTapFrameVisible(existing, in: app) { return existing }

        seedPlantBaselineFromSettings(in: app)
        let seeded = findAnyPlantReminderToggle(in: app, maxSwipes: 18)
        XCTAssertTrue(waitForTapFrame(seeded, in: app, timeout: 8), "UI-test plant seed did not make a per-plant reminder toggle available.")
        return seeded
    }

    @MainActor
    private func seedPlantBaselineFromSettings(in app: XCUIApplication) {
        let seedShortcut = app.descendants(matching: .any)["settings-debug-plant-baseline-shortcut"]
        if seedShortcut.exists {
            XCTAssertTrue(tapWhenFrameReady(seedShortcut, timeout: 8), "Plant baseline seed shortcut did not become tappable.")
            RunLoop.current.run(until: Date().addingTimeInterval(0.8))
            return
        }

        let seedAction = app.descendants(matching: .any)["settings-debug-plant-baseline"]
        scrollTowardTopToElement(seedAction, in: app, maxSwipes: 8)
        if !seedAction.exists || !seedAction.isHittable {
            scrollToElement(seedAction, in: app, maxSwipes: 8)
        }
        XCTAssertTrue(seedAction.waitForExistence(timeout: 8), "Settings did not expose the UI-test plant baseline seed shortcut.")
        XCTAssertTrue(tapWhenFrameReady(seedAction, timeout: 8), "Plant baseline seed shortcut did not become tappable.")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    @MainActor
    private func findPlantReminderToggle(matching element: XCUIElement, in app: XCUIApplication, maxSwipes: Int) -> XCUIElement {
        let identifier = element.identifier
        guard !identifier.isEmpty else { return element }
        let identified = app.descendants(matching: .any)[identifier]
        for _ in 0 ..< maxSwipes {
            if identified.exists { return identified }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return identified.exists ? identified : element
    }

    @MainActor
    private func openCalendarAndAssertPlantVisible(named plantName: String, in app: XCUIApplication) {
        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 12), "Calendar tab did not exist.")
        tapWhenHittable(calendarTab, timeout: 8)

        let allFilter = app.buttons["calendar-filter-all"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 14), "Calendar screen did not open after tapping the Home Calendar tab.")
        tapWhenHittable(allFilter, timeout: 8)

        let listMode = app.buttons["calendar-view-mode-list"]
        XCTAssertTrue(listMode.waitForExistence(timeout: 10), "Calendar list-view toggle did not appear.")
        tapWhenHittable(listMode, timeout: 8)

        let plantPlanRow = app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier CONTAINS[c] %@",
                "calendar-event-row-",
                plantName
            ))
            .firstMatch
        if !waitUntil(timeout: 6, condition: { plantPlanRow.exists }) {
            for _ in 0 ..< 18 where !plantPlanRow.exists {
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        XCTAssertTrue(
            plantPlanRow.waitForExistence(timeout: 8),
            "Calendar did not surface any plant care row for \(plantName) after plant creation."
        )
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
        relaunchWithoutResetToHome(in: app)
    }

    @MainActor
    private func relaunchWithoutResetToHome(in app: XCUIApplication) {
        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launch()

        let didReturnHome = waitUntil(timeout: 20) {
            app.buttons["home-settings-action"].exists || app.buttons["home-primary-action"].exists
        }
        XCTAssertTrue(didReturnHome, "Relaunching after Settings did not return to Home.")
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
                if waitUntil(timeout: 4, condition: { !creationPrimary.exists }) {
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
        XCTAssertTrue(
            waitForKeyboardFocus(on: field, timeout: 2) || app.keyboards.firstMatch.waitForExistence(timeout: 2),
            "Text field did not receive keyboard input readiness: \(identifier)"
        )
        field.typeText(text)
        XCTAssertTrue(waitForTextField(field, toContain: text, timeout: 4), "Text field did not accept typed text: \(identifier)")
    }

    @MainActor
    private func replaceText(_ text: String, inTextField identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Text field did not appear: \(identifier)")
        scrollToElement(field, in: app, maxSwipes: 8)
        scrollElementAboveKeyboardIfNeeded(field, in: app)
        XCTAssertTrue(tapWhenFrameReady(field, timeout: 8), "Text field did not become tappable: \(identifier)")
        XCTAssertTrue(
            waitForKeyboardFocus(on: field, timeout: 2) || app.keyboards.firstMatch.waitForExistence(timeout: 2),
            "Text field did not receive keyboard input readiness: \(identifier)"
        )
        let currentValue = String(describing: field.value ?? "")
        if !currentValue.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        field.typeText(text)
        XCTAssertTrue(waitForTextField(field, toContain: text, timeout: 4), "Text field did not accept replacement text: \(identifier)")
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
    private func scrollTowardTopToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0 ..< maxSwipes where !element.exists || !element.isHittable {
            app.swipeDown()
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

    private func waitForTextField(_ element: XCUIElement, toContain text: String, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            let currentValue = String(describing: element.value ?? "")
            return currentValue.contains(text)
        }
    }

    private func waitForSwitchOnState(_ element: XCUIElement, toEqual expected: Bool, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            switchOnState(of: element) == expected
        }
    }

    private func switchOnState(of element: XCUIElement) -> Bool? {
        let rawValue = String(describing: element.value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch rawValue {
        case "1", "true", "on", "yes":
            return true
        case "0", "false", "off", "no":
            return false
        default:
            return nil
        }
    }

    @MainActor
    private func tapReminderToggleControl(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) {
        XCTAssertTrue(waitForTapFrame(element, in: app, timeout: timeout), "Reminder toggle did not become frame-ready: \(element)")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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

    private func waitForTapFrame(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            isTapFrameVisible(element, in: app)
        }
    }

    private func isTapFrameVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isEnabled else { return false }
        let frame = element.frame
        guard frame.width > 1, frame.height > 1, isFiniteFrame(frame) else { return false }
        return app.frame.insetBy(dx: 0, dy: 8).contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    @MainActor
    private func scrollTowardTapFrame(of element: XCUIElement, in app: XCUIApplication) {
        guard element.exists, isFiniteFrame(element.frame) else {
            app.swipeUp()
            return
        }
        if element.frame.midY < app.frame.minY {
            app.swipeDown()
        } else {
            app.swipeUp()
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

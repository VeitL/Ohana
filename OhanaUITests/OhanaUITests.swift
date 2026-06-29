//
//  OhanaUITests.swift
//  OhanaUITests
//
//  Created by Guanchenulous on 01.03.26.
//

import XCTest

final class OhanaUITests: XCTestCase {

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
    func testCreateFirstHumanFromOnboarding() throws {
        let app = launchEnglishApp()
        createFirstHuman(from: app)
    }

    @MainActor
    func testCreateFirstPetFromTodayFocusAfterFirstHuman() throws {
        let app = launchEnglishApp()
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)
    }

    @MainActor
    func testCreateFirstPetFromTodayFocusWithProductionOverlaysAfterFirstHuman() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(
            in: app,
            completionMessage: "Creating the first pet with production overlays did not leave the pet creation handoff in time."
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
    func testHumanFeatureHubRoutesOpenFromHome() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let routes: [HumanFeatureHubRouteExpectation] = [
            .init(tileIdentifier: "feature-hub-body-weight", markers: ["Weight trend", "Add weight", "Weight is private", "体重趋势", "添加体重", "体重记录仅本人可见"]),
            .init(tileIdentifier: "feature-hub-body-metrics", markers: ["Charts appear after you log a metric", "No checkup metrics yet", "Body data is private", "录入任意指标后会生成追踪图", "还没有体检指标记录", "身体数据仅本人可见"]),
            .init(tileIdentifier: "feature-hub-body-workout", markers: ["Co-health", "Co-health data is private", "人宠共健", "共健数据仅本人可见"]),
            .init(tileIdentifier: "feature-hub-body-report", markers: ["Health Reports", "Add Report", "No health reports yet", "身体检测报告", "添加报告", "还没有检测报告"]),
            .init(tileIdentifier: "feature-hub-care-medication", markers: ["No medication plan yet", "Add medication to see", "No medication yet", "还没有服药计划", "添加药物后", "还没有添加药物"]),
            .init(tileIdentifier: "feature-hub-care-basic", markers: ["\(humanName)'s Info", "\(humanName) 的信息"]),
            .init(tileIdentifier: "feature-hub-money-expense", markers: ["Timeline", "No expenses yet", "Period", "时间分布", "还没有花费记录", "本期"]),
            .init(tileIdentifier: "feature-hub-money-wishlist", markers: ["No wishes yet", "Make a wish", "还没有心愿", "许一个愿"]),
            .init(tileIdentifier: "feature-hub-money-notes", markers: ["Timeline", "Total", "Latest", "时间线", "总记录", "最近"]),
            .init(tileIdentifier: "feature-hub-account-profile", markers: ["\(humanName)'s Info", "\(humanName) 的信息"])
        ]

        for route in routes {
            openHumanFeatureHubFromHome(in: app, humanName: humanName)
            openHumanFeatureTile(route.tileIdentifier, in: app)
            assertAnyMarkerExists(route.markers, in: app, timeout: 18, context: route.tileIdentifier)
            closeCurrentSheetToHome(in: app, humanName: humanName)
        }
    }

    @MainActor
    func testHumanRecordOperationsPersistFromFeatureHub() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let expenseNote = "Codex human expense \(timestamp)"
        let medicationName = "Vitamin D"
        let noteText = "Codex human note \(timestamp)"

        saveHumanWeightFromFeatureHub(in: app, humanName: humanName)
        assertHumanFeatureRouteContains(
            "feature-hub-body-weight",
            markers: ["70.0", "70 kg", "70kg"],
            in: app,
            humanName: humanName
        )

        saveHumanExpenseFromFeatureHub(in: app, humanName: humanName, note: expenseNote)
        assertHumanFeatureRouteContains(
            "feature-hub-money-expense",
            markers: [expenseNote],
            in: app,
            humanName: humanName
        )

        saveHumanMedicationFromFeatureHub(in: app, humanName: humanName, medicationName: medicationName)
        assertHumanFeatureRouteContains(
            "feature-hub-care-medication",
            markers: [medicationName],
            in: app,
            humanName: humanName
        )

        saveHumanNoteFromFeatureHub(in: app, humanName: humanName, note: noteText)
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
    }

    @MainActor
    func testHumanExtendedModuleOperationsPersistFromFeatureHub() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let workoutNote = "Codex workout \(timestamp)"
        let reportHospital = "Codex Clinic \(timestamp)"
        let reportSummary = "Codex health report \(timestamp)"
        let wishTitle = "Codex wish \(timestamp)"
        let profileNote = "Codex profile note \(timestamp)"

        saveHumanHealthMetricFromFeatureHub(in: app, humanName: humanName)
        saveHumanWorkoutFromFeatureHub(in: app, humanName: humanName, note: workoutNote)
        saveHumanHealthReportFromFeatureHub(
            in: app,
            humanName: humanName,
            hospital: reportHospital,
            summary: reportSummary
        )
        saveHumanWishlistFromFeatureHub(in: app, humanName: humanName, title: wishTitle)
        saveHumanProfileNoteFromFeatureHub(in: app, humanName: humanName, note: profileNote)
    }

    @MainActor
    func testHumanWishlistRedeemSpendsCoconutsFromFeatureHub() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let wishTitle = "Codex redeem wish \(Int(Date().timeIntervalSince1970))"

        saveHumanWishlistFromFeatureHub(in: app, humanName: humanName, title: wishTitle)
        redeemHumanWishlistFromFeatureHub(in: app, humanName: humanName, title: wishTitle)
    }

    @MainActor
    func testHumanSettingsAccountPrivacyWritesFromGlobalSettings() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        openSettingsFromHomeChrome(in: app)

        let accountSwitcher = app.buttons["settings-human-account-switcher-action"]
        scrollToElement(accountSwitcher, in: app, maxSwipes: 3)
        XCTAssertTrue(
            accountSwitcher.waitForExistence(timeout: 12),
            "Settings did not expose the Human account switcher entry."
        )
        tapWhenHittable(accountSwitcher, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["human-account-switcher-sheet"].waitForExistence(timeout: 12),
            "Human account switcher did not open from Settings."
        )
        tapWhenHittable(app.buttons["human-account-active-card"], timeout: 8)

        let securitySheet = app.descendants(matching: .any)["human-account-security-sheet"]
        XCTAssertTrue(
            securitySheet.waitForExistence(timeout: 12),
            "Human account security sheet did not open for the active Human."
        )

        let allPrivateAction = app.buttons["human-account-privacy-all-private-action"]
        let allOpenAction = app.buttons["human-account-privacy-all-open-action"]
        XCTAssertTrue(waitForFrameReady(allPrivateAction, timeout: 8), "All-private privacy action was not reachable.")
        XCTAssertTrue(waitForFrameReady(allOpenAction, timeout: 8), "All-open privacy action was not reachable.")

        tapWhenHittable(allPrivateAction, timeout: 8)
        let privacyStatus = app.staticTexts["human-account-privacy-status"]
        XCTAssertTrue(
            waitUntil(timeout: 10) {
                let label = privacyStatus.label
                return label.contains("fields are private")
                    || label.contains("项设为仅本人可见")
                    || label.contains("Felder sind privat")
            },
            "Setting all Human privacy fields private did not update the Settings privacy status."
        )

        tapWhenHittable(app.buttons["human-account-privacy-all-open-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 10) {
                let label = privacyStatus.label
                return label.contains("All sensitive data")
                    || label.contains("所有敏感资料")
                    || label.contains("Alle sensiblen Daten")
            },
            "Reopening all Human privacy fields did not update the Settings privacy status."
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
        closeFeedDetailToHome(in: app)
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
        dismissInlinePottySheetByBackdrop(in: app)
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
        dismissInlinePottySheetByBackdrop(in: app)

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
                app.staticTexts["今天已经完成了"].exists || app.buttons["知道了"].exists
            },
            "Long-session repeat hygiene tap did not show the single-use guard."
        )
        tapWhenHittable(app.buttons["知道了"], timeout: 8)
        closeCurrentSheetToHome(in: app, humanName: humanName)

        openPetHealthDetailFromHome(in: app, petName: petName, humanName: humanName)
        let healthRecentRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "pet-health-recent-row-"))
            .firstMatch
        openPetHealthVisitPopup(in: app)
        tapWhenHittable(petHealthPopupButton(in: app, labels: ["关闭", "Close"]), timeout: 8)
        XCTAssertFalse(
            healthRecentRow.waitForExistence(timeout: 2),
            "Cancelling the long-session health popup created a recent health record."
        )
        openPetHealthVisitPopup(in: app)
        tapWhenHittable(petHealthPopupButton(in: app, labels: ["保存记录", "Save record"]), timeout: 8)
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
        XCTAssertEqual(balance.label, "0", "Long-session pet should reach Bond Vault with zero coconuts before seeding.")
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

        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launch()
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openPetBasicInfoFromHome(in: app, petName: petName)
        openPetBasicInfoEditMode(in: app)
        enterPetBasicInfoNote(cancelledNote, in: app)
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
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
        tapWhenHittable(app.buttons["取消"], timeout: 8)
        XCTAssertFalse(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 2),
            "Cancelling the dog long-session memorial mark still wrote a passed-away date."
        )

        tapWhenHittable(markAction, timeout: 8)
        tapWhenHittable(app.buttons["确认"], timeout: 8)
        let passedDate = app.staticTexts["pet-memorial-passed-date"]
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 12),
            "Confirming dog long-session memorial mark did not show the passed-away summary."
        )

        let undoAction = app.buttons["pet-memorial-undo-action"]
        scrollToElement(undoAction, in: app)
        tapWhenHittable(undoAction, timeout: 8)
        tapWhenHittable(app.buttons["取消"], timeout: 8)
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 4),
            "Cancelling dog long-session memorial undo unexpectedly cleared the passed-away date."
        )

        tapWhenHittable(undoAction, timeout: 8)
        tapWhenHittable(app.buttons["撤销"], timeout: 8)
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
        let app = launchEnglishApp(enableProductionOverlays: true)
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
            "Water \(petName)",
            "\(petName) 喂水",
            "\(petName) Wasser geben"
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

        tapWhenHittable(scoopAction, timeout: 8)
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
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Litter Plan Cat \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            petSpeciesLabel: "Cat",
            completionMessage: "Creating the first cat did not leave the pet creation handoff in time."
        )

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
        dismissInlinePottySheetByBackdrop(in: app)

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

        openLitterSettings(in: app)
        assertLitterSettingsStatus(
            in: app,
            containsAny: ["Reminder on", "提醒已开启", "Erinnerung an"],
            message: "Saving litter settings did not persist the reminder state."
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

        tapWhenHittable(recordAction, timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.staticTexts["今天已经完成了"].exists || app.buttons["知道了"].exists
            },
            "Repeating the same hygiene record did not show the single-use guard."
        )
        tapWhenHittable(app.buttons["知道了"], timeout: 8)
        XCTAssertTrue(
            app.descendants(matching: .any)["pet-hygiene-detail-screen"].waitForExistence(timeout: 8),
            "Dismissing the repeat hygiene guard did not return to the hygiene detail screen."
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
            app.descendants(matching: .any)["pet-health-record-inline-popup"].waitForExistence(timeout: 10),
            "Health visit action did not open the inline record popup."
        )
        tapWhenHittable(petHealthPopupButton(in: app, labels: ["关闭", "Close"]), timeout: 8)
        XCTAssertFalse(
            recentRow.waitForExistence(timeout: 2),
            "Cancelling the health record popup created a recent health record."
        )

        openPetHealthVisitPopup(in: app)
        let saveAction = petHealthPopupButton(in: app, labels: ["保存记录", "Save record"])
        XCTAssertTrue(
            saveAction.waitForExistence(timeout: 10),
            "Health record popup did not expose the save action."
        )
        tapWhenHittable(saveAction, timeout: 8)

        XCTAssertTrue(
            recentRow.waitForExistence(timeout: 18),
            "Health log did not appear in the recent health records after saving."
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
        let deletedPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        let didReturnResponsive = waitUntil(timeout: 20) {
            app.state == .runningForeground &&
                (deletedPrompt.isHittable || deletedPromptCard.isHittable || !deletedPetCard.isHittable) &&
                isHomeSurfaceResponsive(in: app)
        }
        XCTAssertTrue(didReturnResponsive, "Permanent pet deletion did not return to a responsive Home surface.")
        XCTAssertFalse(deletedPetCard.isHittable, "Deleted pet card is still visible on Home.")
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
        scrollToElement(app.buttons["pet-danger-delete-action"], in: app)
        tapWhenHittable(app.buttons["pet-danger-delete-action"], timeout: 8)

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

        let deletedPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                app.state == .runningForeground &&
                    !deletedPetCard.isHittable &&
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
        _ = createFirstHuman(from: app)
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
        tapWhenHittable(app.buttons["取消"], timeout: 8)
        XCTAssertFalse(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 2),
            "Cancelling the memorial mark alert still wrote a passed-away date."
        )

        tapWhenHittable(markAction, timeout: 8)
        tapWhenHittable(app.buttons["确认"], timeout: 8)
        let passedDate = app.staticTexts["pet-memorial-passed-date"]
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 12),
            "Confirming the memorial mark did not show the passed-away summary."
        )

        let undoAction = app.buttons["pet-memorial-undo-action"]
        scrollToElement(undoAction, in: app)
        tapWhenHittable(undoAction, timeout: 8)
        tapWhenHittable(app.buttons["取消"], timeout: 8)
        XCTAssertTrue(
            passedDate.waitForExistence(timeout: 4),
            "Cancelling the memorial undo alert unexpectedly cleared the passed-away date."
        )

        tapWhenHittable(undoAction, timeout: 8)
        tapWhenHittable(app.buttons["撤销"], timeout: 8)
        XCTAssertTrue(
            markAction.waitForExistence(timeout: 12),
            "Confirming memorial undo did not restore the live-pet mark action."
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

        openPetBasicInfoFromHome(in: app, petName: petName)
        let markAction = app.buttons["pet-memorial-mark-action"]
        scrollToElement(markAction, in: app)
        tapWhenHittable(markAction, timeout: 8)
        tapWhenHittable(app.buttons["确认"], timeout: 8)
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
        tapWhenHittable(app.buttons["确认"], timeout: 8)
        XCTAssertTrue(
            app.staticTexts["pet-memorial-passed-date"].waitForExistence(timeout: 12),
            "Confirming memorial mark did not show the passed-away summary before stale Calendar route check."
        )

        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        app.launch()
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        openCalendarTabFromHome(in: app, humanName: humanName)
        assertCalendarEvent(petEventTitle, exists: true, in: app, context: "memorial stale calendar row still visible")
        tapCalendarEvent(petEventTitle, in: app)

        XCTAssertTrue(
            waitUntil(timeout: 8) {
                app.state == .runningForeground
            },
            "Tapping a stale Calendar event for a memorial pet left the app unresponsive."
        )
        XCTAssertFalse(
            isAnyLivePetRouteVisible(in: app),
            "Tapping a stale Calendar event for a memorial pet opened a live care, health, walk, or economy route."
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
        let app = launchEnglishApp(enableProductionOverlays: true)
        let humanName = createFirstHuman(from: app)
        let petName = "Codex Bond Vault Spend Pet \(Int(Date().timeIntervalSince1970))"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openSettingsFromHomeChrome(in: app)
        let debugCoconuts = app.buttons["settings-debug-coconuts-shortcut"].exists
            ? app.buttons["settings-debug-coconuts-shortcut"]
            : app.buttons["settings-debug-coconuts"]
        XCTAssertTrue(
            debugCoconuts.waitForExistence(timeout: 12),
            "Settings did not expose the UI-test Debug Coconuts shortcut."
        )
        tapWhenHittable(debugCoconuts, timeout: 8)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

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
        tapWhenHittable(app.buttons["pet-basic-info-cancel-edit-action"], timeout: 8)
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
    func testPetCalendarEventRowOpensLinkedPetProfile() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-basic-info-screen"].waitForExistence(timeout: 18),
            "Tapping a pet-linked calendar event did not deep-link to the pet profile route."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) { containsAnyMarker([petName], in: app) },
            "The pet calendar deep-link opened a route that did not show the linked pet."
        )
    }

    @MainActor
    func testPetCalendarWaterEventRowOpensQuickWaterDetail() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["quick-water-detail-sheet"].waitForExistence(timeout: 18),
            "Tapping a pet-linked water calendar event did not deep-link to the pet Water detail route."
        )
    }

    @MainActor
    func testPetCalendarFeedEventRowOpensQuickFeedDetail() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        _ = createFirstHuman(from: app)
        let timestamp = Int(Date().timeIntervalSince1970)
        let petName = "Codex Calendar Feed Pet \(timestamp)"
        let petEventTitle = "Codex food reminder \(timestamp)"
        completeFirstDayStarterFunnel(
            in: app,
            petName: petName,
            completionMessage: "Creating the first pet did not leave the pet creation handoff in time."
        )

        openCalendarTab(in: app, petName: petName)
        addCalendarEvent(title: petEventTitle, linkedPetName: petName, in: app)
        tapCalendarEvent(petEventTitle, in: app)

        XCTAssertTrue(
            waitForQuickFeedHome(in: app, timeout: 18),
            "Tapping a pet-linked food calendar event did not deep-link to the pet Feeding detail route."
        )
    }

    @MainActor
    func testPetCalendarPottyEventRowOpensQuickPottyDetail() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["quick-potty-detail-sheet"].waitForExistence(timeout: 18),
            "Tapping a pet-linked potty calendar event did not deep-link to the pet Potty detail route."
        )
    }

    @MainActor
    func testPetCalendarWalkEventRowOpensWalkSummary() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["walk-summary-sheet"].waitForExistence(timeout: 18),
            "Tapping a pet-linked walk calendar event did not deep-link to the pet Walk summary route."
        )
    }

    @MainActor
    func testPetCalendarPlayEventRowOpensQuickPlayDetail() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["quick-play-detail-sheet"].waitForExistence(timeout: 18),
            "Tapping a pet-linked play calendar event did not deep-link to the pet Play detail route."
        )
    }

    @MainActor
    func testPetCalendarWeightEventRowOpensWeightDetail() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-weight-detail-screen"].waitForExistence(timeout: 18),
            "Tapping a pet-linked weight calendar event did not deep-link to the pet Weight detail route."
        )
    }

    @MainActor
    func testPetCalendarHealthEventRowOpensHealthDetail() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-health-detail-screen"].waitForExistence(timeout: 18),
            "Tapping a pet-linked health calendar event did not deep-link to the pet Health detail route."
        )
    }

    @MainActor
    func testPetCalendarHygieneEventRowOpensHygieneDetail() throws {
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

        XCTAssertTrue(
            app.descendants(matching: .any)["pet-hygiene-detail-screen"].waitForExistence(timeout: 18),
            "Tapping a pet-linked hygiene calendar event did not deep-link to the pet Hygiene detail route."
        )
    }

    @MainActor
    func testDailyStreakSheetOpensAndClosesFromHome() throws {
        let app = launchEnglishApp(enableProductionOverlays: true)
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        let streak = app.buttons["home-streak-action"]
        XCTAssertTrue(streak.waitForExistence(timeout: 20), "Home streak action did not appear.")
        tapWhenHittable(streak, timeout: 8)

        let streakTitle = app.staticTexts["打卡连击"]
        let close = app.buttons["ohana-sheet-close-action"]
        let didOpen = waitUntil(timeout: 12) {
            streakTitle.exists || close.exists
        }
        XCTAssertTrue(didOpen, "Daily streak screen did not open.")

        let closeCandidates = [
            close,
            app.buttons["Close"],
            app.buttons["关闭"]
        ]
        let didShowClose = waitUntil(timeout: 8) {
            closeCandidates.contains { $0.exists }
        }
        XCTAssertTrue(didShowClose, "Daily streak close action did not appear.")
        guard let visibleClose = closeCandidates.first(where: { $0.exists }) else {
            XCTFail("Daily streak close action did not appear.")
            return
        }
        tapWhenHittable(visibleClose, timeout: 8)

        let didClose = waitUntil(timeout: 12) {
            app.state == .runningForeground &&
                !streakTitle.exists &&
                !closeCandidates.contains { $0.exists } &&
                app.buttons["home-streak-action"].exists
        }
        XCTAssertTrue(didClose, "Daily streak sheet did not close promptly.")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchEnglishApp(enableProductionOverlays: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
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
    @discardableResult
    private func createFirstHuman(from app: XCUIApplication) -> String {
        let name = "Codex Human \(Int(Date().timeIntervalSince1970))"
        advanceOnboardingIntroToMemberCreation(in: app)
        createMember(
            in: app,
            name: name,
            flowTitle: "Create Member Card",
            missingFieldMessage: "Human creation name field did not appear.",
            completionMessage: "Creating the first human did not leave the creation flow in time.",
            postSaveMarkerIdentifiers: [
                "home-add-first-pet-card",
                "home-add-first-pet-action"
            ],
            postSaveTextMarkers: [
                "Create Pet Card",
                "制作宠物卡",
                "Tierkarte erstellen"
            ]
        )
        return name
    }

    @MainActor
    private func advanceOnboardingIntroToMemberCreation(in app: XCUIApplication) {
        let introPrimary = app.buttons["onboarding-intro-primary-action"]
        let nameField = app.textFields["member-name-input"]
        let didShowStartingSurface = waitUntil(timeout: 25) {
            introPrimary.exists || nameField.exists
        }
        XCTAssertTrue(didShowStartingSurface, "Onboarding intro did not become available.")

        for _ in 0 ..< 6 where !(nameField.exists && nameField.isHittable) {
            guard introPrimary.exists else {
                break
            }
            tapWhenHittable(introPrimary, timeout: 8)
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
        }

        let didReachMemberCreation = waitUntil(timeout: 12) {
            nameField.exists && nameField.isHittable
        }
        XCTAssertTrue(didReachMemberCreation, "Onboarding intro did not advance to member creation.")
    }

    @MainActor
    @discardableResult
    private func completeFirstDayStarterFunnel(
        in app: XCUIApplication,
        petName: String = "Codex Pet \(Int(Date().timeIntervalSince1970))",
        petSpeciesLabel: String? = nil,
        completionMessage: String = "Creating the first pet did not leave the pet creation handoff in time."
    ) -> String {
        openFirstPetCreationFromTodayFocus(in: app)
        createMember(
            in: app,
            name: petName,
            flowTitle: "Create Pet Card",
            missingFieldMessage: "Pet creation name field did not appear.",
            completionMessage: completionMessage,
            starterPetWeight: "7",
            petSpeciesLabel: petSpeciesLabel,
            postSaveMarkerIdentifiers: [
                "starter-gift-finish-action"
            ]
        )
        finishRequiredStarterGift(in: app)
        return petName
    }

    @MainActor
    private func finishRequiredStarterGift(in app: XCUIApplication) {
        let finish = app.buttons["starter-gift-finish-action"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20), "Starter coconut gift unlock action did not appear after the first human.")
        XCTAssertFalse(app.buttons["home-tab-oasis"].exists, "Oasis tab should stay hidden until the starter gift unlock action is tapped.")
        tapWhenHittable(finish, timeout: 8)
        XCTAssertTrue(app.buttons["home-tab-oasis"].waitForExistence(timeout: 8), "Oasis tab did not appear after unlocking the Coconut Tree.")
        XCTAssertTrue(
            app.descendants(matching: .any)["starter-oasis-tab-prompt"].waitForExistence(timeout: 8),
            "Oasis tab prompt did not appear after starter gift."
        )
    }

    @MainActor
    private func openFirstPetCreationFromTodayFocus(in app: XCUIApplication) {
        let nameField = app.textFields["member-name-input"]
        let addPetCard = app.buttons["home-add-first-pet-card"]
        let addPetAction = app.buttons["home-add-first-pet-action"]
        let didReachPetEntry = waitUntil(timeout: 20) {
            nameField.exists || addPetCard.exists || addPetAction.exists
        }
        XCTAssertTrue(didReachPetEntry, "Today Focus first-pet action did not appear.")
        if nameField.exists {
            return
        }
        let didTapEntry = tapWhenFrameReady(addPetCard, timeout: 6) || tapWhenFrameReady(addPetAction, timeout: 6)
        XCTAssertTrue(didTapEntry, "Today Focus first-pet action was visible but not tappable.")
        XCTAssertTrue(
            nameField.waitForExistence(timeout: 12),
            "Pet creation did not open from the Today Focus first-pet action."
        )
    }

    @MainActor
    private func openOasisAndInjectStarterEnergy(in app: XCUIApplication) {
        let oasisTab = app.buttons["home-tab-oasis"]
        XCTAssertTrue(oasisTab.waitForExistence(timeout: 20), "Oasis tab did not appear after member setup.")
        tapWhenHittable(oasisTab, timeout: 8)

        let oasisScreen = app.otherElements["oasis-screen"]
        XCTAssertTrue(oasisScreen.waitForExistence(timeout: 20), "Oasis did not become visible from the home tab.")

        let treeLevel = app.descendants(matching: .any)["oasis-tree-level-control"]
        XCTAssertTrue(treeLevel.waitForExistence(timeout: 12), "Oasis tree level control did not become visible.")
        XCTAssertTrue(treeLevel.label.contains("level 0"), "Fresh starter tree should begin at Lv0 before injection.")

        let injectEnergy = app.buttons["home-primary-action"]
        for attempt in 1 ... 4 {
            tapWhenHittable(injectEnergy, timeout: 8)
            let reachedEarly = waitUntil(timeout: 0.8) {
                app.descendants(matching: .any)["oasis-tree-level-control"].label.contains("level 1")
            }
            XCTAssertFalse(reachedEarly, "Starter energy reached Lv1 after only \(attempt) injection(s).")
        }

        tapWhenHittable(injectEnergy, timeout: 8)

        let didReachLevelOne = waitUntil(timeout: 20) {
            app.descendants(matching: .any)["oasis-tree-level-control"].label.contains("level 1")
        }
        XCTAssertTrue(didReachLevelOne, "Five starter energy injections did not advance the Oasis tree to Lv1.")
    }

    @MainActor
    private func openSettingsFromHomeChrome(in app: XCUIApplication) {
        let settings = app.buttons["home-settings-action"]
        XCTAssertTrue(settings.waitForExistence(timeout: 12), "Home settings action did not appear.")
        tapWhenHittable(settings, timeout: 8)

        let settingsScreen = app.otherElements["settings-screen"]
        XCTAssertTrue(settingsScreen.waitForExistence(timeout: 12), "Settings screen did not open from home chrome.")
    }

    @MainActor
    private func openHumanFeatureHubFromHome(in app: XCUIApplication, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let allFeaturesShortcut = app.buttons["home-expanded-shortcut-humanAllFeatures"]
        if !allFeaturesShortcut.exists || !allFeaturesShortcut.isHittable {
            expandHumanCardFromHome(in: app, humanName: humanName)
        }

        if !waitUntil(timeout: 4, condition: { allFeaturesShortcut.exists && allFeaturesShortcut.isHittable }) {
            tapWhenHittable(app.buttons["home-primary-action"], timeout: 8)
        }
        if !waitUntil(timeout: 5, condition: { allFeaturesShortcut.exists && allFeaturesShortcut.isHittable }) {
            collapseExpandedHumanCardIfNeeded(in: app, humanName: humanName)
            expandHumanCardFromHome(in: app, humanName: humanName)
            if !waitUntil(timeout: 3, condition: { allFeaturesShortcut.exists && allFeaturesShortcut.isHittable }) {
                tapWhenHittable(app.buttons["home-primary-action"], timeout: 8)
            }
        }
        XCTAssertTrue(
            waitUntil(timeout: 10, condition: { allFeaturesShortcut.exists && allFeaturesShortcut.isHittable }),
            "Expanded human card did not expose the Human All Features shortcut."
        )
        tapWhenHittable(allFeaturesShortcut, timeout: 8)

        XCTAssertTrue(
            app.buttons["feature-hub-body-weight"].waitForExistence(timeout: 14),
            "Human feature hub did not expose the body section."
        )
    }

    @MainActor
    private func expandHumanCardFromHome(in app: XCUIApplication, humanName: String) {
        let detailButton = app.buttons["home-expanded-detail-human"]
        if detailButton.exists && detailButton.isHittable { return }

        let humanCard = app.buttons["home-card-human-\(humanName)"]
        let humanCardByLabel = app.buttons.matching(NSPredicate(format: "label == %@", humanName)).firstMatch
        let targetCard = humanCard.exists ? humanCard : humanCardByLabel
        XCTAssertTrue(targetCard.waitForExistence(timeout: 20), "Human home card did not appear before opening the feature hub.")
        XCTAssertTrue(
            tapWhenFrameReady(targetCard, timeout: 8),
            "Human home card existed but did not expose a finite tappable frame."
        )

        let didExpand = waitUntil(timeout: 12) {
            detailButton.exists ||
                app.buttons["home-quick-action-humanWeight"].exists ||
                app.buttons["home-quick-action-humanMedication"].exists ||
                app.buttons["home-quick-action-humanExpense"].exists
        }
        XCTAssertTrue(didExpand, "Human home card did not finish expanding before opening the feature hub.")
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
    private func openHumanFeatureTile(_ identifier: String, in app: XCUIApplication) {
        let tile = app.buttons[identifier]
        scrollToElement(tile, in: app, maxSwipes: 6)
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "Human feature hub tile did not appear: \(identifier)")
        tapWhenHittable(tile, timeout: 8)
    }

    @MainActor
    private func assertHumanFeatureRouteContains(
        _ tileIdentifier: String,
        markers: [String],
        in app: XCUIApplication,
        humanName: String
    ) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile(tileIdentifier, in: app)
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
        if !action.exists || !action.isHittable {
            expandHumanCardFromHome(in: app, humanName: humanName)
        }

        XCTAssertTrue(
            waitUntil(timeout: 10) { action.exists && action.isEnabled && action.isHittable },
            "Expanded human card did not expose quick action: \(actionIdentifier)"
        )
        XCTAssertTrue(
            tapWhenFrameReady(action, timeout: 8),
            "Human home quick action did not have a tappable frame: \(actionIdentifier)"
        )

        let sheetMarker = app.staticTexts[sheetIdentifier]
        if !sheetMarker.waitForExistence(timeout: 1.5) {
            let menuIdentifier = actionIdentifier.replacingOccurrences(
                of: "home-quick-action-",
                with: "home-quick-action-menu-"
            )
            let quickMenuAction = app.buttons[menuIdentifier]
            XCTAssertTrue(
                quickMenuAction.waitForExistence(timeout: 8),
                "Human home quick action \(actionIdentifier) opened neither expected sheet nor inline menu: \(menuIdentifier)"
            )
            tapWhenHittable(quickMenuAction, timeout: 8)
        }

        XCTAssertTrue(
            sheetMarker.waitForExistence(timeout: 10),
            "Human home quick action \(actionIdentifier) did not open expected sheet marker: \(sheetIdentifier)"
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanWeightFromFeatureHub(in app: XCUIApplication, humanName: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-body-weight", in: app)
        tapWhenHittable(app.buttons["human-weight-add-action"], timeout: 8)

        XCTAssertTrue(
            app.staticTexts["generic-weight-entry-sheet-human"].waitForExistence(timeout: 10),
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
                !app.staticTexts["generic-weight-entry-sheet-human"].exists
            },
            "Human weight entry sheet did not dismiss after saving."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanExpenseFromFeatureHub(in app: XCUIApplication, humanName: String, note: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-money-expense", in: app)
        tapWhenHittable(app.buttons["human-expense-add-action"], timeout: 8)

        XCTAssertTrue(
            app.staticTexts["quick-human-expense-sheet"].waitForExistence(timeout: 10),
            "Human quick expense sheet did not open."
        )
        tapWhenHittable(app.buttons["quick-human-expense-amount-0"], timeout: 8)
        typeText(note, intoTextField: "quick-human-expense-note-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["quick-human-expense-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !app.staticTexts["quick-human-expense-sheet"].exists
            },
            "Human expense sheet did not dismiss after saving."
        )
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanMedicationFromFeatureHub(in app: XCUIApplication, humanName: String, medicationName: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-care-medication", in: app)
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
    private func saveHumanNoteFromFeatureHub(in app: XCUIApplication, humanName: String, note: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-money-notes", in: app)
        tapWhenHittable(app.buttons["human-note-add-action"], timeout: 8)

        XCTAssertTrue(
            app.staticTexts["quick-human-note-sheet"].waitForExistence(timeout: 10),
            "Human quick note sheet did not open."
        )
        typeText(note, intoTextView: "quick-human-note-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["quick-human-note-save-action"], timeout: 8)
        assertAnyMarkerExists([note], in: app, timeout: 14, context: "human note save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanHealthMetricFromFeatureHub(in app: XCUIApplication, humanName: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-body-metrics", in: app)

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
    private func saveHumanWorkoutFromFeatureHub(in app: XCUIApplication, humanName: String, note: String) {
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
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let detailButton = app.buttons["home-expanded-detail-human"]
        if !detailButton.exists || !detailButton.isHittable {
            expandHumanCardFromHome(in: app, humanName: humanName)
        }

        XCTAssertTrue(
            waitUntil(timeout: 10) { detailButton.exists && detailButton.isEnabled && detailButton.isHittable },
            "Expanded human card did not expose the human detail entry."
        )
        tapWhenHittable(detailButton, timeout: 8)

        let addWorkout = app.buttons["human-workout-add-action"]
        scrollToElement(addWorkout, in: app, maxSwipes: 10)
        XCTAssertTrue(
            addWorkout.waitForExistence(timeout: 14),
            "Human profile did not expose the Workout add action."
        )
    }

    @MainActor
    private func saveHumanHealthReportFromFeatureHub(
        in app: XCUIApplication,
        humanName: String,
        hospital: String,
        summary: String
    ) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-body-report", in: app)
        tapWhenHittable(app.buttons["human-health-report-add-action"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["add-human-health-report-sheet"].waitForExistence(timeout: 10),
            "Human health report add sheet did not open."
        )
        typeText(hospital, intoTextField: "add-human-health-report-hospital-input", in: app)
        dismissKeyboardIfPresent(in: app)
        let summaryInput = app.textViews["add-human-health-report-summary-input"]
        scrollToElement(summaryInput, in: app, maxSwipes: 4)
        typeText(summary, intoTextView: "add-human-health-report-summary-input", in: app)
        dismissKeyboardIfPresent(in: app)
        scrollToElement(app.buttons["add-human-health-report-save-action"], in: app, maxSwipes: 4)
        tapWhenHittable(app.buttons["add-human-health-report-save-action"], timeout: 8)
        assertAnyMarkerExists([hospital, summary], in: app, timeout: 18, context: "human health report save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanWishlistFromFeatureHub(in app: XCUIApplication, humanName: String, title: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-money-wishlist", in: app)
        tapWhenHittable(app.buttons["human-wishlist-add-action"], timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["add-human-wishlist-sheet"].waitForExistence(timeout: 8),
            "Human wishlist add sheet did not open."
        )
        typeText(title, intoTextField: "add-human-wishlist-title-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["add-human-wishlist-save-action"], timeout: 8)
        assertAnyMarkerExists([title], in: app, timeout: 14, context: "human wishlist save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func redeemHumanWishlistFromFeatureHub(in app: XCUIApplication, humanName: String, title: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-money-wishlist", in: app)
        assertAnyMarkerExists([title], in: app, timeout: 14, context: "human wishlist pending wish")

        let redeem = app.buttons["human-wishlist-redeem-action"]
        XCTAssertTrue(
            waitUntil(timeout: 10) {
                redeem.exists && redeem.isEnabled && redeem.isHittable
            },
            "Human wishlist redeem action did not become available. The starter coconut gift may not have reached the human wallet."
        )
        tapWhenHittable(redeem, timeout: 8)

        XCTAssertTrue(
            app.descendants(matching: .any)["human-wishlist-redeemed-state"].waitForExistence(timeout: 14),
            "Human wishlist did not move the item into the redeemed state after spending coconuts."
        )
        assertAnyMarkerExists(["Redeemed", "已兑换", title], in: app, timeout: 8, context: "human wishlist redeem")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func saveHumanProfileNoteFromFeatureHub(in app: XCUIApplication, humanName: String, note: String) {
        openHumanFeatureHubFromHome(in: app, humanName: humanName)
        openHumanFeatureTile("feature-hub-account-profile", in: app)

        tapWhenHittable(app.buttons["human-basic-info-edit-action"], timeout: 8)
        let noteInput = app.textViews["human-basic-info-notes-input"]
        scrollToElement(noteInput, in: app, maxSwipes: 8)
        typeText(note, intoTextView: "human-basic-info-notes-input", in: app)
        dismissKeyboardIfPresent(in: app)
        tapWhenHittable(app.buttons["human-basic-info-save-action"], timeout: 8)
        assertAnyMarkerExists([note], in: app, timeout: 14, context: "human profile note save")
        closeCurrentSheetToHome(in: app, humanName: humanName)
    }

    @MainActor
    private func ensureHomeSurfaceVisible(in app: XCUIApplication, humanName: String) {
        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists && homeTab.isHittable {
            tapWhenHittable(homeTab, timeout: 4)
        }

        let humanCard = app.buttons[humanName]
        let didReachHome = waitUntil(timeout: 14) {
            app.state == .runningForeground &&
                (humanCard.exists || app.buttons["home-primary-action"].exists)
        }
        XCTAssertTrue(didReachHome, "Home surface did not become visible before human route testing.")
    }

    @MainActor
    private func openFeedDetailFromHome(
        in app: XCUIApplication,
        petName: String,
        usingDetailMenuWhenAvailable: Bool = false
    ) {
        ensureHomeFeedQuickActionVisible(in: app, petName: petName)
        tapHomeFeedQuickAction(in: app, timeout: 8)

        let detailButton = app.buttons["home-quick-action-menu-feed-detail"]
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

        let detailAction = app.buttons["home-quick-action-menu-\(actionType)-detail"]
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

        let menuAction = app.buttons["home-quick-action-menu-\(actionType)"]
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

        let detailAction = app.buttons["home-quick-action-menu-water-detail"]
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
        tapWhenHittable(action, timeout: 8)
        let quickStart = app.buttons["home-quick-action-menu-walk"]
        if quickStart.waitForExistence(timeout: 3) {
            tapWhenHittable(quickStart, timeout: 8)
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
        let visitAction = app.buttons
            .matching(NSPredicate(format: "label IN %@", ["就诊", "Visit record", "Log visit", "Besuchseintrag"]))
            .firstMatch
        scrollToElement(visitAction, in: app, maxSwipes: 4)
        XCTAssertTrue(
            visitAction.waitForExistence(timeout: 12),
            "Pet health detail did not expose the visit record action."
        )
        tapWhenHittable(visitAction, timeout: 8)
    }

    @MainActor
    private func petHealthPopupButton(in app: XCUIApplication, labels: [String]) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label IN %@", "pet-health-record-inline-popup", labels)
        ).firstMatch
    }

    @MainActor
    private func openPetFeatureHubFromHome(in app: XCUIApplication, petName: String, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        ensureHomeSurfaceVisible(in: app, humanName: humanName)

        let petCard = app.buttons["home-card-pet-\(petName)"]
        let fallbackPetCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(petCard.waitForExistence(timeout: 20), "Pet home card did not appear before opening the feature hub.")

        let allFeaturesShortcut = app.buttons["home-expanded-shortcut-allFeatures"]
        for _ in 0 ..< 3 where !allFeaturesShortcut.exists || !allFeaturesShortcut.isHittable {
            let targetCard = petCard.exists ? petCard : fallbackPetCard
            if targetCard.exists && targetCard.isHittable {
                tapWhenHittable(targetCard, timeout: 8)
            }
            if allFeaturesShortcut.waitForExistence(timeout: 3), allFeaturesShortcut.isHittable {
                break
            }

            let primaryAction = app.buttons["home-primary-action"]
            if primaryAction.exists && primaryAction.isHittable {
                tapWhenHittable(primaryAction, timeout: 8)
            }
            if allFeaturesShortcut.waitForExistence(timeout: 3), allFeaturesShortcut.isHittable {
                break
            }

            if app.buttons["home-tab-home"].exists {
                tapWhenHittable(app.buttons["home-tab-home"], timeout: 5)
            }
        }
        XCTAssertTrue(
            allFeaturesShortcut.waitForExistence(timeout: 8),
            "Expanded pet card did not expose the All Features shortcut."
        )
        tapWhenHittable(allFeaturesShortcut, timeout: 8)

        XCTAssertTrue(
            app.buttons["feature-hub-daily-food"].waitForExistence(timeout: 14),
            "Pet feature hub did not expose the daily section."
        )
    }

    @MainActor
    private func saveManualFeedingDefault(in app: XCUIApplication) {
        let saveManualSettings = app.buttons["quick-feed-manual-settings-save"]
        if !saveManualSettings.waitForExistence(timeout: 4) {
            tapWhenHittable(app.buttons["quick-feed-primary-action"], timeout: 8)
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
    private func closeFeedDetailToHome(in app: XCUIApplication) {
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
        tapWhenHittable(close, timeout: 8)

        let didReturnHome = waitForFrameReady(app.buttons["home-quick-action-feed"], timeout: 15)
        XCTAssertTrue(didReturnHome, "Closing Feed detail did not return to a responsive home card.")
        assertHomeFeedReady(in: app)
    }

    @MainActor
    private func performHomeFeedQuickCheckIn(
        in app: XCUIApplication,
        petName: String,
        expectsAntiRepeatConfirmation: Bool
    ) {
        ensureHomeFeedQuickActionVisible(in: app, petName: petName)
        tapHomeFeedQuickAction(in: app, timeout: 8)

        let quickButton = app.buttons["home-quick-action-menu-feed"]
        if quickButton.waitForExistence(timeout: 4) {
            tapWhenHittable(quickButton, timeout: 8)
        } else if waitForQuickFeedHome(in: app, timeout: 2) {
            tapWhenHittable(app.buttons["quick-feed-primary-action"], timeout: 8)
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
        let petCard = app.buttons.matching(NSPredicate(format: "label == %@", petName)).firstMatch
        XCTAssertTrue(petCard.waitForExistence(timeout: 20), "Pet home card did not appear before opening basic info.")
        tapWhenHittable(petCard, timeout: 8)

        let allFeaturesShortcut = app.buttons["home-expanded-shortcut-allFeatures"]
        if !allFeaturesShortcut.waitForExistence(timeout: 3) {
            tapWhenHittable(app.buttons["home-primary-action"], timeout: 8)
        }
        XCTAssertTrue(allFeaturesShortcut.waitForExistence(timeout: 8), "Expanded card did not expose the All Features shortcut.")
        tapWhenHittable(allFeaturesShortcut, timeout: 8)

        let basicInfoTile = app.buttons["feature-hub-archive-basicInfo"]
        XCTAssertTrue(basicInfoTile.waitForExistence(timeout: 12), "Pet feature hub did not expose the Profile tile.")
        tapWhenHittable(basicInfoTile, timeout: 8)

        let basicInfoScreen = app.descendants(matching: .any)["pet-basic-info-screen"]
        XCTAssertTrue(basicInfoScreen.waitForExistence(timeout: 12), "Pet basic info screen did not open.")
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
        value.isEmpty || value == "名字"
    }

    @MainActor
    private func openCalendarTab(in app: XCUIApplication, petName: String) {
        let petCard = app.buttons["home-card-pet-\(petName)"]
        XCTAssertTrue(petCard.waitForExistence(timeout: 20), "Pet home card did not appear before opening pet Calendar context.")
        if app.buttons["home-expanded-detail-pet"].exists {
            tapWhenHittable(petCard, timeout: 8)
            XCTAssertTrue(
                waitUntil(timeout: 10) { !app.buttons["home-expanded-detail-pet"].exists },
                "Expanded pet card did not collapse before opening global Calendar."
            )
        }

        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 20), "Calendar tab did not appear after starter setup.")
        tapWhenHittable(calendarTab, timeout: 8)
        XCTAssertTrue(
            app.buttons["calendar-filter-all"].waitForExistence(timeout: 14),
            "Calendar screen did not open from the Home tab."
        )
    }

    @MainActor
    private func openCalendarTabFromHome(in app: XCUIApplication, humanName: String) {
        ensureHomeSurfaceVisible(in: app, humanName: humanName)
        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 20), "Calendar tab did not appear from Home.")
        tapWhenHittable(calendarTab, timeout: 8)
        XCTAssertTrue(
            app.buttons["calendar-filter-all"].waitForExistence(timeout: 14),
            "Calendar screen did not open from Home."
        )
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
        tapWhenHittable(app.buttons["home-primary-action"], timeout: 8)
        XCTAssertTrue(
            app.textFields["add-event-title-input"].waitForExistence(timeout: 10),
            "Calendar add-event sheet did not open."
        )
        typeText(title, intoTextField: "add-event-title-input", in: app)
        dismissKeyboardIfPresent(in: app)
        if let linkedPetName {
            let petChip = app.buttons["add-event-related-pet-\(linkedPetName)"]
            scrollToElement(petChip, in: app, maxSwipes: 8)
            tapWhenHittable(petChip, timeout: 8)
        }
        tapWhenHittable(app.buttons["add-event-save-action"], timeout: 8)
        XCTAssertTrue(
            waitUntil(timeout: 14) {
                !app.textFields["add-event-title-input"].exists
            },
            "Calendar add-event sheet did not close after saving \(title)."
        )
        assertCalendarEvent(title, exists: expectVisibleAfterSave, in: app, context: "post-save readback")
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
        ].contains { identifier in
            app.descendants(matching: .any)[identifier].exists
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
    private func closeCurrentSheetToHome(in app: XCUIApplication, humanName: String) {
        closeCurrentSheetToHomeIfNeeded(in: app, humanName: humanName)
        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists && homeTab.isEnabled && homeTab.isHittable {
            tapWhenHittable(homeTab, timeout: 5)
        }
        let didReturnHome = waitUntil(timeout: 16) {
            app.state == .runningForeground &&
                (app.buttons[humanName].exists ||
                    app.buttons["home-primary-action"].exists ||
                    app.buttons["home-tab-home"].exists)
        }
        XCTAssertTrue(didReturnHome, "Closing the human feature route did not return to Home.")
    }

    @MainActor
    private func closeCurrentSheetToHomeIfNeeded(in app: XCUIApplication, humanName: String) {
        if app.buttons[humanName].isHittable || app.buttons["home-primary-action"].isHittable,
           !app.buttons["feature-hub-body-weight"].exists,
           !containsAnyMarker(["Weight trend", "Charts appear after you log a metric", "Co-health Report", "Health Reports", "No medication plan yet", "No expenses yet", "No wishes yet", "Timeline"], in: app) {
            return
        }

        let closeCandidates = [
            app.buttons["human-basic-info-close-action"],
            app.buttons["ohana-sheet-close-action"],
            app.buttons["xmark"].firstMatch,
            app.buttons["Close"].firstMatch,
            app.buttons["Done"].firstMatch,
            app.buttons["关闭"].firstMatch,
            app.buttons["完成"].firstMatch
        ]

        if let close = closeCandidates.first(where: { $0.exists && $0.isEnabled && $0.isHittable }) {
            tapWhenHittable(close, timeout: 5)
        } else {
            let homeTab = app.buttons["home-tab-home"]
            let backCandidates = [
                app.buttons["BackButton"],
                app.buttons["Back"],
                app.buttons["返回"]
            ]
            if homeTab.exists && homeTab.isEnabled && homeTab.isHittable {
                tapWhenHittable(homeTab, timeout: 5)
            } else if let back = backCandidates.first(where: { $0.exists && $0.isEnabled && $0.isHittable }) {
                tapWhenHittable(back, timeout: 5)
            } else {
                dismissCurrentSheetByDrag(in: app)
            }
        }

        _ = waitUntil(timeout: 8) {
            app.buttons[humanName].isHittable || app.buttons["home-primary-action"].isHittable
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
    private func dismissInlinePottySheetByBackdrop(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !app.descendants(matching: .any)["quick-potty-litter-settings-sheet"].exists
            },
            "Inline potty sheet did not dismiss after tapping the backdrop."
        )
    }

    @MainActor
    private func closeHumanProfileToHome(in app: XCUIApplication, humanName: String) {
        if app.buttons[humanName].isHittable || app.buttons["home-primary-action"].isHittable {
            return
        }

        let homeTab = app.buttons["home-tab-home"]
        if homeTab.exists && homeTab.isHittable {
            tapWhenHittable(homeTab, timeout: 5)
        } else {
            let navigationBack = app.navigationBars.buttons.element(boundBy: 0)
            if navigationBack.exists && navigationBack.isEnabled && navigationBack.isHittable {
                tapWhenHittable(navigationBack, timeout: 5)
            } else {
                app.swipeRight()
            }
        }

        let didReturnHome = waitUntil(timeout: 14) {
            app.state == .runningForeground &&
                (app.buttons[humanName].isHittable || app.buttons["home-primary-action"].isHittable)
        }
        XCTAssertTrue(didReturnHome, "Closing the human profile did not return to Home.")
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
        postSaveMarkerIdentifiers: [String] = [],
        postSaveTextMarkers: [String] = []
    ) {
        let nameField = app.textFields["member-name-input"]
        let didShowNameField = waitUntil(timeout: 12) {
            nameField.exists && nameField.isHittable
        }
        XCTAssertTrue(didShowNameField, missingFieldMessage)

        nameField.tap()
        nameField.typeText(name)
        nameField.typeText("\n")
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))

        if let petSpeciesLabel {
            selectMemberCreationPetSpecies(petSpeciesLabel, in: app)
        }

        tapThroughMemberCreationSteps(in: app, starterPetWeight: starterPetWeight)

        let handoffTitle = app.staticTexts[flowTitle]
        let creationPrimary = app.buttons["member-creation-primary-action"]
        let didLeaveCreation = waitUntil(timeout: 30) {
            let didReachExpectedMarker = containsAnyElement(in: app, identifiers: postSaveMarkerIdentifiers)
            let didReachExpectedTextMarker = containsAnyText(in: app, texts: postSaveTextMarkers)
            return app.state == .runningForeground &&
                (didReachExpectedMarker ||
                    didReachExpectedTextMarker ||
                    (!nameField.exists &&
                        !creationPrimary.exists &&
                        !handoffTitle.exists))
        }
        XCTAssertTrue(didLeaveCreation, completionMessage)
    }

    @MainActor
    private func selectMemberCreationPetSpecies(_ speciesLabel: String, in app: XCUIApplication) {
        let speciesMenu = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@ OR label CONTAINS %@", "Species", "物种", "Art"))
            .firstMatch
        XCTAssertTrue(
            speciesMenu.waitForExistence(timeout: 8),
            "Pet creation species menu did not appear before selecting \(speciesLabel)."
        )
        tapWhenHittable(speciesMenu, timeout: 8)

        let optionLabels: [String] = switch speciesLabel.lowercased() {
        case "cat", "猫", "katze":
            ["Cat", "猫", "Katze"]
        case "dog", "狗", "hund":
            ["Dog", "狗", "Hund"]
        default:
            [speciesLabel]
        }
        let option = app.buttons
            .matching(NSPredicate(format: "label IN %@", optionLabels))
            .firstMatch
        XCTAssertTrue(
            option.waitForExistence(timeout: 8),
            "Pet creation species option did not appear: \(optionLabels)."
        )
        tapWhenHittable(option, timeout: 8)
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
        XCTAssertTrue(tapWhenFrameReady(target, timeout: 8), "Text field did not become tappable: \(identifier)")
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
        XCTAssertTrue(tapWhenFrameReady(target, timeout: 8), "Text view did not become tappable: \(identifier)")
        target.typeText(text)
    }

    @MainActor
    private func dismissKeyboardIfPresent(in app: XCUIApplication) {
        if app.keyboards.firstMatch.exists {
            let doneLabels = ["Done", "done", "完成", "隐藏键盘", "Hide keyboard"]
            if let done = doneLabels
                .map({ app.buttons[$0] })
                .first(where: { $0.exists && $0.isEnabled && $0.isHittable }) {
                done.tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                return
            }
            app.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
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
                fillStarterPetWeightIfNeeded(
                    in: app,
                    value: starterPetWeight,
                    waitForInput: !creationPrimary.isEnabled
                )
            }
            let actionLabel = creationPrimary.label
            let didBecomeReadyOrLeave = waitUntil(timeout: 8) {
                !creationPrimary.exists || (creationPrimary.isEnabled && creationPrimary.isHittable)
            }
            XCTAssertTrue(didBecomeReadyOrLeave, "Member creation primary action did not become ready.")
            guard creationPrimary.exists else {
                didTapFinalSave = true
                break
            }
            creationPrimary.tap()
            if isMemberCreationFinalActionLabel(actionLabel) {
                didTapFinalSave = true
                RunLoop.current.run(until: Date().addingTimeInterval(0.8))
                if !creationPrimary.exists {
                    break
                }
                continue
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.45))
            if !creationPrimary.exists {
                didTapFinalSave = true
                break
            }
        }
        XCTAssertTrue(didTapFinalSave, "Member creation did not reach the final save action.")
    }

    private func isMemberCreationFinalActionLabel(_ label: String) -> Bool {
        label.contains("Join Island")
            || label.contains("加入岛屿")
            || label.contains("Insel beitreten")
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

        let ok = app.buttons["OK"]
        if ok.exists {
            tapWhenHittable(ok, timeout: 4)
        }

        let didEnablePrimary = waitUntil(timeout: 8) {
            app.buttons["member-creation-primary-action"].isEnabled
        }
        XCTAssertTrue(didEnablePrimary, "Starter pet weight did not enable member creation.")
    }

    @MainActor
    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval) {
        let didBecomeHittable = waitUntil(timeout: timeout) {
            element.exists && element.isEnabled && element.isHittable
        }
        let elementValue = element.value.map { String(describing: $0) } ?? "nil"
        XCTAssertTrue(
            didBecomeHittable,
            "Element did not become hittable: \(element) exists=\(element.exists) enabled=\(element.isEnabled) hittable=\(element.isHittable) frame=\(element.frame) label=\(element.label) value=\(elementValue)"
        )
        element.tap()
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
            guard element.exists else { return false }
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

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    private struct HumanFeatureHubRouteExpectation {
        let tileIdentifier: String
        let markers: [String]
    }

    private struct PetFeatureHubRouteExpectation {
        let tileIdentifier: String
        let markerIdentifier: String
    }
}

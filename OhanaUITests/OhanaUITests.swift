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

        performHomeFeedQuickCheckIn(in: app, petName: petName, expectsAntiRepeatConfirmation: false)
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
    private func createFirstHuman(from app: XCUIApplication) {
        advanceOnboardingIntroToMemberCreation(in: app)
        createMember(
            in: app,
            name: "Codex Human \(Int(Date().timeIntervalSince1970))",
            flowTitle: "Create Member Card",
            missingFieldMessage: "Human creation name field did not appear.",
            completionMessage: "Creating the first human did not leave the creation flow in time.",
            postSaveMarkerIdentifiers: [
                "home-add-first-pet-card",
                "home-add-first-pet-action"
            ]
        )
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
        XCTAssertTrue(quickButton.waitForExistence(timeout: 8), "Home Feed quick submenu action did not appear.")
        tapWhenHittable(quickButton, timeout: 8)

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
                app.buttons["home-quick-action-feed"].exists &&
                !app.buttons["Check in anyway"].exists
        }
        XCTAssertTrue(didFinish, "Home Feed quick check-in did not finish with a responsive home surface.")
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
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        for _ in 0 ..< maxSwipes where !element.exists || !element.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
    }

    private func localizedContains(_ value: String, anyOf needles: [String]) -> Bool {
        needles.contains { value.localizedCaseInsensitiveContains($0) }
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
        postSaveMarkerIdentifiers: [String] = []
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

        tapThroughMemberCreationSteps(in: app, starterPetWeight: starterPetWeight)

        let handoffTitle = app.staticTexts[flowTitle]
        let creationPrimary = app.buttons["member-creation-primary-action"]
        let didLeaveCreation = waitUntil(timeout: 30) {
            let didReachExpectedMarker = containsAnyElement(in: app, identifiers: postSaveMarkerIdentifiers)
            return app.state == .runningForeground &&
                (didReachExpectedMarker ||
                    (!nameField.exists &&
                        !creationPrimary.exists &&
                        !handoffTitle.exists))
        }
        XCTAssertTrue(didLeaveCreation, completionMessage)
    }

    private func containsAnyElement(in app: XCUIApplication, identifiers: [String]) -> Bool {
        identifiers.contains { identifier in
            app.descendants(matching: .any)[identifier].exists
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
            tapWhenHittable(creationPrimary, timeout: 8)
            if isMemberCreationFinalActionLabel(actionLabel) {
                let didBeginSave = waitUntil(timeout: 4) {
                    !creationPrimary.exists || !creationPrimary.isEnabled
                }
                if didBeginSave {
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
        XCTAssertTrue(didBecomeHittable, "Element did not become hittable: \(element)")
        element.tap()
    }

    @MainActor
    private func tapWhenFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let didBecomeFrameReady = waitForFrameReady(element, timeout: timeout)
        guard didBecomeFrameReady else { return false }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }

    private func waitForFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            guard element.exists, element.isEnabled else { return false }
            let frame = element.frame
            return frame.width > 1 && frame.height > 1
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
}

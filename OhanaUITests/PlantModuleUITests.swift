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
        let app = launchEnglishApp(
            resetPersistentState: true,
            enableProductionOverlays: true
        )
        createFirstHuman(from: app)
        completeFirstDayStarterFunnel(in: app)

        XCTAssertFalse(app.buttons["home-tab-plants"].exists, "Plants tab should stay hidden before Lv4 on a fresh account.")

        relaunchWithRewardTierUnlock(in: app)

        openHomePlantsTabAfterUnlock(in: app)

        let plantName = addPlantFromHomePlantsTab(in: app)
        assertHomePlantCard(named: plantName, in: app)

        openCalendarAndAssertPlantVisible(named: plantName, in: app)

        openPlantDetail(named: plantName, in: app)
        exercisePlantDetailCareAndDeleteUndo(named: plantName, in: app)
        returnFromPlantDetailToHome(in: app)

        openPlantDetail(named: plantName, in: app)
        permanentlyDeletePlant(named: plantName, in: app)
    }

    @MainActor
    func testAddPlantPrimaryPathUsesCatalogAndChoiceChipsWithoutTyping() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, plantBaselineSeedCount: 1)
        ensureHouseholdHome(in: app)
        _ = ensureReusablePlantBaselineAndReturnHomePlantName(in: app)

        let plantName = addPlantFromHomePlantsTab(in: app)
        assertHomePlantCard(named: plantName, in: app)
    }

    @MainActor
    func testExistingPlantReminderToggleWithoutReset() throws {
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            enableAnimations: true,
            plantBaselineSeedCount: 1
        )
        ensureHouseholdHome(in: app)

        let plantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openSettingsFromHomeChrome(in: app)
        openPlantReminderPanel(in: app)
        let plantToggle = findPlantReminderToggle(named: plantName, in: app, maxSwipes: 18)

        assertPlantReminderToggleCanRoundTrip(plantToggle, in: app)
    }

    @MainActor
    func testExistingPlantDetailProfileSectionsWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, plantBaselineSeedCount: 1)
        ensureHouseholdHome(in: app)

        let plantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openPlantDetail(named: plantName, in: app)

        XCTAssertTrue(app.descendants(matching: .any)["plant-detail-health-summary"].waitForExistence(timeout: 8), "Plant detail health summary did not appear.")
        openPlantFeatureHubTile("feature-hub-plan-carePlan", in: app)

        XCTAssertTrue(
            waitForAnyMarkerAfterVerticalSearch(
                ["Care rhythm", "Watering", "Plan reasoning"],
                in: app,
                earlierDrags: 6,
                laterDrags: 3
            ),
            "Plant detail care rhythm did not appear."
        )
        XCTAssertTrue(
            waitForAnyMarkerAfterVerticalSearch(
                ["Potting and growth", "Drainage hole"],
                in: app,
                earlierDrags: 0,
                laterDrags: 8
            ),
            "Plant detail growth profile did not appear."
        )
    }

    @MainActor
    func testExistingPlantWalletExpandCollapseReturnsToStableDeckWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, plantBaselineSeedCount: 6)
        ensureHouseholdHome(in: app)

        let plantNames = seedPlantWalletBaselineAndReturnVisibleNames(count: 6, in: app)
        XCTAssertGreaterThanOrEqual(plantNames.count, 6, "Plant wallet stability test needs six visible plant cards.")

        let visibleCards = plantNames.prefix(6).map { plantCard(named: $0, in: app) }
        for (index, card) in visibleCards.enumerated() {
            XCTAssertTrue(waitForTapFrame(card, in: app, timeout: 8), "Plant wallet card \(index + 1) was not tappable before expansion.")
        }

        let framesBefore = visibleCards.map(\.frame)
        let firstCard = visibleCards[0]

        XCTAssertTrue(tapWhenFrameReady(firstCard, timeout: 8), "First plant wallet card did not accept the expansion tap.")
        let expandedDetail = app.buttons["home-expanded-detail-plant"]
        XCTAssertTrue(expandedDetail.waitForExistence(timeout: 8), "Expanded plant wallet card did not expose the detail action.")

        let expandedCollapse = app.buttons["home-expanded-collapse-plant"]
        XCTAssertTrue(tapWhenFrameReady(expandedCollapse, timeout: 8), "Expanded plant wallet card did not expose a collapse hit layer.")
        XCTAssertTrue(waitUntil(timeout: 8) { !expandedCollapse.exists && !expandedDetail.exists }, "Expanded plant wallet controls stayed visible after collapsing.")

        for (index, card) in visibleCards.enumerated() {
            XCTAssertTrue(waitForTapFrame(card, in: app, timeout: 8), "Plant wallet card \(index + 1) did not return to a tappable collapsed state.")
            assertFrame(card.frame, isNear: framesBefore[index], tolerance: 28, message: "Plant card \(index + 1) shifted after expand/collapse.")
        }
    }

    @MainActor
    func testPlantWalletLongListKeepsCardsInOneBalancedDeck() throws {
        let app = launchEnglishApp(resetPersistentState: true, enableProductionOverlays: true, plantBaselineSeedCount: 8)
        ensureHouseholdHome(in: app)

        _ = seedPlantWalletBaselineAndReturnVisibleNames(count: 8, in: app)
        let initialCards = plantWalletCardElements(in: app)
        let initialFrameDiagnostics = initialCards.map { "\($0.identifier)=\($0.frame)" }.joined(separator: "; ")
        XCTAssertGreaterThanOrEqual(
            initialCards.count,
            8,
            "Eight seeded plant cards should stay mounted in one balanced deck. frames=\(initialFrameDiagnostics)"
        )

        let sortedMidY = initialCards.map(\.frame.midY).sorted()
        let maxVerticalGap = zip(sortedMidY.dropFirst(), sortedMidY)
            .map { next, previous in next - previous }
            .max() ?? 0
        XCTAssertLessThan(
            maxVerticalGap,
            220,
            "Plant cards should be evenly distributed without a detached seventh-card section. maxGap=\(maxVerticalGap), frames=\(initialFrameDiagnostics)"
        )

        let lastCard = try XCTUnwrap(initialCards.last, "Could not find the trailing plant card in the balanced deck.")
        XCTAssertTrue(waitForTapFrameHittable(lastCard, in: app, timeout: 8), "The trailing plant card should be reachable in the balanced deck without scrolling to a separate section.")
        XCTAssertTrue(tapWhenFrameReady(lastCard, timeout: 8), "The trailing plant card did not accept an expand tap from the balanced deck.")
        let expandedDetail = app.buttons["home-expanded-detail-plant"]
        XCTAssertTrue(expandedDetail.waitForExistence(timeout: 8), "The trailing plant card did not expand from the balanced deck.")

        let expandedCollapse = app.buttons["home-expanded-collapse-plant"]
        XCTAssertTrue(tapWhenFrameReady(expandedCollapse, timeout: 8), "The expanded trailing plant card did not expose a collapse hit layer.")
        XCTAssertTrue(waitUntil(timeout: 8) { !expandedCollapse.exists && !expandedDetail.exists }, "Expanded balanced-deck plant controls stayed visible after collapsing.")
    }

    @MainActor
    func testPlantRoomRailFiltersAfterCollapsingExpandedCard() throws {
        let app = launchEnglishApp(resetPersistentState: true, enableProductionOverlays: true, plantBaselineSeedCount: 4)
        ensureHouseholdHome(in: app)

        let plantNames = seedPlantWalletBaselineAndReturnVisibleNames(count: 4, in: app)
        let livingRoomPlant = try XCTUnwrap(
            plantNames.first { $0.hasSuffix("-1") || $0.hasSuffix("-3") },
            "Seeded plant names did not include a Living room plant. names=\(plantNames)"
        )
        let balconyPlant = try XCTUnwrap(
            plantNames.first { $0.hasSuffix("-2") || $0.hasSuffix("-4") },
            "Seeded plant names did not include a Balcony plant. names=\(plantNames)"
        )

        let balconyFilter = app.buttons["home-plants-room-edge-balcony"]
        let allFilter = app.buttons["home-plants-room-edge-all"]
        if !balconyFilter.waitForExistence(timeout: 8) || !allFilter.waitForExistence(timeout: 2) {
            XCTFail("Plants room rail buttons did not appear with multiple seeded rooms.")
            return
        }
        XCTAssertTrue(waitForTapFrame(balconyFilter, in: app, timeout: 8), "Balcony room rail button was not tappable.")
        XCTAssertTrue(waitForTapFrame(allFilter, in: app, timeout: 8), "All room rail button was not tappable.")

        let livingRoomCard = plantCard(named: livingRoomPlant, in: app)
        XCTAssertTrue(waitForTapFrame(livingRoomCard, in: app, timeout: 8), "Living room plant card was not tappable before filtering.")
        let livingRoomFrameBeforeFiltering = livingRoomCard.frame
        let balconyCardBeforeFiltering = plantCard(named: balconyPlant, in: app)
        XCTAssertTrue(waitForTapFrame(balconyCardBeforeFiltering, in: app, timeout: 8), "Balcony plant card was not tappable before filtering.")
        let balconyFrameBeforeFiltering = balconyCardBeforeFiltering.frame
        XCTAssertTrue(tapWhenFrameReady(livingRoomCard, timeout: 8), "Living room plant card did not expand before room filtering.")
        let expandedDetail = app.buttons["home-expanded-detail-plant"]
        XCTAssertTrue(expandedDetail.waitForExistence(timeout: 8), "Expanded plant card did not expose detail before room filtering.")
        XCTAssertFalse(
            balconyFilter.exists || allFilter.exists,
            "Room rail should stay hidden while a plant card is expanded."
        )

        let expandedCollapse = app.buttons["home-expanded-collapse-plant"]
        XCTAssertTrue(
            tapWhenFrameReady(expandedCollapse, timeout: 8),
            "Expanded plant card did not expose a stable collapse action before room filtering."
        )
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                !expandedDetail.exists && balconyFilter.exists && allFilter.exists
            },
            "Collapsing the plant card did not restore the room rail."
        )

        XCTAssertTrue(tapWhenFrameReady(balconyFilter, timeout: 8), "Balcony room rail button did not accept a tap.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                plantCard(named: balconyPlant, in: app).exists &&
                    !plantCard(named: livingRoomPlant, in: app).exists
            },
            "Balcony filter did not hide the expanded Living room plant and show the Balcony plant."
        )
        let balconyCardAfterFiltering = plantCard(named: balconyPlant, in: app)
        XCTAssertTrue(waitForTapFrame(balconyCardAfterFiltering, in: app, timeout: 8), "Balcony plant card was not tappable after filtering.")
        let balconyFrameAfterFiltering = balconyCardAfterFiltering.frame
        XCTAssertLessThan(
            abs(balconyFrameAfterFiltering.midX - livingRoomFrameBeforeFiltering.midX),
            max(36, abs(balconyFrameBeforeFiltering.midX - livingRoomFrameBeforeFiltering.midX) * 0.42),
            "Room rail filtering should recompute the deck and move the Balcony card into the filtered front slot."
        )
        XCTAssertGreaterThan(
            abs(balconyFrameAfterFiltering.midX - balconyFrameBeforeFiltering.midX),
            48,
            "Room rail filtering should not leave the Balcony card in its previous all-room deck slot."
        )

        XCTAssertTrue(tapWhenFrameReady(allFilter, timeout: 8), "All room rail button did not accept a tap.")
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                plantCard(named: balconyPlant, in: app).exists &&
                    plantCard(named: livingRoomPlant, in: app).exists
            },
            "All room filter did not restore both room groups."
        )
        let balconyCardAfterAll = plantCard(named: balconyPlant, in: app)
        XCTAssertTrue(waitForTapFrame(balconyCardAfterAll, in: app, timeout: 8), "Balcony plant card was not tappable after returning to All.")
        assertFrame(
            balconyCardAfterAll.frame,
            isNear: balconyFrameBeforeFiltering,
            tolerance: 28,
            message: "Returning to All should restore the Balcony card's original all-room deck slot."
        )
    }

    @MainActor
    func testHomePlantViewSwitcherRailSwitchesToListMode() throws {
        let app = launchEnglishApp(resetPersistentState: true, enableProductionOverlays: true, plantBaselineSeedCount: 4)
        ensureHouseholdHome(in: app)

        _ = seedPlantWalletBaselineAndReturnVisibleNames(count: 4, in: app)

        let deckButton = app.buttons["home-plants-view-deck"]
        let listButton = app.buttons["home-plants-view-list"]
        XCTAssertTrue(deckButton.waitForExistence(timeout: 8), "Home plants view switcher did not expose the card-stack button.")
        XCTAssertTrue(listButton.waitForExistence(timeout: 8), "Home plants view switcher did not expose the list button.")
        XCTAssertTrue(waitForTapFrame(listButton, in: app, timeout: 8), "Home plants list view switcher was not frame-ready.")
        XCTAssertTrue(tapWhenFrameReady(listButton, timeout: 8), "Home plants list view switcher did not accept a tap.")

        let listCards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-plants-room-list-card-"))
        XCTAssertTrue(
            waitUntil(timeout: 8) { listCards.count > 0 },
            "Home plants list cards did not appear after selecting list mode."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["home-plants-room-edge-rail"].exists,
            "Home plants room rail should hide in list mode."
        )
    }

    @MainActor
    func testHomePlantRouteQuickActionOpensCareDetail() throws {
        let app = launchEnglishApp(resetPersistentState: true, enableProductionOverlays: true, plantBaselineSeedCount: 4)
        ensureHouseholdHome(in: app)

        let plantNames = seedPlantWalletBaselineAndReturnVisibleNames(count: 4, in: app)
        let plantName = try XCTUnwrap(plantNames.first, "Plant quick-action route test needs a seeded visible plant.")
        let card = plantCard(named: plantName, in: app)
        XCTAssertTrue(waitForTapFrame(card, in: app, timeout: 8), "Seeded plant card was not tappable before opening quick actions.")
        XCTAssertTrue(tapWhenFrameReady(card, timeout: 8), "Seeded plant card did not expand.")

        let waterAction = app.buttons["home-quick-action-plantWater"]
        XCTAssertTrue(waterAction.waitForExistence(timeout: 8), "Expanded plant card did not expose the default Water quick action.")
        XCTAssertTrue(tapWhenFrameReady(waterAction, timeout: 8), "Plant Water quick action did not accept a tap.")

        let quickRecordAction = app.buttons
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "home-quick-action-menu-",
                    "-plantWater-quick"
                )
            )
            .firstMatch
        let detailAction = app.buttons
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    "home-quick-action-menu-",
                    "-plantWater-detail"
                )
            )
            .firstMatch
        XCTAssertTrue(quickRecordAction.waitForExistence(timeout: 8), "Plant Water quick action did not expose the Quick Record submenu action.")
        XCTAssertTrue(detailAction.waitForExistence(timeout: 8), "Plant Water quick action did not expose the Detail submenu action.")
        XCTAssertTrue(tapWhenFrameReady(detailAction, timeout: 8), "Plant Water detail submenu action did not accept a tap.")
        XCTAssertTrue(
            app.descendants(matching: .any)["plant-care-feature-water-guided-home"].waitForExistence(timeout: 12),
            "Plant Water detail submenu action did not open the watering care detail."
        )
    }

    @MainActor
    func testPlantFunctionMenuEntrypointsOpenDashboardListPhotosWithoutCalendarReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, plantBaselineSeedCount: 4)
        ensureHouseholdHome(in: app)

        _ = seedPlantWalletBaselineAndReturnVisibleNames(count: 4, in: app)
        openPlantFeatureCollectionFromPlantsTab(in: app)

        XCTAssertTrue(
            app.descendants(matching: .any)["plant-feature-collection"].waitForExistence(timeout: 12),
            "Plant FAB All did not open the current Plant Feature Collection."
        )
        XCTAssertFalse(
            app.buttons["plant-feature-card-calendar"].waitForExistence(timeout: 1),
            "Plant Feature Collection should not expose a Plant Calendar card."
        )

        let dashboardCard = app.buttons["plant-feature-card-dashboard"]
        scrollToElement(dashboardCard, in: app, maxSwipes: 6)
        XCTAssertTrue(
            tapWhenFrameReady(dashboardCard, timeout: 8),
            "Plant Feature Collection did not expose a tappable Plant Management card."
        )

        XCTAssertTrue(
            app.descendants(matching: .any)["plant-dashboard-sites-view"].waitForExistence(timeout: 12),
            "Plant Management did not open the Plant Overview dashboard."
        )
        openPlantDashboardDestination(
            actionIdentifier: "plant-dashboard-mode-plants",
            description: "Plants",
            expectedScreen: "plant-dashboard-plants-view",
            in: app
        )
        openPlantDashboardDestination(
            actionIdentifier: "plant-dashboard-quick-action-photos",
            description: "Photos",
            expectedScreen: "plant-dashboard-photos-view",
            in: app
        )
        openPlantDashboardDestination(
            actionIdentifier: "plant-dashboard-mode-sites",
            description: "Sites",
            expectedScreen: "plant-dashboard-sites-view",
            in: app
        )
    }

    @MainActor
    func testExistingPlantCalendarPlantsFilterExcludesGeneralEventsWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, plantBaselineSeedCount: 1)
        ensureHouseholdHome(in: app)

        let plantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openCalendarList(in: app)

        let timestamp = Int(Date().timeIntervalSince1970)
        let generalEventTitle = "Codex General Plant Filter \(timestamp)"
        let plantEventTitle = "Codex Plant Filter \(timestamp)"
        addCalendarEvent(title: generalEventTitle, in: app)
        addCalendarEvent(title: plantEventTitle, linkedPlantName: plantName, in: app)
        assertCalendarEvent(generalEventTitle, exists: true, in: app, context: "all filter before selecting plants")
        assertCalendarEvent(plantEventTitle, exists: true, in: app, context: "all filter before selecting plants")

        tapWhenHittable(app.buttons["calendar-filter-plants"], timeout: 8)
        assertCalendarEvent(plantEventTitle, exists: true, in: app, context: "plants aggregate filter")
        assertCalendarEvent(generalEventTitle, exists: false, in: app, context: "plants aggregate filter excludes general events")
        XCTAssertFalse(
            app.buttons["calendar-filter-plant-\(plantName)"].waitForExistence(timeout: 1),
            "Calendar filter should not expose individual plant chips."
        )
    }

    @MainActor
    func testPlantDetailDoesNotExposeCareCalendarEntrypointWithoutReset() throws {
        let app = launchEnglishApp(enableProductionOverlays: true, plantBaselineSeedCount: 1)
        ensureHouseholdHome(in: app)

        let plantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openPlantDetail(named: plantName, in: app)
        XCTAssertFalse(
            app.buttons["plant-detail-action-tool-calendar"].waitForExistence(timeout: 1),
            "Plant detail action tools should not expose a Calendar entry."
        )

        let hubAction = app.buttons["plant-detail-all-features-action"]
        XCTAssertTrue(hubAction.waitForExistence(timeout: 8), "Plant feature hub action did not appear.")
        XCTAssertTrue(tapWhenFrameReady(hubAction, timeout: 8), "Plant feature hub action was not tappable.")

        let hubSheet = app.descendants(matching: .any)["plant-detail-all-features-sheet"]
        XCTAssertTrue(hubSheet.waitForExistence(timeout: 8), "Plant feature hub sheet did not open.")
        XCTAssertFalse(
            app.buttons["feature-hub-plan-calendar"].waitForExistence(timeout: 1),
            "Plant feature hub should not expose a Care Calendar tile."
        )
    }

    @MainActor
    func testExistingPlantSettingsBulkDeferAndEditCancelSaveWithoutReset() throws {
        let app = launchEnglishApp(
            enableProductionOverlays: true,
            enableAnimations: true,
            plantBaselineSeedCount: 1
        )
        ensureHouseholdHome(in: app)

        let originalPlantName = seedPlantBaselineAndReturnHomePlantName(in: app)
        openSettingsFromHomeChrome(in: app)
        openPlantReminderPanel(in: app)
        let bulkDefer = app.descendants(matching: .any)["settings-plant-reminders-defer-all"]
        for _ in 0 ..< 6 where !isTapFrameVisible(bulkDefer, in: app) {
            scrollSettingsDown(in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(
            waitForTapFrame(bulkDefer, in: app, timeout: 8),
            "Plant reminder bulk defer action did not expose a visible touch frame."
        )
        bulkDefer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        closeSettingsToHome(in: app)
        openPlantDetail(named: originalPlantName, in: app)
        exercisePlantEditCancelAndSave(originalName: originalPlantName, in: app)
    }

    @MainActor
    private func launchEnglishApp(
        resetPersistentState: Bool = false,
        enableProductionOverlays: Bool = false,
        enableAnimations: Bool = false,
        unlockRewardTier: Bool = false,
        plantBaselineSeedCount: Int? = nil
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
        if enableAnimations {
            app.launchArguments += ["-OHANA_UI_TEST_ENABLE_ANIMATIONS"]
        }
        if unlockRewardTier {
            app.launchArguments += ["-OHANA_UI_TEST_UNLOCK_REWARD_TIER"]
        }
        if let plantBaselineSeedCount {
            app.launchArguments += [
                "-OHANA_UI_TEST_SEED_PLANT_BASELINE",
                "-OHANA_UI_TEST_PLANT_BASELINE_COUNT",
                "\(plantBaselineSeedCount)"
            ]
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
            postSaveMarkerIdentifiers: ["home-add-first-pet-card"]
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
        let existingName = openPlantsTabAndReturnFirstPlantNameIfPresent(in: app)
        if !existingName.isEmpty {
            return existingName
        }
        openSettingsFromHomeChrome(in: app)
        seedPlantBaselineFromSettings(in: app)
        closeSettingsToHome(in: app)
        return openPlantsTabAndReturnFirstPlantName(in: app)
    }

    @MainActor
    private func ensureReusablePlantBaselineAndReturnHomePlantName(in app: XCUIApplication) -> String {
        if app.buttons["home-tab-plants"].waitForExistence(timeout: 4) {
            let existingName = openPlantsTabAndReturnFirstPlantNameIfPresent(in: app)
            if !existingName.isEmpty {
                return existingName
            }
        }
        return seedPlantBaselineAndReturnHomePlantName(in: app)
    }

    @MainActor
    private func seedPlantWalletBaselineAndReturnVisibleNames(count: Int, in app: XCUIApplication) -> [String] {
        let existingNames = openPlantsTabAndReturnVisiblePlantNamesIfPresent(minCount: count, in: app)
        if existingNames.count >= count {
            return existingNames
        }
        openSettingsFromHomeChrome(in: app)
        seedPlantBaselineFromSettings(in: app)
        closeSettingsToHome(in: app)
        return openPlantsTabAndReturnVisiblePlantNames(minCount: count, in: app)
    }

    @MainActor
    private func relaunchWithRewardTierUnlock(in app: XCUIApplication) {
        app.terminate()
        app.launchArguments.removeAll { $0 == "-OHANA_RESET_PERSISTENT_STATE" }
        if !app.launchArguments.contains("-OHANA_UI_TEST_UNLOCK_REWARD_TIER") {
            app.launchArguments += ["-OHANA_UI_TEST_UNLOCK_REWARD_TIER"]
        }
        app.launch()

        let didUnlockPlantsSurface = waitUntil(timeout: 24) {
            app.buttons["home-tab-plants"].exists ||
                app.descendants(matching: .any)["growth-unlock-popup"].exists
        }
        XCTAssertTrue(didUnlockPlantsSurface, "UI-test reward-tier seed did not unlock the plants surface after relaunch.")
    }

    @MainActor
    private func openPlantFeatureCollectionFromPlantsTab(in app: XCUIApplication) {
        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 14), "Plants tab did not appear before opening the plant module.")
        XCTAssertTrue(tapWhenFrameReady(plantsTab, timeout: 8), "Plants tab did not become frame-ready before opening the plant module.")
        XCTAssertTrue(
            app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 12),
            "Home plants page did not open before using the plant toolbar menu."
        )

        let primaryAction = app.buttons["home-primary-action"]
        XCTAssertTrue(primaryAction.waitForExistence(timeout: 12), "Plant primary action did not appear before opening the plant module.")
        tapWhenHittable(primaryAction, timeout: 8)

        let allShortcut = app.buttons["home-plant-data-action"]
        XCTAssertTrue(allShortcut.waitForExistence(timeout: 8), "Plant toolbar menu did not expose Plant Data.")
        XCTAssertTrue(tapWhenFrameReady(allShortcut, timeout: 8), "Plant Data action did not become frame-ready.")
        XCTAssertTrue(
            app.descendants(matching: .any)["plant-feature-collection"].waitForExistence(timeout: 12),
            "Plant Data did not open the Plant Feature Collection."
        )
    }

    @MainActor
    private func openPlantDashboardDestination(
        actionIdentifier: String,
        description: String,
        expectedScreen identifier: String,
        in app: XCUIApplication
    ) {
        let action = app.buttons[actionIdentifier]
        scrollToElement(action, in: app, maxSwipes: 6)
        XCTAssertTrue(action.waitForExistence(timeout: 10), "Plant dashboard action did not appear: \(description).")
        XCTAssertTrue(tapWhenFrameReady(action, timeout: 8), "Plant dashboard action was not tappable: \(description).")
        XCTAssertTrue(
            app.descendants(matching: .any)[identifier].waitForExistence(timeout: 12),
            "Plant dashboard action \(description) did not open \(identifier)."
        )
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
    private func addPlantFromHomePlantsTab(in app: XCUIApplication) -> String {
        let addEntry = app.buttons["home-primary-action"]
        tapWhenHittable(addEntry, timeout: 8)
        let addPlantShortcut = app.buttons["home-add-plant-action"]
        XCTAssertTrue(addPlantShortcut.waitForExistence(timeout: 8), "Plant toolbar menu did not expose Add Plant.")
        XCTAssertTrue(tapWhenFrameReady(addPlantShortcut, timeout: 8), "Add Plant did not become frame-ready.")

        let addPlantStep = app.descendants(matching: .any)["add-plant-step-plant-room"]
        XCTAssertTrue(addPlantStep.waitForExistence(timeout: 8), "Add Plant did not open on the plant-and-room step.")

        let pothosChoice = app.descendants(matching: .any)["add-plant-common-catalog-epipremnum-aureum"]
        scrollToElement(pothosChoice, in: app, maxSwipes: 2)
        XCTAssertTrue(tapWhenFrameReady(pothosChoice, timeout: 8), "Pothos catalog choice did not become tappable.")

        let expectedPlantName = "pothos"
        let defaultName = app.staticTexts["add-plant-name-summary-secondary-value"]
        XCTAssertTrue(defaultName.waitForExistence(timeout: 8), "Catalog choice did not expose the default plant name summary.")
        XCTAssertTrue(
            defaultName.label.localizedCaseInsensitiveContains(expectedPlantName),
            "Catalog choice should default the plant name without typing. Current value: \(defaultName.label)"
        )
        assertAddPlantPrimaryPathKeepsCustomTextFieldsHidden(in: app, context: "after catalog selection")

        let roomChoice = app.buttons["add-plant-room-choice-0"]
        scrollToElement(roomChoice, in: app, maxSwipes: 3)
        tapWhenFrameReady(roomChoice, timeout: 8)
        assertAddPlantPrimaryPathKeepsCustomTextFieldsHidden(in: app, context: "after room chip selection")

        let locationChoice = app.buttons["add-plant-location-choice-0"]
        scrollToElement(locationChoice, in: app, maxSwipes: 3)
        tapWhenFrameReady(locationChoice, timeout: 8)
        assertAddPlantPrimaryPathKeepsCustomTextFieldsHidden(in: app, context: "after location chip selection")

        let nextAction = app.buttons["add-plant-next-action"]
        XCTAssertTrue(
            tapWhenFrameReady(nextAction, timeout: 8),
            "Add Plant next action did not become frame-ready after choosing plant and room. \(elementDebugState(nextAction))"
        )
        XCTAssertTrue(app.descendants(matching: .any)["add-plant-step-avatar"].waitForExistence(timeout: 8), "Add Plant did not advance to the avatar step.")

        XCTAssertTrue(
            tapWhenFrameReady(nextAction, timeout: 8),
            "Add Plant next action did not become frame-ready on the avatar step. \(elementDebugState(nextAction))"
        )
        XCTAssertTrue(app.descendants(matching: .any)["add-plant-step-care-details"].waitForExistence(timeout: 8), "Add Plant did not advance to the care details step.")

        XCTAssertTrue(
            tapWhenFrameReady(nextAction, timeout: 8),
            "Add Plant next action did not become frame-ready on the care details step. \(elementDebugState(nextAction))"
        )
        XCTAssertTrue(app.descendants(matching: .any)["add-plant-step-confirm"].waitForExistence(timeout: 8), "Add Plant did not advance to the confirmation step.")

        let saveAction = app.buttons["add-plant-save-action"]
        XCTAssertTrue(
            tapWhenFrameReady(saveAction, timeout: 8),
            "Add Plant save action did not become frame-ready on the confirmation step. \(elementDebugState(saveAction))"
        )

        let didReturnToPlants = waitUntil(timeout: 20) {
            plantCard(named: expectedPlantName, in: app).exists || app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", expectedPlantName)).firstMatch.exists
        }
        XCTAssertTrue(didReturnToPlants, "Adding a plant did not return to the Home plants page with the new plant visible.")
        return expectedPlantName
    }

    @MainActor
    private func assertAddPlantPrimaryPathKeepsCustomTextFieldsHidden(
        in app: XCUIApplication,
        context: String
    ) {
        XCTAssertFalse(app.textFields["add-plant-name-input"].exists, "Plant name text field should stay hidden on the catalog-first path \(context).")
        XCTAssertFalse(app.textFields["add-plant-room-input"].exists, "Custom room text field should stay hidden on the chip-first path \(context).")
        XCTAssertFalse(app.textFields["add-plant-location-input"].exists, "Custom location text field should stay hidden on the chip-first path \(context).")
        XCTAssertFalse(
            app.descendants(matching: .any)["add-plant-optional-details-content"].exists,
            "Optional plant details should stay collapsed on the primary add path \(context)."
        )
    }

    @MainActor
    private func assertHomePlantCard(named plantName: String, in app: XCUIApplication) {
        let card = plantCard(named: plantName, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 12), "Home plants tab did not show the created plant card.")
    }

    @MainActor
    private func openPlantDetail(named plantName: String, in app: XCUIApplication) {
        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 12), "Plants tab did not exist before opening plant detail.")
        XCTAssertTrue(tapWhenFrameReady(plantsTab, timeout: 8), "Plants tab did not become frame-ready before opening plant detail.")
        XCTAssertTrue(app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 12), "Home plants page did not open before opening plant detail.")
        let card = plantCard(named: plantName, in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 14), "Plant card was not visible before opening detail.")
        tapWhenFrameReady(card, timeout: 8)
        if !app.descendants(matching: .any)["plant-detail-screen"].waitForExistence(timeout: 2) {
            let expandedDetail = app.buttons["home-expanded-detail-plant"]
            let quickDetail = app.buttons["home-quick-action-plantDetail"]
            XCTAssertTrue(
                expandedDetail.waitForExistence(timeout: 8) || quickDetail.waitForExistence(timeout: 2),
                "Plant wallet card expanded, but no detail entry appeared."
            )
            if expandedDetail.exists {
                tapWhenFrameReady(expandedDetail, timeout: 8)
            } else {
                tapWhenFrameReady(quickDetail, timeout: 8)
            }
        }
        XCTAssertTrue(app.descendants(matching: .any)["plant-detail-screen"].waitForExistence(timeout: 14), "Plant detail did not open.")
        XCTAssertTrue(containsAnyMarker([plantName, "Next step", "Environment", "Care history"], in: app, timeout: 10), "Plant detail did not show expected content.")
    }

    @MainActor
    private func openPlantFeatureHubTile(_ identifier: String, in app: XCUIApplication) {
        let hubAction = app.buttons["plant-detail-all-features-action"]
        XCTAssertTrue(hubAction.waitForExistence(timeout: 8), "Plant feature hub action did not appear.")
        XCTAssertTrue(tapWhenFrameReady(hubAction, timeout: 8), "Plant feature hub action was not tappable.")

        let hubSheet = app.descendants(matching: .any)["plant-detail-all-features-sheet"]
        XCTAssertTrue(hubSheet.waitForExistence(timeout: 8), "Plant feature hub sheet did not open.")

        let tile = app.buttons[identifier]
        scrollToElement(tile, in: app, maxSwipes: 6)
        XCTAssertTrue(tapWhenFrameReady(tile, timeout: 8), "Plant feature hub tile was not tappable: \(identifier)")
        XCTAssertTrue(waitUntil(timeout: 8) { !hubSheet.exists }, "Plant feature hub sheet did not dismiss after selecting \(identifier).")
    }

    @MainActor
    private func openPlantsTabAndReturnFirstPlantName(in app: XCUIApplication) -> String {
        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 14), "Plants tab did not appear after seeding plant baseline.")
        tapWhenFrameReady(plantsTab, timeout: 8)
        XCTAssertTrue(app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 12), "Home plants page did not open.")

        let firstPlantCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home-card-plant-")).firstMatch
        XCTAssertTrue(firstPlantCard.waitForExistence(timeout: 12), "Home plants page did not show any plant card after seeding.")
        let prefix = "home-card-plant-"
        XCTAssertTrue(firstPlantCard.identifier.hasPrefix(prefix), "First plant card did not expose a plant-card identifier.")
        return String(firstPlantCard.identifier.dropFirst(prefix.count))
    }

    @MainActor
    private func openPlantsTabAndReturnFirstPlantNameIfPresent(in app: XCUIApplication) -> String {
        let plantsTab = app.buttons["home-tab-plants"]
        guard tapWhenFrameReady(plantsTab, timeout: 5) else { return "" }
        guard app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 8) else { return "" }

        let prefix = "home-card-plant-"
        let firstPlantCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
        guard firstPlantCard.waitForExistence(timeout: 4), firstPlantCard.identifier.hasPrefix(prefix) else {
            return ""
        }
        return String(firstPlantCard.identifier.dropFirst(prefix.count))
    }

    @MainActor
    private func openPlantsTabAndReturnVisiblePlantNames(minCount: Int, in app: XCUIApplication) -> [String] {
        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 14), "Plants tab did not appear after seeding plant baseline.")
        XCTAssertTrue(tapWhenFrameReady(plantsTab, timeout: 8), "Plants tab did not become tappable after seeding plant baseline.")
        XCTAssertTrue(app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 12), "Home plants page did not open.")

        let prefix = "home-card-plant-"
        let cards = plantWalletCardsQuery(in: app, prefix: prefix)
        XCTAssertTrue(waitUntil(timeout: 12) { cards.count >= minCount }, "Home plants page did not show \(minCount) plant wallet cards after seeding.")

        let visibleCount = min(cards.count, max(0, minCount))
        return (0 ..< visibleCount).compactMap { index in
            let identifier = cards.element(boundBy: index).identifier
            guard identifier.hasPrefix(prefix) else { return nil }
            return String(identifier.dropFirst(prefix.count))
        }
    }

    @MainActor
    private func openPlantsTabAndReturnVisiblePlantNamesIfPresent(minCount: Int, in app: XCUIApplication) -> [String] {
        let plantsTab = app.buttons["home-tab-plants"]
        guard tapWhenFrameReady(plantsTab, timeout: 5) else { return [] }
        guard app.descendants(matching: .any)["home-plants-page"].waitForExistence(timeout: 8) else { return [] }

        let prefix = "home-card-plant-"
        let cards = plantWalletCardsQuery(in: app, prefix: prefix)
        let hasEnoughCards = waitUntil(timeout: 8) { cards.count >= minCount }
        guard hasEnoughCards else { return [] }

        let visibleCount = min(cards.count, max(0, minCount))
        return (0 ..< visibleCount).compactMap { index in
            let identifier = cards.element(boundBy: index).identifier
            guard identifier.hasPrefix(prefix) else { return nil }
            return String(identifier.dropFirst(prefix.count))
        }
    }

    @MainActor
    private func plantCard(named plantName: String, in app: XCUIApplication) -> XCUIElement {
        let page = app.descendants(matching: .any)["home-plants-page"]
        if page.exists {
            let pageCard = page.buttons["home-card-plant-\(plantName)"]
            if pageCard.exists { return pageCard }
        }

        let walletCard = app.buttons["home-card-plant-\(plantName)"]
        if walletCard.exists { return walletCard }

        let legacyCard = app.buttons["home-plants-card-\(plantName)"]
        if legacyCard.exists { return legacyCard }

        return app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@", "home-card-plant-", plantName)).firstMatch
    }

    @MainActor
    private func plantWalletCardsQuery(in app: XCUIApplication, prefix: String) -> XCUIElementQuery {
        let page = app.descendants(matching: .any)["home-plants-page"]
        if page.exists {
            return page.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        }
        return app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }

    @MainActor
    private func plantWalletCardElements(in app: XCUIApplication) -> [XCUIElement] {
        let prefix = "home-card-plant-"
        let cards = plantWalletCardsQuery(in: app, prefix: prefix)
        return (0 ..< cards.count).map { cards.element(boundBy: $0) }
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
        let todayCarePanel = app.descendants(matching: .any)["plant-detail-today-care-panel"]
        XCTAssertTrue(
            todayCarePanel.exists || containsAnyMarker(["Today care", "今日护理", "Heutige Pflege"], in: app, timeout: 6),
            "Plant detail did not show the today care panel."
        )
        if !quickLogFirstVisiblePlantDetailCareTask(in: app) {
            XCTAssertTrue(
                app.descendants(matching: .any)["plant-detail-today-care-empty"].waitForExistence(timeout: 4) ||
                    containsAnyMarker(["Nothing due", "没有待办", "Nichts fällig"], in: app, timeout: 4),
                "Plant detail showed neither a quick-loggable care task nor the empty today care state."
            )
        }

        tapPlantDetailDeleteAction(in: app)
        tapPlantDeleteConfirmation(in: app)
        let undoAction = app.buttons["plant-detail-delete-undo"]
        XCTAssertTrue(
            tapWhenFrameReady(undoAction, timeout: 3),
            "Plant delete undo banner did not appear or did not expose a tap frame before the undo window expired."
        )
        XCTAssertFalse(app.buttons["plant-detail-delete-now"].waitForExistence(timeout: 1.5), "Plant delete undo did not cancel the pending delete.")
        XCTAssertTrue(containsAnyMarker([plantName], in: app, timeout: 4), "Plant detail lost the plant after undoing delete.")
    }

    @MainActor
    private func quickLogFirstVisiblePlantDetailCareTask(in app: XCUIApplication) -> Bool {
        let careTypes = [
            "watering",
            "fertilizing",
            "misting",
            "pruning",
            "leafCleaning",
            "pestCheck",
            "rotating",
            "repotting",
            "newLeaf",
            "yellowLeaf",
            "pestFound",
            "photo",
            "customNote"
        ]

        for careType in careTypes {
            let quickAction = app.buttons["plant-detail-today-care-quick-\(careType)"]
            guard quickAction.exists else { continue }
            guard isTapFrameVisible(quickAction, in: app) else { continue }
            quickAction.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

            let popup = app.descendants(matching: .any)["plant-detail-quick-care-popup"]
            XCTAssertTrue(waitUntil(timeout: 8) { popup.exists }, "Plant detail quick-care popup did not open for \(careType).")
            let quickLog = app.buttons["plant-detail-quick-care-quick-log"]
            XCTAssertTrue(waitUntil(timeout: 8) { isTapFrameVisible(quickLog, in: app) }, "Plant detail quick log action was not tappable for \(careType).")
            quickLog.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(
                waitUntil(timeout: 10) { app.descendants(matching: .any)["plant-detail-quick-care-toast"].exists },
                "Plant detail quick log did not show success feedback for \(careType)."
            )
            return true
        }

        return false
    }

    @MainActor
    private func openPlantReminderSettingsAndTogglePlant(named plantName: String, in app: XCUIApplication) {
        openSettingsFromHomeChrome(in: app)
        openPlantReminderPanel(in: app)
        let plantToggle = findPlantReminderToggle(named: plantName, in: app, maxSwipes: 18)
        XCTAssertTrue(plantToggle.waitForExistence(timeout: 8), "Per-plant reminder toggle did not appear.")
        assertPlantReminderToggleCanRoundTrip(plantToggle, in: app)
    }

    @MainActor
    private func openPlantReminderPanel(in app: XCUIApplication) {
        let overview = app.descendants(matching: .any)["settings-plant-reminders-overview"]
        if overview.exists { return }

        let disclosure = app.buttons["settings-advanced-notifications-disclosure"]
        scrollToElement(disclosure, in: app, maxSwipes: 10)
        XCTAssertTrue(disclosure.waitForExistence(timeout: 8), "Advanced reminder settings disclosure did not appear in Settings.")
        tapWhenFrameReady(disclosure, timeout: 8)

        if !overview.waitForExistence(timeout: 8) {
            scrollToElement(overview, in: app, maxSwipes: 6)
        }
        XCTAssertTrue(overview.waitForExistence(timeout: 8), "Plant reminder settings panel did not appear after expanding advanced reminder settings.")
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
        let slug = plantReminderIdentifierSlug(for: plantName)
        let identified = app.descendants(matching: .any)["settings-plant-reminders-plant-toggle-\(slug)"]
        let row = app.otherElements.matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS[c] %@",
            "settings-plant-reminders-plant-row-",
            plantName
        )).firstMatch
        let section = app.otherElements["settings-plant-reminders-plant-section"]
        let emptyState = app.otherElements["settings-plant-reminders-empty-state"]

        for _ in 0 ..< maxSwipes {
            if isTapFrameVisible(identified, in: app) { return identified }
            if isTapFrameVisible(row, in: app) { return row }
            if emptyState.exists {
                XCTFail("Settings plant reminder panel loaded with no plants after creating \(plantName).")
                return identified
            }
            if section.exists {
                RunLoop.current.run(until: Date().addingTimeInterval(0.4))
                if isTapFrameVisible(identified, in: app) { return identified }
                if isTapFrameVisible(row, in: app) { return row }
            }
            scrollSettingsDown(in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        if emptyState.exists {
            XCTFail("Settings plant reminder panel loaded with no plants after creating \(plantName).")
        }
        return identified
    }

    private func plantReminderIdentifierSlug(for plantName: String) -> String {
        let folded = plantName.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        ).lowercased()
        var slug = ""
        var didAppendSeparator = false

        for scalar in folded.unicodeScalars {
            let value = scalar.value
            if (48 ... 57).contains(value) || (97 ... 122).contains(value) {
                slug.unicodeScalars.append(scalar)
                didAppendSeparator = false
            } else if !slug.isEmpty, !didAppendSeparator {
                slug.append("-")
                didAppendSeparator = true
            }
        }

        while slug.last == "-" {
            slug.removeLast()
        }
        return slug
    }

    @MainActor
    private func findAnyPlantReminderToggle(in app: XCUIApplication, maxSwipes: Int) -> XCUIElement {
        let identified = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@",
            "settings-plant-reminders-plant-toggle-"
        )).firstMatch
        let row = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@",
            "settings-plant-reminders-plant-row-"
        )).firstMatch
        let emptyState = app.otherElements["settings-plant-reminders-empty-state"]

        for _ in 0 ..< maxSwipes {
            if isTapFrameVisible(identified, in: app) { return identified }
            if isTapFrameVisible(row, in: app) { return row }
            if emptyState.exists { return identified }
            scrollSettingsDown(in: app)
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        return identified.exists ? identified : row
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
        openCalendarList(in: app)
        assertPlantCalendarRow(named: plantName, exists: true, in: app, context: "calendar open after plant creation")
    }

    @MainActor
    private func openCalendarList(in app: XCUIApplication) {
        let calendarTab = app.buttons["home-tab-calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 12), "Calendar tab did not exist.")
        tapWhenHittable(calendarTab, timeout: 8)

        let allFilter = app.buttons["calendar-filter-all"]
        XCTAssertTrue(allFilter.waitForExistence(timeout: 14), "Calendar screen did not open after tapping the Home Calendar tab.")
        tapWhenHittable(allFilter, timeout: 8)

        let listMode = app.buttons["calendar-view-mode-list"]
        XCTAssertTrue(listMode.waitForExistence(timeout: 10), "Calendar list-view toggle did not appear.")
        tapWhenHittable(listMode, timeout: 8)
    }

    @MainActor
    private func tapCalendarFilterChip(_ chip: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(chip.waitForExistence(timeout: 8), "Calendar filter chip did not exist: \(chip.identifier)")
        let chipBar = app.descendants(matching: .any)["calendar-filter-chip-bar"]
        for _ in 0 ..< 10 where !chip.isHittable {
            if chipBar.exists {
                chipBar.swipeLeft()
            } else {
                app.swipeLeft()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        tapWhenHittable(chip, timeout: 8)
    }

    @MainActor
    private func assertCalendarFilterChipSelected(_ chip: XCUIElement, in app: XCUIApplication, context: String) {
        XCTAssertTrue(chip.waitForExistence(timeout: 8), "Calendar filter chip did not exist during \(context): \(chip.identifier)")
        let chipBar = app.descendants(matching: .any)["calendar-filter-chip-bar"]
        for _ in 0 ..< 10 where !chip.isHittable {
            if chipBar.exists {
                chipBar.swipeLeft()
            } else {
                app.swipeLeft()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(
            waitUntil(timeout: 6) { chip.value as? String == "Selected" },
            "Calendar filter chip \(chip.identifier) was not selected during \(context)."
        )
    }

    @MainActor
    private func addCalendarEvent(title: String, linkedPlantName: String? = nil, in app: XCUIApplication) {
        let addEventAction = calendarAddEventAction(in: app)
        XCTAssertTrue(addEventAction.waitForExistence(timeout: 10), "Calendar add-event action did not appear.")
        XCTAssertTrue(tapWhenFrameReady(addEventAction, timeout: 8), "Calendar add-event action did not become tappable.")
        typeText(title, intoTextField: "add-event-title-input", in: app)
        dismissKeyboardIfPresent(in: app)

        if let linkedPlantName {
            let plantChip = app.buttons["add-event-related-plant-\(linkedPlantName)"]
            XCTAssertTrue(plantChip.waitForExistence(timeout: 8), "Calendar add-event sheet did not expose the related plant chip for \(linkedPlantName).")
            for _ in 0 ..< 10 where !isTapFrameVisible(plantChip, in: app) {
                scrollTowardTapFrame(of: plantChip, in: app)
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
            XCTAssertTrue(waitForTapFrame(plantChip, in: app, timeout: 8), "Calendar related plant chip was not visibly tappable for \(linkedPlantName).")
            plantChip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(
                waitUntil(timeout: 4) { plantChip.value as? String == "Selected" },
                "Calendar related plant chip did not enter the selected state for \(linkedPlantName)."
            )
        }

        let saveAction = app.buttons["add-event-save-action"]
        scrollToElement(saveAction, in: app, maxSwipes: 4)
        XCTAssertTrue(tapWhenFrameReady(saveAction, timeout: 8), "Calendar add-event save action did not become tappable.")
        XCTAssertTrue(
            waitUntil(timeout: 14) { !app.textFields["add-event-title-input"].exists },
            "Calendar add-event sheet did not close after saving \(title)."
        )
    }

    @MainActor
    private func calendarAddEventAction(in app: XCUIApplication) -> XCUIElement {
        let headerAction = app.buttons["calendar-add-event-action"]
        if headerAction.exists { return headerAction }
        return app.buttons["home-primary-action"]
    }

    @MainActor
    private func assertPlantCalendarRow(named plantName: String, exists expected: Bool, in app: XCUIApplication, context: String) {
        let row = plantCalendarRow(named: plantName, in: app)
        if expected, !waitUntil(timeout: 4, condition: { row.exists }) {
            for _ in 0 ..< 18 where !row.exists {
                app.swipeUp()
                RunLoop.current.run(until: Date().addingTimeInterval(0.25))
            }
        }
        let didMatch = waitUntil(timeout: expected ? 10 : 3) {
            row.exists == expected
        }
        XCTAssertTrue(
            didMatch,
            "Calendar plant row for \(plantName) existence was \(row.exists), expected \(expected) during \(context)."
        )
    }

    @MainActor
    private func plantCalendarRow(named plantName: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier CONTAINS[c] %@",
                "calendar-event-row-",
                plantName
            ))
            .firstMatch
    }

    @MainActor
    private func assertCalendarEvent(_ title: String, exists expected: Bool, in app: XCUIApplication, context: String) {
        let row = app.descendants(matching: .any)["calendar-event-row-\(title)"]
        if expected, !waitUntil(timeout: 4, condition: { row.exists }) {
            scrollToElement(row, in: app, maxSwipes: 8)
        }
        let didMatch = waitUntil(timeout: expected ? 10 : 3) {
            row.exists == expected
        }
        XCTAssertTrue(
            didMatch,
            "Calendar event \(title) existence was \(row.exists), expected \(expected) during \(context)."
        )
    }

    @MainActor
    private func permanentlyDeletePlant(named plantName: String, in app: XCUIApplication) {
        tapPlantDetailDeleteAction(in: app)
        tapPlantDeleteConfirmation(in: app)
        XCTAssertTrue(
            tapWhenFrameReady(app.buttons["plant-detail-delete-now"], timeout: 4),
            "Plant delete-now action did not become frame-ready before the undo window closed."
        )

        let didLeaveDeletedDetail = waitUntil(timeout: 14) {
            !app.descendants(matching: .any)["plant-detail-screen"].exists || containsAnyMarker(["Content is no longer available"], in: app)
        }
        XCTAssertTrue(didLeaveDeletedDetail, "Permanent plant deletion did not remove the detail content.")
    }

    @MainActor
    private func tapPlantDetailDeleteAction(in app: XCUIApplication) {
        let deleteAction = app.buttons["plant-detail-delete-action"]
        XCTAssertTrue(
            waitForTapFrame(deleteAction, in: app, timeout: 8),
            "Plant detail delete action did not become visible."
        )
        deleteAction.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    private func tapPlantDeleteConfirmation(in app: XCUIApplication) {
        let alertDelete = app.alerts.buttons["Delete"]
        if tapWhenFrameReady(alertDelete, timeout: 4) {
            return
        }

        let globalDelete = app.buttons["Delete"]
        XCTAssertTrue(tapWhenFrameReady(globalDelete, timeout: 8), "Plant delete confirmation did not expose a tappable Delete action.")
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
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                guard !nameField.exists else { return true }
                guard addPetCard.exists, addPetCard.isEnabled else { return false }
                let frame = addPetCard.frame
                return frame.width > 1 && frame.height > 1 && isFiniteFrame(frame)
            },
            "Today Focus first-pet action did not appear."
        )
        if nameField.exists { return }
        XCTAssertTrue(
            addPetCard.label.hasPrefix("Add your first pet") &&
                addPetCard.label.count > "Add your first pet".count,
            "Today Focus first-pet action did not expose its complete English accessibility label: \(addPetCard.label)"
        )
        XCTAssertTrue(
            tapWhenFrameReady(addPetCard, timeout: 4),
            "Today Focus first-pet action did not expose a stable touch frame."
        )
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
        postSaveMarkerIdentifiers: [String]
    ) {
        XCTAssertFalse(
            postSaveMarkerIdentifiers.isEmpty,
            "Member creation requires an explicit post-save marker."
        )
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
            return app.state == .runningForeground &&
                didReachExpectedMarker &&
                !nameField.exists &&
                !creationPrimary.exists &&
                !handoffTitle.exists
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
            selectFirstPetSpeciesIfPresent(in: app)
            selectFirstPetBreedIfPresent(in: app)
            selectFirstPetAppearanceIfPresent(in: app)
            let actionLabel = creationPrimary.label
            tapWhenHittable(creationPrimary, timeout: 8)
            if actionLabel.contains("Join Island") || actionLabel.contains("加入岛屿") || actionLabel.contains("Insel beitreten") {
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
    private func fillStarterPetWeightIfNeeded(in app: XCUIApplication, value _: String, waitForInput _: Bool) {
        // 体重已从添加宠物流程移除:此步不再存在,保留为无操作以兼容既有调用点。
        _ = app
    }

    @MainActor
    private func selectFirstPetBreedIfPresent(in app: XCUIApplication) {
        let breedMenu = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@ OR label CONTAINS %@", "Breed", "品种", "Rasse"))
            .firstMatch
        guard breedMenu.waitForExistence(timeout: 4) else { return } // 人类创建无品种菜单
        let placeholderLabel = breedMenu.label
        let creationPrimary = app.buttons["member-creation-primary-action"]
        if creationPrimary.isEnabled { return }
        let selectionWasRequired = creationPrimary.exists && !creationPrimary.isEnabled

        for _ in 0 ..< 3 {
            guard tapWhenFrameReady(breedMenu, timeout: 8) else { continue }
            let breedMenuList = app.collectionViews.firstMatch
            guard breedMenuList.waitForExistence(timeout: 6) else { continue }
            let option = breedMenuList.cells.element(boundBy: 0).buttons.firstMatch
            guard option.waitForExistence(timeout: 6) else { continue }
            guard tapWhenFrameReady(option, timeout: 8) else { continue }

            if waitUntil(timeout: 4, condition: {
                (breedMenu.exists && breedMenu.label != placeholderLabel) ||
                    (selectionWasRequired && creationPrimary.exists && creationPrimary.isEnabled)
            }) {
                return
            }
        }

        XCTFail("Pet creation breed selection did not apply. Current menu label: \(breedMenu.label)")
    }

    @MainActor
    private func selectFirstPetSpeciesIfPresent(in app: XCUIApplication) {
        let speciesMenu = app.buttons["member-pet-species-picker"]
        guard speciesMenu.exists else { return }
        let creationPrimary = app.buttons["member-creation-primary-action"]
        if creationPrimary.isEnabled { return }

        for _ in 0 ..< 3 {
            guard tapWhenFrameReady(speciesMenu, timeout: 8) else { continue }
            let options = ["Dog", "狗", "Hund"]
            guard let option = options
                .map({ app.buttons[$0].firstMatch })
                .first(where: { $0.waitForExistence(timeout: 2) }) else { continue }
            guard tapWhenFrameReady(option, timeout: 8) else { continue }
            if waitUntil(timeout: 4, condition: {
                app.buttons["member-pet-breed-picker"].exists
            }) {
                return
            }
        }
        XCTFail("Pet creation species selection did not apply.")
    }

    @MainActor
    private func selectFirstPetAppearanceIfPresent(in app: XCUIApplication) {
        let coatMenu = app.buttons["member-pet-coat-picker"]
        guard coatMenu.exists else { return }
        let creationPrimary = app.buttons["member-creation-primary-action"]
        if creationPrimary.isEnabled { return }

        let boy = app.buttons["member-gender-boy"]
        if boy.waitForExistence(timeout: 3) {
            tapWhenFrameReady(boy, timeout: 4)
        }

        for _ in 0 ..< 3 {
            guard tapWhenFrameReady(coatMenu, timeout: 8) else { continue }
            let menu = app.collectionViews.firstMatch
            guard menu.waitForExistence(timeout: 6) else { continue }
            let option = menu.cells.element(boundBy: 0).buttons.firstMatch
            guard option.waitForExistence(timeout: 6) else { continue }
            guard tapWhenFrameReady(option, timeout: 8) else { continue }
            if waitUntil(timeout: 4, condition: { creationPrimary.isEnabled }) {
                return
            }
        }
        XCTFail("Pet creation appearance selection did not apply.")
    }

    @MainActor
    private func typeText(_ text: String, intoTextField identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Text field did not appear: \(identifier)")
        scrollToElement(field, in: app, maxSwipes: 8)
        scrollElementAboveKeyboardIfNeeded(field, in: app)
        XCTAssertTrue(tapWhenFrameReady(field, timeout: 8), "Text field did not become tappable: \(identifier)")
        if !(waitForKeyboardFocus(on: field, timeout: 2) || app.keyboards.firstMatch.waitForExistence(timeout: 2)) {
            _ = tapWhenFrameReady(field, timeout: 1)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
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
        if !(waitForKeyboardFocus(on: field, timeout: 2) || app.keyboards.firstMatch.waitForExistence(timeout: 2)) {
            _ = tapWhenFrameReady(field, timeout: 1)
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        field.press(forDuration: 0.8)
        let selectAllButton = app.buttons["Select All"]
        let selectAllMenuItem = app.menuItems["Select All"]
        if tapWhenFrameReady(selectAllButton, timeout: 2) {
            // Selection is ready for replacement.
        } else if tapWhenFrameReady(selectAllMenuItem, timeout: 2) {
            // Selection is ready for replacement.
        } else {
            field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        }
        field.typeText(text)
        XCTAssertTrue(
            waitUntil(timeout: 4) { String(describing: field.value ?? "") == text },
            "Text field did not accept the exact replacement text: \(identifier) value=\(String(describing: field.value ?? ""))"
        )
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
    private func waitForAnyMarkerAfterVerticalSearch(
        _ markers: [String],
        in app: XCUIApplication,
        earlierDrags: Int,
        laterDrags: Int
    ) -> Bool {
        if containsAnyMarker(markers, in: app, timeout: 2) {
            return true
        }

        for _ in 0 ..< earlierDrags {
            dragTowardEarlierContent(in: app)
            if containsAnyMarker(markers, in: app, timeout: 1) {
                return true
            }
        }

        for _ in 0 ..< laterDrags {
            dragTowardLaterContent(in: app)
            if containsAnyMarker(markers, in: app, timeout: 1) {
                return true
            }
        }

        return containsAnyMarker(markers, in: app)
    }

    @MainActor
    private func dragTowardEarlierContent(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.24))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        start.press(forDuration: 0.04, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
    }

    @MainActor
    private func dragTowardLaterContent(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.24))
        start.press(forDuration: 0.04, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
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
        let didBecomeHittable = waitUntil(timeout: timeout) {
            element.exists && element.isEnabled && element.isHittable
        }
        if didBecomeHittable {
            element.tap()
            return
        }

        let didBecomeFrameReady = waitForFrameReady(element, timeout: 1)
        let elementValue = element.value.map { String(describing: $0) } ?? "nil"
        XCTAssertTrue(
            didBecomeFrameReady,
            "Element did not become hittable or frame-ready: \(element) exists=\(element.exists) enabled=\(element.isEnabled) hittable=\(element.isHittable) frame=\(element.frame) label=\(element.label) value=\(elementValue)"
        )
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForFrameReady(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            guard element.exists, element.isEnabled else { return false }
            let frame = element.frame
            return frame.width > 1 && frame.height > 1 && isFiniteFrame(frame)
        }
    }

    private func elementDebugState(_ element: XCUIElement) -> String {
        let elementValue = element.value.map { String(describing: $0) } ?? "nil"
        return "exists=\(element.exists) enabled=\(element.isEnabled) hittable=\(element.isHittable) frame=\(element.frame) label=\(element.label) value=\(elementValue)"
    }

    private func waitForTapFrame(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            isTapFrameVisible(element, in: app)
        }
    }

    private func waitForTapFrameHittable(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        waitUntil(timeout: timeout) {
            isTapFrameHittable(element, in: app)
        }
    }

    private func isTapFrameHittable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        isTapFrameVisible(element, in: app) && element.isHittable
    }

    private func isTapFrameVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        guard element.exists, element.isEnabled else { return false }
        let frame = element.frame
        guard frame.width > 1, frame.height > 1, isFiniteFrame(frame) else { return false }
        return app.frame.insetBy(dx: 0, dy: 8).contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    private func assertFrame(_ frame: CGRect, isNear expected: CGRect, tolerance: CGFloat, message: String) {
        XCTAssertLessThanOrEqual(abs(frame.midX - expected.midX), tolerance, message)
        XCTAssertLessThanOrEqual(abs(frame.midY - expected.midY), tolerance, message)
        XCTAssertLessThanOrEqual(abs(frame.width - expected.width), tolerance, message)
        XCTAssertLessThanOrEqual(abs(frame.height - expected.height), tolerance, message)
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

    @MainActor
    private func scrollSettingsDown(in app: XCUIApplication) {
        let settingsScroll = app.scrollViews["settings-main-scroll"]
        if settingsScroll.exists {
            settingsScroll.swipeUp(velocity: .fast)
        } else {
            app.swipeUp(velocity: .fast)
        }
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

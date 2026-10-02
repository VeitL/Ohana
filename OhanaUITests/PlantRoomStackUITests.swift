//
//  PlantRoomStackUITests.swift
//  OhanaUITests
//

import XCTest

final class PlantRoomStackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        guard let testRun, testRun.totalFailureCount > 0 else { return }
        await MainActor.run {
            UITestInteraction.captureFailureSnapshot()
            UITestInteraction.respondToPendingAuthorization(assertDismissal: false)
        }
    }

    @MainActor
    func testRoomStacksOpenIntoTheExistingPlantDeck() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-appLanguage", "en",
            "-OHANA_UI_TESTS",
            "-OHANA_RESET_PERSISTENT_STATE",
            "-OHANA_ENABLE_PRODUCTION_OVERLAYS_IN_UI_TESTS",
            "-OHANA_UI_TEST_SEED_HUMAN_BASELINE",
            "-OHANA_UI_TEST_HUMAN_BASELINE_NAME", "Codex Plant Stack Human",
            "-OHANA_UI_TEST_SEED_MEMBER_CARD_BASELINE",
            "-OHANA_UI_TEST_SEED_PLANT_BASELINE",
            "-OHANA_UI_TEST_PLANT_BASELINE_COUNT", "24",
            "-OHANA_UI_TEST_PLANT_BASELINE_ROOM_COUNT", "6",
            "-OHANA_UI_TEST_UNLOCK_REWARD_TIER"
        ]
        UITestInteraction.installAuthorizationMonitor(on: self)
        UITestInteraction.respondToPendingAuthorization()
        app.launch()
        UITestInteraction.respondToPendingAuthorization()

        let standardMode = app.buttons["app-experience-standard"]
        if standardMode.waitForExistence(timeout: 3) {
            standardMode.tap()
        }

        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 20), "Plants tab did not appear for the room-stack fixture.")
        let zenIntroductionDismiss = app.buttons["zen-introduction-banner"]
        if zenIntroductionDismiss.waitForExistence(timeout: 3) {
            XCTAssertTrue(
                waitUntil(timeout: 3) {
                    zenIntroductionDismiss.isEnabled && zenIntroductionDismiss.isHittable
                },
                "The Zen introduction obscured Home without exposing its dismiss action."
            )
            zenIntroductionDismiss.tap()
            XCTAssertTrue(
                waitUntil(timeout: 4) { !zenIntroductionDismiss.exists },
                "The Zen introduction stayed visible after dismissal."
            )
        }
        plantsTab.tap()

        let overview = app.descendants(matching: .any)["home-plants-room-stack-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 12), "Room card-stack overview did not appear.")
        let overviewScroll = app.scrollViews.containing(.any, identifier: "home-plants-room-stack-overview").firstMatch
        let initialViewport = try observeViewport(overviewScroll, in: app)

        let initialRoomStackIdentifiers = [
            "home-plants-room-stack-living-room",
            "home-plants-room-stack-balcony",
            "home-plants-room-stack-kitchen",
            "home-plants-room-stack-bedroom"
        ]
        for identifier in initialRoomStackIdentifiers {
            let stack = app.buttons[identifier]
            XCTAssertTrue(stack.waitForExistence(timeout: 8), "Room card stack \(identifier) did not appear.")
            XCTAssertTrue(
                initialViewport.elements.contains {
                    $0.identifier == identifier && isVisible($0, in: initialViewport.frame, fullyContained: true)
                },
                "Four room stacks should fit in the initial viewport. \(identifier) was clipped."
            )
            XCTAssertTrue(stack.isHittable, "Initial room stack \(identifier) did not expose an activation point.")
        }
        keepScreenshot(named: "plant-room-stacks-six-room-top", app: app)

        let roomStackIdentifiers = Set(initialRoomStackIdentifiers + [
            "home-plants-room-stack-office",
            "home-plants-room-stack-study"
        ])
        var seenRoomStacks = Set<String>()
        for _ in 0 ..< 6 {
            let observation = try observeViewport(overviewScroll, in: app)
            for element in observation.elements where roomStackIdentifiers.contains(element.identifier) && isVisible(element, in: observation.frame) {
                seenRoomStacks.insert(element.identifier)
            }
            if seenRoomStacks == roomStackIdentifiers { break }
            overviewScroll.swipeUp()
        }
        XCTAssertEqual(seenRoomStacks, roomStackIdentifiers, "The room overview should continue scrolling beyond four stacks.")
        keepScreenshot(named: "plant-room-stacks-six-room-lower", app: app)

        let studyStack = app.buttons["home-plants-room-stack-study"]
        let lowerViewport = try observeViewport(overviewScroll, in: app)
        XCTAssertTrue(
            lowerViewport.elements.contains {
                $0.identifier == "home-plants-room-stack-study" && isVisible($0, in: lowerViewport.frame)
            },
            "The sixth room stack did not enter the current scroll viewport."
        )
        XCTAssertTrue(studyStack.isHittable, "The sixth room stack should be tappable after scrolling.")
        studyStack.tap()

        let closeRoom = app.buttons["home-plants-room-stack-close"]
        XCTAssertTrue(closeRoom.waitForExistence(timeout: 8), "Opening a room stack did not expose the room deck header.")
        let plantCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home-card-plant-")
        )
        XCTAssertTrue(waitUntil(timeout: 10) { plantCards.count == 4 }, "Study should open all four of its real plant cards.")
        keepScreenshot(named: "plant-room-stack-open", app: app)

        closeRoom.tap()
        let expandAll = app.buttons["home-plants-expand-all"]
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                overview.exists || expandAll.exists
            },
            "Closing the room did not restore the stack overview."
        )
        XCTAssertTrue(expandAll.waitForExistence(timeout: 8), "Expand all did not appear on the stack overview.")
        expandAll.tap()

        let expandedView = app.descendants(matching: .any)["home-plants-all-expanded-view"]
        XCTAssertTrue(expandedView.waitForExistence(timeout: 8), "Expand all did not reveal the grouped compact-card grid.")
        let expandedScroll = app.scrollViews.containing(.any, identifier: "home-plants-all-expanded-view").firstMatch
        XCTAssertTrue(
            waitUntil(timeout: 8) {
                guard let observation = try? observeViewport(expandedScroll, in: app) else { return false }
                return observation.elements.count {
                    $0.elementType == .button && $0.identifier.hasPrefix("home-plants-all-expanded-card-") &&
                        isVisible($0, in: observation.frame)
                } >= 4
            },
            "Expanded rooms did not expose the denser four-column card grid."
        )
        keepScreenshot(named: "plant-all-rooms-expanded-compact", app: app)

        let expandedRoomIdentifiers = Set([
            "home-plants-all-expanded-room-living-room",
            "home-plants-all-expanded-room-balcony",
            "home-plants-all-expanded-room-kitchen",
            "home-plants-all-expanded-room-bedroom",
            "home-plants-all-expanded-room-office",
            "home-plants-all-expanded-room-study"
        ])
        var seenExpandedRooms = Set<String>()
        var seenExpandedCards = Set<String>()
        for _ in 0 ..< 10 {
            // Lazy grids can mount/unmount between count and indexed queries.
            // Read identifiers and geometry from one immutable observation,
            // and observe again after each scroll instead of caching AX nodes.
            let observation = try observeViewport(expandedScroll, in: app)
            for element in observation.elements where isVisible(element, in: observation.frame) {
                let identifier = element.identifier
                if expandedRoomIdentifiers.contains(identifier) {
                    seenExpandedRooms.insert(identifier)
                }
                if element.elementType == .button, identifier.hasPrefix("home-plants-all-expanded-card-") {
                    seenExpandedCards.insert(identifier)
                }
            }
            if seenExpandedRooms == expandedRoomIdentifiers, seenExpandedCards.count == 24 { break }
            expandedScroll.swipeUp()
        }
        XCTAssertEqual(seenExpandedRooms, expandedRoomIdentifiers, "Expand all should group every card under its room.")
        XCTAssertEqual(seenExpandedCards.count, 24, "Expand all should remain vertically scrollable through every compact card.")

        let collapseAll = app.buttons["home-plants-collapse-all"]
        XCTAssertTrue(collapseAll.waitForExistence(timeout: 8), "Collapse did not remain available in the expanded grid.")
        collapseAll.tap()
        XCTAssertTrue(overview.waitForExistence(timeout: 8), "Collapse did not restore the vertically scrolling room stacks.")
    }

    private struct ViewportObservation {
        let frame: CGRect
        let elements: [XCUIElementSnapshot]
    }

    @MainActor
    private func observeViewport(_ scrollView: XCUIElement, in app: XCUIApplication) throws -> ViewportObservation {
        let snapshot = try scrollView.snapshot()
        guard let frame = UITestInteraction.visibleFrame(for: snapshot.frame, in: app.frame) else {
            throw NSError(domain: "PlantRoomStackUIObservation", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "The current plant scroll view has no readable viewport."
            ])
        }
        var remaining = snapshot.children
        var elements = [XCUIElementSnapshot]()
        while let element = remaining.popLast() {
            elements.append(element)
            remaining.append(contentsOf: element.children)
        }
        return ViewportObservation(frame: frame, elements: elements)
    }

    private func isVisible(_ element: XCUIElementSnapshot, in viewport: CGRect, fullyContained: Bool = false) -> Bool {
        let frame = element.frame
        guard UITestInteraction.isUsable(frame) else { return false }
        if fullyContained { return viewport.insetBy(dx: -1, dy: -1).contains(frame) }
        return viewport.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        UITestInteraction.wait(timeout: timeout, condition: condition)
    }

    @MainActor
    private func keepScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }
}

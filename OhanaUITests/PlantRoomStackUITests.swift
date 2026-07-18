//
//  PlantRoomStackUITests.swift
//  OhanaUITests
//

import XCTest

final class PlantRoomStackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRoomStacksOpenIntoTheExistingPlantDeck() {
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
        app.launch()

        let standardMode = app.buttons["app-experience-standard"]
        if standardMode.waitForExistence(timeout: 3) {
            standardMode.tap()
        }

        let plantsTab = app.buttons["home-tab-plants"]
        XCTAssertTrue(plantsTab.waitForExistence(timeout: 20), "Plants tab did not appear for the room-stack fixture.")
        plantsTab.tap()

        let overview = app.descendants(matching: .any)["home-plants-room-stack-overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 12), "Room card-stack overview did not appear.")

        let initialRoomStackIdentifiers = [
            "home-plants-room-stack-living-room",
            "home-plants-room-stack-balcony",
            "home-plants-room-stack-kitchen",
            "home-plants-room-stack-bedroom"
        ]
        for identifier in initialRoomStackIdentifiers {
            let stack = app.buttons[identifier]
            XCTAssertTrue(stack.waitForExistence(timeout: 8), "Room card stack \(identifier) did not appear.")
            XCTAssertTrue(stack.isHittable, "Four room stacks should fit in the initial viewport. \(identifier) was clipped.")
        }
        keepScreenshot(named: "plant-room-stacks-six-room-top", app: app)

        let roomStackIdentifiers = Set(initialRoomStackIdentifiers + [
            "home-plants-room-stack-office",
            "home-plants-room-stack-study"
        ])
        var seenRoomStacks = Set<String>()
        for _ in 0 ..< 6 {
            for identifier in roomStackIdentifiers {
                let stack = app.buttons[identifier]
                if stack.exists, stack.isHittable {
                    seenRoomStacks.insert(identifier)
                }
            }
            if seenRoomStacks == roomStackIdentifiers { break }
            app.swipeUp()
        }
        XCTAssertEqual(seenRoomStacks, roomStackIdentifiers, "The room overview should continue scrolling beyond four stacks.")
        keepScreenshot(named: "plant-room-stacks-six-room-lower", app: app)

        let studyStack = app.buttons["home-plants-room-stack-study"]
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
        XCTAssertTrue(overview.waitForExistence(timeout: 8), "Closing the room did not restore the stack overview.")

        let expandAll = app.buttons["home-plants-expand-all"]
        XCTAssertTrue(expandAll.waitForExistence(timeout: 8), "Expand all did not appear on the stack overview.")
        expandAll.tap()

        let expandedView = app.descendants(matching: .any)["home-plants-all-expanded-view"]
        XCTAssertTrue(expandedView.waitForExistence(timeout: 8), "Expand all did not reveal the grouped compact-card grid.")
        let expandedCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home-plants-all-expanded-card-")
        )
        XCTAssertTrue(waitUntil(timeout: 8) { expandedCards.count >= 4 }, "Expanded rooms did not expose the denser four-column card grid.")
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
            for identifier in expandedRoomIdentifiers where app.descendants(matching: .any)[identifier].exists {
                seenExpandedRooms.insert(identifier)
            }
            for index in 0 ..< expandedCards.count {
                let identifier = expandedCards.element(boundBy: index).identifier
                if !identifier.isEmpty {
                    seenExpandedCards.insert(identifier)
                }
            }
            if seenExpandedRooms == expandedRoomIdentifiers, seenExpandedCards.count == 24 { break }
            app.swipeUp()
        }
        XCTAssertEqual(seenExpandedRooms, expandedRoomIdentifiers, "Expand all should group every card under its room.")
        XCTAssertEqual(seenExpandedCards.count, 24, "Expand all should remain vertically scrollable through every compact card.")

        let collapseAll = app.buttons["home-plants-collapse-all"]
        XCTAssertTrue(collapseAll.waitForExistence(timeout: 8), "Collapse did not remain available in the expanded grid.")
        collapseAll.tap()
        XCTAssertTrue(overview.waitForExistence(timeout: 8), "Collapse did not restore the vertically scrolling room stacks.")
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return condition()
    }

    @MainActor
    private func keepScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

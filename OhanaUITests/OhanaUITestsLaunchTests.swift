//
//  OhanaUITestsLaunchTests.swift
//  OhanaUITests
//
//  Created by Guanchenulous on 01.03.26.
//

import XCTest

final class OhanaUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

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
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US",
            "-appLanguage",
            "en",
            "-OHANA_UI_TESTS",
            "-OHANA_RESET_PERSISTENT_STATE",
            "-OHANA_UI_TEST_ENABLE_ANIMATIONS"
        ]
        UITestInteraction.installAuthorizationMonitor(on: self)
        UITestInteraction.respondToPendingAuthorization()
        app.launch()
        UITestInteraction.respondToPendingAuthorization()

        let standardMode = app.buttons["app-experience-standard"]
        if standardMode.waitForExistence(timeout: 8) {
            standardMode.tap()
        }

        XCTAssertTrue(
            app.textFields["onboarding-human-name-input"].waitForExistence(timeout: 25),
            "Cold launch did not reach the first meaningful Human onboarding screen."
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Cold launch - first meaningful onboarding screen"
        attachment.lifetime = .deleteOnSuccess
        add(attachment)
    }
}

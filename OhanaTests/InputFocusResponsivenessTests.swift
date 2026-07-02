import Foundation
import XCTest

final class InputFocusResponsivenessTests: XCTestCase {
    func testKeyboardToolbarIsNotMountedOnRootNavigationStack() throws {
        let rootURL = repositoryRootURL()
        let contentSource = try source("Ohana/App/ContentView.swift", rootURL: rootURL)
        let addEventSource = try source("Ohana/Features/Calendar/Views/AddEventView.swift", rootURL: rootURL)

        XCTAssertFalse(contentSource.contains("ToolbarItemGroup(placement: .keyboard)"))
        XCTAssertFalse(contentSource.contains("ignoresSafeArea(.keyboard"))
        XCTAssertFalse(contentSource.contains("private func dismissKeyboard()"))
        XCTAssertTrue(addEventSource.contains("ToolbarItemGroup(placement: .keyboard)"))
    }

    func testStartupMaintenanceWarmsTextInputWithoutStealingActiveFocus() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/App/StartupMaintenanceCoordinator.swift", rootURL: rootURL)

        XCTAssertTrue(source.contains("InputLatencyWarmupService.warmUpOnce()"))
        XCTAssertTrue(source.contains("warmUpTextInputSystem(startedAt: startedAt)"))
        XCTAssertTrue(source.contains("currentFirstResponder() == nil"))
        XCTAssertTrue(source.contains("UIView.performWithoutAnimation"))
        XCTAssertTrue(source.contains("textField.becomeFirstResponder()"))
        XCTAssertTrue(source.contains("textField.resignFirstResponder()"))
        XCTAssertTrue(source.contains("OhanaFeedback.prepareInteraction()"))
    }

    func testKeyboardFrameUpdatesDoNotAnimateFullSheets() throws {
        let rootURL = repositoryRootURL()
        let addEventSource = try source("Ohana/Features/Calendar/Views/AddEventView.swift", rootURL: rootURL)
        let quickFeedPresentation = try source("Ohana/Features/Feeding/Views/QuickFeedDetailContent+Presentation.swift", rootURL: rootURL)
        let quickFeedSheet = try source("Ohana/Features/Feeding/Views/QuickFeedDetailSheet.swift", rootURL: rootURL)

        XCTAssertFalse(addEventSource.contains("withAnimation(GoMotion.quick) {\n                keyboardHeight"))
        XCTAssertTrue(addEventSource.contains("guard abs(keyboardHeight - height) > 0.5 else { return }"))
        XCTAssertFalse(quickFeedPresentation.contains(".animation(GoMotion.page, value: inlineKeyboardHeight)"))
        XCTAssertFalse(quickFeedPresentation.contains("withAnimation(GoMotion.quick) {\n            inlineKeyboardHeight"))
        XCTAssertFalse(quickFeedSheet.contains("withAnimation(GoMotion.quick) {\n                    inlineKeyboardHeight"))
        XCTAssertTrue(quickFeedPresentation.contains("guard abs(inlineKeyboardHeight - height) > 0.5 else { return }"))
    }

    func testSharedTextFieldFocusDoesNotDriveImplicitAnimation() throws {
        let rootURL = repositoryRootURL()
        let formSource = try source("Ohana/Shared/Components/OhanaFormControls.swift", rootURL: rootURL)
        let draftSource = try source("Ohana/Shared/Components/GoDraftInput.swift", rootURL: rootURL)
        let numericSource = try source("Ohana/Shared/Components/InlineNumericInput.swift", rootURL: rootURL)

        XCTAssertFalse(formSource.contains(".animation(GoMotion.stateChange, value: isFocused)"))
        XCTAssertTrue(formSource.contains("transaction.animation = nil"))
        XCTAssertTrue(draftSource.contains("transaction.animation = nil"))
        XCTAssertTrue(draftSource.contains("commitTask = nil"))
        XCTAssertFalse(numericSource.contains("GoKeyboard.dismiss()"))
        XCTAssertTrue(numericSource.contains("transaction.animation = nil"))
    }

    func testCoconutBalanceSelectionSyncDoesNotWriteInputDuringOnChangeFrame() throws {
        let rootURL = repositoryRootURL()
        let source = try source("Ohana/Features/Economy/Views/SettingsCoconutBalanceTestView.swift", rootURL: rootURL)

        XCTAssertTrue(source.contains("@State private var selectionSyncTask: Task<Void, Never>?"))
        XCTAssertTrue(source.contains("scheduleSelectionSync(for: newValue)"))
        XCTAssertTrue(source.contains("OhanaFrameScheduler.runAfterNextFrame"))
        XCTAssertFalse(source.contains(".onChange(of: selectedHumanId) { _, _ in\n            amountText ="))
        XCTAssertFalse(source.contains("withAnimation(GoMotion.feedback) {\n                selectedHumanId"))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appendingPathComponent(path), encoding: .utf8)
    }
}

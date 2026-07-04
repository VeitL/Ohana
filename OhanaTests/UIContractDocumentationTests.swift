import Foundation
import XCTest

final class UIContractDocumentationTests: XCTestCase {
    func testOhanaUISpecIsDocumentedAndReachableFromDebugSettings() throws {
        let rootURL = repositoryRootURL()
        let specSource = try source("docs/design/ohana-ui-spec.md", rootURL: rootURL)
        let templateSource = try source("docs/ui-v4-new-page-template.md", rootURL: rootURL)
        let settingsSource = try source("Ohana/Features/Settings/Views/SettingsView+Debug.swift", rootURL: rootURL)
        let settingsShellSource = try source("Ohana/Features/Settings/Views/SettingsView.swift", rootURL: rootURL)
        let showcaseSource = try source("Ohana/Features/Settings/DesignLab/OhanaUISpecShowcaseView.swift", rootURL: rootURL)

        XCTAssertTrue(specSource.contains("# Ohana UI Specification"))
        XCTAssertTrue(specSource.contains("UI contract: <canonical existing surface/path>"))
        XCTAssertTrue(specSource.contains("QuickFeedDetailSheet.swift"))
        XCTAssertTrue(specSource.contains("### Control Rows"))
        XCTAssertTrue(specSource.contains("DatePicker(selection:displayedComponents:)"))
        XCTAssertTrue(specSource.contains("OhanaMinimalBarChart"))
        XCTAssertTrue(specSource.contains("ui-ux-pro-max"))
        XCTAssertTrue(specSource.contains("Smoothness compliance before calling a strict task complete"))
        XCTAssertTrue(specSource.contains("First-render data"))
        XCTAssertTrue(templateSource.contains("docs/design/ohana-ui-spec.md"))
        XCTAssertTrue(templateSource.contains("Visible first-screen content must be seeded from route data"))

        XCTAssertTrue(settingsSource.contains("UI 规范展示"))
        XCTAssertTrue(settingsSource.contains("settings-debug-ui-spec-showcase"))
        XCTAssertTrue(settingsShellSource.contains("@State var showingUISpecShowcase = false"))
        XCTAssertTrue(settingsShellSource.contains("OhanaUISpecShowcaseView()"))

        XCTAssertTrue(showcaseSource.contains("struct OhanaUISpecShowcaseView: View"))
        XCTAssertTrue(showcaseSource.contains("Strict Smoothness Matrix"))
        XCTAssertTrue(showcaseSource.contains("specToggleRow"))
        XCTAssertTrue(showcaseSource.contains("specDatePickerRow"))
        XCTAssertTrue(showcaseSource.contains("specSegmentedPickerRow"))
        XCTAssertTrue(showcaseSource.contains("OhanaTextField("))
        XCTAssertTrue(showcaseSource.contains("accessibilityIdentifier(\"ui-spec-showcase-toggle-row\")"))
        XCTAssertTrue(showcaseSource.contains("accessibilityIdentifier(\"ui-spec-showcase-date-row\")"))
        XCTAssertTrue(showcaseSource.contains("accessibilityIdentifier(\"ui-spec-showcase-component-reference\")"))
        XCTAssertTrue(showcaseSource.contains("accessibilityIdentifier(\"ui-spec-showcase\")"))
        XCTAssertTrue(showcaseSource.contains("OhanaStaticAppBackground()"))
        XCTAssertFalse(showcaseSource.contains("SwiftData"))
        XCTAssertFalse(showcaseSource.contains("ModelContext"))
        XCTAssertFalse(showcaseSource.contains("@Query"))
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

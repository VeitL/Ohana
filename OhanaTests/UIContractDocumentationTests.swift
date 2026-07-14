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

    func testFigmaGapComponentsHaveCanonicalSwiftUIOwners() throws {
        let rootURL = repositoryRootURL()
        let formSource = try source("Ohana/Shared/Components/OhanaFormControls.swift", rootURL: rootURL)
        let stateSource = try source("Ohana/Shared/Components/OhanaStateComponents.swift", rootURL: rootURL)
        let showcaseSource = try source("Ohana/Features/Settings/DesignLab/OhanaUISpecShowcaseView.swift", rootURL: rootURL)

        XCTAssertTrue(formSource.contains("struct OhanaPickerRow: View"))
        XCTAssertTrue(formSource.contains(".frame(minHeight: 64)"))
        XCTAssertTrue(formSource.contains("Color.ohanaCardSurfaceElevated"))
        XCTAssertTrue(formSource.contains(".accessibilityValue(valueText)"))

        XCTAssertTrue(stateSource.contains("struct OhanaPermissionCard: View"))
        XCTAssertTrue(stateSource.contains("struct OhanaFeedbackState: View"))
        XCTAssertTrue(stateSource.contains("enum OhanaPermissionState: Equatable, Sendable"))
        XCTAssertTrue(stateSource.contains("enum OhanaFeedbackStateKind: Equatable, Sendable"))
        XCTAssertTrue(stateSource.contains(".frame(minHeight: 44)"))
        XCTAssertTrue(stateSource.contains("background: .alertInfoBg"))
        XCTAssertTrue(stateSource.contains("background: .alertWarningBg"))
        XCTAssertTrue(stateSource.contains("background: .alertErrorBg"))
        XCTAssertTrue(stateSource.contains("background: .alertSuccessBg"))
        XCTAssertFalse(stateSource.contains("SwiftData"))
        XCTAssertFalse(stateSource.contains("@Query"))
        XCTAssertFalse(stateSource.contains("ModelContext"))

        XCTAssertTrue(showcaseSource.contains("OhanaPickerRow("))
        XCTAssertTrue(showcaseSource.contains("OhanaPermissionCard("))
        XCTAssertTrue(showcaseSource.contains("OhanaFeedbackState("))
        XCTAssertTrue(showcaseSource.contains("ui-spec-showcase-picker-row"))
        XCTAssertTrue(showcaseSource.contains("ui-spec-showcase-permission-card"))
        XCTAssertTrue(showcaseSource.contains("ui-spec-showcase-feedback-state"))
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

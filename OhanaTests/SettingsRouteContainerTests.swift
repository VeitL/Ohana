import Foundation
import Testing

struct SettingsRouteContainerTests {
    @Test func settingsRoutePresentsSettingsBeforeOptionalDataFetches() throws {
        let rootURL = repositoryRootURL()
        let source = try source(
            "Ohana/Features/Settings/SettingsRouteContainer.swift",
            rootURL: rootURL
        )

        let start = try #require(source.range(of: "struct AppSettingsSheetRouteContainer")?.lowerBound)
        let end = try #require(source.range(of: "private struct SettingsRouteData")?.lowerBound)
        let routeContainer = String(source[start ..< end])

        #expect(!routeContainer.contains("@Query"))
        #expect(!routeContainer.contains("if data.hasLoaded"))
        #expect(!source.contains("SettingsRouteLoadingView"))
        #expect(routeContainer.contains("SettingsView("))
        #expect(routeContainer.contains("OhanaFrameScheduler.runAfterNextFrame"))
        #expect(routeContainer.contains(".onReceive(appServices.domainRevisions.homeRevisionUpdates)"))
        #expect(routeContainer.contains("guard dataLoadTask == nil else { return }"))
    }

    @Test func settingsBiometricAvailabilityIsRefreshedOnAppear() throws {
        let source = try source(
            "Ohana/Features/Settings/Views/SettingsView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("@State var biometricGateAvailability = MemberGateBiometricAvailability.unavailable"))
        #expect(!source.contains("@State var biometricGateAvailability = MemberGateBiometricAuthenticator.availability()"))
        #expect(source.contains("refreshBiometricGateAvailability()"))
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

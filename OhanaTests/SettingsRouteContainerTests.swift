import Foundation
import Testing

struct SettingsRouteContainerTests {
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

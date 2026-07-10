import Foundation
import Testing
@testable import Ohana

struct OnlineFeatureGateTests {
    @Test func launchGateIsClosed() {
        #expect(AppCapabilityProfile.current == .solo)
        #expect(!AppCapabilityProfile.shipsCloudFamilyCapabilities)
        #expect(!AppCapabilityProfile.permitsCloudSyncRuntime)
        #expect(!AppCapabilityProfile.shippingPermitsCloudSyncDirtyWrites)
        #expect(!OnlineFeatureGate.allows(.onlineCollaboration))
    }

    @Test func initialMergeCannotBypassTheSoloDirtyWriteBoundary() throws {
        let source = try source(
            repositoryRootURL().appendingPathComponent(
                "Ohana/Domain/Services/CloudSyncInitialMergeRuntime.swift"
            )
        )
        #expect(source.contains("guard AppCapabilityProfile.permitsCloudSyncDirtyWrites else"))
    }

    @Test func routeGuardBlocksOnlineSurfacesButKeepsWeeklyReport() {
        let launchLevel = 10

        if case .suppress = AppFeatureRouteGuard.functionDestinationDecision(.bountyBoard, currentLevel: launchLevel) {
        } else {
            Issue.record("Expected the bounty board to be hidden while online collaboration is gated")
        }

        #expect(!AppFeatureRouteGuard.allowsSheetRoute(.crewRoster(.collaboration), currentLevel: launchLevel))
        #expect(AppFeatureRouteGuard.allowsSheetRoute(.crewRoster(.members), currentLevel: launchLevel))
        #expect(AppFeatureRouteGuard.isVisibleFunctionDestination(.familyWeeklyReport, currentLevel: launchLevel))
    }

    @Test func blockedShareNoticeHasVisibleLaunchCopy() {
        let reason = OnlineFeatureGateNoticeReason.cloudShareInviteBlocked

        #expect(reason.title(L10n("zh")) == "联机协作即将推出")
        #expect(reason.message(L10n("zh")) == "这个版本不会加入共享家庭，您的本机数据保持不变。")
        #expect(reason.title(L10n("en")) == "Online collaboration is coming soon")
    }

    @Test @MainActor func launchCloudSyncServiceCannotEnableWhileGateIsClosed() {
        let service = LocalDeviceCloudSyncService()
        #expect(!service.isEnabled)
        #expect(!service.hasPendingTransientRetry)
        #expect(service.nextTransientRetryAt == nil)

        service.setEnabled(true)
        #expect(!service.isEnabled)
    }

    @Test @MainActor func onlineCollaborationPresentationFallsBackThroughRoutePolicy() {
        let coordinator = AppRouteCoordinator()

        coordinator.presentRequiredAccountSwitch()
        coordinator.presentCrewRoster(mode: .collaboration)

        #expect(coordinator.sheet == .crewRoster(.members))
        #expect(!AppFeatureRouteGuard.allowsSheetRoute(.crewRoster(.collaboration), currentLevel: 10))
        #expect(AppFeatureRouteGuard.allowsSheetRoute(.crewRoster(.members), currentLevel: 10))
    }

    @Test @MainActor func onlineFunctionMenuDestinationsStaySuppressedThroughRoutePolicy() {
        let coordinator = AppRouteCoordinator()
        let decision = coordinator.functionMenuPresentationDecision(destination: .bountyBoard, currentLevel: 10)

        guard case let .redirected(from, to, reason) = decision else {
            Issue.record("Expected online-only function destination to fall back while the launch gate is closed")
            return
        }
        #expect(from == .functionMenu(destination: .bountyBoard))
        #expect(to == .functionMenu(destination: nil))
        #expect(reason.hasPrefix("onlineGate:"))
    }

    @Test func legacyDayZeroPromiseHasNoLaunchEntryPoint() throws {
        let rootURL = repositoryRootURL()
        let onboardingRoot = rootURL.appendingPathComponent("Ohana/Features/Onboarding")

        let references = try swiftSources(under: onboardingRoot).filter { url in
            guard url.lastPathComponent != "Day0PromiseDataContainer.swift",
                  url.lastPathComponent != "Day0PromiseSheet.swift" else { return false }
            return try source(url).contains("Day0PromiseSheet")
        }

        #expect(references.isEmpty)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try source(rootURL.appendingPathComponent(path))
    }

    private func source(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func swiftSources(under rootURL: URL) throws -> [URL] {
        let enumerator = try #require(FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: nil
        ))
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
    }
}

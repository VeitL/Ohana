import Foundation
import Testing
@testable import Ohana

struct OnlineFeatureGateTests {
    @Test func launchGateIsClosed() {
        #expect(!OnlineFeatureGate.allows(.onlineCollaboration))
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

    @Test func settingsAndShareAcceptanceAreGuardedByOnlineGate() throws {
        let rootURL = repositoryRootURL()
        let settingsView = try source("Ohana/Features/Settings/Views/SettingsView.swift", rootURL: rootURL)
        let settingsCloudSync = try source("Ohana/Features/Settings/Views/SettingsView+CloudSync.swift", rootURL: rootURL)
        let appDelegate = try source("Ohana/App/OhanaCloudSharingAppDelegate.swift", rootURL: rootURL)
        let appServices = try source("Ohana/App/AppServices.swift", rootURL: rootURL)

        let settingsGateIndex = try #require(settingsView.range(of: "if OnlineFeatureGate.allows(.onlineCollaboration)")?.lowerBound)
        let householdSyncIndex = try #require(settingsView.range(of: "householdSyncSection")?.lowerBound)
        #expect(settingsGateIndex < householdSyncIndex)
        #expect(settingsCloudSync.contains("guard canUseOnlineCollaborationForSettings() else { return }"))
        #expect(settingsCloudSync.contains("guard OnlineFeatureGate.allows(.onlineCollaboration) else"))
        let appServicesGateIndex = try #require(appServices.range(of: "guard OnlineFeatureGate.allows(.onlineCollaboration) else")?.lowerBound)
        let noopCloudSyncIndex = try #require(appServices.range(of: "return LocalDeviceCloudSyncService()")?.lowerBound)
        #expect(appServicesGateIndex < noopCloudSyncIndex)

        let gateIndex = try #require(appDelegate.range(of: "guard OnlineFeatureGate.allows(.onlineCollaboration) else")?.lowerBound)
        let acceptIndex = try #require(appDelegate.range(of: "acceptShare(metadata: cloudKitShareMetadata)")?.lowerBound)
        let enableIndex = try #require(appDelegate.range(of: "cloudSync?.setEnabled(true)")?.lowerBound)

        #expect(gateIndex < acceptIndex)
        #expect(gateIndex < enableIndex)
    }

    @Test func homeFamilyTaskSurfacesAreFedOnlyThroughOnlineGate() throws {
        let rootURL = repositoryRootURL()
        let readModel = try source("Ohana/Features/Home/HomeReadModelStore.swift", rootURL: rootURL)
        let homeRoutes = try source("Ohana/Features/Home/HomeRouteCoordinator.swift", rootURL: rootURL)
        let crewRoute = try source("Ohana/Features/CrewRoster/CrewRosterRouteContainer.swift", rootURL: rootURL)

        #expect(readModel.contains("familyTasks: OnlineFeatureGate.allows(.onlineCollaboration) ? fetches.familyTasks() : []"))
        #expect(readModel.contains("let familyTasks = OnlineFeatureGate.allows(.onlineCollaboration) ? fetches.familyTasks() : []"))
        #expect(homeRoutes.contains("!OnlineFeatureGate.allows(.onlineCollaboration)"))
        #expect(crewRoute.contains("if OnlineFeatureGate.allows(.onlineCollaboration)"))
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

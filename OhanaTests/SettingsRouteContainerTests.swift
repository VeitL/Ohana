import Foundation
import Testing
@testable import Ohana

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

    @Test func coconutBalanceDeveloperToolDefersApplyOffTapFrame() throws {
        let coconutSource = try source(
            "Ohana/Features/Economy/Views/SettingsCoconutBalanceTestView.swift",
            rootURL: repositoryRootURL()
        )
        let debugSource = try source(
            "Ohana/Features/Settings/Views/SettingsView+Debug.swift",
            rootURL: repositoryRootURL()
        )
        let frameHandoff = try #require(coconutSource.range(of: "await OhanaFrameScheduler.waitAfterNextFrame()"))
        let command = try #require(
            coconutSource.range(
                of: "SettingsCommandExecutor(context: modelContext, services: appServices).applyCoconutBalanceTest"
            )
        )

        #expect(coconutSource.contains("@State private var isApplying = false"))
        #expect(coconutSource.contains("guard !isApplying else { return }"))
        #expect(coconutSource.contains(".disabled(isApplying)"))
        #expect(frameHandoff.lowerBound < command.lowerBound)
        #expect(!coconutSource.contains("publishesRevision: !isUITestRun"))
        #expect(!coconutSource.contains("updatesProjection: !isUITestRun"))
        #expect(debugSource.contains("-OHANA_UI_TEST_OPEN_COCONUT_BALANCE_SHEET"))
        #expect(debugSource.contains("!SettingsDebugTools.opensCoconutBalanceSheetInUITests"))
    }

    @Test func coconutBalanceRevisionDoesNotReloadSettingsRouteData() throws {
        var coconutRevision = HomeRevision()
        coconutRevision.advance(for: .settingsCoconutBalance(humanID: UUID(), amount: 120))

        var privacyRevision = HomeRevision()
        privacyRevision.advance(for: .command("privacy", "passcode"))

        var activeHumanRevision = HomeRevision()
        activeHumanRevision.advance(for: .settingsActiveHumanSwitch(humanID: UUID()))

        #expect(!SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: coconutRevision))
        #expect(!SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: privacyRevision))
        #expect(SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: activeHumanRevision))
    }

    @Test func settingsDataSectionsReserveSlotsBeforeDeferredRouteDataLoads() throws {
        let settingsSource = try source(
            "Ohana/Features/Settings/Views/SettingsView.swift",
            rootURL: repositoryRootURL()
        )
        let dataIdentitySource = try source(
            "Ohana/Features/Settings/Views/SettingsView+DataIdentity.swift",
            rootURL: repositoryRootURL()
        )
        let routeSource = try source(
            "Ohana/Features/Settings/SettingsRouteContainer.swift",
            rootURL: repositoryRootURL()
        )

        #expect(settingsSource.contains("let isRouteDataLoaded: Bool"))
        #expect(routeSource.contains("isRouteDataLoaded: data.hasLoaded"))
        #expect(dataIdentitySource.contains("""
        if !isRouteDataLoaded {
            deviceIdentityPlaceholderSection
            petManagementPlaceholderSection
        } else {
"""))
    }

    @Test func settingsLanguageSwitchDefersGlobalLocaleCommitOffTapFrame() throws {
        let settingsSource = try source(
            "Ohana/Features/Settings/Views/SettingsView.swift",
            rootURL: repositoryRootURL()
        )
        let mainSource = try source(
            "Ohana/Features/Settings/Views/SettingsView+MainSections.swift",
            rootURL: repositoryRootURL()
        )
        let regionalSource = try source(
            "Ohana/Features/Settings/Views/SettingsView+RegionalDefaults.swift",
            rootURL: repositoryRootURL()
        )

        #expect(settingsSource.contains("@State var languageSelectionCode = AppLanguage.code"))
        #expect(settingsSource.contains("@State var languageCommitTask: Task<Void, Never>?"))
        #expect(mainSource.contains("Picker(\"\", selection: $languageSelectionCode)"))
        #expect(!mainSource.contains("Picker(\"\", selection: $appLanguage)"))
        #expect(mainSource.contains("scheduleLanguageCommit(newValue)"))
        #expect(regionalSource.contains("languageCommitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 96)"))
        #expect(regionalSource.contains("transaction.disablesAnimations = true"))
        #expect(regionalSource.contains("commitLanguageChange(AppLanguage.code, emitFeedback: false)"))
        #expect(!regionalSource.contains("AppCountry.applyDefaults(for: country.code)"))
    }

    @Test func notificationSettingsKeepCategoryControlsBehindAdvancedDisclosure() throws {
        let settingsSource = try source(
            "Ohana/Features/Settings/Views/SettingsView.swift",
            rootURL: repositoryRootURL()
        )
        let mainSource = try source(
            "Ohana/Features/Settings/Views/SettingsView+MainSections.swift",
            rootURL: repositoryRootURL()
        )
        let chromeSource = try source(
            "Ohana/Features/Settings/Views/SettingsView+Chrome.swift",
            rootURL: repositoryRootURL()
        )

        #expect(settingsSource.contains("@State var showAdvancedNotificationSettings = false"))
        #expect(mainSource.contains("routineNotificationsToggleRow"))
        #expect(mainSource.contains("advancedNotificationSettingsDisclosure"))
        #expect(!chromeSource.contains("DisclosureGroup(isExpanded: $showAdvancedNotificationSettings)"))
        #expect(chromeSource.contains("if showAdvancedNotificationSettings"))
        #expect(chromeSource.contains("advancedNotificationSettingsRows"))
        #expect(chromeSource.contains("title: l.tr(zh: \"日历事项提醒\""))
        #expect(chromeSource.contains("group: .calendar"))
        #expect(chromeSource.contains("\"settings-notification-\\(group.rawValue)-toggle\""))
        #expect(chromeSource.contains("notificationPreferenceGroups.forEach"))
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

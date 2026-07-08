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

    @Test func settingsMainRouteUsesValueSnapshotsForMemberData() throws {
        let settingsSource = try source(
            "Ohana/Features/Settings/Views/SettingsView.swift",
            rootURL: repositoryRootURL()
        )
        let routeSource = try source(
            "Ohana/Features/Settings/SettingsRouteContainer.swift",
            rootURL: repositoryRootURL()
        )
        let snapshotSource = try source(
            "Ohana/Features/Settings/SettingsRouteSnapshots.swift",
            rootURL: repositoryRootURL()
        )
        let dataIdentitySource = try source(
            "Ohana/Features/Settings/Views/SettingsView+DataIdentity.swift",
            rootURL: repositoryRootURL()
        )
        let avatarSource = try source(
            "Ohana/Features/Settings/Views/SettingsHumanIdentityAvatar.swift",
            rootURL: repositoryRootURL()
        )
        let petManagementSource = try source(
            "Ohana/Features/Settings/Views/SettingsPetManagementSheet.swift",
            rootURL: repositoryRootURL()
        )
        let quickSwitchSource = try source(
            "Ohana/Features/Settings/Views/HumanQuickSwitchPasscodeSheet.swift",
            rootURL: repositoryRootURL()
        )

        #expect(snapshotSource.contains("struct SettingsHumanSnapshot: Identifiable, Equatable, Sendable"))
        #expect(snapshotSource.contains("hasPasscode: HumanPasscodeService.hasPasscode(human)"))
        #expect(snapshotSource.contains("struct SettingsPetSnapshot: Identifiable, Equatable, Sendable"))
        #expect(snapshotSource.contains("struct SettingsHouseholdSnapshot: Identifiable, Equatable, Sendable"))
        #expect(settingsSource.contains("let homeHumans: [SettingsHumanSnapshot]?"))
        #expect(settingsSource.contains("let homePets: [SettingsPetSnapshot]?"))
        #expect(settingsSource.contains("let homeHouseholds: [SettingsHouseholdSnapshot]?"))
        #expect(!settingsSource.contains("let homeHumans: [Human]?"))
        #expect(!settingsSource.contains("let homePets: [Pet]?"))
        #expect(!settingsSource.contains("let homeHouseholds: [Household]?"))
        #expect(!settingsSource.contains("homeElectronicPets"))
        #expect(routeSource.contains("var humans: [SettingsHumanSnapshot]?"))
        #expect(routeSource.contains("var pets: [SettingsPetSnapshot]?"))
        #expect(routeSource.contains("var households: [SettingsHouseholdSnapshot]?"))
        #expect(routeSource.contains(".map(SettingsHumanSnapshot.init)"))
        #expect(routeSource.contains(".map(SettingsPetSnapshot.init)"))
        #expect(routeSource.contains(".map(SettingsHouseholdSnapshot.init)"))
        #expect(!routeSource.contains("var humans: [Human]?"))
        #expect(!routeSource.contains("var pets: [Pet]?"))
        #expect(!routeSource.contains("var households: [Household]?"))
        #expect(avatarSource.contains("let human: SettingsHumanSnapshot"))
        #expect(!avatarSource.contains("HumanAvatarPipelineView"))
        #expect(dataIdentitySource.contains("func fetchSettingsHuman(id: UUID) -> Human?"))
        #expect(dataIdentitySource.contains("func fetchSettingsPets() -> [Pet]"))
        #expect(!dataIdentitySource.contains("appServices.passcodes.hasPasscode(human)"))
        #expect(petManagementSource.contains("let pets: [SettingsPetSnapshot]"))
        #expect(petManagementSource.contains("fetchPet(id: pet.id)"))
        #expect(!petManagementSource.contains("let pets: [Pet]"))
        #expect(quickSwitchSource.contains("let human: SettingsHumanSnapshot"))
        #expect(quickSwitchSource.contains("fetchHumanForVerification()"))
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
        let appSource = try source(
            "Ohana/App/OhanaApp.swift",
            rootURL: repositoryRootURL()
        )
        let contentSource = try source(
            "Ohana/App/ContentView.swift",
            rootURL: repositoryRootURL()
        )
        let rootSource = try source(
            "Ohana/App/RootView.swift",
            rootURL: repositoryRootURL()
        )
        let routeHostSource = try source(
            "Ohana/App/RouteContainers/AppRouteDestinationContainers.swift",
            rootURL: repositoryRootURL()
        )
        let localizationSource = try source(
            "Ohana/Shared/LocalizationSettings.swift",
            rootURL: repositoryRootURL()
        )

        #expect(settingsSource.contains("@State var languageSelectionCode = AppLanguage.code"))
        #expect(settingsSource.contains("@State var languageCommitTask: Task<Void, Never>?"))
        #expect(settingsSource.contains("@State var isLanguageCommitInFlight = false"))
        #expect(mainSource.contains("Picker(\"\", selection: $languageSelectionCode)"))
        #expect(!mainSource.contains("Picker(\"\", selection: $appLanguage)"))
        #expect(mainSource.contains("scheduleLanguageCommit(newValue)"))
        #expect(mainSource.contains(".disabled(isLanguageCommitInFlight)"))
        #expect(mainSource.contains("if isLanguageCommitInFlight"))
        #expect(mainSource.contains("settingsLanguageCommitPlaceholderSection"))
        #expect(mainSource.contains("\"settings-language-commit-placeholder\""))
        #expect(mainSource.contains("var settingsDeferredHeavySections: some View"))
        #expect(mainSource.contains("if !isLanguageCommitInFlight"))
        #expect(mainSource.contains("settingsDebugSection"))
        #expect(mainSource.contains("householdSyncSection"))
        #expect(regionalSource.contains("func scheduleLanguageCommit(_ rawLanguageCode: String, emitFeedback: Bool = true)"))
        #expect(regionalSource.contains("scheduleLanguageCommit(normalizedLanguage, emitFeedback: false)"))
        #expect(regionalSource.contains("scheduleLanguageCommit(languageSelectionCode, emitFeedback: false)"))
        #expect(regionalSource.contains("prepareForLanguageCommit()"))
        #expect(regionalSource.contains("areDataSectionsMounted = false"))
        #expect(regionalSource.contains("isLanguageCommitInFlight = true"))
        #expect(regionalSource.contains("isLanguageCommitInFlight = false"))
        #expect(regionalSource.contains("languageCommitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 96)"))
        #expect(regionalSource.contains("scheduleDataSectionsMount(delayMilliseconds: 320, animated: false)"))
        #expect(regionalSource.contains("func scheduleDataSectionsMount(delayMilliseconds: UInt64 = 260, animated: Bool = true)"))
        #expect(regionalSource.contains("transaction.disablesAnimations = true"))
        #expect(!regionalSource.contains("commitLanguageChange(AppLanguage.code, emitFeedback: false)"))
        #expect(!regionalSource.contains("AppCountry.applyDefaults(for: country.code)"))
        #expect(appSource.contains("@AppStorage(\"appLanguage\") private var appLanguage: String = AppLanguage.detectedCode"))
        #expect(appSource.contains("appLanguage: appLanguage"))
        #expect(!appSource.contains(".environment(\\.locale, AppLanguage.swiftUIPreferredLocale(for: appLanguage))"))
        #expect(!appSource.contains(".environment(\\.ohanaAppLanguageCode, appLanguage)"))
        #expect(!contentSource.contains("@AppStorage(\"appLanguage\") private var appLanguage"))
        #expect(contentSource.contains("var routeLanguageCode: String = AppLanguage.code"))
        #expect(contentSource.contains(".homeSurfaceLanguage(homeSurfaceLanguage)"))
        #expect(contentSource.contains("@State private var routeSurfaceLanguage = AppLanguage.code"))
        #expect(contentSource.contains("@State private var routeSurfaceLanguageThawTask: Task<Void, Never>?"))
        #expect(contentSource.contains("synchronizeRouteSurfaceLanguageIfAllowed(routeLanguageCode)"))
        #expect(contentSource.contains("thawRouteSurfaceLanguageAfterSheetDismissal()"))
        #expect(contentSource.contains("routeLanguageCode: routeSurfaceLanguage"))
        #expect(!rootSource.contains("@AppStorage(\"appLanguage\") private var appLanguage"))
        #expect(rootSource.contains("var appLanguage: String = AppLanguage.code"))
        #expect(rootSource.contains("routeLanguageCode: appLanguage"))
        #expect(routeHostSource.contains("let routeLanguageCode: String"))
        #expect(routeHostSource.contains(".ohanaLocalizedEnvironment(routeLanguageCode)"))
        #expect(localizationSource.contains("func ohanaLocalizedEnvironment(_ rawLanguage: String) -> some View"))
    }

    @Test func settingsLanguageSwitchDefersHomeReadModelRefresh() throws {
        let homeDataSource = try source(
            "Ohana/Features/Home/VerticalSolidHomeDataContainer.swift",
            rootURL: repositoryRootURL()
        )
        let rootSource = try source(
            "Ohana/App/RootView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(homeDataSource.contains("postLanguageRefreshDelayMilliseconds"))
        #expect(homeDataSource.contains("@State private var readModelLanguage = AppLanguage.code"))
        #expect(homeDataSource.contains("scheduleReadModelLanguageSync(newValue)"))
        #expect(homeDataSource.contains("language: readModelLanguage"))
        #expect(!homeDataSource.contains("language: appLanguage"))
        #expect(!rootSource.contains("@AppStorage(\"appLanguage\") private var appLanguage"))
        #expect(rootSource.contains("var appLanguage: String = AppLanguage.code"))
        #expect(rootSource.contains("routeLanguageCode: appLanguage"))
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

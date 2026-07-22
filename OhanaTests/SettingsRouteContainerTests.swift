import Foundation
import SwiftData
import Testing
@testable import Ohana

@MainActor
struct SettingsRouteContainerTests {
    @Test func settingsExposeSixValueRoutedCategories() throws {
        let root = try source("Ohana/Features/Settings/Views/SettingsView.swift")
        let sections = try source("Ohana/Features/Settings/Views/SettingsView+MainSections.swift")
        let destinations = try source("Ohana/Features/Settings/Views/SettingsDestinationPages.swift")

        #expect(root.contains(".navigationDestination(for: SettingsDestination.self)"))
        #expect(sections.contains("NavigationLink(value: destination)"))
        #expect(destinations.contains("enum SettingsDestination: String, CaseIterable, Hashable"))
        #expect(SettingsDestination.allCases == [
            .regionAndLanguage,
            .appearanceAndPerformance,
            .notifications,
            .privacyAndSecurity,
            .dataAndBackup,
            .about
        ])
    }

    @Test func lightweightRootDoesNotMountDestinationSections() throws {
        let sections = try source("Ohana/Features/Settings/Views/SettingsView+MainSections.swift")

        #expect(sections.contains("settingsDataSections"))
        #expect(sections.contains("settingsExperienceSection"))
        #expect(sections.contains("settingsPersonalSection"))
        #expect(sections.contains("settingsCategorySection"))
        #expect(!sections.contains("settingsPreferencesSection"))
        #expect(!sections.contains("AnyView(settingsDataSections)"))
        #expect(!sections.contains("AnyView(backupSection)"))
    }

    @Test func experienceModeIsTheFirstSettingsSectionAndUsesTwoLargeChoices() throws {
        let sections = try source("Ohana/Features/Settings/Views/SettingsView+MainSections.swift")
        let bodyStart = try #require(sections.range(of: "var settingsBodySections"))
        let experience = try #require(sections.range(of: "settingsExperienceSection", range: bodyStart.upperBound ..< sections.endIndex))
        let data = try #require(sections.range(of: "settingsDataSections", range: bodyStart.upperBound ..< sections.endIndex))

        #expect(experience.lowerBound < data.lowerBound)
        #expect(sections.contains("SettingsExperienceModeSelector("))
        #expect(sections.contains("HStack(alignment: .top, spacing: 10) { modeButtons }"))
        #expect(sections.contains("settings-experience-mode-\\(mode.rawValue)"))
        #expect(sections.contains("dynamicTypeSize.isAccessibilitySize"))
        #expect(!sections.contains("settings-experience-mode-picker"))
        #expect(sections.contains("settings-zen-owner-picker"))
    }

    @Test func debugSettingsExposeAdaptivePrimaryAccentLab() throws {
        let debug = try source("Ohana/Features/Settings/Views/SettingsView+Debug.swift")
        let lab = try source("Ohana/Features/Settings/DesignLab/PrimaryAccentLabView.swift")
        let palette = try source("Ohana/Shared/Design/OhanaPrimaryAccent.swift")

        #expect(debug.contains("PrimaryAccentLabView()"))
        #expect(debug.contains("settings-debug-primary-accent"))
        #expect(lab.contains("primary-accent-appearance-picker"))
        #expect(lab.contains("primary-accent-live-preview"))
        #expect(lab.contains("primary-accent-\\(appearance.rawValue)-preview"))
        #expect(lab.contains("ColorPicker(selection: customColor, supportsOpacity: false)"))
        #expect(lab.contains("primary-accent-system-color-picker"))
        #expect(lab.contains("@AppStorage(OhanaPrimaryAccentPreferences.lightStorageKey)"))
        #expect(lab.contains("@AppStorage(OhanaPrimaryAccentPreferences.darkStorageKey)"))
        #expect(palette.contains("#if DEBUG"))
        #expect(palette.contains("return false"))
    }

    @Test func settingsAboutUsesStaticVersionAndPublicDestinations() throws {
        let about = try source("Ohana/Features/Settings/Views/SettingsDestinationPages.swift")
        let links = try source("Ohana/App/OhanaPublicLinks.swift")

        #expect(about.contains("OhanaReleaseIdentity.currentVersionDisplay"))
        #expect(about.contains("settings-version-value"))
        #expect(!about.contains("subtitle: OhanaReleaseIdentity.currentVersionDisplay"))
        #expect(about.contains("settings-privacy-policy-action"))
        #expect(about.contains("settings-support-action"))
        #expect(about.contains("OhanaPublicLinks.appStoreReview"))
        #expect(links.contains("https://github.com/VeitL/Ohana/blob/main/docs/privacy-policy.md"))
        #expect(links.contains("mailto:guanchen.li.119@gmail.com"))
    }

    @Test func releaseIdentityUsesBundleVersionAndBuildWithoutHardcodedMarketingCopy() {
        #expect(OhanaReleaseIdentity.versionDisplay(infoDictionary: [
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "7"
        ]) == "v1.0 (7)")
        #expect(OhanaReleaseIdentity.versionDisplay(infoDictionary: [
            "CFBundleShortVersionString": "1.0"
        ]) == "v1.0")
        #expect(OhanaReleaseIdentity.versionDisplay(infoDictionary: [:]) == "—")
    }

    @Test func releaseSettingsExcludeVisualExperimentFromPublicPages() throws {
        let root = try source("Ohana/Features/Settings/Views/SettingsView.swift")
        let sections = try source("Ohana/Features/Settings/Views/SettingsView+MainSections.swift")
        let destinations = try source("Ohana/Features/Settings/Views/SettingsDestinationPages.swift")
        let diagnostics = try source("Ohana/Features/Settings/Views/SettingsPerformanceDiagnosticsView.swift")
        let debug = try source("Ohana/Features/Settings/Views/SettingsView+Debug.swift")

        #expect(!root.contains("reducedVisualEffectsMode"))
        #expect(!sections.contains("轻量视觉 A/B"))
        #expect(!destinations.contains("轻量视觉 A/B"))
        #expect(diagnostics.contains("轻量视觉 A/B"))
        #expect(debug.contains("#if DEBUG"))
        #expect(debug.contains("PerformanceDiagnosticsView()"))
    }

    @Test func notificationCategoriesUseNativeLazyDisclosure() throws {
        let notifications = try source("Ohana/Features/Settings/Views/SettingsNotificationsPage.swift")

        #expect(notifications.contains("@State private var showAdvancedNotificationSettings = false"))
        #expect(notifications.contains("DisclosureGroup(isExpanded: $showAdvancedNotificationSettings)"))
        #expect(notifications.contains("SettingsPlantReminderDataContainer()"))
        #expect(notifications.contains("title: l.tr(zh: \"日历事项提醒\""))
        #expect(notifications.contains("group: .calendar"))
        #expect(notifications.contains("settings-notification-\\(group.rawValue)-toggle"))
        #expect(notifications.contains("preferenceGroups.forEach"))
    }

    @Test func pageStateIsOwnedByDestinationViews() throws {
        let root = try source("Ohana/Features/Settings/Views/SettingsView.swift")
        let destinations = try source("Ohana/Features/Settings/Views/SettingsDestinationPages.swift")
        let notifications = try source("Ohana/Features/Settings/Views/SettingsNotificationsPage.swift")
        let backup = try source("Ohana/Features/Settings/Views/SettingsView+Backup.swift")

        #expect(!root.contains("showAdvancedNotificationSettings"))
        #expect(!root.contains("backupPassword"))
        #expect(destinations.contains("struct SettingsRegionLanguagePage: View"))
        #expect(destinations.contains("struct SettingsAppearancePerformancePage: View"))
        #expect(destinations.contains("struct SettingsPrivacySecurityPage: View"))
        #expect(notifications.contains("struct SettingsNotificationsPage: View"))
        #expect(backup.contains("struct SettingsBackupPage: View"))
    }

    @Test func languageCommitDefersOffTapFrameAndSurvivesImmediateClose() throws {
        let destinations = try source("Ohana/Features/Settings/Views/SettingsDestinationPages.swift")

        #expect(destinations.contains("Picker(\"\", selection: $languageSelectionCode)"))
        #expect(destinations.contains("languageCommitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 96)"))
        #expect(destinations.contains(".onDisappear { commitPendingLanguageChangeBeforeDismissal() }"))
        #expect(destinations.contains("let normalized = AppLanguage.normalize(languageSelectionCode)"))
        #expect(destinations.contains("transaction.disablesAnimations = true"))
    }

    @Test func routeStartsWithRootAndLoadsActorAfterFirstFrame() throws {
        let route = try source("Ohana/Features/Settings/SettingsRouteContainer.swift")

        #expect(route.contains("SettingsView("))
        #expect(route.contains("await OhanaFrameScheduler.waitAfterNextFrame()"))
        #expect(route.contains("SettingsOpenPerformance.mark(AppPerformancePhases.firstFrame)"))
        #expect(route.contains("SettingsRouteDataActor(modelContainer: container).load()"))
        #expect(route.contains("SettingsOpenPerformance.mark(AppPerformancePhases.dataReady)"))
        #expect(!route.contains("SettingsFirstFrameShell"))
        #expect(!route.contains("loadDelayMilliseconds: 160"))
        #expect(!route.contains("reloadDelayMilliseconds: 120"))
    }

    @Test func routeRefreshCancelsAndCoalescesWorkWhileKeepingRetry() throws {
        let route = try source("Ohana/Features/Settings/SettingsRouteContainer.swift")
        let data = try source("Ohana/Features/Settings/Views/SettingsView+DataIdentity.swift")

        #expect(route.contains("routeDataLoadTask?.cancel()"))
        #expect(route.contains("revisionReloadTask?.cancel()"))
        #expect(route.contains("await Task.yield()"))
        #expect(route.contains("routeLoadErrorMessage = error.localizedDescription"))
        #expect(data.contains("settings-route-data-retry"))
        #expect(data.contains("Other settings remain available"))
    }

    @Test func modelActorBuildsSendableMemberPetAndHouseholdSnapshots() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let household = Household(name: "Home")
        let pet = Pet(name: "Mochi", species: "cat")
        let human = Human(name: "Owner")
        context.insert(household)
        context.insert(pet)
        context.insert(human)
        try context.save()

        let data = try await SettingsRouteDataActor(modelContainer: container).load()

        #expect(data.hasLoaded)
        #expect(data.households?.map(\.name) == ["Home"])
        #expect(data.pets?.map(\.name) == ["Mochi"])
        #expect(data.humans?.map(\.name) == ["Owner"])
    }

    @Test func modelActorHonorsCancellation() async throws {
        let actor = SettingsRouteDataActor(modelContainer: try makeContainer())
        let task = Task {
            try Task.checkCancellation()
            return try await actor.load()
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    @Test func failedRefreshPreservesLastGoodSnapshots() {
        let existing = SettingsRouteData(
            households: [SettingsHouseholdSnapshot(id: UUID(), name: "Home", ckShareRecordName: "")],
            pets: [SettingsPetSnapshot(id: UUID(), name: "Mochi", avatarEmoji: "🐈", canWriteWallet: true)],
            humans: [],
            hasLoaded: true
        )

        let retained = SettingsRouteDataFailurePolicy.preservingLastGoodData(existing)

        #expect(retained == existing)
        #expect(retained.hasLoaded)
    }

    @Test func coconutAndPrivacyRevisionsDoNotReloadSettingsSnapshots() {
        var coconutRevision = HomeRevision()
        coconutRevision.advance(for: .settingsCoconutBalance(humanID: UUID(), amount: 120))
        var privacyRevision = HomeRevision()
        privacyRevision.advance(for: .command("privacy", "passcode"))
        var activeHumanRevision = HomeRevision()
        activeHumanRevision.advance(for: .settingsActiveHumanSwitch(humanID: UUID()))

        #expect(!SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: coconutRevision))
        #expect(!SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: privacyRevision))
        #expect(!SettingsRouteReloadPolicy.shouldReloadSettingsRouteData(for: activeHumanRevision))
    }

    @Test func coconutBalanceDeveloperToolDefersApplyOffTapFrame() throws {
        let coconut = try source("Ohana/Features/Economy/Views/SettingsCoconutBalanceTestView.swift")
        let debug = try source("Ohana/Features/Settings/Views/SettingsView+Debug.swift")
        let handoff = try #require(coconut.range(of: "await OhanaFrameScheduler.waitAfterNextFrame()"))
        let command = try #require(coconut.range(of: "SettingsCommandExecutor(context: modelContext, services: appServices).applyCoconutBalanceTest"))

        #expect(handoff.lowerBound < command.lowerBound)
        #expect(coconut.contains("guard !isApplying else { return }"))
        #expect(coconut.contains(".disabled(isApplying)"))
        #expect(debug.contains("-OHANA_UI_TEST_OPEN_COCONUT_BALANCE_SHEET"))
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(ArkSchemaV94.models),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
        )
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repositoryRootURL().appendingPathComponent(path), encoding: .utf8)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

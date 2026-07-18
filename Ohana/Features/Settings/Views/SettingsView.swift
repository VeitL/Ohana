//
//  SettingsView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var onClose: (() -> Void)?
    let homeHouseholds: [SettingsHouseholdSnapshot]?
    let homePets: [SettingsPetSnapshot]?
    let homeHumans: [SettingsHumanSnapshot]?
    let isRouteDataLoaded: Bool
    let routeLoadErrorMessage: String?
    let onRetryRouteData: (() -> Void)?
    let experienceMode: AppExperienceMode
    let zenOwnerHumanID: String
    let onRequestExperienceModeChange: ((AppExperienceMode) -> Void)?
    let onRequestZenOwnerChange: ((UUID) -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage("appThemePreference") var appThemePreference: String = "dark"
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage(CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey) var hasCloudSyncSharedZoneAccessRevokedNotice = false
    @AppStorage(CloudSyncEngineRuntime.retryAttemptDefaultsKey) var cloudSyncRetryAttempt = 0
    @AppStorage(CloudSyncEngineRuntime.nextRetryAtDefaultsKey) var cloudSyncNextRetryAtReferenceDate: Double = 0
    @State var showingPersonalPlan = false
    @State var showingPetManagement = false
    @State var quickSwitchHuman: SettingsHumanSnapshot? = nil
    @State var householdSharePresentation: CloudSyncHouseholdSharePresentation? = nil
    @State var isPreparingHouseholdShare = false
    @State var isBindingCloudIdentity = false
    @State var isRetryingCloudSyncNow = false
    @State var householdSyncStatusMessage: String? = nil
    @State var householdSyncErrorMessage: String? = nil
    @State var showingCoconutBalanceTest = false
    @State var showingReminderObservability = false
    @State var showingUISpecShowcase = false
    @State var showingFamilyWeeklyReportDebug = false

    init(
        homeHouseholds: [SettingsHouseholdSnapshot]? = nil,
        homePets: [SettingsPetSnapshot]? = nil,
        homeHumans: [SettingsHumanSnapshot]? = nil,
        isRouteDataLoaded: Bool = true,
        routeLoadErrorMessage: String? = nil,
        onRetryRouteData: (() -> Void)? = nil,
        experienceMode: AppExperienceMode = .standard,
        zenOwnerHumanID: String = "",
        onRequestExperienceModeChange: ((AppExperienceMode) -> Void)? = nil,
        onRequestZenOwnerChange: ((UUID) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.homeHouseholds = homeHouseholds
        self.homePets = homePets
        self.homeHumans = homeHumans
        self.isRouteDataLoaded = isRouteDataLoaded
        self.routeLoadErrorMessage = routeLoadErrorMessage
        self.onRetryRouteData = onRetryRouteData
        self.experienceMode = experienceMode
        self.zenOwnerHumanID = zenOwnerHumanID
        self.onRequestExperienceModeChange = onRequestExperienceModeChange
        self.onRequestZenOwnerChange = onRequestZenOwnerChange
        self.onClose = onClose
    }

    var preferredScheme: ColorScheme? {
        switch appThemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    var primaryText: Color {
        Color.ohanaPrimaryText
    }

    var secondaryText: Color {
        Color.ohanaSecondaryText
    }

    var tertiaryText: Color {
        Color.ohanaTertiaryText
    }

    var dividerLine: Color {
        Color.ohanaDivider
    }

    var accentColor: Color { Color.goPrimary }
    var l: L10n { L10n(appLanguage) }
    var body: some View {
        settingsSharingPresentationContent
    }

    private var settingsRootContent: some View {
        NavigationStack {
            Form {
                settingsBodySections
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(OhanaStaticAppBackground())
            .accessibilityIdentifier("settings-main-scroll")
            .navigationTitle(l.tr(zh: "设置", en: "Settings", de: "Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                settingsToolbarContent
            }
            .navigationDestination(for: SettingsDestination.self) { destination in
                settingsDestinationContent(destination)
            }
        }
        .preferredColorScheme(preferredScheme)
        .accessibilityIdentifier("settings-screen")
    }

    private func settingsDestinationContent(_ destination: SettingsDestination) -> AnyView {
        switch destination {
        case .regionAndLanguage:
            AnyView(SettingsRegionLanguagePage(
                appLanguage: appLanguage,
                onCommitLanguage: { appLanguage = $0 },
                onClose: closeSettings
            ))
        case .appearanceAndPerformance:
            AnyView(SettingsAppearancePerformancePage(onClose: closeSettings))
        case .notifications:
            AnyView(SettingsNotificationsPage(experienceMode: experienceMode, onClose: closeSettings))
        case .privacyAndSecurity:
            AnyView(SettingsPrivacySecurityPage(onClose: closeSettings))
        case .dataAndBackup:
            AnyView(SettingsBackupPage(onClose: closeSettings))
        case .about:
            AnyView(SettingsAboutPage(onClose: closeSettings))
        }
    }

    /// Settings owns many independent presentations. A single modifier chain
    /// previously made Release builds recursively instantiate the complete
    /// generic view type when this route opened, exhausting the physical
    /// device's main-thread stack. Each `AnyView` below is an intentional,
    /// low-frequency route boundary that caps metadata depth without changing
    /// the individual controls or their state ownership.
    private var settingsAlertContent: AnyView {
        AnyView(settingsRootContent)
    }

    private var settingsLifecycleContent: AnyView {
        AnyView(
            settingsAlertContent
        .onAppear {
            reconcileCurrentActiveHumanSelection()
        }
        .onChange(of: isRouteDataLoaded) { _, hasLoaded in
            guard hasLoaded else { return }
            reconcileCurrentActiveHumanSelection()
        }
        .onChange(of: homeHumans) { _, _ in
            reconcileCurrentActiveHumanSelection()
        }
        )
    }

    private var settingsPrimaryPresentationContent: AnyView {
        AnyView(
            settingsLifecycleContent
        .sheet(isPresented: $showingPersonalPlan) {
            PersonalPlanView()
                .ohanaSheetPagePresentation()
        }
        .sheet(isPresented: $showingPetManagement) {
            SettingsPetManagementSheet(pets: homePets ?? [])
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        )
    }

    private var settingsDeveloperPresentationContent: AnyView {
        AnyView(
            settingsPrimaryPresentationContent
        .sheet(isPresented: $showingCoconutBalanceTest) {
            NavigationStack {
                CoconutBalanceTestView()
            }
            .ohanaSheetPagePresentation() // ui-v4: allow developer balance console as long sheet
        }
        .sheet(isPresented: $showingReminderObservability) {
            NavigationStack {
                ReminderObservabilityView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showingReminderObservability = false
                            } label: {
                                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding label
                            }
                            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                            .accessibilityIdentifier("reminder-observability-close-action")
                        }
                    }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow developer reminder observability console as long sheet
        }
        )
    }

    private var settingsUISpecPresentationContent: AnyView {
        #if DEBUG
            AnyView(
                settingsDeveloperPresentationContent
                .sheet(isPresented: $showingUISpecShowcase) {
                NavigationStack {
                    OhanaUISpecShowcaseView()
                }
                .ohanaSheetPagePresentation() // ui-v4: allow developer UI specification console as long sheet
            }
            )
        #else
            settingsDeveloperPresentationContent
        #endif
    }

    private var settingsReportingPresentationContent: AnyView {
        AnyView(
            settingsUISpecPresentationContent
        .sheet(isPresented: $showingFamilyWeeklyReportDebug) {
            NavigationStack {
                FamilyWeeklyReportDashboardView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showingFamilyWeeklyReportDebug = false
                            } label: {
                                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding label
                            }
                            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                            .accessibilityIdentifier("family-weekly-report-debug-close-action")
                        }
                    }
            }
            .ohanaSheetPagePresentation() // ui-v4: allow developer weekly report console as long sheet
        }
        )
    }

    private var settingsSharingPresentationContent: AnyView {
        AnyView(
            settingsReportingPresentationContent
        .sheet(item: $quickSwitchHuman) { human in
            HumanQuickSwitchPasscodeSheet(human: human) {
                switchActiveHuman(to: human, emitSuccessFeedback: false)
                quickSwitchHuman = nil
            }
            .ohanaCompactSheetPresentation(detents: [.height(500)])
        }
        .sheet(item: $householdSharePresentation) { presentation in
            CloudSyncHouseholdSharingController(
                presentation: presentation,
                onSaved: { share in handleHouseholdShareSaved(share) },
                onStoppedSharing: { handleHouseholdShareStopped(presentation) },
                onError: { error in householdSyncErrorMessage = error.localizedDescription }
            )
            .ignoresSafeArea()
        }
        .alert(l.tr(zh: "家庭同步失败", en: "Family Sync Failed", de: "Familiensynchronisierung fehlgeschlagen"), isPresented: Binding(
            get: { householdSyncErrorMessage != nil },
            set: { if !$0 { householdSyncErrorMessage = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {
                householdSyncErrorMessage = nil
            }
        } message: {
            Text(householdSyncErrorMessage ?? l.tr(zh: "未知错误", en: "Unknown error", de: "Unbekannter Fehler"))
        }
        )
    }
}

#Preview {
    SettingsView()
}

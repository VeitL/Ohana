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
    let homeHouseholds: [Household]?
    let homePets: [Pet]?
    let homeHumans: [Human]?
    let homeElectronicPets: [OasisElectronicPet]?

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Environment(AppServices.self) var appServices
    @Environment(\.ohanaInlinePageSafeAreaInsets) var inlinePageSafeAreaInsets
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @AppStorage("appLanguage") var appLanguage = "zh"
    @AppStorage(AppCountry.storageKey) var appCountry = AppCountry.detectedCode
    @AppStorage(AppMeasurementSystem.storageKey) var appMeasurementSystem = AppMeasurementSystem.fallbackCode
    @AppStorage(AppCurrency.storageKey) var appCurrency = AppCurrency.fallbackCode
    @AppStorage("appThemePreference") var appThemePreference: String = "dark"
    @AppStorage("appBackgroundStyle") var appBackgroundStyle: String = AppBackgroundStyle.goIsland.rawValue
    @AppStorage(AppPerformanceMode.powerSavingKey) var powerSavingMode = false
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    @AppStorage(MemberGateBiometricAuthStore.enabledKey) var enableMemberGateBiometrics = MemberGateBiometricAuthStore.defaultEnabled
    @AppStorage(MedicationNotificationPrivacyStore.hidePetDetailsKey) var hidePetMedicationNotificationDetails = false
    @AppStorage("ohana_has_onboarded") var hasOnboarded = false
    @AppStorage("currentActiveHumanId") var currentActiveHumanId = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenHomePetIDsRaw = ""
    @AppStorage("goFocusHomeCardOrder.v1") var homeCardOrderRaw = ""
    @AppStorage(CloudSyncEngineRuntime.sharedZoneAccessRevokedDefaultsKey) var hasCloudSyncSharedZoneAccessRevokedNotice = false
    @AppStorage(CloudSyncEngineRuntime.retryAttemptDefaultsKey) var cloudSyncRetryAttempt = 0
    @AppStorage(CloudSyncEngineRuntime.nextRetryAtDefaultsKey) var cloudSyncNextRetryAtReferenceDate: Double = 0
    @State var showingAppResetAlert = false
    @State var appResetErrorMessage: String? = nil
    // TASK 1：JSON 备份
    @State var exportedJSONURL: URL? = nil
    @State var isExporting = false
    @State var isImporting = false
    @State var automaticBackupStatus = AutomaticBackupStatusStore().snapshot()
    @State var isRunningAutomaticBackup = false
    @State var backupEncryptionEnabled = false
    @State var backupPassword = ""
    @State var backupPasswordConfirmation = ""
    @State var showingImportPicker = false
    @State var importError: String? = nil
    @State var showingImportSuccess = false
    @State var showingImportErrorAlert = false
    @State var showingOnboardingReplay = false
    @State var showingAccountSwitcher = false
    @State var showingBackgroundPicker = false
    @State var showingPetManagement = false
    @State var quickSwitchHuman: Human? = nil
    @State var householdSharePresentation: CloudSyncHouseholdSharePresentation? = nil
    @State var isPreparingHouseholdShare = false
    @State var isBindingCloudIdentity = false
    @State var isRetryingCloudSyncNow = false
    @State var householdSyncStatusMessage: String? = nil
    @State var householdSyncErrorMessage: String? = nil
    @State var areDataSectionsMounted = false
    @State var dataSectionsMountTask: Task<Void, Never>?
    @State var biometricGateAvailability = MemberGateBiometricAvailability.unavailable
    @State var showingCoconutBalanceTest = false

    init(
        homeHouseholds: [Household]? = nil,
        homePets: [Pet]? = nil,
        homeHumans: [Human]? = nil,
        homeElectronicPets: [OasisElectronicPet]? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.homeHouseholds = homeHouseholds
        self.homePets = homePets
        self.homeHumans = homeHumans
        self.homeElectronicPets = homeElectronicPets
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
    var selectedCountry: AppCountry.Option {
        AppCountry.option(for: appCountry)
    }

    var selectedMeasurementSystem: AppMeasurementSystem.Option {
        AppMeasurementSystem.option(for: appMeasurementSystem)
    }

    var selectedCurrency: AppCurrency.Option {
        AppCurrency.supported.first { $0.code == AppCurrency.normalize(appCurrency) } ?? AppCurrency.supported[0]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaStaticAppBackground()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        settingsBodySections
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(10, inlinePageSafeAreaInsets.top + 10))
                    .padding(.bottom, inlinePageSafeAreaInsets.bottom)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(preferredScheme)
        .accessibilityIdentifier("settings-screen")
        .alert(l.tr(zh: "重置 App", en: "Reset App", de: "App zurucksetzen"), isPresented: $showingAppResetAlert) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
            Button(l.tr(zh: "重置", en: "Reset", de: "Zurucksetzen"), role: .destructive) {
                resetApp()
            }
        } message: {
            Text(l.tr(
                zh: "此操作将删除 App 内的成员、记录、提醒、任务、奖励和本地自定义内容，无法恢复。重置后会从引导页面重新开始。",
                en: "This deletes members, logs, reminders, tasks, rewards, and local custom content. It cannot be undone. After reset, Ohana starts from onboarding.",
                de: "Dies loscht Mitglieder, Eintrage, Erinnerungen, Aufgaben, Belohnungen und lokale Anpassungen. Das kann nicht ruckgangig gemacht werden. Danach startet Ohana im Onboarding."
            ))
        }
        .alert(l.tr(zh: "重置失败", en: "Reset Failed", de: "Zurucksetzen fehlgeschlagen"), isPresented: Binding(
            get: { appResetErrorMessage != nil },
            set: { if !$0 { appResetErrorMessage = nil } }
        )) {
            Button(l.tr(zh: "好", en: "OK", de: "OK"), role: .cancel) {
                appResetErrorMessage = nil
            }
        } message: {
            Text(appResetErrorMessage ?? l.tr(zh: "未知错误", en: "Unknown error", de: "Unbekannter Fehler"))
        }
        .onAppear {
            syncStoredRegionalDefaultsIfNeeded()
            refreshBiometricGateAvailability()
            scheduleDataSectionsMount()
        }
        .onDisappear {
            dataSectionsMountTask?.cancel()
        }
        .fullScreenCover(isPresented: $showingOnboardingReplay) {
            ZStack(alignment: .topTrailing) {
                OnboardingView(isReplay: true, onReplayFinished: {
                    showingOnboardingReplay = false
                })
                .preferredColorScheme(.dark)

                Button {
                    showingOnboardingReplay = false
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 38, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.ohanaControlFill, in: Capsule())
                        .padding(20)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .sheet(isPresented: $showingAccountSwitcher) {
            HumanAccountSwitcherSheet(
                humans: homeHumans ?? [],
                homePets: homePets,
                homeHumans: homeHumans,
                homeElectronicPets: homeElectronicPets
            )
            .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .sheet(isPresented: $showingBackgroundPicker) {
            AppBackgroundPickerSheet()
                .ohanaSheetPagePresentation() // ui-v4: allow background picker is a long visual chooser
        }
        .sheet(isPresented: $showingPetManagement) {
            SettingsPetManagementSheet(pets: homePets ?? [])
                .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .sheet(isPresented: $showingCoconutBalanceTest) {
            NavigationStack {
                CoconutBalanceTestView()
            }
            .ohanaSheetPagePresentation() // ui-v4: allow developer balance console as long sheet
        }
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
    }
}

#Preview {
    SettingsView()
}

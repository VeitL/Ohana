//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import Combine
import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) private var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = DatabaseFallbackPreferenceStore.isFallbackActive()
    @State private var appSwitcherSnapshotCoverRequested = false
    @State private var isOnboardingHomePreflightActive = false
    @State private var onlineGateNoticeReason: OnlineFeatureGateNoticeReason?
    @StateObject private var startupMaintenance = StartupMaintenanceCoordinator()
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    var body: some View {
        ZStack {
            if hasOnboarded || isOnboardingHomePreflightActive {
                ContentView(showsEmbeddedOnboarding: false)
                    .allowsHitTesting(hasOnboarded)
            }

            if !hasOnboarded {
                OnboardingView(
                    onHomeJoinHandoffPreflight: beginOnboardingHomePreflight
                )
                .zIndex(100)
            }

            if shouldShowPrivacySnapshotCover {
                AppPrivacySnapshotCover()
                    .zIndex(1000)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .toggleStyle(OhanaPillToggleStyle())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            startupMaintenance.startAfterFirstRender(context: modelContext)
        }
        .onDisappear {
            startupMaintenance.cancel()
        }
        .onChange(of: hasOnboarded) { _, hasOnboarded in
            guard hasOnboarded else { return }
            isOnboardingHomePreflightActive = false
        }
        .onReceive(appServices.notificationRoutes.reminderActionEvents) { event in
            appServices.reminderActions.handle(
                userInfo: event.userInfo,
                currentActiveHumanId: currentActiveHumanId,
                context: modelContext,
                careEvents: appServices.careEvents,
                reminderCompletion: appServices.reminderCompletion,
                careLedger: appServices.careLedger,
                questManager: appServices.questManager,
                medicationReminders: appServices.medicationReminders,
                domainRevisions: appServices.domainRevisions
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            appSwitcherSnapshotCoverRequested = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            appSwitcherSnapshotCoverRequested = false
        }
        .onReceive(NotificationCenter.default.publisher(for: OnlineFeatureGateNoticeCenter.notificationName)) { notification in
            onlineGateNoticeReason = OnlineFeatureGateNoticeCenter.reason(from: notification)
        }
        .alert(Text(l.tr(zh: "数据异常", en: "Data issue", de: "Datenproblem")), isPresented: $showDBFallbackAlert) {
            Button(l.tr(zh: "我知道了", en: "Got it", de: "Verstanden"), role: .cancel) {
                DatabaseFallbackPreferenceStore.clearFallbackActive()
            }
        } message: {
            Text(l.tr(
                zh: "数据库加载失败，当前为临时模式。本次会话的数据不会被保存。请尝试重启 App，如问题持续请联系开发者。",
                en: "The database could not be loaded, so Ohana is running in temporary mode. Data from this session will not be saved. Please restart the app, and contact the developer if the issue continues.",
                de: "Die Datenbank konnte nicht geladen werden. Ohana läuft vorübergehend im temporären Modus. Daten aus dieser Sitzung werden nicht gespeichert. Bitte starte die App neu und kontaktiere den Entwickler, falls das Problem weiterhin besteht."
            ))
        }
        .alert(Text(onlineGateNoticeTitle), isPresented: onlineGateNoticeBinding) {
            Button(l.tr(zh: "知道了", en: "Got it", de: "Verstanden"), role: .cancel) {
                onlineGateNoticeReason = nil
            }
        } message: {
            Text(onlineGateNoticeMessage)
        }
    }

    private var shouldShowPrivacySnapshotCover: Bool {
        guard hideAppSwitcherSnapshot else { return false }
        return appSwitcherSnapshotCoverRequested || AppPrivacySnapshotProtectionStore.shouldShowProtection(
            isEnabled: true,
            scenePhase: scenePhase
        )
    }

    private func beginOnboardingHomePreflight() {
        guard !hasOnboarded, !isOnboardingHomePreflightActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isOnboardingHomePreflightActive = true
        }
    }

    private var l: L10n {
        L10n(appLanguage)
    }

    private var onlineGateNoticeBinding: Binding<Bool> {
        Binding(
            get: { onlineGateNoticeReason != nil },
            set: { isPresented in
                if !isPresented {
                    onlineGateNoticeReason = nil
                }
            }
        )
    }

    private var onlineGateNoticeTitle: String {
        onlineGateNoticeReason?.title(l) ?? ""
    }

    private var onlineGateNoticeMessage: String {
        onlineGateNoticeReason?.message(l) ?? ""
    }
}

#Preview {
    RootView()
        .modelContainer(SharedModelContainer.make())
}

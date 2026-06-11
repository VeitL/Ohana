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
    @AppStorage(AppPrivacySnapshotProtectionStore.hideSnapshotKey) private var hideAppSwitcherSnapshot = AppPrivacySnapshotProtectionStore.defaultHideSnapshot
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = DatabaseFallbackPreferenceStore.isFallbackActive()
    @State private var appSwitcherSnapshotCoverRequested = false
    @State private var isOnboardingHomePreflightActive = false
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
        .alert("数据异常", isPresented: $showDBFallbackAlert) {
            Button("我知道了", role: .cancel) {
                DatabaseFallbackPreferenceStore.clearFallbackActive()
            }
        } message: {
            Text("数据库加载失败，当前为临时模式。本次会话的数据不会被保存。请尝试重启 App，如问题持续请联系开发者。")
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
}

#Preview {
    RootView()
        .modelContainer(SharedModelContainer.make())
}

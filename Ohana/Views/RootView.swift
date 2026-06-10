//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct RootView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = DatabaseFallbackPreferenceStore.isFallbackActive()
    @StateObject private var startupMaintenance = StartupMaintenanceCoordinator()
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    var body: some View {
        Group {
            if hasOnboarded {
                ContentView()
            } else {
                OnboardingView()
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
        .onReceive(appServices.notificationRoutes.reminderActionEvents) { event in
            appServices.reminderActions.handle(
                userInfo: event.userInfo,
                currentActiveHumanId: currentActiveHumanId,
                context: modelContext,
                careEvents: appServices.careEvents,
                reminderCompletion: appServices.reminderCompletion
            )
        }
        .alert("数据异常", isPresented: $showDBFallbackAlert) {
            Button("我知道了", role: .cancel) {
                DatabaseFallbackPreferenceStore.clearFallbackActive()
            }
        } message: {
            Text("数据库加载失败，当前为临时模式。本次会话的数据不会被保存。请尝试重启 App，如问题持续请联系开发者。")
        }
    }

}

#Preview {
    RootView()
        .modelContainer(SharedModelContainer.make())
}

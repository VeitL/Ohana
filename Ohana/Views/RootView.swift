//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId = ""
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = UserDefaults.standard.bool(forKey: "ohana_db_fallback_active")
    @StateObject private var startupMaintenance = StartupMaintenanceCoordinator()
    @Environment(\.modelContext) private var modelContext

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
        .onReceive(NotificationCenter.default.publisher(for: .ohanaReminderAction)) { notification in
            ReminderActionCoordinator.handle(
                userInfo: notification.userInfo,
                currentActiveHumanId: currentActiveHumanId,
                context: modelContext
            )
        }
        .alert("数据异常", isPresented: $showDBFallbackAlert) {
            Button("我知道了", role: .cancel) {
                UserDefaults.standard.removeObject(forKey: "ohana_db_fallback_active")
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

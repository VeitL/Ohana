//
//  RootView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded = false
    // F3: 数据库降级警告
    @State private var showDBFallbackAlert = UserDefaults.standard.bool(forKey: "ohana_db_fallback_active")
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if hasOnboarded {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            // 任务二：App 启动时补充 14 天内的通知窗口
            Task { @MainActor in
                let allReminders = (try? modelContext.fetch(FetchDescriptor<Reminder>())) ?? []
                NotificationManager.shared.refillWindowIfNeeded(allReminders: allReminders)
            }
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

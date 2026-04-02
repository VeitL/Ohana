//
//  IslandToastView.swift
//  Ohana
//
//  岛屿连击 Toast：完成委托后从底部浮出的奖励提示。
//

import SwiftUI

struct IslandToastView: View {
    let message: String
    var isShowing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 16, y: 4)
        .opacity(isShowing ? 1 : 0)
        .offset(y: isShowing ? 0 : 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isShowing)
    }
}

// MARK: - 管理器（维护 Toast 状态）
@MainActor
@Observable
final class IslandToastManager {
    static let shared = IslandToastManager()

    var isShowing = false
    var message = ""

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ msg: String) {
        dismissTask?.cancel()
        message = msg
        withAnimation { isShowing = true }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation { isShowing = false }
        }
    }

    /// 根据打卡进度生成合适的文案
    func showQuestProgress(completed: Int, total: Int) {
        let msg: String
        if completed == total {
            msg = "🎉 今日委托全部完成！岛屿能量 MAX"
        } else if completed % 3 == 0 && completed > 0 {
            msg = "🔥 连击 \(completed) 个！继续！"
        } else {
            msg = "✨ 已完成 \(completed)/\(total) · +椰子入账"
        }
        show(msg)
    }
}

// MARK: - ViewModifier 方便挂载
struct IslandToastModifier: ViewModifier {
    var manager: IslandToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            IslandToastView(message: manager.message, isShowing: manager.isShowing)
                .padding(.bottom, 90)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    func islandToastOverlay() -> some View {
        modifier(IslandToastModifier(manager: IslandToastManager.shared))
    }
}

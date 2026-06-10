//
//  IslandToastManager.swift
//  Ohana
//
//  Shared island toast state used by lightweight overlay surfaces.
//

import SwiftUI

@MainActor
@Observable
final class IslandToastManager {
    var isShowing = false
    var message = ""

    private var dismissTask: Task<Void, Never>?

    init() {}

    func show(_ message: String) {
        dismissTask?.cancel()
        self.message = message
        withAnimation { isShowing = true }
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation { isShowing = false }
        }
    }

    func showQuestProgress(completed: Int, total: Int) {
        let message: String
        if completed == total {
            message = "🎉 今日委托全部完成！岛屿能量 MAX"
        } else if completed % 3 == 0 && completed > 0 {
            message = "🔥 连击 \(completed) 个！继续！"
        } else {
            message = "✨ 已完成 \(completed)/\(total) · +椰子入账"
        }
        show(message)
    }
}

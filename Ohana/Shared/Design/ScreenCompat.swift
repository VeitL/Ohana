//
//  ScreenCompat.swift
//  Ohana
//

import SwiftUI
#if os(iOS)
    import UIKit
#endif

// MARK: - Screen Compat（优先 UIWindowScene，避免直接读 UIScreen.main）
enum ScreenCompat {
    static var bounds: CGRect {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let w = scene.windows.first(where: { $0.isKeyWindow }) {
                return w.bounds
            }
        }
        if let w = scenes.first?.windows.first {
            return w.bounds
        }
        return CGRect(x: 0, y: 0, width: 393, height: 852)
    }

    static var width: CGFloat { bounds.width }
    static var height: CGFloat { bounds.height }
    #if os(iOS)
        /// 物理屏圆角半径（与 SpringBoard / 桌面玻璃一致）。优先 `_displayCornerRadius`； unavailable 时用短边比例估算。
        /// - Note: 公开 SDK 暂无 `UIScreen.displayCornerRadius` 成员时依赖 runtime key；若未来系统提供公开 API 可替换。
        static var displayCornerRadius: CGFloat {
            let screen = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen
            if let r = screen?.value(forKey: "_displayCornerRadius") as? CGFloat, r > 1 {
                return r
            }
            let s = bounds.size
            let m = min(s.width, s.height)
            return max(46, m * 0.134)
        }
    #else
        static var displayCornerRadius: CGFloat {
            let s = bounds.size
            return max(46, min(s.width, s.height) * 0.134)
        }
    #endif
}

// MARK: - Environment：屏幕圆角（Focus / 同心卡片等）
enum OhanaDisplayCornerRadiusKey: EnvironmentKey {
    static var defaultValue: CGFloat { ScreenCompat.displayCornerRadius }
}

extension EnvironmentValues {
    /// 设备显示圆角半径；默认与 `ScreenCompat.displayCornerRadius` 一致，可在预览中覆盖。
    var ohanaDisplayCornerRadius: CGFloat {
        get { self[OhanaDisplayCornerRadiusKey.self] }
        set { self[OhanaDisplayCornerRadiusKey.self] = newValue }
    }
}

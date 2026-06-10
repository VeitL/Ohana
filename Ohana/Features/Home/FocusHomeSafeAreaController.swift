//
//  FocusHomeSafeAreaController.swift
//  Ohana
//
//  Stable safe-area snapshot for the home screen.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class FocusHomeSafeAreaController: ObservableObject {
    @Published private(set) var stableTop: CGFloat?
    @Published private(set) var stableBottom: CGFloat?

    init() {
        stableTop = Self.initialTop()
        stableBottom = Self.initialBottom()
    }

    var top: CGFloat {
        resolvedTop()
    }

    var bottom: CGFloat {
        resolvedBottom()
    }

    func resolvedTop(in geo: GeometryProxy? = nil) -> CGFloat {
        if let stableTop, stableTop > 1 {
            return stableTop
        }
        if let geoTop = geo?.safeAreaInsets.top, geoTop > 1 {
            return geoTop
        }
        let windowTop = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 0
        return windowTop > 1 ? windowTop : 59
    }

    func resolvedBottom(in geo: GeometryProxy? = nil) -> CGFloat {
        if let stableBottom, stableBottom > 1 {
            return stableBottom
        }
        if let geoBottom = geo?.safeAreaInsets.bottom, geoBottom > 1 {
            return geoBottom
        }
        let windowBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 0
        return windowBottom > 1 ? windowBottom : 34
    }

    func stabilize(from geo: GeometryProxy) {
        let measuredTop = geo.safeAreaInsets.top > 1 ? geo.safeAreaInsets.top : Self.windowTop()
        let measuredBottom = geo.safeAreaInsets.bottom > 1 ? geo.safeAreaInsets.bottom : Self.windowBottom()
        let top = measuredTop > 1 ? measuredTop : resolvedTop()
        let bottom = measuredBottom > 1 ? measuredBottom : resolvedBottom()
        HomeSafeAreaCacheStore.cache(top: top, bottom: bottom)
        guard stableTop == nil || stableBottom == nil else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if stableTop == nil, top > 1 {
                stableTop = top
            }
            if stableBottom == nil, bottom > 1 {
                stableBottom = bottom
            }
        }
        AppPerformanceMonitor.shared.record(
            "home.layoutStable",
            valueMS: 0,
            note: "top \(Int(top)), bottom \(Int(bottom))"
        )
    }

    private static func initialTop() -> CGFloat? {
        let window = windowTop()
        if window > 1 { return window }
        return HomeSafeAreaCacheStore.cachedTop() ?? 59
    }

    private static func initialBottom() -> CGFloat? {
        let window = windowBottom()
        if window > 1 { return window }
        return HomeSafeAreaCacheStore.cachedBottom() ?? 34
    }

    private static func windowTop() -> CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.top ?? 0
    }

    private static func windowBottom() -> CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?.safeAreaInsets.bottom ?? 0
    }
}

//
//  OhanaDeferredInlinePageCover.swift
//  Ohana
//
//  Lightweight full-screen inline presentation shell. The shell animates first;
//  heavy page content is mounted by the caller after the motion handoff.
//

import SwiftUI
import UIKit

private struct OhanaInlinePageSafeAreaInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets()
}

extension EnvironmentValues {
    var ohanaInlinePageSafeAreaInsets: EdgeInsets {
        get { self[OhanaInlinePageSafeAreaInsetsKey.self] }
        set { self[OhanaInlinePageSafeAreaInsetsKey.self] = newValue }
    }
}

enum OhanaDeferredInlinePageCoverStyle {
    case fullScreen
    case sheetPage

    func topGap(safeTop: CGFloat) -> CGFloat {
        switch self {
        case .fullScreen:
            0
        case .sheetPage:
            max(10, safeTop - 18)
        }
    }

    var horizontalInset: CGFloat {
        switch self {
        case .fullScreen, .sheetPage:
            0
        }
    }

    var topCornerRadius: CGFloat {
        switch self {
        case .fullScreen:
            0
        case .sheetPage:
            36
        }
    }

    func contentTopInset(reservesSafeArea: Bool, safeTop: CGFloat) -> CGFloat {
        guard reservesSafeArea else { return 0 }
        switch self {
        case .fullScreen:
            return safeTop
        case .sheetPage:
            return 0
        }
    }
}

struct OhanaDeferredInlinePageCover<Content: View>: View {
    let progress: CGFloat
    let isContentMounted: Bool
    var reservesSafeArea: Bool = true
    var style: OhanaDeferredInlinePageCoverStyle = .fullScreen
    @ViewBuilder let content: () -> Content

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let progress = clampedProgress
            let safeInsets = OhanaInlinePageSafeAreaResolver.insets(in: geo)
            let topGap = style.topGap(safeTop: safeInsets.top)
            let contentTopInset = style.contentTopInset(
                reservesSafeArea: reservesSafeArea,
                safeTop: safeInsets.top
            )
            let panelWidth = max(0, geo.size.width - style.horizontalInset * 2)
            let panelHeight = max(0, geo.size.height - topGap)
            let hiddenOffset = panelHeight + safeInsets.bottom + 32

            ZStack(alignment: .bottom) {
                Color.arkInk
                    .opacity(Double(progress) * 0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ZStack {
                    OhanaStaticAppBackground()
                        .opacity(isContentMounted ? 0 : 1)
                        .allowsHitTesting(false)

                    if isContentMounted {
                        content()
                            .environment(\.ohanaInlinePageSafeAreaInsets, safeInsets)
                            .padding(.top, contentTopInset)
                            .padding(.bottom, reservesSafeArea ? safeInsets.bottom : 0)
                            .transition(.opacity)
                    }
                }
                .frame(width: panelWidth, height: panelHeight)
                .background(Color.ohanaCardSurface)
                .modifier(OhanaDeferredInlinePageCoverChrome(style: style))
                .offset(y: (1 - progress) * hiddenOffset)
                .scaleEffect(0.985 + 0.015 * progress, anchor: .bottom)
                .opacity(0.88 + 0.12 * Double(progress))
                .animation(GoMotion.sheetEnter, value: progress)
                .animation(GoMotion.quick, value: isContentMounted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(isContentMounted && progress > 0.98)
        }
    }
}

struct OhanaInlinePageRouteHost<Content: View>: View {
    let routeID: String
    let onClose: () -> Void
    var contentMountDelayMilliseconds: UInt64 = 64
    var interactionReadyDelayMilliseconds: UInt64 = 320
    var closeDelayMilliseconds: UInt64 = 340
    var reservesSafeArea: Bool = false
    var style: OhanaDeferredInlinePageCoverStyle = .fullScreen
    @ViewBuilder let content: (_ requestClose: @escaping () -> Void) -> Content

    @ObservedObject private var workloadPolicy = AppWorkloadPolicy.shared
    @State private var presentationProgress: CGFloat = 0
    @State private var isContentMounted = false
    @State private var isInteractionReady = false
    @State private var isClosing = false
    @State private var closeTask: Task<Void, Never>?

    var body: some View {
        OhanaDeferredInlinePageCover(
            progress: presentationProgress,
            isContentMounted: isContentMounted,
            reservesSafeArea: reservesSafeArea,
            style: style
        ) {
            content(requestClose)
        }
        .allowsHitTesting(isInteractionReady && !isClosing)
        .accessibilityAddTraits(.isModal)
        .task(id: routeID) {
            await playEntrance()
        }
        .onDisappear {
            closeTask?.cancel()
        }
    }

    @MainActor
    private func playEntrance() async {
        closeTask?.cancel()
        presentationProgress = 0
        isContentMounted = false
        isInteractionReady = false
        isClosing = false

        await OhanaFrameScheduler.waitAfterNextFrame()
        guard !Task.isCancelled else { return }
        setPresentationProgress(1)

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: contentMountDelay)
        guard !Task.isCancelled, !isClosing else { return }
        withAnimation(GoMotion.quick) {
            isContentMounted = true
        }

        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: interactionReadyDelay)
        guard !Task.isCancelled, !isClosing else { return }
        isInteractionReady = true
    }

    private func requestClose() {
        guard !isClosing else { return }
        isClosing = true
        isInteractionReady = false
        OhanaFeedback.light()
        withAnimation(GoMotion.quick) {
            isContentMounted = false
        }
        setPresentationProgress(0)
        closeTask?.cancel()
        closeTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: closeDelay) {
            onClose()
        }
    }

    private func setPresentationProgress(_ progress: CGFloat) {
        guard allowsMotion else {
            presentationProgress = progress
            return
        }
        withAnimation(GoMotion.sheetEnter) {
            presentationProgress = progress
        }
    }

    private var allowsMotion: Bool {
        workloadPolicy.interactionMotionBudget(isVisible: true).allowsMotion
    }

    private var contentMountDelay: UInt64 {
        allowsMotion ? contentMountDelayMilliseconds : 0
    }

    private var interactionReadyDelay: UInt64 {
        allowsMotion ? interactionReadyDelayMilliseconds : 0
    }

    private var closeDelay: UInt64 {
        allowsMotion ? closeDelayMilliseconds : 90
    }
}

private enum OhanaInlinePageSafeAreaResolver {
    static func insets(in geo: GeometryProxy) -> EdgeInsets {
        let windowInsets = activeWindowSafeAreaInsets()
        return EdgeInsets(
            top: resolvedInset(geo.safeAreaInsets.top, windowInsets.top, fallback: 59),
            leading: max(geo.safeAreaInsets.leading, windowInsets.left),
            bottom: resolvedInset(geo.safeAreaInsets.bottom, windowInsets.bottom, fallback: 34),
            trailing: max(geo.safeAreaInsets.trailing, windowInsets.right)
        )
    }

    private static func resolvedInset(_ geoValue: CGFloat, _ windowValue: CGFloat, fallback: CGFloat) -> CGFloat {
        let measured = max(geoValue, windowValue)
        return measured > 1 ? measured : fallback
    }

    private static func activeWindowSafeAreaInsets() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
}

private struct OhanaDeferredInlinePageCoverChrome: ViewModifier {
    let style: OhanaDeferredInlinePageCoverStyle

    func body(content: Content) -> some View {
        switch style {
        case .fullScreen:
            content
        case .sheetPage:
            let radius = style.topCornerRadius
            let shape = UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: radius,
                style: .continuous
            )
            content
                .clipShape(shape)
                .overlay {
                    shape
                        .strokeBorder(Color.ohanaGlassStroke.opacity(0.18), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
        }
    }
}

//
//  OhanaDeferredInlinePageCover.swift
//  Ohana
//
//  Lightweight full-screen inline presentation shell. The shell animates first;
//  heavy page content is mounted by the caller after the motion handoff.
//

import SwiftUI

enum OhanaDeferredInlinePageCoverStyle {
    case fullScreen
    case sheetPage

    func topGap(safeTop: CGFloat) -> CGFloat {
        switch self {
        case .fullScreen:
            return 0
        case .sheetPage:
            return max(10, safeTop - 18)
        }
    }

    var horizontalInset: CGFloat {
        switch self {
        case .fullScreen, .sheetPage:
            return 0
        }
    }

    var topCornerRadius: CGFloat {
        switch self {
        case .fullScreen:
            return 0
        case .sheetPage:
            return 36
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
            let topGap = style.topGap(safeTop: geo.safeAreaInsets.top)
            let contentTopInset = style.contentTopInset(
                reservesSafeArea: reservesSafeArea,
                safeTop: geo.safeAreaInsets.top
            )
            let panelWidth = max(0, geo.size.width - style.horizontalInset * 2)
            let panelHeight = max(0, geo.size.height - topGap)
            let hiddenOffset = panelHeight + geo.safeAreaInsets.bottom + 32

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
                            .padding(.top, contentTopInset)
                            .padding(.bottom, reservesSafeArea ? geo.safeAreaInsets.bottom : 0)
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

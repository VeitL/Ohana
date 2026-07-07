//
//  NavigationBarStyleLabView.swift
//  Ohana
//
//  Developer-only navigation chrome style playground.
//

import SwiftUI

struct NavigationBarStyleLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaStaticAppBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header

                    ForEach(NavigationBarLabStyle.allCases) { style in
                        NavigationBarStylePairSection(style: style, l: l)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left") // a11y: allow back button has localized label; icon hidden below
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaCardSurface, in: Circle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "返回设置", en: "Back to Settings", de: "Zurück zu Einstellungen"))

            VStack(alignment: .leading, spacing: 2) {
                Text(l.tr(zh: "导航栏样式测试", en: "Navigation Bar Lab", de: "Navigationsleisten-Labor"))
                    .font(OhanaFont.title(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(l.tr(zh: "每个方向都有 3-tab 与 4-tab 两版", en: "Each direction shows 3-tab and 4-tab versions", de: "Jede Richtung zeigt 3-Tab- und 4-Tab-Versionen"))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct NavigationBarStylePairSection: View {
    let style: NavigationBarLabStyle
    let l: L10n

    @State private var selectedThreeTab = NavigationBarLabTab.home.id
    @State private var selectedFourTab = NavigationBarLabTab.home.id

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: style.icon)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaFunctionalIcon)
                    .frame(width: 44, height: 44)
                    .background(Color.ohanaControlFill, in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(style.title(l))
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(style.subtitle(l))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer(minLength: 0)
            }

            NavigationBarLabVariantPreview(
                style: style,
                tabCount: 3,
                selectedTab: $selectedThreeTab,
                l: l
            )

            NavigationBarLabVariantPreview(
                style: style,
                tabCount: 4,
                selectedTab: $selectedFourTab,
                l: l
            )
        }
    }
}

private struct NavigationBarLabVariantPreview: View {
    let style: NavigationBarLabStyle
    let tabCount: Int
    @Binding var selectedTab: String
    let l: L10n

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var themePulse = false

    private var tabs: [NavigationBarLabTab] {
        Array(NavigationBarLabTab.fixtures.prefix(tabCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(l.tr(zh: "\(tabCount) 个 Tab", en: "\(tabCount) tabs", de: "\(tabCount) Tabs"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)

                Spacer(minLength: 0)

                Label(
                    l.tr(zh: "主题按钮", en: "Theme button", de: "Designfarben-Taste"),
                    systemImage: "paintpalette.fill"
                )
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(Color.goPrimary)
                .labelStyle(.titleAndIcon)
            }

            ZStack {
                previewSurface
                mockContent
                navChrome
            }
            .frame(height: style.canvasHeight)
            .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                    .strokeBorder(Color.ohanaGlassStroke.opacity(0.18), lineWidth: 1)
            }
        }
        .padding(12)
        .background(
            reduceTransparency ? Color.ohanaCardSurfaceElevated : Color.ohanaCardSurface,
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
    }

    private var previewSurface: some View {
        RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
            .fill(Color.ohanaControlFill.opacity(0.72))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                    .fill(Color.ohanaCardSurfaceElevated.opacity(0.82))
                    .frame(width: 118, height: 64)
                    .padding(12)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
    }

    private var mockContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.goPrimary.opacity(0.22))
                    .frame(width: 28, height: 28) // a11y: allow decorative preview shape; surrounding lab card carries the meaningful labels
                VStack(alignment: .leading, spacing: 4) {
                    Capsule()
                        .fill(Color.ohanaPrimaryText.opacity(0.20))
                        .frame(width: 92, height: 8)
                    Capsule()
                        .fill(Color.ohanaSecondaryText.opacity(0.18))
                        .frame(width: 138, height: 7)
                }
            }

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                    .fill(Color.ohanaCardSurfaceElevated.opacity(0.72))
                RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                    .fill(Color.ohanaCardSurfaceElevated.opacity(0.52))
            }
            .frame(height: style.canvasHeight > 180 ? 82 : 46)

            Spacer(minLength: 0)
        }
        .padding(14)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var navChrome: some View {
        switch style {
        case .floatingCapsule:
            floatingCapsuleChrome
        case .splitActionDock:
            splitActionDockChrome
        case .topSegment:
            topSegmentChrome
        case .inlineToolbar:
            inlineToolbarChrome
        case .sideRail:
            sideRailChrome
        }
    }

    private var floatingCapsuleChrome: some View {
        VStack {
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                capsuleTabs(height: 56, showsSelectedFill: true)
                themeButton(size: 50, icon: "paintpalette.fill")
            }
            .padding(12)
        }
    }

    private var splitActionDockChrome: some View {
        VStack {
            Spacer(minLength: 0)
            ZStack {
                splitDockTabs
                    .frame(height: 58)
                    .padding(.horizontal, 2)

                themeButton(size: 56, icon: "plus")
                    .offset(y: -10)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var topSegmentChrome: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTabTitle)
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "今日", en: "Today", de: "Heute"))
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer(minLength: 0)
                themeButton(size: 44, icon: "paintpalette.fill")
            }

            capsuleTabs(height: 46, showsSelectedFill: false)
            Spacer(minLength: 0)
        }
        .padding(12)
    }

    private var inlineToolbarChrome: some View {
        VStack {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    toolbarTabButton(tab)
                }

                Spacer(minLength: 0)
                themeButton(size: 44, icon: "sparkles")
            }
            .padding(8)
            .background(Color.ohanaCardSurface.opacity(0.96), in: Capsule())
            .padding(12)

            Spacer(minLength: 0)
        }
    }

    private var sideRailChrome: some View {
        HStack(spacing: 12) {
            VStack(spacing: 7) {
                ForEach(tabs) { tab in
                    railTabButton(tab)
                }

                Spacer(minLength: 2)
                themeButton(size: 44, icon: "paintpalette.fill")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(width: 62)
            .background(Color.ohanaCardSurface.opacity(0.96), in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
            .padding(.leading, 12)
            .padding(.vertical, 12)

            Spacer(minLength: 0)
        }
    }

    private var splitDockTabs: some View {
        let midpoint = max(1, tabs.count / 2)
        let leftTabs = Array(tabs.prefix(midpoint))
        let rightTabs = Array(tabs.dropFirst(midpoint))

        return HStack(spacing: 8) {
            ForEach(leftTabs) { tab in
                compactTabButton(tab, minWidth: 0)
            }

            Color.clear
                .frame(width: 58, height: 1)

            ForEach(rightTabs) { tab in
                compactTabButton(tab, minWidth: 0)
            }
        }
        .padding(.horizontal, 10)
        .background(Color.ohanaCardSurface.opacity(0.96), in: Capsule())
    }

    private func capsuleTabs(height: CGFloat, showsSelectedFill: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                compactTabButton(tab, minWidth: 0, showsSelectedFill: showsSelectedFill)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(Color.ohanaCardSurface.opacity(0.96), in: Capsule())
    }

    private func compactTabButton(
        _ tab: NavigationBarLabTab,
        minWidth: CGFloat,
        showsSelectedFill: Bool = true
    ) -> some View {
        let isSelected = selectedTab == tab.id

        return Button {
            select(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(OhanaFont.subheadline(.black))
                    .symbolVariant(isSelected ? .fill : .none)
                Text(tab.title(l))
                    .font(OhanaFont.caption2(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaSecondaryText)
            .frame(minWidth: minWidth)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.horizontal, 4)
            .background {
                if isSelected, showsSelectedFill {
                    Capsule()
                        .fill(Color.goPrimary.opacity(0.16))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(tab.title(l))
    }

    private func toolbarTabButton(_ tab: NavigationBarLabTab) -> some View {
        let isSelected = selectedTab == tab.id

        return Button {
            select(tab)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(OhanaFont.callout(.black))
                    .symbolVariant(isSelected ? .fill : .none)

                if isSelected {
                    Text(tab.shortTitle(l))
                        .font(OhanaFont.caption2(.black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .frame(minWidth: isSelected ? 70 : 44)
            .frame(height: 44)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(tab.title(l))
    }

    private func railTabButton(_ tab: NavigationBarLabTab) -> some View {
        let isSelected = selectedTab == tab.id

        return Button {
            select(tab)
        } label: {
            Image(systemName: tab.icon)
                .font(OhanaFont.callout(.black))
                .symbolVariant(isSelected ? .fill : .none)
                .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
                .frame(width: 44, height: 32)
                .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(tab.title(l))
    }

    private func themeButton(size: CGFloat, icon: String) -> some View {
        Button {
            withAnimation(GoMotion.feedback) {
                themePulse.toggle()
            }
        } label: {
            Image(systemName: icon)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: size, height: size)
                .background(Color.goPrimary, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.ohanaPrimaryActionText.opacity(themePulse ? 0.34 : 0.18), lineWidth: 1)
                }
                .scaleEffect(themePulse ? 1.04 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "主题色按钮", en: "Theme color button", de: "Designfarben-Taste"))
    }

    private var selectedTabTitle: String {
        tabs.first { $0.id == selectedTab }?.title(l) ?? tabs[0].title(l)
    }

    private func select(_ tab: NavigationBarLabTab) {
        withAnimation(GoMotion.selection) {
            selectedTab = tab.id
        }
    }
}

private enum NavigationBarLabStyle: CaseIterable, Identifiable {
    case floatingCapsule
    case splitActionDock
    case topSegment
    case inlineToolbar
    case sideRail

    var id: String {
        switch self {
        case .floatingCapsule: "floatingCapsule"
        case .splitActionDock: "splitActionDock"
        case .topSegment: "topSegment"
        case .inlineToolbar: "inlineToolbar"
        case .sideRail: "sideRail"
        }
    }

    var icon: String {
        switch self {
        case .floatingCapsule: "capsule.portrait"
        case .splitActionDock: "plus.circle.fill"
        case .topSegment: "rectangle.topthird.inset.filled"
        case .inlineToolbar: "slider.horizontal.3"
        case .sideRail: "sidebar.left"
        }
    }

    var canvasHeight: CGFloat {
        switch self {
        case .sideRail: 224
        case .topSegment: 166
        default: 154
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .floatingCapsule:
            l.tr(zh: "浮动胶囊导航", en: "Floating Capsule", de: "Schwebende Kapsel")
        case .splitActionDock:
            l.tr(zh: "中心按钮 Dock", en: "Center Action Dock", de: "Dock mit Mitteltaste")
        case .topSegment:
            l.tr(zh: "顶部标题分段", en: "Top Title Segment", de: "Oberes Titelsegment")
        case .inlineToolbar:
            l.tr(zh: "轻量工具条", en: "Light Toolbar", de: "Leichte Werkzeugleiste")
        case .sideRail:
            l.tr(zh: "侧边 Rail", en: "Side Rail", de: "Seitenleiste")
        }
    }

    func subtitle(_ l: L10n) -> String {
        switch self {
        case .floatingCapsule:
            l.tr(zh: "底部浮层，主题按钮独立跟随", en: "Bottom float with a separate theme action", de: "Unten schwebend mit eigener Designaktion")
        case .splitActionDock:
            l.tr(zh: "主操作居中，Tab 分列两侧", en: "Primary action centered between tabs", de: "Hauptaktion mittig zwischen Tabs")
        case .topSegment:
            l.tr(zh: "标题与 Tab 同在顶部", en: "Title and tabs share the top bar", de: "Titel und Tabs teilen die obere Leiste")
        case .inlineToolbar:
            l.tr(zh: "选中项展开，未选中项保持图标", en: "Selected item expands, others stay icon-only", de: "Auswahl klappt auf, andere bleiben Symbole")
        case .sideRail:
            l.tr(zh: "竖向导航，适合大屏或专注页", en: "Vertical nav for wide or focused screens", de: "Vertikale Navigation für breite oder fokussierte Ansichten")
        }
    }
}

private struct NavigationBarLabTab: Identifiable, Equatable {
    let id: String
    let icon: String
    let zh: String
    let en: String
    let de: String
    let shortZh: String
    let shortEn: String
    let shortDe: String

    func title(_ l: L10n) -> String {
        l.tr(zh: zh, en: en, de: de)
    }

    func shortTitle(_ l: L10n) -> String {
        l.tr(zh: shortZh, en: shortEn, de: shortDe)
    }

    static let home = NavigationBarLabTab(
        id: "home",
        icon: "house",
        zh: "首页",
        en: "Home",
        de: "Start",
        shortZh: "首页",
        shortEn: "Home",
        shortDe: "Start"
    )

    static let calendar = NavigationBarLabTab(
        id: "calendar",
        icon: "calendar",
        zh: "日历",
        en: "Calendar",
        de: "Kalender",
        shortZh: "日历",
        shortEn: "Cal",
        shortDe: "Kal"
    )

    static let oasis = NavigationBarLabTab(
        id: "oasis",
        icon: "leaf",
        zh: "绿洲",
        en: "Oasis",
        de: "Oase",
        shortZh: "绿洲",
        shortEn: "Oasis",
        shortDe: "Oase"
    )

    static let health = NavigationBarLabTab(
        id: "health",
        icon: "heart",
        zh: "健康",
        en: "Health",
        de: "Gesundheit",
        shortZh: "健康",
        shortEn: "Health",
        shortDe: "Fit"
    )

    static let fixtures: [NavigationBarLabTab] = [
        .home,
        .calendar,
        .oasis,
        .health
    ]
}

#Preview {
    NavigationStack {
        NavigationBarStyleLabView()
    }
}

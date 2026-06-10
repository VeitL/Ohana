//
//  AddWizardGameComponents.swift
//  Ohana
//
//  Shared lightweight RPG-style creation components for human and pet wizards.
//

import SwiftUI

struct AddWizardStageItem: Identifiable, Equatable {
    let id: Int
    let title: String
    let systemImage: String
}

struct AddWizardThreePanelLayout<Preview: View, Content: View, Footer: View>: View {
    var previewPanelHeight: CGFloat = 204
    var footerPanelHeight: CGFloat = 66
    var topInsetFallback: CGFloat = 50
    var bottomInsetFallback: CGFloat = 12
    @ViewBuilder var preview: () -> Preview
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    init(
        previewPanelHeight: CGFloat = 204,
        footerPanelHeight: CGFloat = 66,
        topInsetFallback: CGFloat = 50,
        bottomInsetFallback: CGFloat = 12,
        @ViewBuilder preview: @escaping () -> Preview,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.previewPanelHeight = previewPanelHeight
        self.footerPanelHeight = footerPanelHeight
        self.topInsetFallback = topInsetFallback
        self.bottomInsetFallback = bottomInsetFallback
        self.preview = preview
        self.content = content
        self.footer = footer
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = max(geo.safeAreaInsets.top, topInsetFallback)
            let bottomInset = max(geo.safeAreaInsets.bottom, bottomInsetFallback)
            let usableHeight = max(0, geo.size.height - topInset - bottomInset)
            let previewHeight = min(previewPanelHeight, max(188, usableHeight * 0.42))
            let footerHeight = min(footerPanelHeight, max(58, usableHeight * 0.12))
            let contentHeight = max(0, usableHeight - previewHeight - footerHeight)

            VStack(spacing: 0) {
                preview()
                    .frame(height: previewHeight, alignment: .top)

                content()
                    .frame(height: contentHeight)

                footer()
                    .frame(height: footerHeight, alignment: .center)
            }
            .frame(width: geo.size.width, height: usableHeight, alignment: .top)
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .ignoresSafeArea(.keyboard)
    }
}

struct AddWizardStageProgress: View {
    let stages: [AddWizardStageItem]
    let currentIndex: Int
    var accent: Color = .goPrimary
    var onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stages) { stage in
                    Button {
                        onSelect(stage.id)
                    } label: {
                        stageCell(stage)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(stage.title)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 52)
        .animation(GoMotion.selection, value: currentIndex)
    }

    private func stageCell(_ stage: AddWizardStageItem) -> some View {
        let isCurrent = stage.id == currentIndex

        return HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(isCurrent ? accent : Color.ohanaCardSurfaceElevated)
                    .frame(width: 28, height: 28) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(systemName: stage.systemImage)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isCurrent ? Color.arkInk : Color.ohanaSecondaryText)
            }
            if isCurrent {
                Text(stage.title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, isCurrent ? 12 : 4)
        .padding(.vertical, 5)
        .frame(minHeight: 44)
        .background(
            isCurrent ? Color.ohanaCardSurfaceElevated : Color.clear,
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(isCurrent ? accent.opacity(0.34) : Color.clear, lineWidth: 1)
        )
    }
}

struct AddWizardThemeMatrixCell<Fill: ShapeStyle>: View {
    let fill: Fill
    let liftColor: Color
    let checkmarkColor: Color
    var isSelected: Bool
    var isDisabled: Bool = false
    var showsPaletteIcon: Bool = false
    var accessibilityTitle: String

    var body: some View {
        ZStack {
            Rectangle()
                .fill(fill)
                .saturation(isDisabled ? 0.22 : 1)
                .opacity(isDisabled ? 0.36 : 1)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.goCardWhite.opacity(isDisabled ? 0.04 : 0.16),
                            Color.clear,
                            Color.arkInk.opacity(isDisabled ? 0.04 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Rectangle()
                .strokeBorder(Color.ohanaCardStroke.opacity(0.24), lineWidth: 0.35)
            if showsPaletteIcon, !isSelected {
                Image(systemName: "plus").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 16, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            if isDisabled {
                Rectangle()
                    .fill(Color.ohanaCardSurface.opacity(0.58))
                Image(systemName: "xmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            if isSelected {
                Circle()
                    .fill(Color.goCardWhite.opacity(0.94))
                    .frame(width: 23, height: 23) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Image(systemName: "checkmark").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.arkInk)
                Rectangle()
                    .strokeBorder(Color.goCardWhite.opacity(0.96), lineWidth: 2)
                Rectangle()
                    .strokeBorder(Color.arkInk.opacity(0.16), lineWidth: 3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(isSelected ? 1.015 : 1.0)
        .zIndex(isSelected ? 2 : isDisabled ? -1 : 0)
        .animation(GoMotion.selection, value: isSelected)
        .accessibilityLabel(accessibilityTitle)
    }
}

enum AddWizardPlainAvatarPlaceholderKind {
    case human
    case pet(symbol: String)
}

struct AddWizardPlainAvatarPlaceholder: View {
    let kind: AddWizardPlainAvatarPlaceholderKind
    var tint: Color = .goPrimary

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)

            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: side * 0.74, height: side * 0.74)
                    .offset(x: -side * 0.08, y: -side * 0.06)
                Circle()
                    .fill(Color.ohanaCardSurface)
                    .frame(width: side * 0.58, height: side * 0.58)
                    .offset(x: side * 0.14, y: side * 0.12)
                Circle()
                    .strokeBorder(tint.opacity(0.42), lineWidth: max(1, side * 0.018))
                    .frame(width: side * 0.78, height: side * 0.78)

                Image(systemName: symbolName)
                    .font(.system(size: side * 0.34, weight: .black, design: .rounded))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(tint)

                RoundedRectangle(cornerRadius: side * 0.03, style: .continuous)
                    .fill(Color.ohanaSecondaryText.opacity(0.18))
                    .frame(width: side * 0.34, height: side * 0.035)
                    .offset(y: side * 0.37)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch kind {
        case .human:
            "person.crop.circle"
        case let .pet(symbol):
            symbol
        }
    }
}

enum AddWizardThemePalette {
    static let gridColumnCount = 10

    // Apple-style compact grid. Excludes Ohana's reserved goLime/goBlue primary colors.
    static let memberOptions: [(hex: String, label: String)] = [
        ("FFFFFF", "白"), ("F2F2F7", "雾灰"), ("D1D5DB", "浅灰"), ("9CA3AF", "银灰"), ("6B7280", "石墨"),
        ("374151", "深灰"), ("111827", "墨黑"), ("2D1B69", "夜紫"), ("3B1D4A", "深莓"), ("143642", "深海"),
        ("164E63", "孔雀"), ("1E3A8A", "海军"), ("312E81", "靛夜"), ("4C1D95", "紫夜"), ("831843", "莓红"),
        ("7F1D1D", "暗红"), ("7C2D12", "陶土"), ("78350F", "咖啡"), ("713F12", "古金"), ("365314", "苔绿"),
        ("0E7490", "湖青"), ("1D4ED8", "皇家蓝"), ("4338CA", "紫蓝"), ("6D28D9", "紫罗兰"), ("BE185D", "玫莓"),
        ("B91C1C", "酒红"), ("C2410C", "橘红"), ("B45309", "琥珀"), ("A16207", "橄榄金"), ("4D7C0F", "森林"),
        ("0891B2", "海青"), ("2563EB", "明蓝"), ("4F46E5", "靛蓝"), ("7C3AED", "电紫"), ("DB2777", "亮粉"),
        ("DC2626", "红"), ("EA580C", "橙"), ("D97706", "蜜橙"), ("CA8A04", "芥末"), ("65A30D", "叶绿"),
        ("06B6D4", "冰青"), ("60A5FA", "天蓝"), ("818CF8", "薰衣草"), ("A78BFA", "淡紫"), ("F472B6", "粉"),
        ("FB7185", "珊瑚"), ("F97316", "暖橙"), ("F59E0B", "金"), ("EAB308", "向日葵"), ("84CC16", "青叶"),
        ("A5F3FC", "浅青"), ("BFDBFE", "雾蓝"), ("C7D2FE", "浅靛"), ("DDD6FE", "浅紫"), ("FBCFE8", "浅粉"),
        ("FECACA", "浅红"), ("FED7AA", "浅橙"), ("FDE68A", "奶油"), ("FEF3C7", "米黄"), ("D9F99D", "嫩叶")
    ]
}

enum AddWizardThemeMatrixContrast {
    static func readableCheckmarkColor(for hex: String) -> Color {
        let upper = hex.uppercased()
        let lightHexes: Set<String> = ["FFFFFF", "F2F2F7", "FFEAA7", "FDCB6E", "FFCC00", "F59E0B", "84CC16", "C8FF00"]
        return lightHexes.contains(upper) ? Color.arkInk : Color.goCardWhite
    }
}

struct AddWizardPagedCardCarousel: View {
    @Binding var pageIndex: Int
    @Binding var pageDirection: Int
    private var isDragging: Binding<Bool>?
    let pageCount: Int
    var spacing: CGFloat = 12
    var page: (Int) -> AnyView

    @State private var dragOffset: CGFloat = 0
    @State private var isHorizontalDragActive = false
    private let settleAnimation = Animation.interactiveSpring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)

    init(
        pageIndex: Binding<Int>,
        pageDirection: Binding<Int>,
        isDragging: Binding<Bool>? = nil,
        pageCount: Int,
        spacing: CGFloat = 12,
        page: @escaping (Int) -> AnyView
    ) {
        self._pageIndex = pageIndex
        self._pageDirection = pageDirection
        self.isDragging = isDragging
        self.pageCount = pageCount
        self.spacing = spacing
        self.page = page
    }

    var body: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width
            let step = pageWidth + spacing
            let displayedDrag = rubberBanded(dragOffset)
            HStack(spacing: spacing) {
                ForEach(0 ..< pageCount, id: \.self) { index in
                    page(index)
                        .allowsHitTesting(!isHorizontalDragActive)
                        .frame(width: pageWidth, height: geo.size.height)
                        .shadow( // ui-v4: allow wizard card depth during direct manipulation
                            color: Color.black.opacity(0.12), // ui-v4: allow physical card shadow
                            radius: 14,
                            y: 7
                        )
                }
            }
            .offset(x: -CGFloat(pageIndex) * step + displayedDrag)
            .contentShape(Rectangle())
            .highPriorityGesture(pageSwipeGesture(width: pageWidth), including: .gesture)
        }
        .clipped()
    }

    private func pageSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                guard isHorizontalDragActive || isHorizontalIntent(value) else { return }
                isHorizontalDragActive = true
                isDragging?.wrappedValue = true
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dragOffset = value.translation.width
                }
            }
            .onEnded { value in
                defer {
                    isHorizontalDragActive = false
                    isDragging?.wrappedValue = false
                }
                guard isHorizontalDragActive || isHorizontalIntent(value) else {
                    withAnimation(settleAnimation) { dragOffset = 0 }
                    return
                }
                let projected = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
                    ? value.predictedEndTranslation.width
                    : value.translation.width
                let threshold = max(78, width * 0.22)
                guard abs(projected) > threshold else {
                    withAnimation(settleAnimation) { dragOffset = 0 }
                    return
                }
                movePage(by: projected < 0 ? 1 : -1)
            }
    }

    private func isHorizontalIntent(_ value: DragGesture.Value) -> Bool {
        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        guard horizontal > 7 else { return false }
        return horizontal > max(10, vertical * 1.12)
    }

    private func rubberBanded(_ offset: CGFloat) -> CGFloat {
        guard offset != 0 else { return 0 }
        let atLeadingEdge = pageIndex == 0 && offset > 0
        let atTrailingEdge = pageIndex == pageCount - 1 && offset < 0
        return offset * (atLeadingEdge || atTrailingEdge ? 0.22 : 1)
    }

    private func movePage(by delta: Int) {
        let next = min(max(pageIndex + delta, 0), pageCount - 1)
        guard next != pageIndex else {
            withAnimation(settleAnimation) { dragOffset = 0 }
            return
        }
        GoKeyboard.dismiss()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pageDirection = delta >= 0 ? 1 : -1
        withAnimation(settleAnimation) {
            pageIndex = next
            dragOffset = 0
        }
    }
}

struct AddWizardStatusBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = .goPrimary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
    }
}

struct AddWizardCardCloseButton: View {
    @AppStorage("appLanguage") private var appLanguage = "zh"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .background(
                    Circle()
                        .fill(Color.goCardWhite.opacity(0.76))
                        .overlay(
                            Circle()
                                .stroke(Color.arkInk.opacity(0.10), lineWidth: 1)
                        )
                )
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n(appLanguage).tr(zh: "关闭", en: "Close", de: "Schließen"))
    }
}

struct AddWizardJoinCelebrationOverlay: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = .goPrimary

    var body: some View {
        ZStack {
            Color.ohanaPrimaryText.opacity(0.26)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent)
                        .frame(width: 72, height: 72)
                    Image(systemName: systemImage)
                        .font(OhanaFont.adaptive(size: 30, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.arkInk)
                }
                VStack(spacing: 5) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: min(ScreenCompat.width - 42, 360))
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.sheetMini, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}

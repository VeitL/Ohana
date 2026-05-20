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

struct AddWizardStageProgress: View {
    let stages: [AddWizardStageItem]
    let currentIndex: Int
    var accent: Color = Color.goPrimary
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
                    .frame(width: 28, height: 28)
                Image(systemName: stage.systemImage)
                    .font(.system(size: 12, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(isCurrent ? Color.arkInk : Color.ohanaSecondaryText)
            }
            if isCurrent {
                Text(stage.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
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
            if showsPaletteIcon && !isSelected {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            if isDisabled {
                Rectangle()
                    .fill(Color.ohanaCardSurface.opacity(0.58))
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            if isSelected {
                Circle()
                    .fill(Color.goCardWhite.opacity(0.94))
                    .frame(width: 23, height: 23)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
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
    let pageCount: Int
    var spacing: CGFloat = 12
    var page: (Int) -> AnyView

    @GestureState private var dragOffset: CGFloat = 0
    private let settleAnimation = Animation.interactiveSpring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)

    init(
        pageIndex: Binding<Int>,
        pageDirection: Binding<Int>,
        pageCount: Int,
        spacing: CGFloat = 12,
        page: @escaping (Int) -> AnyView
    ) {
        self._pageIndex = pageIndex
        self._pageDirection = pageDirection
        self.pageCount = pageCount
        self.spacing = spacing
        self.page = page
    }

    var body: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width
            let step = pageWidth + spacing
            let displayedDrag = rubberBanded(dragOffset)
            let visualPage = CGFloat(pageIndex) - displayedDrag / max(step, 1)

            HStack(spacing: spacing) {
                ForEach(0..<pageCount, id: \.self) { index in
                    page(index)
                        .frame(width: pageWidth, height: geo.size.height)
                        .scaleEffect(scale(for: index, visualPage: visualPage), anchor: .top)
                        .opacity(opacity(for: index, visualPage: visualPage))
                        .shadow( // ui-v4: allow wizard card depth during direct manipulation
                            color: Color.black.opacity(shadowOpacity(for: index, visualPage: visualPage)), // ui-v4: allow physical card shadow
                            radius: shadowRadius(for: index, visualPage: visualPage),
                            y: shadowY(for: index, visualPage: visualPage)
                        )
                }
            }
            .offset(x: -CGFloat(pageIndex) * step + displayedDrag)
            .contentShape(Rectangle())
            .simultaneousGesture(pageSwipeGesture(width: pageWidth))
            .animation(settleAnimation, value: pageIndex)
        }
        .clipped()
    }

    private func scale(for index: Int, visualPage: CGFloat) -> CGFloat {
        let distance = min(abs(CGFloat(index) - visualPage), 1.6)
        return 1 - distance * 0.035
    }

    private func opacity(for index: Int, visualPage: CGFloat) -> Double {
        let distance = min(abs(CGFloat(index) - visualPage), 1.4)
        return 1 - Double(distance) * 0.14
    }

    private func shadowOpacity(for index: Int, visualPage: CGFloat) -> Double {
        let distance = min(abs(CGFloat(index) - visualPage), 1)
        return 0.14 - Double(distance) * 0.06
    }

    private func shadowRadius(for index: Int, visualPage: CGFloat) -> CGFloat {
        let distance = min(abs(CGFloat(index) - visualPage), 1)
        return 16 - distance * 5
    }

    private func shadowY(for index: Int, visualPage: CGFloat) -> CGFloat {
        let distance = min(abs(CGFloat(index) - visualPage), 1)
        return 8 - distance * 3
    }

    private func pageSwipeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .updating($dragOffset) { value, state, _ in
                guard isHorizontalIntent(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isHorizontalIntent(value) else { return }
                let projected = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
                    ? value.predictedEndTranslation.width
                    : value.translation.width
                let threshold = max(78, width * 0.22)
                guard abs(projected) > threshold else { return }
                if projected < 0 {
                    movePage(by: 1)
                } else {
                    movePage(by: -1)
                }
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
        guard next != pageIndex else { return }
        GoKeyboard.dismiss()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pageDirection = delta >= 0 ? 1 : -1
        withAnimation(settleAnimation) {
            pageIndex = next
        }
    }
}

struct AddWizardStatusBadge: View {
    let title: String
    let systemImage: String
    var tint: Color = Color.goPrimary

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint, in: Capsule())
    }
}

struct AddWizardJoinCelebrationOverlay: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var accent: Color = Color.goPrimary

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
                        .font(.system(size: 30, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.arkInk)
                }
                VStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: min(ScreenCompat.width - 42, 360))
            .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            )
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}

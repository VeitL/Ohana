//
//  MotionPreviewLabSupport.swift
//  Ohana
//
//  Extracted support types for the system motion preview lab.
//

import SwiftUI

enum MotionPreviewCategory: String, CaseIterable, Identifiable {
    case number
    case progress
    case chart
    case switching
    case sheetOpen
    case sheetContent

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .number: "number"
        case .progress: "chart.bar.fill"
        case .chart: "chart.line.uptrend.xyaxis"
        case .switching: "person.2.fill"
        case .sheetOpen: "rectangle.bottomthird.inset.filled"
        case .sheetContent: "list.bullet.rectangle"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .number:
            l.tr(zh: "数字", en: "Numbers", de: "Zahlen")
        case .progress:
            l.tr(zh: "进度条", en: "Progress", de: "Fortschritt")
        case .chart:
            l.tr(zh: "Chart", en: "Chart", de: "Chart")
        case .switching:
            l.tr(zh: "切换", en: "Switching", de: "Wechsel")
        case .sheetOpen:
            l.tr(zh: "Sheet 打开", en: "Sheet Opening", de: "Sheet-Oeffnung")
        case .sheetContent:
            l.tr(zh: "Sheet 内容加载", en: "Sheet Content Loading", de: "Sheet-Inhaltsladen")
        }
    }
}

enum MotionPreviewSystem: String, CaseIterable, Identifiable {
    case flow
    case capsule
    case signal

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .flow: "water.waves"
        case .capsule: "circle.hexagongrid.fill"
        case .signal: "sparkles"
        }
    }

    var numberScale: CGFloat {
        switch self {
        case .flow: 1.035
        case .capsule: 1.105
        case .signal: 1.12
        }
    }

    var secondaryNumberScale: CGFloat {
        switch self {
        case .flow: 1.012
        case .capsule: 1.035
        case .signal: 1.045
        }
    }

    var numberDeltaOffset: CGFloat {
        switch self {
        case .flow: -18
        case .capsule: -23
        case .signal: -28
        }
    }

    var numberSettleDelay: Double {
        switch self {
        case .flow: 0.18
        case .capsule: 0.24
        case .signal: 0.30
        }
    }

    var numberDeltaLife: Double {
        switch self {
        case .flow: 0.82
        case .capsule: 1.05
        case .signal: 1.14
        }
    }

    var progressStep: Double {
        switch self {
        case .flow: 0.14
        case .capsule: 0.18
        case .signal: 0.22
        }
    }

    var progressLabelScale: CGFloat {
        switch self {
        case .flow: 1.01
        case .capsule: 1.035
        case .signal: 1.05
        }
    }

    var progressCapScale: CGFloat {
        switch self {
        case .flow: 1.08
        case .capsule: 1.20
        case .signal: 1.30
        }
    }

    var progressCapOpacity: Double {
        switch self {
        case .flow: 0.38
        case .capsule: 0.62
        case .signal: 0.74
        }
    }

    var progressStagger: Double {
        switch self {
        case .flow: 0.012
        case .capsule: 0.026
        case .signal: 0.038
        }
    }

    var progressPulseLife: Double {
        switch self {
        case .flow: 0.16
        case .capsule: 0.22
        case .signal: 0.26
        }
    }

    var chartAreaStartScale: CGFloat {
        switch self {
        case .flow: 1.0
        case .capsule: 0.84
        case .signal: 0.74
        }
    }

    var chartDotStartScale: CGFloat {
        switch self {
        case .flow: 0.96
        case .capsule: 0.70
        case .signal: 0.55
        }
    }

    var chartDotStagger: Double {
        switch self {
        case .flow: 0.045
        case .capsule: 0.026
        case .signal: 0.040
        }
    }

    var switchInitialScale: CGFloat {
        switch self {
        case .flow: 0.998
        case .capsule: 0.990
        case .signal: 0.984
        }
    }

    var sheetContentStartDelay: Double {
        switch self {
        case .flow: 0.08
        case .capsule: 0.10
        case .signal: 0.12
        }
    }

    var contentRowOffset: CGFloat {
        switch self {
        case .flow: 6
        case .capsule: 12
        case .signal: 16
        }
    }

    var contentRowScale: CGFloat {
        switch self {
        case .flow: 0.996
        case .capsule: 0.982
        case .signal: 0.970
        }
    }

    var contentStagger: Double {
        switch self {
        case .flow: 0.018
        case .capsule: 0.035
        case .signal: 0.052
        }
    }

    var numberDeltaTransition: AnyTransition {
        switch self {
        case .flow:
            .opacity.combined(with: .offset(y: -10))
        case .capsule:
            .scale(scale: 0.72, anchor: .bottom).combined(with: .opacity)
        case .signal:
            .scale(scale: 0.58, anchor: .bottom).combined(with: .opacity).combined(with: .offset(y: -8))
        }
    }

    var switchTransition: AnyTransition {
        switch self {
        case .flow:
            .opacity
        case .capsule:
            .opacity.combined(with: .scale(scale: 0.988, anchor: .top))
        case .signal:
            .opacity.combined(with: .scale(scale: 0.976, anchor: .top))
        }
    }

    var sheetTransition: AnyTransition {
        switch self {
        case .flow:
            .move(edge: .bottom).combined(with: .opacity)
        case .capsule:
            .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.985, anchor: .bottom))
        case .signal:
            .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.960, anchor: .bottom))
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "A. Flow", en: "A. Flow", de: "A. Flow")
        case .capsule:
            l.tr(zh: "B. Capsule", en: "B. Capsule", de: "B. Capsule")
        case .signal:
            l.tr(zh: "C. Signal", en: "C. Signal", de: "C. Signal")
        }
    }

    func shortName(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "Flow", en: "Flow", de: "Flow")
        case .capsule:
            l.tr(zh: "Capsule", en: "Capsule", de: "Capsule")
        case .signal:
            l.tr(zh: "Signal", en: "Signal", de: "Signal")
        }
    }

    func badge(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "日常", en: "Daily", de: "Alltag")
        case .capsule:
            l.tr(zh: "推荐", en: "Pick", de: "Favorit")
        case .signal:
            l.tr(zh: "奖励", en: "Reward", de: "Belohnung")
        }
    }

    func summary(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "最克制，数字像流水，切换几乎无位移。适合日历、表单、长列表。", en: "The quietest system: fluid numbers and nearly no movement for switching. Good for calendars, forms, and long lists.", de: "Am ruhigsten: fliessende Zahlen, kaum Bewegung beim Wechsel. Gut fuer Kalender, Formulare und Listen.")
        case .capsule:
            l.tr(zh: "接近你喜欢的椰子胶囊：轻弹、numeric motion、反馈清晰但不夸张。", en: "Closest to the coconut capsule feel: light spring, numeric motion, clear but restrained feedback.", de: "Nahe am Kokos-Kapsel-Gefuehl: leichte Federung, Zahlenbewegung, klares aber dezentes Feedback.")
        case .signal:
            l.tr(zh: "更适合打卡/财富/奖励瞬间，普通切换仍压低幅度。", en: "Best for check-ins, wealth, and reward moments while normal switching stays controlled.", de: "Gut fuer Check-ins, Vermoegen und Belohnungen, normale Wechsel bleiben kontrolliert.")
        }
    }

    func positioning(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "像水一样顺，不吸引注意。", en: "Smooth like water, without asking for attention.", de: "Fliessend wie Wasser, ohne Aufmerksamkeit zu fordern.")
        case .capsule:
            l.tr(zh: "全局默认候选：高级、轻弹、可长期使用。", en: "Global default candidate: premium, lightly elastic, usable everywhere.", de: "Kandidat fuer den Standard: hochwertig, leicht elastisch, ueberall nutzbar.")
        case .signal:
            l.tr(zh: "强调成功和奖励，不用于高频普通切换。", en: "Emphasizes success and rewards, not for frequent ordinary switching.", de: "Betont Erfolg und Belohnung, nicht fuer haeufige normale Wechsel.")
        }
    }

    func spec(for category: MotionPreviewCategory, _ l: L10n) -> String {
        switch (self, category) {
        case (.flow, .number):
            l.tr(zh: "numericText + 1.035 scale + 0.82s delta fade", en: "numericText + 1.035 scale + 0.82s delta fade", de: "numericText + 1.035 Skalierung + 0.82s Delta")
        case (.flow, .progress):
            l.tr(zh: "0.42/0.96 spring，几乎无弹跳", en: "0.42/0.96 spring, almost no bounce", de: "0.42/0.96 Feder, fast kein Bounce")
        case (.flow, .chart):
            l.tr(zh: "0.72s 线条延长 + area 轻淡入，点位轻显", en: "0.72s slow line draw + soft area fade, quiet dots", de: "0.72s langsamer Linienaufbau + weiche Flaeche")
        case (.flow, .switching):
            l.tr(zh: "opacity handoff，0.998 snapshot scale", en: "opacity handoff, 0.998 snapshot scale", de: "Opacity-Handoff, 0.998 Snapshot")
        case (.flow, .sheetOpen):
            l.tr(zh: "bottom slide + fade，无明显 pop", en: "bottom slide + fade, no obvious pop", de: "Bottom-Slide + Fade")
        case (.flow, .sheetContent):
            l.tr(zh: "18ms row stagger，6pt 上浮", en: "18ms row stagger, 6pt lift", de: "18ms Zeilen-Stagger, 6pt Lift")
        case (.capsule, .number):
            l.tr(zh: "numericText + 1.105 capsule pulse + floating delta", en: "numericText + 1.105 capsule pulse + floating delta", de: "numericText + 1.105 Kapsel-Puls")
        case (.capsule, .progress):
            l.tr(zh: "进度尾点轻弹，26ms 分段 stagger", en: "elastic trailing cap, 26ms segment stagger", de: "Elastische Kappe, 26ms Stagger")
        case (.capsule, .chart):
            l.tr(zh: "area grow + line trim + 点位依次弹出", en: "area grow + line trim + staged dot pop", de: "Flaeche waechst + Punkte poppen")
        case (.capsule, .switching):
            l.tr(zh: "opacity + 0.988 scale，像快照换气", en: "opacity + 0.988 scale, snapshot breath", de: "Opacity + 0.988 Snapshot-Atmen")
        case (.capsule, .sheetOpen):
            l.tr(zh: "bottomSpringScaleFade，轻弹落位", en: "bottomSpringScaleFade, lightly settles", de: "BottomSpringScaleFade")
        case (.capsule, .sheetContent):
            l.tr(zh: "35ms row stagger，12pt/0.982 进入", en: "35ms row stagger, 12pt/0.982 entrance", de: "35ms Stagger, 12pt/0.982")
        case (.signal, .number):
            l.tr(zh: "奖励数字 1.12 pop，delta 更高更快", en: "reward number 1.12 pop, higher faster delta", de: "Belohnungszahl 1.12 Pop")
        case (.signal, .progress):
            l.tr(zh: "尾点更亮，38ms 阶段推进", en: "brighter cap, 38ms staged push", de: "Hellere Kappe, 38ms Stufen")
        case (.signal, .chart):
            l.tr(zh: "chart reveal 更强，但只一次", en: "stronger one-shot chart reveal", de: "Staerkeres einmaliges Reveal")
        case (.signal, .switching):
            l.tr(zh: "0.976 scale，仍禁止横跳", en: "0.976 scale, still no lateral jump", de: "0.976 Skalierung, kein Seitensprung")
        case (.signal, .sheetOpen):
            l.tr(zh: "更明显的 bottom pop，只给奖励/确认", en: "more visible bottom pop for rewards/confirm", de: "Staerkerer Bottom-Pop")
        case (.signal, .sheetContent):
            l.tr(zh: "52ms staged reveal，适合奖品列表", en: "52ms staged reveal, for reward lists", de: "52ms gestaffeltes Reveal")
        }
    }

    func chartLabel(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "线条生长", en: "Line draw", de: "Linienaufbau")
        case .capsule:
            l.tr(zh: "点位轻弹", en: "Dot pop", de: "Punkt-Pop")
        case .signal:
            l.tr(zh: "奖励强调", en: "Reward emphasis", de: "Belohnungsfokus")
        }
    }

    func contentLabel(_ l: L10n) -> String {
        switch self {
        case .flow:
            l.tr(zh: "轻淡入", en: "Soft fade", de: "Weicher Fade")
        case .capsule:
            l.tr(zh: "轻弹加载", en: "Elastic load", de: "Elastisches Laden")
        case .signal:
            l.tr(zh: "分段揭示", en: "Staged reveal", de: "Gestaffeltes Reveal")
        }
    }

    func animation(_ category: MotionPreviewCategory, reduceMotion: Bool) -> Animation {
        guard !reduceMotion else { return GoMotion.reduced }
        switch (self, category) {
        case (.flow, .number):
            return .interactiveSpring(response: 0.26, dampingFraction: 0.94, blendDuration: 0.08)
        case (.flow, .progress):
            return .interactiveSpring(response: 0.42, dampingFraction: 0.96, blendDuration: 0.16)
        case (.flow, .chart):
            return .easeOut(duration: 0.72)
        case (.flow, .switching):
            return .interactiveSpring(response: 0.34, dampingFraction: 0.98, blendDuration: 0.14)
        case (.flow, .sheetOpen):
            return .interactiveSpring(response: 0.42, dampingFraction: 0.94, blendDuration: 0.18)
        case (.flow, .sheetContent):
            return .easeOut(duration: 0.22)
        case (.capsule, .number):
            return GoMotion.feedback
        case (.capsule, .progress):
            return .interactiveSpring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.14)
        case (.capsule, .chart):
            return .interactiveSpring(response: 0.44, dampingFraction: 0.88, blendDuration: 0.16)
        case (.capsule, .switching):
            return GoMotion.selection
        case (.capsule, .sheetOpen):
            return GoMotion.sheetEnter
        case (.capsule, .sheetContent):
            return .interactiveSpring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.12)
        case (.signal, .number):
            return .interactiveSpring(response: 0.22, dampingFraction: 0.72, blendDuration: 0.08)
        case (.signal, .progress):
            return .interactiveSpring(response: 0.30, dampingFraction: 0.78, blendDuration: 0.12)
        case (.signal, .chart):
            return .interactiveSpring(response: 0.40, dampingFraction: 0.82, blendDuration: 0.16)
        case (.signal, .switching):
            return .interactiveSpring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.14)
        case (.signal, .sheetOpen):
            return .interactiveSpring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.16)
        case (.signal, .sheetContent):
            return .interactiveSpring(response: 0.30, dampingFraction: 0.82, blendDuration: 0.12)
        }
    }
}

enum MotionPreviewAccent: String, CaseIterable, Identifiable {
    case primary
    case blue
    case teal
    case purple
    case orange

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .primary: Color.goPrimary
        case .blue: Color.goBlue
        case .teal: Color.goTeal
        case .purple: Color.goPurple
        case .orange: Color.goOrange
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .primary: l.tr(zh: "主色", en: "Primary", de: "Primaer")
        case .blue: l.tr(zh: "蓝", en: "Blue", de: "Blau")
        case .teal: l.tr(zh: "青", en: "Teal", de: "Tuerkis")
        case .purple: l.tr(zh: "紫", en: "Purple", de: "Violett")
        case .orange: l.tr(zh: "橙", en: "Orange", de: "Orange")
        }
    }
}

struct MotionPreviewPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }
}

struct MotionScenarioPanel<Content: View>: View {
    let category: MotionPreviewCategory
    let system: MotionPreviewSystem
    let accent: Color
    let localization: L10n
    let action: () -> Void
    let content: Content

    init(
        category: MotionPreviewCategory,
        system: MotionPreviewSystem,
        accent: Color,
        localization: L10n,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.category = category
        self.system = system
        self.accent = accent
        self.localization = localization
        self.action = action
        self.content = content()
    }

    var body: some View {
        MotionPreviewPanel(title: category.title(localization), subtitle: system.spec(for: category, localization)) {
            VStack(alignment: .leading, spacing: 12) {
                content

                Button(action: action) {
                    Label(localization.tr(zh: "重新预览", en: "Replay", de: "Erneut zeigen"), systemImage: "arrow.clockwise")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

struct MotionPreviewChartLine: Shape {
    let points: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        var path = Path()
        let step = rect.width / CGFloat(points.count - 1)
        for index in points.indices {
            let x = CGFloat(index) * step
            let y = rect.height * (1 - points[index])
            if index == points.startIndex {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct MotionPreviewChartArea: Shape {
    let points: [CGFloat]

    func path(in rect: CGRect) -> Path {
        guard points.count > 1 else { return Path() }
        var path = MotionPreviewChartLine(points: points).path(in: rect)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct MotionPreviewChartDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let point: CGFloat
    let index: Int
    let count: Int
    let accent: Color
    let visible: Bool
    let system: MotionPreviewSystem

    var body: some View {
        GeometryReader { geo in
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                .position(
                    x: CGFloat(index) * geo.size.width / CGFloat(max(count - 1, 1)),
                    y: geo.size.height * (1 - point)
                )
                .scaleEffect(visible ? 1 : system.chartDotStartScale)
                .opacity(visible ? 1 : 0)
                .animation(system.animation(.chart, reduceMotion: reduceMotion).delay(system.chartDotStagger * Double(index)), value: visible)
        }
        .allowsHitTesting(false)
    }
}

struct MotionPreviewSheetShell: View {
    let system: MotionPreviewSystem
    let accent: Color
    let localization: L10n
    let contentVisible: Bool
    let onClose: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.ohanaSecondaryText.opacity(0.42))
                .frame(width: 44, height: 5)

            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                    .font(OhanaFont.adaptive(size: 22, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 46, height: 46)
                    .background(accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.tr(zh: "短 Sheet", en: "Short Sheet", de: "Kurzes Sheet"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(system.title(localization))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark") // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        .font(OhanaFont.adaptive(size: 12, weight: .black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .frame(width: 36, height: 36) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                        .contentShape(Circle())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(spacing: 8) {
                ForEach(MotionPreviewLoadingRow.fixtures.indices, id: \.self) { index in
                    MotionPreviewContentLoadingRow(
                        row: MotionPreviewLoadingRow.fixtures[index],
                        index: index,
                        visible: contentVisible,
                        accent: accent,
                        system: system,
                        localization: localization
                    )
                }
            }

            Button(action: onConfirm) {
                Text(localization.tr(zh: "确认 +12", en: "Confirm +12", de: "Bestaetigen +12"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(accent, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
                .strokeBorder(Color.ohanaGlassStroke, lineWidth: 1)
        }
        .shadow(color: Color.arkInk.opacity(0.18), radius: 24, x: 0, y: 14) // ui-v4: allow short sheet preview depth
    }
}

struct MotionPreviewContentLoadingRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let row: MotionPreviewLoadingRow
    let index: Int
    let visible: Bool
    let accent: Color
    let system: MotionPreviewSystem
    let localization: L10n

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: row.icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black))
                .foregroundStyle(visible ? Color.ohanaPrimaryActionText : accent)
                .frame(width: 30, height: 30) // a11y: allow decorative preview/art element; non-interactive or labeled by surrounding content.
                .background(visible ? accent : accent.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title.text(localization))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(row.subtitle.text(localization))
                    .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(row.value)
                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .frame(height: 48)
        .background(Color.ohanaControlFill.opacity(0.68), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : system.contentRowOffset)
        .scaleEffect(visible ? 1 : system.contentRowScale, anchor: .top)
        .animation(system.animation(.sheetContent, reduceMotion: reduceMotion).delay(system.contentStagger * Double(index)), value: visible)
    }
}

struct MotionPreviewContext {
    let name: String
    let tint: Color
    let items: [MotionPreviewLocalizedText]

    static let fixtures: [MotionPreviewContext] = [
        MotionPreviewContext(
            name: "Mochi",
            tint: Color.goPurple,
            items: [
                MotionPreviewLocalizedText(zh: "08:30 喂食", en: "08:30 Feed", de: "08:30 Fuettern"),
                MotionPreviewLocalizedText(zh: "13:00 遛弯", en: "13:00 Walk", de: "13:00 Spaziergang"),
                MotionPreviewLocalizedText(zh: "21:00 刷牙", en: "21:00 Teeth", de: "21:00 Zaehne")
            ]
        ),
        MotionPreviewContext(
            name: "lilo",
            tint: Color.goOrange,
            items: [
                MotionPreviewLocalizedText(zh: "09:00 换水", en: "09:00 Water", de: "09:00 Wasser"),
                MotionPreviewLocalizedText(zh: "16:30 梳毛", en: "16:30 Brush", de: "16:30 Buersten"),
                MotionPreviewLocalizedText(zh: "20:40 体重", en: "20:40 Weight", de: "20:40 Gewicht")
            ]
        ),
        MotionPreviewContext(
            name: "Lee",
            tint: Color.goTeal,
            items: [
                MotionPreviewLocalizedText(zh: "07:45 用药", en: "07:45 Meds", de: "07:45 Medizin"),
                MotionPreviewLocalizedText(zh: "12:15 喝水", en: "12:15 Water", de: "12:15 Wasser"),
                MotionPreviewLocalizedText(zh: "19:30 复盘", en: "19:30 Review", de: "19:30 Review")
            ]
        )
    ]
}

struct MotionPreviewLoadingRow {
    let icon: String
    let title: MotionPreviewLocalizedText
    let subtitle: MotionPreviewLocalizedText
    let value: String

    static let fixtures: [MotionPreviewLoadingRow] = [
        MotionPreviewLoadingRow(
            icon: "checkmark",
            title: MotionPreviewLocalizedText(zh: "打卡结果", en: "Check-in result", de: "Check-in Ergebnis"),
            subtitle: MotionPreviewLocalizedText(zh: "业务结果已经准备好", en: "Business result is already ready", de: "Ergebnis ist bereit"),
            value: "+12"
        ),
        MotionPreviewLoadingRow(
            icon: "chart.bar.fill",
            title: MotionPreviewLocalizedText(zh: "今日统计", en: "Today stats", de: "Heute Statistik"),
            subtitle: MotionPreviewLocalizedText(zh: "作为 snapshot 轻量呈现", en: "Rendered as a lightweight snapshot", de: "Als leichter Snapshot dargestellt"),
            value: "84%"
        ),
        MotionPreviewLoadingRow(
            icon: "bell.fill",
            title: MotionPreviewLocalizedText(zh: "提醒状态", en: "Reminder state", de: "Erinnerungsstatus"),
            subtitle: MotionPreviewLocalizedText(zh: "不在动画帧里重新同步", en: "No resync inside the animation frame", de: "Keine Resyncs im Animationsframe"),
            value: "3"
        )
    ]
}

struct MotionPreviewLocalizedText {
    let zh: String
    let en: String
    let de: String

    func text(_ l: L10n) -> String {
        l.tr(zh: zh, en: en, de: de)
    }
}

enum MotionPreviewChartFixtures {
    static let points: [[CGFloat]] = [
        [0.30, 0.44, 0.38, 0.58, 0.62, 0.74, 0.82],
        [0.48, 0.36, 0.54, 0.50, 0.68, 0.64, 0.88],
        [0.22, 0.34, 0.45, 0.42, 0.61, 0.76, 0.72]
    ]
}

#Preview {
    NavigationStack {
        MotionPreviewLabView()
    }
}

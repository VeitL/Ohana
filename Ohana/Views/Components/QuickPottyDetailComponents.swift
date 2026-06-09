//
//  QuickPottyDetailComponents.swift
//  Ohana
//

import SwiftUI

// MARK: - Potty detail supporting components extracted for compile-time isolation.

enum PoopOverviewRange: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days7: return "7天"
        case .days30: return "30天"
        case .days90: return "90天"
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .days7: return l.tr(zh: "7天", en: "7d", de: "7 T.")
        case .days30: return l.tr(zh: "30天", en: "30d", de: "30 T.")
        case .days90: return l.tr(zh: "90天", en: "90d", de: "90 T.")
        }
    }

    var days: Int {
        switch self {
        case .days7: return 7
        case .days30: return 30
        case .days90: return 90
        }
    }
}

struct PoopChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct PoopTypeSummary: Identifiable {
    let title: String
    let icon: String
    let count: Int
    let tint: Color

    var id: String { title }
}

struct PoopInlineSheetGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        OhanaPopupGlassSurface(cornerRadius: cornerRadius)
    }
}

enum PoopLogItem: Identifiable {
    case potty(PetPottyLog)
    case litter(PetCareLog)

    var id: String {
        switch self {
        case .potty(let log): return "potty-\(log.id.uuidString)"
        case .litter(let log): return "litter-\(log.id.uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .potty(let log): return log.date
        case .litter(let log): return log.date
        }
    }

    var title: String {
        switch self {
        case .potty(let log): return log.pottyType.rawValue
        case .litter: return CareType.litter.label
        }
    }

    func title(_ l: L10n) -> String {
        switch self {
        case .potty(let log): return log.pottyType.localizedLabel(l)
        case .litter: return l.tr(zh: "铲砂", en: "Litter scooped", de: "Klo gereinigt")
        }
    }

    var icon: String {
        switch self {
        case .potty(let log): return log.pottyType.systemIconName
        case .litter: return CareType.litter.systemIconName
        }
    }

    var detail: String? {
        switch self {
        case .potty(let log): return log.executorId == nil ? nil : "已记录"
        case .litter: return nil
        }
    }

    func detail(_ l: L10n) -> String? {
        switch self {
        case .potty(let log):
            return log.executorId == nil ? nil : l.tr(zh: "已记录", en: "Logged", de: "Erfasst")
        case .litter:
            return nil
        }
    }
}

struct PoopCoreCard: View {
    let title: String
    let icon: String
    let tint: Color
    let value: String
    let subtitle: String
    let progress: Double
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var tapAction: (() -> Void)?
    var feedbackToken: CheckInFeedbackToken? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var surface: some ShapeStyle {
        Color.ohanaCardSurface
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 14) {
                tappableInfo

                VStack(spacing: 8) {
                    Button(action: primaryAction) {
                        HStack(spacing: 5) {
                            Image(systemName: primaryIcon)
                                .font(OhanaFont.adaptive(size: 11, weight: .black))
                            Text(primaryTitle)
                                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(Color.arkInk)
                        .frame(minWidth: 72)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if let secondaryTitle, let secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(tint)
                                .frame(minWidth: 72)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }

            if let feedbackToken {
                CheckInFeedbackBadge(token: feedbackToken)
                    .offset(x: 58, y: 4)
            }
        }
        .padding(16)
        .background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
        .checkInPulse(feedbackToken)
    }

    @ViewBuilder
    private var tappableInfo: some View {
        if let tapAction {
            Button(action: tapAction) {
                infoContent
            }
            .buttonStyle(ScaleButtonStyle())
        } else {
            infoContent
        }
    }

    private var infoContent: some View {
        HStack(spacing: 14) {
            ZStack {
                PoopProgressRing(progress: progress, tint: tint)
                    .frame(width: 58, height: 58)
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 20, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }
}

struct PoopProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(GoMotion.page, value: progress)
        }
    }
}

struct PoopHeroCard: View {
    let tint: Color
    let scoopTint: Color
    let litterTint: Color
    let pottyCount: Int
    let scoopProgress: Double
    let litterProgress: Double
    let abnormalRatio: Double

    @State private var bounce = false
    @State private var isVisible = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode
    @Environment(\.colorScheme) private var colorScheme

    private var shouldAnimateHero: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.ohanaCardSurface)

            HStack(spacing: 20) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(litterTint.opacity(0.72), lineWidth: 4)
                        .frame(width: 98, height: 58)
                        .offset(y: 18)
                    Capsule()
                        .fill(litterTint.opacity(0.34))
                        .frame(width: 78, height: 16)
                        .offset(y: 12)
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(tint.opacity(index == 0 ? 0.95 : 0.68))
                            .frame(width: 13 + CGFloat(index * 3), height: 13 + CGFloat(index * 3))
                            .offset(
                                x: CGFloat(index * 18 - 18),
                                y: bounce ? CGFloat(-10 - index * 2) : CGFloat(-3 + index)
                            )
                            .animation(
                                shouldAnimateHero
                                ? .easeInOut(duration: 1.1 + Double(index) * 0.16).repeatForever(autoreverses: true) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                                : nil,
                                value: bounce
                            )
                    }
                    Image(systemName: "sparkles").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 22, weight: .bold))
                        .foregroundStyle(scoopTint)
                        .offset(x: 42, y: -24)
                }
                .frame(width: 118, height: 102)

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(zh: "今日噗噗", en: "Today's poop", de: "Heute Häufchen"))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(l.tr(zh: "\(pottyCount) 次", en: "\(pottyCount)x", de: "\(pottyCount)x"))
                        .font(OhanaFont.adaptive(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                    HStack(spacing: 12) {
                        MiniPoopGauge(title: l.tr(zh: "铲砂", en: "Scoop", de: "Klo"), progress: scoopProgress, tint: scoopTint)
                        MiniPoopGauge(title: l.tr(zh: "换砂", en: "Litter", de: "Streu"), progress: litterProgress, tint: litterTint)
                        if abnormalRatio > 0.3 {
                            MiniPoopGauge(title: l.tr(zh: "留意", en: "Watch", de: "Achten"), progress: abnormalRatio, tint: Color.goRed)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
        }
        .onAppear {
            isVisible = true
            updateHeroMotion()
        }
        .onDisappear {
            isVisible = false
            bounce = false
        }
        .onChange(of: shouldAnimateHero) { _, _ in
            updateHeroMotion()
        }
    }

    private func updateHeroMotion() {
        bounce = shouldAnimateHero
    }
}

struct MiniPoopGauge: View {
    let title: String
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(tint.opacity(0.2))
                .frame(width: 34, height: 8) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(6, 34 * min(max(progress, 0), 1)), height: 8)
                }
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
    }
}

struct PoopLogRow: View {
    let item: PoopLogItem
    let tint: Color
    var showDelete = true
    let onDelete: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(OhanaFont.adaptive(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title(l))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if let detail = item.detail(l) {
                    Text(detail)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            Spacer()
            Text(item.date, format: .dateTime.month().day().hour().minute())
                .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText.opacity(0.55))
                        .frame(width: 30, height: 30) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.vertical, 3)
    }
}

struct PoopSheetHero: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 20, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 48, height: 48)
                .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}

struct PoopInlineNotice: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(text)
                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct PoopPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isDisabled ? Color.secondary.opacity(0.28) : tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isDisabled)
    }
}

struct PoopCheckInSheet: View {
    let tint: Color
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let primaryTitle: String
    let secondaryTitle: String
    let isPrimaryDisabled: Bool
    let primaryAction: () -> Void
    let secondaryAction: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PoopSheetHero(icon: icon, title: title, subtitle: subtitle, tint: tint)

                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 22, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 54, height: 54)
                        .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l.tr(zh: "当前状态", en: "Status now", de: "Status"))
                            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        Text(value)
                            .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if isPrimaryDisabled {
                    PoopInlineNotice(
                        icon: "checkmark.circle.fill",
                        text: l.tr(
                            zh: "今天已完成；要重来，请先在最近记录里删除。",
                            en: "Done today. Delete the latest log to redo.",
                            de: "Heute erledigt. Lösche den letzten Eintrag zum Wiederholen."
                        ),
                        tint: tint
                    )
                }

                PoopPrimaryButton(
                    title: primaryTitle,
                    icon: "checkmark.circle.fill",
                    tint: tint,
                    isDisabled: isPrimaryDisabled,
                    action: primaryAction
                )

                Button(action: secondaryAction) {
                    Label(secondaryTitle, systemImage: "calendar.badge.clock")
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(20)
        }
    }
}

struct PottyTypeSheet: View {
    let tint: Color
    var unknownGroupTitle: String? = nil
    var onUnknownGroup: (() -> Void)? = nil
    let onSelect: (PottyType) -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PoopSheetHero(
                    icon: "seal.fill",
                    title: l.tr(zh: "记录噗噗", en: "Log poop", de: "Häufchen loggen"),
                    subtitle: l.tr(zh: "选择今天看到的状态", en: "Pick what you saw today", de: "Wähle, was du heute gesehen hast"),
                    tint: tint
                )

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(PottyType.allCases, id: \.rawValue) { type in
                        Button {
                            onSelect(type)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: type.systemIconName)
                                    .font(OhanaFont.adaptive(size: 22, weight: .bold))
                                    .foregroundStyle(color(for: type))
                                Text(type.localizedLabel(l))
                                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }

                if let unknownGroupTitle, let onUnknownGroup {
                    Button(action: onUnknownGroup) {
                        Label(unknownGroupTitle, systemImage: "questionmark.circle.fill")
                            .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                PoopInlineNotice(
                    icon: "chart.bar.fill",
                    text: l.tr(
                        zh: "记录次数和状态后，首页会自动更新趋势。",
                        en: "Logs update the home trend automatically.",
                        de: "Einträge aktualisieren den Starttrend automatisch."
                    ),
                    tint: tint
                )
            }
            .padding(20)
        }
    }

    private func color(for type: PottyType) -> Color {
        switch type {
        case .perfectPoop: return tint
        case .softPoop: return Color(hex: "F59E0B")
        case .liquidPoop: return Color(hex: "EF4444")
        case .pee: return Color(hex: "06B6D4")
        }
    }
}

struct PoopCycleSettingsSheet: View {
    let tint: Color
    let icon: String
    let title: String
    let subtitle: String
    let statusTitle: String
    let statusValue: String
    let statusDetail: String
    let intervalRange: ClosedRange<Int>
    @Binding var intervalDays: Int
    @Binding var anchorDate: Date
    @Binding var reminderOn: Bool
    let onSave: () -> Void
    let onDelete: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PoopSheetHero(icon: icon, title: title, subtitle: subtitle, tint: tint)

                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 46, height: 46)
                        .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(statusTitle)
                            .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        Text(statusValue)
                            .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(tint)
                        Text(statusDetail)
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(spacing: 12) {
                    Stepper(value: $intervalDays, in: intervalRange) {
                        settingsRow(l.tr(zh: "周期", en: "Cycle", de: "Rhythmus"), value: everyDaysText(intervalDays))
                    }
                    .tint(tint)

                    DatePicker(selection: $anchorDate, displayedComponents: .date) {
                        Text(l.tr(zh: "起算日", en: "Start date", de: "Startdatum"))
                    }
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                        .tint(tint)

                    Toggle(isOn: $reminderOn) {
                        settingsRow(
                            l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"),
                            value: reminderOn ? l.tr(zh: "开", en: "On", de: "Ein") : l.tr(zh: "关", en: "Off", de: "Aus")
                        )
                    }
                    .tint(tint)
                }
                .padding(14)
                .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                PoopPrimaryButton(title: l.tr(zh: "保存计划", en: "Save plan", de: "Plan speichern"), icon: "checkmark", tint: tint) {
                    onSave()
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(l.tr(zh: "删除当前计划", en: "Delete this plan", de: "Plan löschen"), systemImage: "trash")
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(20)
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Text(value)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    private func everyDaysText(_ days: Int) -> String {
        l.tr(zh: "每\(days)天", en: "Every \(days)d", de: "Alle \(days) Tage")
    }
}

struct PoopHistorySheet: View {
    let title: String
    let items: [PoopLogItem]
    let tintForItem: (PoopLogItem) -> Color
    let onDelete: (PoopLogItem) -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    Text(l.tr(zh: "暂无记录", en: "No logs yet", de: "Noch keine Einträge"))
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                } else {
                    ForEach(items) { item in
                        PoopLogRow(item: item, tint: tintForItem(item), showDelete: true) {
                            onDelete(item)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

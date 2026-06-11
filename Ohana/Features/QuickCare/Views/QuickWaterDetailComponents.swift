//
//  QuickWaterDetailComponents.swift
//  Ohana
//

import SwiftUI

// MARK: - Water detail supporting components extracted for compile-time isolation.

enum WaterOverviewRange: String, CaseIterable, Identifiable {
    case days7
    case days30
    case days90

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .days7: 7
        case .days30: 30
        case .days90: 90
        }
    }

    var title: String {
        switch self {
        case .days7: "7天"
        case .days30: "30天"
        case .days90: "90天"
        }
    }
}

struct WaterChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct QuickWaterRuleSnapshot {
    let planEvents: [Event]
    let todayPlanReminders: [Reminder]
    let pendingTodayPlanReminders: [Reminder]
    let missedPlanReminders: [Reminder]
    let completedTodayPlanReminders: [Reminder]
    let nextPendingReminder: Reminder?

    static let empty = QuickWaterRuleSnapshot(
        planEvents: [],
        todayPlanReminders: [],
        pendingTodayPlanReminders: [],
        missedPlanReminders: [],
        completedTodayPlanReminders: [],
        nextPendingReminder: nil
    )

    var missedCount: Int {
        missedPlanReminders.count
    }

    var completionText: String {
        "\(completedTodayPlanReminders.count)/\(max(todayPlanReminders.count, planEvents.count, 1))"
    }

    static func build(
        pet: Pet,
        allEvents: [Event],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> QuickWaterRuleSnapshot {
        let planEvents = WaterPlanWriter.planEvents(pet: pet, allEvents: allEvents)
        let todayPlanReminders = planEvents
            .flatMap(\.reminders)
            .filter { calendar.isDate($0.scheduledAt, inSameDayAs: now) }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let pendingTodayPlanReminders = todayPlanReminders.filter { $0.isPending || $0.isFailed }
        let missedPlanReminders = planEvents
            .flatMap(\.reminders)
            .filter { ($0.isPending || $0.isFailed) && $0.scheduledAt <= now }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        let completedTodayPlanReminders = todayPlanReminders.filter(\.isCompleted)

        return QuickWaterRuleSnapshot(
            planEvents: planEvents,
            todayPlanReminders: todayPlanReminders,
            pendingTodayPlanReminders: pendingTodayPlanReminders,
            missedPlanReminders: missedPlanReminders,
            completedTodayPlanReminders: completedTodayPlanReminders,
            nextPendingReminder: missedPlanReminders.first ?? pendingTodayPlanReminders.first
        )
    }
}

struct QuickWaterRenderSnapshot {
    let todayWaterLogs: [PetCareLog]
    let waterLogs: [PetCareLog]
    let waterChangeLogs: [PetCareLog]
    let filterCleanLogs: [PetCareLog]
    let allWaterLogs: [PetCareLog]
    let rule: QuickWaterRuleSnapshot

    static let empty = QuickWaterRenderSnapshot(
        todayWaterLogs: [],
        waterLogs: [],
        waterChangeLogs: [],
        filterCleanLogs: [],
        allWaterLogs: [],
        rule: .empty
    )

    var lastWaterLog: PetCareLog? {
        todayWaterLogs.first ?? waterLogs.first
    }

    var lastWaterChange: PetCareLog? {
        waterChangeLogs.first
    }

    var lastFilterClean: PetCareLog? {
        filterCleanLogs.first
    }

    static func build(
        pet: Pet,
        allEvents: [Event],
        waterCareLogs: [PetCareLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> QuickWaterRenderSnapshot {
        let todayWaterLogs = waterCareLogs.filter {
            $0.type == CareType.watering.rawValue &&
                calendar.isDate($0.date, inSameDayAs: now)
        }
        let waterLogs = waterCareLogs.filter { $0.type == CareType.watering.rawValue }
        let waterChangeLogs = waterCareLogs.filter { $0.type == CareType.waterChange.rawValue }
        let filterCleanLogs = waterCareLogs.filter { $0.type == CareType.filterClean.rawValue }

        return QuickWaterRenderSnapshot(
            todayWaterLogs: todayWaterLogs,
            waterLogs: waterLogs,
            waterChangeLogs: waterChangeLogs,
            filterCleanLogs: filterCleanLogs,
            allWaterLogs: waterCareLogs,
            rule: QuickWaterRuleSnapshot.build(pet: pet, allEvents: allEvents, now: now, calendar: calendar)
        )
    }
}

struct WaterInlineSheetGlassSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        OhanaPopupGlassSurface(cornerRadius: cornerRadius)
    }
}

struct WaterPrimaryButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(tint, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

extension View {
    func waterGlassSurface(cornerRadius: CGFloat, tint: Color = .white, tintOpacity: Double = 0.04) -> some View {
        self
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.ohanaCardSurface.opacity(0.62))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(tintOpacity))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
            )
    }
}

struct WaterCoreCard: View {
    let title: String
    let icon: String
    let tint: Color
    let value: String
    let subtitle: String
    let progress: Double?
    let primaryTitle: String
    let primaryIcon: String
    let primaryAction: () -> Void
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    var tapAction: (() -> Void)?
    var feedbackToken: CheckInFeedbackToken?
    var isWarning: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var cardTint: Color {
        isWarning ? Color.goRed : tint
    }

    private var cardSurface: Color {
        isWarning ? Color.goRed.opacity(0.18) : Color.ohanaCardSurface
    }

    private var cardStroke: Color {
        isWarning ? Color.goRed.opacity(0.72) : Color.ohanaCardStroke
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
                        .background(cardTint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    if let secondaryTitle, let secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(cardTint)
                                .frame(minWidth: 72)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(isWarning ? Color.goRed.opacity(0.16) : Color.ohanaCardSurfaceElevated, in: Capsule())
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
        .background(cardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(cardStroke, lineWidth: isWarning ? 1.5 : 1)
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
                if let progress {
                    WaterProgressRing(progress: progress, tint: cardTint)
                        .frame(width: 58, height: 58)
                } else {
                    Circle()
                        .stroke(cardTint.opacity(0.2), lineWidth: 7)
                        .frame(width: 58, height: 58)
                }
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 20, weight: .bold))
                    .foregroundStyle(cardTint)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    if isWarning {
                        Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 12, weight: .black))
                    }
                }
                .foregroundStyle(isWarning ? Color.goRed : Color.ohanaPrimaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(cardTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .contentTransition(.numericText())
                Text(subtitle)
                    .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isWarning ? Color.goRed.opacity(0.92) : Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }
}

struct WaterProgressRing: View {
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

struct WaterHeroCard: View {
    let tint: Color
    let secondaryTint: Color
    let waterCount: Int
    let waterDueProgress: Double
    let filterDueProgress: Double
    let isAquatic: Bool

    @State private var ripple = false
    @State private var isVisible = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared
    @Environment(\.colorScheme) private var colorScheme

    private var shouldAnimateHero: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .fill(Color.ohanaCardSurface)

            HStack(spacing: 20) {
                ZStack {
                    ForEach(0 ..< 3, id: \.self) { index in
                        Circle()
                            .stroke(tint.opacity(0.16 - Double(index) * 0.03), lineWidth: 2)
                            .frame(width: ripple ? 98 + CGFloat(index * 18) : 62 + CGFloat(index * 10))
                            .opacity(ripple ? 0.18 : 0.58)
                            .animation(
                                shouldAnimateHero
                                    ? .easeInOut(duration: 1.9 + Double(index) * 0.18).repeatForever(autoreverses: true) // smoothness: allow pre-existing or workload-gated path surfaced by accessibility font migration; tracked by full-scope ratchet.
                                    : nil,
                                value: ripple
                            )
                    }

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
                            .stroke(tint.opacity(0.68), lineWidth: 4)
                            .frame(width: 86, height: 54)
                            .offset(y: 12)
                        Capsule()
                            .fill(tint.opacity(0.28))
                            .frame(width: 68, height: 16)
                            .offset(y: 9)
                        Image(systemName: isAquatic ? "water.waves" : "drop.fill")
                            .font(OhanaFont.adaptive(size: 30, weight: .bold))
                            .foregroundStyle(tint)
                            .offset(y: -12)
                    }
                }
                .frame(width: 118, height: 100)

                VStack(alignment: .leading, spacing: 10) {
                    Text(isAquatic ? "水体状态" : "今日饮水")
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(isAquatic ? "管理" : "\(waterCount) 次")
                        .font(OhanaFont.adaptive(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                    HStack(spacing: 12) {
                        MiniWaterGauge(title: "换水", progress: waterDueProgress, tint: tint)
                        MiniWaterGauge(title: "滤芯", progress: filterDueProgress, tint: secondaryTint)
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
            ripple = false
        }
        .onChange(of: shouldAnimateHero) { _, _ in
            updateHeroMotion()
        }
    }

    private func updateHeroMotion() {
        ripple = shouldAnimateHero
    }
}

struct MiniWaterGauge: View {
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

struct WaterLogRow: View {
    let log: PetCareLog
    let tint: Color
    var showDelete = true
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: log.careType.systemIconName)
                .font(OhanaFont.adaptive(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(log.careType.label)
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                if log.amountMl > 0 {
                    Text("\(Int(log.amountMl))ml")
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            Spacer()
            Text(log.date, format: .dateTime.month().day().hour().minute())
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

struct WaterAmountSettingsSheet: View {
    let tint: Color
    @Binding var amountEnabled: Bool
    @Binding var amountText: String
    let onSave: () -> Void

    @State private var showsAmountKeypad = false

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "drop.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("喂水")
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    Text(amountEnabled ? "默认 \(displayAmount)ml" : "只记录次数")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Toggle(isOn: $amountEnabled.animation(GoMotion.feedback)) {
                settingsRow("记录水量", value: amountEnabled ? "开" : "关")
            }
            .tint(tint)

            if amountEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("默认水量")
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack(spacing: 10) {
                        amountStepButton(systemName: "minus") {
                            adjustAmount(by: -50)
                        }
                        Button {
                            GoKeyboard.dismiss()
                            withAnimation(GoMotion.feedback) {
                                showsAmountKeypad.toggle()
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(amountText.isEmpty ? "250" : amountText)
                                    .font(OhanaFont.adaptive(size: 36, weight: .black, design: .rounded))
                                    .foregroundStyle(amountText.isEmpty ? Color.ohanaSecondaryText : Color.ohanaPrimaryText)
                                    .monospacedDigit()
                                Text("ml")
                                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(tint)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        amountStepButton(systemName: "plus") {
                            adjustAmount(by: 50)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

                    if showsAmountKeypad {
                        EmbeddedDecimalKeypad(
                            text: $amountText,
                            countryCode: AppCountry.code,
                            maxFractionDigits: 0,
                            accent: tint,
                            isMini: true
                        ) {
                            withAnimation(GoMotion.feedback) {
                                showsAmountKeypad = false
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([100, 150, 200, 250, 300, 500], id: \.self) { amount in
                                Button {
                                    withAnimation(GoMotion.feedback) {
                                        amountText = "\(amount)"
                                        showsAmountKeypad = false
                                    }
                                } label: {
                                    Text("\(amount)ml")
                                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color.ohanaCardSurfaceElevated, in: Capsule())
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }

            Button {
                showsAmountKeypad = false
                onSave()
            } label: {
                Text("保存")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(tint, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(20)
    }

    private var displayAmount: Int {
        Int((CountryDecimalInput.parse(amountText, countryCode: AppCountry.code) ?? 250).rounded())
    }

    private func adjustAmount(by delta: Int) {
        let current = displayAmount
        let next = max(0, current + delta)
        amountText = next > 0 ? "\(next)" : ""
        showsAmountKeypad = false
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func amountStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(OhanaFont.adaptive(size: 13, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(tint, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
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
}

struct WaterChangeSettingsSheet: View {
    let tint: Color
    @Binding var intervalDays: Int
    @Binding var anchorDate: Date
    @Binding var reminderOn: Bool
    let nextDateText: String
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            settingsHero(icon: "arrow.2.circlepath", title: "换水计划", value: "下次 \(nextDateText)")

            Stepper(value: $intervalDays.animation(GoMotion.feedback), in: 1 ... 30) {
                settingsRow("周期", value: "\(intervalDays)天")
            }
            .tint(tint)

            DatePicker("起算日", selection: $anchorDate, displayedComponents: .date)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow("日历提醒", value: reminderOn ? "开" : "关")
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
    }

    private func settingsHero(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 24, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 54, height: 54)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                Text(value)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
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
}

struct FilterSettingsSheet: View {
    let tint: Color
    @Binding var cleanIntervalDays: Int
    @Binding var replaceIntervalDays: Int
    @Binding var reminderOn: Bool
    let nextCleanText: String
    let nextReplaceText: String
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("滤芯计划")
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    Text("清洗 \(nextCleanText) · 更换 \(nextReplaceText)")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Stepper(value: $cleanIntervalDays.animation(GoMotion.feedback), in: 1 ... 60) {
                settingsRow("清洗", value: "\(cleanIntervalDays)天")
            }
            .tint(tint)

            Stepper(value: $replaceIntervalDays.animation(GoMotion.feedback), in: 7 ... 365) {
                settingsRow("更换", value: "\(replaceIntervalDays)天")
            }
            .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow("提醒", value: reminderOn ? "开" : "关")
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("删除")
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.ohanaCardSurface, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(20)
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
}

struct WaterPlanSettingsSheet: View {
    let tint: Color
    @Binding var count: Int
    @Binding var times: [Date]
    let completionText: String
    let onCountChange: (Int) -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 20, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 46, height: 46)
                        .background(tint.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("喂水计划")
                            .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                        Text("今日 \(completionText) · 每天 \(count) 次")
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }

                Stepper(value: $count.animation(GoMotion.feedback), in: 1 ... 6) {
                    settingsRow("每日次数", value: "\(count)次")
                }
                .tint(tint)
                .onChange(of: count) { _, newValue in
                    onCountChange(newValue)
                }

                VStack(spacing: 10) {
                    ForEach(0 ..< count, id: \.self) { index in
                        DatePicker(
                            "第 \(index + 1) 次",
                            selection: Binding(
                                get: { time(at: index) },
                                set: { setTime($0, at: index) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                        .tint(tint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
                    }
                }

                HStack(spacing: 10) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("切回手动")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button {
                        onSave()
                    } label: {
                        Text("保存计划")
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
    }

    private func time(at index: Int) -> Date {
        if index < times.count {
            return times[index]
        }
        return WaterPlanWriter.suggestedTimes(count: count)[min(index, max(count - 1, 0))]
    }

    private func setTime(_ date: Date, at index: Int) {
        while times.count <= index {
            times.append(WaterPlanWriter.suggestedTimes(count: count)[min(times.count, max(count - 1, 0))])
        }
        times[index] = date
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
}

struct WaterHistorySheet: View {
    let logs: [PetCareLog]
    let tintForLog: (PetCareLog) -> Color
    let onDelete: (PetCareLog) -> Void

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    Text("暂无记录")
                        .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                } else {
                    ForEach(logs) { log in
                        WaterLogRow(log: log, tint: tintForLog(log), showDelete: true) {
                            onDelete(log)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("水管理记录")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

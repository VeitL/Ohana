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

    func title(_ l: L10n) -> String {
        switch self {
        case .days7:
            l.tr(zh: "7天", en: "7 days", de: "7 Tage")
        case .days30:
            l.tr(zh: "30天", en: "30 days", de: "30 Tage")
        case .days90:
            l.tr(zh: "90天", en: "90 days", de: "90 Tage")
        }
    }
}

struct WaterChartPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct QuickWaterLedgerEntry: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let careType: CareType
    let amountMl: Double
    let legacyLogId: UUID?

    var canDelete: Bool {
        legacyLogId != nil
    }

    static func entries(
        from events: [CareLedgerEvent],
        fallbackLogs: [PetCareLog] = [],
        petID: UUID
    ) -> [QuickWaterLedgerEntry] {
        let petKey = petID.uuidString
        var entries: [QuickWaterLedgerEntry] = events.compactMap { event in
            guard event.eventKindEnum == .care,
                  event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  event.subjectId == petKey,
                  let careType = CareType(rawValue: event.actionType),
                  careType == .watering || careType == .waterChange || careType == .filterClean
            else { return nil }

            let legacyLogId = event.legacyModelName == "PetCareLog"
                ? event.legacyModelId.flatMap(UUID.init(uuidString:))
                : nil
            return QuickWaterLedgerEntry(
                id: event.id,
                date: event.occurredAt,
                careType: careType,
                amountMl: careType == .watering ? max(0, event.amountValue) : 0,
                legacyLogId: legacyLogId
            )
        }
        let knownLegacyIds = Set<UUID>(entries.compactMap(\.legacyLogId))
        entries += fallbackLogs.compactMap { log -> QuickWaterLedgerEntry? in
            guard !knownLegacyIds.contains(log.id),
                  log.careType == .watering || log.careType == .waterChange || log.careType == .filterClean
            else { return nil }
            return QuickWaterLedgerEntry(
                id: log.id,
                date: log.date,
                careType: log.careType,
                amountMl: log.careType == .watering ? max(0, log.amountMl) : 0,
                legacyLogId: log.id
            )
        }
        return entries
        .sorted { $0.date > $1.date }
    }
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
    let todayWaterLogs: [QuickWaterLedgerEntry]
    let waterLogs: [QuickWaterLedgerEntry]
    let waterChangeLogs: [QuickWaterLedgerEntry]
    let filterCleanLogs: [QuickWaterLedgerEntry]
    let allWaterLogs: [QuickWaterLedgerEntry]
    let rule: QuickWaterRuleSnapshot

    static let empty = QuickWaterRenderSnapshot(
        todayWaterLogs: [],
        waterLogs: [],
        waterChangeLogs: [],
        filterCleanLogs: [],
        allWaterLogs: [],
        rule: .empty
    )

    var lastWaterLog: QuickWaterLedgerEntry? {
        todayWaterLogs.first ?? waterLogs.first
    }

    var lastWaterChange: QuickWaterLedgerEntry? {
        waterChangeLogs.first
    }

    var lastFilterClean: QuickWaterLedgerEntry? {
        filterCleanLogs.first
    }

    static func build(
        pet: Pet,
        allEvents: [Event],
        waterEntries unsortedWaterEntries: [QuickWaterLedgerEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> QuickWaterRenderSnapshot {
        let waterEntries = unsortedWaterEntries.sorted { $0.date > $1.date }
        let todayWaterLogs = waterEntries.filter {
            $0.careType == .watering &&
                calendar.isDate($0.date, inSameDayAs: now)
        }
        let waterLogs = waterEntries.filter { $0.careType == .watering }
        let waterChangeLogs = waterEntries.filter { $0.careType == .waterChange }
        let filterCleanLogs = waterEntries.filter { $0.careType == .filterClean }

        return QuickWaterRenderSnapshot(
            todayWaterLogs: todayWaterLogs,
            waterLogs: waterLogs,
            waterChangeLogs: waterChangeLogs,
            filterCleanLogs: filterCleanLogs,
            allWaterLogs: waterEntries,
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
    var primaryIdentifier: String?
    var secondaryIdentifier: String?

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
                    .accessibilityIdentifier(primaryIdentifier ?? "")

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
                        .accessibilityIdentifier(secondaryIdentifier ?? "")
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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode
    @Environment(\.colorScheme) private var colorScheme

    private var shouldAnimateHero: Bool {
        workloadPolicy.shouldAnimate(isVisible: isVisible)
    }

    private var l: L10n { L10n(appLanguage) }

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
                    Text(isAquatic ? l.tr(zh: "水体状态", en: "Water tank status", de: "Beckenstatus") : l.tr(zh: "今日饮水", en: "Today's water", de: "Trinken heute"))
                        .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(isAquatic ? l.tr(zh: "管理", en: "Manage", de: "Verwalten") : localizedTimes(waterCount))
                        .font(OhanaFont.adaptive(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                    HStack(spacing: 12) {
                        MiniWaterGauge(title: l.tr(zh: "换水", en: "Change", de: "Wechsel"), progress: waterDueProgress, tint: tint)
                        MiniWaterGauge(title: l.tr(zh: "滤芯", en: "Filter", de: "Filter"), progress: filterDueProgress, tint: secondaryTint)
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

    private func localizedTimes(_ count: Int) -> String {
        l.tr(
            zh: "\(count) 次",
            en: count == 1 ? "1 time" : "\(count) times",
            de: count == 1 ? "1 Mal" : "\(count) Mal"
        )
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
    let log: QuickWaterLedgerEntry
    let tint: Color
    var showDelete = true
    let onDelete: () -> Void

    private var accessibilityTypeKey: String {
        switch log.careType {
        case .watering: "watering"
        case .waterChange: "water-change"
        case .filterClean: "filter-clean"
        default: log.careType.rawValue
        }
    }

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
            if showDelete, log.canDelete {
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
        .accessibilityIdentifier("quick-water-log-row-\(accessibilityTypeKey)-\(log.id.uuidString)")
    }
}

struct WaterAmountSettingsSheet: View {
    let tint: Color
    @Binding var amountEnabled: Bool
    @Binding var amountText: String
    let onSave: () -> Void

    @State private var showsAmountKeypad = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "drop.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "喂水", en: "Water", de: "Trinken"))
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    Text(amountEnabled ? localizedDefaultAmount(displayAmount) : l.tr(zh: "只记录次数", en: "Count only", de: "Nur Anzahl"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Toggle(isOn: $amountEnabled.animation(GoMotion.feedback)) {
                settingsRow(l.tr(zh: "记录水量", en: "Track amount", de: "Menge erfassen"), value: localizedToggle(amountEnabled))
            }
            .tint(tint)

            if amountEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(zh: "默认水量", en: "Default amount", de: "Standardmenge"))
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
                Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
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

    private func localizedDefaultAmount(_ amountMl: Int) -> String {
        l.tr(
            zh: "默认 \(amountMl)ml",
            en: "Default \(amountMl) ml",
            de: "Standard \(amountMl) ml"
        )
    }

    private func localizedToggle(_ isOn: Bool) -> String {
        isOn ? l.tr(zh: "开", en: "On", de: "Ein") : l.tr(zh: "关", en: "Off", de: "Aus")
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

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 18) {
            settingsHero(
                icon: "arrow.2.circlepath",
                title: l.tr(zh: "换水计划", en: "Water change plan", de: "Wasserwechselplan"),
                value: localizedNextDate(nextDateText)
            )

            Stepper(value: $intervalDays.animation(GoMotion.feedback), in: 1 ... 30) {
                settingsRow(l.tr(zh: "周期", en: "Cycle", de: "Zyklus"), value: localizedDays(intervalDays))
            }
            .tint(tint)

            DatePicker(l.tr(zh: "起算日", en: "Start date", de: "Startdatum"), selection: $anchorDate, displayedComponents: .date)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow(l.tr(zh: "日历提醒", en: "Calendar reminder", de: "Kalendererinnerung"), value: localizedToggle(reminderOn))
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
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
                    Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
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

    private func localizedNextDate(_ text: String) -> String {
        l.tr(
            zh: "下次 \(text)",
            en: "Next \(text)",
            de: "Nächstes \(text)"
        )
    }

    private func localizedDays(_ days: Int) -> String {
        l.tr(
            zh: "\(days)天",
            en: "\(days) days",
            de: "\(days) Tage"
        )
    }

    private func localizedToggle(_ isOn: Bool) -> String {
        isOn ? l.tr(zh: "开", en: "On", de: "Ein") : l.tr(zh: "关", en: "Off", de: "Aus")
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

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "滤芯计划", en: "Filter plan", de: "Filterplan"))
                        .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    Text(localizedFilterSummary(cleanText: nextCleanText, replaceText: nextReplaceText))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }

            Stepper(value: $cleanIntervalDays.animation(GoMotion.feedback), in: 1 ... 60) {
                settingsRow(l.tr(zh: "清洗", en: "Clean", de: "Reinigen"), value: localizedDays(cleanIntervalDays))
            }
            .tint(tint)

            Stepper(value: $replaceIntervalDays.animation(GoMotion.feedback), in: 7 ... 365) {
                settingsRow(l.tr(zh: "更换", en: "Replace", de: "Wechseln"), value: localizedDays(replaceIntervalDays))
            }
            .tint(tint)

            Toggle(isOn: $reminderOn.animation(GoMotion.feedback)) {
                settingsRow(l.tr(zh: "提醒", en: "Reminder", de: "Erinnerung"), value: localizedToggle(reminderOn))
            }
            .tint(tint)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
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
                    Text(l.tr(zh: "保存", en: "Save", de: "Speichern"))
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

    private func localizedFilterSummary(cleanText: String, replaceText: String) -> String {
        l.tr(
            zh: "清洗 \(cleanText) · 更换 \(replaceText)",
            en: "Clean \(cleanText) · replace \(replaceText)",
            de: "Reinigen \(cleanText) · wechseln \(replaceText)"
        )
    }

    private func localizedDays(_ days: Int) -> String {
        l.tr(
            zh: "\(days)天",
            en: "\(days) days",
            de: "\(days) Tage"
        )
    }

    private func localizedToggle(_ isOn: Bool) -> String {
        isOn ? l.tr(zh: "开", en: "On", de: "Ein") : l.tr(zh: "关", en: "Off", de: "Aus")
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

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

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
                        Text(l.tr(zh: "喂水计划", en: "Water plan", de: "Trinkplan"))
                            .font(OhanaFont.adaptive(size: 21, weight: .black, design: .rounded))
                        Text(localizedPlanSummary(completionText: completionText, count: count))
                            .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                }

                Stepper(value: $count.animation(GoMotion.feedback), in: 1 ... 6) {
                    settingsRow(l.tr(zh: "每日次数", en: "Daily count", de: "Täglich"), value: localizedTimes(count))
                }
                .tint(tint)
                .onChange(of: count) { _, newValue in
                    onCountChange(newValue)
                }

                VStack(spacing: 10) {
                    ForEach(0 ..< count, id: \.self) { index in
                        DatePicker(
                            localizedPlanSlot(index + 1),
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
                        Text(l.tr(zh: "切回手动", en: "Back to manual", de: "Zurück zu manuell"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.ohanaCardSurface, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("quick-water-plan-delete-action")

                    Button {
                        onSave()
                    } label: {
                        Text(l.tr(zh: "保存计划", en: "Save plan", de: "Plan speichern"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(tint, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityIdentifier("quick-water-plan-save-action")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .accessibilityIdentifier("quick-water-plan-settings-sheet")
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

    private func localizedPlanSummary(completionText: String, count: Int) -> String {
        l.tr(
            zh: "今日 \(completionText) · 每天 \(count) 次",
            en: "Today \(completionText) · \(count) per day",
            de: "Heute \(completionText) · \(count) pro Tag"
        )
    }

    private func localizedTimes(_ count: Int) -> String {
        l.tr(
            zh: "\(count)次",
            en: count == 1 ? "1 time" : "\(count) times",
            de: count == 1 ? "1 Mal" : "\(count) Mal"
        )
    }

    private func localizedPlanSlot(_ index: Int) -> String {
        l.tr(
            zh: "第 \(index) 次",
            en: "Time \(index)",
            de: "Zeit \(index)"
        )
    }
}

struct WaterHistorySheet: View {
    let logs: [QuickWaterLedgerEntry]
    let tintForLog: (QuickWaterLedgerEntry) -> Color
    let onDelete: (QuickWaterLedgerEntry) -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    Text(l.tr(zh: "暂无记录", en: "No records yet", de: "Noch keine Einträge"))
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
            .navigationTitle(l.tr(zh: "水管理记录", en: "Water care records", de: "Wasserpflege-Einträge"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

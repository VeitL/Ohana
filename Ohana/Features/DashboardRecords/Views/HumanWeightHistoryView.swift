//
//  HumanWeightHistoryView.swift
//  Ohana
//
//  U13: 人类体重记录页
//  统一 chrome：隐私开关（leading）+ xmark 关闭（trailing）+ 底部 FAB

import SwiftUI
import SwiftData

struct HumanWeightHistoryView: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage(AppCountry.storageKey) private var appCountry = AppCountry.detectedCode
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var isInlineWeightComposerVisible = false
    @State private var showingWeightPopup = false
    @State private var newWeightText = ""
    @State private var newWeightDate = Date()
    @State private var includesWeightTime = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { human.isPrivate(.weight, viewedBy: activeHumanId) }
    private var l: L10n { L10n(appLanguage) }

    private var sortedLogs: [HumanWeightLog] {
        human.weightLogs.sorted { $0.date > $1.date }
    }
    private var chartLogs: [HumanWeightLog] {
        Array(human.weightLogs.sorted { $0.date < $1.date }.suffix(20))
    }

    private var parsedInlineWeight: Double? {
        CountryDecimalInput.parse(newWeightText, countryCode: appCountry)
    }

    private var canSaveInlineWeight: Bool {
        (parsedInlineWeight ?? 0) > 0
    }

    private var inlineWeightRecordDate: Date {
        let date = includesWeightTime ? newWeightDate : Calendar.current.startOfDay(for: newWeightDate)
        return min(date, Date())
    }

    private var inlineQuickWeights: [Double] {
        let latest = sortedLogs.first?.weight ?? 60
        return [latest - 1, latest, latest + 1]
            .filter { $0 > 0 }
            .map { (($0 * 10).rounded() / 10) }
    }

    var body: some View {
        ZStack {
            HumanWeightDashboardContent(
                human: human,
                onClose: { dismiss() },
                onAdd: {
                    withAnimation(GoMotion.feedback) {
                        showingWeightPopup = true
                    }
                }
            )

            if showingWeightPopup {
                GenericWeightEntrySheet(
                    target: .human(human),
                    onDismiss: {
                        withAnimation(GoMotion.feedback) {
                            showingWeightPopup = false
                        }
                    }
                )
                .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var privacyLockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 34, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goYellow)
            Text(l.tr(zh: "体重记录仅本人可见", en: "Weight is private", de: "Gewicht ist privat"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "当前家庭成员无权查看这些数据。", en: "This household member cannot view these records.", de: "Dieses Familienmitglied kann diese Daten nicht sehen."))
                .font(OhanaFont.callout())
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(24)
        .ohanaStandardCard(cornerRadius: 24)
        .padding(.horizontal, 24)
    }

    // MARK: - Chart
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(l.tr(zh: "体重趋势", en: "Weight trend", de: "Gewichtsverlauf"))
                        .font(OhanaFont.title2(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if let latest = sortedLogs.first {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", latest.weight))
                                .font(OhanaFont.metric(size: 44))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text("kg")
                                .font(OhanaFont.title3(.bold))
                                .foregroundStyle(Color.goTeal)
                        }
                    }
                }
                Spacer()
                Text("\(sortedLogs.count)")
                    .font(OhanaFont.metric(size: 26))
                    .foregroundStyle(Color.goPrimary)
                Text(l.tr(zh: "条", en: "logs", de: "Einträge"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 24).padding(.top, 16)

            HumanPrivateDataNotice(human: human, field: .weight)
                .padding(.horizontal, 24)
                .padding(.top, 2)

            if chartLogs.count >= 2 {
                let delta = chartLogs.last!.weight - chartLogs.first!.weight
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(OhanaFont.caption(.bold))
                    Text(String(format: "%+.1f kg", delta))
                        .font(OhanaFont.footnote(.bold))
                }
                .foregroundStyle(delta >= 0 ? Color.goYellow : Color.goTeal)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background((delta >= 0 ? Color.goYellow : Color.goTeal).opacity(0.12), in: Capsule())
                .padding(.horizontal, 24)
            }

            if chartLogs.count >= 2 {
                HumanWeightLineChart(logs: chartLogs)
                    .frame(height: 130)
                    .padding(.horizontal, 24).padding(.top, 8)
                if let f = chartLogs.first, let l = chartLogs.last {
                    HStack {
                        Text(f.date, format: .dateTime.month(.abbreviated).day())
                        Spacer()
                        Text(l.date, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(OhanaFont.caption2())
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.3))
                    .padding(.horizontal, 24)
                }
            } else {
                Text(l.tr(zh: "记录 2 条以上体重后可显示趋势图", en: "Add at least 2 weight logs to show a trend.", de: "Mindestens 2 Einträge zeigen einen Verlauf."))
                    .font(OhanaFont.subheadline())
                    .foregroundStyle(Color.ohanaTertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
            Spacer()
        }
    }

    // MARK: - Record List
    private var recordListLayer: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.ohanaDivider)
                    .frame(width: 40, height: 4) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .padding(.top, 12).padding(.bottom, 8)

                HStack {
                    Text(l.tr(zh: "历史记录", en: "History", de: "Verlauf"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(l.tr(zh: "\(sortedLogs.count) 条", en: "\(sortedLogs.count) logs", de: "\(sortedLogs.count) Einträge"))
                        .font(OhanaFont.footnote(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20).padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        if isInlineWeightComposerVisible {
                            inlineWeightComposer
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        ForEach(sortedLogs) { log in
                            weightRow(log: log)
                        }
                        if sortedLogs.isEmpty {
                            Text(l.tr(zh: "还没有体重记录\n点击下方按钮在这里记录", en: "No weight logs yet\nTap the button below to add one.", de: "Noch keine Gewichtseinträge\nTippe unten zum Hinzufügen."))
                                .font(OhanaFont.callout())
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 100)
                }
            }
        }
    }

    private var inlineWeightComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "添加体重", en: "Add weight", de: "Gewicht hinzufügen"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "记录面板已嵌入当前页面", en: "The recorder stays inside this page.", de: "Die Eingabe bleibt auf dieser Seite."))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    withAnimation(GoMotion.feedback) {
                        isInlineWeightComposerVisible = false
                    }
                } label: {
                    Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                }
                .buttonStyle(ScaleButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(newWeightText.isEmpty ? CountryDecimalInput.placeholder(fractionDigits: 1, countryCode: appCountry) : newWeightText)
                        .font(OhanaFont.metric(size: 36))
                        .foregroundStyle(newWeightText.isEmpty ? Color.ohanaSecondaryText.opacity(0.55) : Color.ohanaPrimaryText)
                        .contentTransition(.numericText())
                    Spacer()
                    Text("kg")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.goPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                EmbeddedDecimalKeypad(
                    text: $newWeightText,
                    countryCode: appCountry,
                    maxFractionDigits: 2,
                    accent: .goPrimary,
                    isMini: true,
                    showsSubmitButton: false
                )
            }

            HStack(spacing: 8) {
                ForEach(inlineQuickWeights, id: \.self) { weight in
                    Button {
                        withAnimation(GoMotion.feedback) {
                            newWeightText = CountryDecimalInput.format(weight, countryCode: appCountry, maxFractionDigits: 1)
                        }
                    } label: {
                        Text("\(CountryDecimalInput.format(weight, countryCode: appCountry, maxFractionDigits: 1)) kg")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.ohanaControlFill, in: Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 24)
                    Text(l.tr(zh: "日期", en: "Date", de: "Datum"))
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DatePicker("", selection: $newWeightDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(Color.goPrimary)
                    .labelsHidden()
            }
            .padding(12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 10) {
                Image(systemName: "clock") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.tr(zh: "时间", en: "Time", de: "Zeit"))
                        .font(OhanaFont.subheadline(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(zh: "可选", en: "Optional", de: "Optional"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                if includesWeightTime {
                    DatePicker("", selection: $newWeightDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                        .labelsHidden()
                }
                Toggle("", isOn: $includesWeightTime.animation(GoMotion.feedback))
                    .labelsHidden()
                    .tint(Color.goPrimary)
            }
            .padding(12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(action: saveInlineWeight) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill") // a11y: allow decorative icon covered by surrounding text or control
                    Text(l.tr(zh: "保存体重", en: "Save weight", de: "Gewicht sichern"))
                }
                .font(OhanaFont.body(.black))
                .foregroundStyle(Color.arkInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(canSaveInlineWeight ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
            }
            .disabled(!canSaveInlineWeight)
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurfaceElevated, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func weightRow(log: HumanWeightLog) -> some View {
        HStack(spacing: 14) {
            Circle().fill(Color.goPrimary).frame(width: 8, height: 8) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 2) {
                Text(log.date, format: .dateTime.year().month().day())
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(weightRowSubtitle(for: log.date))
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", log.weight))
                    .font(OhanaFont.metric(size: 20))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("kg")
                    .font(OhanaFont.footnote(.bold))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
            }
            Button {
                let command = DomainCommand.weightDelete(
                    entityID: human.id,
                    entityKind: EntityKind.human.rawValue,
                    recordID: log.id
                )
                commandQueue.enqueue(command) {
                    DashboardRecordCommandExecutor(context: modelContext, services: appServices).deleteHumanWeight(
                        log,
                        human: human,
                        note: "dashboard.weight.delete.\(EntityKind.human.rawValue)"
                    )
                }
            } label: {
                Image(systemName: "trash") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.subheadline())
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.5))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func saveInlineWeight() {
        guard let value = parsedInlineWeight, value > 0 else { return }
        let executorId = activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
        let savedDate = inlineWeightRecordDate
        let command = DomainCommand.weightEntry(entityID: human.id, entityKind: EntityKind.human.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(GoMotion.feedback) {
            newWeightText = ""
            newWeightDate = Date()
            includesWeightTime = false
            isInlineWeightComposerVisible = false
        }
        commandQueue.enqueue(command) {
            DashboardRecordCommandExecutor(context: modelContext, services: appServices).recordHumanWeight(
                human: human,
                weight: value,
                date: savedDate,
                executorId: executorId,
                command: command,
                note: "dashboard.weight.entry"
            )
        }
    }

    private func weightRowSubtitle(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let weekday = date.formatted(.dateTime.weekday(.wide).locale(AppLanguage.effectiveLocale))
        guard (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0 else {
            return weekday
        }
        return "\(weekday) · \(date.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - Line Chart
struct HumanWeightLineChart: View {
    let logs: [HumanWeightLog]

    private var points: [OhanaMinimalChartPoint] {
        logs
            .sorted { $0.date < $1.date }
            .map { OhanaMinimalChartPoint(date: $0.date, value: $0.weight, id: $0.id.uuidString) }
    }

    var body: some View {
        OhanaMinimalTrendChart(
            points: points,
            tint: .goPrimary,
            yReferenceLineCount: 3,
            yReferenceFormatter: { OhanaChartStyle.weightReferenceLabel(kilograms: $0, domain: $1) }
        )
    }
}

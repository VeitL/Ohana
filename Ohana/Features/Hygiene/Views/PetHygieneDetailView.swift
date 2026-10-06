//
//  PetHygieneDetailView.swift
//  Ohana
//
//  护理详情页 — 参考饮食管理页风格
//  深色背景 + ScrollView 卡片 + 极简月频条
//

import SwiftData
import SwiftUI

// MARK: - Chart Data Point for Hygiene
private struct HygieneChartPoint: Identifiable {
    var id: Date { day }
    let day: Date
    let count: Int
    let label: String
}

struct PetHygieneDetailContentView: View {
    let pet: Pet
    var showsCloseButton = true
    let allReminders: [Reminder]
    let hygieneEntries: [PetHygieneLedgerEntry]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var groomingPlanTarget: HygieneType? = nil
    @State private var pendingHygieneAction: PetHygieneActionHumanDraft?
    @State private var actionHumanOptions: [ActionHumanOption] = []
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    /// 用于匹配 `HygieneTodoSheet` 写入的 Event 标题前缀：`\(pet.name) — \(type.rawValue)`

    private var themeColor: Color {
        Color(hex: pet.safeThemeColorHex)
    }

    private var themeActionForeground: Color {
        OhanaResolvedPrimaryAccent(customHex: pet.safeThemeColorHex)?.actionTextColor ?? Color.ohanaPrimaryText
    }

    private var isDark: Bool { colorScheme == .dark }
    private var chromeAccent: Color { isDark ? Color.goPrimary : Color.goBlue }
    private var l: L10n { L10n(appLanguage) }
    private var currentLocalHumanID: UUID? {
        appServices.activeHumanSelection.currentHumanId.flatMap(UUID.init(uuidString:))
    }

    private func latestHygieneDate(_ type: HygieneType) -> Date? {
        hygieneEntries.first(where: { $0.type == type })?.date
    }

    private func cycleStatus(_ type: HygieneType, now: Date = Date()) -> CareCycleStatus? {
        type.cycleStatus(
            lastDate: latestHygieneDate(type),
            petId: pet.id,
            now: now,
            calendar: .current
        )
    }

    private func statusColor(_ status: CareCycleStatus?) -> Color {
        guard let status else { return themeColor.opacity(0.42) }
        switch status.duePhase {
        case .upcoming:
            return themeColor
        case .dueToday:
            return Color.goOrange
        case .overdue:
            return Color.goRed
        }
    }

    /// 与 `HygieneTodoSheet.save()` 写入的标题前缀一致（含备注时仍以此前缀开头）
    private func titlePrefix(for type: HygieneType) -> String {
        "\(pet.name) — \(type.rawValue)"
    }

    private func pendingHygienePlans(for type: HygieneType) -> [Reminder] {
        let pid = pet.id.uuidString
        let prefix = titlePrefix(for: type)
        return allReminders.filter { r in
            guard r.statusEnum == .pending,
                  let ev = r.event,
                  ev.eventType == EventType.grooming.rawValue,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToPet(ev, petId: pid) else { return false }
            return ev.title.hasPrefix(prefix)
        }
        .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func recurrenceLabel(_ days: Int) -> String {
        switch days {
        case 0:
            l.tr(zh: "不重复", en: "No repeat", de: "Keine Wiederholung")
        case 1:
            l.tr(zh: "每天", en: "Daily", de: "Täglich")
        case 2:
            l.tr(zh: "每 2 天", en: "Every 2 days", de: "Alle 2 Tage")
        case 3:
            l.tr(zh: "每 3 天", en: "Every 3 days", de: "Alle 3 Tage")
        case 7:
            l.tr(zh: "每周", en: "Weekly", de: "Wöchentlich")
        case 14:
            l.tr(zh: "每两周", en: "Every 2 weeks", de: "Alle 2 Wochen")
        case 30:
            l.tr(zh: "每月", en: "Monthly", de: "Monatlich")
        default:
            l.tr(zh: "每 \(days) 天", en: "Every \(days) days", de: "Alle \(days) Tage")
        }
    }

    /// 近 28 天极简条（左旧右新），仅看打卡频率
    private func monthStripPoints(_ type: HygieneType) -> [HygieneChartPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0 ..< 28).reversed().map { offset in
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            let count = hygieneEntries.count(where: {
                $0.type == type && cal.isDate($0.date, inSameDayAs: d)
            })
            return HygieneChartPoint(day: d, count: count, label: "")
        }
    }

    @ViewBuilder
    private func monthFrequencyStrip(_ type: HygieneType) -> some View {
        let pts = monthStripPoints(type)
        let maxH: CGFloat = 22
        VStack(alignment: .leading, spacing: 6) {
            Text(l.tr(zh: "近 28 天", en: "Last 28 days", de: "Letzte 28 Tage"))
                .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .default))
                .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 2) {
                ForEach(pts) { pt in
                    let h = min(maxH, 4 + CGFloat(min(pt.count, 4)) * 4)
                    RoundedRectangle(cornerRadius: OhanaRadius.hairline, style: .continuous)
                        .fill(themeColor.opacity(pt.count > 0 ? 0.72 : 0.12))
                        .frame(width: 5, height: h)
                }
            }
            .frame(height: maxH, alignment: .bottom)
        }
    }

    private var monthlyTotalCount: Int {
        let cal = Calendar.current
        let now = Date()
        return hygieneEntries.count(where: { cal.isDate($0.date, equalTo: now, toGranularity: .month) })
    }

    private var currentStrike: Int {
        let cal = Calendar.current
        var strike = 0
        var lastDateByType: [String: Date] = [:]

        for entry in hygieneEntries.sorted(by: { $0.date < $1.date }) {
            let type = entry.type
            if let lastDate = lastDateByType[type.rawValue] {
                let days = cal.dateComponents(
                    [.day],
                    from: cal.startOfDay(for: lastDate),
                    to: cal.startOfDay(for: entry.date)
                ).day ?? 0
                strike = days <= type.effectiveCycleDays(for: pet.id) ? strike + 1 : 1
            } else {
                strike += 1
            }
            lastDateByType[type.rawValue] = entry.date
        }
        return strike
    }

    private var attentionTypes: [HygieneType] {
        HygieneType.allCases.filter { type in
            cycleStatus(type)?.requiresAttention == true
        }
    }

    private var hasOverdueType: Bool {
        HygieneType.allCases.contains { type in
            cycleStatus(type)?.isOverdue == true
        }
    }

    private var completedTodayCount: Int {
        HygieneType.allCases.count(where: { isDoneToday($0) })
    }

    @State private var hygieneCycleRefresh = 0
    @State private var showSingleUseNotice = false
    @State private var singleUseNoticeMessage = ""

    var body: some View {
        ZStack {
            OhanaAppBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    hygieneHeader
                    // ── 5 项护理卡片（打卡 + 计划；顶部状态条已移除，与首页快捷护理重复）
                    ForEach(HygieneType.allCases, id: \.rawValue) { type in
                        hygieneTypeCard(type)
                    }
                    monthlySummaryCard
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .navigationTitle(l.tr(zh: "护理", en: "Care", de: "Pflege", es: "Cuidados", pt: "Cuidados", fr: "Soins", ja: "お手入れ", ko: "돌봄", it: "Cura"))
        .navigationBarTitleDisplayMode(.inline)
        .tint(themeColor)
        .navigationBarBackButtonHidden(true)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if showsCloseButton { OhanaModalToolbar(onClose: { dismiss() }, closeIdentifier: "pet-hygiene-detail-close-action") }
        }
        .accessibilityIdentifier("pet-hygiene-detail-screen")
        // 护理卡片「计划」按钮 → 待办 sheet
        .sheet(item: $groomingPlanTarget) { hygieneType in
            HygieneTodoSheet(pet: pet, type: hygieneType, accent: themeColor) {
                hygieneCycleRefresh += 1
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $pendingHygieneAction) { draft in
            PetHygieneActionHumanConfirmationSheet(
                draft: draft,
                humans: actionHumanOptions,
                tint: themeColor,
                tintForeground: themeActionForeground
            ) { executorID in
                commitHygiene(draft.type, executorID: executorID)
            }
            .presentationDetents([.medium])
        }
        .alert(l.tr(zh: "今天已经完成了", en: "Already done today", de: "Heute schon erledigt"), isPresented: $showSingleUseNotice) {
            Button(l.tr(zh: "知道了", en: "OK", de: "OK"), role: .cancel) {}
        } message: {
            Text(singleUseNoticeMessage)
        }
    }

    private var hygieneHeader: some View {
        FeatureHubHeader(
            title: pet.name,
            subtitle: "",
            eyebrow: "",
            onClose: { dismiss() },
            closeAccessibilityIdentifier: "pet-hygiene-detail-close-action",
            showsCloseButton: false,
            avatar: {
                PetAvatarPortraitView(
                    pet: pet,
                    fallbackText: pet.avatarEmoji,
                    themeColor: chromeAccent,
                    size: 46,
                    backgroundOpacity: isDark ? 0.18 : 0.12
                )
            }
        )
        .padding(.top, 4)
    }

    // MARK: - 本月概览
    private var monthlySummaryCard: some View {
        let totalTypes = max(HygieneType.allCases.count, 1)
        let progress = CGFloat(completedTodayCount) / CGFloat(totalTypes)
        let attentionTint = hasOverdueType ? Color.goRed : Color.goOrange
        let headline = hygieneEntries.isEmpty
            ? l.tr(
                zh: "还没有护理记录", en: "No care records yet", de: "Noch keine Pflegeeinträge",
                es: "Aún no hay registros de cuidados", pt: "Ainda não há registros de cuidados", fr: "Aucun soin enregistré",
                ja: "お世話の記録はまだありません", ko: "아직 돌봄 기록이 없어요", it: "Nessun registro di cura"
            )
            : (attentionTypes.isEmpty
                ? l.tr(zh: "今天的护理节奏很好", en: "Care rhythm looks good today", de: "Der Pflegerhythmus passt heute")
                : l.tr(zh: "\(attentionTypes.count) 项护理需要关注", en: "\(attentionTypes.count) care items need attention", de: "\(attentionTypes.count) Pflegepunkte brauchen Aufmerksamkeit"))

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(themeColor.opacity(0.16), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(themeColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(completedTodayCount)/\(totalTypes)")
                            .font(OhanaFont.adaptive(size: 17, weight: .semibold, design: .default))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "今日", en: "Today", de: "Heute"))
                            .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .default))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 100 : 66, height: dynamicTypeSize.isAccessibilitySize ? 100 : 66)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l.tr(zh: "今日", en: "Today", de: "Heute"))
                .accessibilityValue("\(completedTodayCount)/\(totalTypes)")

                VStack(alignment: .leading, spacing: 5) {
                    Text(headline)
                        .font(OhanaFont.adaptive(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    if hygieneEntries.isEmpty {
                        if !pet.hasPassedAway {
                            Text(l.tr(
                                zh: "选择下方项目记录护理，也可设置提醒。", en: "Choose a care item below to log it or set a reminder.", de: "Unten Pflege erfassen oder eine Erinnerung einrichten.",
                                es: "Elige un cuidado abajo para registrarlo o crear un recordatorio.", pt: "Escolha um cuidado abaixo para registrar ou criar um lembrete.", fr: "Choisissez un soin ci-dessous pour le noter ou créer un rappel.",
                                ja: "下の項目でお世話を記録したり、リマインダーを設定できます。", ko: "아래 항목에서 돌봄을 기록하거나 알림을 설정하세요.", it: "Scegli una cura qui sotto per registrarla o impostare un promemoria."
                            ))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                        }
                    } else if !attentionTypes.isEmpty {
                        Text(attentionTypes.map { $0.localizedLabel(l) }.joined(separator: l.tr(zh: "、", en: ", ", de: ", ")))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .default))
                            .foregroundStyle(attentionTint.opacity(0.9))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                overviewMetric(icon: "sparkle", value: "\(monthlyTotalCount)", label: l.tr(zh: "本月护理", en: "This month", de: "Dieser Monat"), tint: themeColor)
                overviewMetric(icon: "bolt.fill", value: "\(currentStrike)", label: l.tr(zh: "连续打卡", en: "Streak", de: "Serie"), tint: Color.goOrange)
                overviewMetric(icon: "clock", value: "\(attentionTypes.count)", label: l.tr(zh: "待护理", en: "Due", de: "Fällig"), tint: attentionTypes.isEmpty ? themeColor : attentionTint)
            }
        }
        .padding(.vertical, 6)
    }

    private func overviewMetric(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(label)
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 是否今天已完成
    private func isDoneToday(_ type: HygieneType) -> Bool {
        hygieneEntries.contains {
            $0.type == type && Calendar.current.isDateInToday($0.date)
        }
    }

    // MARK: - 护理类型卡片（重构）
    private func hygieneTypeCard(_ type: HygieneType) -> some View {
        _ = hygieneCycleRefresh
        let logs = hygieneEntries.filter { $0.type == type }.sorted { $0.date > $1.date }
        let status = cycleStatus(type)
        let color = statusColor(status)
        let stripHasData = monthStripPoints(type).contains { $0.count > 0 }
        let doneToday = isDoneToday(type)
        let plans = pendingHygienePlans(for: type)
        let accessibilityPrefix = "pet-hygiene-\(type.accessibilityIdentifierFragment)"

        return VStack(alignment: .leading, spacing: 10) {
            hygieneCardHeader(type, status: status, color: color, doneToday: doneToday, accessibilityPrefix: accessibilityPrefix)

            hygienePlansSection(plans)

            if stripHasData {
                monthFrequencyStrip(type)
            }

            // 周期标签 + 自定义按钮
            HStack(spacing: 6) {
                let effectiveDays = type.effectiveCycleDays(for: pet.id)
                let isCustom = HygieneType.customCycleDays(for: type, petId: pet.id) != nil
                Image(systemName: "repeat").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.6))
                Text(cycleSummary(days: effectiveDays, isCustom: isCustom))
                    .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .default))
                    .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                Spacer()
            }

            hygieneRecentLogsSection(logs, accessibilityPrefix: accessibilityPrefix)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        )
    }

    private func hygieneCardHeader(
        _ type: HygieneType,
        status: CareCycleStatus?,
        color: Color,
        doneToday: Bool,
        accessibilityPrefix: String
    ) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 6))
        return layout {
            HStack(spacing: 6) {
                Image(systemName: type.systemIconName)
                    .accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 14, weight: .semibold))
                    .foregroundStyle(themeColor)
                Text(type.localizedLabel(l))
                    .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer(minLength: 4)
                if let status {
                    Text(status.requiresAttention ? status.compactDueText(l: l) : status.compactLastRecordedText(l: l))
                        .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .default))
                        .foregroundStyle(status.elapsedDays == 0 ? themeColor : color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background((status.elapsedDays == 0 ? themeColor : color).opacity(0.14), in: Capsule())
                } else {
                    Text(l.tr(zh: "未记录", en: "No record", de: "Kein Eintrag"))
                        .font(OhanaFont.adaptive(size: 10, weight: .medium))
                        .foregroundStyle(themeColor.opacity(0.55))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(themeColor.opacity(0.1), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            hygieneCardActions(type, doneToday: doneToday, accessibilityPrefix: accessibilityPrefix)
        }
    }

    private func hygieneCardActions(_ type: HygieneType, doneToday: Bool, accessibilityPrefix: String) -> some View {
        HStack(spacing: 6) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                groomingPlanTarget = type
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "bell.badge.plus").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold))
                    Text(l.tr(
                        zh: "提醒", en: "Remind", de: "Erinnern",
                        es: "Avisar", pt: "Lembrar", fr: "Rappel",
                        ja: "リマインダー", ko: "알림", it: "Promemoria"
                    ))
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .default))
                }
                .foregroundStyle(themeColor)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .frame(minWidth: 44, minHeight: 44)
                .background(themeColor.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(themeColor.opacity(0.35), lineWidth: 0.5))
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(
                zh: "设置\(type.localizedLabel(l))提醒", en: "Set a reminder for \(type.localizedLabel(l))", de: "Erinnerung für \(type.localizedLabel(l)) einrichten",
                es: "Crear recordatorio para \(type.localizedLabel(l))", pt: "Criar lembrete para \(type.localizedLabel(l))", fr: "Créer un rappel pour \(type.localizedLabel(l))",
                ja: "\(type.localizedLabel(l))のリマインダーを設定", ko: "\(type.localizedLabel(l)) 알림 설정", it: "Imposta un promemoria per \(type.localizedLabel(l))"
            ))
            .accessibilityIdentifier("\(accessibilityPrefix)-plan-action")
            Button {
                requestHygieneRecord(type, doneToday: doneToday)
            } label: {
                if doneToday {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .bold))
                        .foregroundStyle(themeColor.opacity(0.55))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(themeColor.opacity(0.1), in: Capsule())
                } else {
                    Text(l.tr(zh: "打卡", en: "Log", de: "Erfassen"))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .default))
                        .foregroundStyle(themeActionForeground)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(themeColor, in: Capsule())
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(hygieneRecordActionLabel(type, doneToday: doneToday))
            .accessibilityIdentifier("\(accessibilityPrefix)-record-action")
        }
    }

    private func hygieneRecordActionLabel(_ type: HygieneType, doneToday: Bool) -> String {
        let name = type.localizedLabel(l)
        if doneToday {
            return l.tr(
                zh: "今天已记录\(name)", en: "\(name) logged today", de: "\(name) heute erfasst",
                es: "\(name) registrado hoy", pt: "\(name) registrado hoje", fr: "\(name) enregistré aujourd’hui",
                ja: "今日の\(name)は記録済み", ko: "오늘 \(name) 기록 완료", it: "\(name) registrato oggi"
            )
        }
        return l.tr(
            zh: "记录\(name)", en: "Log \(name)", de: "\(name) erfassen",
            es: "Registrar \(name)", pt: "Registrar \(name)", fr: "Enregistrer \(name)",
            ja: "\(name)を記録", ko: "\(name) 기록", it: "Registra \(name)"
        )
    }

    @ViewBuilder
    private func hygienePlansSection(_ plans: [Reminder]) -> some View {
        if !plans.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .bold))
                    Text(l.tr(zh: "已设计划", en: "Plans set", de: "Geplante Pflege"))
                        .font(OhanaFont.adaptive(size: 10, weight: .semibold, design: .default))
                }
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))

                ForEach(plans, id: \.id) { reminder in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "calendar").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                            .foregroundStyle(themeColor)
                            .frame(width: 16, alignment: .center)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.scheduledAt, format: .dateTime.month().day())
                                .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .default))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            if let event = reminder.event, event.recurrenceDays > 0 {
                                Text(l.tr(
                                    zh: "重复 · \(recurrenceLabel(event.recurrenceDays))",
                                    en: "Repeats · \(recurrenceLabel(event.recurrenceDays))",
                                    de: "Wiederholt · \(recurrenceLabel(event.recurrenceDays))"
                                ))
                                .font(OhanaFont.adaptive(size: 10, weight: .medium, design: .default))
                                .foregroundStyle(Color.ohanaSecondaryText)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeColor.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous)
                    .strokeBorder(themeColor.opacity(0.22), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func hygieneRecentLogsSection(
        _ logs: [PetHygieneLedgerEntry],
        accessibilityPrefix: String
    ) -> some View {
        if !logs.isEmpty {
            VStack(spacing: 0) {
                ForEach(logs.prefix(3)) { log in
                    HStack {
                        Text(log.date, format: .dateTime.month().day().hour().minute())
                            .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .default))
                            .foregroundStyle(Color.ohanaSecondaryText.opacity(0.7))
                        Spacer()
                        Button(role: .destructive) { deleteHygieneEntry(log) } label: {
                            Image(systemName: "trash").accessibilityHidden(true).font(OhanaFont.adaptive(size: 10))
                                .foregroundStyle(Color.goRed)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(l.tr(
                            zh: "删除\(log.type.localizedLabel(l))记录", en: "Delete \(log.type.localizedLabel(l)) record", de: "\(log.type.localizedLabel(l))-Eintrag löschen",
                            es: "Eliminar registro de \(log.type.localizedLabel(l))", pt: "Excluir registro de \(log.type.localizedLabel(l))", fr: "Supprimer le soin \(log.type.localizedLabel(l))",
                            ja: "\(log.type.localizedLabel(l))の記録を削除", ko: "\(log.type.localizedLabel(l)) 기록 삭제", it: "Elimina il registro di \(log.type.localizedLabel(l))"
                        ))
                        .accessibilityValue(log.date.formatted(
                            Date.FormatStyle(date: .abbreviated, time: .shortened)
                                .locale(AppLanguage.swiftUIPreferredLocale(for: appLanguage))
                        ))
                        .accessibilityIdentifier("\(accessibilityPrefix)-delete-\(log.id.uuidString)")
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("\(accessibilityPrefix)-recent-row-\(log.id.uuidString)")
                }
            }
            .padding(.top, 2)
        }
    }

    private func requestHygieneRecord(_ type: HygieneType, doneToday: Bool) {
        guard !doneToday else {
            singleUseNoticeMessage = l.tr(
                zh: "\(pet.name) 今天已记录\(type.localizedLabel(l))。",
                en: "\(type.localizedLabel(l)) is already logged for \(pet.name) today.",
                de: "\(type.localizedLabel(l)) ist heute bereits für \(pet.name) erfasst."
            )
            showSingleUseNotice = true
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        let options = ActionHumanOptionLoader.load(context: modelContext)
        actionHumanOptions = options
        let eligibleHumanCount = ActionHumanDefaultSelectionPolicy
            .eligibleHumans(from: options)
            .count
        let defaultHumanID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: currentLocalHumanID,
            humans: options
        )
        guard eligibleHumanCount > 1, defaultHumanID == nil else {
            commitHygiene(type, executorID: defaultHumanID)
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pendingHygieneAction = PetHygieneActionHumanDraft(
            type: type,
            initialExecutorID: defaultHumanID
        )
    }

    private func commitHygiene(_ type: HygieneType, executorID: UUID?) {
        let executorId = executorID?.uuidString
        let command = DomainCommand.petHygieneRecord(petID: pet.id, type: type.rawValue)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        commandQueue.enqueue(command) {
            PetHygieneCommandExecutor(context: modelContext, services: appServices).record(
                pet: pet,
                type: type,
                executorId: executorId,
                note: "pet.hygiene.detail.record"
            )
        }
    }

    private func deleteHygieneEntry(_ entry: PetHygieneLedgerEntry) {
        guard let logId = entry.legacyLogId else {
            OhanaLog.warning(
                "PetHygieneDetailView could not resolve hygiene log for ledger entry \(entry.id.uuidString)",
                category: "Care"
            )
            return
        }
        let command = DomainCommand.petHygieneDelete(petID: pet.id, recordID: logId)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            let executor = PetHygieneCommandExecutor(context: modelContext, services: appServices)
            guard let log = executor.hygieneLog(id: logId) else {
                OhanaLog.warning(
                    "PetHygieneDetailView could not resolve hygiene log \(logId.uuidString)",
                    category: "Care"
                )
                return
            }
            // recordDeletion: PetHygieneCommandService.delete marks CloudSync tombstones.
            executor.delete(
                log,
                pet: pet,
                note: "pet.hygiene.detail.delete"
            )
        }
    }

    private func cycleSummary(days: Int, isCustom: Bool) -> String {
        let base = l.tr(zh: "每\(days)天", en: "Every \(days) days", de: "Alle \(days) Tage")
        guard isCustom else { return base }
        return l.tr(zh: "\(base) · 已自定义", en: "\(base) · Custom", de: "\(base) · Eigene Einstellung")
    }
}

private extension HygieneType {
    var accessibilityIdentifierFragment: String {
        switch self {
        case .teeth: "teeth"
        case .nails: "nails"
        case .ears: "ears"
        case .brushing: "brushing"
        case .bath: "bath"
        }
    }
}

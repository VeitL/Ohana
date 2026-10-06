//
//  IslandExpenseDashboard.swift
//  Ohana
//
//  Global expense dashboard, aligned with the V4 "planet" dashboard language.
//

import SwiftData
import SwiftUI
import UIKit

private struct PetExpenseSummary: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let total: Double
    let color: Color
    let categories: [ExpenseCategoryBreakdown]
}

private struct PayerSummary: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let total: Double
    let color: Color
    let pct: Double
    let categories: [ExpenseCategoryBreakdown]
}

struct IslandExpenseDashboardContentView: View {
    var standalone: Bool = true
    let pets: [Pet]
    let humans: [Human]
    let snapshot: ExpenseInsightSnapshot
    let onFilterChange: (ExpenseDashboardRange, String?) -> Void
    var onRefresh: () -> Void = {}
    var isLoading = false
    var loadFailed = false

    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var selectedRange: ExpenseDashboardRange = .month
    @State private var selectedSubjectID: String?
    @State private var showingPersonalPlan = false
    @State private var preparedExpenseCSV = "date,subject,payer,category,amount,note"

    private var l: L10n { L10n(appLanguage) }
    private var allExpenseLogs: [ExpenseInsightLogSnapshot] { snapshot.logs }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var visibleExpenseHumans: [Human] {
        appServices.privacy.unlockedHumans(
            for: .expense,
            from: humans.filter { !$0.hasPassedAway },
            viewedBy: activeHumanId
        )
    }

    private var visiblePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    private var selectedHumanSubjectID: String? {
        guard let selectedSubjectID, selectedSubjectID.hasPrefix("human:") else { return nil }
        return UUID(uuidString: String(selectedSubjectID.dropFirst(6)))?.uuidString
    }

    private var subjectScopedLogs: [ExpenseInsightLogSnapshot] {
        guard let selectedSubjectID else { return allExpenseLogs }
        if selectedSubjectID.hasPrefix("pet:"),
           let id = UUID(uuidString: String(selectedSubjectID.dropFirst(4))) {
            return ExpenseSummaryBuilder.linkedToPet(id, from: allExpenseLogs)
        }
        if selectedSubjectID.hasPrefix("human:"),
           let id = UUID(uuidString: String(selectedSubjectID.dropFirst(6))) {
            return ExpenseSummaryBuilder.paidBy(id, from: allExpenseLogs)
        }
        return []
    }

    private var filteredLogs: [ExpenseInsightLogSnapshot] {
        ExpenseSummaryBuilder.logs(subjectScopedLogs, in: selectedRange)
    }

    private var visibleExpenseLogs: [ExpenseInsightLogSnapshot] {
        visibleLogs(from: filteredLogs)
    }

    private var summaryExpenseLogs: [ExpenseSummarySlice] {
        ExpenseSummaryBuilder.summarySlices(
            from: visibleExpenseLogs,
            attributedTo: selectedHumanSubjectID
        )
    }

    private var positiveExpenseLogs: [ExpenseSummarySlice] {
        ExpenseSummaryBuilder.positiveLogs(summaryExpenseLogs)
    }

    private var totals: ExpenseTotals {
        ExpenseSummaryBuilder.totals(from: summaryExpenseLogs)
    }

    private var totalAmount: Double {
        totals.spent
    }

    private var totalReimbursed: Double {
        totals.reimbursed
    }

    private var periodDelta: Double? {
        guard let currentStart = selectedRange.startDate() else { return nil }
        let now = Date()
        let span = now.timeIntervalSince(currentStart)
        guard span > 0 else { return nil }
        let previousStart = currentStart.addingTimeInterval(-span)
        let previousLogs = subjectScopedLogs.filter { $0.date >= previousStart && $0.date < currentStart }
        let previousSummary = ExpenseSummaryBuilder.summarySlices(
            from: visibleLogs(from: previousLogs),
            attributedTo: selectedHumanSubjectID
        )
        let previousTotal = ExpenseSummaryBuilder.totals(from: previousSummary).spent
        return totalAmount - previousTotal
    }

    private var categorySummaries: [ExpenseCategoryBreakdown] {
        ExpenseSummaryBuilder.categoryBreakdown(from: summaryExpenseLogs)
    }

    private var topCategory: ExpenseCategoryBreakdown? {
        categorySummaries.first
    }

    private var petSummaries: [PetExpenseSummary] {
        pets.compactMap { pet in
            let logs = ExpenseSummaryBuilder.linkedToPet(pet.id, from: summaryExpenseLogs)
            let total = ExpenseSummaryBuilder.totals(from: logs).spent
            guard total > 0 else { return nil }
            return PetExpenseSummary(
                id: pet.id,
                name: pet.name,
                emoji: pet.avatarEmoji,
                total: total,
                color: Color(hex: pet.safeThemeColorHex),
                categories: ExpenseSummaryBuilder.categoryBreakdown(from: logs)
            )
        }
        .sorted { $0.total > $1.total }
    }

    private var topPet: PetExpenseSummary? {
        petSummaries.first
    }

    private var humanSummaries: [PayerSummary] {
        let total = max(1, totalAmount)
        var totals: [String: Double] = [:]
        var logsByKey: [String: [ExpenseSummarySlice]] = [:]
        let payerSlices = ExpenseSummaryBuilder.payerContributionSlices(
            from: visibleExpenseLogs,
            attributedTo: selectedHumanSubjectID
        )
        for slice in payerSlices where slice.amount > 0 {
            let key = payerKey(for: slice.executorId)
            totals[key, default: 0] += slice.amount
            logsByKey[key, default: []].append(slice)
        }

        return totals.compactMap { key, value in
            if key == "__unknown__" {
                return PayerSummary(
                    id: key,
                    name: l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugeordnet"),
                    emoji: "❓",
                    total: value,
                    color: Color.ohanaSecondaryText,
                    pct: value / total,
                    categories: ExpenseSummaryBuilder.categoryBreakdown(from: logsByKey[key] ?? [])
                )
            }

            guard let human = visibleExpenseHumans.first(where: {
                ExpenseSummaryBuilder.payerIDsMatch($0.id.uuidString, key)
            }) else {
                return nil
            }
            return PayerSummary(
                id: key,
                name: human.name,
                emoji: human.avatarEmoji,
                total: value,
                color: humanThemeColor(human),
                pct: value / total,
                categories: ExpenseSummaryBuilder.categoryBreakdown(from: logsByKey[key] ?? [])
            )
        }
        .sorted { $0.total > $1.total }
    }

    private var topPayer: PayerSummary? {
        humanSummaries.first
    }

    private var trendBuckets: [ExpenseTimeBucket] {
        makeExpenseBuckets(from: positiveExpenseLogs, range: selectedRange)
    }

    var body: some View {
        dashboardBody
            .accessibilityIdentifier("household-expense-insight-screen")
            .sheet(isPresented: $showingPersonalPlan) {
                PersonalPlanView()
                    .ohanaSheetPagePresentation()
            }
            .onChange(of: appServices.commerce.hasPersonalEntitlement) { _, _ in
                if selectedRange.requiresPersonal, !appServices.commerce.allows(.extendedTrends) {
                    selectedRange = .month
                    onFilterChange(.month, selectedSubjectID)
                }
                reconcileComparisonAccess()
            }
            .onAppear {
                reconcileComparisonAccess()
                prepareExpenseExport()
            }
            .onChange(of: pets.count) { _, _ in reconcileComparisonAccess() }
            .onChange(of: visibleExpenseHumans.map(\.id)) { _, _ in
                reconcileComparisonAccess()
                prepareExpenseExport()
            }
            .onChange(of: selectedRange) { prepareExpenseExport() }
            .onChange(of: selectedSubjectID) { prepareExpenseExport() }
            .onChange(of: appLanguage) { prepareExpenseExport() }
            .onChange(of: snapshot.revisionID) { prepareExpenseExport() }
            .onReceive(appServices.domainRevisions.homeRevisionUpdates) { _ in
                prepareExpenseExport()
            }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            NavigationStack {
                scrollContent
                    .background(OhanaAppBackground())
                    .navigationTitle(l.tr(zh: "花费", en: "Expenses", de: "Ausgaben", es: "Gastos", pt: "Despesas", fr: "Dépenses", ja: "支出", ko: "지출", it: "Spese"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        OhanaModalToolbar(onClose: { dismiss() })
                    }
            }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: OhanaSpacing.section) {
                analysisLimitNotice
                subjectSelector
                if snapshot.hasLoaded, !visibleExpenseLogs.isEmpty {
                    expensePlanetHero
                }
                expenseTrendCard
                if appServices.commerce.allows(.extendedTrends), !visibleExpenseLogs.isEmpty {
                    humanSpendSection
                    petSpendSection
                    expenseExportButton
                }
                if totalReimbursed > 0 {
                    reimbursementStrip
                }
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, OhanaSpacing.pageMargin)
            .padding(.top, standalone ? 0 : 14)
        }
    }

    private func reconcileComparisonAccess() {
        let validIDs = Set(
            visiblePets.map { "pet:\($0.id.uuidString)" }
                + visibleExpenseHumans.map { "human:\($0.id.uuidString)" }
        )
        if let selectedSubjectID, !validIDs.contains(selectedSubjectID) {
            self.selectedSubjectID = nil
            onFilterChange(selectedRange, nil)
        }
        guard !appServices.commerce.allows(.extendedTrends), selectedSubjectID == nil else { return }
        selectedSubjectID = visiblePets.first.map { "pet:\($0.id.uuidString)" }
            ?? visibleExpenseHumans.first.map { "human:\($0.id.uuidString)" }
        onFilterChange(selectedRange, selectedSubjectID)
    }

    @ViewBuilder
    private var analysisLimitNotice: some View {
        if snapshot.isTruncated {
            Label(
                l.tr(
                    zh: "图表显示最近 20,000 条；原始记录仍完整保留。",
                    en: "Charts show the latest 20,000 records; raw records remain intact.",
                    de: "Diagramme zeigen die neuesten 20.000 Einträge; Rohdaten bleiben vollständig erhalten."
                ),
                systemImage: "info.circle.fill"
            )
            .font(OhanaFont.footnote(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge))
            .accessibilityIdentifier("expense-analysis-truncated-notice")
        }
    }

    private var expenseExportButton: some View {
        ShareLink(item: preparedExpenseCSV) {
            Label(
                l.tr(zh: "导出当前花费数据", en: "Export current expense data", de: "Aktuelle Ausgaben exportieren"),
                systemImage: "square.and.arrow.up"
            )
            .font(OhanaFont.callout(.semibold))
            .foregroundStyle(Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.ohanaControlFill, in: Capsule())
        }
        .accessibilityIdentifier("expense-insight-export")
    }

    private func prepareExpenseExport() {
        var lines = ["date,subject,payer,category,amount,note"]
        lines.append(contentsOf: visibleExpenseLogs.map { log in
            let subject = log.expensePetID.flatMap { petID in
                pets.first(where: { $0.id == petID })?.name
            }
                ?? l.tr(zh: "家庭", en: "Household", de: "Haushalt")
            let export = exportPayerProjection(for: log)
            return [
                HouseholdInsightExport.csvCell(HouseholdInsightExport.iso8601(log.date)),
                HouseholdInsightExport.csvCell(subject),
                HouseholdInsightExport.csvCell(export.payer),
                HouseholdInsightExport.csvCell(l.expenseCategoryTitle(log.expenseCategory)),
                HouseholdInsightExport.decimal(export.amount, fractionDigits: 2),
                HouseholdInsightExport.csvCell(log.note)
            ].joined(separator: ",")
        })
        preparedExpenseCSV = lines.joined(separator: "\n")
    }

    private func exportPayerProjection(
        for log: ExpenseInsightLogSnapshot
    ) -> (payer: String, amount: Double) {
        if let selectedHumanSubjectID {
            let payer = visibleExpenseHumans.first {
                ExpenseSummaryBuilder.payerIDsMatch($0.id.uuidString, selectedHumanSubjectID)
            }?.name ?? l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugeordnet")
            return (
                payer,
                ExpenseSummaryBuilder.amountPaid(by: selectedHumanSubjectID, for: log)
            )
        }

        let payerText = ExpenseSummaryBuilder.payerShares(for: log).map { share in
            let name = share.humanID.flatMap { humanID in
                visibleExpenseHumans.first {
                    ExpenseSummaryBuilder.payerIDsMatch($0.id.uuidString, humanID)
                }?.name
            } ?? l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugeordnet")
            return "\(name) \(AppCurrency.format(share.amount, fractionDigits: 2))"
        }.joined(separator: " · ")
        return (
            payerText.isEmpty ? l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugeordnet") : payerText,
            log.amount
        )
    }

    private var selectedSubjectName: String {
        visiblePets.first(where: { selectedSubjectID == "pet:\($0.id.uuidString)" })?.name
            ?? visibleExpenseHumans.first(where: { selectedSubjectID == "human:\($0.id.uuidString)" })?.name
            ?? l.tr(zh: "全部成员", en: "All members", de: "Alle Mitglieder", es: "Todos los miembros", pt: "Todos os membros", fr: "Tous les membres", ja: "すべてのメンバー", ko: "모든 멤버", it: "Tutti i membri")
    }

    private var subjectSelector: some View {
        Menu {
            subjectOption(id: nil, title: l.tr(zh: "全部", en: "All", de: "Alle", es: "Todos", pt: "Todos", fr: "Tous", ja: "すべて", ko: "전체", it: "Tutti"), isLocked: !appServices.commerce.allows(.extendedTrends))
            ForEach(visiblePets) { pet in
                subjectOption(id: "pet:\(pet.id.uuidString)", title: pet.name)
            }
            ForEach(visibleExpenseHumans) { human in
                subjectOption(id: "human:\(human.id.uuidString)", title: human.name)
            }
        } label: {
            HStack(spacing: OhanaSpacing.related) {
                Text(selectedSubjectName)
                    .font(OhanaFont.headline())
                    .lineLimit(2)
                Image(systemName: "chevron.down")
                    .font(OhanaFont.caption())
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityIdentifier("expense-subject-selector")
    }

    private func subjectOption(id: String?, title: String, isLocked: Bool = false) -> some View {
        Button {
            guard !isLocked else {
                showingPersonalPlan = true
                return
            }
            guard selectedSubjectID != id else { return }
            selectedSubjectID = id
            onFilterChange(selectedRange, id)
            OhanaFeedback.selection()
        } label: {
            Label(title, systemImage: isLocked ? "lock.fill" : (selectedSubjectID == id ? "checkmark" : "person"))
        }
    }

    private var expensePlanetHero: some View {
        VStack(alignment: .leading, spacing: OhanaSpacing.related) {
            Text(l.tr(zh: "本期花费", en: "Spent", de: "Ausgaben"))
                .font(OhanaFont.subheadline())
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(AppCurrency.format(totalAmount, fractionDigits: 0))
                .font(OhanaFont.metric(size: 34))
                .foregroundStyle(Color.ohanaPrimaryText)
                .ohanaNumericMotion(totalAmount)
                .fixedSize(horizontal: false, vertical: true)
            if let periodDelta { trendDeltaPill(periodDelta) }
        }
    }

    private var expenseTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(l.tr(zh: "花费节奏", en: "Spend rhythm", de: "Ausgabenrhythmus"), systemImage: "chart.bar.xaxis")
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(
                    ranges: ExpenseDashboardRange.allCases,
                    selection: personalRangeSelection,
                    isLocked: { $0.requiresPersonal && !appServices.commerce.allows(.extendedTrends) }
                ) {
                    $0.title(l)
                }
            }

            if loadFailed {
                OhanaFeedbackState(
                    state: .error,
                    title: l.recordsLoadFailed,
                    message: l.recordsRetryMessage,
                    actionLabel: l.retryRecords,
                    action: onRefresh,
                    layout: .compact
                )
            } else if isLoading || !snapshot.hasLoaded {
                OhanaFeedbackState(
                    state: .loading,
                    title: l.tr(zh: "正在读取记录", en: "Loading records", de: "Einträge werden geladen", es: "Cargando registros", pt: "Carregando registros", fr: "Chargement des données", ja: "記録を読み込み中", ko: "기록을 불러오는 중", it: "Caricamento dei dati"),
                    message: "",
                    layout: .compact
                )
            } else if visibleExpenseLogs.isEmpty {
                emptyState(
                    icon: "creditcard",
                    text: l.noRecords
                )
            } else {
                ExpenseBarDashboardChart(buckets: trendBuckets, accent: .goPrimary)
                    .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var personalRangeSelection: Binding<ExpenseDashboardRange> {
        Binding(
            get: { selectedRange },
            set: { range in
                guard !range.requiresPersonal || appServices.commerce.allows(.extendedTrends) else {
                    showingPersonalPlan = true
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    return
                }
                selectedRange = range
                onFilterChange(range, selectedSubjectID)
            }
        )
    }

    private var expenseBadgeStrip: some View {
        HStack(spacing: 10) {
            statBadge(
                title: l.tr(zh: "成员", en: "Members", de: "Mitglieder"),
                value: "\(humanSummaries.count)",
                icon: "person.2.fill",
                tint: Color.goPrimary
            )
            statBadge(
                title: l.tr(zh: "宠物", en: "Pets", de: "Tiere"),
                value: "\(petSummaries.count)",
                icon: "pawprint.fill",
                tint: Color(hex: "8B5CF6")
            )
            statBadge(
                title: l.tr(zh: "报销", en: "Refund", de: "Erstattung"),
                value: totalReimbursed > 0 ? AppCurrency.format(totalReimbursed, fractionDigits: 0) : "0",
                icon: "arrow.uturn.backward.circle.fill",
                tint: Color(hex: "06B6D4")
            )
        }
    }

    private var humanSpendSection: some View {
        dashboardSection(
            title: l.tr(zh: "成员花费", en: "Member spending", de: "Mitgliederausgaben"),
            icon: "person.2.fill"
        ) {
            if humanSummaries.isEmpty {
                emptyState(
                    icon: "person.crop.circle.badge.questionmark",
                    text: l.tr(zh: "暂无支付人数据", en: "No payer data", de: "Keine Zahlungsdaten")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(humanSummaries) { summary in
                        spendRow(
                            avatar: summary.emoji,
                            name: summary.name,
                            amount: summary.total,
                            tint: summary.color,
                            categories: summary.categories,
                            detailPrefix: l.tr(zh: "花到", en: "For", de: "Für")
                        )
                    }
                }
            }
        }
    }

    private var petSpendSection: some View {
        dashboardSection(
            title: l.tr(zh: "宠物花费", en: "Pet spending", de: "Tierausgaben"),
            icon: "pawprint.fill"
        ) {
            if petSummaries.isEmpty {
                emptyState(
                    icon: "pawprint",
                    text: l.tr(zh: "暂无宠物花费", en: "No pet expenses", de: "Keine Tierausgaben")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(petSummaries) { summary in
                        spendRow(
                            avatar: summary.emoji,
                            name: summary.name,
                            amount: summary.total,
                            tint: summary.color,
                            categories: summary.categories,
                            detailPrefix: l.tr(zh: "用于", en: "Used for", de: "Verwendet für")
                        )
                    }
                }
            }
        }
    }

    private var reimbursementStrip: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.uturn.backward.circle.fill").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "06B6D4"))
            Text(l.tr(zh: "已记录报销", en: "Refunds logged", de: "Erstattungen erfasst"))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
            Text(AppCurrency.format(totalReimbursed, fractionDigits: 0))
                .font(OhanaFont.subheadline(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .padding(.horizontal, 4)
    }

    private func dashboardSection(
        title: String,
        icon: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(OhanaFont.subheadline(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
            content()
        }
    }

    private func spendRow(
        avatar: String,
        name: String,
        amount: Double,
        tint: Color,
        categories: [ExpenseCategoryBreakdown],
        detailPrefix: String
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text(avatar)
                    .font(OhanaFont.adaptive(size: 24))
                    .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(tint.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(OhanaFont.body(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(categorySummaryText(categories, prefix: detailPrefix))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text(AppCurrency.format(amount, fractionDigits: 0))
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion(amount)
            }

            if !categories.isEmpty {
                categoryStackedBar(categories)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ohanaTertiaryText.opacity(0.18))
                .frame(height: 1)
        }
    }

    private func categoryStackedBar(_ categories: [ExpenseCategoryBreakdown]) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(categories.prefix(5)) { item in
                    RoundedRectangle(cornerRadius: OhanaRadius.micro, style: .continuous)
                        .fill(expenseTint(item.category))
                        .frame(width: max(6, proxy.size.width * item.pct))
                }
            }
        }
        .frame(height: 7)
    }

    private func trendDeltaPill(_ delta: Double) -> some View {
        let isUp = delta > 0
        let tint = isUp ? Color.goRed : Color.goTeal
        return HStack(spacing: 4) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(OhanaFont.adaptive(size: 9, weight: .semibold))
            Text(AppCurrency.format(abs(delta), fractionDigits: 0))
                .ohanaNumericMotion(delta)
        }
        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .default))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private func miniMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaTertiaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statBadge(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion(value)
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .semibold, design: .default))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyState(icon: String, text: String) -> some View {
        OhanaFeedbackState(state: .empty, title: text, message: "", layout: .compact)
    }

    private func visibleLogs(
        from logs: [ExpenseInsightLogSnapshot]
    ) -> [ExpenseInsightLogSnapshot] {
        logs.filter { log in
            ExpenseSummaryBuilder.payerShares(for: log)
                .compactMap(\.humanID)
                .allSatisfy { payerID in
                    !appServices.privacy.isLocked(
                        .expense,
                        humanId: payerID,
                        in: humans,
                        viewedBy: activeHumanId
                    )
                }
        }
    }

    private func payerKey(for executorId: String?) -> String {
        guard let raw = executorId, !raw.isEmpty else { return "__unknown__" }
        guard let human = visibleExpenseHumans.first(where: {
            ExpenseSummaryBuilder.payerIDsMatch($0.id.uuidString, raw)
        }) else { return "__unknown__" }
        return human.id.uuidString
    }

    private func humanThemeColor(_ human: Human) -> Color {
        human.themeColor.count == 6 ? Color(hex: human.themeColor) : Color.goPrimary
    }

    private func categorySummaryText(_ categories: [ExpenseCategoryBreakdown], prefix: String) -> String {
        guard !categories.isEmpty else {
            return l.tr(zh: "暂无分类", en: "No category", de: "Keine Kategorie")
        }
        let names = categories.prefix(2).map { l.expenseCategoryTitle($0.category) }.joined(separator: " · ")
        return "\(prefix) \(names)"
    }

    private func expenseTint(_ category: ExpenseCategory) -> Color {
        switch category {
        case .food: Color.foodDry
        case .treats: Color(hex: "10B981")
        case .medical: Color(hex: "F59E0B")
        case .grooming: Color(hex: "8B5CF6")
        case .toys: Color(hex: "EC4899")
        case .insurancePremium: Color(hex: "06B6D4")
        case .other: Color(hex: "6B7280")
        }
    }

    private func allExpenseStartDate(calendar: Calendar, now: Date) -> Date? {
        let first = positiveExpenseLogs.map(\.date).min()
        return first.map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: now)
    }

    private func compactDayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }
}

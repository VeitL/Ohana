//
//  HumanExpenseDashboardContent.swift
//  Ohana
//
//  Dashboard content split from WeightExpenseDashboardComponents.
//

import SwiftData
import SwiftUI
import UIKit

struct HumanExpenseDashboardContent: View {
    let human: Human
    let allExpenses: [PetExpenseLog]
    var onClose: () -> Void

    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var selectedRange: ExpenseDashboardRange = .month
    @State private var showingPersonalPlan = false
    @State private var selectedCategory: ExpenseCategory?

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool { appServices.privacy.isLocked(.expense, for: human, viewedBy: activeHumanId) }
    private var baseLogs: [PetExpenseLog] {
        ExpenseSummaryBuilder.sortedRecent(ExpenseSummaryBuilder.paidBy(human.id, from: allExpenses))
    }

    private var filteredLogs: [PetExpenseLog] {
        ExpenseSummaryBuilder.logs(
            ExpenseSummaryBuilder.logs(baseLogs, in: selectedRange),
            category: selectedCategory
        )
    }

    private var attributedBaseLogs: [ExpenseSummarySlice] {
        ExpenseSummaryBuilder.summarySlices(from: baseLogs, attributedTo: human.id.uuidString)
    }

    private var attributedFilteredLogs: [ExpenseSummarySlice] {
        ExpenseSummaryBuilder.summarySlices(from: filteredLogs, attributedTo: human.id.uuidString)
    }

    private var positiveLogs: [ExpenseSummarySlice] {
        ExpenseSummaryBuilder.positiveLogs(attributedFilteredLogs)
    }
    /// Personal controls aggregate depth, never access to the underlying
    /// expense records.
    private var historyLogs: [PetExpenseLog] {
        ExpenseSummaryBuilder.logs(baseLogs, category: selectedCategory)
    }
    private var totals: ExpenseTotals { ExpenseSummaryBuilder.totals(from: attributedFilteredLogs) }
    private var baseTotals: ExpenseTotals { ExpenseSummaryBuilder.totals(from: attributedBaseLogs) }
    var body: some View {
        OhanaSheetPageScaffold(
            title: l.tr(
                zh: "宠物花费",
                en: "Pet spending",
                de: "Haustierausgaben",
                es: "Gastos de mascotas", pt: "Despesas com pets", fr: "Dépenses des animaux",
                ja: "ペットの支出", ko: "반려동물 지출", it: "Spese per animali"
            ),
            subtitle: human.name,
            onClose: onClose,
            leading: {
                FeatureHubAvatar(
                    imageCacheID: "human-expense-dashboard-\(human.id.uuidString)",
                    imageSignature: human.avatarThumbnailSignature,
                    humanModelID: human.persistentModelID,
                    emoji: human.avatarEmoji,
                    fallback: "👤",
                    tint: Color(hex: human.safeThemeColorHex)
                )
            },
            trailing: {
                if isViewingOwnProfile {
                    HumanPrivacyToggleButton(human: human, field: .expense)
                }
            },
            content: {
                if isPrivacyLocked {
                    HumanModulePrivacyLockedView(
                        title: appServices.privacy.lockedMessage(for: .expense),
                        message: l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this account to view it.", de: "Wechsle zu diesem Konto, um es zu sehen.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HumanPrivateDataNotice(human: human, field: .expense)
                        metrics
                        chartBlock
                        categoryStrip
                        historyBlock
                    }
                }
            },
            floating: { EmptyView() }
        )
        .sheet(isPresented: $showingPersonalPlan) {
            PersonalPlanView()
                .ohanaSheetPagePresentation()
        }
        .onChange(of: appServices.commerce.hasPersonalEntitlement) { _, _ in
            if selectedRange.requiresPersonal, !appServices.commerce.allows(.extendedTrends) {
                selectedRange = .month
            }
        }
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "range", title: l.tr(zh: "本期", en: "Period", de: "Zeitraum"), value: AppCurrency.format(totals.spent, fractionDigits: 0)),
            FeatureHubMetric(
                id: "net",
                title: l.tr(zh: "净额", en: "Net", de: "Netto"),
                value: AppCurrency.format(totals.net, fractionDigits: 0)
            ),
            FeatureHubMetric(id: "total", title: l.tr(zh: "累计", en: "Total", de: "Gesamt"), value: AppCurrency.format(baseTotals.spent, fractionDigits: 0))
        ])
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.tr(zh: "时间分布", en: "Timeline", de: "Zeitverlauf"))
                    .font(OhanaFont.headline(.black))
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
            if chartBuckets.contains(where: { $0.amount > 0 }) {
                ExpenseBarDashboardChart(buckets: chartBuckets, accent: .goPrimary)
                    .frame(height: 180)
            } else {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "记录花费后显示趋势", en: "Add an expense to show bars", de: "Ausgaben zeigen Balken"))
            }
        }
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
            }
        )
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "square.grid.2x2.fill")
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    categoryChip(category, title: l.expenseCategoryTitle(category), icon: category.systemIconName)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var historyBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "最近", en: "Recent", de: "Zuletzt"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            if historyLogs.isEmpty {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "还没有花费记录", en: "No expenses yet", de: "Noch keine Kosten"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(historyLogs) { log in
                        HStack(spacing: 12) {
                            Image(systemName: log.expenseCategory.systemIconName)
                                .font(OhanaFont.adaptive(size: 14, weight: .black))
                                .foregroundStyle(Color.goPrimary)
                                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rowTitle(log))
                                    .font(OhanaFont.callout(.black))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                    .lineLimit(1)
                                Text(rowSubtitle(log))
                                    .font(OhanaFont.caption(.semibold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            let attributedAmount = ExpenseSummaryBuilder.amountPaid(by: human.id, for: log)
                            Text(AppCurrency.format(attributedAmount, fractionDigits: 2))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(attributedAmount >= 0 ? Color.ohanaPrimaryText : Color.goTeal)
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                    }
                }
            }
        }
    }

    private var chartBuckets: [ExpenseTimeBucket] {
        makeExpenseBuckets(from: positiveLogs, range: selectedRange)
    }

    private func rowTitle(_ log: PetExpenseLog) -> String {
        if log.amount < 0 {
            return l.tr(zh: "报销到账", en: "Reimbursement", de: "Erstattung")
        }
        return log.note.isEmpty ? l.expenseCategoryTitle(log.expenseCategory) : log.note
    }

    private func rowSubtitle(_ log: PetExpenseLog) -> String {
        let dateText = log.date.formatted(date: .abbreviated, time: .omitted)
        guard let pet = log.pet else {
            let legacyLabel = l.tr(
                zh: "历史记录",
                en: "Legacy record",
                de: "Früherer Eintrag",
                es: "Registro anterior", pt: "Registo anterior", fr: "Ancienne entrée",
                ja: "以前の記録", ko: "이전 기록", it: "Voce precedente"
            )
            return "\(dateText) · \(legacyLabel)"
        }
        return "\(dateText) · \(pet.name)"
    }

    private func categoryChip(_ category: ExpenseCategory?, title: String, icon: String) -> some View {
        let selected = selectedCategory == category
        return Button {
            withAnimation(GoMotion.feedback) { selectedCategory = category }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black))
                Text(title)
                    .font(OhanaFont.caption(.black))
            }
            .foregroundStyle(selected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(selected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 28, weight: .black))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }
}

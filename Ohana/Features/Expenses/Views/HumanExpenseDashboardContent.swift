//
//  HumanExpenseDashboardContent.swift
//  Ohana
//
//  Dashboard content split from WeightExpenseDashboardComponents.
//

import SwiftData
import SwiftUI

struct HumanExpenseDashboardContent: View {
    let human: Human
    let allExpenses: [PetExpenseLog]
    var onClose: () -> Void
    var onAdd: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedRange: ExpenseDashboardRange = .month
    @State private var selectedCategory: ExpenseCategory?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

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

    private var positiveLogs: [PetExpenseLog] { ExpenseSummaryBuilder.positiveLogs(filteredLogs) }
    private var totals: ExpenseTotals { ExpenseSummaryBuilder.totals(from: filteredLogs) }
    private var baseTotals: ExpenseTotals { ExpenseSummaryBuilder.totals(from: baseLogs) }
    private var directTotals: ExpenseTotals {
        ExpenseSummaryBuilder.totals(from: ExpenseSummaryBuilder.humanDirectExpenses(human.id, from: filteredLogs))
    }

    var body: some View {
        OhanaSheetPageScaffold(
            title: l.tr(zh: "花费记录", en: "Expenses", de: "Kosten"),
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
            floating: {
                if !isPrivacyLocked {
                    addButton
                }
            }
        )
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "range", title: l.tr(zh: "本期", en: "Period", de: "Zeitraum"), value: AppCurrency.format(totals.spent, fractionDigits: 0)),
            FeatureHubMetric(
                id: totals.reimbursed > 0 ? "net" : "direct",
                title: totals.reimbursed > 0 ? l.tr(zh: "净额", en: "Net", de: "Netto") : l.tr(zh: "个人", en: "Personal", de: "Persönlich"),
                value: totals.reimbursed > 0 ? AppCurrency.format(totals.net, fractionDigits: 0) : AppCurrency.format(directTotals.spent, fractionDigits: 0)
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
                DashboardRangePicker(ranges: ExpenseDashboardRange.allCases, selection: $selectedRange) {
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
            if filteredLogs.isEmpty {
                emptyState(icon: AppCurrency.systemIconName, text: l.tr(zh: "还没有花费记录", en: "No expenses yet", de: "Noch keine Kosten"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredLogs.prefix(30)) { log in
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
                            Text(AppCurrency.format(log.amount, fractionDigits: 2))
                                .font(OhanaFont.callout(.black))
                                .foregroundStyle(log.amount >= 0 ? Color.ohanaPrimaryText : Color.goTeal)
                            Button {
                                commandQueue.enqueue(
                                    .expenseDelete(
                                        entityID: human.id,
                                        entityKind: EntityKind.human.rawValue,
                                        recordID: log.id
                                    )
                                ) {
                                    do {
                                        try DashboardRecordCommandExecutor(context: modelContext, services: appServices).deleteHumanExpense(
                                            log,
                                            human: human,
                                            note: "dashboard.expense.delete.\(EntityKind.human.rawValue)"
                                        )
                                    } catch {
                                        appServices.domainRevisions.publishFailure(
                                            command: .expenseDelete(
                                                entityID: human.id,
                                                entityKind: EntityKind.human.rawValue,
                                                recordID: log.id
                                            ),
                                            error: error
                                        )
                                    }
                                }
                            } label: {
                                Image(systemName: "trash").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityLabel(l.tr(zh: "删除花费", en: "Delete expense", de: "Ausgabe löschen"))
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 56, height: 56)
                .background(Color.goPrimary, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(l.tr(zh: "添加花费", en: "Add expense", de: "Kosten hinzufügen"))
        .accessibilityIdentifier("human-expense-add-action")
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
            return "\(dateText) · \(l.tr(zh: "个人花费", en: "Personal expense", de: "Persönliche Ausgabe"))"
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
            .foregroundStyle(selected ? Color.arkInk : Color.ohanaSecondaryText)
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

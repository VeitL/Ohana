//
//  HumanExpenseDetailView.swift
//  Ohana
//
//  V4 human expense history.
//

import SwiftData
import SwiftUI

struct HumanExpenseDetailContentView: View {
    let human: Human
    let allExpenses: [PetExpenseLog]

    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var showingQuickExpense = false

    init(human: Human, allExpenses: [PetExpenseLog]) {
        self.human = human
        self.allExpenses = allExpenses
    }

    private var l: L10n { L10n(appLanguage) }
    private var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }
    private var isViewingOwnProfile: Bool { activeHumanId == human.id }
    private var isPrivacyLocked: Bool {
        appServices.privacy.isLocked(.expense, for: human, viewedBy: activeHumanId)
    }

    private var myExpenses: [PetExpenseLog] {
        allExpenses
    }

    private var monthExpenses: [PetExpenseLog] {
        myExpenses.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var totalAmount: Double {
        myExpenses.reduce(0) { $0 + $1.amount }
    }

    private var monthAmount: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        ZStack {
            HumanExpenseDashboardContent(
                human: human,
                allExpenses: allExpenses,
                onClose: { dismiss() },
                onAdd: {
                    withAnimation(GoMotion.feedback) {
                        showingQuickExpense = true
                    }
                }
            )
            if showingQuickExpense {
                QuickHumanExpenseSheet(
                    human: human,
                    onDismiss: {
                        withAnimation(GoMotion.feedback) {
                            showingQuickExpense = false
                        }
                    }
                )
                .zIndex(20)
            }
        }
    }

    private var header: some View {
        HumanModulePageHeader(
            human: human,
            title: l.tr(zh: "花费记录", en: "Expenses", de: "Kosten"),
            subtitle: human.name,
            onClose: { dismiss() }
        ) {
            if isViewingOwnProfile {
                HumanPrivacyToggleButton(human: human, field: .expense)
            }
        }
    }

    private var metricStrip: some View {
        HumanModuleMetricStrip(metrics: [
            FeatureHubMetric(
                id: "month",
                title: l.tr(zh: "本月", en: "This month", de: "Diesen Monat"),
                value: AppCurrency.format(monthAmount, fractionDigits: 0)
            ),
            FeatureHubMetric(
                id: "total",
                title: l.tr(zh: "累计", en: "Total", de: "Gesamt"),
                value: AppCurrency.format(totalAmount, fractionDigits: 0)
            )
        ])
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "历史", en: "History", de: "Verlauf"))
                .font(OhanaFont.headline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if myExpenses.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(myExpenses) { log in
                        expenseRow(log)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: AppCurrency.systemIconName) // a11y: allow decorative empty-state icon hidden below
                .font(OhanaFont.largeTitle(.black))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text(l.tr(zh: "还没有花费记录", en: "No expenses yet", de: "Noch keine Kosten"))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(l.tr(zh: "用右下角按钮快速记录一笔。", en: "Use the bottom button to add one quickly.", de: "Mit der unteren Taste schnell eintragen."))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private func expenseRow(_ log: PetExpenseLog) -> some View {
        HStack(spacing: 13) {
            Image(systemName: log.expenseCategory.systemIconName) // a11y: allow decorative category icon hidden below
                .font(OhanaFont.body(.black))
                .foregroundStyle(Color(hex: "F59E0B"))
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(log.note.isEmpty ? l.tr(zh: "花费记录", en: "Expense", de: "Kosten") : log.note)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(AppCurrency.format(log.amount, fractionDigits: 2))
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                .strokeBorder(Color.ohanaCardStroke, lineWidth: 1)
        }
    }

    private var addButton: some View {
        HumanModuleFloatingActionButton(
            title: l.tr(zh: "记一笔", en: "Add", de: "Eintragen"),
            icon: "plus"
        ) {
            showingQuickExpense = true
        }
    }

    private var privacyLockedView: some View {
        HumanModulePrivacyLockedView(
            title: appServices.privacy.lockedMessage(for: .expense),
            message: l.tr(zh: "请切换到本人档案后再查看。", en: "Switch to this account to view it.", de: "Wechsle zu diesem Konto, um es zu sehen.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

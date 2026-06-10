//
//  PetExpenseDashboardContent.swift
//  Ohana
//
//  Dashboard content split from WeightExpenseDashboardComponents.
//

import SwiftData
import SwiftUI

struct PetExpenseDashboardContent: View {
    let pet: Pet
    let allHumans: [Human]
    var showsCloseButton = true
    var onClose: () -> Void
    var onAdd: () -> Void
    var onRemove: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var selectedRange: ExpenseDashboardRange = .month
    @State private var selectedCategory: ExpenseCategory?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var l: L10n { L10n(appLanguage) }
    private var baseLogs: [PetExpenseLog] { pet.expenseLogs.sorted { $0.date > $1.date } }
    private var filteredLogs: [PetExpenseLog] {
        baseLogs.filter { log in
            let rangeOK = selectedRange.startDate().map { log.date >= $0 } ?? true
            let categoryOK = selectedCategory.map { log.expenseCategory == $0 } ?? true
            return rangeOK && categoryOK
        }
    }

    private var positiveLogs: [PetExpenseLog] { filteredLogs.filter { $0.amount > 0 } }
    private var total: Double { positiveLogs.reduce(0) { $0 + $1.amount } }
    private var categoryBreakdown: [(ExpenseCategory, Double)] {
        var dict: [ExpenseCategory: Double] = [:]
        for log in positiveLogs {
            dict[log.expenseCategory, default: 0] += log.amount
        }
        return dict.sorted { $0.value > $1.value }
    }

    var body: some View {
        OhanaSheetPageScaffold(
            title: l.tr(zh: "花费记录", en: "Expenses", de: "Kosten"),
            subtitle: pet.name,
            showsCloseButton: showsCloseButton,
            onClose: onClose,
            leading: {
                FeatureHubAvatar(
                    imageData: pet.avatarImageData,
                    emoji: pet.avatarEmoji,
                    fallback: pet.speciesEmoji,
                    tint: Color(hex: pet.safeThemeColorHex)
                )
            },
            trailing: { EmptyView() },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    metrics
                    chartBlock
                    categoryStrip
                    historyBlock
                }
            },
            floating: {
                addButton
            }
        )
    }

    private var metrics: some View {
        FeatureHubMetricStrip(metrics: [
            FeatureHubMetric(id: "range", title: l.tr(zh: "本期", en: "Period", de: "Zeitraum"), value: AppCurrency.format(total, fractionDigits: 0)),
            FeatureHubMetric(id: "count", title: l.tr(zh: "记录", en: "Logs", de: "Einträge"), value: "\(filteredLogs.count)"),
            FeatureHubMetric(id: "top", title: l.tr(zh: "最多", en: "Top", de: "Top"), value: categoryBreakdown.first.map { l.expenseCategoryTitle($0.0) } ?? "—")
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
                    ForEach(filteredLogs.prefix(30)) { log in expenseRow(log) }
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
    }

    private var chartBuckets: [ExpenseTimeBucket] {
        makeExpenseBuckets(from: positiveLogs, range: selectedRange)
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

    private func expenseRow(_ log: PetExpenseLog) -> some View {
        HStack(spacing: 12) {
            Image(systemName: log.expenseCategory.systemIconName)
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
            VStack(alignment: .leading, spacing: 3) {
                Text(log.note.isEmpty ? l.expenseCategoryTitle(log.expenseCategory) : log.note)
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
                    .expenseDelete(entityID: pet.id, entityKind: EntityKind.pet.rawValue, recordID: log.id)
                ) {
                    DashboardRecordCommandExecutor(context: modelContext, services: appServices).deletePetExpense(
                        log,
                        pet: pet,
                        note: "dashboard.expense.delete.\(EntityKind.pet.rawValue)"
                    )
                }
            } label: {
                Image(systemName: "trash").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(14)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    private func rowSubtitle(_ log: PetExpenseLog) -> String {
        let payer = log.executorId.flatMap { id in allHumans.first { $0.id.uuidString == id }?.name }
        let dateText = log.date.formatted(date: .abbreviated, time: .omitted)
        guard let payer else { return dateText }
        return "\(dateText) · \(payer)"
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

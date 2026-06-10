//
//  IslandExpenseDashboard.swift
//  Ohana
//
//  Global expense dashboard, aligned with the V4 "planet" dashboard language.
//

import SwiftUI
import SwiftData

private struct CategorySpendBreakdown: Identifiable {
    var id: String { category.rawValue }
    let category: ExpenseCategory
    let total: Double
    let pct: Double
}

private struct PetExpenseSummary: Identifiable {
    let id: UUID
    let name: String
    let emoji: String
    let total: Double
    let color: Color
    let categories: [CategorySpendBreakdown]
}

private struct CategorySummary: Identifiable {
    var id: String { category.rawValue }
    let category: ExpenseCategory
    let total: Double
    let pct: Double
}

private struct PayerSummary: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let total: Double
    let color: Color
    let pct: Double
    let categories: [CategorySpendBreakdown]
}

struct IslandExpenseDashboardContentView: View {
    var standalone: Bool = true
    let pets: [Pet]
    let humans: [Human]

    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @State private var selectedRange: ExpenseDashboardRange = .month

    private var l: L10n { L10n(appLanguage) }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var visibleExpenseHumans: [Human] {
        appServices.privacy.unlockedHumans(for: .expense, from: humans, viewedBy: activeHumanId)
    }

    private var allExpenseLogs: [PetExpenseLog] {
        pets.flatMap(\.expenseLogs)
    }

    private var filteredLogs: [PetExpenseLog] {
        guard let cutoff = selectedRange.startDate() else { return allExpenseLogs }
        return allExpenseLogs.filter { $0.date >= cutoff }
    }

    private var visibleExpenseLogs: [PetExpenseLog] {
        visibleLogs(from: filteredLogs)
    }

    private var positiveExpenseLogs: [PetExpenseLog] {
        visibleExpenseLogs.filter { $0.amount > 0 }
    }

    private var totalAmount: Double {
        positiveExpenseLogs.reduce(0) { $0 + $1.amount }
    }

    private var totalReimbursed: Double {
        visibleExpenseLogs
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }

    private var periodDelta: Double? {
        guard let currentStart = selectedRange.startDate() else { return nil }
        let now = Date()
        let span = now.timeIntervalSince(currentStart)
        guard span > 0 else { return nil }
        let previousStart = currentStart.addingTimeInterval(-span)
        let previousLogs = allExpenseLogs.filter { $0.date >= previousStart && $0.date < currentStart }
        let previousTotal = visibleLogs(from: previousLogs)
            .filter { $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
        return totalAmount - previousTotal
    }

    private var categorySummaries: [CategorySummary] {
        let total = max(1, totalAmount)
        var dict: [String: Double] = [:]
        for log in positiveExpenseLogs {
            dict[log.category, default: 0] += log.amount
        }
        return dict.compactMap { key, value in
            guard let category = ExpenseCategory(rawValue: key) else { return nil }
            return CategorySummary(category: category, total: value, pct: value / total)
        }
        .sorted { $0.total > $1.total }
    }

    private var topCategory: CategorySummary? {
        categorySummaries.first
    }

    private var petSummaries: [PetExpenseSummary] {
        pets.compactMap { pet in
            let logs = positiveExpenseLogs.filter { $0.pet?.id == pet.id }
            let total = logs.reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil }
            return PetExpenseSummary(
                id: pet.id,
                name: pet.name,
                emoji: pet.avatarEmoji,
                total: total,
                color: Color(hex: pet.safeThemeColorHex),
                categories: categoryBreakdown(for: logs)
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
        var logsByKey: [String: [PetExpenseLog]] = [:]
        for log in positiveExpenseLogs {
            let key = payerKey(for: log.executorId)
            totals[key, default: 0] += log.amount
            logsByKey[key, default: []].append(log)
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
                    categories: categoryBreakdown(for: logsByKey[key] ?? [])
                )
            }

            guard let human = visibleExpenseHumans.first(where: { $0.id.uuidString == key }) else {
                return nil
            }
            return PayerSummary(
                id: key,
                name: human.name,
                emoji: human.avatarEmoji,
                total: value,
                color: humanThemeColor(human),
                pct: value / total,
                categories: categoryBreakdown(for: logsByKey[key] ?? [])
            )
        }
        .sorted { $0.total > $1.total }
    }

    private var topPayer: PayerSummary? {
        humanSummaries.first
    }

    private var trendBuckets: [ExpenseTimeBucket] {
        let calendar = Calendar.current
        let now = Date()
        let start = selectedRange.startDate() ?? allExpenseStartDate(calendar: calendar, now: now)

        guard let start else { return [] }
        let dayCount = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0)

        return (0...dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start)) else {
                return nil
            }
            let amount = positiveExpenseLogs.reduce(0) { partial, log in
                calendar.isDate(log.date, inSameDayAs: day) ? partial + log.amount : partial
            }
            return ExpenseTimeBucket(date: day, label: compactDayLabel(day), amount: amount)
        }
    }

    var body: some View {
        dashboardBody
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()
                scrollContent
            }
            .ignoresSafeArea(edges: .top)
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if standalone { navBar }
                expensePlanetHero
                expenseTrendCard
                expenseBadgeStrip
                humanSpendSection
                petSpendSection
                if totalReimbursed > 0 {
                    reimbursementStrip
                }
                Color.clear.frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, standalone ? 0 : 14)
        }
    }

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .background(Color.ohanaControlFill, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
            Text(l.tr(zh: "花费星球", en: "Expense Planet", de: "Ausgabenplanet"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
        }
        .padding(.top, 50)
    }

    private var expensePlanetHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.goPrimary.opacity(0.16))
                        .frame(width: 56, height: 56)
                    Image(systemName: "creditcard.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 24, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "本期花费", en: "Spent", de: "Ausgaben"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text(AppCurrency.format(totalAmount, fractionDigits: 0))
                            .font(OhanaFont.adaptive(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .ohanaNumericMotion(totalAmount)
                        if let periodDelta {
                            trendDeltaPill(periodDelta)
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if let topCategory {
                    miniMetric(
                        title: l.tr(zh: "最多", en: "Top", de: "Top"),
                        value: topCategory.category.rawValue,
                        icon: topCategory.category.systemIconName,
                        tint: expenseTint(topCategory.category)
                    )
                }
                if let topPayer {
                    miniMetric(
                        title: l.tr(zh: "成员", en: "Member", de: "Mitglied"),
                        value: topPayer.name,
                        icon: "person.fill",
                        tint: topPayer.color
                    )
                }
                if let topPet {
                    miniMetric(
                        title: l.tr(zh: "宠物", en: "Pet", de: "Tier"),
                        value: topPet.name,
                        icon: "pawprint.fill",
                        tint: topPet.color
                    )
                }
            }
        }
    }

    private var expenseTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label(l.tr(zh: "花费节奏", en: "Spend rhythm", de: "Ausgabenrhythmus"), systemImage: "chart.bar.xaxis")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: ExpenseDashboardRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }

            if trendBuckets.allSatisfy({ $0.amount == 0 }) {
                emptyState(
                    icon: "creditcard",
                    text: l.tr(zh: "记录花费后会显示趋势", en: "Log spending to see the trend", de: "Ausgaben erfassen, um den Trend zu sehen")
                )
            } else {
                ExpenseBarDashboardChart(buckets: trendBuckets, accent: .goPrimary)
                    .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    text: l.tr(zh: "记录支付人后会显示成员花费", en: "Add payers to see member spending", de: "Zahlende erfassen, um Ausgaben je Mitglied zu sehen")
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
                    text: l.tr(zh: "关联宠物后会显示每只宠物花了什么", en: "Link pets to see what each one cost", de: "Haustiere zuordnen, um Kosten je Tier zu sehen")
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
                .font(OhanaFont.adaptive(size: 15, weight: .black))
                .foregroundStyle(Color(hex: "06B6D4"))
            Text(l.tr(zh: "已记录报销", en: "Refunds logged", de: "Erstattungen erfasst"))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
            Text(AppCurrency.format(totalReimbursed, fractionDigits: 0))
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .padding(.horizontal, 4)
    }

    private func dashboardSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            content()
        }
    }

    private func spendRow(
        avatar: String,
        name: String,
        amount: Double,
        tint: Color,
        categories: [CategorySpendBreakdown],
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
                        .font(OhanaFont.body(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(categorySummaryText(categories, prefix: detailPrefix))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Text(AppCurrency.format(amount, fractionDigits: 0))
                    .font(OhanaFont.subheadline(.black))
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

    private func categoryStackedBar(_ categories: [CategorySpendBreakdown]) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 3) {
                ForEach(categories.prefix(5)) { item in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
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
                .font(OhanaFont.adaptive(size: 9, weight: .black))
            Text(AppCurrency.format(abs(delta), fractionDigits: 0))
                .ohanaNumericMotion(delta)
        }
        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private func miniMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
                Text(value)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statBadge(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .ohanaNumericMotion(value)
                Text(title)
                    .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 20, weight: .black))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(text)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }

    private func visibleLogs(from logs: [PetExpenseLog]) -> [PetExpenseLog] {
        logs.filter {
            !appServices.privacy.isLocked(.expense, humanId: $0.executorId, in: humans, viewedBy: activeHumanId)
        }
    }

    private func payerKey(for executorId: String?) -> String {
        guard let raw = executorId, !raw.isEmpty else { return "__unknown__" }
        guard visibleExpenseHumans.contains(where: { $0.id.uuidString == raw }) else { return "__unknown__" }
        return raw
    }

    private func humanThemeColor(_ human: Human) -> Color {
        human.themeColor.count == 6 ? Color(hex: human.themeColor) : Color.goPrimary
    }

    private func categoryBreakdown(for logs: [PetExpenseLog]) -> [CategorySpendBreakdown] {
        let total = max(1, logs.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount })
        var dict: [String: Double] = [:]
        for log in logs where log.amount > 0 {
            dict[log.category, default: 0] += log.amount
        }
        return dict.compactMap { key, value in
            guard let category = ExpenseCategory(rawValue: key) else { return nil }
            return CategorySpendBreakdown(category: category, total: value, pct: value / total)
        }
        .sorted { $0.total > $1.total }
    }

    private func categorySummaryText(_ categories: [CategorySpendBreakdown], prefix: String) -> String {
        guard !categories.isEmpty else {
            return l.tr(zh: "暂无分类", en: "No category", de: "Keine Kategorie")
        }
        let names = categories.prefix(2).map { $0.category.rawValue }.joined(separator: " · ")
        return "\(prefix) \(names)"
    }

    private func expenseTint(_ category: ExpenseCategory) -> Color {
        switch category {
        case .food: return Color.foodDry
        case .treats: return Color(hex: "10B981")
        case .medical: return Color(hex: "F59E0B")
        case .grooming: return Color(hex: "8B5CF6")
        case .toys: return Color(hex: "EC4899")
        case .insurancePremium: return Color(hex: "06B6D4")
        case .other: return Color(hex: "6B7280")
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

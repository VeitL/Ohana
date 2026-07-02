import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func manageRow(icon: String, title: String, value: String, tint: Color, action: @escaping () -> Void) -> some View {
        QuickFeedManageRow(icon: icon, title: title, value: value, tint: tint, action: action)
    }

    func emptyInlineState(icon: String, text: String, solid _: Bool = false) -> some View {
        QuickFeedEmptyInlineState(icon: icon, text: text)
    }

    func feedLogRow(_ entry: QuickFeedLedgerEntry, compact: Bool, solidSurface _: Bool = false) -> some View {
        let badge = feedLedgerBadge(for: entry)
        let grams = feedLedgerDisplayGrams(for: entry)
        let feedLogId = editableFeedLogId(for: entry)
        return QuickFeedLogRow(
            icon: badge.icon,
            title: badge.title,
            tint: badge.tint,
            date: entry.date,
            gramsText: grams > 0 ? formattedFoodWeight(grams) : "--",
            compact: compact,
            editTint: mainFoodTint,
            onEdit: compact ? nil : feedLogId.map { id in
                { beginEditingFeedLog(id: id) }
            },
            onDelete: compact ? nil : feedLogId.map { id in
                { activeAlert = .deleteFeedLog(id: id) }
            }
        )
        .accessibilityIdentifier("quick-feed-log-row-\(entry.source.rawValue)-\(entry.date.quickFeedLogAccessibilityDayID)-\(entry.id.uuidString)")
    }

    func editableFeedLogId(for entry: QuickFeedLedgerEntry) -> UUID? {
        guard let legacyModelId = entry.legacyModelId else { return nil }
        return UUID(uuidString: legacyModelId)
    }

    func feedLedgerBadge(for entry: QuickFeedLedgerEntry) -> (title: String, tint: Color, icon: String) {
        if !entry.sharedSessionId.isEmpty {
            let session = allSharedCareSessions.first { $0.id.uuidString == entry.sharedSessionId }
            let countSuffix = SharedCareMetadata.targetCount(session: session, legacyNote: entry.note).map { " · \($0)只" } ?? ""
            return ("\(l.tr(zh: "共同喂食", en: "Shared", de: "Gemeinsam"))\(countSuffix) · \(entry.foodKind.title(l))", foodKindTint(entry.foodKind), "person.2.fill")
        }
        return switch entry.source {
        case .manualMain:
            ("\(l.tr(zh: "手动", en: "Manual", de: "Manuell")) · \(entry.foodKind.title(l))", foodKindTint(entry.foodKind), "hand.tap.fill")
        case .manualReminder:
            ("\(l.tr(zh: "计划", en: "Plan", de: "Plan")) · \(entry.foodKind.title(l))", Color.goPurple, FeedRuleKind.manualReminder.iconName)
        case .autoMain:
            ("\(l.tr(zh: "自动", en: "Auto", de: "Auto")) · \(entry.foodKind.title(l))", Color.goTeal, FeedRuleKind.autoFeeder.iconName)
        case .treat:
            (entry.treatKind?.title(l) ?? l.tr(zh: "零食", en: "Treat", de: "Snack"), treatTint, entry.treatKind?.systemIconName ?? "birthday.cake.fill")
        }
    }

    func feedLedgerDisplayGrams(for entry: QuickFeedLedgerEntry) -> Double {
        entry.source == .treat
            ? entry.displayAmountGrams
            : QuickFeedOverviewSnapshot.effectiveMainFoodAmount(for: entry, pet: pet)
    }

    func planReminderHistoryRow(_ reminder: Reminder, allowsCatchUp: Bool = false) -> some View {
        let isSatisfied = reminder.isCompleted
        let overdue = !isSatisfied && (reminder.isFailed || (reminder.isPending && reminder.scheduledAt < clockTick))
        let statusTitle: String = {
            if isSatisfied { return l.tr(zh: "打卡成功", en: "Checked in", de: "Erledigt") }
            if overdue { return l.tr(zh: "未打卡", en: "Missed", de: "Verpasst") }
            return l.tr(zh: "待打卡", en: "Pending", de: "Ausstehend")
        }()
        let tint: Color = isSatisfied ? Color.goPrimary : (overdue ? Color.goRed : Color.goYellow)
        let icon = isSatisfied ? "checkmark.seal.fill" : (overdue ? "exclamationmark.triangle.fill" : "clock.fill")
        let event = reminder.event
        let grams = event.map { formattedFoodWeight(FeedRuleMetadata.amountGrams(from: $0, fallback: pet.dailyPortionGrams)) } ?? "--"
        let foodKind = event?.foodKind.title(l) ?? pet.mainFoodKind.title(l)

        return QuickFeedPlanStatusRow(
            icon: icon,
            title: statusTitle,
            detail: "\(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened)) · \(foodKind) · \(grams)",
            tint: tint,
            actionTitle: allowsCatchUp && overdue && canCatchUpPlanReminder(reminder)
                ? l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen")
                : nil,
            onAction: {
                completePlannedFeed(reminder)
            }
        )
    }

    func foodRecordRow(_ record: PetFoodRecord) -> some View {
        let total = stockSnapshot.totalGrams(for: record)
        let foodTint = foodKindTint(record.foodKind)
        return QuickFeedFoodRecordRow(
            icon: record.foodKind.systemIconName,
            title: record.brand.isEmpty ? l.tr(zh: "未命名主粮", en: "Food", de: "Futter") : record.brand,
            subtitle: stockRecordDateSummary(record),
            value: total > 0 ? formattedFoodWeight(total) : nil,
            foodTint: foodTint,
            stockTint: stockTint,
            onEdit: {
                prepareStockSheet(record: record)
                openFeedSheet(.stock)
                UISelectionFeedbackGenerator().selectionChanged()
            },
            onDelete: {
                activeAlert = .deleteFoodRecord(record)
            }
        )
    }
}

private extension Date {
    var quickFeedLogAccessibilityDayID: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%04d%02d%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

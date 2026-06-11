import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func manageRow(icon: String, title: String, value: String, tint: Color, action: @escaping () -> Void) -> some View {
        QuickFeedManageRow(icon: icon, title: title, value: value, tint: tint, action: action)
    }

    func emptyInlineState(icon: String, text: String, solid _: Bool = false) -> some View {
        QuickFeedEmptyInlineState(icon: icon, text: text)
    }

    func feedLogRow(_ log: PetCareLog, compact: Bool, solidSurface _: Bool = false) -> some View {
        let badge = feedLogBadge(for: log)
        let grams = feedLogDisplayGrams(for: log)
        return QuickFeedLogRow(
            icon: badge.icon,
            title: badge.title,
            tint: badge.tint,
            date: log.date,
            gramsText: grams > 0 ? formattedFoodWeight(grams) : "--",
            compact: compact,
            editTint: mainFoodTint,
            onEdit: compact ? nil : {
                beginEditingFeedLog(log)
            },
            onDelete: compact ? nil : {
                activeAlert = .deleteFeedLog(log)
            }
        )
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

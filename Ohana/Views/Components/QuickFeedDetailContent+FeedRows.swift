import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func manageRow(icon: String, title: String, value: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 42, height: 42)
                    .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: 18)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func emptyInlineState(icon: String, text: String, solid _: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    func feedLogRow(_ log: PetCareLog, compact: Bool, solidSurface _: Bool = false) -> some View {
        let badge = feedLogBadge(for: log)
        let grams = feedLogDisplayGrams(for: log)
        return HStack(spacing: 10) {
            Image(systemName: badge.icon)
                .font(.system(size: compact ? 12 : 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
                .background(badge.tint, in: RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: compact ? 12 : 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(log.date, format: compact ? .dateTime.hour().minute() : .dateTime.month().day().hour().minute())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(grams > 0 ? formattedFoodWeight(grams) : "--")
                .font(.system(size: compact ? 13 : 15, weight: .black, design: .rounded))
                .foregroundStyle(badge.tint)
            if !compact {
                Button {
                    beginEditingFeedLog(log)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(mainFoodTint)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(ScaleButtonStyle())
                Button {
                    activeAlert = .deleteFeedLog(log)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.goRed)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(compact ? 0 : 12)
        .background {
            if !compact {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.ohanaCardSurface)
            }
        }
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

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(reminder.scheduledAt.formatted(date: .abbreviated, time: .shortened)) · \(foodKind) · \(grams)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if allowsCatchUp && overdue && !isSatisfied && (reminder.isPending || reminder.isFailed) {
                Button {
                    completePlannedFeed(reminder)
                } label: {
                    Text(l.tr(zh: "补打卡", en: "Catch up", de: "Nachtragen"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }

    func foodRecordRow(_ record: PetFoodRecord) -> some View {
        let total = stockSnapshot.totalGrams(for: record)
        return HStack(spacing: 10) {
            Image(systemName: record.foodKind.systemIconName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.arkInk)
                .frame(width: 36, height: 36)
                .background(foodKindTint(record.foodKind), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.brand.isEmpty ? l.tr(zh: "未命名主粮", en: "Food", de: "Futter") : record.brand)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(stockRecordDateSummary(record))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            if total > 0 {
                Text(formattedFoodWeight(total))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(foodKindTint(record.foodKind))
            }
            Button {
                prepareStockSheet(record: record)
                openFeedSheet(.stock)
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(stockTint)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(ScaleButtonStyle())
            Button {
                activeAlert = .deleteFoodRecord(record)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color.goRed)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(12)
        .feedFlatBlockSurface(cornerRadius: 18)
    }
}

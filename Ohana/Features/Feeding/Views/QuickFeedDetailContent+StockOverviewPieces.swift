import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func stockSnapshotCard(foodKind: FeedFoodKind, tint: Color) -> some View {
        let snapshot = stockSnapshot.stock(for: foodKind)
        let progress = snapshot.totalGrams > 0 ? max(0, min(1, snapshot.remainingGrams / snapshot.totalGrams)) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(foodKind.title(l), systemImage: "shippingbox.fill")
                    .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                Text(snapshot.totalGrams > 0 ? "\(snapshot.remainingDays) \(l.tr(zh: "天", en: "days", de: "Tage"))" : l.tr(zh: "未添加", en: "Not set", de: "Nicht gesetzt"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(snapshot.totalGrams > 0 && snapshot.remainingDays <= 3 ? Color.goRed : Color.ohanaSecondaryText)
            }
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(snapshot.totalGrams > 0 ? formattedStockWeight(snapshot.remainingGrams) : "--")
                    .font(OhanaFont.adaptive(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                Text(snapshot.totalGrams > 0 ? "/ \(formattedStockWeight(snapshot.totalGrams))" : "")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(snapshot.totalGrams > 0 && snapshot.remainingDays <= 3 ? Color.goRed : tint)
                            .frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 8)
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.input)
    }

    var stockOverviewStatusStrip: some View {
        let dry = stockSnapshot.dryStock
        let wet = stockSnapshot.wetStock
        let activeCount = stockSnapshot.activeCount
        let pendingCount = stockSnapshot.pendingCount
        let days = [dry, wet].filter { $0.totalGrams > 0 && $0.remainingDays > 0 }.map(\.remainingDays).min()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(days.map { "\($0)d" } ?? "--")
                    .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(stockOverviewStatusTint(dry: dry, wet: wet))
                    .contentTransition(.numericText())
                Text(l.tr(zh: "预计可用", en: "estimated", de: "geschätzt"))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(stockOverviewStatusText(dry: dry, wet: wet))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(stockOverviewStatusTint(dry: dry, wet: wet))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(stockOverviewStatusTint(dry: dry, wet: wet), in: Capsule())
                    .foregroundStyle(Color.arkInk)
            }

            HStack(spacing: 8) {
                stockOverviewMetric(
                    title: l.tr(zh: "开袋中", en: "Open", de: "Offen"),
                    value: "\(activeCount)",
                    icon: "shippingbox.fill"
                )
                stockOverviewMetric(
                    title: l.tr(zh: "待开袋", en: "Pending", de: "Wartend"),
                    value: "\(pendingCount)",
                    icon: "clock.fill"
                )
                stockOverviewMetric(
                    title: l.tr(zh: "提醒", en: "Alert", de: "Alarm"),
                    value: pet.foodReminderEnabled ? l.tr(zh: "开", en: "On", de: "Ein") : l.tr(zh: "关", en: "Off", de: "Aus"),
                    icon: pet.foodReminderEnabled ? "bell.badge.fill" : "bell.slash.fill"
                )
            }
        }
        .padding(.vertical, 2)
    }

    func stockOverviewMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(stockTint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(title)
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    var stockOverviewRestockSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                overviewSectionHeader(l.tr(zh: "补粮记录", en: "Restocks", de: "Nachfüllungen"))
                Spacer()
                Text("\(stockOverviewRecords.count)")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(stockTint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.ohanaControlFill, in: Capsule())
            }

            if stockOverviewRecords.isEmpty {
                emptyInlineState(
                    icon: "shippingbox",
                    text: l.tr(zh: "补粮后会显示每袋粮的购买、开袋和使用状态", en: "Restocks show purchase, open date, and status.", de: "Nachfüllungen zeigen Kauf, Öffnung und Status.")
                )
            } else {
                ForEach(stockOverviewRecords.prefix(6)) { record in
                    stockOverviewRecordCard(record)
                }
            }
        }
    }

    var stockOverviewRecords: [PetFoodRecord] {
        stockSnapshot.records
    }

    func stockOverviewRecordCard(_ record: PetFoodRecord) -> some View {
        let total = stockSnapshot.totalGrams(for: record)
        let activeRecord = stockSnapshot.activeRecord(for: record.foodKind)
        let isActive = activeRecord?.id == record.id
        let isPending = FeedStockCalculator.stockOpenDay(for: record) > Calendar.current.startOfDay(for: Date())
        let statusTint = isActive ? stockTint : (isPending ? Color.goYellow : Color.ohanaSecondaryText)
        let statusText = isActive
            ? l.tr(zh: "使用中", en: "Active", de: "Aktiv")
            : (isPending ? l.tr(zh: "待开袋", en: "Pending", de: "Wartend") : l.tr(zh: "历史", en: "Past", de: "Verlauf"))

        return Button {
            prepareStockSheet(record: record)
            openFeedSheet(.stock)
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Image(systemName: record.foodKind.systemIconName)
                        .font(OhanaFont.adaptive(size: 15, weight: .black))
                        .foregroundStyle(Color.arkInk)
                    Text(record.foodKind == .dry ? "DRY" : "WET")
                        .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk.opacity(0.72))
                }
                .frame(width: 44, height: 48)
                .background(foodKindTint(record.foodKind), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(record.brand.isEmpty ? l.tr(zh: "未命名主粮", en: "Food", de: "Futter") : record.brand)
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(statusText)
                            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(statusTint, in: Capsule())
                    }
                    Text(stockRecordDateSummary(record))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(total > 0 ? formattedStockWeight(total) : "--")
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(foodKindTint(record.foodKind))
                    Image(systemName: "pencil").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 11, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .padding(12)
            .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var autoFeederOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: FeedRuleKind.autoFeeder.iconName)
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.arkInk)
                    .frame(width: 34, height: 34) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                    .background(Color.goTeal, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "自动猫粮机", en: "Auto feeder", de: "Futterautomat"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(autoFeederStatusText)
                        .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text("\(autoFeederEvents.count)x")
                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goTeal)
            }

            HStack(spacing: 8) {
                modeInfoPill(
                    title: l.tr(zh: "每日", en: "Daily", de: "Täglich"),
                    value: formattedFoodWeight(feedTaskState.autoDailyTotalGrams),
                    tint: Color.goTeal
                )
                modeInfoPill(
                    title: l.tr(zh: "下次", en: "Next", de: "Nächste"),
                    value: nextAutoFeedDate?.formatted(date: .omitted, time: .shortened) ?? "--",
                    tint: Color.goTeal
                )
            }
        }
        .padding(14)
        .feedFlatBlockSurface(cornerRadius: OhanaRadius.controlLarge)
    }

    func stockRecordDateSummary(_ record: PetFoodRecord) -> String {
        let purchase = (record.purchaseDate ?? record.startDate).formatted(date: .numeric, time: .omitted)
        let open = record.startDate.formatted(date: .numeric, time: .omitted)
        let pending = record.startDate > Date() ? l.tr(zh: "待开袋", en: "Pending", de: "Ausstehend") + " · " : ""
        return pending + l.tr(
            zh: "\(record.foodKind.title(l)) · 买 \(purchase) · 开 \(open)",
            en: "\(record.foodKind.title(l)) · bought \(purchase) · open \(open)",
            de: "\(record.foodKind.title(l)) · gekauft \(purchase) · offen \(open)"
        )
    }
}

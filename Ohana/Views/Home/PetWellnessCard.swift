//
//  PetWellnessCard.swift
//  Ohana
//
//  首页宠物状态一览卡：当前顶牌宠物的今日核心指标
//

import SwiftUI
import SwiftData

struct PetWellnessCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext

    private let cal = Calendar.current

    // MARK: - Today's stats

    private var todayFeedCount: Int {
        (pet.careLogs ?? []).filter { $0.careType == .feeding && cal.isDateInToday($0.date) }.count
    }
    private var todayWaterCount: Int {
        (pet.careLogs ?? []).filter { $0.careType == .watering && cal.isDateInToday($0.date) }.count
    }
    private var todayWalkCount: Int {
        (pet.walkLogs ?? []).filter { cal.isDateInToday($0.startDate) }.count
    }
    private var todayPottyCount: Int {
        (pet.pottyLogs ?? []).filter { cal.isDateInToday($0.date) }.count
    }

    private var foodDaysLeft: Int? {
        if pet.foodTrackingMode == .casual {
            return pet.casualRemainingDays
        }
        let days = pet.remainingFoodDays
        return days > 0 ? days : nil
    }

    private var urgentAlerts: [HealthAlert] {
        PetHealthAlertEngine.shared.scanAlerts(pets: [pet])
            .filter { $0.severity >= .warning }
            .prefix(2)
            .map { $0 }
    }

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            checkInPills
            statusRow
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(themeColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(pet.avatarEmoji)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(todaySummaryText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if pet.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(streakColor)
                    Text("\(pet.currentStreak)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(streakColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(streakColor.opacity(0.12), in: Capsule())
            }
        }
    }

    private var streakColor: Color {
        pet.currentStreak >= 30 ? .orange : (pet.currentStreak >= 7 ? .goPrimary : .secondary)
    }

    private var todaySummaryText: String {
        let total = todayFeedCount + todayWaterCount + todayWalkCount + todayPottyCount
        if total == 0 { return "今天还没有打卡记录" }
        return "今日已完成 \(total) 项打卡"
    }

    // MARK: - Check-in pills

    private var checkInPills: some View {
        HStack(spacing: 8) {
            wellnessPill(emoji: "🍗", label: "喂食", count: todayFeedCount)
            wellnessPill(emoji: "💧", label: "喂水", count: todayWaterCount)
            if pet.species.lowercased().contains("dog") || pet.species.lowercased().contains("狗") {
                wellnessPill(emoji: "🦮", label: "遛狗", count: todayWalkCount)
            }
            wellnessPill(emoji: "💩", label: "便便", count: todayPottyCount)
        }
    }

    private func wellnessPill(emoji: String, label: String, count: Int) -> some View {
        let done = count > 0
        return HStack(spacing: 3) {
            Text(emoji)
                .font(.system(size: 12))
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(done ? themeColor : .secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(done ? themeColor.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .overlay(
            Capsule()
                .stroke(done ? themeColor.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .opacity(done ? 1 : 0.5)
    }

    // MARK: - Status row (food + alerts)

    @ViewBuilder
    private var statusRow: some View {
        let alerts = urgentAlerts
        let hasFood = foodDaysLeft != nil
        if hasFood || !alerts.isEmpty {
            HStack(spacing: 10) {
                if let days = foodDaysLeft {
                    foodCapsule(days: days)
                }
                ForEach(alerts) { alert in
                    alertCapsule(alert)
                }
                Spacer()
            }
        }
    }

    private func foodCapsule(days: Int) -> some View {
        let urgent = days <= 3
        return HStack(spacing: 4) {
            Image(systemName: "bag.fill")
                .font(.system(size: 10, weight: .bold))
            Text("粮仓 \(days) 天")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(urgent ? .white : .primary.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(urgent ? Color.red.opacity(0.85) : Color.primary.opacity(0.06))
        )
    }

    private func alertCapsule(_ alert: HealthAlert) -> some View {
        HStack(spacing: 3) {
            Text(alert.emoji)
                .font(.system(size: 10))
            Text(alert.title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(alert.severity == .urgent ? .white : .primary.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(alert.severity == .urgent ? Color.red.opacity(0.75) : Color.orange.opacity(0.15))
        )
    }
}

// MARK: - Family summary (when top card is human)
struct FamilyWellnessCard: View {
    let pets: [Pet]
    let plants: [Plant]

    private let cal = Calendar.current

    private var livePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    private var totalCheckins: Int {
        livePets.reduce(0) { acc, pet in
            let feeds = (pet.careLogs ?? []).filter { $0.careType == .feeding && cal.isDateInToday($0.date) }.count
            let walks = (pet.walkLogs ?? []).filter { cal.isDateInToday($0.startDate) }.count
            let potty = (pet.pottyLogs ?? []).filter { cal.isDateInToday($0.date) }.count
            return acc + feeds + walks + potty
        }
    }

    private var needsWateringCount: Int {
        plants.filter { $0.needsWatering }.count
    }

    private var urgentAlertCount: Int {
        PetHealthAlertEngine.shared.scanAlerts(pets: livePets)
            .filter { $0.severity >= .warning }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            summaryBadge(value: "\(totalCheckins)", label: "今日打卡", icon: "checkmark.circle.fill", color: .goPrimary)
            summaryBadge(value: "\(livePets.count)", label: "宠物", icon: "pawprint.fill", color: .goPrimary)
            if !plants.isEmpty {
                summaryBadge(value: "\(needsWateringCount)", label: "需浇水", icon: "drop.fill", color: .blue)
            }
            if urgentAlertCount > 0 {
                summaryBadge(value: "\(urgentAlertCount)", label: "提醒", icon: "exclamationmark.triangle.fill", color: .red)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 16)
    }

    private func summaryBadge(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 54)
    }
}

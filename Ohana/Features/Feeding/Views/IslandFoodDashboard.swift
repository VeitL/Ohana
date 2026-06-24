//
//  IslandFoodDashboard.swift
//  Ohana
//
//  Cross-pet food overview used by the GO home FAB and feature groups.
//

import SwiftData
import SwiftUI

struct IslandFoodDashboardContentView: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?
    let pets: [Pet]
    let allEvents: [Event]
    let allFeedingLedgerEntries: [FoodLedgerEntry]
    let legacyStockCareLogs: [PetCareLog]
    let allFoodRecords: [PetFoodRecord]
    let allSharedCareSessions: [SharedCareSession]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var chartRevealProgress: CGFloat = 0
    @StateObject private var snapshotStore = IslandFoodDashboardSnapshotStore()

    private var l: L10n { L10n(appLanguage) }

    private var activePets: [Pet] {
        snapshot.activePets
    }

    private var selectedPets: [Pet] {
        snapshot.selectedPets
    }

    private var dailyPoints: [FoodDayPoint] {
        snapshot.dailyPoints
    }

    private var petSummaries: [FoodPetSummary] {
        snapshot.petSummaries
    }

    private var lowestFoodDaysPet: Pet? {
        snapshot.lowestFoodDaysPet
    }

    private var snapshot: IslandFoodDashboardSnapshot {
        snapshotStore.snapshot
    }

    private var inputRevision: IslandFoodDashboardInputRevision {
        IslandFoodDashboardInputRevision.make(
            pets: pets,
            selectedPetId: selectedPetId,
            allEvents: allEvents,
            allFeedingLedgerEntries: allFeedingLedgerEntries,
            legacyStockCareLogs: legacyStockCareLogs,
            allFoodRecords: allFoodRecords,
            allSharedCareSessions: allSharedCareSessions
        )
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetFoodManagementView(pet: pet)
            }
            .onAppear {
                rebuildSnapshot(force: true)
                playChartReveal()
            }
            .onChange(of: inputRevision) { oldValue, newValue in
                rebuildSnapshot()
                if newValue.shouldReplayChart(comparedTo: oldValue) {
                    playChartReveal()
                }
            }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            NavigationStack {
                ZStack {
                    OhanaAppBackground().ignoresSafeArea()
                    scrollContent
                }
                .ignoresSafeArea(edges: .top)
                .navigationBarHidden(true)
            }
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if standalone { navBar }
                memberSelector
                foodBowlHero
                overviewCards
                trendSection
                foodRows
                Color.clear.frame(height: 36)
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
                    .goGlassBackground(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
            Text(l.tr(zh: "饮食总览", en: "Food overview"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
        }
        .padding(.top, 64)
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                selectorChip(title: l.tr(zh: "全部", en: "All"), icon: "square.grid.2x2.fill", isSelected: selectedPetId == nil) {
                    selectedPetId = nil
                }
                ForEach(activePets) { pet in
                    selectorChip(title: pet.name, avatar: { FMPetAvatar(pet: pet, size: 22) }, isSelected: selectedPetId == pet.id) {
                        selectedPetId = pet.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func selectorChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold))
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func selectorChip(
        title: String,
        @ViewBuilder avatar: () -> some View,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(
                title: l.tr(zh: "今日喂食", en: "Today's feeds"),
                value: "\(snapshot.todayFeedCount)",
                unit: l.tr(zh: "次", en: "x"),
                icon: "fork.knife",
                accent: Color.foodDry
            )
            metricCard(
                title: l.tr(zh: "今日总量", en: "Today total"),
                value: compactFoodWeight(snapshot.todayGrams),
                unit: "",
                icon: "scalemass.fill",
                accent: Color.goPrimary
            )
            metricCard(
                title: l.tr(zh: "7 天总量", en: "7-day total"),
                value: compactFoodWeight(snapshot.weekGrams),
                unit: "",
                icon: "chart.bar.fill",
                accent: Color.goTeal
            )
            metricCard(
                title: l.tr(zh: "余粮风险", en: "Stock risk"),
                value: foodRiskValue,
                unit: foodRiskUnit,
                icon: "shippingbox.fill",
                accent: foodRiskAccent
            )
        }
    }

    private var foodBowlHero: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 82, weight: .black))
                    .foregroundStyle(Color.foodDry.opacity(0.22))
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .fill(Color.foodDry.gradient)
                    .frame(width: 82, height: max(10, 68 * CGFloat(min(1, snapshot.weekGrams / max(1, Double(selectedPets.count) * 700))) * chartRevealProgress))
                    .mask {
                        Image(systemName: "takeoutbag.and.cup.and.straw.fill").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 82, weight: .black))
                    }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 7) {
                Text(l.tr(zh: "喂食节奏", en: "Feeding rhythm"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(todayFeedText)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(weekFeedText)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                Text(l.tr(zh: "近 7 天喂食", en: "Last 7 days"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text(l.tr(zh: "克数", en: "Grams"))
                    .font(OhanaFont.adaptive(size: 10, weight: .semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }

            if dailyPoints.allSatisfy({ $0.count == 0 }) {
                emptyState(l.tr(zh: "暂无喂食数据\n打卡后即可看到趋势", en: "No feeding data yet\nTrends appear after check-ins"))
                    .frame(height: 150)
            } else {
                OhanaMinimalBarChart(
                    points: dailyPoints.map {
                        OhanaMinimalChartPoint(date: $0.date, value: $0.grams)
                    },
                    tint: Color.foodDry,
                    progress: Double(chartRevealProgress),
                    showsLabels: true,
                    maxBarHeight: 118
                )
                .frame(height: 150)
            }
        }
    }

    private var foodRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "成员饮食状态", en: "Member food status"))
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            if petSummaries.isEmpty {
                emptyState(l.tr(zh: "还没有可显示的成员", en: "No members to show yet"))
                    .frame(height: 140)
            } else {
                ForEach(petSummaries) { summary in
                    foodRow(summary)
                }
            }
        }
    }

    private func foodRow(_ summary: FoodPetSummary) -> some View {
        let pet = summary.pet
        let accent = foodAccent(for: pet)
        return Button {
            if let onOpenPet {
                onOpenPet(pet)
            } else {
                sheetPet = pet
            }
        } label: {
            HStack(spacing: 13) {
                FMPetAvatar(pet: pet, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(pet.name)
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(pet.species.isEmpty ? l.tr(zh: "成员", en: "Member") : pet.species)
                            .font(OhanaFont.adaptive(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .lineLimit(1)
                    }
                    Text(foodStatusText(for: pet))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    Text(summaryText(summary))
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaTertiaryText)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.ohanaDivider, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: foodProgress(for: pet))
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .frame(width: 38, height: 38) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func metricCard(title: String, value: String, unit: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(OhanaFont.adaptive(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(unit)
                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Text(title)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 26, weight: .semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private func compactFoodWeight(_ value: Double) -> String {
        AppMeasurementSystem.formatFoodGrams(value)
    }

    private var foodRiskValue: String {
        guard let pet = lowestFoodDaysPet, let days = foodRemainingDays(for: pet) else { return "--" }
        return "\(days)"
    }

    private var foodRiskUnit: String {
        l.tr(zh: "天", en: "d")
    }

    private var foodRiskAccent: Color {
        guard let pet = lowestFoodDaysPet, let days = foodRemainingDays(for: pet) else { return Color.ohanaSecondaryText }
        if days <= 3 { return Color.goRed }
        if days <= 7 { return Color.goOrange }
        return Color.goPrimary
    }

    private func foodRemainingDays(for pet: Pet) -> Int? {
        snapshot.stock(for: pet)?.remainingDays
    }

    private func foodProgress(for pet: Pet) -> Double {
        snapshot.stock(for: pet)?.progress ?? 0.04
    }

    private func foodAccent(for pet: Pet) -> Color {
        guard let days = foodRemainingDays(for: pet) else { return Color.ohanaSecondaryText }
        if days <= 3 { return Color.goRed }
        if days <= 7 { return Color.goOrange }
        return Color.goPrimary
    }

    private func foodStatusText(for pet: Pet) -> String {
        guard let stock = snapshot.stock(for: pet), stock.hasStock else {
            return l.tr(zh: "未设置粮仓", en: "Food stock not set")
        }
        if let days = stock.remainingDays {
            return l.tr(
                zh: "余粮 \(compactFoodWeight(stock.remainingGrams)) · 可用 \(days) 天",
                en: "\(compactFoodWeight(stock.remainingGrams)) left · \(days)d available"
            )
        }
        return l.tr(
            zh: "余粮 \(compactFoodWeight(stock.remainingGrams)) · 未估算",
            en: "\(compactFoodWeight(stock.remainingGrams)) left · not estimated"
        )
    }

    private var todayFeedText: String {
        snapshot.todayFeedCount == 0
            ? l.tr(zh: "今天还没开饭", en: "No feeds yet today")
            : l.tr(zh: "今天 \(snapshot.todayFeedCount) 次", en: "\(snapshot.todayFeedCount) feeds today")
    }

    private var weekFeedText: String {
        l.tr(
            zh: "7 天 \(snapshot.weekFeedCount) 次 · \(compactFoodWeight(snapshot.weekGrams))",
            en: "7 days · \(snapshot.weekFeedCount) feeds · \(compactFoodWeight(snapshot.weekGrams))"
        )
    }

    private func summaryText(_ summary: FoodPetSummary) -> String {
        l.tr(
            zh: "今日 \(summary.todayCount) 次 · \(compactFoodWeight(summary.todayGrams)) / 7天 \(summary.weekCount) 次",
            en: "Today \(summary.todayCount)x · \(compactFoodWeight(summary.todayGrams)) / 7 days \(summary.weekCount)x"
        )
    }

    private func rebuildSnapshot(force: Bool = false) {
        snapshotStore.rebuild(
            pets: pets,
            selectedPetId: selectedPetId,
            allEvents: allEvents,
            allFeedingLedgerEntries: allFeedingLedgerEntries,
            legacyStockCareLogs: legacyStockCareLogs,
            allFoodRecords: allFoodRecords,
            allSharedCareSessions: allSharedCareSessions,
            force: force
        )
    }

    private func playChartReveal() {
        chartRevealProgress = 0
        withAnimation(GoMotion.page) {
            chartRevealProgress = 1
        }
    }
}

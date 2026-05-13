//
//  IslandFoodDashboard.swift
//  Ohana
//
//  Cross-pet food overview used by the GO home FAB and feature groups.
//

import SwiftUI
import SwiftData
import Charts

private struct FoodDayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let grams: Double
    let count: Int
}

private struct FoodPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let todayCount: Int
    let todayGrams: Double
    let weekCount: Int
    let weekGrams: Double
}

struct IslandFoodDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var chartRevealProgress: CGFloat = 0

    private var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var filteredFeedLogs: [PetCareLog] {
        selectedPets
            .flatMap(\.careLogs)
            .filter { $0.careType == .feeding }
    }

    private var todayFeedLogs: [PetCareLog] {
        filteredFeedLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var weekFeedLogs: [PetCareLog] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let cutoff = cal.date(byAdding: .day, value: -6, to: today) ?? today
        return filteredFeedLogs.filter { $0.date >= cutoff }
    }

    private var todayGrams: Double {
        todayFeedLogs.reduce(0) { $0 + amountGrams(for: $1) }
    }

    private var weekGrams: Double {
        weekFeedLogs.reduce(0) { $0 + amountGrams(for: $1) }
    }

    private var dailyPoints: [FoodDayPoint] {
        let cal = Calendar.current
        let selected = selectedPets
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) ?? Date()
            let logs = selected
                .flatMap(\.careLogs)
                .filter { $0.careType == .feeding && cal.isDate($0.date, inSameDayAs: day) }
            return FoodDayPoint(
                date: day,
                grams: logs.reduce(0) { $0 + amountGrams(for: $1) },
                count: logs.count
            )
        }
    }

    private var petSummaries: [FoodPetSummary] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let cutoff = cal.date(byAdding: .day, value: -6, to: today) ?? today
        return selectedPets.map { pet in
            let todayLogs = pet.careLogs.filter { $0.careType == .feeding && cal.isDateInToday($0.date) }
            let weekLogs = pet.careLogs.filter { $0.careType == .feeding && $0.date >= cutoff }
            return FoodPetSummary(
                id: pet.id,
                pet: pet,
                todayCount: todayLogs.count,
                todayGrams: todayLogs.reduce(0) { $0 + amountGrams(for: $1) },
                weekCount: weekLogs.count,
                weekGrams: weekLogs.reduce(0) { $0 + amountGrams(for: $1) }
            )
        }
    }

    private var lowestFoodDaysPet: Pet? {
        activePets
            .filter { foodRemainingDays(for: $0) != nil }
            .min { (foodRemainingDays(for: $0) ?? Int.max) < (foodRemainingDays(for: $1) ?? Int.max) }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetFoodManagementView(pet: pet)
            }
            .onAppear { playChartReveal() }
            .onChange(of: selectedPetId) { _, _ in playChartReveal() }
            .onChange(of: filteredFeedLogs.count) { _, _ in playChartReveal() }
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 36, height: 36)
                    .goGlassBackground(Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
            Text("饮食总览")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 64)
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                selectorChip(title: "全部", icon: "square.grid.2x2.fill", isSelected: selectedPetId == nil) {
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
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func selectorChip<Avatar: View>(
        title: String,
        @ViewBuilder avatar: () -> Avatar,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
            metricCard(title: "今日喂食", value: "\(todayFeedLogs.count)", unit: "次", icon: "fork.knife", accent: Color.foodDry)
            metricCard(title: "今日总量", value: compactFoodWeight(todayGrams), unit: "", icon: "scalemass.fill", accent: Color.goPrimary)
            metricCard(title: "7 天总量", value: compactFoodWeight(weekGrams), unit: "", icon: "chart.bar.fill", accent: Color.goTeal)
            metricCard(title: "余粮风险", value: foodRiskValue, unit: foodRiskUnit, icon: "shippingbox.fill", accent: foodRiskAccent)
        }
    }

    private var foodBowlHero: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.system(size: 82, weight: .black))
                    .foregroundStyle(Color.foodDry.opacity(0.22))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.foodDry.gradient)
                    .frame(width: 82, height: max(10, 68 * CGFloat(min(1, weekGrams / max(1, Double(selectedPets.count) * 700))) * chartRevealProgress))
                    .mask {
                        Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                            .font(.system(size: 82, weight: .black))
                    }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 7) {
                Text("喂食节奏")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Text(todayFeedLogs.isEmpty ? "今天还没开饭" : "今天 \(todayFeedLogs.count) 次")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("7 天 \(weekFeedLogs.count) 次 · \(compactFoodWeight(weekGrams))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.goPrimary)
                Text("近 7 天喂食")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                Spacer()
                Text("克数")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }

            if dailyPoints.allSatisfy({ $0.count == 0 }) {
                emptyState("暂无喂食数据\n打卡后即可看到趋势")
                    .frame(height: 150)
            } else {
                Chart(dailyPoints) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("克数", point.grams * Double(chartRevealProgress))
                    )
                    .foregroundStyle(Color.foodDry.gradient)
                    .cornerRadius(6)
                }
                .chartXAxis {
                    AxisMarks(values: dailyPoints.map(\.date)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.ohanaDivider)
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                .chartPlotStyle { plot in
                    plot.padding(.top, 10)
                }
                .frame(height: 168)
            }
        }
    }

    private var foodRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员饮食状态")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
                .padding(.horizontal, 2)

            if petSummaries.isEmpty {
                emptyState("还没有可显示的成员")
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
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(pet.species.isEmpty ? "成员" : pet.species)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaTertiaryText)
                            .lineLimit(1)
                    }
                    Text(foodStatusText(for: pet))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    Text("今日 \(summary.todayCount) 次 · \(compactFoodWeight(summary.todayGrams)) / 7天 \(summary.weekCount) 次")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
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
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .frame(width: 38, height: 38)
            }
            .padding(14)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func metricCard(title: String, value: String, unit: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(unit)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.ohanaTertiaryText)
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func amountGrams(for log: PetCareLog) -> Double {
        if log.amountGrams > 0 { return log.amountGrams }
        return log.pet?.dailyPortionGrams ?? 0
    }

    private func compactFoodWeight(_ value: Double) -> String {
        AppMeasurementSystem.formatFoodGrams(value)
    }

    private var foodRiskValue: String {
        guard let pet = lowestFoodDaysPet, let days = foodRemainingDays(for: pet) else { return "--" }
        return "\(days)"
    }

    private var foodRiskUnit: String {
        lowestFoodDaysPet == nil ? "天" : "天"
    }

    private var foodRiskAccent: Color {
        guard let pet = lowestFoodDaysPet, let days = foodRemainingDays(for: pet) else { return Color.ohanaSecondaryText }
        if days <= 3 { return Color.goRed }
        if days <= 7 { return Color.goOrange }
        return Color.goPrimary
    }

    private func foodRemainingDays(for pet: Pet) -> Int? {
        switch pet.foodTrackingMode {
        case .precise:
            guard pet.restockWeight > 0, pet.dailyPortionGrams > 0 else { return nil }
            return pet.remainingFoodDays
        case .casual:
            return pet.casualRemainingDays
        }
    }

    private func foodProgress(for pet: Pet) -> Double {
        switch pet.foodTrackingMode {
        case .precise:
            if pet.restockWeight > 0 { return max(0.04, min(1, pet.remainingFoodPercent)) }
            return 0.04
        case .casual:
            guard pet.casualDurationDays > 0, let days = pet.casualRemainingDays else { return 0.04 }
            return max(0.04, min(1, Double(days) / Double(pet.casualDurationDays)))
        }
    }

    private func foodAccent(for pet: Pet) -> Color {
        guard let days = foodRemainingDays(for: pet) else { return Color.ohanaSecondaryText }
        if days <= 3 { return Color.goRed }
        if days <= 7 { return Color.goOrange }
        return Color.goPrimary
    }

    private func foodStatusText(for pet: Pet) -> String {
        switch pet.foodTrackingMode {
        case .precise:
            guard pet.restockWeight > 0, pet.dailyPortionGrams > 0 else {
                return "未设置粮仓"
            }
            return "余粮 \(compactFoodWeight(pet.remainingFoodGrams)) · 可用 \(pet.remainingFoodDays) 天"
        case .casual:
            if let days = pet.casualRemainingDays {
                return "佛系估算 · 约 \(days) 天"
            }
            return "未设置开包估算"
        }
    }

    private func playChartReveal() {
        chartRevealProgress = 0
        withAnimation(GoMotion.page) {
            chartRevealProgress = 1
        }
    }
}

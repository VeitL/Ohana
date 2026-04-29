//
//  IslandHygieneDashboard.swift
//  Ohana
//
//  Cross-pet hygiene overview used by the GO home FAB and feature groups.
//

import SwiftUI
import SwiftData
import Charts

private struct HygieneDayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

private struct HygienePetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let todayCount: Int
    let weekCount: Int
    let overdueCount: Int
    let latestTitle: String
    let latestDate: Date?
}

struct IslandHygieneDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var scrubProgress: CGFloat = 0

    private var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var hygieneCareTypes: Set<CareType> {
        [.litter, .waterChange, .filterClean, .cageCleaning, .misting, .substrateChange]
    }

    private var todayCount: Int {
        selectedPets.reduce(0) { $0 + hygieneActionCount(for: $1, matching: { Calendar.current.isDateInToday($0) }) }
    }

    private var weekCount: Int {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        return selectedPets.reduce(0) { $0 + hygieneActionCount(for: $1, matching: { $0 >= cutoff }) }
    }

    private var overdueCount: Int {
        selectedPets.reduce(0) { $0 + overdueTypes(for: $1).count }
    }

    private var dailyPoints: [HygieneDayPoint] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) ?? Date()
            let count = selectedPets.reduce(0) { total, pet in
                total + hygieneActionCount(for: pet, matching: { cal.isDate($0, inSameDayAs: day) })
            }
            return HygieneDayPoint(date: day, count: count)
        }
    }

    private var petSummaries: [HygienePetSummary] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        return selectedPets.map { pet in
            let latest = latestAction(for: pet)
            return HygienePetSummary(
                id: pet.id,
                pet: pet,
                todayCount: hygieneActionCount(for: pet, matching: { cal.isDateInToday($0) }),
                weekCount: hygieneActionCount(for: pet, matching: { $0 >= cutoff }),
                overdueCount: overdueTypes(for: pet).count,
                latestTitle: latest?.title ?? "暂无护理记录",
                latestDate: latest?.date
            )
        }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetHygieneDetailView(pet: pet)
            }
            .onAppear { playScrubAnimation() }
            .onChange(of: selectedPetId) { _, _ in playScrubAnimation() }
            .onChange(of: weekCount) { _, _ in playScrubAnimation() }
    }

    @ViewBuilder
    private var dashboardBody: some View {
        if standalone {
            NavigationStack {
                ZStack {
                    ArkBackgroundView().ignoresSafeArea()
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
                cleanStationHero
                overviewCards
                trendSection
                hygieneRows
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
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .goGlassBackground(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
            Text("清洁护理")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
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
            .padding(.horizontal, 2)
        }
    }

    private var overviewCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(title: "今日护理", value: "\(todayCount)", subtitle: "次", icon: "sparkles", tint: Color.goLime)
            metricCard(title: "7 天护理", value: "\(weekCount)", subtitle: "次", icon: "calendar.badge.clock", tint: Color.goTeal)
            metricCard(title: "待补护理", value: "\(overdueCount)", subtitle: "项", icon: "exclamationmark.triangle.fill", tint: overdueCount > 0 ? Color.goOrange : Color.goLime)
            metricCard(title: "成员数", value: "\(selectedPets.count)", subtitle: "个", icon: "pawprint.fill", tint: Color(hex: "A78BFA"))
        }
    }

    private var cleanStationHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.goTeal.opacity(0.14))
                    .frame(width: 104, height: 104)
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill((index.isMultiple(of: 2) ? Color.goLime : Color.goTeal).opacity(0.72))
                        .frame(width: 8 + CGFloat(index % 3) * 4, height: 8 + CGFloat(index % 3) * 4)
                        .offset(x: CGFloat(index - 2) * 12, y: -34 + CGFloat(index % 2) * 18)
                        .scaleEffect(scrubProgress)
                }
                Image(systemName: overdueCount > 0 ? "exclamationmark.bubbles.fill" : "bubbles.and.sparkles.fill")
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(overdueCount > 0 ? Color.goOrange : Color.goTeal)
                    .rotationEffect(.degrees(Double(scrubProgress) * 8))
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("清洁站")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                Text(overdueCount > 0 ? "\(overdueCount) 项待补" : "护理节奏正常")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("今日 \(todayCount) 次 · 7 天 \(weekCount) 次")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.goTeal.opacity(0.2), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("近 14 天护理频率", systemImage: "chart.bar.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text("次数")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            if dailyPoints.allSatisfy({ $0.count == 0 }) {
                emptyState("暂无护理数据\n完成护理后会显示频率趋势")
            } else {
                Chart(dailyPoints) { point in
                    BarMark(
                        x: .value("日期", point.date, unit: .day),
                        y: .value("次数", Double(point.count) * Double(scrubProgress))
                    )
                    .foregroundStyle(Color.goLime.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 150)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var hygieneRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员护理状态")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            ForEach(petSummaries) { summary in
                Button {
                    open(summary.pet)
                } label: {
                    hygieneRow(summary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hygieneRow(_ summary: HygienePetSummary) -> some View {
        HStack(spacing: 12) {
            FMPetAvatar(pet: summary.pet, size: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(summary.pet.name)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(summary.pet.species)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(summary.latestTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    pill("今日 \(summary.todayCount)", color: Color.goLime)
                    pill("7天 \(summary.weekCount)", color: Color.goTeal)
                    if summary.overdueCount > 0 {
                        pill("待补 \(summary.overdueCount)", color: Color.goOrange)
                    }
                }
            }

            Spacer()

            if let date = summary.latestDate {
                Text(relativeDayText(date))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func metricCard(title: String, value: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(tint)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
            }
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func selectorChip<A: View>(title: String, avatar: () -> A, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.goLime : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func selectorChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        selectorChip(title: title, avatar: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
        }, isSelected: isSelected, action: action)
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .multilineTextAlignment(.center)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity, minHeight: 130)
    }

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func hygieneActionCount(for pet: Pet, matching dateMatches: (Date) -> Bool) -> Int {
        let hygiene = pet.hygieneLogs.filter { dateMatches($0.date) }.count
        let care = pet.careLogs.filter { hygieneCareTypes.contains($0.careType) && dateMatches($0.date) }.count
        return hygiene + care
    }

    private func latestAction(for pet: Pet) -> (title: String, date: Date)? {
        let hygiene = pet.hygieneLogs.map { ("护理 · \($0.hygieneType.rawValue)", $0.date) }
        let care = pet.careLogs
            .filter { hygieneCareTypes.contains($0.careType) }
            .map { ("清洁 · \($0.careType.rawValue)", $0.date) }
        return (hygiene + care).max { $0.1 < $1.1 }
    }

    private func overdueTypes(for pet: Pet) -> [HygieneType] {
        HygieneType.allCases.filter { type in
            let cycle = type.effectiveCycleDays(for: pet.id)
            guard let last = pet.hygieneLogs.filter({ $0.type == type.rawValue }).max(by: { $0.date < $1.date }) else {
                return false
            }
            let days = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            return days >= cycle
        }
    }

    private func relativeDayText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return "\(max(days, 0))天前"
    }

    private func playScrubAnimation() {
        scrubProgress = 0
        withAnimation(.spring(response: 0.58, dampingFraction: 0.78)) {
            scrubProgress = 1
        }
    }
}

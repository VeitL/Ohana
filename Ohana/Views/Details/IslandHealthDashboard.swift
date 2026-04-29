//
//  IslandHealthDashboard.swift
//  Ohana
//
//  Cross-pet health overview used by the GO home FAB and feature groups.
//

import SwiftUI
import SwiftData
import Charts

private struct HealthMonthPoint: Identifiable {
    let id = UUID()
    let month: Date
    let count: Int
}

private struct HealthPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let recordCount: Int
    let yearCount: Int
    let latestTitle: String
    let latestDate: Date?
    let riskText: String
    let riskColor: Color
}

struct IslandHealthDashboard: View {
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

    private var filteredLogs: [PetHealthLog] {
        selectedPets.flatMap(\.healthLogs)
    }

    private var yearLogs: [PetHealthLog] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        return filteredLogs.filter { $0.date >= cutoff }
    }

    private var dueSoonCount: Int {
        selectedPets.reduce(0) { total, pet in
            total + dueItems(for: pet).filter { item in
                guard let days = Calendar.current.dateComponents([.day], from: Date(), to: item.date).day else { return false }
                return days <= 30
            }.count
        }
    }

    private var noRecordCount: Int {
        selectedPets.filter(\.healthLogs.isEmpty).count
    }

    private var monthPoints: [HealthMonthPoint] {
        let cal = Calendar.current
        let thisMonth = cal.dateInterval(of: .month, for: Date())?.start ?? Date()
        return (0..<12).reversed().map { offset in
            let month = cal.date(byAdding: .month, value: -offset, to: thisMonth) ?? Date()
            let count = filteredLogs.filter { log in
                cal.isDate(log.date, equalTo: month, toGranularity: .month)
            }.count
            return HealthMonthPoint(month: month, count: count)
        }
    }

    private var typeBreakdown: [(type: HealthLogType, count: Int)] {
        HealthLogType.allCases
            .map { type in (type, filteredLogs.filter { $0.type == type.rawValue }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private var petSummaries: [HealthPetSummary] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        return selectedPets.map { pet in
            let latest = pet.healthLogs.max { $0.date < $1.date }
            let risk = riskStatus(for: pet)
            return HealthPetSummary(
                id: pet.id,
                pet: pet,
                recordCount: pet.healthLogs.count,
                yearCount: pet.healthLogs.filter { $0.date >= cutoff }.count,
                latestTitle: latest.map { $0.healthLogType.rawValue } ?? "暂无健康记录",
                latestDate: latest?.date,
                riskText: risk.text,
                riskColor: risk.color
            )
        }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetHealthDetailView(pet: pet, isModal: false)
            }
            .onAppear { playChartReveal() }
            .onChange(of: selectedPetId) { _, _ in playChartReveal() }
            .onChange(of: filteredLogs.count) { _, _ in playChartReveal() }
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
                healthSignalHero
                overviewCards
                trendSection
                typeBreakdownSection
                healthRows
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
            Text("健康总览")
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
            metricCard(title: "总记录", value: "\(filteredLogs.count)", subtitle: "条", icon: "cross.case.fill", tint: Color.goLime)
            metricCard(title: "12 个月", value: "\(yearLogs.count)", subtitle: "条", icon: "calendar", tint: Color.goTeal)
            metricCard(title: "近期到期", value: "\(dueSoonCount)", subtitle: "项", icon: "bell.badge.fill", tint: dueSoonCount > 0 ? Color.goOrange : Color.goLime)
            metricCard(title: "待建立档案", value: "\(noRecordCount)", subtitle: "位", icon: "person.crop.circle.badge.exclamationmark", tint: noRecordCount > 0 ? Color.goRed : Color.goLime)
        }
    }

    private var healthSignalHero: some View {
        HStack(spacing: 16) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.goLime.opacity(0.16 + Double(index) * 0.07), lineWidth: 5)
                        .frame(width: 92 - CGFloat(index) * 18, height: 92 - CGFloat(index) * 18)
                        .rotationEffect(.degrees(Double(index) * 12 + Double(chartRevealProgress) * 20))
                }
                Image(systemName: dueSoonCount > 0 ? "bell.badge.fill" : "heart.text.square.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(dueSoonCount > 0 ? Color.goOrange : Color.goLime)
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 7) {
                Text("健康信号")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                Text(dueSoonCount > 0 ? "\(dueSoonCount) 项需要关注" : "状态稳定")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("12 个月 \(yearLogs.count) 条记录 · \(typeBreakdown.first?.type.rawValue ?? "暂无类型")")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.goLime.opacity(0.2), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("12 个月健康记录", systemImage: "chart.bar.fill")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text("记录数")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }

            if monthPoints.allSatisfy({ $0.count == 0 }) {
                emptyState("暂无健康数据\n添加疫苗、体检或用药后会显示趋势")
            } else {
                Chart(monthPoints) { point in
                    BarMark(
                        x: .value("月份", point.month, unit: .month),
                        y: .value("记录", Double(point.count) * Double(chartRevealProgress))
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

    private var typeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记录类型")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if typeBreakdown.isEmpty {
                emptyState("暂无类型分布")
                    .frame(minHeight: 78)
            } else {
                ForEach(typeBreakdown.prefix(5), id: \.type.rawValue) { item in
                    HStack(spacing: 10) {
                        Text(item.type.emoji)
                            .font(.system(size: 18))
                        Text(item.type.rawValue)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }
                    .padding(12)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var healthRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员健康状态")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            ForEach(petSummaries) { summary in
                Button {
                    open(summary.pet)
                } label: {
                    healthRow(summary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func healthRow(_ summary: HealthPetSummary) -> some View {
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
                    pill("总计 \(summary.recordCount)", color: Color.goLime)
                    pill("年内 \(summary.yearCount)", color: Color.goTeal)
                    pill(summary.riskText, color: summary.riskColor)
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

    private func dueItems(for pet: Pet) -> [(type: HealthLogType, date: Date)] {
        let trackedTypes: [HealthLogType] = [.vaccine, .medication, .dewormingInternal, .dewormingExternal, .checkup]
        return trackedTypes.compactMap { type in
            guard let last = pet.healthLogs.filter({ $0.type == type.rawValue }).max(by: { $0.date < $1.date }) else {
                return nil
            }
            let next: Date?
            switch type {
            case .vaccine, .checkup:
                next = Calendar.current.date(byAdding: .year, value: 1, to: last.date)
            case .medication, .dewormingInternal, .dewormingExternal:
                next = Calendar.current.date(byAdding: .month, value: 3, to: last.date)
            default:
                next = nil
            }
            guard let next else { return nil }
            return (type, next)
        }
    }

    private func riskStatus(for pet: Pet) -> (text: String, color: Color) {
        let items = dueItems(for: pet)
        guard !items.isEmpty else {
            return pet.healthLogs.isEmpty ? ("待建立", Color.goRed) : ("正常", Color.goLime)
        }
        let days = items.compactMap { Calendar.current.dateComponents([.day], from: Date(), to: $0.date).day }
        if days.contains(where: { $0 < 0 }) { return ("已过期", Color.goRed) }
        if days.contains(where: { $0 <= 30 }) { return ("即将到期", Color.goOrange) }
        return ("正常", Color.goLime)
    }

    private func relativeDayText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return "\(max(days, 0))天前"
    }

    private func playChartReveal() {
        chartRevealProgress = 0
        withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
            chartRevealProgress = 1
        }
    }
}

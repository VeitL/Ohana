//
//  IslandHealthDashboard.swift
//  Ohana
//
//  Cross-pet health archive dashboard.
//

import SwiftData
import SwiftUI

private enum HealthDashboardRange: Hashable, CaseIterable {
    case days7
    case days30
    case days90
    case all

    func title(_ l: L10n) -> String {
        switch self {
        case .days7: l.tr(zh: "7天", en: "7D", de: "7T")
        case .days30: l.tr(zh: "30天", en: "30D", de: "30T")
        case .days90: l.tr(zh: "90天", en: "90D", de: "90T")
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }

    func startDate(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .days7:
            calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))
        case .days30:
            calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))
        case .days90:
            calendar.date(byAdding: .day, value: -89, to: calendar.startOfDay(for: now))
        case .all:
            nil
        }
    }
}

private struct HealthDayPoint: Identifiable, Hashable {
    let date: Date
    let count: Int

    var id: String {
        "\(Int(date.timeIntervalSinceReferenceDate))-\(count)"
    }
}

private struct HealthPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let totalCount: Int
    let periodCount: Int
    let latestTitle: String
    let latestDate: Date?
    let riskText: String
    let riskColor: Color
    let riskRank: Int
}

struct IslandHealthDashboardContentView: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?
    let pets: [Pet]
    let healthLogsByPetID: [UUID: [PetHealthLog]]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    @State private var selectedPetId: UUID? = nil
    @State private var selectedRange: HealthDashboardRange = .days30
    @State private var sheetPet: Pet? = nil
    @State private var chartProgress: Double = 0

    private var l: L10n { L10n(appLanguage) }

    private var activePets: [Pet] {
        pets.filter(\.canWriteHealthFacts)
    }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var filteredLogs: [PetHealthLog] {
        selectedPets.flatMap { healthLogs(for: $0) }
    }

    private var periodLogs: [PetHealthLog] {
        guard let cutoff = selectedRange.startDate() else { return filteredLogs }
        return filteredLogs.filter { $0.date >= cutoff }
    }

    private var overdueCount: Int {
        selectedPets.reduce(0) { total, pet in
            total + dueItems(for: pet).count(where: { item in
                let days = Calendar.current.dateComponents([.day], from: Date(), to: item.date).day ?? 0
                return days < 0
            })
        }
    }

    private var dueSoonCount: Int {
        selectedPets.reduce(0) { total, pet in
            total + dueItems(for: pet).count(where: { item in
                let days = Calendar.current.dateComponents([.day], from: Date(), to: item.date).day ?? 0
                return days >= 0 && days <= 30
            })
        }
    }

    private var noRecordCount: Int {
        selectedPets.count(where: { healthLogs(for: $0).isEmpty })
    }

    private var attentionCount: Int {
        overdueCount + dueSoonCount + noRecordCount
    }

    private var chartStartDate: Date {
        let calendar = Calendar.current
        let now = Date()
        if let rangeStart = selectedRange.startDate(now: now, calendar: calendar) {
            return rangeStart
        }
        let earliest = filteredLogs.map(\.date).min()
        let capped = calendar.date(byAdding: .day, value: -119, to: calendar.startOfDay(for: now)) ?? now
        return max(calendar.startOfDay(for: earliest ?? now), capped)
    }

    private var dayPoints: [HealthDayPoint] {
        let calendar = Calendar.current
        let nowStart = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: chartStartDate)
        let dayCount = max(0, calendar.dateComponents([.day], from: start, to: nowStart).day ?? 0)
        return (0 ... dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let count = filteredLogs.count(where: { calendar.isDate($0.date, inSameDayAs: day) })
            return HealthDayPoint(date: day, count: count)
        }
    }

    private var typeBreakdown: [(type: HealthLogType, count: Int)] {
        HealthLogType.allCases
            .map { type in (type, periodLogs.count(where: { $0.type == type.rawValue })) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    private var petSummaries: [HealthPetSummary] {
        let cutoff = selectedRange.startDate() ?? .distantPast
        return selectedPets.map { pet in
            let logs = healthLogs(for: pet)
            let latest = logs.max { $0.date < $1.date }
            let risk = riskStatus(for: pet)
            return HealthPetSummary(
                id: pet.id,
                pet: pet,
                totalCount: logs.count,
                periodCount: logs.count(where: { $0.date >= cutoff }),
                latestTitle: latest.map(\.healthLogType.rawValue) ?? l.tr(zh: "暂无健康记录", en: "No health logs", de: "Keine Gesundheitsdaten"),
                latestDate: latest?.date,
                riskText: risk.text,
                riskColor: risk.color,
                riskRank: risk.rank
            )
        }
        .sorted {
            if $0.riskRank != $1.riskRank { return $0.riskRank > $1.riskRank }
            return $0.pet.name < $1.pet.name
        }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetHealthDetailView(pet: pet, isModal: false)
            }
            .onAppear { playChartEntrance() }
            .onChange(of: selectedPetId) { _, _ in playChartEntrance() }
            .onChange(of: selectedRange) { _, _ in playChartEntrance() }
            .onChange(of: dayPoints) { _, _ in playChartEntrance() }
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
            VStack(spacing: 18) {
                if standalone { navBar }
                memberSelector
                healthPlanetHero
                healthTrendCard
                healthBadgeStrip
                typeBreakdownStrip
                healthRows
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
            Text(l.tr(zh: "健康星球", en: "Health Planet", de: "Gesundheitsplanet"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
        }
        .padding(.top, 50)
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                selectorChip(
                    title: l.tr(zh: "全部", en: "All", de: "Alle"),
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedPetId == nil
                ) {
                    selectedPetId = nil
                }

                ForEach(activePets) { pet in
                    selectorChip(
                        title: pet.name,
                        avatar: { FMPetAvatar(pet: pet, size: 22) },
                        isSelected: selectedPetId == pet.id
                    ) {
                        selectedPetId = pet.id
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var healthPlanetHero: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(heroTint.opacity(0.16))
                    .frame(width: 62, height: 62)
                Image(systemName: attentionCount > 0 ? "heart.text.square.fill" : "checkmark.seal.fill")
                    .font(OhanaFont.adaptive(size: 26, weight: .black))
                    .foregroundStyle(heroTint)
                    .symbolEffect(.pulse, value: attentionCount)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(attentionCount > 0 ? l.tr(zh: "需要关注", en: "Needs attention", de: "Braucht Aufmerksamkeit") : l.tr(zh: "健康记录", en: "Health logs", de: "Gesundheitsdaten"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(attentionCount > 0 ? attentionCount : periodLogs.count)")
                        .font(OhanaFont.adaptive(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .ohanaNumericMotion(attentionCount > 0 ? attentionCount : periodLogs.count)
                    Text(attentionCount > 0 ? l.tr(zh: "项", en: "items", de: "Punkte") : l.tr(zh: "条", en: "logs", de: "Einträge"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Text(heroSubtitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var healthTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(l.tr(zh: "健康记录频率", en: "Health rhythm", de: "Gesundheitsrhythmus"), systemImage: "chart.bar.fill")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: HealthDashboardRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }

            if dayPoints.allSatisfy({ $0.count == 0 }) {
                emptyState(
                    icon: "cross.case",
                    text: l.tr(zh: "添加疫苗、体检或用药后会显示趋势", en: "Vaccines, checkups, or meds will show here", de: "Impfungen, Checks oder Medikamente erscheinen hier")
                )
            } else {
                OhanaMinimalBarChart(
                    points: dayPoints.map { OhanaMinimalChartPoint(date: $0.date, value: Double($0.count)) },
                    tint: heroTint,
                    progress: chartProgress,
                    showsLabels: dayPoints.count <= 10,
                    maxBarHeight: 124
                )
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var healthBadgeStrip: some View {
        HStack(spacing: 10) {
            statBadge(
                title: l.tr(zh: "本期", en: "Period", de: "Zeitraum"),
                value: "\(periodLogs.count)",
                icon: "cross.case.fill",
                tint: Color.goPrimary
            )
            statBadge(
                title: l.tr(zh: "到期", en: "Due", de: "Fällig"),
                value: "\(overdueCount + dueSoonCount)",
                icon: "bell.badge.fill",
                tint: overdueCount + dueSoonCount > 0 ? Color.goOrange : Color.goTeal
            )
            statBadge(
                title: l.tr(zh: "待建档", en: "Setup", de: "Anlegen"),
                value: "\(noRecordCount)",
                icon: "person.crop.circle.badge.exclamationmark",
                tint: noRecordCount > 0 ? Color.goRed : Color.goTeal
            )
        }
    }

    @ViewBuilder
    private var typeBreakdownStrip: some View {
        if !typeBreakdown.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(typeBreakdown.prefix(6), id: \.type.rawValue) { item in
                        HStack(spacing: 6) {
                            Text(item.type.emoji)
                                .font(OhanaFont.adaptive(size: 15))
                            Text(item.type.rawValue)
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(Color.ohanaPrimaryText)
                            Text("\(item.count)")
                                .font(OhanaFont.caption(.black))
                                .foregroundStyle(Color.goPrimary)
                                .ohanaNumericMotion(item.count)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(Color.ohanaControlFill, in: Capsule())
                    }
                }
            }
        }
    }

    private var healthRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(l.tr(zh: "成员健康", en: "Health status", de: "Gesundheitsstatus"), systemImage: "pawprint.fill")
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if petSummaries.isEmpty {
                emptyState(
                    icon: "pawprint",
                    text: l.tr(zh: "添加宠物后会显示健康档案", en: "Add pets to see health files", de: "Füge Tiere hinzu, um Akten zu sehen")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(petSummaries) { summary in
                        Button {
                            open(summary.pet)
                        } label: {
                            healthRow(summary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private func healthRow(_ summary: HealthPetSummary) -> some View {
        HStack(spacing: 12) {
            FMPetAvatar(pet: summary.pet, size: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(summary.pet.name)
                        .font(OhanaFont.body(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    pill(summary.riskText, color: summary.riskColor)
                }

                Text(summary.latestTitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    pill(l.tr(zh: "本期 \(summary.periodCount)", en: "Now \(summary.periodCount)", de: "Jetzt \(summary.periodCount)"), color: Color.goPrimary)
                    pill(l.tr(zh: "总计 \(summary.totalCount)", en: "Total \(summary.totalCount)", de: "Gesamt \(summary.totalCount)"), color: Color.goTeal)
                }
            }

            Spacer(minLength: 0)

            if let date = summary.latestDate {
                Text(relativeDayText(date))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaTertiaryText)
            }

            Image(systemName: "chevron.right").accessibilityHidden(true)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
                .foregroundStyle(Color.ohanaTertiaryText)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.ohanaTertiaryText.opacity(0.18))
                .frame(height: 1)
        }
    }

    private var heroTint: Color {
        if overdueCount > 0 || noRecordCount > 0 { return Color.goRed }
        if dueSoonCount > 0 { return Color.goOrange }
        return Color.goPrimary
    }

    private var heroSubtitle: String {
        if overdueCount > 0 {
            return l.tr(zh: "\(overdueCount) 项已过期", en: "\(overdueCount) overdue", de: "\(overdueCount) überfällig")
        }
        if dueSoonCount > 0 {
            return l.tr(zh: "\(dueSoonCount) 项 30 天内到期", en: "\(dueSoonCount) due in 30 days", de: "\(dueSoonCount) in 30 Tagen fällig")
        }
        if noRecordCount > 0 {
            return l.tr(zh: "\(noRecordCount) 位还没有健康档案", en: "\(noRecordCount) without health files", de: "\(noRecordCount) ohne Gesundheitsakte")
        }
        return l.tr(zh: "健康档案节奏稳定", en: "Health files look steady", de: "Gesundheitsakten wirken stabil")
    }

    @ViewBuilder
    private func selectorChip(
        title: String,
        avatar: () -> some View,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(OhanaFont.caption(.black))
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func selectorChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        selectorChip(title: title, avatar: {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 11, weight: .black))
        }, isSelected: isSelected, action: action)
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

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
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

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func dueItems(for pet: Pet) -> [(type: HealthLogType, date: Date)] {
        let fallbackTypes: [HealthLogType] = [.vaccine, .medication, .dewormingInternal, .dewormingExternal, .checkup]
        let logs = healthLogs(for: pet)
        let explicitDates = logs.compactMap { log -> (HealthLogType, Date)? in
            if let expiration = log.expirationDate {
                return (log.healthLogType, expiration)
            }
            if let nextCheckup = log.nextCheckupDate {
                return (log.healthLogType, nextCheckup)
            }
            return nil
        }

        let fallbackDates = fallbackTypes.compactMap { type -> (HealthLogType, Date)? in
            guard let last = logs.filter({ $0.type == type.rawValue }).max(by: { $0.date < $1.date }) else {
                return nil
            }
            let next: Date? = switch type {
            case .vaccine, .checkup:
                Calendar.current.date(byAdding: .year, value: 1, to: last.date)
            case .medication, .dewormingInternal, .dewormingExternal:
                Calendar.current.date(byAdding: .month, value: 3, to: last.date)
            default:
                nil
            }
            guard let next else { return nil }
            return (type, next)
        }

        return explicitDates + fallbackDates
    }

    private func riskStatus(for pet: Pet) -> (text: String, color: Color, rank: Int) {
        if healthLogs(for: pet).isEmpty {
            return (l.tr(zh: "待建档", en: "Setup", de: "Anlegen"), Color.goRed, 3)
        }

        let items = dueItems(for: pet)
        let days = items.compactMap { Calendar.current.dateComponents([.day], from: Date(), to: $0.date).day }
        if days.contains(where: { $0 < 0 }) {
            return (l.tr(zh: "已过期", en: "Overdue", de: "Überfällig"), Color.goRed, 4)
        }
        if days.contains(where: { $0 <= 30 }) {
            return (l.tr(zh: "即将到期", en: "Due soon", de: "Bald fällig"), Color.goOrange, 2)
        }
        return (l.tr(zh: "稳定", en: "Steady", de: "Stabil"), Color.goTeal, 0)
    }

    private func relativeDayText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return l.tr(zh: "今天", en: "Today", de: "Heute")
        }
        if calendar.isDateInYesterday(date) {
            return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern")
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        return l.tr(zh: "\(max(days, 0))天前", en: "\(max(days, 0))d ago", de: "vor \(max(days, 0))T")
    }

    private func healthLogs(for pet: Pet) -> [PetHealthLog] {
        healthLogsByPetID[pet.id] ?? []
    }

    private func playChartEntrance() {
        chartProgress = 0
        withAnimation(GoMotion.page.delay(0.04)) {
            chartProgress = 1
        }
    }
}

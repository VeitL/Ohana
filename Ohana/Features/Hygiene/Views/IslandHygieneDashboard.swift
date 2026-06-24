//
//  IslandHygieneDashboard.swift
//  Ohana
//
//  Cross-pet hygiene and cleaning dashboard.
//

import SwiftUI

private enum HygieneDashboardRange: Hashable, CaseIterable {
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

private struct HygieneDayPoint: Identifiable, Hashable {
    let date: Date
    let count: Int

    var id: String {
        "\(Int(date.timeIntervalSinceReferenceDate))-\(count)"
    }
}

private struct HygienePetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let todayCount: Int
    let periodCount: Int
    let overdueCount: Int
    let latestTitle: String
    let latestDate: Date?
}

struct IslandHygieneDashboardContentView: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?
    let pets: [Pet]
    let hygieneLedgerEntries: [HygieneDashboardLedgerEntry]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @State private var selectedPetId: UUID? = nil
    @State private var selectedRange: HygieneDashboardRange = .days30
    @State private var sheetPet: Pet? = nil
    @State private var chartProgress: Double = 0

    private var l: L10n { L10n(appLanguage) }

    private var activePets: [Pet] {
        pets.filter { !$0.hasPassedAway }
    }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var hygieneDashboardActionsByPetId: [UUID: [HygieneDashboardLedgerEntry]] {
        Dictionary(grouping: hygieneLedgerEntries, by: \.petId)
    }

    private var todayCount: Int {
        selectedPets.reduce(0) { total, pet in
            total + hygieneActionCount(for: pet, matching: { Calendar.current.isDateInToday($0) })
        }
    }

    private var periodCount: Int {
        guard let cutoff = selectedRange.startDate() else {
            return selectedPets.reduce(0) { $0 + hygieneActionCount(for: $1, matching: { _ in true }) }
        }
        return selectedPets.reduce(0) { total, pet in
            total + hygieneActionCount(for: pet, matching: { $0 >= cutoff })
        }
    }

    private var overdueCount: Int {
        selectedPets.reduce(0) { $0 + overdueTypes(for: $1).count }
    }

    private var latestActionTitle: String {
        let latest = selectedPets.compactMap { latestAction(for: $0) }.max { $0.date < $1.date }
        return latest?.title ?? l.tr(zh: "还没有清洁记录", en: "No cleaning yet", de: "Noch keine Reinigung")
    }

    private var chartStartDate: Date {
        let calendar = Calendar.current
        let now = Date()
        if let rangeStart = selectedRange.startDate(now: now, calendar: calendar) {
            return rangeStart
        }
        let earliest = selectedPets.flatMap { hygieneActionDates(for: $0) }.min()
        let capped = calendar.date(byAdding: .day, value: -119, to: calendar.startOfDay(for: now)) ?? now
        return max(calendar.startOfDay(for: earliest ?? now), capped)
    }

    private var dailyPoints: [HygieneDayPoint] {
        let calendar = Calendar.current
        let nowStart = calendar.startOfDay(for: Date())
        let start = calendar.startOfDay(for: chartStartDate)
        let dayCount = max(0, calendar.dateComponents([.day], from: start, to: nowStart).day ?? 0)
        return (0 ... dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let count = selectedPets.reduce(0) { total, pet in
                total + hygieneActionCount(for: pet, matching: { calendar.isDate($0, inSameDayAs: day) })
            }
            return HygieneDayPoint(date: day, count: count)
        }
    }

    private var petSummaries: [HygienePetSummary] {
        let cutoff = selectedRange.startDate() ?? .distantPast
        return selectedPets.map { pet in
            let latest = latestAction(for: pet)
            return HygienePetSummary(
                id: pet.id,
                pet: pet,
                todayCount: hygieneActionCount(for: pet, matching: { Calendar.current.isDateInToday($0) }),
                periodCount: hygieneActionCount(for: pet, matching: { $0 >= cutoff }),
                overdueCount: overdueTypes(for: pet).count,
                latestTitle: latest?.title ?? l.tr(zh: "暂无护理记录", en: "No care yet", de: "Noch keine Pflege"),
                latestDate: latest?.date
            )
        }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetHygieneDetailView(pet: pet)
            }
            .onAppear { playChartEntrance() }
            .onChange(of: selectedPetId) { _, _ in playChartEntrance() }
            .onChange(of: selectedRange) { _, _ in playChartEntrance() }
            .onChange(of: dailyPoints) { _, _ in playChartEntrance() }
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
                hygienePlanetHero
                hygieneTrendCard
                hygieneBadgeStrip
                hygieneRows
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
            Text(l.tr(zh: "清洁星球", en: "Clean Planet", de: "Putzplanet"))
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

    private var hygienePlanetHero: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(heroTint.opacity(0.16))
                    .frame(width: 62, height: 62)
                Image(systemName: overdueCount > 0 ? "exclamationmark.bubbles.fill" : "bubbles.and.sparkles.fill")
                    .font(OhanaFont.adaptive(size: 26, weight: .black))
                    .foregroundStyle(heroTint)
                    .scaleEffect(chartProgress > 0.5 ? 1 : 0.92)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(overdueCount > 0 ? l.tr(zh: "待补护理", en: "Due care", de: "Fällige Pflege") : l.tr(zh: "今日护理", en: "Today", de: "Heute"))
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaSecondaryText)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(overdueCount > 0 ? overdueCount : todayCount)")
                        .font(OhanaFont.adaptive(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .ohanaNumericMotion(overdueCount > 0 ? overdueCount : todayCount)
                    Text(overdueCount > 0 ? l.tr(zh: "项", en: "due", de: "fällig") : l.tr(zh: "次", en: "done", de: "erledigt"))
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }

                Text(latestActionTitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var hygieneTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(l.tr(zh: "护理频率", en: "Care rhythm", de: "Pflegerhythmus"), systemImage: "chart.bar.fill")
                    .font(OhanaFont.subheadline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Spacer()
                DashboardRangePicker(ranges: HygieneDashboardRange.allCases, selection: $selectedRange) {
                    $0.title(l)
                }
            }

            if dailyPoints.allSatisfy({ $0.count == 0 }) {
                emptyState(
                    icon: "sparkles",
                    text: l.tr(zh: "完成清洁后会显示频率", en: "Cleaning logs will show here", de: "Pflegeeinträge erscheinen hier")
                )
            } else {
                OhanaMinimalBarChart(
                    points: dailyPoints.map { OhanaMinimalChartPoint(date: $0.date, value: Double($0.count)) },
                    tint: heroTint,
                    progress: chartProgress,
                    showsLabels: dailyPoints.count <= 10,
                    maxBarHeight: 124
                )
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous))
    }

    private var hygieneBadgeStrip: some View {
        HStack(spacing: 10) {
            statBadge(
                title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                value: "\(todayCount)",
                icon: "checkmark.seal.fill",
                tint: Color.goPrimary
            )
            statBadge(
                title: selectedRange.title(l),
                value: "\(periodCount)",
                icon: "calendar.badge.clock",
                tint: Color.goTeal
            )
            statBadge(
                title: l.tr(zh: "待补", en: "Due", de: "Fällig"),
                value: "\(overdueCount)",
                icon: "exclamationmark.triangle.fill",
                tint: overdueCount > 0 ? Color.goOrange : Color.goTeal
            )
        }
    }

    private var hygieneRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(l.tr(zh: "成员护理", en: "Care status", de: "Pflegestatus"), systemImage: "pawprint.fill")
                .font(OhanaFont.subheadline(.black))
                .foregroundStyle(Color.ohanaPrimaryText)

            if petSummaries.isEmpty {
                emptyState(
                    icon: "pawprint",
                    text: l.tr(zh: "添加宠物后会显示清洁护理", en: "Add pets to see cleaning care", de: "Füge Tiere hinzu, um Pflege zu sehen")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(petSummaries) { summary in
                        Button {
                            open(summary.pet)
                        } label: {
                            hygieneRow(summary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private func hygieneRow(_ summary: HygienePetSummary) -> some View {
        HStack(spacing: 12) {
            FMPetAvatar(pet: summary.pet, size: 42)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(summary.pet.name)
                        .font(OhanaFont.body(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    if summary.overdueCount > 0 {
                        pill("\(summary.overdueCount)", color: Color.goOrange, icon: "exclamationmark")
                    }
                }

                Text(summary.latestTitle)
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    pill(l.tr(zh: "今日 \(summary.todayCount)", en: "Today \(summary.todayCount)", de: "Heute \(summary.todayCount)"), color: Color.goPrimary)
                    pill("\(selectedRange.title(l)) \(summary.periodCount)", color: Color.goTeal)
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
        overdueCount > 0 ? Color.goOrange : Color.goPrimary
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

    private func pill(_ text: String, color: Color, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 8, weight: .black))
            }
            Text(text)
        }
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

    private func hygieneActionCount(for pet: Pet, matching dateMatches: (Date) -> Bool) -> Int {
        hygieneDashboardActions(for: pet).count { dateMatches($0.date) }
    }

    private func hygieneActionDates(for pet: Pet) -> [Date] {
        hygieneDashboardActions(for: pet).map(\.date)
    }

    private func latestAction(for pet: Pet) -> (title: String, date: Date)? {
        hygieneDashboardActions(for: pet)
            .map { (hygieneActionTitle(for: $0), $0.date) }
            .max { $0.1 < $1.1 }
    }

    private func overdueTypes(for pet: Pet) -> [HygieneType] {
        HygieneType.allCases.filter { type in
            let cycle = type.effectiveCycleDays(for: pet.id)
            guard let last = hygieneDashboardActions(for: pet).first(where: {
                $0.eventKind == .hygiene &&
                    $0.actionType == type.rawValue
            }) else {
                return false
            }
            let days = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            return days >= cycle
        }
    }

    private func hygieneDashboardActions(for pet: Pet) -> [HygieneDashboardLedgerEntry] {
        hygieneDashboardActionsByPetId[pet.id] ?? []
    }

    private func hygieneActionTitle(for action: HygieneDashboardLedgerEntry) -> String {
        switch action.eventKind {
        case .hygiene:
            let type = HygieneType(rawValue: action.actionType)?.rawValue ?? action.actionType
            return l.tr(zh: "护理", en: "Care", de: "Pflege") + " · \(type)"
        case .care:
            let type = CareType(rawValue: action.actionType)?.rawValue ?? action.actionType
            return l.tr(zh: "清洁", en: "Clean", de: "Reinigung") + " · \(type)"
        default:
            return action.actionType
        }
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

    private func playChartEntrance() {
        chartProgress = 0
        withAnimation(GoMotion.page.delay(0.04)) {
            chartProgress = 1
        }
    }
}

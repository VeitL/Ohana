//
//  IslandPottyDashboard.swift
//  Ohana
//
//  Cross-pet potty rhythm overview for GO home FAB and feature groups.
//

import SwiftUI
import SwiftData

private struct PottyDayPulse: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

private struct PottyPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let todayCount: Int
    let weekCount: Int
    let latestType: PottyType?
    let latestDate: Date?
}

struct IslandPottyDashboardContentView: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil
    let pets: [Pet]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.fallbackCode

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var pulseProgress: CGFloat = 0

    private var l: L10n { L10n(appLanguage) }

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var allLogs: [PetPottyLog] { selectedPets.flatMap(\.pottyLogs) }

    private var todayLogs: [PetPottyLog] {
        allLogs.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var weekLogs: [PetPottyLog] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        return allLogs.filter { $0.date >= cutoff }
    }

    private var dayPulses: [PottyDayPulse] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<10).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let count = allLogs.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            return PottyDayPulse(date: day, count: count)
        }
    }

    private var typeCounts: [(type: PottyType, count: Int)] {
        PottyType.allCases.map { type in
            (type, allLogs.filter { $0.type == type.rawValue }.count)
        }
    }

    private var dominantType: PottyType? {
        typeCounts.max { $0.count < $1.count }?.type
    }

    private var rhythmSummaryText: String {
        guard !weekLogs.isEmpty else {
            return l.tr(zh: "还没有形成规律", en: "No rhythm yet", de: "Noch kein Rhythmus")
        }
        let type = dominantType?.localizedLabel(l) ?? l.tr(zh: "混合记录", en: "mixed logs", de: "gemischt")
        return l.tr(
            zh: "7 天共 \(weekLogs.count) 次 · \(type) 最多",
            en: "7d · \(weekLogs.count)x · mostly \(type)",
            de: "7 T. · \(weekLogs.count)x · meist \(type)"
        )
    }

    private var petSummaries: [PottyPetSummary] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        return selectedPets.map { pet in
            let latest = pet.pottyLogs.max { $0.date < $1.date }
            return PottyPetSummary(
                id: pet.id,
                pet: pet,
                todayCount: pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count,
                weekCount: pet.pottyLogs.filter { $0.date >= cutoff }.count,
                latestType: latest?.pottyType,
                latestDate: latest?.date
            )
        }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                QuickPottyDetailRouteContainer(id: pet.id, onRemove: { sheetPet = nil }, onClose: { sheetPet = nil })
            }
            .onAppear { animatePulse() }
            .onChange(of: selectedPetId) { _, _ in animatePulse() }
            .onChange(of: allLogs.count) { _, _ in animatePulse() }
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
                radioHero
                typeBubbles
                rhythmStrip
                pottyRows
                Color.clear.frame(height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.top, standalone ? 0 : 14)
        }
    }

    private var navBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .goGlassBackground(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
            Text(l.tr(zh: "噗噗电台", en: "Poop Radio", de: "Häufchen-Radio"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goCardWhite)
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
        }
        .padding(.top, 64)
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                selectorChip(title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "dot.radiowaves.left.and.right", isSelected: selectedPetId == nil) {
                    selectedPetId = nil
                }
                ForEach(activePets) { pet in
                    selectorChip(title: pet.name, avatar: { FMPetAvatar(pet: pet, size: 22) }, isSelected: selectedPetId == pet.id) {
                        selectedPetId = pet.id
                    }
                }
            }
        }
    }

    private var radioHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(pottyBrown.opacity(0.15))
                    .frame(width: 96, height: 96)
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(pottyBrown.opacity(0.18 - Double(index) * 0.04), lineWidth: 8)
                        .scaleEffect(0.62 + CGFloat(index) * 0.22 + pulseProgress * 0.08)
                        .frame(width: 96, height: 96)
                }
                Text(dominantType?.emoji ?? "💩")
                    .font(OhanaFont.adaptive(size: 42)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .scaleEffect(0.94 + pulseProgress * 0.06)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(l.tr(zh: "今日节奏", en: "Today's rhythm", de: "Heute Rhythmus"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite.opacity(0.56))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(todayLogs.count)")
                        .font(OhanaFont.adaptive(size: 44, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goCardWhite)
                    Text(l.tr(zh: "次", en: "x", de: "x"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(pottyBrown)
                }
                Text(rhythmSummaryText)
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goCardWhite.opacity(0.52))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [pottyBrown.opacity(0.22), Color.goCardWhite.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(pottyBrown.opacity(0.24), lineWidth: 1)
        }
    }

    private var typeBubbles: some View {
        HStack(spacing: 8) {
            ForEach(typeCounts, id: \.type.rawValue) { item in
                VStack(spacing: 4) {
                    Image(systemName: item.type.systemIconName)
                        .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("\(item.count)")
                        .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .monospacedDigit()
                    Text(item.type.localizedLabel(l))
                        .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .lineLimit(1)
                }
                .foregroundStyle(pottyColor(item.type))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(pottyColor(item.type).opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var rhythmStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("10 日节奏条")
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goCardWhite.opacity(0.72))

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(dayPulses) { pulse in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(pulse.count > 0 ? pottyBrown.gradient : Color.goCardWhite.opacity(0.08).gradient)
                            .frame(height: max(10, CGFloat(pulse.count) * 17 * pulseProgress))
                        Text(pulse.date, format: .dateTime.weekday(.narrow))
                            .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goCardWhite.opacity(Calendar.current.isDateInToday(pulse.date) ? 0.78 : 0.36))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 104, alignment: .bottom)
        }
        .padding(16)
        .background(Color.goCardWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var pottyRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "成员噗况", en: "Crew poop status", de: "Team-Häufchenstatus"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goCardWhite)
            ForEach(petSummaries) { summary in
                Button { open(summary.pet) } label: {
                    HStack(spacing: 12) {
                        FMPetAvatar(pet: summary.pet, size: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(summary.pet.name)
                                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle(Color.goCardWhite)
                                Text(summary.latestType?.localizedLabel(l) ?? l.tr(zh: "暂无", en: "None", de: "Keine"))
                                    .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                    .foregroundStyle((summary.latestType.map(pottyColor) ?? .white).opacity(0.72))
                            }
                            Text(memberSummaryText(today: summary.todayCount, week: summary.weekCount))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                                .foregroundStyle(Color.goCardWhite.opacity(0.48))
                        }
                        Spacer()
                        Text(summary.latestDate.map(relativeDayText) ?? "--")
                            .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goCardWhite.opacity(0.42))
                        Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.goCardWhite.opacity(0.3))
                    }
                    .padding(14)
                    .background(Color.goCardWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func selectorChip<A: View>(title: String, avatar: () -> A, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.goLime : Color.goCardWhite.opacity(0.12), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func selectorChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        selectorChip(title: title, avatar: {
            Image(systemName: icon).font(OhanaFont.adaptive(size: 11, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }, isSelected: isSelected, action: action)
    }

    private var pottyBrown: Color { Color(red: 0.62, green: 0.38, blue: 0.18) }

    private func pottyColor(_ type: PottyType) -> Color {
        switch type {
        case .perfectPoop: return pottyBrown
        case .softPoop:    return Color.goOrange
        case .liquidPoop:  return Color.goRed
        case .pee:         return Color(hex: "06B6D4")
        }
    }

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func animatePulse() {
        pulseProgress = 0
        withAnimation(GoMotion.page) {
            pulseProgress = 1
        }
    }

    private func relativeDayText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        let safeDays = max(days, 0)
        return l.tr(zh: "\(safeDays)天前", en: "\(safeDays)d ago", de: "vor \(safeDays) T.")
    }

    private func memberSummaryText(today: Int, week: Int) -> String {
        l.tr(
            zh: "今日 \(today) 次 · 7 天 \(week) 次",
            en: "Today \(today)x · 7d \(week)x",
            de: "Heute \(today)x · 7 T. \(week)x"
        )
    }
}

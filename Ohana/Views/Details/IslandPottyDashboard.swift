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

struct IslandPottyDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var pulseProgress: CGFloat = 0

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
                PottyOverviewView(pet: pet)
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .goGlassBackground(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("便便电台")
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
                selectorChip(title: "全部", icon: "dot.radiowaves.left.and.right", isSelected: selectedPetId == nil) {
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
                    .font(.system(size: 42))
                    .scaleEffect(0.94 + pulseProgress * 0.06)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("今日节奏")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(todayLogs.count)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("次")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(pottyBrown)
                }
                Text(weekLogs.isEmpty ? "还没有形成规律" : "7 天共 \(weekLogs.count) 次 · \(dominantType?.rawValue ?? "混合记录")最多")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [pottyBrown.opacity(0.22), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
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
                        .font(.system(size: 15, weight: .black))
                    Text("\(item.count)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(item.type.rawValue)
                        .font(.system(size: 9, weight: .black, design: .rounded))
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
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(dayPulses) { pulse in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(pulse.count > 0 ? pottyBrown.gradient : Color.white.opacity(0.08).gradient)
                            .frame(height: max(10, CGFloat(pulse.count) * 17 * pulseProgress))
                        Text(pulse.date, format: .dateTime.weekday(.narrow))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(Calendar.current.isDateInToday(pulse.date) ? 0.78 : 0.36))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 104, alignment: .bottom)
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var pottyRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员便便状态")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            ForEach(petSummaries) { summary in
                Button { open(summary.pet) } label: {
                    HStack(spacing: 12) {
                        FMPetAvatar(pet: summary.pet, size: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(summary.pet.name)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(summary.latestType?.rawValue ?? "暂无")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle((summary.latestType.map(pottyColor) ?? .white).opacity(0.72))
                            }
                            Text("今日 \(summary.todayCount) 次 · 7 天 \(summary.weekCount) 次")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                        Text(summary.latestDate.map(relativeDayText) ?? "--")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
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
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
        }, isSelected: isSelected, action: action)
    }

    private var pottyBrown: Color { Color(red: 0.62, green: 0.38, blue: 0.18) }

    private func pottyColor(_ type: PottyType) -> Color {
        switch type {
        case .perfectPoop: return pottyBrown
        case .softPoop:    return Color.goOrange
        case .liquidPoop:  return Color.goRed
        case .pee:         return Color(hex: "3B82F6")
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
        withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
            pulseProgress = 1
        }
    }

    private func relativeDayText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return "\(max(days, 0))天前"
    }
}

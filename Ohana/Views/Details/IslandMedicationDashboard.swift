//
//  IslandMedicationDashboard.swift
//  Ohana
//
//  Cross-pet medication pillbox overview for GO home FAB and feature groups.
//

import SwiftUI
import SwiftData

private struct MedicationPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let activeMeds: [PetMedication]
    let dueDoses: Int
    let takenDoses: Int
}

struct IslandMedicationDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var doseRefreshToken = UUID()
    @State private var revealProgress: CGFloat = 0

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var summaries: [MedicationPetSummary] {
        selectedPets.map { pet in
            let meds = pet.medications.filter { $0.isActiveToday }.sorted { $0.createdAt > $1.createdAt }
            let due = meds.reduce(0) { $0 + max(0, $1.frequency.dosesPerDay) }
            let taken = meds.reduce(0) { $0 + min(MedicationReminderService.dosesTakenToday(for: $1.id), max(0, $1.frequency.dosesPerDay)) }
            let _ = doseRefreshToken
            return MedicationPetSummary(id: pet.id, pet: pet, activeMeds: meds, dueDoses: due, takenDoses: taken)
        }
    }

    private var activeMeds: [PetMedication] {
        selectedPets.flatMap(\.medications).filter { $0.isActiveToday }
    }

    private var dueDoses: Int {
        activeMeds.reduce(0) { $0 + max(0, $1.frequency.dosesPerDay) }
    }

    private var takenDoses: Int {
        let _ = doseRefreshToken
        return activeMeds.reduce(0) { total, med in
            total + min(MedicationReminderService.dosesTakenToday(for: med.id), max(0, med.frequency.dosesPerDay))
        }
    }

    private var completion: Double {
        guard dueDoses > 0 else { return activeMeds.isEmpty ? 0 : 1 }
        return min(1, Double(takenDoses) / Double(dueDoses))
    }

    private var endingSoonCount: Int {
        activeMeds.filter { med in
            guard let days = med.daysRemaining else { return false }
            return days <= 7
        }.count
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetMedicationView(pet: pet)
            }
            .onAppear { animateReveal() }
            .onChange(of: selectedPetId) { _, _ in animateReveal() }
            .onChange(of: doseRefreshToken) { _, _ in animateReveal() }
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
                pillboxHero
                todayMedicationStrip
                medicationRows
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
            Text("今日药盒")
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
                selectorChip(title: "全部", icon: "pills.fill", isSelected: selectedPetId == nil) {
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

    private var pillboxHero: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 12)
                    .frame(width: 104, height: 104)
                Circle()
                    .trim(from: 0, to: completion * revealProgress)
                    .stroke(medAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 104, height: 104)
                VStack(spacing: 1) {
                    Text("\(takenDoses)")
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(dueDoses)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("今日服药进度")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                Text(dueDoses == 0 ? "没有固定剂量" : completion >= 1 ? "今日完成" : "还有 \(max(0, dueDoses - takenDoses)) 次")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(activeMeds.count) 个当前用药 · \(endingSoonCount) 个 7 天内结束")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(hex: "FF5A00").opacity(0.26), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color(hex: "FF5A00").opacity(0.22), lineWidth: 1)
        }
    }

    private var todayMedicationStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("药盒格")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            if activeMeds.isEmpty {
                emptyState("暂无当前用药\n进入成员页添加药物计划")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                    ForEach(activeMeds.prefix(12)) { med in
                        pillCell(med)
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func pillCell(_ med: PetMedication) -> some View {
        let need = max(0, med.frequency.dosesPerDay)
        let taken = min(MedicationReminderService.dosesTakenToday(for: med.id), max(need, 1))
        let done = need > 0 && taken >= need
        let pet = med.pet
        let _ = doseRefreshToken
        return VStack(spacing: 8) {
            ZStack {
                Capsule()
                    .fill(Color(hex: med.colorHex).opacity(done ? 0.28 : 0.18))
                    .frame(width: 52, height: 24)
                    .rotationEffect(.degrees(-18))
                Capsule()
                    .fill(Color(hex: med.colorHex).opacity(done ? 0.7 : 0.38))
                    .frame(width: 52 * max(0.18, CGFloat(need == 0 ? 1 : Double(taken) / Double(max(need, 1))) * revealProgress), height: 24)
                    .rotationEffect(.degrees(-18))
                    .mask {
                        Capsule()
                            .frame(width: 52, height: 24)
                            .rotationEffect(.degrees(-18))
                    }
            }
            Text(med.name.isEmpty ? "未命名" : med.name)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(pet?.name ?? med.frequency.rawValue)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var medicationRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员药盒")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            ForEach(summaries) { summary in
                Button { open(summary.pet) } label: {
                    HStack(spacing: 12) {
                        FMPetAvatar(pet: summary.pet, size: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(summary.pet.name)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text(summary.activeMeds.isEmpty ? "暂无当前用药" : "\(summary.activeMeds.count) 个当前用药")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                        Text(summary.dueDoses == 0 ? "--" : "\(summary.takenDoses)/\(summary.dueDoses)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(summary.dueDoses > 0 && summary.takenDoses >= summary.dueDoses ? Color.goLime : medAccent)
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

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.42))
            .frame(maxWidth: .infinity, minHeight: 100)
    }

    private var medAccent: Color { Color(hex: "FF5A00") }

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func animateReveal() {
        revealProgress = 0
        withAnimation(.spring(response: 0.58, dampingFraction: 0.82)) {
            revealProgress = 1
        }
    }
}

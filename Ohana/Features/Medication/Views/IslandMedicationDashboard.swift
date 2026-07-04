//
//  IslandMedicationDashboard.swift
//  Ohana
//
//  Cross-pet medication pillbox overview for GO home FAB and feature groups.
//

import SwiftData
import SwiftUI

private struct MedicationPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let activeMeds: [PetMedication]
    let dueDoses: Int
    let takenDoses: Int
}

struct IslandMedicationDashboardContentView: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?
    let pets: [Pet]
    let medicationsByPetID: [UUID: [PetMedication]]
    var onMedicationDataChanged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

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
            let meds = medications(for: pet).filter(\.isActiveToday).sorted { $0.createdAt > $1.createdAt }
            let due = meds.reduce(0) { $0 + max(0, $1.frequency.dosesPerDay) }
            let taken = meds.reduce(0) { $0 + min(appServices.medicationReminders.dosesTakenToday(for: $1.id), max(0, $1.frequency.dosesPerDay)) }
            _ = doseRefreshToken
            return MedicationPetSummary(id: pet.id, pet: pet, activeMeds: meds, dueDoses: due, takenDoses: taken)
        }
    }

    private var activeMeds: [PetMedication] {
        selectedPets.flatMap { medications(for: $0) }
            .filter(\.isActiveToday)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var medicationPetNamesByID: [UUID: String] {
        var names: [UUID: String] = [:]
        for pet in pets {
            for medication in medications(for: pet) {
                names[medication.id] = pet.name
            }
        }
        return names
    }

    private var dueDoses: Int {
        activeMeds.reduce(0) { $0 + max(0, $1.frequency.dosesPerDay) }
    }

    private var takenDoses: Int {
        _ = doseRefreshToken
        return activeMeds.reduce(0) { total, med in
            total + min(appServices.medicationReminders.dosesTakenToday(for: med.id), max(0, med.frequency.dosesPerDay))
        }
    }

    private var completion: Double {
        guard dueDoses > 0 else { return activeMeds.isEmpty ? 0 : 1 }
        return min(1, Double(takenDoses) / Double(dueDoses))
    }

    private var endingSoonCount: Int {
        activeMeds.count(where: { med in
            guard let days = med.daysRemaining else { return false }
            return days <= 7
        })
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                PetMedicationView(pet: pet, onDataChanged: onMedicationDataChanged)
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
                Image(systemName: "chevron.left").accessibilityHidden(true)
                    .font(OhanaFont.adaptive(size: 15, weight: .bold))
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
                    .goGlassBackground(Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
            Text(l.tr(zh: "今日药盒", en: "Today's pillbox", de: "Heutige Medikamentenbox"))
                .font(OhanaFont.adaptive(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite)
            Spacer()
            Color.clear.frame(width: 36, height: 36) // a11y: allow decorative/non-interactive frame; parent content or surrounding label owns accessibility.
        }
        .padding(.top, 64)
    }

    private var memberSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                selectorChip(title: l.tr(zh: "全部", en: "All", de: "Alle"), icon: "pills.fill", isSelected: selectedPetId == nil) {
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
                    .stroke(Color.goCardWhite.opacity(0.12), lineWidth: 12)
                    .frame(width: 104, height: 104)
                Circle()
                    .trim(from: 0, to: completion * revealProgress)
                    .stroke(medAccent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 104, height: 104)
                VStack(spacing: 1) {
                    Text("\(takenDoses)")
                        .font(OhanaFont.adaptive(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goCardWhite)
                    Text("/ \(dueDoses)")
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goCardWhite.opacity(0.48))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(l.tr(zh: "今日服药进度", en: "Today's medication progress", de: "Heutiger Medikationsfortschritt"))
                    .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.56))
                Text(todayMedicationStatus)
                    .font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite)
                Text(l.tr(
                    zh: "\(activeMeds.count) 个当前用药 · \(endingSoonCount) 个 7 天内结束",
                    en: "\(activeMeds.count) active medications · \(endingSoonCount) ending within 7 days",
                    de: "\(activeMeds.count) aktive Medikamente · \(endingSoonCount) enden innerhalb von 7 Tagen"
                ))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.52))
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(hex: "FF5A00").opacity(0.26), Color.goCardWhite.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
                .strokeBorder(Color(hex: "FF5A00").opacity(0.22), lineWidth: 1)
        }
    }

    private var todayMedicationStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l.tr(zh: "药盒格", en: "Pill slots", de: "Medikamentenfaecher"))
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite.opacity(0.72))

            if activeMeds.isEmpty {
                emptyState(l.tr(
                    zh: "暂无当前用药\n进入成员页添加药物计划",
                    en: "No active medications yet\nOpen a member page to add a medication plan",
                    de: "Noch keine aktiven Medikamente\nOeffne eine Mitgliederseite, um einen Plan hinzuzufuegen"
                ))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                    ForEach(activeMeds.prefix(12)) { med in
                        pillCell(med)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.goCardWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous))
    }

    private func pillCell(_ med: PetMedication) -> some View {
        let need = max(0, med.frequency.dosesPerDay)
        let taken = min(appServices.medicationReminders.dosesTakenToday(for: med.id), max(need, 1))
        let done = need > 0 && taken >= need
        _ = doseRefreshToken
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
            Text(med.name.isEmpty ? l.tr(zh: "未命名", en: "Unnamed", de: "Unbenannt") : med.name)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite)
                .lineLimit(1)
            Text(medicationPetNamesByID[med.id] ?? med.frequency.rawValue)
                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goCardWhite.opacity(0.42))
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.goCardWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    private var medicationRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(l.tr(zh: "成员药盒", en: "Member pillboxes", de: "Medikamentenboxen der Mitglieder"))
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.goCardWhite)
            ForEach(summaries) { summary in
                Button { open(summary.pet) } label: {
                    HStack(spacing: 12) {
                        FMPetAvatar(pet: summary.pet, size: 42)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(summary.pet.name)
                                .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(Color.goCardWhite)
                            Text(summary.activeMeds.isEmpty ? l.tr(zh: "暂无当前用药", en: "No active medications", de: "Keine aktiven Medikamente") : l.tr(zh: "\(summary.activeMeds.count) 个当前用药", en: "\(summary.activeMeds.count) active medications", de: "\(summary.activeMeds.count) aktive Medikamente"))
                                .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.goCardWhite.opacity(0.48))
                        }
                        Spacer()
                        Text(summary.dueDoses == 0 ? "--" : "\(summary.takenDoses)/\(summary.dueDoses)")
                            .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(summary.dueDoses > 0 && summary.takenDoses >= summary.dueDoses ? Color.goPrimary : medAccent)
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 11, weight: .black))
                            .foregroundStyle(Color.goCardWhite.opacity(0.3))
                    }
                    .padding(14)
                    .background(Color.goCardWhite.opacity(0.07), in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func selectorChip(title: String, avatar: () -> some View, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar()
                Text(title)
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Color.arkInk : Color.goCardWhite)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func selectorChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        selectorChip(title: title, avatar: {
            Image(systemName: icon).font(OhanaFont.adaptive(size: 11, weight: .bold))
        }, isSelected: isSelected, action: action)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.goCardWhite.opacity(0.42))
            .frame(maxWidth: .infinity, minHeight: 100)
    }

    private var medAccent: Color { Color(hex: "FF5A00") }

    private var todayMedicationStatus: String {
        if dueDoses == 0 {
            return l.tr(zh: "没有固定剂量", en: "No fixed doses", de: "Keine festen Dosen")
        }
        if completion >= 1 {
            return l.tr(zh: "今日完成", en: "Done today", de: "Heute erledigt")
        }
        let remaining = max(0, dueDoses - takenDoses)
        return l.tr(zh: "还有 \(remaining) 次", en: "\(remaining) doses left", de: "Noch \(remaining) Dosen")
    }

    private func medications(for pet: Pet) -> [PetMedication] {
        medicationsByPetID[pet.id, default: []]
    }

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func animateReveal() {
        revealProgress = 0
        withAnimation(GoMotion.page) {
            revealProgress = 1
        }
    }
}

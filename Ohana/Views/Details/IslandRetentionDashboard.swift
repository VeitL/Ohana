//
//  IslandRetentionDashboard.swift
//  Ohana
//
//  Cross-pet archive and memory overview for GO home FAB and feature groups.
//

import SwiftUI
import SwiftData

private struct RetentionPetSummary: Identifiable {
    let id: UUID
    let pet: Pet
    let score: Int
    let photos: Int
    let milestones: Int
    let unlocked: Int
    let totalAchievements: Int
}

struct IslandRetentionDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var pets: [Pet]

    @State private var selectedPetId: UUID? = nil
    @State private var sheetPet: Pet? = nil
    @State private var growProgress: CGFloat = 0

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    private var selectedPets: [Pet] {
        guard let selectedPetId else { return activePets }
        return activePets.filter { $0.id == selectedPetId }
    }

    private var summaries: [RetentionPetSummary] {
        selectedPets.map { pet in
            let achievements = AchievementManager.compute(for: pet)
            return RetentionPetSummary(
                id: pet.id,
                pet: pet,
                score: retentionScore(for: pet),
                photos: pet.photoLogs.count,
                milestones: pet.milestones.count,
                unlocked: achievements.filter(\.isUnlocked).count,
                totalAchievements: achievements.count
            )
        }
    }

    private var averageScore: Double {
        guard !summaries.isEmpty else { return 0 }
        return summaries.reduce(0) { $0 + Double($1.score) } / Double(summaries.count)
    }

    private var totalMemories: Int {
        summaries.reduce(0) { $0 + $1.photos + $1.milestones }
    }

    private var totalAchievements: (unlocked: Int, total: Int) {
        summaries.reduce((0, 0)) { partial, item in
            (partial.0 + item.unlocked, partial.1 + item.totalAchievements)
        }
    }

    var body: some View {
        dashboardBody
            .sheet(item: $sheetPet) { pet in
                NavigationStack { PetRetentionHubView(pet: pet) }
            }
            .onAppear { animateGrowth() }
            .onChange(of: selectedPetId) { _, _ in animateGrowth() }
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
                treeHero
                memoryCapsules
                archiveRows
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
            Text("成长档案")
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
                selectorChip(title: "全部", icon: "tree.fill", isSelected: selectedPetId == nil) {
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

    private var treeHero: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.goLime.opacity(0.72))
                    .frame(width: 18, height: 64 * growProgress)
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < Int(averageScore.rounded()) ? Color.goLime.opacity(0.82) : Color.white.opacity(0.12))
                        .frame(width: 22 + CGFloat(index) * 9, height: 22 + CGFloat(index) * 9)
                        .offset(x: index.isMultiple(of: 2) ? -22 : 22, y: -CGFloat(index) * 13 * growProgress)
                        .scaleEffect(growProgress)
                }
            }
            .frame(width: 112, height: 112)

            VStack(alignment: .leading, spacing: 7) {
                Text("档案完整度")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(String(format: "%.1f", averageScore))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ 5")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                }
                Text("\(totalMemories) 个记忆点 · \(totalAchievements.unlocked)/\(totalAchievements.total) 枚成就")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color.goLime.opacity(0.19), Color.white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private var memoryCapsules: some View {
        HStack(spacing: 8) {
            archiveMetric("照片", "\(selectedPets.reduce(0) { $0 + $1.photoLogs.count })", "photo.on.rectangle.angled", .goTeal)
            archiveMetric("时刻", "\(selectedPets.reduce(0) { $0 + $1.milestones.count })", "sparkles", .goPrimary)
            archiveMetric("证件", "\(selectedPets.reduce(0) { $0 + $1.documents.count })", "doc.fill", .goOrange)
        }
    }

    private func archiveMetric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var archiveRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成员成长档案")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            ForEach(summaries) { summary in
                Button { open(summary.pet) } label: {
                    HStack(spacing: 12) {
                        FMPetAvatar(pet: summary.pet, size: 42)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(summary.pet.name)
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(summary.score)/5")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.goLime)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.1))
                                    Capsule()
                                        .fill(Color.goLime)
                                        .frame(width: geo.size.width * CGFloat(summary.score) / 5 * growProgress)
                                }
                            }
                            .frame(height: 7)
                            Text("\(summary.photos) 张照片 · \(summary.milestones) 个时刻 · \(summary.unlocked)/\(summary.totalAchievements) 成就")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.46))
                                .lineLimit(1)
                        }
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

    private func retentionScore(for pet: Pet) -> Int {
        let achievements = AchievementManager.compute(for: pet)
        return [
            !pet.weightLogs.isEmpty || !pet.healthLogs.isEmpty,
            !pet.photoLogs.isEmpty || !pet.milestones.isEmpty,
            !pet.expenseLogs.isEmpty,
            !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty,
            achievements.contains(where: \.isUnlocked) || pet.currentStreak > 0
        ].filter { $0 }.count
    }

    private func open(_ pet: Pet) {
        if let onOpenPet {
            onOpenPet(pet)
        } else {
            sheetPet = pet
        }
    }

    private func animateGrowth() {
        growProgress = 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
            growProgress = 1
        }
    }
}

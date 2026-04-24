// FunctionMenuSheet.swift
// GO Focus UI — 左上角功能菜单，跨宠物聚合所有功能入口

import SwiftUI
import SwiftData

// MARK: - Navigation Destination Enum (internal — shared with FeatureAggregateView & PetAllFeaturesSheet)

enum FMDest: Hashable {
    case featureAggregate(PetFeature)
    case petHealth(PersistentIdentifier)
    case petMedications(PersistentIdentifier)
    case petFood(PersistentIdentifier)
    case petHygiene(PersistentIdentifier)
    case petWalks(PersistentIdentifier)
    case petPotty(PersistentIdentifier)
    case petBasicInfo(PersistentIdentifier)
    case petDocuments(PersistentIdentifier)
    case petMoments(PersistentIdentifier)
    case petAchievements(PersistentIdentifier)
    case petWeight(PersistentIdentifier)
    case petExpense(PersistentIdentifier)
    case humanWeight(PersistentIdentifier)
    case humanExpense(PersistentIdentifier)
}

enum PetFeature: String, Hashable, CaseIterable {
    case health, medications, food, hygiene, walks, potty
    case basicInfo, documents, moments, achievements
    case weight, expense

    var title: String {
        switch self {
        case .health:        return "健康档案"
        case .medications:   return "用药管理"
        case .food:          return "饮食管理"
        case .hygiene:       return "清洁护理"
        case .walks:         return "遛狗记录"
        case .potty:         return "便便记录"
        case .basicInfo:     return "基本信息"
        case .documents:     return "证件保障"
        case .moments:       return "重要时刻"
        case .achievements:  return "成就"
        case .weight:        return "体重记录"
        case .expense:       return "花费记录"
        }
    }
    var icon: String {
        switch self {
        case .health:        return "cross.fill"
        case .medications:   return "pills.fill"
        case .food:          return "fork.knife"
        case .hygiene:       return "bubbles.and.sparkles.fill"
        case .walks:         return "figure.walk"
        case .potty:         return "drop.fill"
        case .basicInfo:     return "person.fill"
        case .documents:     return "doc.fill"
        case .moments:       return "sparkles"
        case .achievements:  return "trophy.fill"
        case .weight:        return "scalemass.fill"
        case .expense:       return "creditcard.fill"
        }
    }
}

// MARK: - Main Sheet

struct FunctionMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name) private var allHumans: [Human]

    @State private var path = NavigationPath()

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                List {
                    // ── Section 1: 健康管理 ──
                    Section {
                        fmRow(icon: "cross.fill", iconColor: Color(hex: "EF4444"),
                              title: "健康档案", subtitle: healthSubtitle) {
                            path.append(FMDest.featureAggregate(.health))
                        }
                        fmRow(icon: "scalemass.fill", iconColor: Color(hex: "16A34A"),
                              title: "体重记录", subtitle: weightSubtitle) {
                            path.append(FMDest.featureAggregate(.weight))
                        }
                        fmRow(icon: PetFeature.medications.icon, iconColor: Color(hex: "8B5CF6"),
                              title: PetFeature.medications.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.medications))
                        }
                    } header: {
                        fmSectionHeader(icon: "cross.fill", title: "健康管理", label: "HEALTH")
                    }
                    .listRowBackground(rowBackground)

                    // ── Section 2: 日常生活 ──
                    Section {
                        fmRow(icon: PetFeature.food.icon, iconColor: Color(hex: "F59E0B"),
                              title: PetFeature.food.title, subtitle: foodSubtitle) {
                            path.append(FMDest.featureAggregate(.food))
                        }
                        fmRow(icon: PetFeature.hygiene.icon, iconColor: Color(hex: "06B6D4"),
                              title: PetFeature.hygiene.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.hygiene))
                        }
                        if hasDogs {
                            fmRow(icon: PetFeature.walks.icon, iconColor: Color(hex: "0EA5E9"),
                                  title: PetFeature.walks.title, subtitle: walkSubtitle) {
                                path.append(FMDest.featureAggregate(.walks))
                            }
                        }
                        fmRow(icon: PetFeature.potty.icon, iconColor: Color(hex: "D97706"),
                              title: PetFeature.potty.title, subtitle: pottySubtitle) {
                            path.append(FMDest.featureAggregate(.potty))
                        }
                        fmRow(icon: "creditcard.fill", iconColor: Color(hex: "D97706"),
                              title: "花费记录", subtitle: expenseSubtitle) {
                            path.append(FMDest.featureAggregate(.expense))
                        }
                    } header: {
                        fmSectionHeader(icon: "sun.max.fill", title: "日常生活", label: "DAILY LIFE")
                    }
                    .listRowBackground(rowBackground)

                    // ── Section 3: 档案与记忆 ──
                    Section {
                        fmRow(icon: PetFeature.basicInfo.icon, iconColor: Color(hex: "6B82C4"),
                              title: PetFeature.basicInfo.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.basicInfo))
                        }
                        fmRow(icon: PetFeature.documents.icon, iconColor: Color(hex: "6B7280"),
                              title: PetFeature.documents.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.documents))
                        }
                        fmRow(icon: PetFeature.moments.icon, iconColor: Color(hex: "C8FF00"),
                              title: PetFeature.moments.title, subtitle: momentsSubtitle) {
                            path.append(FMDest.featureAggregate(.moments))
                        }
                        fmRow(icon: PetFeature.achievements.icon, iconColor: Color(hex: "F59E0B"),
                              title: PetFeature.achievements.title, subtitle: "\(activePets.count)只宠物") {
                            path.append(FMDest.featureAggregate(.achievements))
                        }
                    } header: {
                        fmSectionHeader(icon: "folder.fill", title: "档案与记忆", label: "ARCHIVE")
                    }
                    .listRowBackground(rowBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("所有功能")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.goLime)
                }
            }
            .navigationDestination(for: FMDest.self) { dest in
                fmDestinationView(dest)
            }
        }
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func fmDestinationView(_ dest: FMDest) -> some View {
        switch dest {
        case .featureAggregate(let feature):
            FeatureAggregateView(feature: feature, parentPath: $path)
        case .petHealth(let id):
            if let p = pet(for: id) { PetHealthDetailView(pet: p, isModal: false) }
        case .petMedications(let id):
            if let p = pet(for: id) { PetMedicationView(pet: p) }
        case .petFood(let id):
            if let p = pet(for: id) { PetFoodManagementView(pet: p) }
        case .petHygiene(let id):
            if let p = pet(for: id) { PetHygieneDetailView(pet: p) }
        case .petWalks(let id):
            if let p = pet(for: id) { WalkSummarySheet(pet: p) }
        case .petPotty(let id):
            if let p = pet(for: id) { PottyOverviewView(pet: p) }
        case .petBasicInfo(let id):
            if let p = pet(for: id) { PetBasicInfoDetailView(pet: p) }
        case .petDocuments(let id):
            if let p = pet(for: id) { DocumentsListView(pet: p) }
        case .petMoments(let id):
            if let p = pet(for: id) { PetMomentsHubView(pet: p) }
        case .petAchievements(let id):
            if let p = pet(for: id) { AchievementWallView(pet: p) }
        case .petWeight(let id):
            if let p = pet(for: id) { WeightHistoryView(pet: p) }
        case .petExpense(let id):
            if let p = pet(for: id) { ExpenseHistoryView(pet: p) }
        case .humanWeight(let id):
            if let h = human(for: id) { HumanWeightHistoryView(human: h) }
        case .humanExpense(let id):
            if let h = human(for: id) { HumanExpenseDetailView(human: h) }
        }
    }

    private func pet(for id: PersistentIdentifier) -> Pet? {
        pets.first { $0.persistentModelID == id }
    }

    private func human(for id: PersistentIdentifier) -> Human? {
        allHumans.first { $0.persistentModelID == id }
    }

    // MARK: - Aggregate Subtitles

    private var healthSubtitle: String {
        let total = activePets.flatMap { $0.healthLogs }.count
        return total > 0 ? "\(total)条健康记录" : "\(activePets.count)只宠物"
    }
    private var weightSubtitle: String {
        let total = activePets.flatMap { $0.weightLogs }.count
        return total > 0 ? "\(total)条体重记录" : "\(activePets.count)只宠物"
    }
    private var foodSubtitle: String {
        let todayLogs = activePets.flatMap { $0.careLogs }.filter {
            $0.careType == .feeding && Calendar.current.isDateInToday($0.date)
        }
        return todayLogs.isEmpty ? "今日未喂食" : "今日喂食\(todayLogs.count)次"
    }
    private var walkSubtitle: String {
        let dogs = activePets.filter { $0.species.lowercased().contains("狗") || $0.species.lowercased().contains("dog") }
        return "\(dogs.count)只犬"
    }
    private var pottySubtitle: String {
        let todayLogs = activePets.flatMap { $0.pottyLogs }.filter {
            Calendar.current.isDateInToday($0.date)
        }
        return todayLogs.isEmpty ? "今日暂无记录" : "今日\(todayLogs.count)次"
    }
    private var expenseSubtitle: String {
        let total = activePets.flatMap { $0.expenseLogs }.count
        return total > 0 ? "\(total)条花费记录" : "\(activePets.count)只宠物"
    }
    private var momentsSubtitle: String {
        let total = activePets.map { $0.photoLogs.count }.reduce(0, +)
        return total > 0 ? "\(total)个时刻" : "\(activePets.count)只宠物"
    }
    private var hasDogs: Bool {
        activePets.contains { $0.species.lowercased().contains("狗") || $0.species.lowercased().contains("dog") }
    }

    // MARK: - Row / Header Builders

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.07))
    }

    @ViewBuilder
    private func fmRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowSeparatorTint(.white.opacity(0.08))
    }

    @ViewBuilder
    private func fmSectionHeader(icon: String, title: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.goLime.opacity(0.8))
            Text(title)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.goLime.opacity(0.6))
                .tracking(2)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - Shared Pet Avatar (used by FeatureAggregateView & PetAllFeaturesSheet)

struct FMPetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: pet.themeColorHex.isEmpty ? "233BFF" : pet.themeColorHex).opacity(0.3))
                .frame(width: size, height: size)
            if let data = pet.avatarImageData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(String(pet.name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: pet.themeColorHex.isEmpty ? "233BFF" : pet.themeColorHex))
            }
        }
    }
}

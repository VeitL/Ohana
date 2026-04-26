// FeatureAggregateView.swift
// Aggregate view per feature.
// Top: "全部" chip (selected) + per-entity chips (tap → navigate to detail).
// Body: full feature content for all entities.

import SwiftUI
import SwiftData

struct FeatureAggregateView: View {
    let feature: PetFeature
    @Binding var parentPath: NavigationPath

    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.name)   private var humans: [Human]

    private var activePets: [Pet] { pets.filter { !$0.hasPassedAway } }
    private var visibleHumans: [Human] { humans.filter { $0.shouldShowOnHome } }

    private func isDog(_ pet: Pet) -> Bool {
        pet.species.lowercased().contains("狗") || pet.species.lowercased().contains("dog")
    }

    // Pets visible in chip row (walks = dogs only)
    private var chipsForFeature: [Pet] {
        feature == .walks ? activePets.filter { isDog($0) } : activePets
    }

    // Features that show human chips
    private var showHumanChips: Bool { feature == .weight || feature == .expense }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                chipRow
                Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                featureContent
            }
        }
        .navigationTitle(feature.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chip Row

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "全部" — selected state, no action
                HStack(spacing: 5) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("全部")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.goLime, in: Capsule())

                // Pet chips
                ForEach(chipsForFeature) { pet in
                    Button { parentPath.append(petDest(feature, pet: pet)) } label: {
                        entityChip(avatar: { FMPetAvatar(pet: pet, size: 24) }, name: pet.name)
                    }
                    .buttonStyle(.plain)
                }

                // Human chips (weight / expense)
                if showHumanChips {
                    ForEach(visibleHumans) { human in
                        Button { parentPath.append(humanDest(feature, human: human)) } label: {
                            entityChip(avatar: { humanAvatarView(human) }, name: human.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func entityChip<A: View>(avatar: () -> A, name: String) -> some View {
        HStack(spacing: 6) {
            avatar()
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.white.opacity(0.12), in: Capsule())
    }

    @ViewBuilder
    private func humanAvatarView(_ human: Human) -> some View {
        let color = Color(hex: human.themeColorHex.isEmpty ? "4ECDC4" : human.themeColorHex)
        ZStack {
            Circle().fill(color.opacity(0.3)).frame(width: 24, height: 24)
            if let data = human.avatarImageData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 24, height: 24).clipShape(Circle())
            } else {
                Text(String(human.name.prefix(1)))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Feature Content

    @ViewBuilder
    private var featureContent: some View {
        switch feature {
        case .weight:
            IslandWeightDashboard(standalone: false)
        case .expense:
            IslandExpenseDashboard(standalone: false)
        case .walks:
            IslandExplorationDashboard(standalone: false)
        default:
            summaryList
        }
    }

    private var summaryList: some View {
        List {
            ForEach(activePets) { pet in
                Button { parentPath.append(petDest(feature, pet: pet)) } label: {
                    HStack(spacing: 14) {
                        FMPetAvatar(pet: pet)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pet.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(subtitle(for: pet))
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
                .listRowBackground(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                .listRowSeparatorTint(.white.opacity(0.08))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Routing

    private func petDest(_ feature: PetFeature, pet: Pet) -> FMDest {
        switch feature {
        case .health:        return .petHealth(pet.persistentModelID)
        case .medications:   return .petMedications(pet.persistentModelID)
        case .food:          return .petFood(pet.persistentModelID)
        case .hygiene:       return .petHygiene(pet.persistentModelID)
        case .walks:         return .petWalks(pet.persistentModelID)
        case .potty:         return .petPotty(pet.persistentModelID)
        case .basicInfo:     return .petBasicInfo(pet.persistentModelID)
        case .documents:     return .petDocuments(pet.persistentModelID)
        case .moments:       return .petMoments(pet.persistentModelID)
        case .achievements:  return .petAchievements(pet.persistentModelID)
        case .retention:     return .petRetention(pet.persistentModelID)
        case .weight:        return .petWeight(pet.persistentModelID)
        case .expense:       return .petExpense(pet.persistentModelID)
        }
    }

    private func humanDest(_ feature: PetFeature, human: Human) -> FMDest {
        switch feature {
        case .expense: return .humanExpense(human.persistentModelID)
        default:       return .humanWeight(human.persistentModelID)
        }
    }

    // MARK: - Per-pet subtitles (for summary list)

    private func subtitle(for pet: Pet) -> String {
        switch feature {
        case .health:
            let n = pet.healthLogs.count; return n > 0 ? "\(n)条记录" : "暂无记录"
        case .medications:
            let n = pet.medications.filter { $0.isActiveToday }.count
            return n > 0 ? "当前\(n)种药物" : "暂无用药"
        case .food:
            let n = pet.careLogs.filter {
                $0.careType == .feeding && Calendar.current.isDateInToday($0.date)
            }.count
            return n > 0 ? "今日喂食\(n)次" : "今日未喂食"
        case .hygiene:
            let n = pet.careLogs.filter { $0.careType != .feeding }.count
            return n > 0 ? "\(n)条护理记录" : "暂无记录"
        case .potty:
            let n = pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
            return n > 0 ? "今日\(n)次" : "今日暂无记录"
        case .basicInfo:
            return pet.breed.isEmpty ? pet.species : pet.breed
        case .documents:
            return "\(pet.documents.count)份证件"
        case .moments:
            return "\(pet.photoLogs.count)个时刻"
        case .achievements:
            return "\(pet.milestones.count)个里程碑"
        case .retention:
            let score = [
                !pet.weightLogs.isEmpty || !pet.healthLogs.isEmpty,
                !pet.photoLogs.isEmpty || !pet.milestones.isEmpty,
                !pet.expenseLogs.isEmpty,
                !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty,
                pet.currentStreak > 0
            ].filter { $0 }.count
            return "已完善 \(score)/5 个长期模块"
        default:
            return ""
        }
    }
}

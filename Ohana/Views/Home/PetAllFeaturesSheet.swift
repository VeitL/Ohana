// PetAllFeaturesSheet.swift
// Single-pet feature entry sheet — same visual style as FunctionMenuSheet
// but routes directly to per-pet views without any aggregate step.

import SwiftUI
import SwiftData

enum PetAllFeatureDestination: Hashable {
    case health
    case medications
    case food
    case hygiene
    case walks
    case potty
    case basicInfo
    case documents
    case moments
    case timeline
    case achievements
    case retention
    case weight
    case expense
}

struct PetAllFeaturesSheet: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @State private var path: [PetAllFeatureDestination] = []

    private var isDog: Bool { pet.species.lowercased().contains("狗") || pet.species.lowercased().contains("dog") }
    private var archiveSnapshot: ArchiveMemorySnapshot { ArchiveMemorySnapshot(pet: pet) }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        petFeatureHero

                        HStack(spacing: 12) {
                            featureTile(
                                icon: "fork.knife",
                                color: Color(hex: "F59E0B"),
                                title: "饮食",
                                value: todayFeedMetric,
                                subtitle: foodSub,
                                destination: .food,
                                height: 142
                            )
                            featureTile(
                                icon: "cross.fill",
                                color: Color(hex: "EF4444"),
                                title: "健康",
                                value: "\(pet.healthLogs.count)",
                                subtitle: healthSub,
                                destination: .health,
                                height: 142
                            )
                        }

                        HStack(spacing: 12) {
                            featureTile(
                                icon: "scalemass.fill",
                                color: Color(hex: "16A34A"),
                                title: "体重",
                                value: latestWeightText,
                                subtitle: weightSub,
                                destination: .weight,
                                height: 156
                            )
                            VStack(spacing: 12) {
                                compactFeatureTile(
                                    icon: "pills.fill",
                                    color: Color(hex: "8B5CF6"),
                                    title: "用药",
                                    subtitle: medSub,
                                    destination: .medications
                                )
                                compactFeatureTile(
                                    icon: "bubbles.and.sparkles.fill",
                                    color: Color(hex: "06B6D4"),
                                    title: "清洁护理",
                                    subtitle: hygieneSub,
                                    destination: .hygiene
                                )
                            }
                        }

                        HStack(spacing: 12) {
                            if isDog {
                                featureTile(
                                    icon: "figure.walk",
                                    color: Color(hex: "38BDF8"),
                                    title: "遛狗",
                                    value: weekWalkText,
                                    subtitle: walkSub,
                                    destination: .walks,
                                    height: 138
                                )
                            }
                            featureTile(
                                icon: "drop.fill",
                                color: Color(hex: "D97706"),
                                title: "便便",
                                value: todayPottyMetric,
                                subtitle: pottySub,
                                destination: .potty,
                                height: 138
                            )
                            featureTile(
                                icon: "creditcard.fill",
                                color: Color(hex: "F97316"),
                                title: "花费",
                                value: expenseMetric,
                                subtitle: expenseSub,
                                destination: .expense,
                                height: 138
                            )
                        }

                        archiveBento
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("\(pet.name) 的功能")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.goLime)
                }
            }
            .navigationDestination(for: PetAllFeatureDestination.self) { dest in
                destView(dest)
            }
        }
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func destView(_ dest: PetAllFeatureDestination) -> some View {
        switch dest {
        case .health:        PetHealthDetailView(pet: pet, isModal: false)
        case .medications:   PetMedicationView(pet: pet)
        case .food:          PetFoodManagementView(pet: pet)
        case .hygiene:       PetHygieneDetailView(pet: pet)
        case .walks:         WalkSummarySheet(pet: pet)
        case .potty:         PottyOverviewView(pet: pet)
        case .basicInfo:     PetBasicInfoDetailView(pet: pet)
        case .documents:     DocumentsListView(pet: pet)
        case .moments:       PetMomentsHubView(pet: pet)
        case .timeline:      PetUnifiedTimelineSheet(pet: pet)
        case .achievements:  AchievementWallView(pet: pet)
        case .retention:     PetRetentionHubView(pet: pet)
        case .weight:        WeightHistoryView(pet: pet)
        case .expense:       ExpenseHistoryView(pet: pet)
        }
    }

    // MARK: - Subtitles

    private var healthSub: String  {
        let n = pet.healthLogs.count; return n > 0 ? "\(n)条记录" : "暂无记录"
    }
    private var weightSub: String  {
        let n = pet.weightLogs.count; return n > 0 ? "\(n)条记录" : "暂无记录"
    }
    private var medSub: String     {
        let n = pet.medications.filter { $0.isActiveToday }.count
        return n > 0 ? "当前\(n)种药物" : "暂无用药"
    }
    private var foodSub: String    {
        let n = pet.careLogs.filter { $0.careType == .feeding && Calendar.current.isDateInToday($0.date) }.count
        return n > 0 ? "今日喂食\(n)次" : "今日未喂食"
    }
    private var hygieneSub: String {
        let n = pet.careLogs.filter { $0.careType != .feeding }.count
        return n > 0 ? "\(n)条护理记录" : "暂无记录"
    }
    private var walkSub: String    {
        let n = pet.walkLogs.count; return n > 0 ? "\(n)次遛狗" : "暂无记录"
    }
    private var pottySub: String   {
        let n = pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
        return n > 0 ? "今日\(n)次" : "今日暂无记录"
    }
    private var expenseSub: String {
        let n = pet.expenseLogs.count; return n > 0 ? "\(n)条花费记录" : "暂无记录"
    }
    private var momentsSub: String {
        let n = pet.photoLogs.count; return n > 0 ? "\(n)个时刻" : "暂无时刻"
    }
    private var basicInfoSub: String {
        if !pet.breed.isEmpty { return pet.breed }
        if !pet.species.isEmpty { return pet.species }
        return "完善基本信息"
    }
    private var documentsSub: String {
        let documentCount = pet.documents.count
        let insuranceCount = pet.insurances.count
        if documentCount > 0 && insuranceCount > 0 {
            return "\(documentCount)份证件 · \(insuranceCount)份保险"
        }
        if documentCount > 0 { return "\(documentCount)份证件" }
        if insuranceCount > 0 { return "\(insuranceCount)份保险" }
        return "证件/保险资料"
    }
    private var timelineSub: String {
        let total = pet.photoLogs.count + pet.milestones.count + pet.healthLogs.count + pet.weightLogs.count
        return total > 0 ? "\(total)条记录" : "暂无记录"
    }
    private var achievementsSub: String {
        let n = pet.milestones.count
        return n > 0 ? "\(n)个里程碑" : "暂无成就"
    }
    private var retentionSub: String {
        "长期模块 \(archiveSnapshot.score)/5"
    }

    private var todayFeedMetric: String {
        "\(pet.careLogs.filter { $0.careType == .feeding && Calendar.current.isDateInToday($0.date) }.count)"
    }

    private var todayPottyMetric: String {
        "\(pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count)"
    }

    private var latestWeightText: String {
        guard let latest = pet.weightLogs.sorted(by: { $0.date > $1.date }).first else { return "--" }
        return String(format: "%.1f", latest.weightInKg)
    }

    private var weekWalkText: String {
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let km = pet.walkLogs
            .filter { $0.startDate >= start }
            .reduce(0.0) { $0 + $1.distanceMeters } / 1000
        return km >= 10 ? String(format: "%.0fkm", km) : String(format: "%.1fkm", km)
    }

    private var expenseMetric: String {
        let total = pet.expenseLogs.reduce(0.0) { $0 + $1.amount }
        return AppCurrency.formatCompact(total)
    }

    // MARK: - Bento Builders

    private var petFeatureHero: some View {
        NavigationLink(value: PetAllFeatureDestination.retention) {
            ZStack(alignment: .topLeading) {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                        SIMD2(0.0, 0.5), SIMD2(0.55, 0.35), SIMD2(1.0, 0.5),
                        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                    ],
                    colors: [
                        Color(hex: pet.themeColorHex).mix(with: .white, by: 0.22),
                        Color(hex: "C8FF00").opacity(0.9),
                        Color(hex: "38BDF8").opacity(0.65),
                        Color(hex: pet.themeColorHex).opacity(0.85),
                        Color(hex: "1A2E8A"),
                        Color(hex: "F97316").opacity(0.72),
                        Color(hex: "0C1640"),
                        Color(hex: pet.themeColorHex).mix(with: .black, by: 0.2),
                        Color(hex: "050816")
                    ]
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("OHANA OS")
                                .font(OhanaFont.caption2(.black))
                                .tracking(2.6)
                                .foregroundStyle(.white.opacity(0.55))
                            Text(pet.name)
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.62)
                            Text(pet.breed.isEmpty ? pet.species : "\(pet.species) · \(pet.breed)")
                                .font(OhanaFont.caption(.bold))
                                .foregroundStyle(.white.opacity(0.62))
                                .lineLimit(1)
                        }
                        Spacer()
                        petAvatar(size: 54)
                    }

                    HStack(spacing: 9) {
                        heroChip(title: "今日照护", value: "\(todayCareCount)")
                        heroChip(title: "记录", value: "\(pet.careLogs.count + pet.healthLogs.count + pet.weightLogs.count)")
                        heroChip(title: "档案", value: "\(archiveScore)/5")
                    }
                }
                .padding(18)

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 84, weight: .black))
                    .foregroundStyle(.white.opacity(0.08))
                    .offset(x: 250, y: 78)
            }
            .frame(height: 188)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: Color(hex: pet.themeColorHex).opacity(0.28), radius: 22, y: 12)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var archiveBento: some View {
        let snapshot = archiveSnapshot
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "folder.fill", title: "档案与记忆", label: "\(snapshot.score)/\(snapshot.total)")

            HStack(spacing: 12) {
                featureTile(
                    icon: snapshot.nextStep.icon,
                    color: Color.goLime,
                    title: "档案完整度",
                    value: "\(snapshot.score)/\(snapshot.total)",
                    subtitle: "下一步 · \(snapshot.nextStep.title)",
                    destination: snapshot.nextStep.destination,
                    height: 156
                )
                VStack(spacing: 12) {
                    compactFeatureTile(
                        icon: "person.fill",
                        color: Color(hex: "6B82C4"),
                        title: "基本信息",
                        subtitle: basicInfoSub,
                        destination: .basicInfo
                    )
                    compactFeatureTile(
                        icon: "doc.fill",
                        color: Color(hex: "94A3B8"),
                        title: "证件保障",
                        subtitle: documentsSub,
                        destination: .documents
                    )
                }
            }

            HStack(spacing: 12) {
                compactFeatureTile(
                    icon: "sparkles.rectangle.stack.fill",
                    color: Color.goPrimary,
                    title: "成长档案",
                    subtitle: retentionSub,
                    destination: .retention
                )
                compactFeatureTile(
                    icon: "clock.arrow.circlepath",
                    color: Color(hex: "8B5CF6"),
                    title: "时间轴",
                    subtitle: timelineSub,
                    destination: .timeline
                )
            }

            HStack(spacing: 12) {
                compactFeatureTile(
                    icon: "sparkles",
                    color: Color(hex: "EC4899"),
                    title: "重要时刻",
                    subtitle: momentsSub,
                    destination: .moments
                )
                compactFeatureTile(
                    icon: "trophy.fill",
                    color: Color(hex: "F59E0B"),
                    title: "成就",
                    subtitle: achievementsSub,
                    destination: .achievements
                )
            }
        }
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var todayCareCount: Int {
        let cal = Calendar.current
        let care = pet.careLogs.filter { cal.isDateInToday($0.date) }.count
        let potty = pet.pottyLogs.filter { cal.isDateInToday($0.date) }.count
        let walks = pet.walkLogs.filter { cal.isDateInToday($0.startDate) }.count
        return care + potty + walks
    }

    private var archiveScore: Int {
        archiveSnapshot.score
    }

    private func featureTile(
        icon: String,
        color: Color,
        title: String,
        value: String,
        subtitle: String,
        destination: PetAllFeatureDestination,
        height: CGFloat
    ) -> some View {
        NavigationLink(value: destination) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(.white.opacity(0.36))
                }
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 29, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(subtitle)
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.28), Color.white.opacity(0.07), Color.black.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.11), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func compactFeatureTile(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        destination: PetAllFeatureDestination
    ) -> some View {
        NavigationLink(value: destination) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Spacer(minLength: 0)
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(.white.opacity(0.43))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, maxHeight: 72, alignment: .leading)
            .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.09), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(.white)
            Text(title)
                .font(OhanaFont.caption2(.bold))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func petAvatar(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: size, height: size)
            if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(pet.speciesEmoji)
                    .font(.system(size: size * 0.48))
            }
        }
    }

    // MARK: - Row / Header Builders

    private var rowBg: some View {
        RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07))
    }

    @ViewBuilder
    private func row(icon: String, color: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: color).opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: color))
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
    private func sectionHeader(icon: String, title: String, label: String) -> some View {
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

enum ArchiveMemoryNextStepKind: Equatable {
    case basicInfo
    case documents
    case moments
    case weight
    case retention
}

struct ArchiveMemoryNextStep {
    let kind: ArchiveMemoryNextStepKind
    let title: String
    let subtitle: String
    let icon: String

    var destination: PetAllFeatureDestination {
        switch kind {
        case .basicInfo:
            return .basicInfo
        case .documents:
            return .documents
        case .moments:
            return .moments
        case .weight:
            return .weight
        case .retention:
            return .retention
        }
    }
}

struct ArchiveMemorySnapshot {
    let score: Int
    let total: Int
    let nextStep: ArchiveMemoryNextStep

    init(pet: Pet) {
        let hasBasicProfile = Self.hasBasicProfile(pet)
        let hasHealthOrWeight = !pet.healthLogs.isEmpty || !pet.weightLogs.isEmpty
        let hasMemory = !pet.photoLogs.isEmpty || !pet.milestones.isEmpty
        let hasProtection = !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty
        let hasContinuity = pet.currentStreak > 0 || !pet.milestones.isEmpty
        let checks = [hasBasicProfile, hasHealthOrWeight, hasMemory, hasProtection, hasContinuity]

        self.score = checks.filter { $0 }.count
        self.total = checks.count
        self.nextStep = Self.nextStep(
            hasBasicProfile: hasBasicProfile,
            hasDocumentsOrInsurance: !pet.documents.isEmpty || !pet.insurances.isEmpty,
            hasMemory: hasMemory,
            hasHealthOrWeight: hasHealthOrWeight
        )
    }

    private static func hasBasicProfile(_ pet: Pet) -> Bool {
        !pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !pet.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !pet.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        pet.birthday != nil &&
        pet.homeDate != nil
    }

    private static func nextStep(
        hasBasicProfile: Bool,
        hasDocumentsOrInsurance: Bool,
        hasMemory: Bool,
        hasHealthOrWeight: Bool
    ) -> ArchiveMemoryNextStep {
        if !hasBasicProfile {
            return ArchiveMemoryNextStep(
                kind: .basicInfo,
                title: "完善基础档案",
                subtitle: "补充生日、品种或到家日",
                icon: "person.fill"
            )
        }
        if !hasDocumentsOrInsurance {
            return ArchiveMemoryNextStep(
                kind: .documents,
                title: "添加证件/保障",
                subtitle: "上传疫苗、证件或保险资料",
                icon: "doc.badge.plus"
            )
        }
        if !hasMemory {
            return ArchiveMemoryNextStep(
                kind: .moments,
                title: "留下第一段回忆",
                subtitle: "添加照片或重要时刻",
                icon: "camera.fill"
            )
        }
        if !hasHealthOrWeight {
            return ArchiveMemoryNextStep(
                kind: .weight,
                title: "补一条健康基线",
                subtitle: "记录体重或健康档案",
                icon: "scalemass.fill"
            )
        }
        return ArchiveMemoryNextStep(
            kind: .retention,
            title: "查看成长档案",
            subtitle: "回顾长期趋势与照护故事",
            icon: "sparkles.rectangle.stack.fill"
        )
    }
}

// PetAllFeaturesSheet.swift
// Single-pet feature entry sheet — same visual style as FunctionMenuSheet
// but routes directly to per-pet views without any aggregate step.

import SwiftUI
import SwiftData

struct PetAllFeaturesSheet: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()

    private var isDog: Bool { pet.species.lowercased().contains("狗") || pet.species.lowercased().contains("dog") }

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
                                destination: .petFood(pet.persistentModelID),
                                height: 142
                            )
                            featureTile(
                                icon: "cross.fill",
                                color: Color(hex: "EF4444"),
                                title: "健康",
                                value: "\(pet.healthLogs.count)",
                                subtitle: healthSub,
                                destination: .petHealth(pet.persistentModelID),
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
                                destination: .petWeight(pet.persistentModelID),
                                height: 156
                            )
                            VStack(spacing: 12) {
                                compactFeatureTile(
                                    icon: "pills.fill",
                                    color: Color(hex: "8B5CF6"),
                                    title: "用药",
                                    subtitle: medSub,
                                    destination: .petMedications(pet.persistentModelID)
                                )
                                compactFeatureTile(
                                    icon: "bubbles.and.sparkles.fill",
                                    color: Color(hex: "06B6D4"),
                                    title: "清洁护理",
                                    subtitle: hygieneSub,
                                    destination: .petHygiene(pet.persistentModelID)
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
                                    destination: .petWalks(pet.persistentModelID),
                                    height: 138
                                )
                            }
                            featureTile(
                                icon: "drop.fill",
                                color: Color(hex: "D97706"),
                                title: "便便",
                                value: todayPottyMetric,
                                subtitle: pottySub,
                                destination: .petPotty(pet.persistentModelID),
                                height: 138
                            )
                            featureTile(
                                icon: "creditcard.fill",
                                color: Color(hex: "F97316"),
                                title: "花费",
                                value: expenseMetric,
                                subtitle: expenseSub,
                                destination: .petExpense(pet.persistentModelID),
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
            .navigationDestination(for: FMDest.self) { dest in
                destView(dest)
            }
        }
    }

    // MARK: - Destination Views

    @ViewBuilder
    private func destView(_ dest: FMDest) -> some View {
        switch dest {
        case .petHealth(_):        PetHealthDetailView(pet: pet, isModal: false)
        case .petMedications(_):   PetMedicationView(pet: pet)
        case .petFood(_):          PetFoodManagementView(pet: pet)
        case .petHygiene(_):       PetHygieneDetailView(pet: pet)
        case .petWalks(_):         WalkSummarySheet(pet: pet)
        case .petPotty(_):         PottyOverviewView(pet: pet)
        case .petBasicInfo(_):     PetBasicInfoDetailView(pet: pet)
        case .petDocuments(_):     DocumentsListView(pet: pet)
        case .petMoments(_):       PetMomentsHubView(pet: pet)
        case .petAchievements(_):  AchievementWallView(pet: pet)
        case .petRetention(_):     PetRetentionHubView(pet: pet)
        case .petWeight(_):        WeightHistoryView(pet: pet)
        case .petExpense(_):       ExpenseHistoryView(pet: pet)
        // The following FMDest cases are cross-entity / aggregate routes; they
        // are not reachable from a single-pet sheet. Assert in debug to catch
        // accidental wiring, fall back to EmptyView in release.
        case .featureGroup(_):
            let _ = { assertionFailure("PetAllFeaturesSheet: featureGroup route is unreachable from single-pet sheet") }()
            EmptyView()
        case .featureAggregate(_):
            let _ = { assertionFailure("PetAllFeaturesSheet: featureAggregate route is unreachable from single-pet sheet") }()
            EmptyView()
        case .humanWeight(_):
            let _ = { assertionFailure("PetAllFeaturesSheet: humanWeight route is unreachable from single-pet sheet") }()
            EmptyView()
        case .humanExpense(_):
            let _ = { assertionFailure("PetAllFeaturesSheet: humanExpense route is unreachable from single-pet sheet") }()
            EmptyView()
        case .plantsDashboard, .wealthDashboard, .bountyBoard, .familyWeeklyReport, .careLedgerAnalysis, .reminderObservability, .coconutShop, .gacha, .calendar:
            let _ = { assertionFailure("PetAllFeaturesSheet: island-wide route is unreachable from single-pet sheet") }()
            EmptyView()
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
    private var retentionSub: String {
        let score = [
            !pet.weightLogs.isEmpty || !pet.healthLogs.isEmpty,
            !pet.photoLogs.isEmpty || !pet.milestones.isEmpty,
            !pet.expenseLogs.isEmpty,
            !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty,
            pet.currentStreak > 0
        ].filter { $0 }.count
        return "长期模块 \(score)/5"
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
        if total >= 10_000 { return String(format: "¥%.0fk", total / 1000) }
        if total >= 100 { return String(format: "¥%.0f", total) }
        return total > 0 ? String(format: "¥%.1f", total) : "¥0"
    }

    // MARK: - Bento Builders

    private var petFeatureHero: some View {
        Button {
            path.append(FMDest.petRetention(pet.persistentModelID))
        } label: {
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
        }
        .buttonStyle(.plain)
    }

    private var archiveBento: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("档案与记忆", systemImage: "folder.fill")
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("ARCHIVE")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
                    .tracking(2)
            }
            .padding(.horizontal, 2)

            HStack(spacing: 12) {
                compactFeatureTile(
                    icon: "sparkles.rectangle.stack.fill",
                    color: Color.goPrimary,
                    title: "成长档案",
                    subtitle: retentionSub,
                    destination: .petRetention(pet.persistentModelID)
                )
                compactFeatureTile(
                    icon: "person.fill",
                    color: Color(hex: "6B82C4"),
                    title: "基本信息",
                    subtitle: pet.breed.isEmpty ? pet.species : pet.breed,
                    destination: .petBasicInfo(pet.persistentModelID)
                )
            }
            HStack(spacing: 12) {
                compactFeatureTile(
                    icon: "doc.fill",
                    color: Color(hex: "94A3B8"),
                    title: "证件保障",
                    subtitle: "\(pet.documents.count)份证件",
                    destination: .petDocuments(pet.persistentModelID)
                )
                compactFeatureTile(
                    icon: "sparkles",
                    color: Color(hex: "EC4899"),
                    title: "重要时刻",
                    subtitle: momentsSub,
                    destination: .petMoments(pet.persistentModelID)
                )
                compactFeatureTile(
                    icon: "trophy.fill",
                    color: Color(hex: "F59E0B"),
                    title: "成就",
                    subtitle: "\(pet.milestones.count)个里程碑",
                    destination: .petAchievements(pet.persistentModelID)
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
        [
            !pet.weightLogs.isEmpty || !pet.healthLogs.isEmpty,
            !pet.photoLogs.isEmpty || !pet.milestones.isEmpty,
            !pet.expenseLogs.isEmpty,
            !pet.documents.isEmpty || !pet.insurances.isEmpty || !pet.medications.isEmpty,
            pet.currentStreak > 0
        ].filter { $0 }.count
    }

    private func featureTile(
        icon: String,
        color: Color,
        title: String,
        value: String,
        subtitle: String,
        destination: FMDest,
        height: CGFloat
    ) -> some View {
        Button { path.append(destination) } label: {
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
        }
        .buttonStyle(.plain)
    }

    private func compactFeatureTile(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        destination: FMDest
    ) -> some View {
        Button { path.append(destination) } label: {
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

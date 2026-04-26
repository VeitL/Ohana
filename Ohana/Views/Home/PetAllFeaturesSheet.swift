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

                List {
                    // ── Section 1: 健康管理 ──
                    Section {
                        row(icon: "cross.fill",        color: "EF4444", title: "健康档案",  subtitle: healthSub)   { path.append(FMDest.petHealth(pet.persistentModelID)) }
                        row(icon: "scalemass.fill",    color: "16A34A", title: "体重记录",  subtitle: weightSub)   { path.append(FMDest.petWeight(pet.persistentModelID)) }
                        row(icon: "pills.fill",        color: "8B5CF6", title: "用药管理",  subtitle: medSub)      { path.append(FMDest.petMedications(pet.persistentModelID)) }
                    } header: {
                        sectionHeader(icon: "cross.fill", title: "健康管理", label: "HEALTH")
                    }
                    .listRowBackground(rowBg)

                    // ── Section 2: 日常生活 ──
                    Section {
                        row(icon: "fork.knife",        color: "F59E0B", title: "饮食管理",  subtitle: foodSub)     { path.append(FMDest.petFood(pet.persistentModelID)) }
                        row(icon: "bubbles.and.sparkles.fill", color: "06B6D4", title: "清洁护理", subtitle: hygieneSub) { path.append(FMDest.petHygiene(pet.persistentModelID)) }
                        if isDog {
                            row(icon: "figure.walk",   color: "0EA5E9", title: "遛狗记录",  subtitle: walkSub)     { path.append(FMDest.petWalks(pet.persistentModelID)) }
                        }
                        row(icon: "drop.fill",         color: "D97706", title: "便便记录",  subtitle: pottySub)    { path.append(FMDest.petPotty(pet.persistentModelID)) }
                        row(icon: "creditcard.fill",   color: "D97706", title: "花费记录",  subtitle: expenseSub)  { path.append(FMDest.petExpense(pet.persistentModelID)) }
                    } header: {
                        sectionHeader(icon: "sun.max.fill", title: "日常生活", label: "DAILY LIFE")
                    }
                    .listRowBackground(rowBg)

                    // ── Section 3: 档案与记忆 ──
                    Section {
                        row(icon: "sparkles.rectangle.stack.fill", color: "C8FF00", title: "成长档案", subtitle: retentionSub) { path.append(FMDest.petRetention(pet.persistentModelID)) }
                        row(icon: "person.fill",       color: "6B82C4", title: "基本信息",  subtitle: pet.breed.isEmpty ? pet.species : pet.breed) { path.append(FMDest.petBasicInfo(pet.persistentModelID)) }
                        row(icon: "doc.fill",          color: "6B7280", title: "证件保障",  subtitle: "\(pet.documents.count)份证件")               { path.append(FMDest.petDocuments(pet.persistentModelID)) }
                        row(icon: "sparkles",          color: "C8FF00", title: "重要时刻",  subtitle: momentsSub)  { path.append(FMDest.petMoments(pet.persistentModelID)) }
                        row(icon: "trophy.fill",       color: "F59E0B", title: "成就",      subtitle: "\(pet.milestones.count)个里程碑")             { path.append(FMDest.petAchievements(pet.persistentModelID)) }
                    } header: {
                        sectionHeader(icon: "folder.fill", title: "档案与记忆", label: "ARCHIVE")
                    }
                    .listRowBackground(rowBg)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
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

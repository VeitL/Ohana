//
//  PetDetailView.swift
//  Ohana
//
//  HUD 瀑布流仪表盘 — Phase 26 重构
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Tab 兼容保留（ContentView 仍引用此 enum）
enum PetDetailTab: String, CaseIterable {
    case overview = "概览"
    case health   = "健康"
    case records  = "记录"

    var icon: String {
        switch self {
        case .overview: return "pawprint.fill"
        case .health:   return "heart.text.clipboard"
        case .records:  return "list.clipboard"
        }
    }
}

// MARK: - Unified Timeline Item
struct UnifiedLogItem: Identifiable {
    let id: UUID
    let date: Date
    let type: String        // "walk" | "potty" | "health" | "expense" | "weight"
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
}

// MARK: - Main View
struct PetDetailView: View {
    let pet: Pet
    var initialTab: PetDetailTab = .overview   // 保留兼容
    var openHealthOnAppear: Bool = false       // 任务3：Quick Access health路由

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet      = false
    @State private var showingCalendar       = false
    @State private var showingDeleteConfirm  = false
    @State private var deleteConfirmName     = ""
    @State private var showingClearConfirm   = false
    @State private var showingWeightHistory  = false
    @State private var showingExpenseHistory = false
    @State private var showingPetInfo        = false
    @State private var showingSitterCard     = false
    @State private var showingAchievements   = false
    @State private var showingPottyOverview  = false
    @State private var showingWalkSummary    = false
    @State private var showingDocuments      = false
    @State private var showingAddWeight      = false
    @State private var quickWeightInput      = ""
    @State private var healthRecordType: HealthLogType? = nil
    @State private var showingVaccinePassport  = false
    @State private var showingFoodManagement   = false
    @State private var showingHealthDetail     = false
    @State private var showingQuickPotty       = false
    @State private var showingQuickExpense     = false
    @State private var showingCoconutLog       = false
    @State private var showingMilestones       = false
    @State private var showingRainbowBridgeAlert = false
    @State private var showingUndoPassingAlert   = false
    @State private var rainbowBridgeDate         = Date()
    
    var body: some View {
        ZStack {
            ArkBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {

                    // ── L1: Hero 横排卡 ──────────────────────────────────
                    PetHeroRow(pet: pet, onTap: { showingPetInfo = true })

                    // ── L1.5: HUD 发光环 + 活力大字（无边框悬浮）─────────
                    PetHUDVitalSection(pet: pet)

                    // ── L2: 智能预警横滚区（有警告时才出现）──────────────
                    PetAlertScrollSection(pet: pet)

                    // ── L3: 透明图表仪表盘（体重·遛狗·噗噗·花费·余粮）U17: 移到免疫健康之上
                    PetChartDashboard(
                        pet: pet,
                        onWeight:  { showingWeightHistory  = true },
                        onWalk:    { showingWalkSummary    = true },
                        onPotty:   { showingPottyOverview  = true },
                        onExpense: { showingExpenseHistory = true },
                        onFood:    { showingFoodManagement = true },
                        showingAddWeight: $showingAddWeight,
                        quickWeightInput: $quickWeightInput,
                        modelContext: modelContext
                    )

                    // ── L3.5: 免疫健康中枢卡（快动作 + 疫苗本 + 免疫状态）──
                    PetHealthHubCard(pet: pet, onRecord: { type in
                        healthRecordType = type
                    }, onViewPassport: {
                        showingVaccinePassport = true
                    }, onViewDetail: {
                        showingHealthDetail = true
                    })
                    .padding(.horizontal, 16)

                    // ── L4: 护理卡 ──────────────────────────────────────
                    PetHygieneCard(pet: pet)
                        .padding(.horizontal, 16)

                    // ── L4.5: 饮食与排泄卡片（task4: 内联快速打卡）
                    DietCardWithQuickActions(
                        pet: pet,
                        onOpenDetail: { showingFoodManagement = true }
                    )
                    .padding(.horizontal, 16)

                    // ── L5: 证件 + 里程碑 + 成就墙（并列三列 compact）────────────
                    HStack(alignment: .top, spacing: 10) {
                        // 证件卡
                        NavigationLink { DocumentsListView(pet: pet) } label: {
                            compactDocumentsCard
                        }.buttonStyle(.plain)
                        // 里程碑卡
                        Button { showingMilestones = true } label: {
                            compactMilestonesCard
                        }.buttonStyle(.plain)
                        // 成就墙卡
                        Button { showingAchievements = true } label: {
                            compactAchievementsCard
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)

                    // ── L7: 时间轴（岁月史书）────────────────────────────
                    PetUnifiedTimeline(pet: pet)
                        .padding(.horizontal, 16)

                    // ── L7.5: Rainbow Bridge 离世操作区 ─────────────────
                    rainbowBridgeSection
                        .padding(.horizontal, 16)

                    // ── L8: 危险区域 ───────────────────────────────────────
                    deleteDangerZone
                        .padding(.horizontal, 16)

                    Spacer(minLength: 60)
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            IslandQuestEngine.markVisited()
            if openHealthOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showingHealthDetail = true
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // 全局椰子余额胶囊
                    CoconutBalanceCapsule {
                        showingCoconutLog = true
                    }
                    
                    Button { showingSitterCard = true } label: {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Button { showingCalendar = true } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet)        { EditPetSheet(pet: pet) }
        .sheet(isPresented: $showingCalendar)         { CalendarView(preselectedPetId: pet.id.uuidString) }
        .sheet(isPresented: $showingSitterCard)       { SitterCardPreviewSheet(pet: pet) }
        .sheet(isPresented: $showingAchievements)     { AchievementWallView(pet: pet) }
        .sheet(isPresented: $showingPottyOverview)    { PottyOverviewView(pet: pet) }
        .sheet(isPresented: $showingWalkSummary)      { WalkSummarySheet(pet: pet) }
        .sheet(isPresented: $showingVaccinePassport)  { VaccinePassportView(pet: pet) }
        .sheet(isPresented: $showingFoodManagement)   { PetFoodManagementView(pet: pet) }
        .sheet(isPresented: $showingQuickPotty)       { QuickPottySheet(pet: pet).presentationDetents([.height(320)]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showingQuickExpense)     { AddExpenseSheet(pet: pet).presentationDetents([.medium]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showingCoconutLog)       { CoconutLogView() }
        .sheet(item: $healthRecordType)               { AddHealthRecordSheet(pet: pet, type: $0) }
        .navigationDestination(isPresented: $showingWeightHistory)  { WeightHistoryView(pet: pet) }
        .navigationDestination(isPresented: $showingExpenseHistory) { ExpenseHistoryView(pet: pet) }
        .navigationDestination(isPresented: $showingMilestones)      { PetMilestoneListView(pet: pet) }
        .navigationDestination(isPresented: $showingPetInfo)        { PetBasicInfoDetailView(pet: pet) }
        .navigationDestination(isPresented: $showingHealthDetail)   { PetHealthDetailView(pet: pet) }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            TextField("输入宠物名字确认", text: $deleteConfirmName)
            Button("取消", role: .cancel) { deleteConfirmName = "" }
            Button("删除", role: .destructive) {
                if deleteConfirmName == pet.name {
                    deletePetWithCascade(pet)
                    dismiss()
                }
            }
        } message: { Text("请输入 \"\(pet.name)\" 确认删除。此操作不可撤销。") }
        .alert("仅清空所有记录", isPresented: $showingClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空记录", role: .destructive) { clearPetLogs() }
        } message: { Text("将删除 \(pet.name) 的所有打卡、体重、花费等记录，但保留宠物档案（名字、头像、品种等）。此操作不可撤销。") }
    }

    private func deletePetWithCascade(_ p: Pet) {
        let petIdStr = p.id.uuidString
        if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
            for event in allEvents where event.relatedEntityId == petIdStr {
                modelContext.delete(event)
            }
        }
        removeQuickAccessItems(for: p.id)
        modelContext.delete(p)
        modelContext.safeSave()
        deleteConfirmName = ""
    }

    private func removeQuickAccessItems(for petId: UUID) {
        let key = "quickActionItems_v2"
        guard let json = UserDefaults.standard.string(forKey: key),
              let data = json.data(using: .utf8),
              var items = try? JSONDecoder().decode([QuickActionItem].self, from: data) else { return }
        items.removeAll { $0.petId == petId }
        if let newData = try? JSONEncoder().encode(items),
           let newJSON = String(data: newData, encoding: .utf8) {
            UserDefaults.standard.set(newJSON, forKey: key)
        }
    }

    private func clearPetLogs() {
        for log in pet.weightLogs   { modelContext.delete(log) }
        for log in pet.expenseLogs  { modelContext.delete(log) }
        for log in pet.healthLogs   { modelContext.delete(log) }
        for log in pet.hygieneLogs  { modelContext.delete(log) }
        for log in pet.walkLogs     { modelContext.delete(log) }
        for log in pet.pottyLogs    { modelContext.delete(log) }
        for log in pet.careLogs     { modelContext.delete(log) }
        let petIdStr = pet.id.uuidString
        if let events = try? modelContext.fetch(FetchDescriptor<Event>()) {
            for event in events where event.relatedEntityId == petIdStr {
                modelContext.delete(event)
            }
        }
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // MARK: - Vaccine Banner Row
    private var vaccineBannerRow: some View {
        HStack(spacing: 14) {
            Text("💉").font(.system(size: 28))
            VStack(alignment: .leading, spacing: 3) {
                Text("疫苗本")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                let count = pet.healthLogs.filter { $0.type == "疫苗" }.count
                Text(count == 0 ? "点击添加第一条疫苗记录" : "共 \(count) 条记录")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(Color.goCardCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.goCardCyan.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Achievement Banner Row
    private var achievementBannerRow: some View {
        let achievements = AchievementManager.compute(for: pet)
        let unlocked = achievements.filter(\.isUnlocked).count
        let total    = achievements.count
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.goYellow.opacity(0.15)).frame(width: 44, height: 44)
                Text("🏆").font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("成就墙")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("\(unlocked) / \(total) 已解锁")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text("\(total > 0 ? Int(Double(unlocked)/Double(total)*100) : 0)%")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.goYellow)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.goYellow.opacity(0.15), in: Capsule())
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .goTranslucentCard(cornerRadius: 18)
    }

    // MARK: - Compact 三列卡（证件/里程碑/成就）
    private var compactDocumentsCard: some View {
        let expiring = pet.documents.filter { $0.isExpiringSoon || $0.isExpired }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.goCardCyan)
                Text("证件")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            Text("\(pet.documents.count) 份")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if !expiring.isEmpty {
                Text("\(expiring.count) 即将到期")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.goRed)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.goRed.opacity(0.12), in: Capsule())
            } else {
                Text("全部有效")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.goTeal)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.goTeal.opacity(0.12), in: Capsule())
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 18)
    }

    private var compactMilestonesCard: some View {
        let latest = pet.milestones.sorted { $0.date > $1.date }.first
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.goYellow)
                Text("里程碑")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            Text("\(pet.milestones.count)")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if let m = latest {
                Text(m.emoji + " " + m.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            } else {
                Text("暂无记录")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 18)
    }

    private var compactAchievementsCard: some View {
        let achievements = AchievementManager.compute(for: pet)
        let unlocked = achievements.filter(\.isUnlocked).count
        let total    = achievements.count
        let pct      = total > 0 ? Int(Double(unlocked) / Double(total) * 100) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("🏆").font(.system(size: 11))
                Text("成就")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
            }
            Text("\(pct)%")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Color.goYellow)
            Text("\(unlocked)/\(total) 解锁")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: 18)
    }

    // MARK: - Rainbow Bridge Section
    @ViewBuilder
    private var rainbowBridgeSection: some View {
        if pet.hasPassedAway {
            // 已离世：显示纪念信息 + 撤销入口
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text("🌈").font(.system(size: 14))
                    Text("岁月史书 · 彩虹桥彼端")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    Spacer()
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        if let d = pet.passedAwayDate {
                            Text("离世日期：\(d.formatted(.dateTime.year().month().day()))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Text("相伴 \(pet.daysTogetherAtPassing) 天 · \(pet.ageAtPassingText)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button {
                        showingUndoPassingAlert = true
                    } label: {
                        Text("撤销离世")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goYellow)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goYellow.opacity(0.1), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.goYellow.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1))
            }
            .alert("撤销离世标记", isPresented: $showingUndoPassingAlert) {
                Button("撤销", role: .destructive) {
                    RainbowBridgeService.undoPassedAway(pet: pet, context: modelContext)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清除 \(pet.name) 的离世记录，恢复为在世状态。")
            }
        } else {
            // 在世：显示「标记离世」入口
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "rainbow")
                        .foregroundStyle(Color.purple.opacity(0.6))
                        .font(.system(size: 12))
                    Text("生命终章")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Color.purple.opacity(0.6))
                        .tracking(2)
                    Spacer()
                }
                Button {
                    rainbowBridgeDate = Date()
                    showingRainbowBridgeAlert = true
                } label: {
                    HStack(spacing: 8) {
                        Text("🌈")
                        Text("标记 \(pet.name) 已离世")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.purple.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.purple.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
            .alert("确认标记离世", isPresented: $showingRainbowBridgeAlert) {
                Button("确认", role: .destructive) {
                    RainbowBridgeService.markPassedAway(
                        pet: pet, date: rainbowBridgeDate, context: modelContext)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将标记 \(pet.name) 为离世，并删除所有未来的提醒和事件。此操作可撤销。")
            }
        }
    }

    // MARK: - Delete Danger Zone
    private var deleteDangerZone: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .font(.system(size: 12))
                Text("危险区域")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goRed.opacity(0.7))
                    .tracking(2)
                Spacer()
            }
            // 按钮一：仅清空记录（次警告色）
            Button { showingClearConfirm = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("仅清空所有记录")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.goOrange)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goOrange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goOrange.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            // 按钮二：彻底删除（主危险色）
            Button { showingDeleteConfirm = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("彻底删除 \(pet.name)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.goRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.goRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.goRed.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

}

// ═══════════════════════════════════════════════════════════════
// MARK: - L1 Hero Row
// ═══════════════════════════════════════════════════════════════
private struct PetHeroRow: View {
    let pet: Pet
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    // 头像
                    ZStack {
                        Circle().fill(.white.opacity(0.1)).frame(width: 72, height: 72)
                        if let data = pet.avatarImageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFill()
                                .frame(width: 72, height: 72).clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2))
                        } else {
                            Text(pet.avatarEmoji).font(.system(size: 38))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pet.name)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        HStack(spacing: 5) {
                            if !pet.breed.isEmpty {
                                heroTag("\(pet.species) · \(pet.breed)")
                            } else {
                                heroTag(pet.species)
                            }
                            heroTag(pet.genderSymbol)
                            if pet.isNeutered { heroTag("已绝育") }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        heroStat(value: "\(pet.daysTogether)", label: "同行天", accent: .goLime)
                        heroStat(value: pet.ageText, label: "年龄", accent: .goTeal)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                }

                // 第二行：出生/到家/体重
                HStack(spacing: 0) {
                    if pet.birthday != nil {
                        heroInfoCell(icon: "birthday.cake.fill", label: "生日",
                                     value: pet.birthday?.formatted(.dateTime.month().day()) ?? "--",
                                     accent: .goYellow)
                        Divider().frame(height: 28).opacity(0.15)
                    }
                    if pet.homeDate != nil {
                        heroInfoCell(icon: "house.fill", label: "到家",
                                     value: pet.homeDate?.formatted(.dateTime.year().month().day()) ?? "--",
                                     accent: .goTeal)
                    }
                    if let w = pet.weightLogs.sorted(by: { $0.date > $1.date }).first {
                        Divider().frame(height: 28).opacity(0.15)
                        heroInfoCell(icon: "scalemass.fill", label: "体重",
                                     value: String(format: "%.1f kg", w.weight),
                                     accent: .goLime)
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            .goTranslucentCard(cornerRadius: 20)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func heroTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.white.opacity(0.1), in: Capsule())
    }

    private func heroStat(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(accent)
        }
    }

    private func heroInfoCell(icon: String, label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
// FIX 6: @Query 实时查询，确保打卡后数字立即更新
private struct PetHUDVitalSection: View {
    let pet: Pet

    @Query private var walkLogsQ: [PetWalkLog]
    @Query private var pottyLogsQ: [PetPottyLog]
    @Query private var careLogsQ: [PetCareLog]

    init(pet: Pet) {
        self.pet = pet
        let pid = pet.id
        let todayStart = Calendar.current.startOfDay(for: Date())
        let weekStart  = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        // 遛狗日志：取整周（7天）以支持点阵显示，今日遛狗次数在属性中二次过滤
        _walkLogsQ  = Query(filter: #Predicate<PetWalkLog>  { $0.pet?.id == pid && $0.startDate >= weekStart })
        // 今日便便：从今日 00:00 开始
        _pottyLogsQ = Query(filter: #Predicate<PetPottyLog> { $0.pet?.id == pid && $0.date >= todayStart })
        // 一周护理：从 6天前 00:00 开始（包含今日喜食、喜水等）
        _careLogsQ  = Query(filter: #Predicate<PetCareLog>  { $0.pet?.id == pid && $0.date >= weekStart })
    }

    private var isDog: Bool { pet.species == "狗" }

    // ── 狗：遛狗数据（全部来自 @Query，不再读 pet 关联结果集）
    private var todayWalks: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return walkLogsQ.filter { $0.startDate >= todayStart }.count
    }
    private var walkGoal: Int { 2 }
    private var walkProgress: Double { min(1.0, Double(todayWalks) / Double(walkGoal)) }
    private var weekWalks: Int { walkLogsQ.count }

    // ── 非狗：铲屎/喂食数据（全部来自 @Query，不读 pet.关联）
    private var todayPotty: Int { pottyLogsQ.count }
    private var todayFeed: Int {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return careLogsQ.filter { $0.type == "feeding" && $0.date >= todayStart }.count
    }
    private var weekActivity: Int {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        return pottyLogsQ.filter { $0.date >= weekStart }.count
             + careLogsQ.filter { $0.type == "feeding" && $0.date >= weekStart }.count
    }

    var body: some View {
        if isDog {
            dogHUD
        } else {
            nonDogHUD
        }
    }

    // MARK: 狗：遛狗环形图
    private var dogHUD: some View {
        HStack(alignment: .center, spacing: 24) {
            ZStack {
                Circle().stroke(.white.opacity(0.07), lineWidth: 10).frame(width: 110, height: 110)
                Circle()
                    .trim(from: 0, to: walkProgress)
                    .stroke(
                        AngularGradient(colors: [Color.goLime.opacity(0.6), Color.goLime, Color.goLime.opacity(0.6)], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 110, height: 110)
                    .shadow(color: Color.goLime.opacity(0.7), radius: 10)
                    .animation(.spring(response: 0.6), value: walkProgress)
                VStack(spacing: 1) {
                    Text("\(todayWalks)")
                        .font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white)
                    Text("/ \(walkGoal) 次")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Color.goLime)
                }
            }
            .padding(.leading, 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("今日遛狗")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35)).tracking(2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(weekWalks)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white).contentTransition(.numericText())
                    Text("次").font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goLime).padding(.bottom, 6)
                }
                Text("本周己出巡岛").font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
                HStack(spacing: 5) {
                    ForEach(0..<7, id: \.self) { offset in
                        let day = Calendar.current.date(byAdding: .day, value: -(6 - offset), to: Date())!
                        // 使用 @Query 来的 walkLogsQ 而非 pet.walkLogs
                        let active = walkLogsQ.contains { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
                        Circle().fill(active ? Color.goLime : Color.white.opacity(0.12))
                            .frame(width: 7, height: 7)
                            .shadow(color: active ? Color.goLime.opacity(0.5) : .clear, radius: 4)
                    }
                }.padding(.top, 2)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: 非狗：铲屎+喟食双指标
    private var nonDogHUD: some View {
        HStack(spacing: 0) {
            hudCell(
                icon: pet.species == "猫" ? "🪣" : "💩",
                label: pet.species == "猫" ? "今日铲屎" : "今日如厕",
                value: "\(todayPotty)",
                unit: "次",
                accent: Color.goYellow
            )
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 50)
            hudCell(
                icon: "🍗",
                label: "今日喂食",
                value: "\(todayFeed)",
                unit: "次",
                accent: Color.goOrange
            )
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 50)
            hudCell(
                icon: "✨",
                label: "本周活动",
                value: "\(weekActivity)",
                unit: "次",
                accent: Color.goTeal
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func hudCell(icon: String, label: String, value: String, unit: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 22))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(unit).font(.system(size: 12, weight: .bold)).foregroundStyle(accent)
            }
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L2 Smart Alert Scroll Section
// ═══════════════════════════════════════════════════════════════
private struct PetAlertScrollSection: View {
    let pet: Pet

    private var alerts: [(String, String, Color)] {
        var list: [(String, String, Color)] = []
        if pet.remainingFoodDays > 0 && pet.remainingFoodDays <= 3 {
            list.append(("⚠️", "即将断粮 · 仅剩 \(pet.remainingFoodDays) 天", .goOrange))
        }
        let now = Date()
        for doc in pet.documents {
            if let exp = doc.expiryDate, exp.timeIntervalSinceNow < 86400 * 14 && exp > now {
                let days = Calendar.current.dateComponents([.day], from: now, to: exp).day ?? 0
                list.append(("📄", "\(doc.title) 将在 \(days) 天到期", .goOrange))
            }
        }
        for log in pet.healthLogs.filter({ $0.type == "疫苗" }) {
            if let exp = log.expirationDate, exp.timeIntervalSinceNow < 86400 * 21 && exp > now {
                let days = Calendar.current.dateComponents([.day], from: now, to: exp).day ?? 0
                list.append(("💉", "\(log.type) 疫苗 \(days) 天后到期", .goRed))
            }
        }
        return list
    }

    var body: some View {
        if alerts.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                        HStack(spacing: 10) {
                            Text(alert.0).font(.system(size: 20))
                            Text(alert.1)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(alert.2.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(alert.2.opacity(0.4), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L3 Health Action Row
// ═══════════════════════════════════════════════════════════════
private struct PetHealthActionRow: View {
    let pet: Pet
    let onRecord: (HealthLogType) -> Void

    private let actions: [(String, String, Color, HealthLogType)] = [
        ("💉", "疫苗", .goCardCyan, .vaccine),
        ("🛡️", "驱虫", .goTeal,    .medication),
        ("🩺", "体检", .goYellow,  .checkup),
        ("🏥", "就诊", .goRed,     .surgery),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(actions, id: \.1) { emoji, label, accent, type in
                Button { onRecord(type) } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle().fill(accent.opacity(0.15)).frame(width: 46, height: 46)
                            Text(emoji).font(.system(size: 22))
                        }
                        Text(label)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .goTranslucentCard(cornerRadius: 20)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L3 Health Hub Card（快动作 + 疫苗本入口 + 免疫状态）
// ═══════════════════════════════════════════════════════════════
private struct PetHealthHubCard: View {
    let pet: Pet
    let onRecord: (HealthLogType) -> Void
    let onViewPassport: () -> Void
    var onViewDetail: (() -> Void)? = nil

    private let quickActions: [(String, String, Color, HealthLogType)] = [
        ("💉", "疫苗", .goCardCyan, .vaccine),
        ("🛡️", "驱虫", .goTeal,    .medication),
        ("🩺", "体检", .goYellow,  .checkup),
        ("🏥", "就诊", .goRed,     .surgery),
    ]

    private var immunityRows: [(String, String, Date?, Date?)] {
        let v = pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.sorted { $0.date > $1.date }.first
        let d = pet.healthLogs.filter { $0.type == HealthLogType.medication.rawValue }.sorted { $0.date > $1.date }.first
        let c = pet.healthLogs.filter { $0.type == HealthLogType.checkup.rawValue }.sorted { $0.date > $1.date }.first
        return [
            ("💉", "疫苗", v?.date, v.flatMap { Calendar.current.date(byAdding: .year, value: 1, to: $0.date) }),
            ("🛡️", "驱虫", d?.date, d.flatMap { Calendar.current.date(byAdding: .month, value: 3, to: $0.date) }),
            ("🩺", "体检", c?.date, c.flatMap { Calendar.current.date(byAdding: .year, value: 1, to: $0.date) }),
        ]
    }

    private var vaccineCount: Int { pet.healthLogs.filter { $0.type == HealthLogType.vaccine.rawValue }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── 顶栏：标题（可点进详情）+ 疫苗本入口
            Button { onViewDetail?() } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.goCardCyan.opacity(0.15)).frame(width: 34, height: 34)
                        Text("💉").font(.system(size: 17))
                    }
                    Text("免疫健康")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(vaccineCount == 0 ? "暂无记录" : "\(vaccineCount) 条")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

            // 疫苗本快捷入口（独立行）
            HStack {
                Spacer()
                Button(action: onViewPassport) {
                    HStack(spacing: 3) {
                        Text("疫苗本")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.goCardCyan.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.goCardCyan.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.bottom, 8)

            GoDashedDivider().padding(.horizontal, 14)

            // ── 快动作按钮行（点击直接添加记录）
            HStack(spacing: 0) {
                ForEach(quickActions, id: \.1) { emoji, label, accent, type in
                    Button { onRecord(type) } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle().fill(accent.opacity(0.14)).frame(width: 38, height: 38)
                                Text(emoji).font(.system(size: 18))
                            }
                            Text(label)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
        }
        .goTranslucentCard(cornerRadius: 20)
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L4 Bento Grid
// ═══════════════════════════════════════════════════════════════
private struct PetBentoGrid: View {
    let pet: Pet
    let onWeight:  () -> Void
    let onWalk:    () -> Void
    let onPotty:   () -> Void
    let onExpense: () -> Void
    let onAddWeight: () -> Void
    @Binding var showingAddWeight: Bool
    @Binding var quickWeightInput: String
    let modelContext: ModelContext

    private var latestWeight: PetWeightLog? {
        pet.weightLogs.sorted { $0.date > $1.date }.first
    }
    private var monthTotal: Double {
        pet.expenseLogs.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    private var todayPotty: Int {
        pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
    }
    private var lastWalk: PetWalkLog? {
        pet.walkLogs.sorted { $0.startDate > $1.startDate }.first
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // ── 体重（宽卡）──
                Button(action: onWeight) {
                    bentoWeightCard
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // ── 花费（方卡）──
                Button(action: onExpense) {
                    bentoExpenseCard
                }
                .buttonStyle(.plain)
                .frame(width: 130)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                // ── 遛狗（宽卡，仅狗）──
                if pet.species == "狗" {
                    Button(action: onWalk) { bentoWalkCard }
                        .buttonStyle(.plain).frame(maxWidth: .infinity)
                } else {
                    // 余粮（宽卡，非狗品种）
                    bentoFoodCard.frame(maxWidth: .infinity)
                }

                // ── 噗噗（方卡）──
                Button(action: onPotty) { bentoPottyCard }
                    .buttonStyle(.plain).frame(width: 130)
            }
            .padding(.horizontal, 16)

            // ── 余粮（仅狗显示，独立全宽）──
            if pet.species == "狗" && pet.dailyPortionGrams > 0 {
                bentoFoodCard.padding(.horizontal, 16)
            }
        }
    }

    // 体重卡
    private var bentoWeightCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("体重", systemImage: "scalemass")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goTeal)
                Spacer()
                Button {
                    showingAddWeight.toggle()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.goLime)
                }
            }
            if let w = latestWeight {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", w.weight))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("kg").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.goTeal)
                }
            } else {
                Text("--").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.3))
            }
            if showingAddWeight {
                HStack(spacing: 8) {
                    TextField("0.0", text: $quickWeightInput)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        if let w = Double(quickWeightInput.replacingOccurrences(of: ",", with: ".")) {
                            let log = PetWeightLog(date: Date(), weight: w, pet: pet)
                            modelContext.insert(log)
                            modelContext.safeSave()
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        quickWeightInput = ""
                        showingAddWeight = false
                    } label: {
                        Text("存").font(.system(size: 13, weight: .black)).foregroundStyle(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.goLime, in: Capsule())
                    }
                }
            }
            // mini weight chart
            let sorted = pet.weightLogs.sorted { $0.date < $1.date }
            if sorted.count >= 2 {
                WeightLineChart(logs: Array(sorted.suffix(8))).frame(height: 40)
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 20)
    }

    // 花费卡
    private var bentoExpenseCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("花费", systemImage: "yensign.circle")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goYellow)
            Text("¥\(Int(monthTotal))")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white).minimumScaleFactor(0.6).lineLimit(1)
            Text("本月")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.2))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(minHeight: 130)
        .goTranslucentCard(cornerRadius: 20)
    }

    // 遛狗卡
    private var bentoWalkCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("巡岛", systemImage: "figure.walk")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goLime)
                Spacer()
                Text("查看 →").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.goLime.opacity(0.6))
            }
            if let w = lastWalk {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("距离").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                        Text(w.distanceText).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("时长").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                        Text(w.durationText).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                }
            } else {
                Text("暂无记录").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.3))
            }
            Text("\(pet.walkLogs.count) 次巡岛").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(14)
        .background(LinearGradient(colors: [Color.goLime.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.goLime.opacity(0.2), lineWidth: 1))
    }

    // 噗噗卡
    private var bentoPottyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("噗噗", systemImage: "drop.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goOrange)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(todayPotty)").font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("次").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.goOrange)
            }
            Text("今日").font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.35))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.2))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(minHeight: 130)
        .goTranslucentCard(cornerRadius: 20)
    }

    // 粮仓卡
    private var bentoFoodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("粮仓", systemImage: "fork.knife")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goOrange)
                Spacer()
                if pet.remainingFoodDays > 0 && pet.remainingFoodDays <= 7 {
                    Text("⚠️ 仅剩 \(pet.remainingFoodDays) 天")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Color.goRed)
                }
            }
            if pet.remainingFoodDays > 0 {
                ProgressView(value: pet.remainingFoodPercent)
                    .tint(pet.remainingFoodDays <= 7 ? Color.goRed : Color.goTeal)
                HStack {
                    Text("\(Int(pet.remainingFoodGrams))g 剩余")
                    Spacer()
                    Text("\(pet.remainingFoodDays) 天")
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.4))
            } else {
                Text("未设置粮食库存").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: 20)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - L7 Unified Timeline（岁月史书）
// ═══════════════════════════════════════════════════════════════
private struct PetUnifiedTimeline: View {
    let pet: Pet

    private var items: [UnifiedLogItem] {
        var list: [UnifiedLogItem] = []

        for w in pet.walkLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.startDate, type: "walk",
                title: "巡岛 · \(w.distanceText)", subtitle: w.durationText,
                iconName: "figure.walk", color: .goLime))
        }
        for p in pet.pottyLogs {
            list.append(UnifiedLogItem(id: p.id, date: p.date, type: "potty",
                title: "噗噗 · \(p.pottyType.emoji)\(p.pottyType.rawValue)", subtitle: "",
                iconName: "drop.fill", color: .goOrange))
        }
        for h in pet.healthLogs {
            list.append(UnifiedLogItem(id: h.id, date: h.date, type: "health",
                title: "\(h.healthLogType.emoji) \(h.type)",
                subtitle: h.note.isEmpty ? (h.vetName.isEmpty ? "" : h.vetName) : h.note,
                iconName: "heart.text.clipboard", color: .goTeal))
        }
        for e in pet.expenseLogs {
            list.append(UnifiedLogItem(id: e.id, date: e.date, type: "expense",
                title: "¥\(Int(e.amount)) · \(e.note.isEmpty ? e.category : e.note)",
                subtitle: e.category,
                iconName: "yensign.circle.fill", color: .goYellow))
        }
        for w in pet.weightLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.date, type: "weight",
                title: String(format: "体重 %.1f kg", w.weight), subtitle: "",
                iconName: "scalemass.fill", color: .goTeal))
        }

        return list.sorted { $0.date > $1.date }.prefix(40).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Text("岁月史书")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
                Text("\(items.count) 条")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.bottom, 16)

            if items.isEmpty {
                Text("还没有任何记录")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    HStack(alignment: .top, spacing: 14) {
                        // 左侧时间轴
                        VStack(spacing: 0) {
                            ZStack {
                                Circle().fill(item.color.opacity(0.18)).frame(width: 34, height: 34)
                                Image(systemName: item.iconName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(item.color)
                            }
                            if idx < items.count - 1 {
                                Rectangle()
                                    .fill(.white.opacity(0.08))
                                    .frame(width: 1)
                                    .frame(minHeight: 20)
                            }
                        }

                        // 右侧内容
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            if !item.subtitle.isEmpty {
                                Text(item.subtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                            Text(item.date, format: .dateTime.year().month().day().hour().minute())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        .padding(.top, 6)
                        .padding(.bottom, idx < items.count - 1 ? 16 : 0)

                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 24)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Weight Line Chart（保留供 Bento 使用）
// ═══════════════════════════════════════════════════════════════
struct WeightLineChart: View {
    let logs: [PetWeightLog]

    private var weights: [Double] { logs.map { $0.weight } }
    private var minW: Double { (weights.min() ?? 0) - 0.2 }
    private var maxW: Double { (weights.max() ?? 1) + 0.2 }
    private var range: Double { max(maxW - minW, 0.1) }

    private func xPos(_ i: Int, w: CGFloat) -> CGFloat {
        logs.count <= 1 ? w / 2 : CGFloat(i) / CGFloat(logs.count - 1) * w
    }
    private func yPos(_ v: Double, h: CGFloat) -> CGFloat {
        h - CGFloat((v - minW) / range) * h
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                if logs.count >= 2 {
                    Path { p in
                        p.move(to: CGPoint(x: xPos(0, w: w), y: h))
                        p.addLine(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(weights[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            p.addCurve(to: curr,
                                       control1: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: prev.y),
                                       control2: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: curr.y))
                        }
                        p.addLine(to: CGPoint(x: xPos(logs.count-1, w: w), y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color.goTeal.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))

                    Path { p in
                        p.move(to: CGPoint(x: xPos(0, w: w), y: yPos(weights[0], h: h)))
                        for i in 1..<logs.count {
                            let prev = CGPoint(x: xPos(i-1, w: w), y: yPos(weights[i-1], h: h))
                            let curr = CGPoint(x: xPos(i, w: w), y: yPos(weights[i], h: h))
                            p.addCurve(to: curr,
                                       control1: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: prev.y),
                                       control2: CGPoint(x: prev.x + (curr.x - prev.x)*0.5, y: curr.y))
                        }
                    }
                    .stroke(Color.goTeal, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
    }
}

// MARK: - task4: 饮食排泄卡片（内联快速打卡）
private struct DietCardWithQuickActions: View {
    let pet: Pet
    let onOpenDetail: () -> Void
    @Environment(\.modelContext) private var modelContext

    private var isCatLike: Bool {
        ["猫","兔子","仓鼠","龙猫","豚鼠"].contains(pet.species)
    }
    private var todayFeed: Int {
        pet.careLogs.filter { $0.type == CareType.feeding.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }
    private var todayWater: Int {
        pet.careLogs.filter { $0.type == CareType.watering.rawValue && Calendar.current.isDateInToday($0.date) }.count
    }
    private var todayPotty: Int {
        if isCatLike {
            return pet.careLogs.filter { $0.type == CareType.litter.rawValue && Calendar.current.isDateInToday($0.date) }.count
        } else {
            return pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpenDetail) {
                HStack {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.goOrange)
                    Text("饮食与排泄")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)

            GoDashedDivider().padding(.horizontal, 14)

            HStack(spacing: 8) {
                Button {
                    let log = PetCareLog(date: Date(), type: .feeding, pet: pet)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    QuestManager.shared.recordFirstMeal()
                    QuestManager.shared.awardAction(type: .feed, pet: pet, context: modelContext)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dietActionCell(
                        emoji: "🍗", label: "喂食", countLabel: "今日 \(todayFeed) 次",
                        accent: Color.goOrange
                    )
                }
                .buttonStyle(.plain)

                Button {
                    let log = PetCareLog(date: Date(), type: .watering, pet: pet)
                    modelContext.insert(log)
                    modelContext.safeSave()
                    QuestManager.shared.awardAction(type: .water, pet: pet, context: modelContext)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dietActionCell(
                        emoji: "💧", label: "喂水", countLabel: "今日 \(todayWater) 次",
                        accent: Color.goCardCyan
                    )
                }
                .buttonStyle(.plain)

                // FIX 4: 猫的便便/铲砂快捷打卡
                Button {
                    let eid = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap { $0.isEmpty ? nil : $0 }
                    if isCatLike {
                        let log = PetCareLog(date: Date(), type: .litter, pet: pet, executorId: eid)
                        modelContext.insert(log)
                        QuestManager.shared.awardAction(type: .potty(isLitter: true), pet: pet, context: modelContext)
                    } else {
                        let log = PetPottyLog(date: Date(), type: .perfectPoop, pet: pet, executorId: eid)
                        modelContext.insert(log)
                        QuestManager.shared.awardAction(type: .potty(isLitter: false), pet: pet, context: modelContext)
                    }
                    modelContext.safeSave()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    dietActionCell(
                        emoji: isCatLike ? "🧹" : "💩",
                        label: isCatLike ? "铲砂" : "便便",
                        countLabel: "今日 \(todayPotty) 次",
                        accent: isCatLike ? Color(hex: "5B6AFF") : Color(hex: "FF8C42")
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 10)
        }
        .goTranslucentCard(cornerRadius: 20)
    }

    private func dietActionCell(emoji: String, label: String, countLabel: String, accent: Color) -> some View {
        HStack(spacing: 5) {
            Text(emoji).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(countLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(accent)
            }
            Spacer()
            Text("+")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(accent.opacity(0.6))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

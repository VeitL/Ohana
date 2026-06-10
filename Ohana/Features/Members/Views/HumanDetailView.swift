//
//  HumanDetailView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct HumanDetailView: View {
    let human: Human
    let allPets: [Pet]
    let allHumans: [Human]
    let allPendingReminders: [Reminder]
    let allMeds: [HumanMedication]
    let allReports: [HumanHealthReport]
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices
    @AppStorage("currentActiveHumanId") var activeHumanIdStr = ""
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) var hiddenHomePetIDsRaw = ""
    @AppStorage("appLanguage") var appLanguage = AppLanguage.code

    init(
        human: Human,
        allPets: [Pet] = [],
        allHumans: [Human] = [],
        allPendingReminders: [Reminder] = [],
        allMeds: [HumanMedication] = [],
        allReports: [HumanHealthReport] = [],
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        self.human = human
        self.allPets = allPets
        self.allHumans = allHumans
        self.allPendingReminders = allPendingReminders
        self.allMeds = allMeds
        self.allReports = allReports
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @ObservedObject var avatarPipeline = AvatarPipelineRegistry.current
    @State var showingEditSheet = false
    @State var showingDeleteConfirm = false
    @State var showWeightHistory = false
    @State var showingWishlist = false
    @State var showingCoHealth = false
    @State var showingExpenses = false
    @State var showingMedication = false
    @State var showingHealthReport = false
    @State var showingHealthMetrics = false
    @State var showingHomeStackFullAlert = false
    @State var homeVisibilityOverride: Bool?
    @State var avatarSignature = ""
    @State var avatarCacheKey = "human-detail-avatar-empty"

    var isViewingOwnProfile: Bool { activeHumanId == human.id }
    var isAllPrivateForViewer: Bool {
        !isViewingOwnProfile && HumanPrivateField.allCases.allSatisfy { human.privateFields.contains($0.rawValue) }
    }

    var humanReminders: [Reminder] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allPendingReminders.filter {
            $0.event?.relatedEntityType == "Human" &&
                $0.event?.relatedEntityId == human.id.uuidString
        }
    }

    var myMeds: [HumanMedication] {
        guard !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allMeds.filter { $0.isActive && $0.isActiveToday }
    }

    var myReports: [HumanHealthReport] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.weight, viewedBy: activeHumanId) else { return [] }
        return allReports
    }

    var myHealthMetricLogs: [HumanHealthMetricLog] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.weight, viewedBy: activeHumanId) else { return [] }
        return human.healthMetricLogs
    }

    var abnormalHealthMetricLogCount: Int {
        myHealthMetricLogs.count(where: { log in
            guard let metric = HealthMetricCatalog.metric(forKey: log.metricKey),
                  let unit = metric.unit(for: log.unitCode) else { return false }
            let status = unit.status(for: log.value)
            return status == .low || status == .high
        })
    }

    var themeColor: Color { Color(hex: human.themeColorHex) }
    var l: L10n { L10n(appLanguage) }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    heroCard
                    if isAllPrivateForViewer {
                        fullPrivacyPlaceholder
                    } else {
                        badgesCard
                        statsBento
                        showOnHomeCard

                        sectionHeader("健康 & 身体")

                        if human.isPrivate(.weight, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "体重记录")
                        } else {
                            HumanPrivateDataNotice(human: human, field: .weight)
                                .padding(.horizontal, 16)
                            weightCard
                        }
                        if human.isPrivate(.weight, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "体检指标", en: "Checkup Metrics", de: "Check-up-Werte"))
                        } else {
                            healthMetricCard
                        }
                        if human.isPrivate(.medication, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "吃药提醒")
                        } else {
                            HumanPrivateDataNotice(human: human, field: .medication)
                                .padding(.horizontal, 16)
                            medicationCard
                        }
                        if human.isPrivate(.weight, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "身体检测报告")
                        } else {
                            healthReportCard
                        }

                        sectionHeader("活动 & 记录")

                        if human.isPrivate(.workout, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "运动记录")
                        } else {
                            HumanPrivateDataNotice(human: human, field: .workout)
                                .padding(.horizontal, 16)
                            HumanWorkoutCard(human: human, pets: allPets)
                                .padding(.horizontal, 16)
                        }
                        if human.isPrivate(.weight, viewedBy: activeHumanId) ||
                            human.isPrivate(.workout, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "共健数据")
                        } else {
                            coHealthCard
                        }

                        sectionHeader("财务")

                        if human.isPrivate(.expense, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "花费记录")
                        } else {
                            HumanPrivateDataNotice(human: human, field: .expense)
                                .padding(.horizontal, 16)
                            humanExpenseCard
                        }
                        if human.isPrivate(.wishlist, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "椰子资产")
                        } else {
                            HumanPrivateDataNotice(human: human, field: .wishlist)
                                .padding(.horizontal, 16)
                            humanAssetCard
                        }

                        sectionHeader("提醒 & 备注")
                        if human.isPrivate(.medication, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: "待办提醒")
                        } else {
                            remindersSection
                        }
                        notesSection
                        if isViewingOwnProfile {
                            deleteSection
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !human.isPrivate(.wishlist, viewedBy: activeHumanId) {
                        CoconutBalanceCapsule(balance: human.coconutBalance) {
                            presentCoconutLog()
                        }
                    }
                    if isViewingOwnProfile {
                        Button { showingEditSheet = true } label: {
                            Image(systemName: "pencil.circle") // a11y: allow decorative icon covered by surrounding text or control
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) { EditHumanSheet(human: human) }
        .sheet(isPresented: $showWeightHistory) {
            NavigationStack { HumanWeightHistoryView(human: human) }
                .ohanaSheetPagePresentation() // ui-v4: allow long weight history uses large sheet
        }
        .navigationDestination(isPresented: $showingWishlist) { HumanWishlistView(human: human) }
        .navigationDestination(isPresented: $showingCoHealth) { CoHealthDashboardFullView(human: human) }
        .navigationDestination(isPresented: $showingExpenses) { HumanExpenseDetailView(human: human) }
        .sheet(isPresented: $showingMedication) {
            NavigationStack { HumanMedicationView(human: human) }
                .ohanaSheetPagePresentation() // ui-v4: allow long medication management uses large sheet
        }
        .navigationDestination(isPresented: $showingHealthReport) { HumanHealthReportView(human: human) }
        .navigationDestination(isPresented: $showingHealthMetrics) { HumanHealthCheckupView(human: human) }
        .alert("确认删除", isPresented: $showingDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteHumanAndReturnHome()
            }
        } message: {
            Text("确定要删除 \(human.name) 吗？此操作不可撤销。")
        }
        .alert("首页卡片堆已满", isPresented: $showingHomeStackFullAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先从首页移除一张宠物或人类卡片，再添加 \(human.name)。")
        }
        .task(id: avatarSourceKey) {
            await prepareAvatar()
        }
        .onDisappear {
            avatarPipeline.cancel(key: avatarCacheKey)
        }
    }

    // MARK: - Hero Card（GO 首页同款白底卡片，弱化大色块背景）
}

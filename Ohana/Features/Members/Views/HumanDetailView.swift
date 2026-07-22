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
    let onOpenTasks: () -> Void

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(AppServices.self) var appServices
    @AppStorage("currentActiveHumanId") var activeHumanIdStr = ""
    @Environment(\.ohanaAppLanguageCode) var appLanguage

    init(
        human: Human,
        allPets: [Pet] = [],
        allHumans: [Human] = [],
        allPendingReminders: [Reminder] = [],
        allMeds: [HumanMedication] = [],
        allReports: [HumanHealthReport] = [],
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in },
        onOpenTasks: @escaping () -> Void = {}
    ) {
        self.human = human
        self.allPets = allPets
        self.allHumans = allHumans
        self.allPendingReminders = allPendingReminders
        self.allMeds = allMeds
        self.allReports = allReports
        self.onPresentCoconutLog = onPresentCoconutLog
        self.onOpenTasks = onOpenTasks
    }

    var activeHumanId: UUID? { UUID(uuidString: activeHumanIdStr) }

    @StateObject var commandQueue = DeferredDomainCommandQueue()
    @ObservedObject var avatarPipeline = AvatarPipelineRegistry.current
    @State var showingEditSheet = false
    @State var showWeightHistory = false
    @State var showingWishlist = false
    @State var showingCoHealth = false
    @State var showingExpenses = false
    @State var showingMedication = false
    @State var showingHealthReport = false
    @State var showingHealthMetrics = false
    @State var isDeleting = false
    @State var personalUpgradePrompt: PersonalUpgradePrompt?
    @State var avatarSignature = ""
    @State var avatarCacheKey = "human-detail-avatar-empty"

    var isViewingOwnProfile: Bool { activeHumanId == human.id }
    var canEditProfile: Bool { HumanProfileEditPolicy.canEdit(hasPassedAway: human.hasPassedAway) }
    var isAllPrivateForViewer: Bool {
        HumanLocalPrivacyPolicy.isEnabled &&
            !isViewingOwnProfile &&
            HumanPrivateField.allCases.allSatisfy { human.privateFields.contains($0.rawValue) }
    }

    var humanReminders: [Reminder] {
        guard !isAllPrivateForViewer,
              !human.isPrivate(.medication, viewedBy: activeHumanId) else { return [] }
        return allPendingReminders.filter { reminder in
            guard let event = reminder.event else { return false }
            return MemberLifecycleActiveScheduleResolver.eventBelongsToHuman(
                event,
                humanId: human.id.uuidString,
                humanMedications: allMeds
            )
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

                        sectionHeader(l.tr(zh: "健康 & 身体", en: "Health & Body", de: "Gesundheit & Körper"))

                        if human.isPrivate(.weight, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "体重记录", en: "Weight Records", de: "Gewichtsverlauf"))
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
                            privacyPlaceholderCard(label: l.tr(zh: "吃药提醒", en: "Medication Reminders", de: "Medikamentenerinnerungen"))
                        } else {
                            HumanPrivateDataNotice(human: human, field: .medication)
                                .padding(.horizontal, 16)
                            medicationCard
                        }
                        if human.isPrivate(.weight, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "身体检测报告", en: "Health Reports", de: "Gesundheitsberichte"))
                        } else {
                            healthReportCard
                        }

                        sectionHeader(l.tr(zh: "活动 & 记录", en: "Activity & Records", de: "Aktivität & Einträge"))

                        if human.isPrivate(.workout, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "运动记录", en: "Workout Records", de: "Trainingseinträge"))
                        } else {
                            HumanPrivateDataNotice(human: human, field: .workout)
                                .padding(.horizontal, 16)
                            HumanWorkoutCard(human: human, pets: allPets)
                                .padding(.horizontal, 16)
                        }
                        if human.isPrivate(.weight, viewedBy: activeHumanId) ||
                            human.isPrivate(.workout, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "共健数据", en: "Shared Health Data", de: "Gemeinsame Gesundheitsdaten"))
                        } else {
                            coHealthCard
                        }

                        sectionHeader(l.tr(zh: "财务", en: "Finance", de: "Finanzen"))

                        if human.isPrivate(.expense, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "花费记录", en: "Expense Records", de: "Ausgabeneinträge"))
                        } else {
                            HumanPrivateDataNotice(human: human, field: .expense)
                                .padding(.horizontal, 16)
                            humanExpenseCard
                        }
                        if human.isPrivate(.wishlist, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "椰子资产", en: "Coconut Assets", de: "Kokosnussvermögen"))
                        } else {
                            HumanPrivateDataNotice(human: human, field: .wishlist)
                                .padding(.horizontal, 16)
                            humanAssetCard
                        }

                        sectionHeader(l.tr(zh: "提醒 & 备注", en: "Reminders & Notes", de: "Erinnerungen & Notizen"))
                        if human.isPrivate(.medication, viewedBy: activeHumanId) {
                            privacyPlaceholderCard(label: l.tr(zh: "待办提醒", en: "Pending Reminders", de: "Ausstehende Erinnerungen"))
                        } else {
                            remindersSection
                        }
                        notesSection
                    }
                    humanLifecycleDangerZone
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
                    if canEditProfile {
                        Button { showingEditSheet = true } label: {
                            Image(systemName: "pencil.circle") // a11y: allow decorative icon covered by surrounding text or control
                                .foregroundStyle(Color.ohanaPrimaryText)
                        }
                        .accessibilityIdentifier("human-detail-edit-action")
                    }
                }
            }
        }
        .accessibilityIdentifier("human-detail-screen")
        .sheet(isPresented: $showingEditSheet) { EditHumanSheet(human: human) }
        .sheet(item: $personalUpgradePrompt) { prompt in
            PersonalPlanView(prompt: prompt)
                .ohanaSheetPagePresentation()
        }
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
        .task(id: avatarSourceKey) {
            await prepareAvatar()
        }
        .onDisappear {
            avatarPipeline.cancel(key: avatarCacheKey)
        }
    }

    // MARK: - Hero Card（GO 首页同款白底卡片，弱化大色块背景）
}

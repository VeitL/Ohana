//
//  PetAllFeaturesSheet.swift
//  Ohana
//
//  Single-pet V4 feature hub.
//

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
    case bondVault
}

extension PetAllFeatureDestination: Identifiable {
    var id: String {
        switch self {
        case .health: return "health"
        case .medications: return "medications"
        case .food: return "food"
        case .hygiene: return "hygiene"
        case .walks: return "walks"
        case .potty: return "potty"
        case .basicInfo: return "basicInfo"
        case .documents: return "documents"
        case .moments: return "moments"
        case .timeline: return "timeline"
        case .achievements: return "achievements"
        case .retention: return "retention"
        case .weight: return "weight"
        case .expense: return "expense"
        case .bondVault: return "bondVault"
        }
    }
}

struct PetAllFeaturesSheet: View {
    let pet: Pet

    @Environment(\.dismiss) private var dismiss
    @State private var activeDestination: PetAllFeatureDestination?

    private var l: L10n { L10n() }
    private var isDog: Bool {
        pet.species.localizedCaseInsensitiveContains("狗") ||
        pet.species.localizedCaseInsensitiveContains("dog")
    }
    private var archiveSnapshot: ArchiveMemorySnapshot { ArchiveMemorySnapshot(pet: pet) }

    var body: some View {
        NavigationStack {
            FeatureHubScaffold {
                FeatureHubHeader(
                    title: pet.name,
                    subtitle: petSubtitle,
                    eyebrow: l.tr(zh: "全部功能", en: "All Features", de: "Alle Funktionen"),
                    onClose: { dismiss() },
                    avatar: {
                        FeatureHubAvatar(
                            imageData: pet.avatarImageData,
                            emoji: pet.avatarEmoji,
                            fallback: pet.speciesEmoji,
                            tint: Color(hex: pet.safeThemeColorHex)
                        )
                    }
                )
            } content: {
                if pet.hasPassedAway {
                    PetMemorialBanner(pet: pet)
                }

                FeatureHubMetricStrip(metrics: petMetrics)

                ForEach(petSections) { section in
                    FeatureHubSectionActionView(section: section) { destination in
                        withAnimation(GoMotion.page) {
                            activeDestination = destination
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .petMemorialTone(isActive: pet.hasPassedAway)
        }
        .fullScreenCover(item: $activeDestination) { destination in
            FeatureHubDestinationHost(
                onClose: { activeDestination = nil },
                showsCloseButton: destinationNeedsHostClose(destination)
            ) {
                destView(destination)
            }
        }
    }

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
        case .retention:     PetRetentionHubView(pet: pet, showsCloseButton: true)
        case .weight:        WeightHistoryView(pet: pet)
        case .expense:       ExpenseHistoryView(pet: pet, showsCloseButton: true)
        case .bondVault:     PetBondVaultView(pet: pet)
        }
    }

    private func destinationNeedsHostClose(_ destination: PetAllFeatureDestination) -> Bool {
        switch destination {
        case .food, .basicInfo, .documents, .weight:
            return true
        case .health, .medications, .hygiene, .walks, .potty, .moments, .timeline, .achievements, .retention, .expense, .bondVault:
            return false
        }
    }

    private var petSections: [FeatureHubSectionData<PetAllFeatureDestination>] {
        [
            FeatureHubSectionData(
                id: "daily",
                title: l.tr(zh: "高频照护", en: "Daily Care", de: "Tägliche Pflege"),
                subtitle: l.tr(zh: "打卡与日常管理", en: "Logs and routines", de: "Einträge und Routinen"),
                items: dailyItems
            ),
            FeatureHubSectionData(
                id: "health",
                title: l.tr(zh: "健康身体", en: "Health", de: "Gesundheit"),
                subtitle: l.tr(zh: "状态、用药、趋势", en: "Status, meds, trends", de: "Status, Medikamente, Trends"),
                items: healthItems
            ),
            FeatureHubSectionData(
                id: "archive",
                title: l.tr(zh: "档案记忆", en: "Archive", de: "Archiv"),
                subtitle: l.tr(zh: "资料、证件、时刻", en: "Profile, documents, moments", de: "Profil, Dokumente, Momente"),
                items: archiveItems
            ),
            FeatureHubSectionData(
                id: "finance",
                title: l.tr(zh: "财务保障", en: "Money & Protection", de: "Kosten & Schutz"),
                subtitle: l.tr(zh: "花费与保障资料", en: "Spending and coverage", de: "Ausgaben und Schutz"),
                items: financeItems
            )
        ]
    }

    private var dailyItems: [FeatureHubDestinationItem<PetAllFeatureDestination>] {
        var items: [FeatureHubDestinationItem<PetAllFeatureDestination>] = [
            item(
                id: "food",
                title: l.tr(zh: "饮食", en: "Food", de: "Futter"),
                value: todayFeedMetric,
                subtitle: foodSub,
                icon: "fork.knife",
                tint: Color(hex: "F59E0B"),
                destination: .food
            ),
            item(
                id: "hygiene",
                title: l.tr(zh: "清洁护理", en: "Care", de: "Pflege"),
                value: "\(pet.careLogs.filter { $0.careType != .feeding }.count)",
                subtitle: hygieneSub,
                icon: "bubbles.and.sparkles.fill",
                tint: Color.goTeal,
                destination: .hygiene
            ),
            item(
                id: "potty",
                title: l.tr(zh: "便便", en: "Potty", de: "Kot"),
                value: todayPottyMetric,
                subtitle: pottySub,
                icon: "drop.fill",
                tint: Color(hex: "D97706"),
                destination: .potty
            )
        ]
        if isDog {
            items.insert(
                item(
                    id: "walk",
                    title: l.tr(zh: "遛狗", en: "Walks", de: "Gassi"),
                    value: weekWalkText,
                    subtitle: walkSub,
                    icon: "figure.walk",
                    tint: Color(hex: "14B8A6"),
                    destination: .walks
                ),
                at: 2
            )
        }
        return items
    }

    private var healthItems: [FeatureHubDestinationItem<PetAllFeatureDestination>] {
        [
            item(
                id: "health",
                title: l.tr(zh: "健康", en: "Health", de: "Gesundheit"),
                value: "\(pet.healthLogs.count)",
                subtitle: healthSub,
                icon: "cross.fill",
                tint: Color.goRed,
                destination: .health
            ),
            item(
                id: "meds",
                title: l.tr(zh: "用药", en: "Meds", de: "Medikamente"),
                value: "\(pet.medications.filter { $0.isActiveToday }.count)",
                subtitle: medSub,
                icon: "pills.fill",
                tint: Color.goPurple,
                destination: .medications
            ),
            item(
                id: "weight",
                title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                value: latestWeightText,
                subtitle: weightSub,
                icon: "scalemass.fill",
                tint: Color(hex: "16A34A"),
                destination: .weight
            )
        ]
    }

    private var archiveItems: [FeatureHubDestinationItem<PetAllFeatureDestination>] {
        [
            item(
                id: "retention",
                title: l.tr(zh: "成长档案", en: "Growth", de: "Entwicklung"),
                value: "\(archiveSnapshot.score)/\(archiveSnapshot.total)",
                subtitle: archiveSnapshot.nextStep.title,
                icon: "sparkles.rectangle.stack.fill",
                tint: Color(hex: pet.safeThemeColorHex),
                destination: .retention
            ),
            item(
                id: "moments",
                title: l.tr(zh: "记录中心", en: "Moments", de: "Momente"),
                value: "\(pet.photoLogs.count)",
                subtitle: momentsSub,
                icon: "sparkles",
                tint: Color(hex: "EC4899"),
                destination: .moments
            ),
            item(
                id: "documents",
                title: l.tr(zh: "证件保障", en: "Documents", de: "Dokumente"),
                value: "\(pet.documents.count + pet.insurances.count)",
                subtitle: documentsSub,
                icon: "doc.fill",
                tint: Color(hex: "94A3B8"),
                destination: .documents
            )
        ]
    }

    private var financeItems: [FeatureHubDestinationItem<PetAllFeatureDestination>] {
        [
            item(
                id: "bondVault",
                title: l.tr(zh: "宠物小金库", en: "Bond Vault", de: "Bindungs-Tresor"),
                value: "🥥 \(pet.coconutBalance)",
                subtitle: l.tr(zh: "宠物专属成长资产", en: "Pet-only bond assets", de: "Nur Haustier-Bindung"),
                icon: "pawprint.circle.fill",
                tint: Color.goYellow,
                destination: .bondVault
            ),
            item(
                id: "expense",
                title: l.tr(zh: "花费", en: "Expenses", de: "Ausgaben"),
                value: expenseMetric,
                subtitle: expenseSub,
                icon: "creditcard.fill",
                tint: Color.goOrange,
                destination: .expense
            )
        ]
    }

    private func item(
        id: String,
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        destination: PetAllFeatureDestination
    ) -> FeatureHubDestinationItem<PetAllFeatureDestination> {
        FeatureHubDestinationItem(
            data: FeatureHubTileData(
                id: id,
                title: title,
                value: value.isEmpty ? "--" : value,
                subtitle: subtitle,
                icon: icon,
                tint: tint
            ),
            destination: destination
        )
    }

    private var petMetrics: [FeatureHubMetric] {
        [
            FeatureHubMetric(id: "today", title: l.tr(zh: "今日照护", en: "Today", de: "Heute"), value: "\(todayCareCount)"),
            FeatureHubMetric(id: "records", title: l.tr(zh: "记录", en: "Logs", de: "Einträge"), value: "\(timelineCount)"),
            FeatureHubMetric(id: "archive", title: l.tr(zh: "档案", en: "Archive", de: "Archiv"), value: "\(archiveScore)/5"),
            FeatureHubMetric(id: "bond", title: l.tr(zh: "成长椰子", en: "Bond", de: "Bindung"), value: "🥥 \(pet.coconutBalance)")
        ]
    }

    private var petSubtitle: String {
        if !pet.breed.isEmpty { return "\(pet.species) · \(pet.breed)" }
        if !pet.species.isEmpty { return pet.species }
        return l.tr(zh: "宠物成员", en: "Pet member", de: "Tiermitglied")
    }

    private var healthSub: String  {
        pet.healthLogs.isEmpty
            ? l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge")
            : l.tr(zh: "\(pet.healthLogs.count)条记录", en: "\(pet.healthLogs.count) records", de: "\(pet.healthLogs.count) Einträge")
    }
    private var weightSub: String  {
        pet.weightLogs.isEmpty
            ? l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge")
            : l.tr(zh: "\(pet.weightLogs.count)条记录", en: "\(pet.weightLogs.count) records", de: "\(pet.weightLogs.count) Einträge")
    }
    private var medSub: String {
        let count = pet.medications.filter { $0.isActiveToday }.count
        return count > 0
            ? l.tr(zh: "当前\(count)种药物", en: "\(count) active meds", de: "\(count) aktive Medikamente")
            : l.tr(zh: "暂无用药", en: "No medication", de: "Keine Medikamente")
    }
    private var foodSub: String {
        let count = pet.careLogs.filter { $0.careType == .feeding && Calendar.current.isDateInToday($0.date) }.count
        return count > 0
            ? l.tr(zh: "今日喂食\(count)次", en: "\(count) feeds today", de: "\(count) Fütterungen heute")
            : l.tr(zh: "今日未喂食", en: "No feed today", de: "Heute kein Futter")
    }
    private var hygieneSub: String {
        let count = pet.careLogs.filter { $0.careType != .feeding }.count
        return count > 0
            ? l.tr(zh: "\(count)条护理记录", en: "\(count) care logs", de: "\(count) Pflegeeinträge")
            : l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge")
    }
    private var walkSub: String {
        pet.walkLogs.isEmpty
            ? l.tr(zh: "暂无记录", en: "No walks yet", de: "Noch keine Gassi-Runden")
            : l.tr(zh: "\(pet.walkLogs.count)次遛狗", en: "\(pet.walkLogs.count) walks", de: "\(pet.walkLogs.count) Runden")
    }
    private var pottySub: String {
        let count = pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count
        return count > 0
            ? l.tr(zh: "今日\(count)次", en: "\(count) today", de: "\(count) heute")
            : l.tr(zh: "今日暂无记录", en: "No logs today", de: "Heute keine Einträge")
    }
    private var expenseSub: String {
        pet.expenseLogs.isEmpty
            ? l.tr(zh: "暂无记录", en: "No expenses", de: "Keine Ausgaben")
            : l.tr(zh: "\(pet.expenseLogs.count)条花费记录", en: "\(pet.expenseLogs.count) expense logs", de: "\(pet.expenseLogs.count) Ausgaben")
    }
    private var momentsSub: String {
        pet.photoLogs.isEmpty
            ? l.tr(zh: "暂无时刻", en: "No moments", de: "Keine Momente")
            : l.tr(zh: "\(pet.photoLogs.count)个时刻", en: "\(pet.photoLogs.count) moments", de: "\(pet.photoLogs.count) Momente")
    }
    private var basicInfoSub: String {
        if !pet.breed.isEmpty { return l.tr(zh: "品种已设置", en: "Breed set", de: "Rasse gesetzt") }
        if !pet.species.isEmpty { return l.tr(zh: "补充品种/日期", en: "Add breed or dates", de: "Rasse oder Daten ergänzen") }
        return l.tr(zh: "完善基本信息", en: "Complete profile", de: "Profil ergänzen")
    }
    private var documentsSub: String {
        let documentCount = pet.documents.count
        let insuranceCount = pet.insurances.count
        if documentCount > 0 || insuranceCount > 0 {
            return l.tr(zh: "\(documentCount)份证件 · \(insuranceCount)份保险", en: "\(documentCount) docs · \(insuranceCount) policies", de: "\(documentCount) Dokumente · \(insuranceCount) Policen")
        }
        return l.tr(zh: "证件/保险资料", en: "Documents and coverage", de: "Dokumente und Schutz")
    }
    private var timelineSub: String {
        timelineCount > 0
            ? l.tr(zh: "\(timelineCount)条记录", en: "\(timelineCount) logs", de: "\(timelineCount) Einträge")
            : l.tr(zh: "暂无记录", en: "No logs", de: "Keine Einträge")
    }
    private var achievementsSub: String {
        pet.milestones.isEmpty
            ? l.tr(zh: "暂无成就", en: "No awards", de: "Keine Erfolge")
            : l.tr(zh: "\(pet.milestones.count)个里程碑", en: "\(pet.milestones.count) milestones", de: "\(pet.milestones.count) Meilensteine")
    }

    private var todayFeedMetric: String {
        "\(pet.careLogs.filter { $0.careType == .feeding && Calendar.current.isDateInToday($0.date) }.count)"
    }
    private var todayPottyMetric: String {
        "\(pet.pottyLogs.filter { Calendar.current.isDateInToday($0.date) }.count)"
    }
    private var latestWeightText: String {
        guard let latest = pet.weightLogs.max(by: { $0.date < $1.date }) else { return "--" }
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
        AppCurrency.formatCompact(pet.expenseLogs.reduce(0.0) { $0 + $1.amount })
    }
    private var timelineCount: Int {
        pet.photoLogs.count + pet.milestones.count + pet.healthLogs.count + pet.weightLogs.count
    }
    private var todayCareCount: Int {
        let calendar = Calendar.current
        return pet.careLogs.filter { calendar.isDateInToday($0.date) }.count
        + pet.pottyLogs.filter { calendar.isDateInToday($0.date) }.count
        + pet.walkLogs.filter { calendar.isDateInToday($0.startDate) }.count
    }
    private var archiveScore: Int { archiveSnapshot.score }
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
        case .basicInfo: return .basicInfo
        case .documents: return .documents
        case .moments: return .moments
        case .weight: return .weight
        case .retention: return .retention
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
        let l = L10n()
        if !hasBasicProfile {
            return ArchiveMemoryNextStep(
                kind: .basicInfo,
                title: l.tr(zh: "完善基础档案", en: "Complete profile", de: "Profil ergänzen"),
                subtitle: l.tr(zh: "补充生日、品种或到家日", en: "Add birthday, breed, or home date", de: "Geburtstag, Rasse oder Einzug ergänzen"),
                icon: "person.fill"
            )
        }
        if !hasDocumentsOrInsurance {
            return ArchiveMemoryNextStep(
                kind: .documents,
                title: l.tr(zh: "添加证件/保障", en: "Add documents", de: "Dokumente hinzufügen"),
                subtitle: l.tr(zh: "上传疫苗、证件或保险资料", en: "Add vaccine, ID, or insurance files", de: "Impfung, Ausweis oder Versicherung hinzufügen"),
                icon: "doc.badge.plus"
            )
        }
        if !hasMemory {
            return ArchiveMemoryNextStep(
                kind: .moments,
                title: l.tr(zh: "留下第一段回忆", en: "Add first moment", de: "Ersten Moment speichern"),
                subtitle: l.tr(zh: "添加照片或重要时刻", en: "Add a photo or milestone", de: "Foto oder Meilenstein hinzufügen"),
                icon: "camera.fill"
            )
        }
        if !hasHealthOrWeight {
            return ArchiveMemoryNextStep(
                kind: .weight,
                title: l.tr(zh: "补一条健康基线", en: "Add health baseline", de: "Gesundheitsbasis ergänzen"),
                subtitle: l.tr(zh: "记录体重或健康档案", en: "Log weight or health data", de: "Gewicht oder Gesundheit eintragen"),
                icon: "scalemass.fill"
            )
        }
        return ArchiveMemoryNextStep(
            kind: .retention,
            title: l.tr(zh: "查看成长档案", en: "View growth archive", de: "Entwicklungsarchiv ansehen"),
            subtitle: l.tr(zh: "回顾长期趋势与照护故事", en: "Review trends and care story", de: "Trends und Pflegegeschichte ansehen"),
            icon: "sparkles.rectangle.stack.fill"
        )
    }
}

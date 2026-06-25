//
//  PetAllFeaturesSheet.swift
//  Ohana
//
//  Single-pet V4 feature hub.
//

import SwiftData
import SwiftUI

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
        case .health: "health"
        case .medications: "medications"
        case .food: "food"
        case .hygiene: "hygiene"
        case .walks: "walks"
        case .potty: "potty"
        case .basicInfo: "basicInfo"
        case .documents: "documents"
        case .moments: "moments"
        case .timeline: "timeline"
        case .achievements: "achievements"
        case .retention: "retention"
        case .weight: "weight"
        case .expense: "expense"
        case .bondVault: "bondVault"
        }
    }

    var petFeature: PetFeature? {
        switch self {
        case .health:
            .health
        case .medications:
            .medications
        case .food:
            .food
        case .hygiene:
            .hygiene
        case .walks:
            .walks
        case .potty:
            .potty
        case .basicInfo:
            .basicInfo
        case .documents:
            .documents
        case .moments, .timeline:
            .moments
        case .achievements:
            .achievements
        case .retention:
            .retention
        case .weight:
            .weight
        case .expense, .bondVault:
            .expense
        }
    }

    var isAvailableInMemorialMode: Bool {
        switch self {
        case .basicInfo, .documents, .moments, .timeline, .achievements, .retention:
            true
        case .health, .medications, .food, .hygiene, .walks, .potty, .weight, .expense, .bondVault:
            false
        }
    }
}

struct PetAllFeaturesActivitySummary: Equatable {
    let todayFeedCount: Int
    let todayNonFeedingCareCount: Int
    let totalNonFeedingCareCount: Int
    let todayPottyCount: Int
    let todayWalkCount: Int
    let totalWalkCount: Int
    let weekWalkDistanceMeters: Double
    let healthCount: Int
    let weightCount: Int
    let latestWeightKg: Double?
    let expenseCount: Int
    let expenseTotal: Double
    let photoCount: Int
    let milestoneCount: Int
    let documentCount: Int
    let protectionDocumentCount: Int
    let insuranceCount: Int
    let medicationCount: Int
    let activeMedicationCount: Int

    static let empty = PetAllFeaturesActivitySummary()

    init(
        todayFeedCount: Int = 0,
        todayNonFeedingCareCount: Int = 0,
        totalNonFeedingCareCount: Int = 0,
        todayPottyCount: Int = 0,
        todayWalkCount: Int = 0,
        totalWalkCount: Int = 0,
        weekWalkDistanceMeters: Double = 0,
        healthCount: Int = 0,
        weightCount: Int = 0,
        latestWeightKg: Double? = nil,
        expenseCount: Int = 0,
        expenseTotal: Double = 0,
        photoCount: Int = 0,
        milestoneCount: Int = 0,
        documentCount: Int = 0,
        protectionDocumentCount: Int = 0,
        insuranceCount: Int = 0,
        medicationCount: Int = 0,
        activeMedicationCount: Int = 0
    ) {
        self.todayFeedCount = todayFeedCount
        self.todayNonFeedingCareCount = todayNonFeedingCareCount
        self.totalNonFeedingCareCount = totalNonFeedingCareCount
        self.todayPottyCount = todayPottyCount
        self.todayWalkCount = todayWalkCount
        self.totalWalkCount = totalWalkCount
        self.weekWalkDistanceMeters = weekWalkDistanceMeters
        self.healthCount = healthCount
        self.weightCount = weightCount
        self.latestWeightKg = latestWeightKg
        self.expenseCount = expenseCount
        self.expenseTotal = expenseTotal
        self.photoCount = photoCount
        self.milestoneCount = milestoneCount
        self.documentCount = documentCount
        self.protectionDocumentCount = protectionDocumentCount
        self.insuranceCount = insuranceCount
        self.medicationCount = medicationCount
        self.activeMedicationCount = activeMedicationCount
    }

    var todayCareCount: Int {
        todayFeedCount + todayNonFeedingCareCount + todayPottyCount + todayWalkCount
    }

    @MainActor
    static func load(petID: UUID, context: ModelContext, now: Date = Date()) -> PetAllFeaturesActivitySummary {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? now
        let weekStart = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        let petSubjectKind = CareLedgerSubjectKind.pet.rawValue
        let petIDRaw = petID.uuidString
        let careKind = CareLedgerEventKind.care.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        let walkKind = CareLedgerEventKind.walk.rawValue
        let healthKind = CareLedgerEventKind.health.rawValue
        let weightKind = CareLedgerEventKind.weight.rawValue
        let expenseKind = CareLedgerEventKind.expense.rawValue
        let feedingType = CareType.feeding.rawValue

        let ledgerEvents = fetch(
            FetchDescriptor<CareLedgerEvent>(
                predicate: #Predicate<CareLedgerEvent> { event in
                    event.subjectKind == petSubjectKind &&
                        event.subjectId == petIDRaw
                },
                sortBy: [SortDescriptor(\.occurredAt, order: .forward)]
            ),
            context: context,
            operation: "fetch pet care ledger events"
        )
        let todayLedgerEvents = ledgerEvents.filter { event in
            event.occurredAt >= todayStart && event.occurredAt < todayEnd
        }
        let weekLedgerEvents = ledgerEvents.filter { event in
            event.occurredAt >= weekStart && event.occurredAt < todayEnd
        }
        let todayFeedCount = todayLedgerEvents.count { event in
            event.eventKind == careKind && event.actionType == feedingType
        }
        let todayNonFeedingCareCount = todayLedgerEvents.count { event in
            event.eventKind == careKind && event.actionType != feedingType
        }
        let totalNonFeedingCareCount = ledgerEvents.count { event in
            event.eventKind == careKind && event.actionType != feedingType
        }
        let todayPottyCount = todayLedgerEvents.count { event in
            event.eventKind == pottyKind
        }
        let todayWalkCount = todayLedgerEvents.count { event in
            event.eventKind == walkKind
        }
        let totalWalkCount = ledgerEvents.count { event in
            event.eventKind == walkKind
        }
        let weekWalkDistanceMeters = weekLedgerEvents.reduce(0.0) { total, event in
            guard event.eventKind == walkKind else { return total }
            return total + max(0, event.amountValue)
        }
        let healthCount = ledgerEvents.count { event in
            event.eventKind == healthKind
        }
        let weightEvents = ledgerEvents.filter { event in
            event.eventKind == weightKind
        }
        let expenseEvents = ledgerEvents.filter { event in
            event.eventKind == expenseKind
        }
        let latestWeightKg = weightEvents.max(by: { $0.occurredAt < $1.occurredAt })?.amountValue
        let documents = fetch(
            FetchDescriptor<PetDocument>(
                predicate: #Predicate<PetDocument> { document in
                    document.pet?.id == petID
                }
            ),
            context: context,
            operation: "fetch pet document counts"
        )
        let medications = fetch(
            FetchDescriptor<PetMedication>(
                predicate: #Predicate<PetMedication> { medication in
                    medication.pet?.id == petID
                }
            ),
            context: context,
            operation: "fetch pet medication counts"
        )
        let vaccineCategory = DocumentCategory.vaccine.rawValue
        let insuranceCategory = DocumentCategory.insurance.rawValue
        let protectionDocumentCount = documents.count { document in
            document.category != vaccineCategory && document.category != insuranceCategory
        }
        let insuranceCount = count(
            FetchDescriptor<PetInsurance>(
                predicate: #Predicate<PetInsurance> { insurance in
                    insurance.pet?.id == petID
                }
            ),
            context: context,
            operation: "count pet insurances"
        )
        let photoCount = count(
            FetchDescriptor<PetPhotoLog>(
                predicate: #Predicate<PetPhotoLog> { log in
                    log.pet?.id == petID
                }
            ),
            context: context,
            operation: "count pet photo logs"
        )
        let milestoneCount = count(
            FetchDescriptor<PetMilestone>(
                predicate: #Predicate<PetMilestone> { milestone in
                    milestone.pet?.id == petID
                }
            ),
            context: context,
            operation: "count pet milestones"
        )
        return PetAllFeaturesActivitySummary(
            todayFeedCount: todayFeedCount,
            todayNonFeedingCareCount: todayNonFeedingCareCount,
            totalNonFeedingCareCount: totalNonFeedingCareCount,
            todayPottyCount: todayPottyCount,
            todayWalkCount: todayWalkCount,
            totalWalkCount: totalWalkCount,
            weekWalkDistanceMeters: weekWalkDistanceMeters,
            healthCount: healthCount,
            weightCount: weightEvents.count,
            latestWeightKg: latestWeightKg,
            expenseCount: expenseEvents.count,
            expenseTotal: expenseEvents.reduce(0) { $0 + max(0, $1.amountValue) },
            photoCount: photoCount,
            milestoneCount: milestoneCount,
            documentCount: documents.count,
            protectionDocumentCount: protectionDocumentCount,
            insuranceCount: insuranceCount,
            medicationCount: medications.count,
            activeMedicationCount: medications.count { $0.isActive(on: now) }
        )
    }

    @MainActor
    private static func count(
        _ descriptor: FetchDescriptor<some PersistentModel>,
        context: ModelContext,
        operation: String
    ) -> Int {
        do {
            return try context.fetchCount(descriptor)
        } catch {
            OhanaLog.warning("PetAllFeaturesActivitySummary failed to \(operation): \(error.localizedDescription)", category: "Members")
            return 0
        }
    }

    @MainActor
    private static func fetch<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning("PetAllFeaturesActivitySummary failed to \(operation): \(error.localizedDescription)", category: "Members")
            return []
        }
    }
}

struct PetAllFeaturesSheet: View {
    let pet: Pet
    let activitySummary: PetAllFeaturesActivitySummary
    let onOpenDestination: (PetAllFeatureDestination) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(GrowthNewFeatureStore.revisionKey) private var newFeatureRevision = 0

    init(
        pet: Pet,
        activitySummary: PetAllFeaturesActivitySummary = .empty,
        onOpenDestination: @escaping (PetAllFeatureDestination) -> Void
    ) {
        self.pet = pet
        self.activitySummary = activitySummary
        self.onOpenDestination = onOpenDestination
    }

    private var l: L10n { L10n() }
    private var isDog: Bool {
        pet.species.localizedCaseInsensitiveContains("狗") ||
            pet.species.localizedCaseInsensitiveContains("dog")
    }

    private var archiveSnapshot: ArchiveMemorySnapshot { ArchiveMemorySnapshot(pet: pet, activitySummary: activitySummary) }

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

                ForEach(visiblePetSections) { section in
                    FeatureHubSectionActionView(section: section) { destination in
                        open(destination)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .petMemorialTone(isActive: pet.hasPassedAway)
        }
    }

    private func open(_ destination: PetAllFeatureDestination) {
        guard !pet.hasPassedAway || destination.isAvailableInMemorialMode else {
            return
        }
        if let feature = destination.petFeature {
            GrowthNewFeatureStore.markVisited(feature: feature)
        }
        onOpenDestination(destination)
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
                subtitle: l.tr(zh: "状态与趋势", en: "Status and trends", de: "Status und Trends"),
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

    private var visiblePetSections: [FeatureHubSectionData<PetAllFeatureDestination>] {
        guard pet.hasPassedAway else { return petSections }
        return petSections.compactMap { section in
            let items = section.items.filter(\.destination.isAvailableInMemorialMode)
            guard !items.isEmpty else { return nil }
            return FeatureHubSectionData(
                id: section.id,
                title: section.title,
                subtitle: section.subtitle,
                items: items
            )
        }
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
                value: "\(activitySummary.totalNonFeedingCareCount)",
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
                value: "\(activitySummary.healthCount)",
                subtitle: healthSub,
                icon: "cross.fill",
                tint: Color.goRed,
                destination: .health
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
                id: "basicInfo",
                title: l.tr(zh: "基础资料", en: "Profile", de: "Profil"),
                value: basicInfoStatusText,
                subtitle: basicInfoSub,
                icon: "pawprint.circle.fill",
                tint: Color(hex: pet.safeThemeColorHex),
                destination: .basicInfo
            ),
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
                value: "\(activitySummary.photoCount)",
                subtitle: momentsSub,
                icon: "sparkles",
                tint: Color(hex: "EC4899"),
                destination: .moments
            ),
            item(
                id: "documents",
                title: l.tr(zh: "证件保障", en: "Documents", de: "Dokumente"),
                value: "\(activitySummary.protectionDocumentCount + activitySummary.insuranceCount)",
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
        let showsNewFeature: Bool = {
            _ = newFeatureRevision
            return destination.petFeature.map { GrowthNewFeatureStore.hasPending(feature: $0) } ?? false
        }()

        return FeatureHubDestinationItem(
            data: FeatureHubTileData(
                id: id,
                title: title,
                value: value.isEmpty ? "--" : value,
                subtitle: subtitle,
                icon: icon,
                tint: tint,
                showsNewFeature: showsNewFeature
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

    private var healthSub: String {
        activitySummary.healthCount == 0
            ? l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge")
            : l.tr(zh: "\(activitySummary.healthCount)条记录", en: "\(activitySummary.healthCount) records", de: "\(activitySummary.healthCount) Einträge")
    }

    private var weightSub: String {
        activitySummary.weightCount == 0
            ? l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge")
            : l.tr(zh: "\(activitySummary.weightCount)条记录", en: "\(activitySummary.weightCount) records", de: "\(activitySummary.weightCount) Einträge")
    }

    private var medSub: String {
        let count = activitySummary.activeMedicationCount
        return count > 0
            ? l.tr(zh: "当前\(count)种药物", en: "\(count) active meds", de: "\(count) aktive Medikamente")
            : l.tr(zh: "暂无用药", en: "No medication", de: "Keine Medikamente")
    }

    private var foodSub: String {
        let count = activitySummary.todayFeedCount
        return count > 0
            ? l.tr(zh: "今日喂食\(count)次", en: "\(count) feeds today", de: "\(count) Fütterungen heute")
            : l.tr(zh: "今日未喂食", en: "No feed today", de: "Heute kein Futter")
    }

    private var hygieneSub: String {
        let count = activitySummary.totalNonFeedingCareCount
        return count > 0
            ? l.tr(zh: "\(count)条护理记录", en: "\(count) care logs", de: "\(count) Pflegeeinträge")
            : l.tr(zh: "暂无记录", en: "No records", de: "Keine Einträge")
    }

    private var walkSub: String {
        activitySummary.totalWalkCount == 0
            ? l.tr(zh: "暂无记录", en: "No walks yet", de: "Noch keine Gassi-Runden")
            : l.tr(
                zh: "\(activitySummary.totalWalkCount)次遛狗",
                en: "\(activitySummary.totalWalkCount) walks",
                de: "\(activitySummary.totalWalkCount) Runden"
            )
    }

    private var pottySub: String {
        let count = activitySummary.todayPottyCount
        return count > 0
            ? l.tr(zh: "今日\(count)次", en: "\(count) today", de: "\(count) heute")
            : l.tr(zh: "今日暂无记录", en: "No logs today", de: "Heute keine Einträge")
    }

    private var expenseSub: String {
        activitySummary.expenseCount == 0
            ? l.tr(zh: "暂无记录", en: "No expenses", de: "Keine Ausgaben")
            : l.tr(zh: "\(activitySummary.expenseCount)条花费记录", en: "\(activitySummary.expenseCount) expense logs", de: "\(activitySummary.expenseCount) Ausgaben")
    }

    private var momentsSub: String {
        activitySummary.photoCount == 0
            ? l.tr(zh: "暂无时刻", en: "No moments", de: "Keine Momente")
            : l.tr(zh: "\(activitySummary.photoCount)个时刻", en: "\(activitySummary.photoCount) moments", de: "\(activitySummary.photoCount) Momente")
    }

    private var basicInfoSub: String {
        if !pet.breed.isEmpty { return l.tr(zh: "品种已设置", en: "Breed set", de: "Rasse gesetzt") }
        if !pet.species.isEmpty { return l.tr(zh: "补充品种/日期", en: "Add breed or dates", de: "Rasse oder Daten ergänzen") }
        return l.tr(zh: "完善基本信息", en: "Complete profile", de: "Profil ergänzen")
    }

    private var basicInfoStatusText: String {
        hasCompleteBasicInfo
            ? l.tr(zh: "已完成", en: "Done", de: "Fertig")
            : l.tr(zh: "待补充", en: "To do", de: "Offen")
    }

    private var hasCompleteBasicInfo: Bool {
        !pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !pet.species.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !pet.breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            pet.birthday != nil &&
            pet.homeDate != nil
    }

    private var documentsSub: String {
        let documentCount = activitySummary.protectionDocumentCount
        let insuranceCount = activitySummary.insuranceCount
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
        activitySummary.milestoneCount == 0
            ? l.tr(zh: "暂无成就", en: "No awards", de: "Keine Erfolge")
            : l.tr(zh: "\(activitySummary.milestoneCount)个里程碑", en: "\(activitySummary.milestoneCount) milestones", de: "\(activitySummary.milestoneCount) Meilensteine")
    }

    private var todayFeedMetric: String {
        "\(activitySummary.todayFeedCount)"
    }

    private var todayPottyMetric: String {
        "\(activitySummary.todayPottyCount)"
    }

    private var latestWeightText: String {
        guard let latest = activitySummary.latestWeightKg else { return "--" }
        return String(format: "%.1f", latest)
    }

    private var weekWalkText: String {
        let km = activitySummary.weekWalkDistanceMeters / 1000
        return km >= 10 ? String(format: "%.0fkm", km) : String(format: "%.1fkm", km)
    }

    private var expenseMetric: String {
        AppCurrency.formatCompact(activitySummary.expenseTotal)
    }

    private var timelineCount: Int {
        activitySummary.photoCount + activitySummary.milestoneCount + activitySummary.healthCount + activitySummary.weightCount
    }

    private var todayCareCount: Int {
        activitySummary.todayCareCount
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
        case .basicInfo: .basicInfo
        case .documents: .documents
        case .moments: .moments
        case .weight: .weight
        case .retention: .retention
        }
    }
}

struct ArchiveMemorySnapshot {
    let score: Int
    let total: Int
    let nextStep: ArchiveMemoryNextStep

    init(pet: Pet, activitySummary: PetAllFeaturesActivitySummary) {
        self.init(
            hasBasicProfile: Self.hasBasicProfile(pet),
            healthCount: activitySummary.healthCount,
            weightCount: activitySummary.weightCount,
            photoCount: activitySummary.photoCount,
            milestoneCount: activitySummary.milestoneCount,
            documentCount: activitySummary.documentCount,
            insuranceCount: activitySummary.insuranceCount,
            medicationCount: activitySummary.medicationCount,
            currentStreak: pet.currentStreak
        )
    }

    private init(
        hasBasicProfile: Bool,
        healthCount: Int,
        weightCount: Int,
        photoCount: Int,
        milestoneCount: Int,
        documentCount: Int,
        insuranceCount: Int,
        medicationCount: Int,
        currentStreak: Int
    ) {
        let hasHealthOrWeight = healthCount > 0 || weightCount > 0
        let hasMemory = photoCount > 0 || milestoneCount > 0
        let hasProtectionDocument = documentCount > 0
        let hasProtection = hasProtectionDocument || insuranceCount > 0 || medicationCount > 0
        let hasContinuity = currentStreak > 0 || milestoneCount > 0
        let checks = [hasBasicProfile, hasHealthOrWeight, hasMemory, hasProtection, hasContinuity]

        self.score = checks.count(where: { $0 })
        self.total = checks.count
        self.nextStep = Self.nextStep(
            hasBasicProfile: hasBasicProfile,
            hasDocumentsOrInsurance: hasProtectionDocument || insuranceCount > 0,
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
                subtitle: l.tr(zh: "上传证件或保险资料", en: "Add ID or insurance files", de: "Ausweis oder Versicherung hinzufügen"),
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

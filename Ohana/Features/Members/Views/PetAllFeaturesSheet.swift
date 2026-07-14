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

nonisolated struct PetAllFeaturesActivitySummary: Equatable, Sendable {
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
    let foodChartPoints: [OhanaMinimalChartPoint]
    let careChartPoints: [OhanaMinimalChartPoint]
    let pottyChartPoints: [OhanaMinimalChartPoint]
    let walkChartPoints: [OhanaMinimalChartPoint]
    let healthChartPoints: [OhanaMinimalChartPoint]
    let weightChartPoints: [OhanaMinimalChartPoint]
    let expenseChartPoints: [OhanaMinimalChartPoint]
    let archiveChartPoints: [OhanaMinimalChartPoint]

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
        activeMedicationCount: Int = 0,
        foodChartPoints: [OhanaMinimalChartPoint] = [],
        careChartPoints: [OhanaMinimalChartPoint] = [],
        pottyChartPoints: [OhanaMinimalChartPoint] = [],
        walkChartPoints: [OhanaMinimalChartPoint] = [],
        healthChartPoints: [OhanaMinimalChartPoint] = [],
        weightChartPoints: [OhanaMinimalChartPoint] = [],
        expenseChartPoints: [OhanaMinimalChartPoint] = [],
        archiveChartPoints: [OhanaMinimalChartPoint] = []
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
        self.foodChartPoints = foodChartPoints
        self.careChartPoints = careChartPoints
        self.pottyChartPoints = pottyChartPoints
        self.walkChartPoints = walkChartPoints
        self.healthChartPoints = healthChartPoints
        self.weightChartPoints = weightChartPoints
        self.expenseChartPoints = expenseChartPoints
        self.archiveChartPoints = archiveChartPoints
    }

    var todayCareCount: Int {
        todayFeedCount + todayNonFeedingCareCount + todayPottyCount + todayWalkCount
    }

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
        let recentDays = recentDays(endingAt: todayStart, calendar: calendar)
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
            activeMedicationCount: medications.count { $0.isActive(on: now) },
            foodChartPoints: dailyEventPoints(
                days: recentDays,
                events: weekLedgerEvents,
                idPrefix: "pet-all-food"
            ) { $0.eventKind == careKind && $0.actionType == feedingType },
            careChartPoints: dailyEventPoints(
                days: recentDays,
                events: weekLedgerEvents,
                idPrefix: "pet-all-care"
            ) { $0.eventKind == careKind && $0.actionType != feedingType },
            pottyChartPoints: dailyEventPoints(
                days: recentDays,
                events: weekLedgerEvents,
                idPrefix: "pet-all-potty"
            ) { $0.eventKind == pottyKind },
            walkChartPoints: dailyEventPoints(
                days: recentDays,
                events: weekLedgerEvents,
                idPrefix: "pet-all-walk",
                value: { max(0, $0.amountValue) / 1000.0 }
            ) { $0.eventKind == walkKind },
            healthChartPoints: dailyEventPoints(
                days: recentDays,
                events: weekLedgerEvents,
                idPrefix: "pet-all-health"
            ) { $0.eventKind == healthKind },
            weightChartPoints: weightEvents.suffix(7).map {
                OhanaMinimalChartPoint(date: $0.occurredAt, value: max(0, $0.amountValue), id: "pet-all-weight-\($0.id.uuidString)")
            },
            expenseChartPoints: dailyEventPoints(
                days: recentDays,
                events: expenseEvents.filter { $0.occurredAt >= weekStart && $0.occurredAt < todayEnd },
                idPrefix: "pet-all-expense",
                value: { max(0, $0.amountValue) }
            ) { $0.eventKind == expenseKind },
            archiveChartPoints: FeatureHubChartPointFactory.bars(
                [Double(documents.count), Double(photoCount), Double(milestoneCount), Double(insuranceCount)],
                idPrefix: "pet-all-archive"
            )
        )
    }

    private static func recentDays(endingAt todayStart: Date, calendar: Calendar) -> [Date] {
        (0 ..< 7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: todayStart)
        }
    }

    private static func dailyEventPoints(
        days: [Date],
        events: [CareLedgerEvent],
        idPrefix: String,
        value: (CareLedgerEvent) -> Double = { _ in 1 },
        matches: (CareLedgerEvent) -> Bool
    ) -> [OhanaMinimalChartPoint] {
        let calendar = Calendar.current
        return days.enumerated().map { index, day in
            let total = events.reduce(0.0) { partial, event in
                guard matches(event), calendar.isDate(event.occurredAt, inSameDayAs: day) else {
                    return partial
                }
                return partial + max(0, value(event))
            }
            return OhanaMinimalChartPoint(
                date: day,
                value: total,
                id: "\(idPrefix)-\(index)-\(Int((total * 1000).rounded()))"
            )
        }
    }

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
        Pet.isDogSpecies(pet.species)
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
                            imageCacheID: "pet-all-features-\(pet.id.uuidString)",
                            imageSignature: pet.avatarThumbnailSignature,
                            petModelID: pet.persistentModelID,
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

                FeatureHubSummaryPanel(
                    title: l.tr(zh: "宠物摘要", en: "Pet Summary", de: "Tierübersicht"),
                    statusText: petSummaryStatusText,
                    statusTint: petSummaryStatusTint,
                    metrics: petMetrics
                )
                .accessibilityIdentifier("pet-all-features-summary-panel")

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
                chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.foodChartPoints),
                destination: .food
            ),
            item(
                id: "hygiene",
                title: l.tr(zh: "清洁护理", en: "Care", de: "Pflege"),
                value: "\(activitySummary.totalNonFeedingCareCount)",
                subtitle: hygieneSub,
                icon: "bubbles.and.sparkles.fill",
                tint: Color.goTeal,
                chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.careChartPoints),
                destination: .hygiene
            ),
            item(
                id: "potty",
                title: l.tr(zh: "便便", en: "Potty", de: "Kot"),
                value: todayPottyMetric,
                subtitle: pottySub,
                icon: "drop.fill",
                tint: Color(hex: "D97706"),
                chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.pottyChartPoints),
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
                    tint: Color(hex: "FF8A0F"),
                    chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.walkChartPoints),
                    appearance: .orangeLight,
                    supportingMetrics: walkSupportingMetrics,
                    progress: walkProgress,
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
                chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.healthChartPoints),
                destination: .health
            ),
            item(
                id: "weight",
                title: l.tr(zh: "体重", en: "Weight", de: "Gewicht"),
                value: latestWeightText,
                subtitle: weightSub,
                icon: "scalemass.fill",
                tint: Color(hex: "16A34A"),
                chart: FeatureHubMiniChartData(style: .trend, points: activitySummary.weightChartPoints),
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
                chart: FeatureHubMiniChartData(
                    style: .bar,
                    points: FeatureHubChartPointFactory.level(
                        current: hasCompleteBasicInfo ? 1 : 0,
                        total: 1,
                        idPrefix: "pet-all-basic"
                    )
                ),
                destination: .basicInfo
            ),
            item(
                id: "retention",
                title: l.tr(zh: "成长档案", en: "Growth", de: "Entwicklung"),
                value: "\(archiveSnapshot.score)/\(archiveSnapshot.total)",
                subtitle: archiveSnapshot.nextStep.title,
                icon: "sparkles.rectangle.stack.fill",
                tint: Color(hex: pet.safeThemeColorHex),
                chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.archiveChartPoints),
                destination: .retention
            ),
            item(
                id: "moments",
                title: l.tr(zh: "记录中心", en: "Moments", de: "Momente"),
                value: "\(activitySummary.photoCount)",
                subtitle: momentsSub,
                icon: "sparkles",
                tint: Color(hex: "EC4899"),
                chart: FeatureHubMiniChartData(
                    style: .bar,
                    points: FeatureHubChartPointFactory.bars(
                        [Double(activitySummary.photoCount), Double(activitySummary.milestoneCount)],
                        idPrefix: "pet-all-moments"
                    )
                ),
                destination: .moments
            ),
            item(
                id: "documents",
                title: l.tr(zh: "证件保障", en: "Documents", de: "Dokumente"),
                value: "\(activitySummary.protectionDocumentCount + activitySummary.insuranceCount)",
                subtitle: documentsSub,
                icon: "doc.fill",
                tint: Color(hex: "94A3B8"),
                chart: FeatureHubMiniChartData(
                    style: .bar,
                    points: FeatureHubChartPointFactory.bars(
                        [Double(activitySummary.protectionDocumentCount), Double(activitySummary.insuranceCount)],
                        idPrefix: "pet-all-documents"
                    )
                ),
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
                chart: FeatureHubMiniChartData(
                    style: .bar,
                    points: FeatureHubChartPointFactory.quietPlaceholder(
                        seed: Double(max(1, pet.coconutBalance)),
                        idPrefix: "pet-all-bond"
                    )
                ),
                destination: .bondVault
            ),
            item(
                id: "expense",
                title: l.tr(zh: "花费", en: "Expenses", de: "Ausgaben"),
                value: expenseMetric,
                subtitle: expenseSub,
                icon: "creditcard.fill",
                tint: Color.goOrange,
                chart: FeatureHubMiniChartData(style: .bar, points: activitySummary.expenseChartPoints),
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
        chart: FeatureHubMiniChartData? = nil,
        appearance: FeatureHubTileAppearance = .standard,
        supportingMetrics: [FeatureHubSupportingMetric] = [],
        progress: Double? = nil,
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
                chart: chart,
                appearance: appearance,
                supportingMetrics: supportingMetrics,
                progress: progress,
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

    private var petSummaryStatusText: String {
        if pet.hasPassedAway {
            return l.tr(zh: "纪念模式", en: "Memorial", de: "Gedenken")
        }
        if todayCareCount > 0 {
            return l.tr(zh: "\(todayCareCount) 项今日记录", en: "\(todayCareCount) logs today", de: "\(todayCareCount) Einträge heute")
        }
        return l.tr(zh: "今日稳定", en: "Steady today", de: "Heute stabil")
    }

    private var petSummaryStatusTint: Color {
        if pet.hasPassedAway {
            return Color.ohanaSecondaryText
        }
        return todayCareCount > 0 ? Color.goYellow : Color.goTeal
    }

    private var petSubtitle: String {
        let summary = pet.localizedSpeciesBreedSummary(l: l)
        if !summary.isEmpty { return summary }
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

    private var walkSupportingMetrics: [FeatureHubSupportingMetric] {
        [
            FeatureHubSupportingMetric(
                id: "week-distance",
                title: l.tr(zh: "本周", en: "Week", de: "Woche"),
                value: weekWalkText,
                icon: "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill"
            ),
            FeatureHubSupportingMetric(
                id: "today-count",
                title: l.tr(zh: "今日", en: "Today", de: "Heute"),
                value: "\(activitySummary.todayWalkCount)",
                icon: "calendar"
            ),
            FeatureHubSupportingMetric(
                id: "total-count",
                title: l.tr(zh: "总计", en: "Total", de: "Gesamt"),
                value: "\(activitySummary.totalWalkCount)",
                icon: "figure.walk"
            )
        ]
    }

    private var walkProgress: Double {
        let weekKilometers = max(0, activitySummary.weekWalkDistanceMeters / 1000)
        if pet.weeklyWalkGoalKm > 0 {
            return min(1, weekKilometers / pet.weeklyWalkGoalKm)
        }

        let points = activitySummary.walkChartPoints
        guard !points.isEmpty else { return 0 }
        return Double(points.count { $0.value > 0 }) / Double(points.count)
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

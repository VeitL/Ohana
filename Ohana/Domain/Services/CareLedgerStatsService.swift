//
//  CareLedgerStatsService.swift
//  Ohana
//
//  Read helpers for analytics built on the canonical care ledger.
//

import Foundation

nonisolated struct CareLedgerStatsService {
    struct SubjectCoverage: Hashable, Sendable {
        let kindRaw: String
        let id: String
        let name: String

        var isPet: Bool {
            kindRaw == CareLedgerSubjectKind.pet.rawValue
        }

        var isPlant: Bool {
            kindRaw == CareLedgerSubjectKind.plant.rawValue
        }
    }

    struct Totals: Equatable, Sendable {
        let workloadCount: Int
        let coverageCount: Int
        let petCoverageCount: Int
        let plantCoverageCount: Int

        static let zero = Totals(
            workloadCount: 0,
            coverageCount: 0,
            petCoverageCount: 0,
            plantCoverageCount: 0
        )
    }

    struct ReportEntry: Identifiable, Sendable {
        let id: UUID
        let date: Date
        let actorId: String?
        let participantActorIds: [String]
        let actorName: String
        let petName: String
        let operationIdentity: String
        let subjectCoverages: [SubjectCoverage]
        let title: String
        let icon: String
        let colorToken: DomainColorToken
        let coconuts: Int

        var coverageCount: Int {
            subjectCoverages.count
        }

        init(
            id: UUID = UUID(),
            date: Date,
            actorId: String?,
            participantActorIds: [String] = [],
            actorName: String,
            petName: String,
            operationIdentity: String = "",
            subjectCoverages: [SubjectCoverage] = [],
            title: String,
            icon: String,
            colorToken: DomainColorToken,
            coconuts: Int
        ) {
            self.id = id
            self.date = date
            self.actorId = actorId
            self.participantActorIds = participantActorIds
            self.actorName = actorName
            self.petName = petName
            self.operationIdentity = operationIdentity
            self.subjectCoverages = subjectCoverages
            self.title = title
            self.icon = icon
            self.colorToken = colorToken
            self.coconuts = coconuts
        }
    }

    func reportEntries(
        events: [CareLedgerEvent],
        pets: [Pet],
        plants: [Plant] = [],
        humans: [Human],
        interval: DateInterval,
        l: L10n = .current
    ) -> [ReportEntry] {
        let subjectCatalog = SubjectCatalog(pets: pets, plants: plants)
        let humanById = Dictionary(uniqueKeysWithValues: humans.map { ($0.id.uuidString, $0) })
        let reportableEvents = reportableEvents(
            events,
            subjectCatalog: subjectCatalog,
            interval: interval
        )
        return Dictionary(grouping: reportableEvents) { operationIdentity(for: $0) }
            .compactMap { operationIdentity, operationEvents in
                makeReportEntry(
                    operationIdentity: operationIdentity,
                    events: operationEvents,
                    subjectCatalog: subjectCatalog,
                    humanById: humanById,
                    l: l
                )
            }
            .sorted { $0.date > $1.date }
    }

    func count(
        events: [CareLedgerEvent],
        pets: [Pet],
        plants: [Plant] = [],
        interval: DateInterval
    ) -> Int {
        totals(events: events, pets: pets, plants: plants, interval: interval).workloadCount
    }

    func coverageCount(
        events: [CareLedgerEvent],
        pets: [Pet],
        plants: [Plant] = [],
        interval: DateInterval
    ) -> Int {
        totals(events: events, pets: pets, plants: plants, interval: interval).coverageCount
    }

    func totals(
        events: [CareLedgerEvent],
        pets: [Pet],
        plants: [Plant] = [],
        interval: DateInterval
    ) -> Totals {
        let subjectCatalog = SubjectCatalog(pets: pets, plants: plants)
        let reportableEvents = reportableEvents(
            events,
            subjectCatalog: subjectCatalog,
            interval: interval
        )
        guard !reportableEvents.isEmpty else { return .zero }

        let workloadCount = Set(reportableEvents.map { operationIdentity(for: $0) }).count
        var coverageKeys = Set<String>()
        var petCoverageCount = 0
        var plantCoverageCount = 0
        for event in reportableEvents {
            guard let subjectId = event.subjectId else { continue }
            let key = "\(operationIdentity(for: event))|\(event.subjectKind)|\(subjectId)"
            guard coverageKeys.insert(key).inserted else { continue }
            if event.subjectKind == CareLedgerSubjectKind.pet.rawValue {
                petCoverageCount += 1
            } else if event.subjectKind == CareLedgerSubjectKind.plant.rawValue {
                plantCoverageCount += 1
            }
        }
        return Totals(
            workloadCount: workloadCount,
            coverageCount: coverageKeys.count,
            petCoverageCount: petCoverageCount,
            plantCoverageCount: plantCoverageCount
        )
    }

    func operationIdentity(for event: CareLedgerEvent) -> String {
        if let sharedSessionId = CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.sharedSessionId,
            in: event.metadataJSON
        ) {
            return "shared:\(normalizedOperationComponent(sharedSessionId))"
        }
        if let careTransactionId = CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.careTransactionId,
            in: event.metadataJSON
        ) {
            return "plant:\(normalizedOperationComponent(careTransactionId))"
        }
        if let batchID = CareLedgerMetadata.stringValue(
            named: CareLedgerMetadata.batchID,
            in: event.metadataJSON
        ) {
            return "batch:\(normalizedOperationComponent(batchID))"
        }
        return "ledger:\(event.id.uuidString.lowercased())"
    }

    private struct SubjectCatalog {
        let petNamesById: [String: String]
        let plantNamesById: [String: String]

        init(pets: [Pet], plants: [Plant]) {
            petNamesById = Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, $0.name) })
            plantNamesById = Dictionary(uniqueKeysWithValues: plants.map { ($0.id.uuidString, $0.name) })
        }

        func name(for event: CareLedgerEvent) -> String? {
            guard let subjectId = event.subjectId else { return nil }
            switch event.subjectKind {
            case CareLedgerSubjectKind.pet.rawValue:
                return petNamesById[subjectId]
            case CareLedgerSubjectKind.plant.rawValue:
                return plantNamesById[subjectId]
            default:
                return nil
            }
        }
    }

    private func reportableEvents(
        _ events: [CareLedgerEvent],
        subjectCatalog: SubjectCatalog,
        interval: DateInterval
    ) -> [CareLedgerEvent] {
        events.filter { event in
            interval.contains(event.occurredAt) &&
                subjectCatalog.name(for: event) != nil &&
                isReportable(event)
        }
    }

    private func isReportable(_ event: CareLedgerEvent) -> Bool {
        switch event.subjectKind {
        case CareLedgerSubjectKind.pet.rawValue:
            switch event.eventKindEnum {
            case .care, .potty, .walk, .hygiene, .health, .weight, .medication, .expense:
                true
            case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
                false
            }
        case CareLedgerSubjectKind.plant.rawValue:
            event.eventKindEnum == .plantCare
        default:
            false
        }
    }

    private func makeReportEntry(
        operationIdentity: String,
        events: [CareLedgerEvent],
        subjectCatalog: SubjectCatalog,
        humanById: [String: Human],
        l: L10n
    ) -> ReportEntry? {
        guard let representative = representativeEvent(in: events) else { return nil }
        let coverages = subjectCoverages(events: events, subjectCatalog: subjectCatalog)
        guard !coverages.isEmpty else { return nil }
        let participantActorIds = participantActorIds(events: events)
        let primaryActorId = representative.actorId ?? participantActorIds.first
        let actor = primaryActorId.flatMap { humanById[$0] }
        let title = operationTitle(events: events, representative: representative, l: l)

        return ReportEntry(
            id: representative.id,
            date: events.map(\.occurredAt).max() ?? representative.occurredAt,
            actorId: primaryActorId,
            participantActorIds: participantActorIds,
            actorName: actor?.name ?? unassignedActorTitle(l: l),
            petName: coverageDisplayName(coverages, l: l),
            operationIdentity: operationIdentity,
            subjectCoverages: coverages,
            title: title,
            icon: icon(for: representative),
            colorToken: colorToken(for: representative),
            coconuts: events.reduce(0) { $0 + max($1.coconutDelta, 0) }
        )
    }

    private func representativeEvent(in events: [CareLedgerEvent]) -> CareLedgerEvent? {
        events.first(where: { $0.coconutDelta > 0 }) ?? events.min {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    private func subjectCoverages(
        events: [CareLedgerEvent],
        subjectCatalog: SubjectCatalog
    ) -> [SubjectCoverage] {
        var seen = Set<String>()
        return events
            .sorted {
                if $0.occurredAt == $1.occurredAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.occurredAt < $1.occurredAt
            }
            .compactMap { event in
                guard let subjectId = event.subjectId,
                      let name = subjectCatalog.name(for: event) else { return nil }
                let key = "\(event.subjectKind)|\(subjectId)"
                guard seen.insert(key).inserted else { return nil }
                return SubjectCoverage(kindRaw: event.subjectKind, id: subjectId, name: name)
            }
    }

    private func participantActorIds(events: [CareLedgerEvent]) -> [String] {
        var result: [String] = []
        func append(_ raw: String?) {
            let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !normalized.isEmpty, !result.contains(normalized) else { return }
            result.append(normalized)
        }

        for event in events.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            append(event.actorId)
            CareLedgerMetadata.stringArrayValue(named: "executorIds", in: event.metadataJSON)
                .forEach { append($0) }
        }
        return result
    }

    private func coverageDisplayName(_ coverages: [SubjectCoverage], l: L10n) -> String {
        guard let first = coverages.first else { return unknownSubjectTitle(l: l) }
        guard coverages.count > 1 else { return first.name }
        return l.tr(
            zh: "\(first.name) 等 \(coverages.count) 个对象",
            en: "\(first.name) +\(coverages.count - 1)",
            de: "\(first.name) +\(coverages.count - 1)"
        )
    }

    private func operationTitle(
        events: [CareLedgerEvent],
        representative: CareLedgerEvent,
        l: L10n
    ) -> String {
        let actionKeys = Set(events.map { "\($0.eventKind)|\($0.actionType)" })
        guard actionKeys.count > 1 else { return title(for: representative, l: l) }
        if events.allSatisfy({ $0.eventKindEnum == .plantCare }) {
            return l.tr(zh: "批量植物照顾", en: "Batch plant care", de: "Pflanzen-Sammelpflege")
        }
        return l.tr(zh: "共同照顾", en: "Shared care", de: "Gemeinsame Pflege")
    }

    private func normalizedOperationComponent(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func title(for event: CareLedgerEvent, l: L10n) -> String {
        switch event.eventKindEnum {
        case .care:
            CareType(rawValue: event.actionType).map { careTitle($0, l: l) } ?? event.actionType
        case .potty:
            PottyType(rawValue: event.actionType)?.localizedLabel(l) ?? event.actionType
        case .walk:
            l.tr(zh: "遛狗", en: "Walk", de: "Spaziergang")
        case .expense:
            ExpenseCategory(rawValue: event.actionType).map { l.expenseCategoryTitle($0) } ?? event.actionType
        case .hygiene:
            HygieneType(rawValue: event.actionType).map { hygieneTitle($0, l: l) } ?? event.actionType
        case .health:
            l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .medication:
            l.tr(zh: "吃药", en: "Medication", de: "Medikament")
        case .plantCare:
            PlantCareType(rawValue: event.actionType)?.displayName(l: l) ?? event.actionType
        case .reminder, .coconut, .workout, .milestone, .unknown:
            event.actionType
        }
    }

    private func unknownSubjectTitle(l: L10n) -> String {
        l.tr(zh: "未知对象", en: "Unknown subject", de: "Unbekanntes Objekt")
    }

    private func unassignedActorTitle(l: L10n) -> String {
        l.tr(zh: "未指定", en: "Unassigned", de: "Nicht zugewiesen")
    }

    private func careTitle(_ type: CareType, l: L10n) -> String {
        switch type {
        case .feeding:
            l.tr(zh: "喂食", en: "Feeding", de: "Fütterung")
        case .watering:
            l.tr(zh: "喂水", en: "Water", de: "Wasser")
        case .litter:
            l.tr(zh: "铲屎", en: "Litter", de: "Klo")
        case .waterChange:
            l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterClean:
            l.tr(zh: "清理滤材", en: "Filter cleaning", de: "Filterreinigung")
        case .cageCleaning:
            l.tr(zh: "清理鸟笼", en: "Cage cleaning", de: "Käfigreinigung")
        case .freeFlight:
            l.tr(zh: "放飞互动", en: "Free flight", de: "Freiflug")
        case .misting:
            l.tr(zh: "喷水保湿", en: "Misting", de: "Befeuchten")
        case .substrateChange:
            l.tr(zh: "换垫材", en: "Substrate change", de: "Substratwechsel")
        case .play:
            l.tr(zh: "逗玩", en: "Play", de: "Spielen")
        }
    }

    private func hygieneTitle(_ type: HygieneType, l: L10n) -> String {
        switch type {
        case .teeth:
            l.tr(zh: "刷牙", en: "Teeth", de: "Zähne")
        case .nails:
            l.tr(zh: "剪甲", en: "Nails", de: "Krallen")
        case .ears:
            l.tr(zh: "清耳", en: "Ears", de: "Ohren")
        case .brushing:
            l.tr(zh: "梳毛", en: "Brushing", de: "Bürsten")
        case .bath:
            l.tr(zh: "洗澡", en: "Bath", de: "Bad")
        }
    }

    private func icon(for event: CareLedgerEvent) -> String {
        switch event.eventKindEnum {
        case .care:
            CareType(rawValue: event.actionType)?.systemIconName ?? "checkmark.circle.fill"
        case .potty:
            PottyType(rawValue: event.actionType)?.systemIconName ?? "allergens"
        case .walk:
            "figure.walk"
        case .expense:
            ExpenseCategory(rawValue: event.actionType)?.systemIconName ?? AppCurrency.systemIconName
        case .hygiene:
            HygieneType(rawValue: event.actionType)?.systemIconName ?? "sparkles"
        case .health:
            "heart.fill"
        case .weight:
            "scalemass.fill"
        case .medication:
            "pills.fill"
        case .plantCare:
            PlantCareType(rawValue: event.actionType)?.careCategory.icon ?? "leaf.fill"
        case .reminder, .coconut, .workout, .milestone, .unknown:
            "circle.grid.2x2.fill"
        }
    }

    private func colorToken(for event: CareLedgerEvent) -> DomainColorToken {
        switch event.eventKindEnum {
        case .care:
            .hex(CareType(rawValue: event.actionType)?.accentColorHex ?? OhanaThemeColorPolicy.petFallbackHex)
        case .potty:
            .goOrange
        case .walk:
            .goTeal
        case .expense:
            .goYellow
        case .hygiene:
            .goPrimary
        case .health:
            .goRed
        case .weight:
            .hex("80FFEA")
        case .medication:
            .hex("A78BFA")
        case .plantCare:
            .goTeal
        case .reminder, .coconut, .workout, .milestone, .unknown:
            .goPrimary
        }
    }
}

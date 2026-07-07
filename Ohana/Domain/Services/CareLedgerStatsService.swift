//
//  CareLedgerStatsService.swift
//  Ohana
//
//  Read helpers for analytics built on the canonical care ledger.
//

import Foundation

nonisolated struct CareLedgerStatsService {
    struct ReportEntry: Identifiable, Sendable {
        let id: UUID
        let date: Date
        let actorId: String?
        let actorName: String
        let petName: String
        let title: String
        let icon: String
        let colorToken: DomainColorToken
        let coconuts: Int

        init(
            id: UUID = UUID(),
            date: Date,
            actorId: String?,
            actorName: String,
            petName: String,
            title: String,
            icon: String,
            colorToken: DomainColorToken,
            coconuts: Int
        ) {
            self.id = id
            self.date = date
            self.actorId = actorId
            self.actorName = actorName
            self.petName = petName
            self.title = title
            self.icon = icon
            self.colorToken = colorToken
            self.coconuts = coconuts
        }
    }

    func reportEntries(
        events: [CareLedgerEvent],
        pets: [Pet],
        humans: [Human],
        interval: DateInterval,
        l: L10n = .current
    ) -> [ReportEntry] {
        let petById = Dictionary(uniqueKeysWithValues: pets.map { ($0.id.uuidString, $0) })
        let humanById = Dictionary(uniqueKeysWithValues: humans.map { ($0.id.uuidString, $0) })
        return events
            .filter { event in
                interval.contains(event.occurredAt)
                    && event.subjectKind == CareLedgerSubjectKind.pet.rawValue
                    && event.subjectId.flatMap { petById[$0] } != nil
                    && isReportable(event.eventKindEnum)
            }
            .map { event in
                let petName = event.subjectId.flatMap { petById[$0]?.name } ?? unknownPetTitle(l: l)
                let actor = event.actorId.flatMap { humanById[$0] }
                return ReportEntry(
                    id: event.id,
                    date: event.occurredAt,
                    actorId: event.actorId,
                    actorName: actor?.name ?? unassignedActorTitle(l: l),
                    petName: petName,
                    title: title(for: event, l: l),
                    icon: icon(for: event),
                    colorToken: colorToken(for: event),
                    coconuts: max(event.coconutDelta, 0)
                )
            }
            .sorted { $0.date > $1.date }
    }

    func count(
        events: [CareLedgerEvent],
        pets: [Pet],
        interval: DateInterval
    ) -> Int {
        let petIds = Set(pets.map(\.id.uuidString))
        return events.count(where: { event in
            interval.contains(event.occurredAt)
                && event.subjectKind == CareLedgerSubjectKind.pet.rawValue
                && event.subjectId.map { petIds.contains($0) } == true
                && isReportable(event.eventKindEnum)
        })
    }

    private func isReportable(_ kind: CareLedgerEventKind) -> Bool {
        switch kind {
        case .care, .potty, .walk, .hygiene, .health, .weight, .medication, .expense:
            true
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            false
        }
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
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            event.actionType
        }
    }

    private func unknownPetTitle(l: L10n) -> String {
        l.tr(zh: "未知宠物", en: "Unknown pet", de: "Unbekanntes Haustier")
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
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
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
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            .goPrimary
        }
    }
}

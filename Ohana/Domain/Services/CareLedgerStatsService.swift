//
//  CareLedgerStatsService.swift
//  Ohana
//
//  Read helpers for analytics built on the canonical care ledger.
//

import Foundation

struct CareLedgerStatsService {
    struct ReportEntry: Identifiable {
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
        interval: DateInterval
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
                let petName = event.subjectId.flatMap { petById[$0]?.name } ?? "未知宠物"
                let actor = event.actorId.flatMap { humanById[$0] }
                return ReportEntry(
                    id: event.id,
                    date: event.occurredAt,
                    actorId: event.actorId,
                    actorName: actor?.name ?? "未指定",
                    petName: petName,
                    title: title(for: event),
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

    private func title(for event: CareLedgerEvent) -> String {
        switch event.eventKindEnum {
        case .care:
            CareType(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .potty:
            PottyType(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .walk:
            "遛狗"
        case .expense:
            ExpenseCategory(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .hygiene:
            HygieneType(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .health:
            "健康"
        case .weight:
            "体重"
        case .medication:
            "吃药"
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            event.actionType
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

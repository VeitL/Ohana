//
//  CareLedgerStatsService.swift
//  Ohana
//
//  Read helpers for analytics built on the canonical care ledger.
//

import SwiftUI

enum CareLedgerStatsService {
    struct ReportEntry: Identifiable {
        let id: UUID
        let date: Date
        let actorId: String?
        let actorName: String
        let petName: String
        let title: String
        let icon: String
        let color: Color
        let coconuts: Int

        init(
            id: UUID = UUID(),
            date: Date,
            actorId: String?,
            actorName: String,
            petName: String,
            title: String,
            icon: String,
            color: Color,
            coconuts: Int
        ) {
            self.id = id
            self.date = date
            self.actorId = actorId
            self.actorName = actorName
            self.petName = petName
            self.title = title
            self.icon = icon
            self.color = color
            self.coconuts = coconuts
        }
    }

    static func reportEntries(
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
                    color: color(for: event),
                    coconuts: max(event.coconutDelta, 0)
                )
            }
            .sorted { $0.date > $1.date }
    }

    static func count(
        events: [CareLedgerEvent],
        pets: [Pet],
        interval: DateInterval
    ) -> Int {
        let petIds = Set(pets.map { $0.id.uuidString })
        return events.filter { event in
            interval.contains(event.occurredAt)
                && event.subjectKind == CareLedgerSubjectKind.pet.rawValue
                && event.subjectId.map { petIds.contains($0) } == true
                && isReportable(event.eventKindEnum)
        }.count
    }

    private static func isReportable(_ kind: CareLedgerEventKind) -> Bool {
        switch kind {
        case .care, .potty, .walk, .hygiene, .health, .weight, .medication, .expense:
            return true
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            return false
        }
    }

    private static func title(for event: CareLedgerEvent) -> String {
        switch event.eventKindEnum {
        case .care:
            return CareType(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .potty:
            return PottyType(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .walk:
            return "遛狗"
        case .expense:
            return ExpenseCategory(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .hygiene:
            return HygieneType(rawValue: event.actionType)?.rawValue ?? event.actionType
        case .health:
            return "健康"
        case .weight:
            return "体重"
        case .medication:
            return "吃药"
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            return event.actionType
        }
    }

    private static func icon(for event: CareLedgerEvent) -> String {
        switch event.eventKindEnum {
        case .care:
            return CareType(rawValue: event.actionType)?.systemIconName ?? "checkmark.circle.fill"
        case .potty:
            return PottyType(rawValue: event.actionType)?.systemIconName ?? "allergens"
        case .walk:
            return "figure.walk"
        case .expense:
            return ExpenseCategory(rawValue: event.actionType)?.systemIconName ?? "yensign.circle"
        case .hygiene:
            return HygieneType(rawValue: event.actionType)?.systemIconName ?? "sparkles"
        case .health:
            return "heart.fill"
        case .weight:
            return "scalemass.fill"
        case .medication:
            return "pills.fill"
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            return "circle.grid.2x2.fill"
        }
    }

    private static func color(for event: CareLedgerEvent) -> Color {
        switch event.eventKindEnum {
        case .care:
            return Color(hex: CareType(rawValue: event.actionType)?.accentColorHex ?? "C8FF00")
        case .potty:
            return .goOrange
        case .walk:
            return .goTeal
        case .expense:
            return .goYellow
        case .hygiene:
            return .goPrimary
        case .health:
            return .goRed
        case .weight:
            return Color(hex: "80FFEA")
        case .medication:
            return Color(hex: "A78BFA")
        case .reminder, .plantCare, .coconut, .workout, .milestone, .unknown:
            return .goPrimary
        }
    }
}

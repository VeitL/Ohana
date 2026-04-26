//
//  CareLedgerEvent.swift
//  Ohana
//
//  Canonical event ledger for care, reminders, economy, and backup sync.
//

import Foundation
import SwiftData

enum CareLedgerActorKind: String, Codable, CaseIterable {
    case human
    case pet
    case plant
    case system
    case unknown
}

enum CareLedgerSubjectKind: String, Codable, CaseIterable {
    case pet
    case human
    case plant
    case household
    case system
    case unknown
}

enum CareLedgerEventKind: String, Codable, CaseIterable {
    case care
    case potty
    case walk
    case hygiene
    case health
    case weight
    case medication
    case workout
    case expense
    case reminder
    case plantCare
    case coconut
    case milestone
    case unknown
}

enum CareLedgerSource: String, Codable, CaseIterable {
    case quickAction
    case detail
    case reminder
    case notification
    case calendar
    case economy
    case backfill
    case service
    case importData
}

@Model
final class CareLedgerEvent {
    #Index<CareLedgerEvent>([\.occurredAt], [\.legacyModelName], [\.legacyModelId])

    var id: UUID
    var occurredAt: Date
    var actorKind: String
    var actorId: String?
    var subjectKind: String
    var subjectId: String?
    var eventKind: String
    var actionType: String
    var amountValue: Double
    var amountUnit: String
    var note: String
    var source: String
    var sourceEventId: String?
    var sourceReminderId: String?
    var legacyModelName: String?
    var legacyModelId: String?
    var coconutDelta: Int
    var rewardLogId: String?
    var privacyFieldRaw: String?
    var metadataJSON: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        actorKind: CareLedgerActorKind = .unknown,
        actorId: String? = nil,
        subjectKind: CareLedgerSubjectKind = .unknown,
        subjectId: String? = nil,
        eventKind: CareLedgerEventKind = .unknown,
        actionType: String,
        amountValue: Double = 0,
        amountUnit: String = "",
        note: String = "",
        source: CareLedgerSource = .service,
        sourceEventId: String? = nil,
        sourceReminderId: String? = nil,
        legacyModelName: String? = nil,
        legacyModelId: String? = nil,
        coconutDelta: Int = 0,
        rewardLogId: String? = nil,
        privacyFieldRaw: String? = nil,
        metadataJSON: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.actorKind = actorKind.rawValue
        self.actorId = actorId
        self.subjectKind = subjectKind.rawValue
        self.subjectId = subjectId
        self.eventKind = eventKind.rawValue
        self.actionType = actionType
        self.amountValue = amountValue
        self.amountUnit = amountUnit
        self.note = note
        self.source = source.rawValue
        self.sourceEventId = sourceEventId
        self.sourceReminderId = sourceReminderId
        self.legacyModelName = legacyModelName
        self.legacyModelId = legacyModelId
        self.coconutDelta = coconutDelta
        self.rewardLogId = rewardLogId
        self.privacyFieldRaw = privacyFieldRaw
        self.metadataJSON = metadataJSON
        self.createdAt = createdAt
    }

    var eventKindEnum: CareLedgerEventKind {
        CareLedgerEventKind(rawValue: eventKind) ?? .unknown
    }

    var sourceEnum: CareLedgerSource {
        CareLedgerSource(rawValue: source) ?? .service
    }
}

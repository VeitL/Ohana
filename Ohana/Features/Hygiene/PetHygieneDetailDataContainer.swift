import SwiftData
import SwiftUI

struct PetHygieneLedgerEntry: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let type: HygieneType
    let legacyLogId: UUID?

    static func entries(from events: [CareLedgerEvent], petID: UUID) -> [PetHygieneLedgerEntry] {
        let petId = petID.uuidString
        return events.compactMap { event in
            guard event.eventKindEnum == .hygiene,
                  event.subjectKind == CareLedgerSubjectKind.pet.rawValue,
                  event.subjectId == petId,
                  let type = HygieneType(rawValue: event.actionType) else { return nil }
            let legacyLogId = event.legacyModelName == "PetHygieneLog"
                ? event.legacyModelId.flatMap(UUID.init(uuidString:))
                : nil
            return PetHygieneLedgerEntry(
                id: event.id,
                date: event.occurredAt,
                type: type,
                legacyLogId: legacyLogId
            )
        }
        .sorted { $0.date > $1.date }
    }
}

struct PetHygieneDetailView: View {
    let pet: Pet

    @Query(sort: \Reminder.scheduledAt, order: .forward) private var allReminders: [Reminder]
    @Query private var hygieneLedgerEvents: [CareLedgerEvent]
    @Query private var legacyDeleteLogs: [PetHygieneLog]

    init(pet: Pet) {
        self.pet = pet
        let petUUID = pet.id
        let petId = pet.id.uuidString
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let hygieneKind = CareLedgerEventKind.hygiene.rawValue
        _hygieneLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petId &&
                    event.eventKind == hygieneKind
            },
            sort: \.occurredAt,
            order: .reverse
        )
        _legacyDeleteLogs = Query(
            filter: #Predicate<PetHygieneLog> { log in
                log.pet?.id == petUUID
            },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        PetHygieneDetailContentView(
            pet: pet,
            allReminders: allReminders,
            hygieneEntries: PetHygieneLedgerEntry.entries(from: hygieneLedgerEvents, petID: pet.id),
            legacyDeleteLogs: legacyDeleteLogs
        )
    }
}

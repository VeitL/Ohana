import SwiftData
import SwiftUI

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
            hygieneLedgerEvents: hygieneLedgerEvents,
            legacyDeleteLogs: legacyDeleteLogs
        )
    }
}

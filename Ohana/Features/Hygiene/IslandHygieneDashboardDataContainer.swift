import SwiftData
import SwiftUI

struct HygieneDashboardLedgerEntry: Identifiable, Hashable {
    let id: UUID
    let petId: UUID
    let date: Date
    let eventKind: CareLedgerEventKind
    let actionType: String

    static func entries(from events: [CareLedgerEvent]) -> [HygieneDashboardLedgerEntry] {
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let hygieneCareTypes: Set<CareType> = [
            .litter,
            .waterChange,
            .filterClean,
            .cageCleaning,
            .misting,
            .substrateChange
        ]

        return events.compactMap { event in
            guard event.subjectKind == petSubject,
                  let subjectId = event.subjectId,
                  let petId = UUID(uuidString: subjectId) else { return nil }

            switch event.eventKindEnum {
            case .hygiene:
                guard HygieneType(rawValue: event.actionType) != nil else { return nil }
            case .care:
                guard let careType = CareType(rawValue: event.actionType),
                      hygieneCareTypes.contains(careType) else { return nil }
            default:
                return nil
            }

            return HygieneDashboardLedgerEntry(
                id: event.id,
                petId: petId,
                date: event.occurredAt,
                eventKind: event.eventKindEnum,
                actionType: event.actionType
            )
        }
        .sorted { $0.date > $1.date }
    }
}

struct IslandHygieneDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query private var careLedgerEvents: [CareLedgerEvent]

    init(standalone: Bool = true, onOpenPet: ((Pet) -> Void)? = nil) {
        self.standalone = standalone
        self.onOpenPet = onOpenPet
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let careKind = CareLedgerEventKind.care.rawValue
        let hygieneKind = CareLedgerEventKind.hygiene.rawValue
        _careLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    (event.eventKind == careKind || event.eventKind == hygieneKind)
            },
            sort: \.occurredAt,
            order: .reverse
        )
    }

    var body: some View {
        IslandHygieneDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets,
            hygieneLedgerEntries: HygieneDashboardLedgerEntry.entries(from: careLedgerEvents)
        )
    }
}

import SwiftData
import SwiftUI

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
            careLedgerEvents: careLedgerEvents
        )
    }
}

import SwiftData
import SwiftUI

struct IslandPottyDashboard: View {
    var standalone: Bool = true
    var onOpenPet: ((Pet) -> Void)?

    @Query(sort: \Pet.name) private var pets: [Pet]
    @Query private var pottyLedgerEvents: [CareLedgerEvent]

    init(standalone: Bool = true, onOpenPet: ((Pet) -> Void)? = nil) {
        self.standalone = standalone
        self.onOpenPet = onOpenPet
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let pottyKind = CareLedgerEventKind.potty.rawValue
        _pottyLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject && event.eventKind == pottyKind
            },
            sort: \.occurredAt,
            order: .reverse
        )
    }

    var body: some View {
        IslandPottyDashboardContentView(
            standalone: standalone,
            onOpenPet: onOpenPet,
            pets: pets,
            pottyLedgerEvents: pottyLedgerEvents
        )
    }
}

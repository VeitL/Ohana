//
//  PetWeightDashboardDataContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for pet weight history.
//

import SwiftData
import SwiftUI

struct PetWeightDashboardDataContainer: View {
    let pet: Pet
    var showsCloseButton: Bool
    var onClose: () -> Void
    var onAdd: () -> Void
    var onRemove: (() -> Void)?

    @Query private var weightLedgerEvents: [CareLedgerEvent] // smoothness: allow route-scoped pet-weight ledger snapshot after explicit weight history navigation.
    @Query private var legacyWeightDeleteLogs: [PetWeightLog] // smoothness: allow route-scoped legacy delete bridge for rows already represented by ledger events.

    init(
        pet: Pet,
        showsCloseButton: Bool,
        onClose: @escaping () -> Void,
        onAdd: @escaping () -> Void,
        onRemove: (() -> Void)?
    ) {
        self.pet = pet
        self.showsCloseButton = showsCloseButton
        self.onClose = onClose
        self.onAdd = onAdd
        self.onRemove = onRemove
        let petSubject = CareLedgerSubjectKind.pet.rawValue
        let petUUID = pet.id
        let petId = petUUID.uuidString
        let weightKind = CareLedgerEventKind.weight.rawValue
        let petWeightAction = "petWeight"
        _weightLedgerEvents = Query(
            filter: #Predicate<CareLedgerEvent> { event in
                event.subjectKind == petSubject &&
                    event.subjectId == petId &&
                    event.eventKind == weightKind &&
                    event.actionType == petWeightAction
            },
            sort: \.occurredAt,
            order: .reverse
        )
        _legacyWeightDeleteLogs = Query(
            filter: #Predicate<PetWeightLog> { log in
                log.pet?.id == petUUID
            },
            sort: \.date,
            order: .reverse
        )
    }

    var body: some View {
        PetWeightDashboardContent(
            pet: pet,
            showsCloseButton: showsCloseButton,
            weightLedgerEvents: weightLedgerEvents,
            legacyWeightDeleteLogs: legacyWeightDeleteLogs,
            onClose: onClose,
            onAdd: onAdd,
            onRemove: onRemove
        )
    }
}

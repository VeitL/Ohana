//
//  FocusHomeQuickRecordRouter.swift
//  Ohana
//
//  Routes inline quick-record popups launched from expanded quick actions.
//

import Combine
import Foundation

@MainActor
final class FocusHomeQuickRecordRouter: ObservableObject {
    @Published var petWeight: ExpandedQuickPetRecordRoute?
    @Published var petExpense: ExpandedQuickPetRecordRoute?
    @Published var humanWeight: ExpandedQuickHumanRecordRoute?
    @Published var humanWorkout: ExpandedQuickHumanRecordRoute?
    @Published var humanMedication: ExpandedQuickHumanRecordRoute?
    @Published var petMedication: ExpandedQuickPetRecordRoute?
    @Published var humanNote: ExpandedQuickHumanRecordRoute?
    @Published var humanExpense: ExpandedQuickHumanRecordRoute?

    var hasActiveOverlay: Bool {
        petWeight != nil
        || petExpense != nil
        || humanWeight != nil
        || humanWorkout != nil
        || humanMedication != nil
        || petMedication != nil
        || humanNote != nil
        || humanExpense != nil
    }

    func openPetWeight(_ pet: Pet) {
        petWeight = ExpandedQuickPetRecordRoute(pet: pet)
    }

    func openPetExpense(_ pet: Pet) {
        petExpense = ExpandedQuickPetRecordRoute(pet: pet)
    }

    func openHumanWeight(_ human: Human, actionType: String = "humanWeight") {
        humanWeight = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    func openHumanExpense(_ human: Human, actionType: String = "humanExpense") {
        humanExpense = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    func openHumanNote(_ human: Human, actionType: String = "humanNote") {
        humanNote = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    func openHumanWorkout(_ human: Human, actionType: String = "humanWorkout") {
        humanWorkout = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    func openHumanMedication(_ human: Human, actionType: String = "humanMedication") {
        humanMedication = ExpandedQuickHumanRecordRoute(human: human, actionType: actionType)
    }

    func openPetMedication(_ pet: Pet) {
        petMedication = ExpandedQuickPetRecordRoute(pet: pet)
    }

    func dismissPetWeight(routeID: UUID) {
        guard petWeight?.id == routeID else { return }
        petWeight = nil
    }

    func dismissPetExpense(routeID: UUID) {
        guard petExpense?.id == routeID else { return }
        petExpense = nil
    }

    func dismissHumanWeight(routeID: UUID) {
        guard humanWeight?.id == routeID else { return }
        humanWeight = nil
    }

    func dismissHumanExpense(routeID: UUID) {
        guard humanExpense?.id == routeID else { return }
        humanExpense = nil
    }

    func dismissHumanNote(routeID: UUID) {
        guard humanNote?.id == routeID else { return }
        humanNote = nil
    }

    func dismissHumanWorkout(routeID: UUID) {
        guard humanWorkout?.id == routeID else { return }
        humanWorkout = nil
    }

    func dismissHumanMedication(routeID: UUID) {
        guard humanMedication?.id == routeID else { return }
        humanMedication = nil
    }

    func dismissPetMedication(routeID: UUID) {
        guard petMedication?.id == routeID else { return }
        petMedication = nil
    }

    func resetHumanRoutes() {
        humanWeight = nil
        humanWorkout = nil
        humanMedication = nil
        humanNote = nil
        humanExpense = nil
    }
}

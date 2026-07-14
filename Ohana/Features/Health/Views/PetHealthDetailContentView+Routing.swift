//
//  PetHealthDetailContentView+Routing.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension PetHealthDetailContentView {
    var sheetHealthPlusDestination: Binding<HealthPlusDestination?> {
        Binding(
            get: { healthPlusDestination },
            set: { healthPlusDestination = $0 }
        )
    }

    func openInitialSectionIfNeeded() {
        guard !didOpenInitialSection, let initialSection else { return }
        didOpenInitialSection = true
        DispatchQueue.main.async {
            switch initialSection {
            case .preventive:
                activeHealthSheet = .preventiveOverview
            case .medication:
                activeHealthSheet = .medicationOverview
            case .symptomVisit:
                activeHealthSheet = .symptomVisitOverview
            }
        }
    }

    func healthRecordInitialType(for destination: HealthPlusDestination) -> HealthLogType {
        switch destination {
        case let .guided(mode):
            mode == .preventive ? .vaccine : .surgery
        case let .direct(type):
            type
        default:
            .general
        }
    }

    func healthRecordEntryMode(for destination: HealthPlusDestination) -> HealthRecordEntryMode? {
        if case let .guided(mode) = destination { return mode }
        return nil
    }
}

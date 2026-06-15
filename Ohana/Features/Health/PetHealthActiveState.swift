//
//  PetHealthActiveState.swift
//  Ohana
//
//  Shared Health read/write invariants for active records.
//

import Foundation

extension Pet {
    var canWriteHealthFacts: Bool {
        MemberLifecycleGate.disposition(pet: self, writeKind: .care).allowsCareFactWrite
    }

    var activeHealthLogs: [PetHealthLog] {
        healthLogs
    }

    var activeSymptomLogs: [SymptomLog] {
        symptomLogs
    }

    var activeHeatCycleLogs: [HeatCycleLog] {
        heatCycleLogs
    }
}

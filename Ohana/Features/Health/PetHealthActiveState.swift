//
//  PetHealthActiveState.swift
//  Ohana
//
//  Shared Health read/write invariants for active records.
//

import Foundation

extension Pet {
    var canWriteHealthFacts: Bool {
        trashedAt == nil && !hasPassedAway
    }

    var activeHealthLogs: [PetHealthLog] {
        healthLogs.activeRecycleBinItems
    }

    var activeSymptomLogs: [SymptomLog] {
        symptomLogs.activeRecycleBinItems
    }

    var activeHeatCycleLogs: [HeatCycleLog] {
        heatCycleLogs.activeRecycleBinItems
    }
}

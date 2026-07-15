//
//  PhysicalDeletionService+HumanAttribution.swift
//  Ohana
//
//  Scrubs retained local facts that refer to a Human being physically deleted.
//

import Foundation
import SwiftData

extension PhysicalDeletionService {
    nonisolated static func scrubHumanAttribution(
        for human: Human,
        in context: ModelContext,
        at deletedAt: Date,
        by deletedByHumanId: String?
    ) -> Int {
        let humanId = human.id.uuidString
        let allNotes = fetchAll(HumanNoteRecord.self, context: context)
        let subjectNotes = allNotes.filter { $0.humanId == human.id }
        subjectNotes.forEach(context.delete)
        let retainedNotes = allNotes.filter {
            $0.humanId != human.id && idsMatch($0.recordedByHumanId, humanId)
        }
        retainedNotes.forEach { $0.recordedByHumanId = nil }

        let humanExpenses = fetchAll(PetExpenseLog.self, context: context).filter {
            $0.pet == nil && idsMatch($0.executorId, humanId)
        }
        let deletedExpenseCount = deleteRows(humanExpenses, context: context) {
            CloudSyncMutationRecorder.markDeleted(
                $0,
                pet: $0.pet,
                context: context,
                deletedAt: deletedAt,
                deletedByHumanId: deletedByHumanId
            )
        }

        let retainedExpenses = fetchAll(PetExpenseLog.self, context: context).filter {
            $0.pet == nil && !idsMatch($0.executorId, humanId) && idsMatch($0.recordedByHumanId, humanId)
        }
        retainedExpenses.forEach { $0.recordedByHumanId = nil }
        for retainedExpens in retainedExpenses {
            CloudSyncMutationRecorder.markModified(retainedExpens, context: context, modifiedAt: deletedAt)
        }

        let retainedHealthMetrics = fetchAll(HumanHealthMetricLog.self, context: context).filter {
            $0.human?.id != human.id && idsMatch($0.recordedByHumanId, humanId)
        }
        retainedHealthMetrics.forEach { $0.recordedByHumanId = nil }
        for retainedHealthMetric in retainedHealthMetrics {
            CloudSyncMutationRecorder.markModified(retainedHealthMetric, context: context, modifiedAt: deletedAt)
        }

        let retainedHealthReports = fetchAll(HumanHealthReport.self, context: context).filter {
            !idsMatch($0.humanId, humanId) && idsMatch($0.recordedByHumanId, humanId)
        }
        retainedHealthReports.forEach { $0.recordedByHumanId = nil }
        for retainedHealthReport in retainedHealthReports {
            CloudSyncMutationRecorder.markModified(retainedHealthReport, context: context, modifiedAt: deletedAt)
        }

        let retainedSymptoms = fetchAll(SymptomLog.self, context: context).filter {
            idsMatch($0.recordedByHumanId, humanId)
        }
        retainedSymptoms.forEach { $0.recordedByHumanId = nil }
        for retainedSymptom in retainedSymptoms {
            CloudSyncMutationRecorder.markModified(retainedSymptom, context: context, modifiedAt: deletedAt)
        }

        let retainedHeatCycles = fetchAll(HeatCycleLog.self, context: context).filter {
            idsMatch($0.recordedByHumanId, humanId)
        }
        retainedHeatCycles.forEach { $0.recordedByHumanId = nil }
        for retainedHeatCycle in retainedHeatCycles {
            CloudSyncMutationRecorder.markModified(retainedHeatCycle, context: context, modifiedAt: deletedAt)
        }

        return subjectNotes.count + retainedNotes.count + deletedExpenseCount + retainedExpenses.count
            + retainedHealthMetrics.count + retainedHealthReports.count
            + retainedSymptoms.count + retainedHeatCycles.count
    }
}

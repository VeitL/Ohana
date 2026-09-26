//
//  DataBackupPreflightValidator.swift
//  Ohana
//
//  Strict, read-only validation for backup input before the live ModelContext
//  receives any restore mutations.
//

import Foundation
import SwiftData

nonisolated enum DataBackupRestoreLimits {
    static let maximumManifestBytes = 32 * 1024 * 1024
    static let maximumRecordCount = 100_000
    static let maximumMediaItemBytes = 64 * 1024 * 1024
    static let maximumMediaBytes = 512 * 1024 * 1024
    static let maximumEncryptionOverheadBytes = 1024 * 1024
    static let maximumEncryptedManifestBytes = ((maximumManifestBytes + 2) / 3) * 4 + maximumEncryptionOverheadBytes
    static let maximumEncryptedMediaItemBytes = ((maximumMediaItemBytes + 2) / 3) * 4 + maximumEncryptionOverheadBytes
}

nonisolated struct DataBackupRestoreExistingIdentities: Sendable {
    let pets: Set<UUID>
    let humans: Set<UUID>
    let plants: Set<UUID>
    let documents: Set<UUID>
    let humanMedications: Set<UUID>
    let humanHealthReportOwners: [UUID: UUID]

    @MainActor
    init(context: ModelContext) throws {
        pets = try Set(context.fetch(FetchDescriptor<Pet>()).map(\.id))
        humans = try Set(context.fetch(FetchDescriptor<Human>()).map(\.id))
        plants = try Set(context.fetch(FetchDescriptor<Plant>()).map(\.id))
        documents = try Set(context.fetch(FetchDescriptor<PetDocument>()).map(\.id))
        humanMedications = try Set(context.fetch(FetchDescriptor<HumanMedication>()).map(\.id))
        var reportOwners: [UUID: UUID] = [:]
        for report in try context.fetch(FetchDescriptor<HumanHealthReport>()) {
            guard let humanID = UUID(uuidString: report.humanId) else { continue }
            reportOwners[report.id] = humanID
        }
        humanHealthReportOwners = reportOwners
    }
}

nonisolated enum DataBackupPreflightValidator {
    @MainActor
    static func validate(
        _ backup: OhanaBackup,
        existing: DataBackupRestoreExistingIdentities
    ) throws {
        guard backup.schemaVersion >= 1, backup.schemaVersion <= 34 else {
            throw BackupError.unsupportedVersion(backup.schemaVersion)
        }

        var counters = ValidationCounters()
        let dateParser = ISO8601DateFormatter()
        try validateValue(
            backup,
            fieldName: nil,
            isOptional: false,
            dateParser: dateParser,
            counters: &counters
        )
        try validateTopLevelIdentities(backup, counters: &counters)
        try validateBusinessValues(backup)

        guard counters.recordCount <= DataBackupRestoreLimits.maximumRecordCount,
              counters.mediaBytes <= DataBackupRestoreLimits.maximumMediaBytes else {
            throw BackupError.invalidRestoreData(.sizeLimit)
        }

        try validateRequiredRelationships(backup, existing: existing)
    }

    static func validateManifestSize(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size >= 0,
              size <= DataBackupRestoreLimits.maximumEncryptedManifestBytes else {
            throw BackupError.invalidRestoreData(.sizeLimit)
        }
    }

    // MARK: - Structural validation

    private struct ValidationCounters {
        var recordCount = 0
        var mediaBytes = 0
    }

    private static func validateValue(
        _ value: Any,
        fieldName: String?,
        isOptional: Bool,
        dateParser: ISO8601DateFormatter,
        counters: inout ValidationCounters
    ) throws {
        let unwrapped = unwrap(value)
        guard let actualValue = unwrapped.value else { return }

        if let string = actualValue as? String {
            if fieldName == "id" {
                guard UUID(uuidString: string) != nil else {
                    throw BackupError.invalidRestoreData(.identity)
                }
            }
            if let fieldName, isDateField(fieldName) {
                if string.isEmpty, isOptional || unwrapped.wasOptional {
                    return
                }
                guard dateParser.date(from: string) != nil else {
                    throw BackupError.invalidRestoreData(.date)
                }
            }
            return
        }

        if let reference = actualValue as? BackupMediaReference {
            guard reference.byteCount > 0,
                  reference.byteCount <= DataBackupRestoreLimits.maximumMediaItemBytes,
                  isManagedMediaPath(reference.path) else {
                throw BackupError.invalidRestoreData(.media)
            }
            let (total, overflow) = counters.mediaBytes.addingReportingOverflow(reference.byteCount)
            guard !overflow else {
                throw BackupError.invalidRestoreData(.sizeLimit)
            }
            counters.mediaBytes = total
            return
        }

        let mirror = Mirror(reflecting: actualValue)
        switch mirror.displayStyle {
        case .collection, .set:
            for child in mirror.children {
                try validateValue(
                    child.value,
                    fieldName: fieldName,
                    isOptional: isOptional || unwrapped.wasOptional,
                    dateParser: dateParser,
                    counters: &counters
                )
            }
        case .dictionary:
            return
        case .class, .struct, .tuple:
            for child in mirror.children {
                try validateValue(
                    child.value,
                    fieldName: child.label,
                    isOptional: Mirror(reflecting: child.value).displayStyle == .optional,
                    dateParser: dateParser,
                    counters: &counters
                )
            }
        case .enum, .optional, .none:
            for child in mirror.children {
                try validateValue(
                    child.value,
                    fieldName: fieldName,
                    isOptional: isOptional || unwrapped.wasOptional,
                    dateParser: dateParser,
                    counters: &counters
                )
            }
        default:
            return
        }
    }

    private static func validateTopLevelIdentities(
        _ backup: OhanaBackup,
        counters: inout ValidationCounters
    ) throws {
        for child in Mirror(reflecting: backup).children {
            guard let records = collectionElements(child.value), !records.isEmpty else { continue }
            let ids = records.compactMap(primaryIdentity)
            guard !ids.isEmpty else { continue }

            counters.recordCount += records.count
            guard ids.count == records.count,
                  Set(ids).count == ids.count else {
                throw BackupError.invalidRestoreData(.duplicateIdentity)
            }
        }
    }

    private static func collectionElements(_ value: Any) -> [Any]? {
        guard let value = unwrap(value).value else { return nil }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .collection || mirror.displayStyle == .set else { return nil }
        return mirror.children.map(\.value)
    }

    private static func primaryIdentity(_ value: Any) -> UUID? {
        let mirror = Mirror(reflecting: value)
        guard let raw = mirror.children.first(where: { $0.label == "id" })?.value as? String else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    private static func unwrap(_ value: Any) -> (value: Any?, wasOptional: Bool) {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return (value, false) }
        return (mirror.children.first?.value, true)
    }

    private static func isDateField(_ name: String) -> Bool {
        name == "date" ||
            name == "birthday" ||
            name.hasSuffix("Date") ||
            name.hasSuffix("At") ||
            name.hasSuffix("Time")
    }

    private static func isManagedMediaPath(_ path: String) -> Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.count == 2 &&
            components[0] == Substring(DataBackupPackageFormat.mediaDirectoryName) &&
            !components[1].isEmpty &&
            components[1] != "." &&
            components[1] != ".."
    }

    // MARK: - Business value validation

    @MainActor
    private static func validateBusinessValues(_ backup: OhanaBackup) throws {
        for expense in backup.petExpenseLogs {
            guard ExpenseAmountPolicy.isValidPersistedExpense(
                amount: expense.amount,
                categoryRaw: expense.category,
                note: expense.note
            ),
            (try? ExpensePayerContributionPolicy.validatedDecoded(
                expense.payerContributionsJSON ?? "",
                total: expense.amount
            )) != nil else {
                throw BackupError.invalidRestoreData(.businessValue)
            }
        }

        for session in backup.sharedCareSessions ?? [] {
            guard session.actionKindRaw == SharedCareActionKind.expense.rawValue else { continue }
            guard let amount = session.totalExpenseAmount,
                  ExpenseAmountPolicy.isValidUserExpense(amount) else {
                throw BackupError.invalidRestoreData(.businessValue)
            }
        }

        for metric in backup.humanHealthMetricLogs ?? [] {
            guard HumanHealthMetricImportValidationPolicy.isValid(
                metricKey: metric.metricKey,
                unitCode: metric.unitCode,
                value: metric.value,
                referenceLow: metric.referenceLow,
                referenceHigh: metric.referenceHigh,
                sourceLabel: metric.sourceLabel ?? "",
                referenceRangeText: metric.referenceRangeText ?? ""
            ),
                  metric.reportedFlagRaw.map({ ["low", "normal", "high", "unknown"].contains($0) }) != false else {
                throw BackupError.invalidRestoreData(.businessValue)
            }
        }

        for report in backup.humanHealthReports ?? [] {
            guard report.captureSourceRaw.map({ ["manual", "documentScan"].contains($0) }) != false else {
                throw BackupError.invalidRestoreData(.businessValue)
            }
        }
    }

    // MARK: - Required relationship validation

    private static func validateRequiredRelationships(
        _ backup: OhanaBackup,
        existing: DataBackupRestoreExistingIdentities
    ) throws {
        let petIDs = existing.pets.union(backup.pets.compactMap { UUID(uuidString: $0.id) })
        let humanIDs = existing.humans.union(backup.humans.compactMap { UUID(uuidString: $0.id) })
        let plantIDs = existing.plants.union(backup.plants.compactMap { UUID(uuidString: $0.id) })
        let documentIDs = existing.documents.union(backup.petDocuments.compactMap { UUID(uuidString: $0.id) })
        let medicationIDs = existing.humanMedications.union(
            (backup.humanMedications ?? []).compactMap { UUID(uuidString: $0.id) }
        )
        var healthReportOwners = existing.humanHealthReportOwners

        for relationship in backup.petRelationships ?? [] {
            try requireReference(relationship.fromPetId, in: petIDs)
            try requireReference(relationship.toPetId, in: petIDs)
        }
        for attachment in backup.petDocumentAttachments ?? [] {
            try requireReference(attachment.documentId, in: documentIDs)
        }
        for medication in backup.humanMedications ?? [] {
            try requireReference(medication.humanId, in: humanIDs)
        }
        for log in backup.humanMedicationLogs ?? [] {
            try requireReference(log.humanId, in: humanIDs)
            try requireReference(log.medicationId, in: medicationIDs)
        }
        for report in backup.humanHealthReports ?? [] {
            try requireReference(report.humanId, in: humanIDs)
            guard let reportID = UUID(uuidString: report.id),
                  let humanID = UUID(uuidString: report.humanId),
                  healthReportOwners[reportID] == nil || healthReportOwners[reportID] == humanID else {
                throw BackupError.invalidRestoreData(.relationship)
            }
            healthReportOwners[reportID] = humanID
            if let recorder = report.recordedByHumanId {
                try requireReference(recorder, in: humanIDs)
            }
        }
        for metric in backup.humanHealthMetricLogs ?? [] {
            if let humanID = metric.humanId {
                try requireReference(humanID, in: humanIDs)
            }
            if let recorder = metric.recordedByHumanId {
                try requireReference(recorder, in: humanIDs)
            }
            if let sourceReportID = metric.sourceReportID {
                guard let reportID = UUID(uuidString: sourceReportID),
                      let humanID = metric.humanId.flatMap(UUID.init(uuidString:)),
                      healthReportOwners[reportID] == humanID else {
                    throw BackupError.invalidRestoreData(.relationship)
                }
            }
        }
        for record in backup.humanNoteRecords ?? [] {
            try requireReference(record.humanId, in: humanIDs)
            if let recorder = record.recordedByHumanId {
                try requireReference(recorder, in: humanIDs)
            }
        }
        try validateExpensePayerReferences(backup.petExpenseLogs, humanIDs: humanIDs)
        for symptom in backup.symptomLogs ?? [] {
            if let recorder = symptom.recordedByHumanId {
                try requireReference(recorder, in: humanIDs)
            }
        }
        for heatCycle in backup.heatCycleLogs ?? [] {
            if let recorder = heatCycle.recordedByHumanId {
                try requireReference(recorder, in: humanIDs)
            }
        }
        for override in backup.appState.plantReminderPreferences?.plantCareOverrides ?? [] {
            try requireReference(override.plantID, in: plantIDs)
        }
        for session in backup.sharedCareSessions ?? [] {
            try requireReference(session.sourcePetId, in: petIDs)
            for targetID in session.targetPetIdsRaw.split(separator: "|").map(String.init) {
                try requireReference(targetID, in: petIDs)
            }
            if !session.stockOwnerPetId.isEmpty {
                try requireReference(session.stockOwnerPetId, in: petIDs)
            }
        }
    }

    private static func validateExpensePayerReferences(
        _ expenses: [PetExpenseLogBackup],
        humanIDs: Set<UUID>
    ) throws {
        for expense in expenses {
            if let recorder = expense.recordedByHumanId {
                try requireReference(recorder, in: humanIDs)
            }
            for contribution in ExpensePayerContributionPolicy.decode(
                expense.payerContributionsJSON ?? ""
            ) ?? [] {
                if let humanID = contribution.humanID {
                    try requireReference(humanID.uuidString, in: humanIDs)
                }
            }
        }
    }

    private static func requireReference(_ raw: String, in identities: Set<UUID>) throws {
        guard let id = UUID(uuidString: raw), identities.contains(id) else {
            throw BackupError.invalidRestoreData(.relationship)
        }
    }
}

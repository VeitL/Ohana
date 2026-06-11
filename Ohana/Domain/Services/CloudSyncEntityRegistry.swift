//
//  CloudSyncEntityRegistry.swift
//  Ohana
//
//  Central model sync decisions for the future CKSyncEngine pipeline.
//

import Foundation

nonisolated enum CloudSyncEntityRole: String, Codable, CaseIterable {
    case mutableRecord
    case appendOnlyFact
    case ledgerEntry
    case derivedProjection
    case localSyncMetadata
}

nonisolated struct CloudSyncEntityDescriptor: Equatable {
    let entityName: String
    let recordType: String
    let role: CloudSyncEntityRole
    let uploadsToCloudKit: Bool
    let defaultConflictPolicy: CloudSyncConflictPolicy
    let excludedFieldNames: Set<String>
    let fieldPolicies: [String: CloudSyncConflictPolicy]

    func conflictPolicy(for fieldName: String) -> CloudSyncConflictPolicy {
        let normalized = fieldName.trimmingCharacters(in: .whitespacesAndNewlines)
        return fieldPolicies[normalized] ?? defaultConflictPolicy
    }

    func shouldUploadField(_ fieldName: String) -> Bool {
        let normalized = fieldName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !excludedFieldNames.contains(normalized) else { return false }
        return conflictPolicy(for: normalized) != .ledgerProjection
    }
}

nonisolated enum CloudSyncEntityRegistry {
    static let descriptors: [CloudSyncEntityDescriptor] = [
        mutable(Pet.self, excluded: ["ckRecordName"], fieldPolicies: ["coconutBalance": .ledgerProjection]),
        mutable(
            Human.self,
            excluded: ["appleUserIdentifier", "pinHash", "pinSalt", "pinFailedAttempts", "pinLockedUntil"],
            fieldPolicies: ["coconutBalance": .ledgerProjection]
        ),
        mutable(Plant.self),
        mutable(Household.self, excluded: ["ckShareRecordName"], fieldPolicies: ["totalProsperity": .maxValue]),
        mutable(Event.self),
        mutable(Reminder.self, excluded: ["notificationId"]),
        mutable(PetRelationship.self),
        mutable(WishlistItem.self),
        mutable(PetDocument.self),
        mutable(PetDocumentAttachment.self),
        mutable(PetMedication.self),
        mutable(PetInsurance.self),
        mutable(InsuranceClaim.self),
        mutable(HumanMedication.self),
        mutable(HumanHealthReport.self),
        mutable(FamilyCollaborationTask.self),
        mutable(CoconutExchangeRequest.self),
        mutable(OasisUpgradeCoconut.self),
        mutable(OasisElectronicPet.self),
        mutable(OasisCritterFragmentBalance.self, fieldPolicies: ["amount": .maxValue]),
        mutable(OasisUnlock.self),
        mutable(GachaOwnedItem.self, fieldPolicies: ["ownedCount": .maxValue]),

        appendOnly(WaterLog.self),
        appendOnly(PetCareLog.self),
        appendOnly(PetPottyLog.self),
        appendOnly(PetWalkLog.self),
        appendOnly(PetHygieneLog.self),
        appendOnly(PetWeightLog.self),
        appendOnly(PetHealthLog.self),
        appendOnly(PetExpenseLog.self),
        appendOnly(PetFoodRecord.self),
        appendOnly(PetMilestone.self),
        appendOnly(PetPhotoLog.self),
        appendOnly(PlantCareLog.self),
        appendOnly(SymptomLog.self),
        appendOnly(HeatCycleLog.self),
        appendOnly(HumanWeightLog.self),
        appendOnly(HumanWorkoutLog.self),
        appendOnly(HumanMedicationLog.self),
        appendOnly(HumanHealthMetricLog.self),
        appendOnly(SharedCareSession.self),
        appendOnly(CareLedgerEvent.self),
        appendOnly(CoconutLedgerEntry.self, role: .ledgerEntry),
        appendOnly(EconomyBudgetUsageEvent.self),
        appendOnly(OasisCritterActionLog.self),
        appendOnly(GachaDrawLog.self),

        derived(CoconutAccount.self, fieldPolicies: ["balance": .ledgerProjection]),
        localMetadata(CloudSyncRecordState.self)
    ]

    static var uploadableDescriptors: [CloudSyncEntityDescriptor] {
        descriptors.filter { $0.uploadsToCloudKit && supportsUploadPipeline(for: $0.entityName) }
    }

    static let uploadPipelineEntityNames: Set<String> = [
        String(describing: Household.self),
        String(describing: Pet.self),
        String(describing: Human.self),
        String(describing: PetCareLog.self),
        String(describing: PetPottyLog.self),
        String(describing: PetHygieneLog.self),
        String(describing: PetHealthLog.self),
        String(describing: PetWalkLog.self),
        String(describing: PetExpenseLog.self),
        String(describing: PetWeightLog.self),
        String(describing: CoconutLedgerEntry.self)
    ]

    static func supportsUploadPipeline(for entityName: String) -> Bool {
        uploadPipelineEntityNames.contains(CloudSyncRecordState.normalizedEntityName(entityName))
    }

    static func descriptor(for entityName: String) -> CloudSyncEntityDescriptor? {
        descriptorsByEntityName[CloudSyncRecordState.normalizedEntityName(entityName)]
    }

    static func descriptor<T>(for _: T.Type) -> CloudSyncEntityDescriptor? {
        descriptor(for: String(describing: T.self))
    }

    static func defaultConflictPolicy(for entityName: String) -> CloudSyncConflictPolicy {
        descriptor(for: entityName)?.defaultConflictPolicy ?? .lastWriterWins
    }

    static func conflictPolicy(entityName: String, fieldName: String) -> CloudSyncConflictPolicy {
        descriptor(for: entityName)?.conflictPolicy(for: fieldName) ?? defaultConflictPolicy(for: entityName)
    }

    private static let descriptorsByEntityName: [String: CloudSyncEntityDescriptor] = Dictionary(
        uniqueKeysWithValues: descriptors.map { ($0.entityName, $0) }
    )

    private static func mutable<T>(
        _: T.Type,
        excluded: Set<String> = [],
        fieldPolicies: [String: CloudSyncConflictPolicy] = [:]
    ) -> CloudSyncEntityDescriptor {
        descriptor(
            T.self,
            role: .mutableRecord,
            uploadsToCloudKit: true,
            defaultConflictPolicy: .lastWriterWins,
            excluded: excluded,
            fieldPolicies: fieldPolicies
        )
    }

    private static func appendOnly<T>(
        _: T.Type,
        role: CloudSyncEntityRole = .appendOnlyFact,
        excluded: Set<String> = [],
        fieldPolicies: [String: CloudSyncConflictPolicy] = [:]
    ) -> CloudSyncEntityDescriptor {
        descriptor(
            T.self,
            role: role,
            uploadsToCloudKit: true,
            defaultConflictPolicy: .appendOnly,
            excluded: excluded,
            fieldPolicies: fieldPolicies
        )
    }

    private static func derived<T>(
        _: T.Type,
        fieldPolicies: [String: CloudSyncConflictPolicy] = [:]
    ) -> CloudSyncEntityDescriptor {
        descriptor(
            T.self,
            role: .derivedProjection,
            uploadsToCloudKit: false,
            defaultConflictPolicy: .ledgerProjection,
            excluded: [],
            fieldPolicies: fieldPolicies
        )
    }

    private static func localMetadata<T>(_: T.Type) -> CloudSyncEntityDescriptor {
        descriptor(
            T.self,
            role: .localSyncMetadata,
            uploadsToCloudKit: false,
            defaultConflictPolicy: .lastWriterWins,
            excluded: [],
            fieldPolicies: [:]
        )
    }

    private static func descriptor<T>(
        _: T.Type,
        role: CloudSyncEntityRole,
        uploadsToCloudKit: Bool,
        defaultConflictPolicy: CloudSyncConflictPolicy,
        excluded: Set<String>,
        fieldPolicies: [String: CloudSyncConflictPolicy]
    ) -> CloudSyncEntityDescriptor {
        let entityName = CloudSyncRecordState.normalizedEntityName(String(describing: T.self))
        return CloudSyncEntityDescriptor(
            entityName: entityName,
            recordType: entityName,
            role: role,
            uploadsToCloudKit: uploadsToCloudKit,
            defaultConflictPolicy: defaultConflictPolicy,
            excludedFieldNames: excluded,
            fieldPolicies: fieldPolicies
        )
    }
}

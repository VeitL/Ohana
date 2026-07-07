//
//  DomainMemberContentRehydrateWriteKernel.swift
//  Ohana
//
//  Central rehydrate writer for member content restored from backup records.
//

import Foundation
import SwiftData

nonisolated struct DomainPetDocumentRehydrateSnapshot: Equatable {
    let id: UUID
    let title: String
    let categoryRaw: String
    let expiryDate: Date?
    let petId: UUID?
    let issueDate: Date?
    let issuingAuthority: String
    let notes: String
    let reminderDate: Date?
    let cost: Double
    let attachmentData: Data?
    let attachmentFilename: String
}

nonisolated struct DomainPetDocumentAttachmentRehydrateSnapshot: Equatable {
    let id: UUID
    let documentId: UUID?
    let data: Data?
    let filename: String
    let isImage: Bool
}

nonisolated struct DomainPetPhotoLogRehydrateSnapshot: Equatable {
    let id: UUID
    let imageData: Data
    let date: Date
    let note: String
    let createdAt: Date
    let petId: UUID?
    let locationLatitude: Double
    let locationLongitude: Double
    let locationPlacename: String
}

nonisolated struct DomainPetInsuranceRehydrateSnapshot: Equatable {
    let id: UUID
    let companyName: String
    let policyNumber: String
    let productName: String
    let annualPremium: Double
    let coverageAmount: Double
    let startDate: Date
    let renewalDate: Date
    let notes: String
    let isActive: Bool
    let createdAt: Date
    let paymentFrequencyRaw: String
    let paymentDayOfMonth: Int
    let showInCalendar: Bool
    let otherFeeAmount: Double
    let otherFeeNote: String
    let firstPremiumPaymentDate: Date?
    let petId: UUID?
}

nonisolated struct DomainInsuranceClaimRehydrateSnapshot: Equatable {
    let id: UUID
    let insuranceId: UUID?
    let claimDate: Date
    let incidentDate: Date
    let totalExpense: Double
    let claimedAmount: Double
    let approvedAmount: Double
    let statusRaw: String
    let note: String
    let relatedExpenseLogId: String?
    let approvedAt: Date?
    let createdAt: Date
}

nonisolated struct DomainPetMedicationRehydrateSnapshot: Equatable {
    let id: UUID
    let name: String
    let dosage: String
    let frequencyRaw: String
    let customFrequencyNote: String
    let startDate: Date
    let endDate: Date?
    let colorHex: String
    let notes: String
    let isActive: Bool
    let remainingAmount: Double
    let createdAt: Date
    let petId: UUID?
}

nonisolated struct DomainHumanMedicationRehydrateSnapshot: Equatable {
    let id: UUID
    let humanId: String
    let name: String
    let dosage: String
    let frequencyRaw: String
    let customFrequencyNote: String
    let firstDoseTime: Date
    let startDate: Date
    let endDate: Date?
    let colorHex: String
    let notes: String
    let isActive: Bool
    let createdAt: Date
}

nonisolated struct DomainHumanMedicationLogRehydrateSnapshot: Equatable {
    let id: UUID
    let humanId: String
    let medicationId: String
    let scheduledTime: Date
    let statusRaw: String
    let recordedTime: Date?
    let createdAt: Date
}

nonisolated struct DomainHumanHealthMetricLogRehydrateSnapshot: Equatable {
    let id: UUID
    let metricKey: String
    let unitCode: String
    let value: Double
    let date: Date
    let notes: String
    let humanId: UUID?
    let createdAt: Date
}

nonisolated struct DomainHumanHealthReportRehydrateSnapshot: Equatable {
    let id: UUID
    let humanId: String
    let reportTypeRaw: String
    let conclusionRaw: String
    let hospitalName: String
    let doctorName: String
    let reportDate: Date
    let nextCheckDate: Date?
    let summary: String
    let notes: String
    let colorHex: String
    let createdAt: Date
}

nonisolated struct DomainPetMilestoneRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let title: String
    let emoji: String
    let notes: String
    let petId: UUID?
    let photoData: Data?
    let location: String
}

nonisolated struct DomainHumanWeightLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let humanId: UUID?
    let executorId: String?
}

nonisolated struct DomainHumanWorkoutLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let typeRaw: String
    let durationMinutes: Int
    let distanceKm: Double
    let calories: Int
    let steps: Int
    let notes: String
    let sourceHealthKit: Bool
    let healthKitWorkoutUUID: String
    let healthKitSourceBundleID: String
    let healthKitSourceName: String
    let sourcePetWalkLogID: String
    let humanId: UUID?
}

nonisolated struct DomainSymptomLogRehydrateSnapshot: Equatable {
    let id: UUID
    let date: Date
    let categoryRaw: String
    let symptomName: String
    let severityRaw: Int
    let note: String
    let photoData: Data?
    let petId: UUID?
}

nonisolated struct DomainHeatCycleLogRehydrateSnapshot: Equatable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let statusRaw: String
    let note: String
    let isMated: Bool
    let expectedDeliveryDate: Date?
    let petId: UUID?
}

nonisolated struct DomainMemberContentRehydrateResult {
    let inserted: Bool
    let plan: AuthorizedDomainRehydratePlan

    var didPersist: Bool {
        plan.disposition.allowsPersistence
    }
}

nonisolated enum DomainMemberContentRehydrateWriter {
    @discardableResult
    static func insertPetDocumentIfNeeded(
        snapshot: DomainPetDocumentRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetDocument(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let document = PetDocument(
            title: snapshot.title,
            category: DocumentCategory(rawValue: snapshot.categoryRaw) ?? .other,
            pet: try petReference(id: snapshot.petId, context: context)
        )
        document.id = snapshot.id
        document.expiryDate = snapshot.expiryDate
        document.issueDate = snapshot.issueDate
        document.issuingAuthority = snapshot.issuingAuthority
        document.notes = snapshot.notes
        document.reminderDate = snapshot.reminderDate
        document.cost = snapshot.cost
        document.updateLegacyAttachment(data: snapshot.attachmentData, filename: snapshot.attachmentFilename)
        context.insert(document)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetDocumentAttachmentIfNeeded(
        snapshot: DomainPetDocumentAttachmentRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let document = try snapshot.documentId.flatMap { try fetchPetDocument(id: $0, context: context) }
        let plan = authorizePet(petId: document?.pet?.id, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetDocumentAttachment(id: snapshot.id, context: context) == nil,
              let data = snapshot.data else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let attachment = PetDocumentAttachment(data: data, filename: snapshot.filename, isImage: snapshot.isImage)
        attachment.id = snapshot.id
        document?.attachments.append(attachment)
        context.insert(attachment)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetPhotoLogIfNeeded(
        snapshot: DomainPetPhotoLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetPhotoLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let log = PetPhotoLog(
            imageData: snapshot.imageData,
            date: snapshot.date,
            note: snapshot.note,
            pet: try petReference(id: snapshot.petId, context: context),
            locationLatitude: snapshot.locationLatitude,
            locationLongitude: snapshot.locationLongitude,
            locationPlacename: snapshot.locationPlacename
        )
        log.id = snapshot.id
        log.createdAt = snapshot.createdAt
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetInsuranceIfNeeded(
        snapshot: DomainPetInsuranceRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetInsurance(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let insurance = PetInsurance(
            companyName: snapshot.companyName,
            policyNumber: snapshot.policyNumber,
            productName: snapshot.productName,
            annualPremium: snapshot.annualPremium,
            coverageAmount: snapshot.coverageAmount,
            startDate: snapshot.startDate,
            renewalDate: snapshot.renewalDate,
            notes: snapshot.notes,
            paymentFrequency: InsurancePaymentFrequency(rawValue: snapshot.paymentFrequencyRaw) ?? .annual,
            paymentDayOfMonth: snapshot.paymentDayOfMonth,
            showInCalendar: snapshot.showInCalendar,
            otherFeeAmount: snapshot.otherFeeAmount,
            otherFeeNote: snapshot.otherFeeNote,
            firstPremiumPaymentDate: snapshot.firstPremiumPaymentDate,
            pet: try petReference(id: snapshot.petId, context: context)
        )
        insurance.id = snapshot.id
        insurance.isActive = snapshot.isActive
        insurance.createdAt = snapshot.createdAt
        context.insert(insurance)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertInsuranceClaimIfNeeded(
        snapshot: DomainInsuranceClaimRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let insurance = try snapshot.insuranceId.flatMap { try fetchPetInsurance(id: $0, context: context) }
        let plan = authorizePet(petId: insurance?.pet?.id, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchInsuranceClaim(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let claim = InsuranceClaim(
            claimDate: snapshot.claimDate,
            incidentDate: snapshot.incidentDate,
            totalExpense: snapshot.totalExpense,
            claimedAmount: snapshot.claimedAmount,
            approvedAmount: snapshot.approvedAmount,
            status: ClaimStatus(rawValue: snapshot.statusRaw) ?? .submitted,
            note: snapshot.note,
            relatedExpenseLogId: snapshot.relatedExpenseLogId,
            insurance: insurance
        )
        claim.id = snapshot.id
        claim.approvedAt = snapshot.approvedAt
        claim.createdAt = snapshot.createdAt
        context.insert(claim)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetMedicationIfNeeded(
        snapshot: DomainPetMedicationRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetMedication(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let medication = PetMedication(
            name: snapshot.name,
            dosage: snapshot.dosage,
            frequency: PetMedicationFrequency(rawValue: snapshot.frequencyRaw) ?? .daily,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            colorHex: snapshot.colorHex,
            notes: snapshot.notes,
            remainingAmount: snapshot.remainingAmount,
            pet: try petReference(id: snapshot.petId, context: context)
        )
        medication.id = snapshot.id
        medication.customFrequencyNote = snapshot.customFrequencyNote
        medication.isActive = snapshot.isActive
        medication.createdAt = snapshot.createdAt
        context.insert(medication)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHumanMedicationIfNeeded(
        snapshot: DomainHumanMedicationRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizeHuman(humanId: snapshot.humanId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHumanMedication(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let medication = HumanMedication(
            humanId: snapshot.humanId,
            name: snapshot.name,
            dosage: snapshot.dosage,
            frequency: MedicationFrequency(rawValue: snapshot.frequencyRaw) ?? .daily,
            firstDoseTime: snapshot.firstDoseTime,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            colorHex: snapshot.colorHex,
            notes: snapshot.notes
        )
        medication.id = snapshot.id
        medication.customFrequencyNote = snapshot.customFrequencyNote
        medication.isActive = snapshot.isActive
        medication.createdAt = snapshot.createdAt
        context.insert(medication)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHumanMedicationLogIfNeeded(
        snapshot: DomainHumanMedicationLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizeHuman(humanId: snapshot.humanId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHumanMedicationLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let log = HumanMedicationLog(
            humanId: snapshot.humanId,
            medicationId: snapshot.medicationId,
            scheduledTime: snapshot.scheduledTime,
            status: HumanMedicationStatus(rawValue: snapshot.statusRaw) ?? .pending,
            recordedTime: snapshot.recordedTime
        )
        log.id = snapshot.id
        log.createdAt = snapshot.createdAt
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHumanHealthMetricLogIfNeeded(
        snapshot: DomainHumanHealthMetricLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizeHuman(humanId: snapshot.humanId?.uuidString, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHumanHealthMetricLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let human = try humanReference(id: snapshot.humanId, context: context)
        let log = HumanHealthMetricLog(
            metricKey: snapshot.metricKey,
            unitCode: snapshot.unitCode,
            value: snapshot.value,
            date: snapshot.date,
            notes: snapshot.notes,
            human: human
        )
        log.id = snapshot.id
        log.createdAt = snapshot.createdAt
        human?.healthMetricLogs.append(log)
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHumanHealthReportIfNeeded(
        snapshot: DomainHumanHealthReportRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizeHuman(humanId: snapshot.humanId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHumanHealthReport(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let report = HumanHealthReport(
            humanId: snapshot.humanId,
            reportType: HealthReportType(rawValue: snapshot.reportTypeRaw) ?? .other,
            conclusion: ReportConclusion(rawValue: snapshot.conclusionRaw) ?? .normal,
            hospitalName: snapshot.hospitalName,
            doctorName: snapshot.doctorName,
            reportDate: snapshot.reportDate,
            nextCheckDate: snapshot.nextCheckDate,
            summary: snapshot.summary,
            notes: snapshot.notes,
            colorHex: snapshot.colorHex
        )
        report.id = snapshot.id
        report.createdAt = snapshot.createdAt
        context.insert(report)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertPetMilestoneIfNeeded(
        snapshot: DomainPetMilestoneRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchPetMilestone(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let milestone = PetMilestone(
            date: snapshot.date,
            title: snapshot.title,
            emoji: snapshot.emoji,
            notes: snapshot.notes,
            pet: try petReference(id: snapshot.petId, context: context),
            photoData: snapshot.photoData,
            location: snapshot.location
        )
        milestone.id = snapshot.id
        milestone.updatePhotoData(snapshot.photoData)
        context.insert(milestone)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHumanWeightLogIfNeeded(
        snapshot: DomainHumanWeightLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizeHuman(humanId: snapshot.humanId?.uuidString, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHumanWeightLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let log = HumanWeightLog(
            date: snapshot.date,
            weight: snapshot.weight,
            human: try humanReference(id: snapshot.humanId, context: context),
            executorId: snapshot.executorId
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHumanWorkoutLogIfNeeded(
        snapshot: DomainHumanWorkoutLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizeHuman(humanId: snapshot.humanId?.uuidString, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHumanWorkoutLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let log = HumanWorkoutLog(
            date: snapshot.date,
            type: WorkoutType(rawValue: snapshot.typeRaw) ?? .walking,
            durationMinutes: snapshot.durationMinutes,
            distanceKm: snapshot.distanceKm,
            calories: snapshot.calories,
            steps: snapshot.steps,
            notes: snapshot.notes,
            sourceHealthKit: snapshot.sourceHealthKit,
            healthKitWorkoutUUID: snapshot.healthKitWorkoutUUID,
            healthKitSourceBundleID: snapshot.healthKitSourceBundleID,
            healthKitSourceName: snapshot.healthKitSourceName,
            sourcePetWalkLogID: snapshot.sourcePetWalkLogID,
            human: try humanReference(id: snapshot.humanId, context: context)
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertSymptomLogIfNeeded(
        snapshot: DomainSymptomLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchSymptomLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let log = SymptomLog(
            date: snapshot.date,
            category: SymptomCategory(rawValue: snapshot.categoryRaw) ?? .other,
            symptomName: snapshot.symptomName,
            severity: SymptomSeverity(rawValue: snapshot.severityRaw) ?? .mild,
            note: snapshot.note,
            photoData: snapshot.photoData,
            pet: try petReference(id: snapshot.petId, context: context)
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    @discardableResult
    static func insertHeatCycleLogIfNeeded(
        snapshot: DomainHeatCycleLogRehydrateSnapshot,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) throws -> DomainMemberContentRehydrateResult {
        let plan = authorizePet(petId: snapshot.petId, source: source, context: context)
        guard plan.disposition.allowsPersistence else { return DomainMemberContentRehydrateResult(inserted: false, plan: plan) }
        guard try fetchHeatCycleLog(id: snapshot.id, context: context) == nil else {
            return DomainMemberContentRehydrateResult(inserted: false, plan: plan)
        }
        let log = HeatCycleLog(
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
            status: HeatCycleStatus(rawValue: snapshot.statusRaw) ?? .proestrus,
            note: snapshot.note,
            isMated: snapshot.isMated,
            expectedDeliveryDate: snapshot.expectedDeliveryDate,
            pet: try petReference(id: snapshot.petId, context: context)
        )
        log.id = snapshot.id
        context.insert(log)
        plan.consumeAuthorization()
        return DomainMemberContentRehydrateResult(inserted: true, plan: plan)
    }

    private static func authorizePet(
        petId: UUID?,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        let request = petId.map {
            DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: $0.uuidString
            )
        } ?? DomainSubjectResolutionRequest()
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: request,
            source: source,
            context: context,
            requirement: .requiredPet
        )
    }

    private static func authorizeHuman(
        humanId: String?,
        source: DomainRehydrateSourceKind,
        context: ModelContext
    ) -> AuthorizedDomainRehydratePlan {
        let request = humanId.map {
            DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: $0
            )
        } ?? DomainSubjectResolutionRequest()
        return DomainRehydrateAuthorizer.authorizeSubject(
            request: request,
            source: source,
            context: context,
            requirement: .requiredHuman
        )
    }

    private static func petReference(id: UUID?, context: ModelContext) throws -> Pet? {
        guard let id else { return nil }
        return try fetchPet(id: id, context: context)
    }

    private static func humanReference(id: UUID?, context: ModelContext) throws -> Human? {
        guard let id else { return nil }
        return try fetchHuman(id: id, context: context)
    }

    private static func fetchPet(id: UUID, context: ModelContext) throws -> Pet? {
        var descriptor = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHuman(id: UUID, context: ModelContext) throws -> Human? {
        var descriptor = FetchDescriptor<Human>(predicate: #Predicate<Human> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetDocument(id: UUID, context: ModelContext) throws -> PetDocument? {
        var descriptor = FetchDescriptor<PetDocument>(predicate: #Predicate<PetDocument> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetDocumentAttachment(id: UUID, context: ModelContext) throws -> PetDocumentAttachment? {
        var descriptor = FetchDescriptor<PetDocumentAttachment>(
            predicate: #Predicate<PetDocumentAttachment> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetPhotoLog(id: UUID, context: ModelContext) throws -> PetPhotoLog? {
        var descriptor = FetchDescriptor<PetPhotoLog>(predicate: #Predicate<PetPhotoLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetInsurance(id: UUID, context: ModelContext) throws -> PetInsurance? {
        var descriptor = FetchDescriptor<PetInsurance>(predicate: #Predicate<PetInsurance> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchInsuranceClaim(id: UUID, context: ModelContext) throws -> InsuranceClaim? {
        var descriptor = FetchDescriptor<InsuranceClaim>(predicate: #Predicate<InsuranceClaim> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetMedication(id: UUID, context: ModelContext) throws -> PetMedication? {
        var descriptor = FetchDescriptor<PetMedication>(predicate: #Predicate<PetMedication> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHumanMedication(id: UUID, context: ModelContext) throws -> HumanMedication? {
        var descriptor = FetchDescriptor<HumanMedication>(predicate: #Predicate<HumanMedication> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHumanMedicationLog(id: UUID, context: ModelContext) throws -> HumanMedicationLog? {
        var descriptor = FetchDescriptor<HumanMedicationLog>(predicate: #Predicate<HumanMedicationLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHumanHealthMetricLog(id: UUID, context: ModelContext) throws -> HumanHealthMetricLog? {
        var descriptor = FetchDescriptor<HumanHealthMetricLog>(
            predicate: #Predicate<HumanHealthMetricLog> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHumanHealthReport(id: UUID, context: ModelContext) throws -> HumanHealthReport? {
        var descriptor = FetchDescriptor<HumanHealthReport>(
            predicate: #Predicate<HumanHealthReport> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchPetMilestone(id: UUID, context: ModelContext) throws -> PetMilestone? {
        var descriptor = FetchDescriptor<PetMilestone>(predicate: #Predicate<PetMilestone> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHumanWeightLog(id: UUID, context: ModelContext) throws -> HumanWeightLog? {
        var descriptor = FetchDescriptor<HumanWeightLog>(predicate: #Predicate<HumanWeightLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHumanWorkoutLog(id: UUID, context: ModelContext) throws -> HumanWorkoutLog? {
        var descriptor = FetchDescriptor<HumanWorkoutLog>(predicate: #Predicate<HumanWorkoutLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchSymptomLog(id: UUID, context: ModelContext) throws -> SymptomLog? {
        var descriptor = FetchDescriptor<SymptomLog>(predicate: #Predicate<SymptomLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchHeatCycleLog(id: UUID, context: ModelContext) throws -> HeatCycleLog? {
        var descriptor = FetchDescriptor<HeatCycleLog>(predicate: #Predicate<HeatCycleLog> { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

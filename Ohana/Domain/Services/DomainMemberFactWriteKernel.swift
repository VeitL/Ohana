//
//  DomainMemberFactWriteKernel.swift
//  Ohana
//
//  Typed authorization and persistence writer for member content facts.
//

import Foundation
import SwiftData

nonisolated struct DomainMemberFactWriteToken {
    fileprivate init() {}
}

nonisolated struct AuthorizedDomainMemberFactWrite {
    fileprivate let token: DomainMemberFactWriteToken
    let mutationPlan: AuthorizedMutationPlan
    let occurredAt: Date
    let modifiedAt: Date
    let actor: EconomyRewardOwnerResolution

    fileprivate init(
        mutationPlan: AuthorizedMutationPlan,
        occurredAt: Date,
        modifiedAt: Date,
        actor: EconomyRewardOwnerResolution
    ) {
        self.token = DomainMemberFactWriteToken()
        self.mutationPlan = mutationPlan
        self.occurredAt = occurredAt
        self.modifiedAt = modifiedAt
        self.actor = actor
    }

    var writesContent: Bool {
        mutationPlan.writesContent
    }

    var allowsDerivedEffects: Bool {
        mutationPlan.allowsDerivedEffects
    }

    var allowsEconomyDerivation: Bool {
        mutationPlan.allowsEconomyDerivation
    }
}

@MainActor
enum DomainMemberFactWriteAuthorizer {
    static func authorizePetFact(
        pet: Pet,
        occurredAt: Date,
        modifiedAt: Date? = nil,
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .userCommand,
        executorId: String? = nil,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainMemberFactWrite? {
        authorize(
            subjectRequest: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.pet.rawValue,
                relatedEntityId: pet.id.uuidString
            ),
            occurredAt: occurredAt,
            modifiedAt: modifiedAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actorOverride
        )
    }

    static func authorizeHumanFact(
        human: Human,
        occurredAt: Date,
        modifiedAt: Date? = nil,
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .userCommand,
        executorId: String? = nil,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainMemberFactWrite? {
        let humanId = human.id.uuidString
        let actor = actorOverride ?? EconomyRewardOwnerResolution(
            requestedExecutorId: executorId ?? humanId,
            effectiveExecutorId: executorId ?? humanId,
            rewardExecutorId: executorId ?? humanId,
            usedFallback: false
        )
        return authorize(
            subjectRequest: DomainSubjectResolutionRequest(
                relatedEntityType: EntityKind.human.rawValue,
                relatedEntityId: humanId
            ),
            occurredAt: occurredAt,
            modifiedAt: modifiedAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId ?? humanId,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actor
        )
    }

    static func authorizeUnscopedFact(
        occurredAt: Date,
        modifiedAt: Date? = nil,
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .userCommand,
        executorId: String? = nil,
        context: ModelContext,
        logPrefix: String
    ) -> AuthorizedDomainMemberFactWrite? {
        authorize(
            subjectRequest: DomainSubjectResolutionRequest(),
            occurredAt: occurredAt,
            modifiedAt: modifiedAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId,
            context: context,
            logPrefix: logPrefix
        )
    }

    static func authorizeSubjectFact(
        subjectRequest: DomainSubjectResolutionRequest,
        occurredAt: Date,
        modifiedAt: Date? = nil,
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind = .userCommand,
        executorId: String? = nil,
        unresolvedAssigneePolicy: DomainUnresolvedAssigneePolicy = .deny,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainMemberFactWrite? {
        authorize(
            subjectRequest: subjectRequest,
            occurredAt: occurredAt,
            modifiedAt: modifiedAt,
            writeKind: writeKind,
            source: source,
            executorId: executorId,
            unresolvedAssigneePolicy: unresolvedAssigneePolicy,
            context: context,
            logPrefix: logPrefix,
            actorOverride: actorOverride
        )
    }

    private static func authorize(
        subjectRequest: DomainSubjectResolutionRequest,
        occurredAt: Date,
        modifiedAt: Date?,
        writeKind: MemberWriteKind,
        source: DomainMutationSourceKind,
        executorId: String?,
        unresolvedAssigneePolicy: DomainUnresolvedAssigneePolicy = .deny,
        context: ModelContext,
        logPrefix: String,
        actorOverride: EconomyRewardOwnerResolution? = nil
    ) -> AuthorizedDomainMemberFactWrite? {
        guard let mutationPlan = DomainPolicyAuthorizer.authorize(
            DomainMutationAuthorizationRequest(
                scope: .memberContent,
                source: source,
                subjectRequest: subjectRequest,
                writeKind: writeKind,
                unresolvedAssigneePolicy: unresolvedAssigneePolicy,
                assigneeWriteKind: writeKind
            ),
            context: context
        ),
            mutationPlan.writesContent
        else {
            return nil
        }

        let actor = actorOverride ?? CareFactWritePolicy.executorResolution(
            requestedExecutorId: executorId,
            context: context,
            logPrefix: logPrefix
        )
        return AuthorizedDomainMemberFactWrite(
            mutationPlan: mutationPlan,
            occurredAt: occurredAt,
            modifiedAt: modifiedAt ?? occurredAt,
            actor: actor
        )
    }
}

nonisolated enum DomainMemberFactWriter {
    @discardableResult
    static func createPetInsurancePolicy(
        plan: AuthorizedDomainMemberFactWrite,
        companyName: String,
        policyNumber: String,
        productName: String,
        annualPremium: Double,
        coverageAmount: Double,
        startDate: Date,
        renewalDate: Date,
        notes: String,
        paymentFrequency: InsurancePaymentFrequency,
        paymentDayOfMonth: Int,
        showInCalendar: Bool,
        otherFeeAmount: Double,
        otherFeeNote: String,
        pet: Pet,
        context: ModelContext
    ) -> PetInsurance {
        plan.consume()
        let insurance = PetInsurance(
            companyName: companyName,
            policyNumber: policyNumber,
            productName: productName,
            annualPremium: annualPremium,
            coverageAmount: coverageAmount,
            startDate: startDate,
            renewalDate: renewalDate,
            notes: notes,
            paymentFrequency: paymentFrequency,
            paymentDayOfMonth: paymentDayOfMonth,
            showInCalendar: showInCalendar,
            otherFeeAmount: otherFeeAmount,
            otherFeeNote: otherFeeNote,
            pet: pet
        )
        context.insert(insurance)
        CloudSyncMutationRecorder.markModified(insurance, context: context, modifiedAt: plan.modifiedAt)
        return insurance
    }

    static func updatePetInsurancePolicy(
        plan: AuthorizedDomainMemberFactWrite,
        insurance: PetInsurance,
        companyName: String,
        policyNumber: String,
        productName: String,
        annualPremium: Double,
        coverageAmount: Double,
        startDate: Date,
        renewalDate: Date,
        notes: String,
        paymentFrequency: InsurancePaymentFrequency,
        paymentDayOfMonth: Int,
        showInCalendar: Bool,
        otherFeeAmount: Double,
        otherFeeNote: String,
        context: ModelContext
    ) {
        plan.consume()
        insurance.companyName = companyName
        insurance.policyNumber = policyNumber
        insurance.productName = productName
        insurance.annualPremium = annualPremium
        insurance.coverageAmount = coverageAmount
        insurance.startDate = startDate
        insurance.renewalDate = renewalDate
        insurance.notes = notes
        insurance.paymentFrequencyRaw = paymentFrequency.rawValue
        insurance.paymentDayOfMonth = max(1, min(28, paymentDayOfMonth))
        insurance.showInCalendar = showInCalendar
        insurance.otherFeeAmount = otherFeeAmount
        insurance.otherFeeNote = otherFeeNote
        CloudSyncMutationRecorder.markModified(insurance, context: context, modifiedAt: plan.modifiedAt)
    }

    static func setPetInsurancePolicyActive(
        plan: AuthorizedDomainMemberFactWrite,
        insurance: PetInsurance,
        isActive: Bool,
        context: ModelContext
    ) -> Bool {
        plan.consume()
        let didChange = insurance.isActive != isActive
        insurance.isActive = isActive
        if didChange {
            CloudSyncMutationRecorder.markModified(insurance, context: context, modifiedAt: plan.modifiedAt)
        }
        return didChange
    }

    static func deletePetInsurancePolicy(
        plan: AuthorizedDomainMemberFactWrite,
        insurance: PetInsurance,
        pet: Pet,
        context: ModelContext
    ) {
        plan.consume()
        PhysicalDeletionService.deleteInsurance(insurance, pet: pet, context: context)
    }

    @discardableResult
    static func createInsuranceClaim(
        plan: AuthorizedDomainMemberFactWrite,
        claimDate: Date,
        incidentDate: Date,
        totalExpense: Double,
        claimedAmount: Double,
        approvedAmount: Double,
        status: ClaimStatus,
        note: String,
        relatedExpenseLogId: String?,
        approvedAt: Date?,
        insurance: PetInsurance,
        context: ModelContext
    ) -> InsuranceClaim {
        plan.consume()
        let claim = InsuranceClaim(
            claimDate: claimDate,
            incidentDate: incidentDate,
            totalExpense: totalExpense,
            claimedAmount: claimedAmount,
            approvedAmount: approvedAmount,
            status: status,
            note: note,
            relatedExpenseLogId: relatedExpenseLogId,
            insurance: insurance
        )
        claim.approvedAt = approvedAt
        context.insert(claim)
        CloudSyncMutationRecorder.markModified(claim, context: context, modifiedAt: plan.modifiedAt)
        return claim
    }

    static func updateInsuranceClaimStatus(
        plan: AuthorizedDomainMemberFactWrite,
        claim: InsuranceClaim,
        status: ClaimStatus,
        approvedAmount: Double,
        approvedAt: Date?,
        context: ModelContext
    ) -> Bool {
        plan.consume()
        let oldStatus = claim.claimStatus
        let oldApprovedAmount = claim.approvedAmount
        let oldApprovedAt = claim.approvedAt
        claim.statusRaw = status.rawValue
        claim.approvedAmount = approvedAmount
        claim.approvedAt = approvedAt
        let didChange = oldStatus != status || oldApprovedAmount != approvedAmount || oldApprovedAt != approvedAt
        if didChange {
            CloudSyncMutationRecorder.markModified(claim, context: context, modifiedAt: plan.modifiedAt)
        }
        return didChange
    }

    static func deleteInsuranceClaim(
        plan: AuthorizedDomainMemberFactWrite,
        claim: InsuranceClaim,
        pet: Pet,
        context: ModelContext
    ) {
        plan.consume()
        CloudSyncMutationRecorder.markDeleted(claim, pet: pet, context: context, deletedAt: plan.modifiedAt)
        context.delete(claim)
    }

    @discardableResult
    static func createPetDocument(
        plan: AuthorizedDomainMemberFactWrite,
        title: String,
        category: DocumentCategory,
        pet: Pet,
        context: ModelContext
    ) -> PetDocument {
        plan.consume()
        let document = PetDocument(title: title, category: category, pet: pet)
        context.insert(document)
        CloudSyncMutationRecorder.markModified(document, context: context, modifiedAt: plan.modifiedAt)
        return document
    }

    @discardableResult
    static func createPetDocumentAttachment(
        plan: AuthorizedDomainMemberFactWrite,
        data: Data,
        filename: String,
        isImage: Bool,
        document: PetDocument,
        context: ModelContext
    ) -> PetDocumentAttachment {
        plan.consume()
        let attachment = PetDocumentAttachment(data: data, filename: filename, isImage: isImage)
        document.attachments.append(attachment)
        context.insert(attachment)
        CloudSyncMutationRecorder.markModified(document, context: context, modifiedAt: plan.modifiedAt)
        return attachment
    }

    @discardableResult
    static func createPetPhotoLog(
        plan: AuthorizedDomainMemberFactWrite,
        imageData: Data,
        date: Date,
        note: String = "",
        pet: Pet?,
        locationLatitude: Double = 0,
        locationLongitude: Double = 0,
        locationPlacename: String = "",
        context: ModelContext
    ) -> PetPhotoLog {
        plan.consume()
        let log = PetPhotoLog(
            imageData: imageData,
            date: date,
            note: note,
            pet: pet,
            locationLatitude: locationLatitude,
            locationLongitude: locationLongitude,
            locationPlacename: locationPlacename
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createPetMilestone(
        plan: AuthorizedDomainMemberFactWrite,
        date: Date,
        title: String,
        emoji: String,
        notes: String,
        pet: Pet,
        photoData: Data? = nil,
        location: String = "",
        context: ModelContext
    ) -> PetMilestone {
        plan.consume()
        let milestone = PetMilestone(
            date: date,
            title: title,
            emoji: emoji,
            notes: notes,
            pet: pet,
            photoData: photoData,
            location: location
        )
        context.insert(milestone)
        CloudSyncMutationRecorder.markModified(milestone, context: context, modifiedAt: plan.modifiedAt)
        return milestone
    }

    @discardableResult
    static func createPetWeightLog(
        plan: AuthorizedDomainMemberFactWrite,
        pet: Pet,
        weight: Double,
        weightUnit: String,
        bcsScore: Int,
        context: ModelContext
    ) -> PetWeightLog {
        plan.consume()
        let log = PetWeightLog(
            date: plan.occurredAt,
            weight: weight,
            weightUnit: weightUnit,
            bcsScore: bcsScore,
            pet: pet,
            executorId: plan.actor.effectiveExecutorId
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createHumanWeightLog(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        weight: Double,
        context: ModelContext
    ) -> HumanWeightLog {
        plan.consume()
        let log = HumanWeightLog(
            date: plan.occurredAt,
            weight: weight,
            human: human,
            executorId: plan.actor.effectiveExecutorId
        )
        context.insert(log)
        human.weightLogs.append(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createSymptomLog(
        plan: AuthorizedDomainMemberFactWrite,
        pet: Pet,
        category: SymptomCategory,
        symptomName: String,
        severity: SymptomSeverity,
        note: String,
        photoData: Data?,
        context: ModelContext
    ) -> SymptomLog {
        plan.consume()
        let log = SymptomLog(
            date: plan.occurredAt,
            category: category,
            symptomName: symptomName,
            severity: severity,
            note: note,
            photoData: photoData,
            pet: pet
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createHeatCycleLog(
        plan: AuthorizedDomainMemberFactWrite,
        pet: Pet,
        endDate: Date?,
        status: HeatCycleStatus,
        note: String,
        isMated: Bool,
        expectedDeliveryDate: Date?,
        context: ModelContext
    ) -> HeatCycleLog {
        plan.consume()
        let log = HeatCycleLog(
            startDate: plan.occurredAt,
            endDate: endDate,
            status: status,
            note: note,
            isMated: isMated,
            expectedDeliveryDate: expectedDeliveryDate,
            pet: pet
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createHumanHealthMetricLog(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        metricKey: String,
        unitCode: String,
        value: Double,
        notes: String,
        context: ModelContext
    ) -> HumanHealthMetricLog {
        plan.consume()
        let log = HumanHealthMetricLog(
            metricKey: metricKey,
            unitCode: unitCode,
            value: value,
            date: plan.occurredAt,
            notes: notes,
            human: human
        )
        context.insert(log)
        human.healthMetricLogs.append(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createHumanHealthReport(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        reportType: HealthReportType,
        conclusion: ReportConclusion,
        hospitalName: String,
        doctorName: String,
        reportDate: Date,
        nextCheckDate: Date?,
        summary: String,
        notes: String,
        context: ModelContext
    ) -> HumanHealthReport {
        plan.consume()
        let report = HumanHealthReport(
            humanId: human.id.uuidString,
            reportType: reportType,
            conclusion: conclusion,
            hospitalName: hospitalName,
            doctorName: doctorName,
            reportDate: reportDate,
            nextCheckDate: nextCheckDate,
            summary: summary,
            notes: notes
        )
        context.insert(report)
        CloudSyncMutationRecorder.markModified(report, context: context, modifiedAt: plan.modifiedAt)
        return report
    }

    @discardableResult
    static func createHumanWorkoutLog(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        type: WorkoutType,
        durationMinutes: Int,
        distanceKm: Double,
        calories: Int,
        steps: Int = 0,
        notes: String,
        sourceHealthKit: Bool = false,
        healthKitWorkoutUUID: String = "",
        healthKitSourceBundleID: String = "",
        healthKitSourceName: String = "",
        sourcePetWalkLogID: String = "",
        context: ModelContext
    ) -> HumanWorkoutLog {
        plan.consume()
        let log = HumanWorkoutLog(
            date: plan.occurredAt,
            type: type,
            durationMinutes: durationMinutes,
            distanceKm: distanceKm,
            calories: calories,
            steps: steps,
            notes: notes,
            sourceHealthKit: sourceHealthKit,
            healthKitWorkoutUUID: healthKitWorkoutUUID,
            healthKitSourceBundleID: healthKitSourceBundleID,
            healthKitSourceName: healthKitSourceName,
            sourcePetWalkLogID: sourcePetWalkLogID,
            human: human
        )
        context.insert(log)
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return log
    }

    @discardableResult
    static func createHumanMedicationPlan(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        customFrequencyNote: String = "",
        firstDoseTime: Date,
        startDate: Date,
        endDate: Date? = nil,
        colorHex: String,
        notes: String,
        isActive: Bool = true,
        context: ModelContext
    ) -> HumanMedication {
        plan.consume()
        let medication = HumanMedication(
            humanId: human.id.uuidString,
            name: name,
            dosage: dosage,
            frequency: frequency,
            firstDoseTime: firstDoseTime,
            startDate: startDate,
            endDate: endDate,
            colorHex: colorHex,
            notes: notes
        )
        medication.customFrequencyNote = customFrequencyNote
        medication.isActive = isActive
        context.insert(medication)
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: plan.modifiedAt)
        return medication
    }

    static func updateHumanMedicationPlan(
        plan: AuthorizedDomainMemberFactWrite,
        medication: HumanMedication,
        human: Human,
        name: String,
        dosage: String,
        frequency: MedicationFrequency,
        customFrequencyNote: String,
        firstDoseTime: Date,
        startDate: Date,
        endDate: Date?,
        colorHex: String,
        notes: String,
        isActive: Bool,
        context: ModelContext
    ) {
        plan.consume()
        medication.humanId = human.id.uuidString
        medication.name = name
        medication.dosage = dosage
        medication.frequency = frequency
        medication.customFrequencyNote = customFrequencyNote
        medication.firstDoseTime = firstDoseTime
        medication.startDate = startDate
        medication.endDate = endDate
        medication.colorHex = colorHex
        medication.notes = notes
        medication.isActive = isActive
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: plan.modifiedAt)
    }

    static func updateHumanMedicationPlanActive(
        plan: AuthorizedDomainMemberFactWrite,
        medication: HumanMedication,
        isActive: Bool,
        context: ModelContext
    ) {
        plan.consume()
        medication.isActive = isActive
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: plan.modifiedAt)
    }

    static func deleteHumanMedicationPlan(
        plan: AuthorizedDomainMemberFactWrite,
        medication: HumanMedication,
        context: ModelContext
    ) {
        plan.consume()
        CloudSyncMutationRecorder.markDeleted(medication, context: context)
        context.delete(medication)
    }

    @discardableResult
    static func createPetMedicationPlan(
        plan: AuthorizedDomainMemberFactWrite,
        pet: Pet,
        name: String,
        dosage: String,
        frequency: PetMedicationFrequency,
        customFrequencyNote: String,
        startDate: Date,
        endDate: Date? = nil,
        colorHex: String,
        notes: String,
        isActive: Bool = true,
        remainingAmount: Double = 0,
        context: ModelContext
    ) -> PetMedication {
        plan.consume()
        let medication = PetMedication(
            name: name,
            dosage: dosage,
            frequency: frequency,
            startDate: startDate,
            endDate: endDate,
            colorHex: colorHex,
            notes: notes,
            pet: pet
        )
        medication.customFrequencyNote = customFrequencyNote
        medication.isActive = isActive
        medication.remainingAmount = max(0, remainingAmount)
        context.insert(medication)
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: plan.modifiedAt)
        return medication
    }

    static func updatePetMedicationPlan(
        plan: AuthorizedDomainMemberFactWrite,
        medication: PetMedication,
        pet: Pet,
        name: String,
        dosage: String,
        frequency: PetMedicationFrequency,
        customFrequencyNote: String,
        startDate: Date,
        endDate: Date?,
        colorHex: String,
        notes: String,
        isActive: Bool,
        remainingAmount: Double,
        context: ModelContext
    ) {
        plan.consume()
        medication.name = name
        medication.dosage = dosage
        medication.frequency = frequency
        medication.customFrequencyNote = customFrequencyNote
        medication.startDate = startDate
        medication.endDate = endDate
        medication.colorHex = colorHex
        medication.notes = notes
        medication.isActive = isActive
        medication.remainingAmount = max(0, remainingAmount)
        medication.pet = pet
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: plan.modifiedAt)
    }

    static func updatePetMedicationPlanActive(
        plan: AuthorizedDomainMemberFactWrite,
        medication: PetMedication,
        isActive: Bool,
        context: ModelContext
    ) {
        plan.consume()
        medication.isActive = isActive
        CloudSyncMutationRecorder.markModified(medication, context: context, modifiedAt: plan.modifiedAt)
    }

    static func deletePetMedicationPlan(
        plan: AuthorizedDomainMemberFactWrite,
        medication: PetMedication,
        pet: Pet,
        context: ModelContext
    ) {
        plan.consume()
        CloudSyncMutationRecorder.markDeleted(medication, pet: pet, context: context)
        context.delete(medication)
    }

    @discardableResult
    @MainActor
    static func applyHumanMedicationDoseStatus(
        plan: AuthorizedDomainMemberFactWrite,
        human: Human,
        medicationId: UUID,
        scheduledTime: Date,
        status: HumanMedicationStatus,
        existingLogs: [HumanMedicationLog] = [],
        context: ModelContext,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> HumanMedicationDoseLogUpdate {
        plan.consume()
        let humanId = human.id.uuidString
        let medicationIdString = medicationId.uuidString
        let matching = HumanMedicationLogStore.matchingLog(
            in: existingLogs,
            humanId: humanId,
            medicationId: medicationIdString,
            scheduledTime: scheduledTime,
            calendar: calendar
        ) ?? fetchMatchingHumanMedicationLog(
            humanId: humanId,
            medicationId: medicationIdString,
            scheduledTime: scheduledTime,
            context: context,
            calendar: calendar
        )

        guard let log = matching else {
            guard status != .pending else {
                return HumanMedicationDoseLogUpdate(log: nil, previousStatus: nil, didChange: false)
            }
            let log = HumanMedicationLog(
                humanId: humanId,
                medicationId: medicationIdString,
                scheduledTime: scheduledTime,
                status: status,
                recordedTime: now
            )
            context.insert(log)
            CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
            return HumanMedicationDoseLogUpdate(log: log, previousStatus: nil, didChange: true)
        }

        let previous = log.status
        guard previous != status else {
            return HumanMedicationDoseLogUpdate(log: log, previousStatus: previous, didChange: false)
        }
        log.status = status
        log.recordedTime = status == .pending ? nil : now
        CloudSyncMutationRecorder.markModified(log, context: context, modifiedAt: plan.modifiedAt)
        return HumanMedicationDoseLogUpdate(log: log, previousStatus: previous, didChange: true)
    }

    @discardableResult
    static func createWishlistItem(
        plan: AuthorizedDomainMemberFactWrite,
        title: String,
        cost: Int,
        human: Human,
        createdAt: Date,
        context: ModelContext
    ) -> WishlistItem {
        plan.consume()
        let item = WishlistItem(title: title, cost: cost, creatorId: human.id.uuidString)
        item.createdAt = createdAt
        context.insert(item)
        CloudSyncMutationRecorder.markModified(item, context: context, modifiedAt: plan.modifiedAt)
        return item
    }

    static func redeemWishlistItem(
        plan: AuthorizedDomainMemberFactWrite,
        item: WishlistItem,
        redeemedById: String?,
        context: ModelContext
    ) {
        plan.consume()
        item.isRedeemed = true
        item.redeemedById = redeemedById
        CloudSyncMutationRecorder.markModified(item, context: context, modifiedAt: plan.modifiedAt)
    }

    static func deleteWishlistItem(
        plan: AuthorizedDomainMemberFactWrite,
        item: WishlistItem,
        context: ModelContext
    ) {
        plan.consume()
        CloudSyncMutationRecorder.markDeleted(item, context: context)
        context.delete(item)
    }

    @discardableResult
    static func createFamilyTask(
        plan: AuthorizedDomainMemberFactWrite,
        id: UUID = UUID(),
        title: String,
        note: String = "",
        kind: FamilyCollaborationTaskKind,
        status: FamilyCollaborationTaskStatus = .active,
        relatedPetId: String? = nil,
        relatedEventId: String? = nil,
        relatedReminderId: String? = nil,
        createdById: String,
        createdByName: String,
        assignedToId: String? = nil,
        assignedToName: String? = nil,
        rewardCoconuts: Int = 0,
        dueAt: Date? = nil,
        emoji: String = "🎯",
        createdAt: Date? = nil,
        context: ModelContext
    ) -> FamilyCollaborationTask {
        plan.consume()
        let task = FamilyCollaborationTask(
            id: id,
            title: title,
            note: note,
            kind: kind,
            status: status,
            relatedPetId: relatedPetId,
            relatedEventId: relatedEventId,
            relatedReminderId: relatedReminderId,
            createdById: createdById,
            createdByName: createdByName,
            assignedToId: assignedToId,
            assignedToName: assignedToName,
            rewardCoconuts: rewardCoconuts,
            dueAt: dueAt,
            emoji: emoji,
            createdAt: createdAt ?? plan.occurredAt
        )
        context.insert(task)
        CloudSyncMutationRecorder.markModified(task, context: context, modifiedAt: plan.modifiedAt)
        return task
    }

    static func mutateFamilyTask(
        plan: AuthorizedDomainMemberFactWrite,
        task: FamilyCollaborationTask,
        context: ModelContext,
        mutation: (FamilyCollaborationTask) -> Void
    ) {
        plan.consume()
        mutation(task)
        CloudSyncMutationRecorder.markModified(task, context: context, modifiedAt: plan.modifiedAt)
    }

    static func deleteFamilyTask(
        plan: AuthorizedDomainMemberFactWrite,
        task: FamilyCollaborationTask,
        context: ModelContext
    ) {
        plan.consume()
        _ = CloudSyncMutationRecorder.markDeleted(
            entityName: String(describing: FamilyCollaborationTask.self),
            localRecordId: task.id,
            householdId: nil,
            fallbackHouseholdId: UUID(uuidString: task.createdById)
                ?? UUID(uuidString: task.assignedToId ?? "")
                ?? UUID(uuidString: task.claimedById ?? "")
                ?? task.id,
            deletedAt: plan.modifiedAt,
            deletedByHumanId: nil,
            context: context
        )
        context.delete(task)
    }

    @MainActor
    private static func fetchMatchingHumanMedicationLog(
        humanId: String,
        medicationId: String,
        scheduledTime: Date,
        context: ModelContext,
        calendar: Calendar
    ) -> HumanMedicationLog? {
        var descriptor = FetchDescriptor<HumanMedicationLog>(
            predicate: #Predicate<HumanMedicationLog> { log in
                log.humanId == humanId && log.medicationId == medicationId
            }
        )
        descriptor.fetchLimit = 128
        let logs: [HumanMedicationLog]
        do {
            logs = try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[DomainMemberFactWriter] failed to fetch human medication log for humanId=\(humanId) medicationId=\(medicationId): \(error.localizedDescription)",
                category: "Care"
            )
            logs = []
        }
        return HumanMedicationLogStore.matchingLog(
            in: logs,
            humanId: humanId,
            medicationId: medicationId,
            scheduledTime: scheduledTime,
            calendar: calendar
        )
    }
}

@MainActor
enum DomainMemberFactEffectsDispatcher {
    @discardableResult
    static func run(
        plan: AuthorizedDomainMemberFactWrite,
        _ effects: (EconomyRewardOwnerResolution) -> Void
    ) -> Bool {
        plan.consume()
        guard plan.allowsDerivedEffects else { return false }
        effects(plan.actor)
        return true
    }

    static func map<Result>(
        plan: AuthorizedDomainMemberFactWrite,
        default defaultValue: Result,
        _ effects: (EconomyRewardOwnerResolution) -> Result
    ) -> Result {
        plan.consume()
        guard plan.allowsDerivedEffects else { return defaultValue }
        return effects(plan.actor)
    }
}

private nonisolated extension AuthorizedDomainMemberFactWrite {
    func consume() {
        _ = token
        mutationPlan.consumeAuthorization()
    }
}

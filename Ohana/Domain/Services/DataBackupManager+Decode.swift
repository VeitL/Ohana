//
//  DataBackupManager+Decode.swift
//  Ohana
//

import Foundation
import SwiftData

nonisolated extension DataBackupManager {
    // MARK: - Decode helpers

    func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso.date(from: s)
    }

    func decodePetSnapshot(
        _ dto: PetBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainPetRehydrateSnapshot {
        DomainPetRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            name: dto.name,
            species: dto.species,
            breed: dto.breed,
            birthday: parseDate(dto.birthday),
            gender: dto.gender,
            isNeutered: dto.isNeutered,
            avatarEmoji: dto.avatarEmoji,
            avatarImageData: nil,
            microchipID: dto.microchipID,
            vetContact: dto.vetContact,
            vetClinicName: "",
            vetDoctorName: "",
            vetAddress: "",
            allergies: dto.allergies,
            passportNumber: dto.passportNumber,
            passportExpiryDate: parseDate(dto.passportExpiryDate),
            formerName: dto.formerName,
            lineageInfo: dto.lineageInfo,
            themeColorHex: dto.themeColorHex,
            homeDate: parseDate(dto.homeDate),
            birthCountry: dto.birthCountry,
            birthCity: dto.birthCity,
            foodBrand: dto.foodBrand,
            restockDate: parseDate(dto.restockDate),
            restockWeight: dto.restockWeight,
            dailyPortionGrams: dto.dailyPortionGrams,
            mainFoodKindRaw: dto.mainFoodKindRaw ?? FeedFoodKind.dry.rawValue,
            foodPrice: dto.foodPrice,
            isShared: dto.isShared,
            ckRecordName: "",
            createdAt: parseDate(dto.createdAt) ?? Date(),
            notes: dto.notes,
            coatColor: dto.coatColor,
            eyeColor: dto.eyeColor,
            currentStreak: dto.currentStreak,
            lastCheckInDate: parseDate(dto.lastCheckInDate),
            foodTrackingModeRaw: dto.foodTrackingModeRaw,
            casualOpenDate: parseDate(dto.casualOpenDate),
            casualDurationDays: dto.casualDurationDays,
            foodReminderEnabled: dto.foodReminderEnabled ?? false,
            foodReminderAdvanceDays: dto.foodReminderAdvanceDays ?? 7,
            coconutBalance: dto.coconutBalance,
            passedAwayDate: parseDate(dto.passedAwayDate),
            cardStyleRaw: dto.cardStyleRaw ?? "classic",
            cardPopoutImageData: try mediaData(
                reference: dto.cardPopoutImageRef,
                legacyBase64: dto.cardPopoutImageBase64,
                resolver: mediaResolver
            ),
            cardPopoutSourceRaw: dto.cardPopoutSourceRaw,
            weeklyWalkGoalKm: 0,
            personalityTagsRaw: dto.personalityTagsRaw ?? ""
        )
    }

    func decodeHumanSnapshot(
        _ dto: HumanBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainHumanRehydrateSnapshot {
        DomainHumanRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            name: dto.name,
            birthday: parseDate(dto.birthday),
            bloodType: dto.bloodType,
            avatarEmoji: dto.avatarEmoji,
            avatarImageData: try mediaData(
                reference: dto.avatarImageRef,
                legacyBase64: dto.avatarImageBase64,
                resolver: mediaResolver
            ),
            role: dto.role,
            genderIdentityRaw: dto.genderIdentityRaw ?? HumanProfileOptions.genderMetadata(from: dto.notes),
            notes: HumanProfileOptions.visibleNoteParts(from: dto.notes).joined(separator: "｜"),
            createdAt: parseDate(dto.createdAt) ?? Date(),
            nationality: dto.nationality,
            city: dto.city,
            coconutBalance: dto.coconutBalance,
            shouldShowOnHome: dto.shouldShowOnHome,
            mbti: dto.mbti ?? "",
            privateFieldsRaw: dto.privateFieldsRaw ?? "",
            themeColorHex: dto.themeColorHex ?? "",
            heightCm: dto.heightCm ?? 0,
            passedAwayDate: parseDate(dto.passedAwayDate)
        )
    }

    func decodeHouseholdSnapshot(_ dto: HouseholdBackup) -> DomainHouseholdRehydrateSnapshot {
        DomainHouseholdRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            name: dto.name,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            totalProsperity: dto.totalProsperity
        )
    }

    func decodeEventSnapshot(_ dto: EventBackup) -> DomainScheduleRehydrateEventSnapshot {
        DomainScheduleRehydrateEventSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            title: dto.title,
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            isAllDay: dto.isAllDay,
            eventType: dto.eventType,
            relatedEntityType: dto.relatedEntityType,
            relatedEntityId: dto.relatedEntityId,
            recurrenceDays: dto.recurrenceDays,
            recurrenceEndDate: parseDate(dto.recurrenceEndDate),
            isCompleted: dto.isCompleted,
            completedOccurrences: dto.completedOccurrences ?? [],
            createdAt: parseDate(dto.createdAt) ?? Date(),
            assigneeId: dto.assigneeId,
            feedRuleKindRaw: dto.feedRuleKindRaw ?? "",
            foodKindRaw: dto.foodKindRaw ?? FeedFoodKind.dry.rawValue,
            feedAmountGrams: dto.feedAmountGrams ?? 0,
            feedPlanGroupId: dto.feedPlanGroupId ?? ""
        )
    }

    func decodeReminderSnapshot(_ dto: ReminderBackup) -> DomainScheduleRehydrateReminderSnapshot {
        DomainScheduleRehydrateReminderSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            scheduledAt: parseDate(dto.scheduledAt) ?? Date(),
            status: dto.status,
            notificationId: dto.notificationId,
            eventId: dto.eventId.flatMap(UUID.init(uuidString:)),
            completedAt: parseDate(dto.completedAt),
            completedBy: dto.completedBy ?? "",
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeCareLogSnapshot(_ dto: PetCareLogBackup) -> DomainPetCareLogRehydrateSnapshot {
        DomainPetCareLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            typeRaw: dto.type,
            amountGrams: dto.amountGrams,
            amountMl: dto.amountMl,
            note: dto.note,
            foodKindRaw: dto.foodKindRaw ?? FeedFoodKind.dry.rawValue,
            treatKindRaw: dto.treatKindRaw,
            autoFeedDedupKey: "",
            sharedSessionId: dto.sharedSessionId ?? "",
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId
        )
    }

    func decodePlantCareLogSnapshot(
        _ dto: PlantCareLogBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainPlantCareLogRehydrateSnapshot {
        DomainPlantCareLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            careTypeRaw: dto.careTypeRaw,
            note: dto.note,
            executorId: dto.executorId,
            plantId: dto.plantId.flatMap(UUID.init(uuidString:)),
            healthStatusRaw: dto.healthStatusRaw ?? "",
            photoData: try mediaData(
                reference: dto.photoRef,
                legacyBase64: dto.photoBase64,
                resolver: mediaResolver
            )
        )
    }

    func decodePottyLogSnapshot(_ dto: PetPottyLogBackup) -> DomainPetPottyLogRehydrateSnapshot {
        DomainPetPottyLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            typeRaw: dto.type,
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId,
            latitude: dto.latitude,
            longitude: dto.longitude,
            locationAccuracyMeters: dto.locationAccuracyMeters,
            walkLogId: dto.walkLogId,
            sharedSessionId: dto.sharedSessionId ?? ""
        )
    }

    func decodeSharedCareSessionSnapshot(_ dto: SharedCareSessionBackup) -> DomainSharedCareSessionRehydrateSnapshot {
        DomainSharedCareSessionRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            actionKindRaw: dto.actionKindRaw,
            executorId: dto.executorId,
            executorIdsRaw: dto.executorIdsRaw ?? "",
            sourcePetId: dto.sourcePetId,
            targetPetIds: dto.targetPetIdsRaw.split(separator: "|").map(String.init),
            speciesRaw: dto.speciesRaw,
            totalAmountGrams: dto.totalAmountGrams,
            totalAmountMl: dto.totalAmountMl,
            totalExpenseAmount: dto.totalExpenseAmount ?? 0,
            expenseCategoryRaw: dto.expenseCategoryRaw ?? ExpenseCategory.other.rawValue,
            currencyCode: dto.currencyCode ?? "",
            allocationModeRaw: dto.allocationModeRaw,
            foodKindRaw: dto.foodKindRaw,
            stockOwnerPetId: dto.stockOwnerPetId,
            primaryLegacyModelName: dto.primaryLegacyModelName ?? "",
            primaryLegacyModelId: dto.primaryLegacyModelId ?? "",
            note: dto.note,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeWalkLogSnapshot(_ dto: PetWalkLogBackup) -> DomainPetWalkLogRehydrateSnapshot {
        DomainPetWalkLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            startDate: parseDate(dto.startDate) ?? Date(),
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId,
            executorIdsRaw: dto.executorIdsRaw ?? "",
            sharedSessionId: dto.sharedSessionId ?? "",
            endDate: parseDate(dto.endDate),
            distanceMeters: dto.distanceMeters,
            coconutsEarned: dto.coconutsEarned,
            mapSnapshotData: nil,
            routeLocationsData: nil,
            behaviorNotes: dto.behaviorNotes,
            moodRating: dto.moodRating ?? 0
        )
    }

    func decodeWeightLogSnapshot(_ dto: PetWeightLogBackup) -> DomainPetWeightLogRehydrateSnapshot {
        DomainPetWeightLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            weight: dto.weight,
            weightUnit: "kg",
            bcsScore: 0,
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId
        )
    }

    func decodeExpenseLogSnapshot(_ dto: PetExpenseLogBackup) -> DomainPetExpenseLogRehydrateSnapshot {
        DomainPetExpenseLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            amount: dto.amount,
            categoryRaw: dto.category,
            note: dto.note,
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId,
            sharedSessionId: dto.sharedSessionId ?? ""
        )
    }

    func decodeHealthLogSnapshot(_ dto: PetHealthLogBackup) -> DomainPetHealthLogRehydrateSnapshot {
        DomainPetHealthLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            typeRaw: dto.type,
            note: dto.note,
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId,
            vetName: dto.vetName,
            cost: dto.cost,
            expirationDate: parseDate(dto.expirationDate),
            nextCheckupDate: nil
        )
    }

    func decodeHygieneLogSnapshot(_ dto: PetHygieneLogBackup) -> DomainPetHygieneLogRehydrateSnapshot {
        DomainPetHygieneLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            typeRaw: dto.type,
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId,
            sharedSessionId: dto.sharedSessionId ?? ""
        )
    }

    func decodeFoodRecordSnapshot(_ dto: PetFoodRecordBackup) -> DomainPetFoodRecordRehydrateSnapshot {
        DomainPetFoodRecordRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            brand: dto.brand,
            dailyGrams: dto.dailyGrams,
            totalGrams: dto.totalGrams ?? 0,
            foodKindRaw: dto.foodKindRaw ?? FeedFoodKind.dry.rawValue,
            purchaseDate: parseDate(dto.purchaseDate ?? ""),
            startDate: parseDate(dto.date) ?? Date(),
            remainingCorrectionGrams: dto.remainingCorrectionGrams,
            remainingCorrectionDate: parseDate(dto.remainingCorrectionDate ?? ""),
            notes: dto.notes ?? "",
            expenseId: nil,
            calculationModeRaw: FeedStockCalculationMode.manualOrPlan.rawValue,
            executorId: dto.executorId,
            petId: dto.petId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeDocumentSnapshot(
        _ dto: PetDocumentBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainPetDocumentRehydrateSnapshot {
        DomainPetDocumentRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            title: dto.title,
            categoryRaw: dto.categoryRaw,
            expiryDate: parseDate(dto.expiryDate),
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            issueDate: parseDate(dto.issueDate),
            issuingAuthority: dto.issuingAuthority ?? "",
            notes: dto.notes ?? "",
            reminderDate: parseDate(dto.reminderDate),
            cost: dto.cost ?? 0,
            attachmentData: try mediaData(
                reference: dto.attachmentRef,
                legacyBase64: dto.attachmentBase64,
                resolver: mediaResolver
            ),
            attachmentFilename: dto.attachmentFilename ?? ""
        )
    }

    func decodeDocumentAttachmentSnapshot(
        _ dto: PetDocumentAttachmentBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainPetDocumentAttachmentRehydrateSnapshot {
        DomainPetDocumentAttachmentRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            documentId: UUID(uuidString: dto.documentId),
            data: try mediaData(
                reference: dto.dataRef,
                legacyBase64: dto.dataBase64,
                resolver: mediaResolver
            ),
            filename: dto.filename,
            isImage: dto.isImage
        )
    }

    func decodeMilestoneSnapshot(_ dto: PetMilestoneBackup) -> DomainPetMilestoneRehydrateSnapshot {
        DomainPetMilestoneRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            title: dto.title,
            emoji: dto.emoji,
            notes: dto.notes,
            petId: dto.petId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeHumanWeightSnapshot(_ dto: HumanWeightLogBackup) -> DomainHumanWeightLogRehydrateSnapshot {
        DomainHumanWeightLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            weight: dto.weight,
            humanId: dto.humanId.flatMap(UUID.init(uuidString:)),
            executorId: dto.executorId
        )
    }

    func decodeHumanWorkoutSnapshot(_ dto: HumanWorkoutLogBackup) -> DomainHumanWorkoutLogRehydrateSnapshot {
        DomainHumanWorkoutLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            typeRaw: dto.typeRaw,
            durationMinutes: dto.durationMinutes,
            distanceKm: dto.distanceKm ?? 0,
            calories: dto.calories ?? 0,
            steps: dto.steps ?? 0,
            notes: dto.notes,
            sourceHealthKit: dto.sourceHealthKit ?? false,
            healthKitWorkoutUUID: dto.healthKitWorkoutUUID ?? "",
            healthKitSourceBundleID: dto.healthKitSourceBundleID ?? "",
            healthKitSourceName: dto.healthKitSourceName ?? "",
            sourcePetWalkLogID: dto.sourcePetWalkLogID ?? "",
            humanId: dto.humanId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeWaterLogSnapshot(_ dto: WaterLogBackup) -> DomainWaterLogRehydrateSnapshot {
        DomainWaterLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            amountMl: dto.amountMl,
            note: dto.note
        )
    }

    func decodePhotoLogSnapshot(
        _ dto: PetPhotoLogBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainPetPhotoLogRehydrateSnapshot {
        DomainPetPhotoLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            imageData: try mediaData(
                reference: dto.imageRef,
                legacyBase64: dto.imageBase64,
                resolver: mediaResolver
            ) ?? Data(),
            date: parseDate(dto.date) ?? Date(),
            note: dto.note,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            petId: dto.petId.flatMap(UUID.init(uuidString:)),
            locationLatitude: dto.locationLatitude,
            locationLongitude: dto.locationLongitude,
            locationPlacename: dto.locationPlacename
        )
    }

    func decodeInsuranceSnapshot(_ dto: PetInsuranceBackup) -> DomainPetInsuranceRehydrateSnapshot {
        DomainPetInsuranceRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            companyName: dto.companyName,
            policyNumber: dto.policyNumber,
            productName: dto.productName,
            annualPremium: dto.annualPremium,
            coverageAmount: dto.coverageAmount,
            startDate: parseDate(dto.startDate) ?? Date(),
            renewalDate: parseDate(dto.renewalDate) ?? Date(),
            notes: dto.notes,
            isActive: dto.isActive,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            paymentFrequencyRaw: dto.paymentFrequencyRaw,
            paymentDayOfMonth: dto.paymentDayOfMonth,
            showInCalendar: dto.showInCalendar,
            otherFeeAmount: dto.otherFeeAmount,
            otherFeeNote: dto.otherFeeNote,
            firstPremiumPaymentDate: parseDate(dto.firstPremiumPaymentDate),
            petId: dto.petId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeInsuranceClaimSnapshot(_ dto: InsuranceClaimBackup) -> DomainInsuranceClaimRehydrateSnapshot {
        DomainInsuranceClaimRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            insuranceId: dto.insuranceId.flatMap(UUID.init(uuidString:)),
            claimDate: parseDate(dto.claimDate) ?? Date(),
            incidentDate: parseDate(dto.incidentDate) ?? Date(),
            totalExpense: dto.totalExpense,
            claimedAmount: dto.claimedAmount,
            approvedAmount: dto.approvedAmount,
            statusRaw: dto.statusRaw,
            note: dto.note,
            relatedExpenseLogId: dto.relatedExpenseLogId,
            approvedAt: parseDate(dto.approvedAt),
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodePetMedicationSnapshot(_ dto: PetMedicationBackup) -> DomainPetMedicationRehydrateSnapshot {
        DomainPetMedicationRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            name: dto.name,
            dosage: dto.dosage,
            frequencyRaw: dto.frequencyRaw,
            customFrequencyNote: dto.customFrequencyNote,
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            colorHex: dto.colorHex,
            notes: dto.notes,
            isActive: dto.isActive,
            remainingAmount: max(0, dto.remainingAmount ?? 0),
            createdAt: parseDate(dto.createdAt) ?? Date(),
            petId: dto.petId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeHumanMedicationSnapshot(_ dto: HumanMedicationBackup) -> DomainHumanMedicationRehydrateSnapshot {
        DomainHumanMedicationRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            humanId: dto.humanId,
            name: dto.name,
            dosage: dto.dosage,
            frequencyRaw: dto.frequencyRaw,
            customFrequencyNote: dto.customFrequencyNote,
            firstDoseTime: parseDate(dto.firstDoseTime) ?? Date(),
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            colorHex: dto.colorHex,
            notes: dto.notes,
            isActive: dto.isActive,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeHumanMedicationLogSnapshot(_ dto: HumanMedicationLogBackup) -> DomainHumanMedicationLogRehydrateSnapshot {
        DomainHumanMedicationLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            humanId: dto.humanId,
            medicationId: dto.medicationId,
            scheduledTime: parseDate(dto.scheduledTime) ?? Date(),
            statusRaw: dto.statusRaw,
            recordedTime: parseDate(dto.recordedTime),
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeHumanHealthMetricLogSnapshot(_ dto: HumanHealthMetricLogBackup) -> DomainHumanHealthMetricLogRehydrateSnapshot {
        DomainHumanHealthMetricLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            metricKey: dto.metricKey,
            unitCode: dto.unitCode,
            value: dto.value,
            date: parseDate(dto.date) ?? Date(),
            notes: dto.notes,
            humanId: dto.humanId.flatMap(UUID.init(uuidString:)),
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeHumanHealthReportSnapshot(_ dto: HumanHealthReportBackup) -> DomainHumanHealthReportRehydrateSnapshot {
        DomainHumanHealthReportRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            humanId: dto.humanId,
            reportTypeRaw: dto.reportTypeRaw,
            conclusionRaw: dto.conclusionRaw,
            hospitalName: dto.hospitalName,
            doctorName: dto.doctorName,
            reportDate: parseDate(dto.reportDate) ?? Date(),
            nextCheckDate: parseDate(dto.nextCheckDate),
            summary: dto.summary,
            notes: dto.notes,
            colorHex: dto.colorHex,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeSymptomLogSnapshot(
        _ dto: SymptomLogBackup,
        mediaResolver: DataBackupMediaResolving? = nil
    ) throws -> DomainSymptomLogRehydrateSnapshot {
        DomainSymptomLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            date: parseDate(dto.date) ?? Date(),
            categoryRaw: dto.categoryRaw,
            symptomName: dto.symptomName,
            severityRaw: dto.severityRaw,
            note: dto.note,
            photoData: try mediaData(
                reference: dto.photoRef,
                legacyBase64: dto.photoBase64,
                resolver: mediaResolver
            ),
            petId: dto.petId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeHeatCycleLogSnapshot(_ dto: HeatCycleLogBackup) -> DomainHeatCycleLogRehydrateSnapshot {
        DomainHeatCycleLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            statusRaw: dto.statusRaw,
            note: dto.note,
            isMated: dto.isMated,
            expectedDeliveryDate: parseDate(dto.expectedDeliveryDate),
            petId: dto.petId.flatMap(UUID.init(uuidString:))
        )
    }

    func decodeWishlistSnapshot(_ dto: WishlistItemBackup) -> DomainWishlistItemRehydrateSnapshot {
        DomainWishlistItemRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            title: dto.title,
            cost: dto.cost,
            creatorId: dto.creatorId,
            isRedeemed: dto.isRedeemed,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeCareLedgerEventSnapshot(_ dto: CareLedgerEventBackup) -> DomainCareLedgerRehydrateSnapshot {
        DomainCareLedgerRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            occurredAt: parseDate(dto.occurredAt) ?? Date(),
            actorKind: dto.actorKind,
            actorId: dto.actorId,
            subjectKind: dto.subjectKind,
            subjectId: dto.subjectId,
            eventKind: dto.eventKind,
            actionType: dto.actionType,
            amountValue: dto.amountValue,
            amountUnit: dto.amountUnit,
            note: dto.note,
            source: dto.source,
            sourceEventId: dto.sourceEventId,
            sourceReminderId: dto.sourceReminderId,
            legacyModelName: dto.legacyModelName,
            legacyModelId: dto.legacyModelId,
            coconutDelta: dto.coconutDelta,
            rewardLogId: dto.rewardLogId,
            privacyFieldRaw: dto.privacyFieldRaw,
            metadataJSON: dto.metadataJSON,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeCoconutAccountSnapshot(_ dto: CoconutAccountBackup) -> DomainCoconutAccountRehydrateSnapshot {
        DomainCoconutAccountRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            accountKey: dto.accountKey,
            ownerKindRaw: dto.ownerKindRaw,
            ownerId: dto.ownerId,
            displayName: dto.displayName,
            balance: dto.balance,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            updatedAt: parseDate(dto.updatedAt) ?? Date(),
            metadataJSON: dto.metadataJSON
        )
    }

    func decodeCoconutLedgerEntrySnapshot(_ dto: CoconutLedgerEntryBackup) -> DomainCoconutLedgerEntryRehydrateSnapshot {
        DomainCoconutLedgerEntryRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            transactionKey: dto.transactionKey,
            accountKey: dto.accountKey,
            ownerKindRaw: dto.ownerKindRaw,
            ownerId: dto.ownerId,
            ownerName: dto.ownerName,
            delta: dto.delta,
            balanceBefore: dto.balanceBefore,
            balanceAfter: dto.balanceAfter,
            affectsBalance: dto.affectsBalance,
            entryKindRaw: dto.entryKindRaw,
            sourceRaw: dto.sourceRaw,
            title: dto.title,
            emoji: dto.emoji,
            actorId: dto.actorId,
            actorName: dto.actorName,
            subjectKindRaw: dto.subjectKindRaw,
            subjectId: dto.subjectId,
            sourceModelName: dto.sourceModelName,
            sourceModelId: dto.sourceModelId,
            careLedgerEventId: dto.careLedgerEventId,
            metadataJSON: dto.metadataJSON,
            occurredAt: parseDate(dto.occurredAt) ?? Date(),
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
    }

    func decodeFamilyCollaborationTaskSnapshot(_ dto: FamilyCollaborationTaskBackup) -> DomainFamilyCollaborationTaskRehydrateSnapshot {
        DomainFamilyCollaborationTaskRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            title: dto.title,
            note: dto.note,
            kindRaw: dto.kindRaw,
            statusRaw: dto.statusRaw,
            relatedPetId: dto.relatedPetId,
            relatedEventId: dto.relatedEventId,
            relatedReminderId: dto.relatedReminderId,
            createdById: dto.createdById,
            createdByName: dto.createdByName,
            assignedToId: dto.assignedToId,
            assignedToName: dto.assignedToName,
            claimedById: dto.claimedById,
            claimedByName: dto.claimedByName,
            completedById: dto.completedById,
            completedByName: dto.completedByName,
            rewardCoconuts: dto.rewardCoconuts,
            dueAt: parseDate(dto.dueAt),
            completedAt: parseDate(dto.completedAt),
            createdAt: parseDate(dto.createdAt) ?? Date(),
            updatedAt: parseDate(dto.updatedAt) ?? parseDate(dto.createdAt) ?? Date(),
            emoji: dto.emoji
        )
    }

    func decodeCoconutExchangeRequestSnapshot(_ dto: CoconutExchangeRequestBackup) -> DomainCoconutExchangeRequestRehydrateSnapshot {
        DomainCoconutExchangeRequestRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            senderId: dto.senderId,
            senderName: dto.senderName,
            receiverId: dto.receiverId,
            receiverName: dto.receiverName,
            coconutCost: dto.coconutCost,
            currencyCode: dto.currencyCode,
            localAmount: dto.localAmount,
            statusRaw: dto.statusRaw,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            confirmedAt: parseDate(dto.confirmedAt),
            cancelledAt: parseDate(dto.cancelledAt),
            updatedAt: parseDate(dto.updatedAt) ?? Date(),
            note: dto.note
        )
    }

    func decodeOasisUpgradeCoconutSnapshot(_ dto: OasisUpgradeCoconutBackup) -> DomainOasisUpgradeCoconutRehydrateSnapshot {
        DomainOasisUpgradeCoconutRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            level: dto.level,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            openedAt: parseDate(dto.openedAt),
            rewardKindRaw: dto.rewardKindRaw,
            rewardCatalogId: dto.rewardCatalogId,
            guaranteedCritterId: dto.guaranteedCritterId,
            coconutAmount: dto.coconutAmount,
            treeEnergyAmount: dto.treeEnergyAmount,
            fragmentAmount: dto.fragmentAmount,
            decorUnlockId: dto.decorUnlockId,
            storyStyleUnlockId: dto.storyStyleUnlockId,
            temporaryEffectId: dto.temporaryEffectId,
            titleZh: dto.titleZh,
            titleEn: dto.titleEn,
            titleDe: dto.titleDe,
            descriptionZh: dto.descriptionZh,
            descriptionEn: dto.descriptionEn,
            descriptionDe: dto.descriptionDe
        )
    }

    func decodeOasisElectronicPetSnapshot(_ dto: OasisElectronicPetBackup) -> DomainOasisElectronicPetRehydrateSnapshot {
        DomainOasisElectronicPetRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            catalogId: dto.catalogId,
            nameZh: dto.nameZh,
            nameEn: dto.nameEn,
            nameDe: dto.nameDe,
            emoji: dto.emoji,
            rarityRaw: dto.rarityRaw,
            nickname: dto.nickname,
            level: dto.level,
            starLevel: dto.starLevel,
            xp: dto.xp,
            hunger: dto.hunger,
            mood: dto.mood,
            health: dto.health ?? 100,
            bond: dto.bond,
            appearanceStage: dto.appearanceStage,
            isFeaturedOnOasis: dto.isFeaturedOnOasis ?? false,
            habitatSlot: dto.habitatSlot ?? 0,
            equippedDecorId: dto.equippedDecorId ?? "",
            favoriteItemId: dto.favoriteItemId ?? "",
            personalityRaw: dto.personalityRaw ?? "gentle",
            featuredPoseRaw: dto.featuredPoseRaw ?? "idle",
            sourceLevel: dto.sourceLevel,
            obtainedAt: parseDate(dto.obtainedAt) ?? Date(),
            lastInteractionAt: parseDate(dto.lastInteractionAt) ?? Date(),
            lastStateRefreshAt: parseDate(dto.lastStateRefreshAt) ?? parseDate(dto.lastInteractionAt) ?? Date(),
            lifeStateRaw: dto.lifeStateRaw ?? OasisCritterLifeState.healthy.rawValue,
            deathReasonRaw: dto.deathReasonRaw ?? "",
            riskStartedAt: parseDate(dto.riskStartedAt),
            criticalStartedAt: parseDate(dto.criticalStartedAt),
            diedAt: parseDate(dto.diedAt),
            lastGentlePromptAt: parseDate(dto.lastGentlePromptAt),
            isArchived: dto.isArchived
        )
    }

    func decodeOasisCritterFragmentSnapshot(_ dto: OasisCritterFragmentBackup) -> DomainOasisCritterFragmentRehydrateSnapshot {
        DomainOasisCritterFragmentRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            catalogId: dto.catalogId,
            amount: dto.amount,
            updatedAt: parseDate(dto.updatedAt) ?? Date()
        )
    }

    func decodeOasisUnlockSnapshot(_ dto: OasisUnlockBackup) -> DomainOasisUnlockRehydrateSnapshot {
        DomainOasisUnlockRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            unlockId: dto.unlockId,
            unlockKindRaw: dto.unlockKindRaw,
            sourceLevel: dto.sourceLevel,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            metadataJSON: dto.metadataJSON
        )
    }

    func decodeOasisCritterActionLogSnapshot(_ dto: OasisCritterActionLogBackup) -> DomainOasisCritterActionLogRehydrateSnapshot {
        DomainOasisCritterActionLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            critterId: dto.critterId.flatMap(UUID.init(uuidString:)),
            critterCatalogId: dto.critterCatalogId,
            actionRaw: dto.actionRaw,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            coconutDelta: dto.coconutDelta,
            fragmentDelta: dto.fragmentDelta,
            xpDelta: dto.xpDelta,
            sourceLevel: dto.sourceLevel,
            noteZh: dto.noteZh,
            noteEn: dto.noteEn,
            noteDe: dto.noteDe
        )
    }

    func decodeGachaOwnedItemSnapshot(_ dto: GachaOwnedItemBackup) -> DomainGachaOwnedItemRehydrateSnapshot {
        DomainGachaOwnedItemRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            ownerHumanId: dto.ownerHumanId,
            seriesId: dto.seriesId,
            itemId: dto.itemId,
            rarityRaw: dto.rarityRaw,
            isHidden: dto.isHidden,
            ownedCount: dto.ownedCount,
            firstObtainedAt: parseDate(dto.firstObtainedAt) ?? Date(),
            latestObtainedAt: parseDate(dto.latestObtainedAt) ?? Date(),
            createdAt: parseDate(dto.createdAt) ?? parseDate(dto.firstObtainedAt) ?? Date()
        )
    }

    func decodeGachaDrawLogSnapshot(_ dto: GachaDrawLogBackup) -> DomainGachaDrawLogRehydrateSnapshot {
        DomainGachaDrawLogRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            ownerHumanId: dto.ownerHumanId,
            ownerName: dto.ownerName,
            seriesId: dto.seriesId,
            itemId: dto.itemId,
            rarityRaw: dto.rarityRaw,
            isHidden: dto.isHidden,
            isNew: dto.isNew,
            outcomeKindRaw: dto.outcomeKindRaw ?? GachaOutcomeKind.collectible.rawValue,
            instantResultId: dto.instantResultId ?? "",
            instantTitleZh: dto.instantTitleZh ?? "",
            instantTitleEn: dto.instantTitleEn ?? "",
            instantTitleDe: dto.instantTitleDe ?? "",
            instantDetailZh: dto.instantDetailZh ?? "",
            instantDetailEn: dto.instantDetailEn ?? "",
            instantDetailDe: dto.instantDetailDe ?? "",
            instantSymbol: dto.instantSymbol ?? "",
            instantCoconutDelta: dto.instantCoconutDelta ?? 0,
            costCoconuts: dto.costCoconuts,
            dailySequence: dto.dailySequence,
            drawDate: parseDate(dto.drawDate) ?? Date(),
            createdAt: parseDate(dto.createdAt) ?? parseDate(dto.drawDate) ?? Date()
        )
    }

    func decodeShopPurchaseRecordSnapshot(_ dto: ShopPurchaseRecordBackup) -> DomainShopPurchaseRecordRehydrateSnapshot {
        DomainShopPurchaseRecordRehydrateSnapshot(
            id: UUID(uuidString: dto.id) ?? UUID(),
            transactionKey: dto.transactionKey,
            itemId: dto.itemId,
            buyerHumanId: dto.buyerHumanId,
            purchasedAt: parseDate(dto.purchasedAt) ?? Date(),
            sourceRaw: dto.sourceRaw,
            isLegacyImport: dto.isLegacyImport,
            createdAt: parseDate(dto.createdAt) ?? parseDate(dto.purchasedAt) ?? Date()
        )
    }

    private func mediaData(
        reference: BackupMediaReference?,
        legacyBase64: String?,
        resolver: DataBackupMediaResolving?
    ) throws -> Data? {
        if let reference {
            guard let resolver else {
                throw BackupError.invalidBackupPackage
            }
            return try resolver.data(for: reference)
        }
        return legacyBase64.flatMap { Data(base64Encoded: $0) }
    }
}

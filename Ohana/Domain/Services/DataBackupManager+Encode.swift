//
//  DataBackupManager+Encode.swift
//  Ohana
//

import Foundation
import SwiftData

nonisolated extension DataBackupManager {
    // MARK: - Encode helpers

    func d(_ date: Date?) -> String? { date.map { iso.string(from: $0) } }
    func d(_ date: Date) -> String { iso.string(from: date) }
    func nilIfEmpty(_ value: String) -> String? { value.isEmpty ? nil : value }

    func encodePet(_ p: Pet, mediaWriter: DataBackupMediaWriting? = nil) throws -> PetBackup {
        let avatarImageRef = try mediaWriter?.write(
            p.avatarImageData,
            purpose: .petAvatar,
            id: p.id.uuidString
        )
        let cardPopoutImageRef = try mediaWriter?.write(
            p.cardPopoutImageData,
            purpose: .petCardPopout,
            id: p.id.uuidString
        )
        return PetBackup(
            id: p.id.uuidString, name: p.name, species: p.species, breed: p.breed,
            birthday: d(p.birthday), gender: p.gender, isNeutered: p.isNeutered,
            avatarEmoji: p.avatarEmoji, microchipID: p.microchipID, vetContact: p.vetContact,
            allergies: p.allergies, passportNumber: p.passportNumber,
            passportExpiryDate: d(p.passportExpiryDate), formerName: p.formerName,
            lineageInfo: p.lineageInfo, themeColorHex: p.themeColorHex,
            homeDate: d(p.homeDate), birthCountry: p.birthCountry, birthCity: p.birthCity,
            foodBrand: p.foodBrand, restockDate: d(p.restockDate),
            restockWeight: p.restockWeight, dailyPortionGrams: p.dailyPortionGrams,
            mainFoodKindRaw: p.mainFoodKindRaw,
            foodPrice: p.foodPrice, isShared: p.isShared,
            createdAt: d(p.createdAt), notes: p.notes, coatColor: p.coatColor,
            eyeColor: p.eyeColor, currentStreak: p.currentStreak,
            lastCheckInDate: d(p.lastCheckInDate),
            foodTrackingModeRaw: p.foodTrackingModeRaw, casualOpenDate: d(p.casualOpenDate),
            casualDurationDays: p.casualDurationDays,
            foodReminderEnabled: p.foodReminderEnabled,
            foodReminderAdvanceDays: p.foodReminderAdvanceDays,
            coconutBalance: p.coconutBalance,
            passedAwayDate: d(p.passedAwayDate),
            cardStyleRaw: p.cardStyleRaw.isEmpty ? nil : p.cardStyleRaw,
            avatarImageBase64: avatarImageRef == nil ? p.avatarImageData?.base64EncodedString() : nil,
            avatarImageRef: avatarImageRef,
            cardPopoutImageBase64: cardPopoutImageRef == nil ? p.cardPopoutImageData?.base64EncodedString() : nil,
            cardPopoutImageRef: cardPopoutImageRef,
            cardPopoutSourceRaw: (p.cardPopoutSourceRaw ?? "").isEmpty ? nil : p.cardPopoutSourceRaw,
            personalityTagsRaw: p.personalityTagsRaw.isEmpty ? nil : p.personalityTagsRaw
        )
    }

    func encodeHuman(
        _ h: Human,
        mediaWriter: DataBackupMediaWriting? = nil,
        redactingHealthData: Bool = false
    ) throws -> HumanBackup {
        let avatarImageRef = try mediaWriter?.write(
            h.avatarImageData,
            purpose: .humanAvatar,
            id: h.id.uuidString
        )
        return HumanBackup(
            id: h.id.uuidString, name: h.name, birthday: d(h.birthday),
            bloodType: redactingHealthData ? "" : h.bloodType,
            avatarEmoji: h.avatarEmoji,
            role: h.role,
            appleUserIdentifier: nil,
            genderIdentityRaw: HumanProfileOptions.storedGenderIdentity(raw: h.genderIdentityRaw, notes: h.notes),
            notes: redactingHealthData ? "" : HumanProfileOptions.visibleNoteParts(from: h.notes).joined(separator: "｜"),
            createdAt: d(h.createdAt), nationality: h.nationality, city: h.city,
            coconutBalance: h.coconutBalance, shouldShowOnHome: h.shouldShowOnHome,
            mbti: h.mbti.isEmpty ? nil : h.mbti,
            privateFieldsRaw: redactingHealthData || h.privateFieldsRaw.isEmpty ? nil : h.privateFieldsRaw,
            themeColorHex: h.themeColorHex,
            heightCm: redactingHealthData ? nil : h.heightCm,
            avatarImageBase64: avatarImageRef == nil ? h.avatarImageData?.base64EncodedString() : nil,
            avatarImageRef: avatarImageRef,
            // Memorial lifecycle is not human-health data and must survive a
            // restricted backup/restore even while health fields are omitted.
            passedAwayDate: d(h.passedAwayDate)
        )
    }

    func encodeEvent(_ e: Event) -> EventBackup {
        EventBackup(
            id: e.id.uuidString, title: e.title, startDate: d(e.startDate),
            endDate: d(e.endDate), isAllDay: e.isAllDay, eventType: e.eventType,
            relatedEntityId: e.relatedEntityId, relatedEntityType: e.relatedEntityType,
            recurrenceDays: e.recurrenceDays, recurrenceEndDate: d(e.recurrenceEndDate),
            isCompleted: e.isCompleted, createdAt: d(e.createdAt),
            completedOccurrences: e.completedOccurrences,
            assigneeId: e.assigneeId,
            feedRuleKindRaw: e.feedRuleKindRaw.isEmpty ? nil : e.feedRuleKindRaw,
            foodKindRaw: e.foodKindRaw,
            feedAmountGrams: e.feedAmountGrams,
            feedPlanGroupId: e.feedPlanGroupId.isEmpty ? nil : e.feedPlanGroupId
        )
    }

    func encodeReminder(_ r: Reminder) -> ReminderBackup {
        ReminderBackup(
            id: r.id.uuidString, scheduledAt: d(r.scheduledAt),
            status: r.status, notificationId: r.notificationId,
            eventId: r.event?.id.uuidString,
            completedAt: d(r.completedAt),
            completedBy: r.completedBy.isEmpty ? nil : r.completedBy,
            createdAt: iso.string(from: r.createdAt)
        )
    }

    func encodeHousehold(_ h: Household) -> HouseholdBackup {
        HouseholdBackup(id: h.id.uuidString, name: h.name,
                        createdAt: d(h.createdAt), totalProsperity: h.totalProsperity)
    }

    func encodePlant(_ p: Plant, mediaWriter: DataBackupMediaWriting? = nil) throws -> PlantBackup {
        let avatarImageRef = try mediaWriter?.write(
            p.avatarImageData,
            purpose: .plantAvatar,
            id: p.id.uuidString
        )
        return PlantBackup(
            id: p.id.uuidString, name: p.name, species: p.species, avatarEmoji: p.avatarEmoji,
            location: p.location, notes: p.notes, createdAt: d(p.createdAt),
            lastWateredDate: d(p.lastWateredDate), wateringIntervalDays: p.wateringIntervalDays,
            lastFertilizedDate: d(p.lastFertilizedDate), fertilizingIntervalDays: p.fertilizingIntervalDays,
            themeColorHex: p.themeColorHex,
            lastHealthCheckDate: d(p.lastHealthCheckDate),
            roomNameRaw: p.roomNameRaw,
            potDiameterCm: p.potDiameterCm,
            potMaterialRaw: p.potMaterialRaw,
            soilTypeRaw: p.soilTypeRaw,
            isIndoor: p.isIndoor,
            windowDirectionRaw: p.windowDirectionRaw,
            lightLevelRaw: p.lightLevelRaw,
            lastLightMeasurementLux: p.lastLightMeasurementLux,
            lastLightMeasurementDate: d(p.lastLightMeasurementDate),
            humidityPreferenceRaw: p.humidityPreferenceRaw,
            temperaturePreferenceRaw: p.temperaturePreferenceRaw,
            isNearClimateSource: p.isNearClimateSource,
            potHasDrainage: p.potHasDrainage,
            acquiredDate: d(p.acquiredDate),
            acquisitionSourceRaw: p.acquisitionSourceRaw,
            currentHeightCm: p.currentHeightCm,
            currentSpreadCm: p.currentSpreadCm,
            isHydroponic: p.isHydroponic,
            isSucculent: p.isSucculent,
            healthStatusRaw: p.healthStatusRaw,
            catalogSpeciesId: p.catalogSpeciesId,
            isToxicToCats: p.isToxicToCats,
            isToxicToDogs: p.isToxicToDogs,
            isToxicToChildren: p.isToxicToChildren,
            isIndoorSuitable: p.isIndoorSuitable,
            remindersEnabled: p.remindersEnabled,
            archivedAt: d(p.archivedAt),
            avatarImageBase64: avatarImageRef == nil ? p.avatarImageData?.base64EncodedString() : nil,
            avatarImageRef: avatarImageRef
        )
    }

    func encodePlantCareLog(_ l: PlantCareLog, mediaWriter: DataBackupMediaWriting? = nil) throws -> PlantCareLogBackup {
        let photoRef = try mediaWriter?.write(
            l.photoData,
            purpose: .plantCarePhoto,
            id: l.id.uuidString
        )
        return PlantCareLogBackup(
            id: l.id.uuidString,
            date: d(l.date),
            careTypeRaw: l.careTypeRaw,
            note: l.note,
            executorId: l.executorId,
            plantId: l.plant?.id.uuidString,
            healthStatusRaw: l.healthStatusRaw.isEmpty ? nil : l.healthStatusRaw,
            photoBase64: photoRef == nil ? l.photoData?.base64EncodedString() : nil,
            photoRef: photoRef
        )
    }

    func encodePetRelationship(_ relationship: PetRelationship) -> PetRelationshipBackup {
        PetRelationshipBackup(
            id: relationship.id.uuidString,
            fromPetId: relationship.fromPetId.uuidString,
            toPetId: relationship.toPetId.uuidString,
            relationshipTypeRaw: relationship.relationshipTypeRaw,
            note: relationship.note,
            createdAt: d(relationship.createdAt)
        )
    }

    func encodeCareLog(_ l: PetCareLog) -> PetCareLogBackup {
        PetCareLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
                         amountGrams: l.amountGrams, amountMl: l.amountMl, note: l.note,
                         foodKindRaw: l.foodKindRaw, treatKindRaw: l.treatKindRaw,
                         sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId,
                         executorId: l.executorId, petId: l.pet?.id.uuidString)
    }

    func encodePottyLog(_ l: PetPottyLog) -> PetPottyLogBackup {
        PetPottyLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
                          executorId: l.executorId, petId: l.pet?.id.uuidString,
                          latitude: l.latitude, longitude: l.longitude,
                          locationAccuracyMeters: l.locationAccuracyMeters, walkLogId: l.walkLogId,
                          sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId)
    }

    func encodeSharedCareSession(_ session: SharedCareSession) -> SharedCareSessionBackup {
        SharedCareSessionBackup(
            id: session.id.uuidString,
            date: d(session.date),
            actionKindRaw: session.actionKindRaw,
            executorId: session.executorId,
            executorIdsRaw: nilIfEmpty(SharedCareParticipantIDs.encode(session.executorIds)),
            sourcePetId: session.sourcePetId,
            targetPetIdsRaw: session.targetPetIdsRaw,
            speciesRaw: session.speciesRaw,
            totalAmountGrams: session.totalAmountGrams,
            totalAmountMl: session.totalAmountMl,
            totalExpenseAmount: session.totalExpenseAmount,
            expenseCategoryRaw: session.expenseCategoryRaw,
            currencyCode: session.currencyCode.isEmpty ? nil : session.currencyCode,
            allocationModeRaw: session.allocationModeRaw,
            foodKindRaw: session.foodKindRaw,
            stockOwnerPetId: session.stockOwnerPetId,
            primaryLegacyModelName: session.primaryLegacyModelName.isEmpty ? nil : session.primaryLegacyModelName,
            primaryLegacyModelId: session.primaryLegacyModelId.isEmpty ? nil : session.primaryLegacyModelId,
            note: session.note,
            createdAt: d(session.createdAt)
        )
    }

    func encodeWalkLog(_ l: PetWalkLog, mediaWriter: DataBackupMediaWriting? = nil) throws -> PetWalkLogBackup {
        let mapSnapshotRef = try mediaWriter?.write(
            l.mapSnapshotData,
            purpose: .petWalkMapSnapshot,
            id: l.id.uuidString
        )
        let routeLocationsRef = try mediaWriter?.write(
            l.routeLocationsData,
            purpose: .petWalkRouteLocations,
            id: l.id.uuidString
        )
        return PetWalkLogBackup(id: l.id.uuidString, startDate: d(l.startDate),
                                endDate: d(l.endDate), distanceMeters: l.distanceMeters,
                                coconutsEarned: l.coconutsEarned,
                                executorId: l.executorId,
                                executorIdsRaw: nilIfEmpty(SharedCareParticipantIDs.encode(l.executorIds)),
                                petId: l.pet?.id.uuidString,
                                sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId,
                                behaviorNotes: l.behaviorNotes,
                                moodRating: l.moodRating,
                                mapSnapshotBase64: mapSnapshotRef == nil ? l.mapSnapshotData?.base64EncodedString() : nil,
                                mapSnapshotRef: mapSnapshotRef,
                                routeLocationsBase64: routeLocationsRef == nil ? l.routeLocationsData?.base64EncodedString() : nil,
                                routeLocationsRef: routeLocationsRef)
    }

    func encodeWeightLog(_ l: PetWeightLog) -> PetWeightLogBackup {
        PetWeightLogBackup(id: l.id.uuidString, date: d(l.date),
                           weight: l.weight, petId: l.pet?.id.uuidString,
                           executorId: l.executorId)
    }

    func encodeExpenseLog(_ l: PetExpenseLog) -> PetExpenseLogBackup {
        PetExpenseLogBackup(id: l.id.uuidString, date: d(l.date),
                            amount: l.amount, category: l.category, note: l.note,
                            petId: l.pet?.id.uuidString,
                            executorId: l.executorId,
                            sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId)
    }

    func encodeHealthLog(_ l: PetHealthLog) -> PetHealthLogBackup {
        PetHealthLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
                           note: l.note, expirationDate: d(l.expirationDate), vetName: l.vetName,
                           cost: l.cost, petId: l.pet?.id.uuidString,
                           executorId: l.executorId)
    }

    func encodeHygieneLog(_ l: PetHygieneLog) -> PetHygieneLogBackup {
        PetHygieneLogBackup(id: l.id.uuidString, date: d(l.date), type: l.type,
                            petId: l.pet?.id.uuidString,
                            executorId: l.executorId,
                            sharedSessionId: l.sharedSessionId.isEmpty ? nil : l.sharedSessionId)
    }

    func encodeFoodRecord(_ r: PetFoodRecord) -> PetFoodRecordBackup {
        PetFoodRecordBackup(id: r.id.uuidString, date: d(r.startDate), brand: r.brand,
                            dailyGrams: r.dailyGrams, totalGrams: r.totalGrams, foodKindRaw: r.foodKindRaw,
                            petId: r.pet?.id.uuidString,
                            purchaseDate: d(r.purchaseDate),
                            remainingCorrectionGrams: r.remainingCorrectionGrams,
                            remainingCorrectionDate: d(r.remainingCorrectionDate),
                            notes: r.notes, executorId: r.executorId)
    }

    func encodeDocument(_ doc: PetDocument, mediaWriter: DataBackupMediaWriting? = nil) throws -> PetDocumentBackup {
        let attachmentRef = try mediaWriter?.write(
            doc.attachmentData,
            purpose: .petDocumentAttachment,
            id: doc.id.uuidString
        )
        return PetDocumentBackup(id: doc.id.uuidString, title: doc.title, categoryRaw: doc.category,
                                 expiryDate: d(doc.expiryDate), petId: doc.pet?.id.uuidString,
                                 issueDate: d(doc.issueDate),
                                 issuingAuthority: doc.issuingAuthority,
                                 notes: doc.notes,
                                 reminderDate: d(doc.reminderDate),
                                 cost: doc.cost,
                                 attachmentBase64: attachmentRef == nil ? doc.attachmentData?.base64EncodedString() : nil,
                                 attachmentRef: attachmentRef,
                                 attachmentFilename: doc.attachmentFilename.isEmpty ? nil : doc.attachmentFilename)
    }

    func encodeDocumentAttachments(_ doc: PetDocument, mediaWriter: DataBackupMediaWriting? = nil) throws -> [PetDocumentAttachmentBackup] {
        try doc.attachments.map {
            let dataRef = try mediaWriter?.write(
                $0.data,
                purpose: .petDocumentAttachmentFile,
                id: $0.id.uuidString
            )
            return PetDocumentAttachmentBackup(
                id: $0.id.uuidString,
                documentId: doc.id.uuidString,
                dataBase64: dataRef == nil ? $0.data.base64EncodedString() : nil,
                dataRef: dataRef,
                filename: $0.filename,
                isImage: $0.isImage
            )
        }
    }

    func encodeMilestone(_ m: PetMilestone, mediaWriter: DataBackupMediaWriting? = nil) throws -> PetMilestoneBackup {
        let photoRef = try mediaWriter?.write(
            m.photoData,
            purpose: .petMilestonePhoto,
            id: m.id.uuidString
        )
        return PetMilestoneBackup(id: m.id.uuidString, date: d(m.date), title: m.title,
                                  emoji: m.emoji, notes: m.notes, petId: m.pet?.id.uuidString,
                                  photoBase64: photoRef == nil ? m.photoData?.base64EncodedString() : nil,
                                  photoRef: photoRef,
                                  location: m.location.isEmpty ? nil : m.location)
    }

    func encodeHumanWeight(_ l: HumanWeightLog) -> HumanWeightLogBackup {
        HumanWeightLogBackup(id: l.id.uuidString, date: d(l.date),
                             weight: l.weight, humanId: l.human?.id.uuidString,
                             executorId: l.executorId)
    }

    func encodeHumanWorkout(_ l: HumanWorkoutLog) -> HumanWorkoutLogBackup {
        HumanWorkoutLogBackup(id: l.id.uuidString, date: d(l.date), typeRaw: l.typeRaw,
                              durationMinutes: l.durationMinutes, distanceKm: l.distanceKm,
                              calories: l.calories, steps: l.steps, notes: l.notes,
                              sourceHealthKit: l.sourceHealthKit,
                              healthKitWorkoutUUID: l.healthKitWorkoutUUID,
                              healthKitSourceBundleID: l.healthKitSourceBundleID,
                              healthKitSourceName: l.healthKitSourceName,
                              sourcePetWalkLogID: l.sourcePetWalkLogID,
                              humanId: l.human?.id.uuidString)
    }

    func encodeWaterLog(_ l: WaterLog) -> WaterLogBackup {
        WaterLogBackup(id: l.id.uuidString, date: d(l.date),
                       amountMl: l.amountMl, note: l.note)
    }

    func encodePhotoLog(_ l: PetPhotoLog, mediaWriter: DataBackupMediaWriting? = nil) throws -> PetPhotoLogBackup {
        let imageRef = try mediaWriter?.write(
            l.imageData,
            purpose: .petPhoto,
            id: l.id.uuidString
        )
        return PetPhotoLogBackup(
            id: l.id.uuidString,
            date: d(l.date),
            note: l.note,
            createdAt: d(l.createdAt),
            imageBase64: imageRef == nil ? l.imageData.base64EncodedString() : nil,
            imageRef: imageRef,
            petId: l.pet?.id.uuidString,
            locationLatitude: l.locationLatitude,
            locationLongitude: l.locationLongitude,
            locationPlacename: l.locationPlacename
        )
    }

    func encodeInsurance(_ i: PetInsurance) -> PetInsuranceBackup {
        PetInsuranceBackup(
            id: i.id.uuidString,
            companyName: i.companyName,
            policyNumber: i.policyNumber,
            productName: i.productName,
            annualPremium: i.annualPremium,
            coverageAmount: i.coverageAmount,
            startDate: d(i.startDate),
            renewalDate: d(i.renewalDate),
            notes: i.notes,
            isActive: i.isActive,
            createdAt: d(i.createdAt),
            paymentFrequencyRaw: i.paymentFrequencyRaw,
            paymentDayOfMonth: i.paymentDayOfMonth,
            showInCalendar: i.showInCalendar,
            otherFeeAmount: i.otherFeeAmount,
            otherFeeNote: i.otherFeeNote,
            firstPremiumPaymentDate: d(i.firstPremiumPaymentDate),
            petId: i.pet?.id.uuidString
        )
    }

    func encodeInsuranceClaim(_ c: InsuranceClaim) -> InsuranceClaimBackup {
        InsuranceClaimBackup(
            id: c.id.uuidString,
            insuranceId: c.insurance?.id.uuidString,
            claimDate: d(c.claimDate),
            incidentDate: d(c.incidentDate),
            totalExpense: c.totalExpense,
            claimedAmount: c.claimedAmount,
            approvedAmount: c.approvedAmount,
            statusRaw: c.statusRaw,
            note: c.note,
            relatedExpenseLogId: c.relatedExpenseLogId,
            approvedAt: d(c.approvedAt),
            createdAt: d(c.createdAt)
        )
    }

    func encodePetMedication(_ m: PetMedication) -> PetMedicationBackup {
        PetMedicationBackup(
            id: m.id.uuidString,
            name: m.name,
            dosage: m.dosage,
            frequencyRaw: m.frequencyRaw,
            customFrequencyNote: m.customFrequencyNote,
            startDate: d(m.startDate),
            endDate: d(m.endDate),
            colorHex: m.colorHex,
            notes: m.notes,
            isActive: m.isActive,
            remainingAmount: m.remainingAmount,
            createdAt: d(m.createdAt),
            petId: m.pet?.id.uuidString
        )
    }

    func encodeHumanMedication(_ m: HumanMedication) -> HumanMedicationBackup {
        HumanMedicationBackup(
            id: m.id.uuidString,
            humanId: m.humanId,
            name: m.name,
            dosage: m.dosage,
            frequencyRaw: m.frequencyRaw,
            customFrequencyNote: m.customFrequencyNote,
            firstDoseTime: d(m.firstDoseTime),
            startDate: d(m.startDate),
            endDate: d(m.endDate),
            colorHex: m.colorHex,
            notes: m.notes,
            isActive: m.isActive,
            createdAt: d(m.createdAt)
        )
    }

    func encodeHumanMedicationLog(_ l: HumanMedicationLog) -> HumanMedicationLogBackup {
        HumanMedicationLogBackup(
            id: l.id.uuidString,
            humanId: l.humanId,
            medicationId: l.medicationId,
            scheduledTime: d(l.scheduledTime),
            recordedTime: d(l.recordedTime),
            statusRaw: l.statusRaw,
            createdAt: d(l.createdAt)
        )
    }

    func encodeHumanHealthMetricLog(_ l: HumanHealthMetricLog) -> HumanHealthMetricLogBackup {
        HumanHealthMetricLogBackup(
            id: l.id.uuidString,
            metricKey: l.metricKey,
            unitCode: l.unitCode,
            value: l.value,
            date: d(l.date),
            notes: l.notes,
            humanId: l.human?.id.uuidString,
            createdAt: d(l.createdAt)
        )
    }

    func encodeHumanHealthReport(_ report: HumanHealthReport) -> HumanHealthReportBackup {
        HumanHealthReportBackup(
            id: report.id.uuidString,
            humanId: report.humanId,
            reportTypeRaw: report.reportTypeRaw,
            conclusionRaw: report.conclusionRaw,
            hospitalName: report.hospitalName,
            doctorName: report.doctorName,
            reportDate: d(report.reportDate),
            nextCheckDate: d(report.nextCheckDate),
            summary: report.summary,
            notes: report.notes,
            colorHex: report.colorHex,
            createdAt: d(report.createdAt)
        )
    }

    func encodeSymptomLog(_ l: SymptomLog, mediaWriter: DataBackupMediaWriting? = nil) throws -> SymptomLogBackup {
        let photoRef = try mediaWriter?.write(
            l.photoData,
            purpose: .symptomPhoto,
            id: l.id.uuidString
        )
        return SymptomLogBackup(
            id: l.id.uuidString,
            date: d(l.date),
            categoryRaw: l.categoryRaw,
            symptomName: l.symptomName,
            severityRaw: l.severityRaw,
            note: l.note,
            photoBase64: photoRef == nil ? l.photoData?.base64EncodedString() : nil,
            photoRef: photoRef,
            petId: l.pet?.id.uuidString
        )
    }

    func encodeHeatCycleLog(_ l: HeatCycleLog) -> HeatCycleLogBackup {
        HeatCycleLogBackup(
            id: l.id.uuidString,
            startDate: d(l.startDate),
            endDate: d(l.endDate),
            statusRaw: l.statusRaw,
            note: l.note,
            isMated: l.isMated,
            expectedDeliveryDate: d(l.expectedDeliveryDate),
            petId: l.pet?.id.uuidString
        )
    }

    func encodeWishlist(_ w: WishlistItem) -> WishlistItemBackup {
        WishlistItemBackup(id: w.id.uuidString, title: w.title, cost: w.cost,
                           creatorId: w.creatorId, isRedeemed: w.isRedeemed, createdAt: d(w.createdAt))
    }

    func encodeCareLedgerEvent(_ e: CareLedgerEvent) -> CareLedgerEventBackup {
        CareLedgerEventBackup(
            id: e.id.uuidString,
            occurredAt: d(e.occurredAt),
            actorKind: e.actorKind,
            actorId: e.actorId,
            subjectKind: e.subjectKind,
            subjectId: e.subjectId,
            eventKind: e.eventKind,
            actionType: e.actionType,
            amountValue: e.amountValue,
            amountUnit: e.amountUnit,
            note: e.note,
            source: e.source,
            sourceEventId: e.sourceEventId,
            sourceReminderId: e.sourceReminderId,
            legacyModelName: e.legacyModelName,
            legacyModelId: e.legacyModelId,
            coconutDelta: e.coconutDelta,
            rewardLogId: e.rewardLogId,
            privacyFieldRaw: e.privacyFieldRaw,
            metadataJSON: e.metadataJSON,
            createdAt: d(e.createdAt)
        )
    }

    func encodeCoconutAccount(_ account: CoconutAccount) -> CoconutAccountBackup {
        CoconutAccountBackup(
            id: account.id.uuidString,
            accountKey: account.accountKey,
            ownerKindRaw: account.ownerKindRaw,
            ownerId: account.ownerId,
            displayName: account.displayName,
            balance: account.balance,
            createdAt: d(account.createdAt),
            updatedAt: d(account.updatedAt),
            metadataJSON: account.metadataJSON
        )
    }

    func encodeCoconutLedgerEntry(_ entry: CoconutLedgerEntry) -> CoconutLedgerEntryBackup {
        CoconutLedgerEntryBackup(
            id: entry.id.uuidString,
            transactionKey: entry.transactionKey,
            accountKey: entry.accountKey,
            ownerKindRaw: entry.ownerKindRaw,
            ownerId: entry.ownerId,
            ownerName: entry.ownerName,
            delta: entry.delta,
            balanceBefore: entry.balanceBefore,
            balanceAfter: entry.balanceAfter,
            affectsBalance: entry.affectsBalance,
            entryKindRaw: entry.entryKindRaw,
            sourceRaw: entry.sourceRaw,
            title: entry.title,
            emoji: entry.emoji,
            actorId: entry.actorId,
            actorName: entry.actorName,
            subjectKindRaw: entry.subjectKindRaw,
            subjectId: entry.subjectId,
            sourceModelName: entry.sourceModelName,
            sourceModelId: entry.sourceModelId,
            careLedgerEventId: entry.careLedgerEventId,
            metadataJSON: entry.metadataJSON,
            occurredAt: d(entry.occurredAt),
            createdAt: d(entry.createdAt)
        )
    }

    func encodeEconomyBudgetUsageEvent(_ event: EconomyBudgetUsageEvent) -> EconomyBudgetUsageEventBackup {
        EconomyBudgetUsageEventBackup(
            id: event.id.uuidString,
            dayKey: event.dayKey,
            householdKey: event.householdKey,
            memberKey: event.memberKey,
            careObjectKey: event.careObjectKey,
            scopeRaw: event.scopeRaw,
            scopeKey: event.scopeKey,
            growthXPUsed: event.growthXPUsed,
            coconutUsed: event.coconutUsed,
            luckyCoconutUsed: event.luckyCoconutUsed,
            actionKey: event.actionKey,
            source: event.source,
            metadataJSON: event.metadataJSON,
            occurredAt: d(event.occurredAt),
            createdAt: d(event.createdAt)
        )
    }

    func encodeFamilyCollaborationTask(_ task: FamilyCollaborationTask) -> FamilyCollaborationTaskBackup {
        FamilyCollaborationTaskBackup(
            id: task.id.uuidString,
            title: task.title,
            note: task.note,
            kindRaw: task.kindRaw,
            statusRaw: task.statusRaw,
            relatedPetId: task.relatedPetId,
            relatedEventId: task.relatedEventId,
            relatedReminderId: task.relatedReminderId,
            createdById: task.createdById,
            createdByName: task.createdByName,
            assignedToId: task.assignedToId,
            assignedToName: task.assignedToName,
            claimedById: task.claimedById,
            claimedByName: task.claimedByName,
            completedById: task.completedById,
            completedByName: task.completedByName,
            rewardCoconuts: task.rewardCoconuts,
            dueAt: d(task.dueAt),
            completedAt: d(task.completedAt),
            createdAt: d(task.createdAt),
            updatedAt: d(task.updatedAt),
            emoji: task.emoji
        )
    }

    func encodeCoconutExchangeRequest(_ request: CoconutExchangeRequest) -> CoconutExchangeRequestBackup {
        CoconutExchangeRequestBackup(
            id: request.id.uuidString,
            senderId: request.senderId,
            senderName: request.senderName,
            receiverId: request.receiverId,
            receiverName: request.receiverName,
            coconutCost: request.coconutCost,
            currencyCode: request.currencyCode,
            localAmount: request.localAmount,
            statusRaw: request.statusRaw,
            createdAt: d(request.createdAt),
            confirmedAt: d(request.confirmedAt),
            cancelledAt: d(request.cancelledAt),
            updatedAt: d(request.updatedAt),
            note: request.note
        )
    }

    func encodeOasisUpgradeCoconut(_ coconut: OasisUpgradeCoconut) -> OasisUpgradeCoconutBackup {
        OasisUpgradeCoconutBackup(
            id: coconut.id.uuidString,
            level: coconut.level,
            createdAt: d(coconut.createdAt),
            openedAt: d(coconut.openedAt),
            rewardKindRaw: coconut.rewardKindRaw,
            rewardCatalogId: coconut.rewardCatalogId,
            guaranteedCritterId: coconut.guaranteedCritterId,
            coconutAmount: coconut.coconutAmount,
            treeEnergyAmount: coconut.treeEnergyAmount,
            fragmentAmount: coconut.fragmentAmount,
            decorUnlockId: coconut.decorUnlockId,
            storyStyleUnlockId: coconut.storyStyleUnlockId,
            temporaryEffectId: coconut.temporaryEffectId,
            titleZh: coconut.titleZh,
            titleEn: coconut.titleEn,
            titleDe: coconut.titleDe,
            descriptionZh: coconut.descriptionZh,
            descriptionEn: coconut.descriptionEn,
            descriptionDe: coconut.descriptionDe
        )
    }

    func encodeOasisElectronicPet(_ critter: OasisElectronicPet) -> OasisElectronicPetBackup {
        OasisElectronicPetBackup(
            id: critter.id.uuidString,
            catalogId: critter.catalogId,
            nameZh: critter.nameZh,
            nameEn: critter.nameEn,
            nameDe: critter.nameDe,
            emoji: critter.emoji,
            rarityRaw: critter.rarityRaw,
            nickname: critter.nickname,
            level: critter.level,
            starLevel: critter.starLevel,
            xp: critter.xp,
            hunger: critter.hunger,
            mood: critter.mood,
            health: critter.health,
            bond: critter.bond,
            appearanceStage: critter.appearanceStage,
            isFeaturedOnOasis: critter.isFeaturedOnOasis,
            habitatSlot: critter.habitatSlot,
            equippedDecorId: critter.equippedDecorId,
            favoriteItemId: critter.favoriteItemId,
            personalityRaw: critter.personalityRaw,
            featuredPoseRaw: critter.featuredPoseRaw,
            sourceLevel: critter.sourceLevel,
            obtainedAt: d(critter.obtainedAt),
            lastInteractionAt: d(critter.lastInteractionAt),
            lastStateRefreshAt: iso.string(from: critter.lastStateRefreshAt),
            lifeStateRaw: critter.lifeStateRaw,
            deathReasonRaw: critter.deathReasonRaw,
            riskStartedAt: d(critter.riskStartedAt),
            criticalStartedAt: d(critter.criticalStartedAt),
            diedAt: d(critter.diedAt),
            lastGentlePromptAt: d(critter.lastGentlePromptAt),
            isArchived: critter.isArchived
        )
    }

    func encodeOasisCritterFragment(_ fragment: OasisCritterFragmentBalance) -> OasisCritterFragmentBackup {
        OasisCritterFragmentBackup(
            id: fragment.id.uuidString,
            catalogId: fragment.catalogId,
            amount: fragment.amount,
            updatedAt: d(fragment.updatedAt)
        )
    }

    func encodeOasisUnlock(_ unlock: OasisUnlock) -> OasisUnlockBackup {
        OasisUnlockBackup(
            id: unlock.id.uuidString,
            unlockId: unlock.unlockId,
            unlockKindRaw: unlock.unlockKindRaw,
            sourceLevel: unlock.sourceLevel,
            createdAt: d(unlock.createdAt),
            metadataJSON: unlock.metadataJSON
        )
    }

    func encodeOasisCritterActionLog(_ log: OasisCritterActionLog) -> OasisCritterActionLogBackup {
        OasisCritterActionLogBackup(
            id: log.id.uuidString,
            critterId: log.critterId?.uuidString,
            critterCatalogId: log.critterCatalogId,
            actionRaw: log.actionRaw,
            createdAt: d(log.createdAt),
            coconutDelta: log.coconutDelta,
            fragmentDelta: log.fragmentDelta,
            xpDelta: log.xpDelta,
            sourceLevel: log.sourceLevel,
            noteZh: log.noteZh,
            noteEn: log.noteEn,
            noteDe: log.noteDe
        )
    }

    func encodeGachaOwnedItem(_ item: GachaOwnedItem) -> GachaOwnedItemBackup {
        GachaOwnedItemBackup(
            id: item.id.uuidString,
            ownerHumanId: item.ownerHumanId,
            seriesId: item.seriesId,
            itemId: item.itemId,
            rarityRaw: item.rarityRaw,
            isHidden: item.isHidden,
            ownedCount: item.ownedCount,
            firstObtainedAt: d(item.firstObtainedAt),
            latestObtainedAt: d(item.latestObtainedAt),
            createdAt: d(item.createdAt)
        )
    }

    func encodeGachaDrawLog(_ log: GachaDrawLog) -> GachaDrawLogBackup {
        GachaDrawLogBackup(
            id: log.id.uuidString,
            ownerHumanId: log.ownerHumanId,
            ownerName: log.ownerName,
            seriesId: log.seriesId,
            itemId: log.itemId,
            rarityRaw: log.rarityRaw,
            isHidden: log.isHidden,
            isNew: log.isNew,
            outcomeKindRaw: log.outcomeKindRaw,
            instantResultId: log.instantResultId,
            instantTitleZh: log.instantTitleZh,
            instantTitleEn: log.instantTitleEn,
            instantTitleDe: log.instantTitleDe,
            instantDetailZh: log.instantDetailZh,
            instantDetailEn: log.instantDetailEn,
            instantDetailDe: log.instantDetailDe,
            instantSymbol: log.instantSymbol,
            instantCoconutDelta: log.instantCoconutDelta,
            costCoconuts: log.costCoconuts,
            dailySequence: log.dailySequence,
            drawDate: d(log.drawDate),
            createdAt: d(log.createdAt)
        )
    }

    func encodeShopPurchaseRecord(_ record: ShopPurchaseRecord) -> ShopPurchaseRecordBackup {
        ShopPurchaseRecordBackup(
            id: record.id.uuidString,
            transactionKey: record.transactionKey,
            itemId: record.itemId,
            buyerHumanId: record.buyerHumanId,
            purchasedAt: d(record.purchasedAt),
            sourceRaw: record.sourceRaw,
            isLegacyImport: record.isLegacyImport,
            createdAt: d(record.createdAt)
        )
    }
}

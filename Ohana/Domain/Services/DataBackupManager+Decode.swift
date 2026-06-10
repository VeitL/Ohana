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

    func decodePet(_ dto: PetBackup) -> Pet {
        let p = Pet(name: dto.name, species: dto.species, breed: dto.breed,
                    birthday: parseDate(dto.birthday), gender: dto.gender,
                    isNeutered: dto.isNeutered)
        if let uuid = UUID(uuidString: dto.id) { p.id = uuid }
        p.avatarEmoji = dto.avatarEmoji
        p.microchipID = dto.microchipID
        p.vetContact = dto.vetContact
        p.allergies = dto.allergies
        p.passportNumber = dto.passportNumber
        p.passportExpiryDate = parseDate(dto.passportExpiryDate)
        p.formerName = dto.formerName
        p.lineageInfo = dto.lineageInfo
        p.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            dto.themeColorHex,
            fallback: OhanaThemeColorPolicy.petFallbackHex
        )
        p.homeDate = parseDate(dto.homeDate)
        p.birthCountry = dto.birthCountry
        p.birthCity = dto.birthCity
        p.foodBrand = dto.foodBrand
        p.restockDate = parseDate(dto.restockDate)
        p.restockWeight = dto.restockWeight
        p.dailyPortionGrams = dto.dailyPortionGrams
        p.mainFoodKindRaw = dto.mainFoodKindRaw ?? FeedFoodKind.dry.rawValue
        p.foodPrice = dto.foodPrice
        p.isShared = dto.isShared
        p.createdAt = parseDate(dto.createdAt) ?? Date()
        p.notes = dto.notes
        p.coatColor = dto.coatColor
        p.eyeColor = dto.eyeColor
        p.currentStreak = dto.currentStreak
        p.lastCheckInDate = parseDate(dto.lastCheckInDate)
        p.foodTrackingModeRaw = dto.foodTrackingModeRaw
        p.casualOpenDate = parseDate(dto.casualOpenDate)
        p.casualDurationDays = dto.casualDurationDays
        p.foodReminderEnabled = dto.foodReminderEnabled ?? false
        p.foodReminderAdvanceDays = dto.foodReminderAdvanceDays ?? 7
        p.coconutBalance = dto.coconutBalance
        p.passedAwayDate = parseDate(dto.passedAwayDate)
        p.cardStyleRaw = dto.cardStyleRaw ?? "classic"
        if let raw = dto.cardPopoutImageBase64, let data = Data(base64Encoded: raw) {
            p.cardPopoutImageData = data
        }
        p.cardPopoutSourceRaw = dto.cardPopoutSourceRaw
        p.personalityTagsRaw = dto.personalityTagsRaw ?? ""
        return p
    }

    func decodeHuman(_ dto: HumanBackup) -> Human {
        let h = Human(name: dto.name, birthday: parseDate(dto.birthday),
                      bloodType: dto.bloodType, avatarEmoji: dto.avatarEmoji,
                      role: dto.role, nationality: dto.nationality, city: dto.city)
        if let uuid = UUID(uuidString: dto.id) { h.id = uuid }
        h.appleUserIdentifier = dto.appleUserIdentifier
        h.notes = dto.notes
        h.createdAt = parseDate(dto.createdAt) ?? Date()
        h.coconutBalance = dto.coconutBalance
        h.shouldShowOnHome = dto.shouldShowOnHome
        h.mbti = dto.mbti ?? ""
        h.privateFieldsRaw = dto.privateFieldsRaw ?? ""
        h.themeColorHex = OhanaThemeColorPolicy.normalizedMemberThemeHex(
            dto.themeColorHex ?? "",
            fallback: OhanaThemeColorPolicy.humanFallbackHex
        )
        h.heightCm = dto.heightCm ?? 0
        h.avatarImageData = dto.avatarImageBase64.flatMap { Data(base64Encoded: $0) }
        h.passedAwayDate = parseDate(dto.passedAwayDate)
        return h
    }

    func decodeHousehold(_ dto: HouseholdBackup) -> Household {
        let h = Household(name: dto.name)
        if let uuid = UUID(uuidString: dto.id) { h.id = uuid }
        h.createdAt = parseDate(dto.createdAt) ?? Date()
        h.totalProsperity = dto.totalProsperity
        return h
    }

    func decodeEvent(_ dto: EventBackup) -> Event {
        let e = Event(
            title: dto.title,
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            isAllDay: dto.isAllDay,
            eventType: dto.eventType,
            relatedEntityType: dto.relatedEntityType,
            relatedEntityId: dto.relatedEntityId
        )
        if let uuid = UUID(uuidString: dto.id) { e.id = uuid }
        e.recurrenceDays = dto.recurrenceDays
        e.recurrenceEndDate = parseDate(dto.recurrenceEndDate)
        e.isCompleted = dto.isCompleted
        e.completedOccurrences = dto.completedOccurrences ?? []
        e.createdAt = parseDate(dto.createdAt) ?? Date()
        e.assigneeId = dto.assigneeId
        return e
    }

    func decodeReminder(_ dto: ReminderBackup, events: [String: Event]) -> Reminder {
        let r = Reminder(
            event: dto.eventId.flatMap { events[$0] },
            scheduledAt: parseDate(dto.scheduledAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { r.id = uuid }
        r.status = dto.status
        r.notificationId = dto.notificationId
        r.completedAt = parseDate(dto.completedAt)
        r.completedBy = dto.completedBy ?? ""
        r.createdAt = parseDate(dto.createdAt) ?? Date()
        return r
    }

    func decodeCareLog(_ dto: PetCareLogBackup, pets: [String: Pet]) -> PetCareLog {
        let l = PetCareLog(date: parseDate(dto.date) ?? Date(),
                           type: CareType(rawValue: dto.type) ?? .feeding,
                           amountGrams: dto.amountGrams, amountMl: dto.amountMl, note: dto.note,
                           foodKind: FeedFoodKind(rawValue: dto.foodKindRaw ?? "") ?? .dry,
                           treatKind: dto.treatKindRaw.flatMap(FeedTreatKind.init(rawValue:)),
                           sharedSessionId: dto.sharedSessionId ?? "",
                           pet: dto.petId.flatMap { pets[$0] },
                           executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodePottyLog(_ dto: PetPottyLogBackup, pets: [String: Pet]) -> PetPottyLog {
        let l = PetPottyLog(date: parseDate(dto.date) ?? Date(),
                            type: PottyType(rawValue: dto.type) ?? .perfectPoop,
                            pet: dto.petId.flatMap { pets[$0] },
                            executorId: dto.executorId,
                            latitude: dto.latitude,
                            longitude: dto.longitude,
                            locationAccuracyMeters: dto.locationAccuracyMeters,
                            walkLogId: dto.walkLogId,
                            sharedSessionId: dto.sharedSessionId ?? "")
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeSharedCareSession(_ dto: SharedCareSessionBackup) -> SharedCareSession {
        let session = SharedCareSession(
            date: parseDate(dto.date) ?? Date(),
            actionKind: SharedCareActionKind(rawValue: dto.actionKindRaw) ?? .feeding,
            executorId: dto.executorId,
            sourcePetId: dto.sourcePetId,
            targetPetIds: dto.targetPetIdsRaw.split(separator: "|").map(String.init),
            species: dto.speciesRaw,
            totalAmountGrams: dto.totalAmountGrams,
            totalAmountMl: dto.totalAmountMl,
            totalExpenseAmount: dto.totalExpenseAmount ?? 0,
            expenseCategory: ExpenseCategory(rawValue: dto.expenseCategoryRaw ?? "") ?? .other,
            currencyCode: dto.currencyCode ?? "",
            allocationMode: SharedCareAllocationMode(rawValue: dto.allocationModeRaw) ?? .equal,
            foodKind: FeedFoodKind(rawValue: dto.foodKindRaw) ?? .dry,
            stockOwnerPetId: dto.stockOwnerPetId,
            primaryLegacyModelName: dto.primaryLegacyModelName ?? "",
            primaryLegacyModelId: dto.primaryLegacyModelId ?? "",
            note: dto.note
        )
        if let uuid = UUID(uuidString: dto.id) { session.id = uuid }
        session.createdAt = parseDate(dto.createdAt) ?? session.createdAt
        return session
    }

    func decodeWalkLog(_ dto: PetWalkLogBackup, pets: [String: Pet]) -> PetWalkLog {
        let l = PetWalkLog(startDate: parseDate(dto.startDate) ?? Date(),
                           pet: dto.petId.flatMap { pets[$0] },
                           executorId: dto.executorId,
                           sharedSessionId: dto.sharedSessionId ?? "")
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.endDate = parseDate(dto.endDate)
        l.distanceMeters = dto.distanceMeters
        l.coconutsEarned = dto.coconutsEarned
        return l
    }

    func decodeWeightLog(_ dto: PetWeightLogBackup, pets: [String: Pet]) -> PetWeightLog {
        let l = PetWeightLog(date: parseDate(dto.date) ?? Date(), weight: dto.weight, pet: dto.petId.flatMap { pets[$0] }, executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeExpenseLog(_ dto: PetExpenseLogBackup, pets: [String: Pet]) -> PetExpenseLog {
        let l = PetExpenseLog(date: parseDate(dto.date) ?? Date(),
                              amount: dto.amount,
                              category: ExpenseCategory(rawValue: dto.category) ?? .other,
                              note: dto.note,
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId,
                              sharedSessionId: dto.sharedSessionId ?? "")
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeHealthLog(_ dto: PetHealthLogBackup, pets: [String: Pet]) -> PetHealthLog {
        let l = PetHealthLog(date: parseDate(dto.date) ?? Date(),
                             type: HealthLogType(rawValue: dto.type) ?? .general,
                             note: dto.note,
                             pet: dto.petId.flatMap { pets[$0] },
                             executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.vetName = dto.vetName
        l.cost = dto.cost
        l.expirationDate = parseDate(dto.expirationDate)
        return l
    }

    func decodeHygieneLog(_ dto: PetHygieneLogBackup, pets: [String: Pet]) -> PetHygieneLog {
        let l = PetHygieneLog(date: parseDate(dto.date) ?? Date(),
                              type: HygieneType(rawValue: dto.type) ?? .bath,
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeFoodRecord(_ dto: PetFoodRecordBackup, pets: [String: Pet]) -> PetFoodRecord {
        let l = PetFoodRecord(brand: dto.brand, dailyGrams: dto.dailyGrams,
                              totalGrams: dto.totalGrams ?? 0,
                              foodKind: FeedFoodKind(rawValue: dto.foodKindRaw ?? "") ?? .dry,
                              purchaseDate: parseDate(dto.purchaseDate ?? ""),
                              startDate: parseDate(dto.date) ?? Date(),
                              pet: dto.petId.flatMap { pets[$0] },
                              executorId: dto.executorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.remainingCorrectionGrams = dto.remainingCorrectionGrams
        l.remainingCorrectionDate = parseDate(dto.remainingCorrectionDate ?? "")
        l.notes = dto.notes ?? ""
        return l
    }

    func decodeDocument(_ dto: PetDocumentBackup, pets: [String: Pet]) -> PetDocument {
        let l = PetDocument(title: dto.title,
                            category: DocumentCategory(rawValue: dto.categoryRaw) ?? .other,
                            pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.expiryDate = parseDate(dto.expiryDate)
        l.issueDate = parseDate(dto.issueDate)
        l.issuingAuthority = dto.issuingAuthority ?? ""
        l.notes = dto.notes ?? ""
        l.reminderDate = parseDate(dto.reminderDate)
        l.cost = dto.cost ?? 0
        l.attachmentData = dto.attachmentBase64.flatMap { Data(base64Encoded: $0) }
        l.attachmentFilename = dto.attachmentFilename ?? ""
        return l
    }

    func decodeDocumentAttachment(_ dto: PetDocumentAttachmentBackup) -> PetDocumentAttachment? {
        guard let data = Data(base64Encoded: dto.dataBase64) else { return nil }
        let l = PetDocumentAttachment(data: data, filename: dto.filename, isImage: dto.isImage)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeMilestone(_ dto: PetMilestoneBackup, pets: [String: Pet]) -> PetMilestone {
        let l = PetMilestone(date: parseDate(dto.date) ?? Date(),
                             title: dto.title, emoji: dto.emoji, notes: dto.notes,
                             pet: dto.petId.flatMap { pets[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeHumanWeight(_ dto: HumanWeightLogBackup, humans: [String: Human]) -> HumanWeightLog {
        let l = HumanWeightLog(
            date: parseDate(dto.date) ?? Date(),
            weight: dto.weight,
            human: dto.humanId.flatMap { humans[$0] },
            executorId: dto.executorId
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeHumanWorkout(_ dto: HumanWorkoutLogBackup, humans: [String: Human]) -> HumanWorkoutLog {
        let l = HumanWorkoutLog(date: parseDate(dto.date) ?? Date(),
                                type: WorkoutType(rawValue: dto.typeRaw) ?? .walking,
                                durationMinutes: dto.durationMinutes,
                                notes: dto.notes,
                                human: dto.humanId.flatMap { humans[$0] })
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeWaterLog(_ dto: WaterLogBackup) -> WaterLog {
        let l = WaterLog(date: parseDate(dto.date) ?? Date(), amountMl: dto.amountMl,
                         note: dto.note)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodePhotoLog(_ dto: PetPhotoLogBackup, pets: [String: Pet]) -> PetPhotoLog {
        let l = PetPhotoLog(
            imageData: Data(base64Encoded: dto.imageBase64) ?? Data(),
            date: parseDate(dto.date) ?? Date(),
            note: dto.note,
            pet: dto.petId.flatMap { pets[$0] },
            locationLatitude: dto.locationLatitude,
            locationLongitude: dto.locationLongitude,
            locationPlacename: dto.locationPlacename
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodeInsurance(_ dto: PetInsuranceBackup, pets: [String: Pet]) -> PetInsurance {
        let l = PetInsurance(
            companyName: dto.companyName,
            policyNumber: dto.policyNumber,
            productName: dto.productName,
            annualPremium: dto.annualPremium,
            coverageAmount: dto.coverageAmount,
            startDate: parseDate(dto.startDate) ?? Date(),
            renewalDate: parseDate(dto.renewalDate) ?? Date(),
            notes: dto.notes,
            paymentFrequency: InsurancePaymentFrequency(rawValue: dto.paymentFrequencyRaw) ?? .annual,
            paymentDayOfMonth: dto.paymentDayOfMonth,
            showInCalendar: dto.showInCalendar,
            otherFeeAmount: dto.otherFeeAmount,
            otherFeeNote: dto.otherFeeNote,
            firstPremiumPaymentDate: parseDate(dto.firstPremiumPaymentDate),
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.isActive = dto.isActive
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodeInsuranceClaim(_ dto: InsuranceClaimBackup, insurances: [String: PetInsurance]) -> InsuranceClaim {
        let l = InsuranceClaim(
            claimDate: parseDate(dto.claimDate) ?? Date(),
            incidentDate: parseDate(dto.incidentDate) ?? Date(),
            totalExpense: dto.totalExpense,
            claimedAmount: dto.claimedAmount,
            approvedAmount: dto.approvedAmount,
            status: ClaimStatus(rawValue: dto.statusRaw) ?? .submitted,
            note: dto.note,
            relatedExpenseLogId: dto.relatedExpenseLogId,
            insurance: dto.insuranceId.flatMap { insurances[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.approvedAt = parseDate(dto.approvedAt)
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodePetMedication(_ dto: PetMedicationBackup, pets: [String: Pet]) -> PetMedication {
        let l = PetMedication(
            name: dto.name,
            dosage: dto.dosage,
            frequency: PetMedicationFrequency(rawValue: dto.frequencyRaw) ?? .daily,
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            colorHex: dto.colorHex,
            notes: dto.notes,
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.customFrequencyNote = dto.customFrequencyNote
        l.isActive = dto.isActive
        l.remainingAmount = max(0, dto.remainingAmount ?? 0)
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodeHumanMedication(_ dto: HumanMedicationBackup) -> HumanMedication {
        let l = HumanMedication(
            humanId: dto.humanId,
            name: dto.name,
            dosage: dto.dosage,
            frequency: MedicationFrequency(rawValue: dto.frequencyRaw) ?? .daily,
            firstDoseTime: parseDate(dto.firstDoseTime) ?? Date(),
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            colorHex: dto.colorHex,
            notes: dto.notes
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.customFrequencyNote = dto.customFrequencyNote
        l.isActive = dto.isActive
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodeHumanMedicationLog(_ dto: HumanMedicationLogBackup) -> HumanMedicationLog {
        let l = HumanMedicationLog(
            humanId: dto.humanId,
            medicationId: dto.medicationId,
            scheduledTime: parseDate(dto.scheduledTime) ?? Date(),
            status: HumanMedicationStatus(rawValue: dto.statusRaw) ?? .pending,
            recordedTime: parseDate(dto.recordedTime)
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodeHumanHealthMetricLog(_ dto: HumanHealthMetricLogBackup, humans: [String: Human]) -> HumanHealthMetricLog {
        let log = HumanHealthMetricLog(
            metricKey: dto.metricKey,
            unitCode: dto.unitCode,
            value: dto.value,
            date: parseDate(dto.date) ?? Date(),
            notes: dto.notes,
            human: dto.humanId.flatMap { humans[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        log.createdAt = parseDate(dto.createdAt) ?? Date()
        return log
    }

    func decodeSymptomLog(_ dto: SymptomLogBackup, pets: [String: Pet]) -> SymptomLog {
        let l = SymptomLog(
            date: parseDate(dto.date) ?? Date(),
            category: SymptomCategory(rawValue: dto.categoryRaw) ?? .other,
            symptomName: dto.symptomName,
            severity: SymptomSeverity(rawValue: dto.severityRaw) ?? .mild,
            note: dto.note,
            photoData: dto.photoBase64.flatMap { Data(base64Encoded: $0) },
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeHeatCycleLog(_ dto: HeatCycleLogBackup, pets: [String: Pet]) -> HeatCycleLog {
        let l = HeatCycleLog(
            startDate: parseDate(dto.startDate) ?? Date(),
            endDate: parseDate(dto.endDate),
            status: HeatCycleStatus(rawValue: dto.statusRaw) ?? .proestrus,
            note: dto.note,
            isMated: dto.isMated,
            expectedDeliveryDate: parseDate(dto.expectedDeliveryDate),
            pet: dto.petId.flatMap { pets[$0] }
        )
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        return l
    }

    func decodeWishlist(_ dto: WishlistItemBackup) -> WishlistItem {
        let l = WishlistItem(title: dto.title, cost: dto.cost, creatorId: dto.creatorId)
        if let uuid = UUID(uuidString: dto.id) { l.id = uuid }
        l.isRedeemed = dto.isRedeemed
        l.createdAt = parseDate(dto.createdAt) ?? Date()
        return l
    }

    func decodeCareLedgerEvent(_ dto: CareLedgerEventBackup) -> CareLedgerEvent {
        let event = CareLedgerEvent(
            occurredAt: parseDate(dto.occurredAt) ?? Date(),
            actorKind: CareLedgerActorKind(rawValue: dto.actorKind) ?? .unknown,
            actorId: dto.actorId,
            subjectKind: CareLedgerSubjectKind(rawValue: dto.subjectKind) ?? .unknown,
            subjectId: dto.subjectId,
            eventKind: CareLedgerEventKind(rawValue: dto.eventKind) ?? .unknown,
            actionType: dto.actionType,
            amountValue: dto.amountValue,
            amountUnit: dto.amountUnit,
            note: dto.note,
            source: CareLedgerSource(rawValue: dto.source) ?? .importData,
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
        if let uuid = UUID(uuidString: dto.id) { event.id = uuid }
        return event
    }

    func decodeCoconutAccount(_ dto: CoconutAccountBackup) -> CoconutAccount {
        let account = CoconutAccount(
            accountKey: dto.accountKey,
            ownerKind: CoconutWalletOwnerKind(rawValue: dto.ownerKindRaw) ?? .system,
            ownerId: dto.ownerId,
            displayName: dto.displayName,
            balance: dto.balance,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            updatedAt: parseDate(dto.updatedAt) ?? Date(),
            metadataJSON: dto.metadataJSON
        )
        if let uuid = UUID(uuidString: dto.id) { account.id = uuid }
        return account
    }

    func decodeCoconutLedgerEntry(_ dto: CoconutLedgerEntryBackup) -> CoconutLedgerEntry {
        let entry = CoconutLedgerEntry(
            transactionKey: dto.transactionKey,
            accountKey: dto.accountKey,
            ownerKind: CoconutWalletOwnerKind(rawValue: dto.ownerKindRaw) ?? .system,
            ownerId: dto.ownerId,
            ownerName: dto.ownerName,
            delta: dto.delta,
            balanceBefore: dto.balanceBefore,
            balanceAfter: dto.balanceAfter,
            affectsBalance: dto.affectsBalance,
            entryKind: CoconutWalletEntryKind(rawValue: dto.entryKindRaw) ?? .adjustment,
            source: CoconutWalletSource(rawValue: dto.sourceRaw) ?? .importData,
            title: dto.title,
            emoji: dto.emoji,
            actorId: dto.actorId,
            actorName: dto.actorName,
            subjectKind: CareLedgerSubjectKind(rawValue: dto.subjectKindRaw) ?? .system,
            subjectId: dto.subjectId,
            sourceModelName: dto.sourceModelName,
            sourceModelId: dto.sourceModelId,
            careLedgerEventId: dto.careLedgerEventId,
            metadataJSON: dto.metadataJSON,
            occurredAt: parseDate(dto.occurredAt) ?? Date(),
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { entry.id = uuid }
        return entry
    }

    func decodeFamilyCollaborationTask(_ dto: FamilyCollaborationTaskBackup) -> FamilyCollaborationTask {
        let task = FamilyCollaborationTask(
            title: dto.title,
            note: dto.note,
            kind: FamilyCollaborationTaskKind(rawValue: dto.kindRaw) ?? .householdTask,
            status: FamilyCollaborationTaskStatus(rawValue: dto.statusRaw) ?? .active,
            relatedPetId: dto.relatedPetId,
            relatedEventId: dto.relatedEventId,
            relatedReminderId: dto.relatedReminderId,
            createdById: dto.createdById,
            createdByName: dto.createdByName,
            assignedToId: dto.assignedToId,
            assignedToName: dto.assignedToName,
            rewardCoconuts: dto.rewardCoconuts,
            dueAt: parseDate(dto.dueAt),
            emoji: dto.emoji,
            createdAt: parseDate(dto.createdAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { task.id = uuid }
        task.claimedById = dto.claimedById
        task.claimedByName = dto.claimedByName
        task.completedById = dto.completedById
        task.completedByName = dto.completedByName
        task.completedAt = parseDate(dto.completedAt)
        task.updatedAt = parseDate(dto.updatedAt) ?? task.createdAt
        return task
    }

    func decodeCoconutExchangeRequest(_ dto: CoconutExchangeRequestBackup) -> CoconutExchangeRequest {
        let request = CoconutExchangeRequest(
            senderId: dto.senderId,
            senderName: dto.senderName,
            receiverId: dto.receiverId,
            receiverName: dto.receiverName,
            coconutCost: dto.coconutCost,
            currencyCode: dto.currencyCode,
            localAmount: dto.localAmount,
            status: CoconutExchangeRequestStatus(rawValue: dto.statusRaw) ?? .pending,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            confirmedAt: parseDate(dto.confirmedAt),
            cancelledAt: parseDate(dto.cancelledAt),
            updatedAt: parseDate(dto.updatedAt) ?? Date(),
            note: dto.note
        )
        if let uuid = UUID(uuidString: dto.id) { request.id = uuid }
        return request
    }

    func decodeOasisUpgradeCoconut(_ dto: OasisUpgradeCoconutBackup) -> OasisUpgradeCoconut {
        let coconut = OasisUpgradeCoconut(
            level: dto.level,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            openedAt: parseDate(dto.openedAt),
            rewardKind: OasisUpgradeRewardKind(rawValue: dto.rewardKindRaw) ?? .coconuts,
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
        if let uuid = UUID(uuidString: dto.id) { coconut.id = uuid }
        return coconut
    }

    func decodeOasisElectronicPet(_ dto: OasisElectronicPetBackup) -> OasisElectronicPet {
        let critter = OasisElectronicPet(
            catalogId: dto.catalogId,
            nameZh: dto.nameZh,
            nameEn: dto.nameEn,
            nameDe: dto.nameDe,
            emoji: dto.emoji,
            rarity: OasisElectronicPetRarity(rawValue: dto.rarityRaw) ?? .common,
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
        if let uuid = UUID(uuidString: dto.id) { critter.id = uuid }
        return critter
    }

    func decodeOasisCritterFragment(_ dto: OasisCritterFragmentBackup) -> OasisCritterFragmentBalance {
        let fragment = OasisCritterFragmentBalance(
            catalogId: dto.catalogId,
            amount: dto.amount,
            updatedAt: parseDate(dto.updatedAt) ?? Date()
        )
        if let uuid = UUID(uuidString: dto.id) { fragment.id = uuid }
        return fragment
    }

    func decodeOasisUnlock(_ dto: OasisUnlockBackup) -> OasisUnlock {
        let unlock = OasisUnlock(
            unlockId: dto.unlockId,
            unlockKind: OasisUpgradeRewardKind(rawValue: dto.unlockKindRaw) ?? .decoration,
            sourceLevel: dto.sourceLevel,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            metadataJSON: dto.metadataJSON
        )
        if let uuid = UUID(uuidString: dto.id) { unlock.id = uuid }
        return unlock
    }

    func decodeOasisCritterActionLog(_ dto: OasisCritterActionLogBackup) -> OasisCritterActionLog {
        let log = OasisCritterActionLog(
            critterId: dto.critterId.flatMap(UUID.init(uuidString:)),
            critterCatalogId: dto.critterCatalogId,
            action: OasisCritterAction(rawValue: dto.actionRaw) ?? .rest,
            createdAt: parseDate(dto.createdAt) ?? Date(),
            coconutDelta: dto.coconutDelta,
            fragmentDelta: dto.fragmentDelta,
            xpDelta: dto.xpDelta,
            sourceLevel: dto.sourceLevel,
            noteZh: dto.noteZh,
            noteEn: dto.noteEn,
            noteDe: dto.noteDe
        )
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        return log
    }

    func decodeGachaOwnedItem(_ dto: GachaOwnedItemBackup) -> GachaOwnedItem {
        let item = GachaOwnedItem(
            ownerHumanId: dto.ownerHumanId,
            seriesId: dto.seriesId,
            itemId: dto.itemId,
            rarity: GachaRarity(rawValue: dto.rarityRaw) ?? .common,
            isHidden: dto.isHidden,
            ownedCount: dto.ownedCount,
            firstObtainedAt: parseDate(dto.firstObtainedAt) ?? Date(),
            latestObtainedAt: parseDate(dto.latestObtainedAt) ?? Date()
        )
        item.createdAt = parseDate(dto.createdAt) ?? item.firstObtainedAt
        if let uuid = UUID(uuidString: dto.id) { item.id = uuid }
        return item
    }

    func decodeGachaDrawLog(_ dto: GachaDrawLogBackup) -> GachaDrawLog {
        let log = GachaDrawLog(
            ownerHumanId: dto.ownerHumanId,
            ownerName: dto.ownerName,
            seriesId: dto.seriesId,
            itemId: dto.itemId,
            rarity: GachaRarity(rawValue: dto.rarityRaw) ?? .common,
            isHidden: dto.isHidden,
            isNew: dto.isNew,
            outcomeKind: GachaOutcomeKind(rawValue: dto.outcomeKindRaw ?? "") ?? .collectible,
            costCoconuts: dto.costCoconuts,
            dailySequence: dto.dailySequence,
            drawDate: parseDate(dto.drawDate) ?? Date()
        )
        log.instantResultId = dto.instantResultId ?? ""
        log.instantTitleZh = dto.instantTitleZh ?? ""
        log.instantTitleEn = dto.instantTitleEn ?? ""
        log.instantTitleDe = dto.instantTitleDe ?? ""
        log.instantDetailZh = dto.instantDetailZh ?? ""
        log.instantDetailEn = dto.instantDetailEn ?? ""
        log.instantDetailDe = dto.instantDetailDe ?? ""
        log.instantSymbol = dto.instantSymbol ?? ""
        log.instantCoconutDelta = dto.instantCoconutDelta ?? 0
        log.createdAt = parseDate(dto.createdAt) ?? log.drawDate
        if let uuid = UUID(uuidString: dto.id) { log.id = uuid }
        return log
    }
}

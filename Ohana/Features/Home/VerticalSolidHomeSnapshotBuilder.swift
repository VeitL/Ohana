//
//  VerticalSolidHomeSnapshotBuilder.swift
//  Ohana
//
//  Read-model aggregation for verticalSolid home. Views should render the snapshot, not
//  derive dashboard state from SwiftData collections inside body.
//

import Foundation

nonisolated struct VerticalSolidHomeSourceState {
    let pets: [Pet]
    let humans: [Human]
    let plants: [Plant]
    let electronicPets: [OasisElectronicPet]
    let events: [Event]
    let pendingReminders: [Reminder]
    let humanMedications: [HumanMedication]
    let humanMedicationLogs: [HumanMedicationLog]
    let healthAlertSources: [PetHealthAlertSource]
    let todayFocusCareLedgerEntries: [TodayFocusCareLedgerEntry]
    let feedingLedgerEntries: [HomeFeedQuickActionEntry]
    let careLedgerEntries: [HomeCareQuickActionEntry]
    let hygieneLedgerEntries: [HomeHygieneQuickActionEntry]
    let walkLedgerEntries: [HomeWalkQuickActionEntry]
    let pottyLedgerEntries: [HomePottyQuickActionEntry]
    let petExpenseLedgerEntries: [HomePetExpenseQuickActionEntry]
    let petWeightLedgerEntries: [HomePetWeightQuickActionEntry]
    let petMomentEntries: [HomePetMomentQuickActionEntry]
    let humanWeightLogs: [HumanWeightLog]
    let familyTasks: [FamilyCollaborationTask]
    let exchangeRequests: [CoconutExchangeRequest]
    let activeHumanIdRaw: String
    let hiddenPetIDsRaw: String
    let homeCardOrderRaw: String
    let showDummyCards: Bool
    let petBondVaultRevision: Int
    let equippedTitleRaw: String
    let language: String

    init(
        pets: [Pet],
        humans: [Human],
        plants: [Plant],
        electronicPets: [OasisElectronicPet],
        events: [Event],
        pendingReminders: [Reminder],
        humanMedications: [HumanMedication],
        humanMedicationLogs: [HumanMedicationLog],
        healthAlertSources: [PetHealthAlertSource] = [],
        todayFocusCareLedgerEntries: [TodayFocusCareLedgerEntry] = [],
        feedingLedgerEntries: [HomeFeedQuickActionEntry],
        careLedgerEntries: [HomeCareQuickActionEntry],
        hygieneLedgerEntries: [HomeHygieneQuickActionEntry] = [],
        walkLedgerEntries: [HomeWalkQuickActionEntry],
        pottyLedgerEntries: [HomePottyQuickActionEntry],
        petExpenseLedgerEntries: [HomePetExpenseQuickActionEntry] = [],
        petWeightLedgerEntries: [HomePetWeightQuickActionEntry] = [],
        petMomentEntries: [HomePetMomentQuickActionEntry] = [],
        humanWeightLogs: [HumanWeightLog],
        familyTasks: [FamilyCollaborationTask],
        exchangeRequests: [CoconutExchangeRequest],
        activeHumanIdRaw: String,
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String,
        showDummyCards: Bool,
        petBondVaultRevision: Int,
        equippedTitleRaw: String,
        language: String
    ) {
        self.pets = pets
        self.humans = humans
        self.plants = plants
        self.electronicPets = electronicPets
        self.events = events
        self.pendingReminders = pendingReminders
        self.humanMedications = humanMedications
        self.humanMedicationLogs = humanMedicationLogs
        self.healthAlertSources = healthAlertSources
        self.todayFocusCareLedgerEntries = todayFocusCareLedgerEntries
        self.feedingLedgerEntries = feedingLedgerEntries
        self.careLedgerEntries = careLedgerEntries
        self.hygieneLedgerEntries = hygieneLedgerEntries
        self.walkLedgerEntries = walkLedgerEntries
        self.pottyLedgerEntries = pottyLedgerEntries
        self.petExpenseLedgerEntries = petExpenseLedgerEntries
        self.petWeightLedgerEntries = petWeightLedgerEntries
        self.petMomentEntries = petMomentEntries
        self.humanWeightLogs = humanWeightLogs
        self.familyTasks = familyTasks
        self.exchangeRequests = exchangeRequests
        self.activeHumanIdRaw = activeHumanIdRaw
        self.hiddenPetIDsRaw = hiddenPetIDsRaw
        self.homeCardOrderRaw = homeCardOrderRaw
        self.showDummyCards = showDummyCards
        self.petBondVaultRevision = petBondVaultRevision
        self.equippedTitleRaw = equippedTitleRaw
        self.language = language
    }

    var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdRaw)
    }

    var activeHuman: Human? {
        activeHumanId.flatMap { id in humans.first { $0.id == id } } ?? humans.first
    }
}

nonisolated enum VerticalSolidHomeSnapshotBuilder {
    @MainActor
    static func build(
        from source: VerticalSolidHomeSourceState,
        now: Date = Date(),
        privacy: HumanPrivacyManaging,
        todayFocus: TodayFocusManaging,
        healthAlerts: PetHealthAlerting
    ) -> VerticalSolidHomeSnapshot {
        build(
            from: source,
            now: now,
            weightVisibleHumans: privacy.unlockedHumans(for: .weight, from: source.humans, viewedBy: source.activeHumanId),
            makeTodayFocus: { pets, plants, reminders, events, humans, activeHumanId, todayFocusCareLedgerEntries, humanWeightLogs, familyTasks, exchangeRequests in
                TodayFocusSnapshot.make(
                    pets: pets,
                    plants: plants,
                    reminders: reminders,
                    events: events,
                    humans: humans,
                    humanMedications: source.humanMedications,
                    activeHumanId: activeHumanId,
                    careLedgerEntries: todayFocusCareLedgerEntries,
                    humanWeightLogs: humanWeightLogs,
                    familyTasks: familyTasks,
                    exchangeRequests: exchangeRequests,
                    todayFocus: todayFocus,
                    healthAlerts: healthAlerts,
                    now: now
                )
            }
        )
    }

    static func buildForReadModelActor(
        from source: VerticalSolidHomeSourceState,
        now: Date = Date(),
        questProgress: TodayFocusQuestProgress = .fromDefaults(),
        healthAlertEngine: PetHealthAlertEngine = PetHealthAlertEngine()
    ) -> VerticalSolidHomeSnapshot {
        let clinicalAlerts = healthAlertEngine.scanAlerts(sources: source.healthAlertSources)
        return build(
            from: source,
            now: now,
            weightVisibleHumans: weightVisibleHumans(from: source),
            makeTodayFocus: { pets, plants, reminders, events, humans, activeHumanId, todayFocusCareLedgerEntries, humanWeightLogs, familyTasks, exchangeRequests in
                TodayFocusSnapshot.make(
                    pets: pets,
                    plants: plants,
                    reminders: reminders,
                    events: events,
                    humans: humans,
                    humanMedications: source.humanMedications,
                    activeHumanId: activeHumanId,
                    careLedgerEntries: todayFocusCareLedgerEntries,
                    humanWeightLogs: humanWeightLogs,
                    familyTasks: familyTasks,
                    exchangeRequests: exchangeRequests,
                    questProgress: questProgress,
                    clinicalAlerts: clinicalAlerts,
                    now: now
                )
            }
        )
    }

    private static func weightVisibleHumans(from source: VerticalSolidHomeSourceState) -> [Human] {
        source.humans.filter { !$0.isPrivate(.weight, viewedBy: source.activeHumanId) }
    }

    private static func build(
        from source: VerticalSolidHomeSourceState,
        now: Date,
        weightVisibleHumans: [Human],
        makeTodayFocus: (
            [Pet],
            [Plant],
            [Reminder],
            [Event],
            [Human],
            String,
            [TodayFocusCareLedgerEntry],
            [HumanWeightLog],
            [FamilyCollaborationTask],
            [CoconutExchangeRequest]
        ) -> TodayFocusSnapshot
    ) -> VerticalSolidHomeSnapshot {
        let l = L10n(source.language)
        let activePets = source.pets.filter { !$0.hasPassedAway }
        let activeHumans = source.humans.filter { !$0.hasPassedAway }
        let cards = enrichCardsWithAvatarData(
            HomeSnapshotBuilder.buildCards(
                pets: source.pets,
                humans: source.humans,
                electronicPets: source.electronicPets,
                events: source.events,
                humanMedications: source.humanMedications,
                humanMedicationLogs: source.humanMedicationLogs,
                careLedgerEntries: source.careLedgerEntries,
                hiddenPetIDsRaw: source.hiddenPetIDsRaw,
                homeCardOrderRaw: source.homeCardOrderRaw,
                showDummyCards: source.showDummyCards,
                now: now
            ),
            pets: source.pets,
            humans: source.humans,
            hiddenPetIDsRaw: source.hiddenPetIDsRaw,
            activeHumanIdRaw: source.activeHumanIdRaw,
            equippedTitleRaw: source.equippedTitleRaw,
            language: source.language
        )
        let visiblePlants = PlantFeatureGate.allows(.plants) ? source.plants : []
        let todayFocus = makeTodayFocus(
            activePets,
            visiblePlants,
            source.pendingReminders,
            source.events,
            weightVisibleHumans,
            source.activeHumanIdRaw,
            source.todayFocusCareLedgerEntries,
            source.humanWeightLogs,
            source.familyTasks,
            source.exchangeRequests
        )

        return VerticalSolidHomeSnapshot(
            isReady: true,
            greeting: greetingText(l, now: now),
            activeName: source.activeHuman?.name ?? l.tr(zh: "家人", en: "Family", de: "Familie"),
            coconutText: "\(source.pets.reduce(0) { $0 + $1.coconutBalance } + source.humans.reduce(0) { $0 + $1.coconutBalance })",
            todayFocus: todayFocus,
            cards: cards,
            firstPetEmptyState: firstPetEmptyState(activePets: activePets, activeHumans: activeHumans, l: l),
            plants: visiblePlants.sorted { $0.createdAt > $1.createdAt }.map { plant in
                VerticalSolidHomePlantSnapshot(
                    id: plant.id,
                    name: plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name,
                    subtitle: plant.species.isEmpty ? plant.location : plant.species,
                    emoji: plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji,
                    themeHex: plant.themeColorHex,
                    needsCare: plant.needsWatering(on: now) || plant.needsFertilizing(on: now)
                )
            },
            heroPreparationRevision: heroPreparationRevision(for: cards)
        )
    }

    private static func firstPetEmptyState(
        activePets: [Pet],
        activeHumans: [Human],
        l: L10n
    ) -> VerticalSolidHomeFirstPetEmptyState? {
        guard activePets.isEmpty, !activeHumans.isEmpty else { return nil }
        return VerticalSolidHomeFirstPetEmptyState(
            eyebrow: l.tr(zh: "首日进度 1/3", en: "First day 1/3", de: "Erster Tag 1/3"),
            title: l.tr(zh: "添加第一只宠物", en: "Add your first pet", de: "Erstes Haustier hinzufügen"),
            subtitle: l.tr(
                zh: "身份已准备好。添加宠物后记录首次体重照护，就能领取 50 椰子新人礼包。",
                en: "Your identity is ready. Add a pet, log the first weight care, then claim the 50-coconut starter gift.",
                de: "Dein Profil ist bereit. Füge ein Haustier hinzu, erfasse das erste Gewicht und erhalte das Startergeschenk mit 50 Kokosnüssen."
            ),
            progressText: l.tr(
                zh: "下一步：宠物档案",
                en: "Next: pet profile",
                de: "Weiter: Haustierprofil"
            ),
            primaryActionTitle: l.tr(zh: "添加宠物", en: "Add pet", de: "Haustier hinzufügen")
        )
    }

    static func signature(for source: VerticalSolidHomeSourceState, now: Date = Date()) -> String {
        let visiblePlants = PlantFeatureGate.allows(.plants) ? source.plants : []
        return [
            "day:\(dayToken(for: now))",
            petSignature(source.pets),
            humanSignature(source.humans),
            plantSignature(visiblePlants, now: now),
            electronicPetSignature(source.electronicPets),
            eventSignature(source.events),
            reminderSignature(source.pendingReminders),
            medicationSignature(source.humanMedications),
            medicationLogSignature(source.humanMedicationLogs),
            healthAlertSourceSignature(source.healthAlertSources),
            todayFocusCareLedgerSignature(source.todayFocusCareLedgerEntries),
            feedingLedgerSignature(source.feedingLedgerEntries),
            careLedgerSignature(source.careLedgerEntries),
            hygieneLedgerSignature(source.hygieneLedgerEntries),
            walkLedgerSignature(source.walkLedgerEntries),
            pottyLedgerSignature(source.pottyLedgerEntries),
            petExpenseLedgerSignature(source.petExpenseLedgerEntries),
            petWeightLedgerSignature(source.petWeightLedgerEntries),
            petMomentSignature(source.petMomentEntries),
            humanWeightSignature(source.humanWeightLogs),
            familyTaskSignature(source.familyTasks),
            exchangeSignature(source.exchangeRequests),
            source.activeHumanIdRaw,
            source.hiddenPetIDsRaw,
            source.homeCardOrderRaw,
            "\(source.showDummyCards)",
            "\(source.petBondVaultRevision)",
            source.equippedTitleRaw,
            source.language
        ].joined(separator: "#")
    }

    private static func greetingText(_ l: L10n, now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5 ..< 11: return l.tr(zh: "早安", en: "Good morning", de: "Guten Morgen")
        case 11 ..< 18: return l.tr(zh: "今天", en: "Today", de: "Heute")
        default: return l.tr(zh: "晚上好", en: "Good evening", de: "Guten Abend")
        }
    }

    private static func enrichCardsWithAvatarData(
        _ cards: [FocusCard],
        pets: [Pet],
        humans: [Human],
        hiddenPetIDsRaw: String,
        activeHumanIdRaw: String,
        equippedTitleRaw: String,
        language: String
    ) -> [FocusCard] {
        cards.map { card in
            var copy = card
            if let pet = pets.first(where: { $0.id == card.id }) {
                copy.avatarImageData = pet.avatarImageData
                copy.avatarImageSignature = pet.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
                let popoutImageData = pet.cardStyleRaw == "popout"
                    ? (pet.cardPopoutImageData ?? pet.avatarImageData)
                    : nil
                copy.cardPopoutImageData = popoutImageData
                copy.cardPopoutImageSignature = popoutImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
                copy.cardPopoutSourceRaw = pet.cardPopoutSourceRaw ?? ""
                copy.petBondCardBorderActive = PetBondVaultStore.isUnlocked(.cardBorder, for: pet.id)
                copy.petBondNameplateActive = PetBondVaultStore.isUnlocked(.nameplate, for: pet.id)
                copy.petBondNameplateText = copy.petBondNameplateActive
                    ? L10n(language).tr(zh: "羁绊", en: "Bond", de: "Bindung")
                    : nil
                copy.isShownOnHome = HomeCardVisibility.isPetVisible(pet, raw: hiddenPetIDsRaw)
            } else if let human = humans.first(where: { $0.id == card.id }) {
                copy.avatarImageData = human.avatarImageData
                copy.avatarImageSignature = human.avatarImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
                copy.isShownOnHome = human.shouldShowOnHome
                if human.id.uuidString == activeHumanIdRaw {
                    copy.equippedTitleBadgeText = equippedTitleBadgeText(for: equippedTitleRaw)
                }
            }
            return copy
        }
    }

    private static func equippedTitleBadgeText(for raw: String) -> String? {
        switch raw {
        case "title_guardian": "🛡️ 守护者"
        case "title_pioneer": "🚀 先行者"
        case "title_chef": "👨‍🍳 首席厨师"
        default: nil
        }
    }

    static func heroPreparationRevision(for cards: [FocusCard]) -> String {
        cards.map { card in
            [
                card.id.uuidString,
                card.name,
                card.kind,
                "\(card.coconutBalance)",
                card.homePrimaryMetricValue,
                card.homePrimaryMetricUnit,
                card.statusBadgeText ?? "",
                card.themeColorHex
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    private static func petSignature(_ pets: [Pet]) -> String {
        pets.map { pet in
            [
                pet.id.uuidString,
                pet.name,
                pet.species,
                pet.avatarEmoji,
                pet.safeThemeColorHex,
                String(pet.coconutBalance),
                String(pet.currentStreak),
                String(pet.hasPassedAway)
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func humanSignature(_ humans: [Human]) -> String {
        humans.map { human in
            [
                human.id.uuidString,
                human.name,
                String(human.coconutBalance),
                String(human.shouldShowOnHome)
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func plantSignature(_ plants: [Plant], now: Date) -> String {
        plants.map { plant in
            [
                plant.id.uuidString,
                plant.name,
                plant.species,
                plant.location,
                plant.avatarEmoji,
                plant.themeColorHex,
                String(timestamp(plant.lastWateredDate)),
                String(timestamp(plant.lastFertilizedDate)),
                String(plant.wateringIntervalDays),
                String(plant.fertilizingIntervalDays),
                String(plant.needsWatering(on: now)),
                String(plant.needsFertilizing(on: now))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func electronicPetSignature(_ electronicPets: [OasisElectronicPet]) -> String {
        electronicPets.prefix(8).map { electronicPet in
            [
                electronicPet.id.uuidString,
                electronicPet.catalogId,
                String(electronicPet.isFeaturedOnOasis),
                String(electronicPet.level),
                electronicPet.lifeStateRaw,
                String(electronicPet.isArchived)
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func eventSignature(_ events: [Event]) -> String {
        events.map { event in
            [
                event.id.uuidString,
                event.title,
                event.eventType,
                event.relatedEntityType,
                event.relatedEntityId,
                String(Int(event.startDate.timeIntervalSince1970)),
                String(timestamp(event.endDate)),
                String(event.isAllDay),
                String(event.recurrenceDays),
                String(timestamp(event.recurrenceEndDate)),
                event.completedOccurrences.sorted().joined(separator: ","),
                String(event.isCompleted),
                event.assigneeId ?? ""
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func reminderSignature(_ reminders: [Reminder]) -> String {
        reminders.map { reminder in
            [
                reminder.id.uuidString,
                String(Int(reminder.scheduledAt.timeIntervalSince1970)),
                reminder.status,
                reminder.completedBy,
                String(timestamp(reminder.completedAt)),
                reminder.event?.id.uuidString ?? "",
                reminder.event?.title ?? ""
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func medicationSignature(_ medications: [HumanMedication]) -> String {
        medications.map { medication in
            [
                medication.id.uuidString,
                medication.name,
                String(medication.isActive),
                String(timestamp(medication.startDate)),
                String(timestamp(medication.endDate))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func medicationLogSignature(_ logs: [HumanMedicationLog]) -> String {
        logs.map { log in
            [
                log.id.uuidString,
                String(Int(log.scheduledTime.timeIntervalSince1970)),
                log.statusRaw
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func healthAlertSourceSignature(_ sources: [PetHealthAlertSource]) -> String {
        sources.map { source in
            [
                source.petId.uuidString,
                source.healthLogs.map(healthAlertHealthLogSignature).joined(separator: ";"),
                source.weightLogs.map(healthAlertWeightLogSignature).joined(separator: ";"),
                source.careLogs.map(healthAlertCareLogSignature).joined(separator: ";"),
                source.pottyLogs.map(healthAlertPottyLogSignature).joined(separator: ";"),
                source.walkLogs.map(healthAlertWalkLogSignature).joined(separator: ";"),
                source.documents.map(healthAlertDocumentSignature).joined(separator: ";"),
                source.symptomLogs.map(healthAlertSymptomSignature).joined(separator: ";"),
                source.heatCycleLogs.map(healthAlertHeatCycleSignature).joined(separator: ";")
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func healthAlertHealthLogSignature(_ log: PetHealthLog) -> String {
        [
            log.id.uuidString,
            log.type,
            String(Int(log.date.timeIntervalSince1970)),
            String(timestamp(log.expirationDate)),
            String(timestamp(log.nextCheckupDate))
        ].joined(separator: ",")
    }

    private static func healthAlertWeightLogSignature(_ log: PetWeightLog) -> String {
        [
            log.id.uuidString,
            String(Int(log.date.timeIntervalSince1970)),
            String(Int((log.weight * 1000).rounded()))
        ].joined(separator: ",")
    }

    private static func healthAlertCareLogSignature(_ log: PetCareLog) -> String {
        [
            log.id.uuidString,
            log.type,
            String(Int(log.date.timeIntervalSince1970))
        ].joined(separator: ",")
    }

    private static func healthAlertPottyLogSignature(_ log: PetPottyLog) -> String {
        [
            log.id.uuidString,
            log.type,
            String(Int(log.date.timeIntervalSince1970))
        ].joined(separator: ",")
    }

    private static func healthAlertWalkLogSignature(_ log: PetWalkLog) -> String {
        [
            log.id.uuidString,
            String(Int(log.startDate.timeIntervalSince1970))
        ].joined(separator: ",")
    }

    private static func healthAlertDocumentSignature(_ document: PetDocument) -> String {
        [
            document.id.uuidString,
            document.category,
            String(timestamp(document.expiryDate))
        ].joined(separator: ",")
    }

    private static func healthAlertSymptomSignature(_ log: SymptomLog) -> String {
        [
            log.id.uuidString,
            log.categoryRaw,
            log.symptomName,
            String(log.severityRaw),
            String(Int(log.date.timeIntervalSince1970))
        ].joined(separator: ",")
    }

    private static func healthAlertHeatCycleSignature(_ log: HeatCycleLog) -> String {
        [
            log.id.uuidString,
            log.statusRaw,
            String(Int(log.startDate.timeIntervalSince1970)),
            String(timestamp(log.endDate)),
            String(timestamp(log.expectedDeliveryDate))
        ].joined(separator: ",")
    }

    private static func todayFocusCareLedgerSignature(_ entries: [TodayFocusCareLedgerEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.eventKind.rawValue,
                entry.actionType,
                String(Int(entry.date.timeIntervalSince1970)),
                entry.sourceEventId?.uuidString ?? "",
                entry.actorId ?? ""
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func feedingLedgerSignature(_ entries: [HomeFeedQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.source.rawValue,
                String(Int(entry.date.timeIntervalSince1970)),
                String(Int(entry.amountGrams.rounded()))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func careLedgerSignature(_ entries: [HomeCareQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.actionType,
                String(Int(entry.date.timeIntervalSince1970)),
                String(Int(entry.amountValue.rounded()))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func hygieneLedgerSignature(_ entries: [HomeHygieneQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.hygieneType.rawValue,
                String(Int(entry.date.timeIntervalSince1970))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func walkLedgerSignature(_ entries: [HomeWalkQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                String(Int(entry.startDate.timeIntervalSince1970)),
                String(Int(entry.distanceMeters.rounded()))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func pottyLedgerSignature(_ entries: [HomePottyQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                entry.pottyType.rawValue,
                String(Int(entry.date.timeIntervalSince1970))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func petExpenseLedgerSignature(_ entries: [HomePetExpenseQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                String(Int(entry.date.timeIntervalSince1970)),
                String(Int(entry.amount.rounded()))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func petWeightLedgerSignature(_ entries: [HomePetWeightQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                String(Int(entry.date.timeIntervalSince1970)),
                String(Int((entry.weightKg * 1000).rounded()))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func petMomentSignature(_ entries: [HomePetMomentQuickActionEntry]) -> String {
        entries.map { entry in
            [
                entry.id.uuidString,
                entry.petId.uuidString,
                String(Int(entry.date.timeIntervalSince1970))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func humanWeightSignature(_ logs: [HumanWeightLog]) -> String {
        logs.map { log in
            [
                log.id.uuidString,
                log.human?.id.uuidString ?? "",
                String(Int(log.date.timeIntervalSince1970)),
                String(log.weight)
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func familyTaskSignature(_ tasks: [FamilyCollaborationTask]) -> String {
        tasks.map { task in
            [
                task.id.uuidString,
                task.title,
                task.statusRaw,
                task.createdByName,
                task.assignedToId ?? "",
                task.assignedToName ?? "",
                task.claimedById ?? "",
                task.claimedByName ?? "",
                task.completedByName ?? "",
                String(task.rewardCoconuts),
                String(timestamp(task.dueAt)),
                String(timestamp(task.updatedAt))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func exchangeSignature(_ requests: [CoconutExchangeRequest]) -> String {
        requests.map { request in
            [
                request.id.uuidString,
                request.senderName,
                request.statusRaw,
                request.receiverId,
                request.currencyCode,
                String(request.localAmount),
                String(request.coconutCost),
                String(timestamp(request.updatedAt))
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func dayToken(for date: Date, calendar: Calendar = .current) -> Int {
        timestamp(calendar.startOfDay(for: date))
    }

    private static func timestamp(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970)
    }

    private static func timestamp(_ date: Date?) -> Int {
        guard let date else { return 0 }
        return timestamp(date)
    }
}

nonisolated enum VerticalSolidHomePreloadPlanner {
    static func avatarSignature(for payloads: [FocusWalletAvatarCache.Payload]) -> String {
        payloads.map { payload in
            [
                payload.id.uuidString,
                payload.data.map(FocusWalletAvatarCache.signature(for:)) ?? ""
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }

    static func avatarSignature(for snapshot: VerticalSolidHomeSnapshot) -> String {
        avatarSignature(for: avatarPayloads(snapshot: snapshot))
    }

    static func avatarPayloads(snapshot: VerticalSolidHomeSnapshot) -> [FocusWalletAvatarCache.Payload] {
        snapshot.cards
            .prefix(FocusHomeCardDataSource.maxCardsPerPage)
            .map { card in
                FocusWalletAvatarCache.Payload(id: card.id, data: card.avatarImageData)
            }
    }

    static func popoutSignature(for payloads: [FocusWalletAvatarCache.Payload]) -> String {
        avatarSignature(for: payloads)
    }

    static func popoutPayloads(snapshot: VerticalSolidHomeSnapshot) -> [FocusWalletAvatarCache.Payload] {
        snapshot.cards
            .prefix(FocusHomeCardDataSource.maxCardsPerPage)
            .map { card in
                FocusWalletAvatarCache.Payload(id: card.id, data: card.cardPopoutImageData)
            }
    }
}

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
    let careLogs: [PetCareLog]
    let walkLogs: [PetWalkLog]
    let pottyLogs: [PetPottyLog]
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
            makeTodayFocus: { pets, plants, reminders, events, humans, activeHumanId, careLogs, walkLogs, pottyLogs, humanWeightLogs, familyTasks, exchangeRequests in
                TodayFocusSnapshot.make(
                    pets: pets,
                    plants: plants,
                    reminders: reminders,
                    events: events,
                    humans: humans,
                    activeHumanId: activeHumanId,
                    careLogs: careLogs,
                    walkLogs: walkLogs,
                    pottyLogs: pottyLogs,
                    humanWeightLogs: humanWeightLogs,
                    familyTasks: familyTasks,
                    exchangeRequests: exchangeRequests,
                    todayFocus: todayFocus,
                    healthAlerts: healthAlerts
                )
            }
        )
    }

    static func buildForReadModelActor(
        from source: VerticalSolidHomeSourceState,
        now: Date = Date(),
        questManager: QuestManager = QuestManager(),
        healthAlertEngine: PetHealthAlertEngine = PetHealthAlertEngine()
    ) -> VerticalSolidHomeSnapshot {
        let clinicalAlerts = healthAlertEngine.scanAlerts(pets: source.pets.filter { !$0.hasPassedAway })
        return build(
            from: source,
            now: now,
            weightVisibleHumans: weightVisibleHumans(from: source),
            makeTodayFocus: { pets, plants, reminders, events, humans, activeHumanId, careLogs, walkLogs, pottyLogs, humanWeightLogs, familyTasks, exchangeRequests in
                TodayFocusSnapshot.make(
                    pets: pets,
                    plants: plants,
                    reminders: reminders,
                    events: events,
                    humans: humans,
                    activeHumanId: activeHumanId,
                    careLogs: careLogs,
                    walkLogs: walkLogs,
                    pottyLogs: pottyLogs,
                    humanWeightLogs: humanWeightLogs,
                    familyTasks: familyTasks,
                    exchangeRequests: exchangeRequests,
                    questManager: questManager,
                    clinicalAlerts: clinicalAlerts
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
            [PetCareLog],
            [PetWalkLog],
            [PetPottyLog],
            [HumanWeightLog],
            [FamilyCollaborationTask],
            [CoconutExchangeRequest]
        ) -> TodayFocusSnapshot
    ) -> VerticalSolidHomeSnapshot {
        let l = L10n(source.language)
        let cards = enrichCardsWithAvatarData(
            HomeSnapshotBuilder.buildCards(
                pets: source.pets,
                humans: source.humans,
                electronicPets: source.electronicPets,
                events: source.events,
                humanMedications: source.humanMedications,
                humanMedicationLogs: source.humanMedicationLogs,
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
        let todayFocus = makeTodayFocus(
            source.pets.filter { !$0.hasPassedAway },
            source.plants,
            source.pendingReminders,
            source.events,
            weightVisibleHumans,
            source.activeHumanIdRaw,
            source.careLogs,
            source.walkLogs,
            source.pottyLogs,
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
            plants: source.plants.sorted { $0.createdAt > $1.createdAt }.map { plant in
                VerticalSolidHomePlantSnapshot(
                    id: plant.id,
                    name: plant.name.isEmpty ? l.tr(zh: "植物", en: "Plant", de: "Pflanze") : plant.name,
                    subtitle: plant.species.isEmpty ? plant.location : plant.species,
                    emoji: plant.avatarEmoji.isEmpty ? "🌱" : plant.avatarEmoji,
                    themeHex: plant.themeColorHex,
                    needsCare: plant.needsWatering || plant.needsFertilizing
                )
            },
            heroPreparationRevision: heroPreparationRevision(for: cards)
        )
    }

    static func signature(for source: VerticalSolidHomeSourceState) -> String {
        [
            petSignature(source.pets),
            humanSignature(source.humans),
            plantSignature(source.plants),
            electronicPetSignature(source.electronicPets),
            eventSignature(source.events),
            reminderSignature(source.pendingReminders),
            medicationSignature(source.humanMedications),
            medicationLogSignature(source.humanMedicationLogs),
            careSignature(source.careLogs),
            walkSignature(source.walkLogs),
            pottySignature(source.pottyLogs),
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
        case 5..<11: return l.tr(zh: "早安", en: "Good morning", de: "Guten Morgen")
        case 11..<18: return l.tr(zh: "今天", en: "Today", de: "Heute")
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
        case "title_guardian": return "🛡️ 守护者"
        case "title_pioneer": return "🚀 先行者"
        case "title_chef": return "👨‍🍳 首席厨师"
        default: return nil
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

    private static func plantSignature(_ plants: [Plant]) -> String {
        plants.map { plant in
            [
                plant.id.uuidString,
                plant.name,
                plant.species,
                plant.location,
                plant.avatarEmoji,
                plant.themeColorHex,
                String(plant.needsWatering),
                String(plant.needsFertilizing)
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
        events.prefix(24).map { event in
            [
                event.id.uuidString,
                String(Int(event.startDate.timeIntervalSince1970)),
                String(event.isCompleted)
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func reminderSignature(_ reminders: [Reminder]) -> String {
        reminders.prefix(8).map { reminder in
            [
                reminder.id.uuidString,
                String(Int(reminder.scheduledAt.timeIntervalSince1970)),
                reminder.status,
                reminder.event?.title ?? ""
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func medicationSignature(_ medications: [HumanMedication]) -> String {
        medications.prefix(12).map { medication in
            [medication.id.uuidString, medication.name].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func medicationLogSignature(_ logs: [HumanMedicationLog]) -> String {
        logs.prefix(12).map { log in
            [
                log.id.uuidString,
                String(Int(log.scheduledTime.timeIntervalSince1970)),
                log.statusRaw
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func careSignature(_ logs: [PetCareLog]) -> String {
        logs.prefix(16).map { log in
            [log.id.uuidString, String(Int(log.date.timeIntervalSince1970))].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func walkSignature(_ logs: [PetWalkLog]) -> String {
        logs.prefix(16).map { log in
            [log.id.uuidString, String(Int(log.startDate.timeIntervalSince1970))].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func pottySignature(_ logs: [PetPottyLog]) -> String {
        logs.prefix(16).map { log in
            [log.id.uuidString, String(Int(log.date.timeIntervalSince1970))].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func humanWeightSignature(_ logs: [HumanWeightLog]) -> String {
        logs.prefix(12).map { log in
            [log.id.uuidString, String(Int(log.date.timeIntervalSince1970))].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func familyTaskSignature(_ tasks: [FamilyCollaborationTask]) -> String {
        tasks.prefix(16).map { task in
            [
                task.id.uuidString,
                task.statusRaw,
                task.assignedToId ?? "",
                task.claimedById ?? ""
            ].joined(separator: ":")
        }.joined(separator: "|")
    }

    private static func exchangeSignature(_ requests: [CoconutExchangeRequest]) -> String {
        requests.prefix(12).map { request in
            [
                request.id.uuidString,
                request.statusRaw,
                request.receiverId
            ].joined(separator: ":")
        }.joined(separator: "|")
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

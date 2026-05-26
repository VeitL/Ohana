//
//  VerticalSolidHomeSnapshotBuilder.swift
//  Ohana
//
//  Read-model aggregation for verticalSolid home. Views should render the snapshot, not
//  derive dashboard state from SwiftData collections inside body.
//

import Foundation

struct VerticalSolidHomeSourceState {
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
    let language: String

    var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdRaw)
    }

    var activeHuman: Human? {
        activeHumanId.flatMap { id in humans.first { $0.id == id } } ?? humans.first
    }
}

enum VerticalSolidHomeSnapshotBuilder {
    static func build(from source: VerticalSolidHomeSourceState, now: Date = Date()) -> VerticalSolidHomeSnapshot {
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
            humans: source.humans
        )
        let todayFocus = TodayFocusSnapshot.make(
            pets: source.pets.filter { !$0.hasPassedAway },
            plants: source.plants,
            reminders: source.pendingReminders,
            events: source.events,
            humans: PrivacyService.unlockedHumans(for: .weight, from: source.humans, viewedBy: source.activeHumanId),
            activeHumanId: source.activeHumanIdRaw,
            careLogs: source.careLogs,
            walkLogs: source.walkLogs,
            pottyLogs: source.pottyLogs,
            humanWeightLogs: source.humanWeightLogs,
            familyTasks: source.familyTasks,
            exchangeRequests: source.exchangeRequests
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
            }
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
        humans: [Human]
    ) -> [FocusCard] {
        cards.map { card in
            var copy = card
            if let pet = pets.first(where: { $0.id == card.id }) {
                copy.avatarImageData = pet.avatarImageData
                copy.cardPopoutImageData = pet.cardPopoutImageData
                copy.cardPopoutSourceRaw = pet.cardPopoutSourceRaw ?? ""
            } else if let human = humans.first(where: { $0.id == card.id }) {
                copy.avatarImageData = human.avatarImageData
            }
            return copy
        }
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

enum VerticalSolidHomePreloadPlanner {
    static func avatarSignature(for source: VerticalSolidHomeSourceState) -> String {
        (
            source.pets.map { pet in
                [
                    pet.id.uuidString,
                    FocusWalletAvatarCache.signature(for: pet.avatarImageData ?? Data()),
                    pet.cardPopoutImageData.map(FocusWalletAvatarCache.signature(for:)) ?? ""
                ].joined(separator: ":")
            } +
            source.humans.map { human in
                [
                    human.id.uuidString,
                    FocusWalletAvatarCache.signature(for: human.avatarImageData ?? Data())
                ].joined(separator: ":")
            }
        ).joined(separator: "|")
    }

    static func avatarPayloads(
        source: VerticalSolidHomeSourceState,
        snapshot: VerticalSolidHomeSnapshot
    ) -> [FocusWalletAvatarCache.Payload] {
        var payloads: [FocusWalletAvatarCache.Payload] = []
        for card in snapshot.cards.prefix(FocusHomeCardDataSource.maxCardsPerPage) {
            if let pet = source.pets.first(where: { $0.id == card.id }) {
                payloads.append(.init(id: pet.id, data: pet.avatarImageData))
                if let popout = pet.cardPopoutImageData {
                    payloads.append(.init(id: pet.id, data: popout))
                }
            } else if let human = source.humans.first(where: { $0.id == card.id }) {
                payloads.append(.init(id: human.id, data: human.avatarImageData))
            }
        }
        return payloads
    }
}

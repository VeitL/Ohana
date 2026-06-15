//
//  QuickActionReminderCompletionSyncService.swift
//  Ohana
//

import Foundation
import SwiftData

@MainActor
private func fetchQuickActionReminderModelsOrLog<T: PersistentModel>(
    _ descriptor: FetchDescriptor<T>,
    context: ModelContext,
    operation: String
) -> [T] {
    do {
        return try context.fetch(descriptor)
    } catch {
        OhanaLog.warning(
            "QuickActionReminderCompletionSyncService failed to \(operation): \(error.localizedDescription)",
            category: "Care"
        )
        return []
    }
}

@MainActor
protocol QuickActionReminderCompleting {
    @discardableResult
    func completeNearestPetCareReminder(
        pet: Pet,
        type: CareType,
        context: ModelContext,
        executorId: String?,
        now: Date
    ) -> Reminder?

    @discardableResult
    func completeNearestPetPottyReminder(
        pet: Pet,
        context: ModelContext,
        executorId: String?,
        now: Date
    ) -> Reminder?

    @discardableResult
    func completeNearestPetHygieneReminder(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        now: Date
    ) -> Reminder?
}

@MainActor
final class QuickActionReminderCompletionSyncService: QuickActionReminderCompleting {
    private let reminderCompletion: ReminderCompleting

    init(reminderCompletion: ReminderCompleting? = nil) {
        self.reminderCompletion = reminderCompletion ?? DomainServiceDependencyRegistry.reminderCompletion(careLedger: CareLedgerService())
    }

    @discardableResult
    func completeNearestPetCareReminder(
        pet: Pet,
        type: CareType,
        context: ModelContext,
        executorId: String?,
        now: Date
    ) -> Reminder? {
        Self.completeNearestPetCareReminder(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            now: now,
            reminderCompletion: reminderCompletion
        )
    }

    @discardableResult
    func completeNearestPetPottyReminder(
        pet: Pet,
        context: ModelContext,
        executorId: String?,
        now: Date
    ) -> Reminder? {
        Self.completeNearestPetPottyReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now,
            reminderCompletion: reminderCompletion
        )
    }

    @discardableResult
    func completeNearestPetHygieneReminder(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        now: Date
    ) -> Reminder? {
        Self.completeNearestPetHygieneReminder(
            pet: pet,
            type: type,
            context: context,
            executorId: executorId,
            now: now,
            reminderCompletion: reminderCompletion
        )
    }

    @discardableResult
    @MainActor
    static func completeNearestPetCareReminder(
        pet: Pet,
        type: CareType,
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        reminderCompletion: ReminderCompleting? = nil
    ) -> Reminder? {
        completeNearestPetReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now,
            reminderCompletion: reminderCompletion
        ) { event in
            matchesCare(event, type: type)
        }
    }

    @discardableResult
    @MainActor
    static func completeNearestPetPottyReminder(
        pet: Pet,
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        reminderCompletion: ReminderCompleting? = nil
    ) -> Reminder? {
        completeNearestPetReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now,
            reminderCompletion: reminderCompletion
        ) { event in
            matchesAny(normalizedText(for: event), [
                "便", "尿", "potty", "poop", "pee", "kot", "urin"
            ])
        }
    }

    @discardableResult
    @MainActor
    static func completeNearestPetHygieneReminder(
        pet: Pet,
        type: HygieneType,
        context: ModelContext,
        executorId: String?,
        now: Date = Date(),
        reminderCompletion: ReminderCompleting? = nil
    ) -> Reminder? {
        completeNearestPetReminder(
            pet: pet,
            context: context,
            executorId: executorId,
            now: now,
            reminderCompletion: reminderCompletion
        ) { event in
            matchesHygiene(event, type: type)
        }
    }

    @discardableResult
    @MainActor
    private static func completeNearestPetReminder(
        pet: Pet,
        context: ModelContext,
        executorId: String?,
        now: Date,
        reminderCompletion providedReminderCompletion: ReminderCompleting?,
        matches: (Event) -> Bool
    ) -> Reminder? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let catchUpStart = calendar.date(byAdding: .day, value: -30, to: start) ?? start
        let pending = ReminderStatus.pending.rawValue
        let failed = ReminderStatus.failed.rawValue
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate<Reminder> { reminder in
                reminder.scheduledAt >= catchUpStart &&
                    reminder.scheduledAt < end &&
                    (reminder.status == pending || reminder.status == failed)
            },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        descriptor.fetchLimit = 96

        let reminders = fetchQuickActionReminderModelsOrLog(
            descriptor,
            context: context,
            operation: "fetch pending pet reminders"
        )
        let petId = pet.id.uuidString
        let matched = reminders.filter { reminder in
            guard let event = reminder.event,
                  MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: petId) else { return false }
            return matches(event)
        }
        guard !matched.isEmpty else { return nil }

        let due = matched.filter { $0.scheduledAt <= now }
        let selected = due.max { $0.scheduledAt < $1.scheduledAt }
            ?? matched.min { $0.scheduledAt < $1.scheduledAt }
        guard let selected else { return nil }
        let reminderCompletion = providedReminderCompletion ?? DomainServiceDependencyRegistry.reminderCompletion(careLedger: CareLedgerService())
        reminderCompletion.complete(selected, by: executorId, context: context)
        return selected
    }

    private static func matchesCare(_ event: Event, type: CareType) -> Bool {
        let text = normalizedText(for: event)
        switch type {
        case .feeding:
            return event.eventType == EventType.foodChange.rawValue ||
                matchesAny(text, ["喂食", "喂", "吃", "粮", "feed", "food", "meal", "futter", "fütter"])
        case .watering:
            return matchesAny(text, ["喂水", "喝水", "饮水", "water", "drink", "wasser"])
        case .litter:
            return event.eventType == EventType.litterBox.rawValue ||
                matchesAny(text, ["铲", "猫砂", "litter", "scoop", "toilet", "klo"])
        case .waterChange:
            return matchesAny(text, ["换水", "water change", "wasserwechsel"])
        case .filterClean:
            return matchesAny(text, ["滤", "filter"])
        case .cageCleaning:
            return matchesAny(text, ["清笼", "鸟笼", "cage", "käfig"])
        case .freeFlight:
            return matchesAny(text, ["放飞", "free flight", "freiflug"])
        case .misting:
            return matchesAny(text, ["保湿", "喷水", "mist", "spray", "befeuchten"])
        case .substrateChange:
            return matchesAny(text, ["垫材", "substrate", "substrat"])
        case .play:
            return matchesAny(text, ["陪玩", "逗", "play", "spielen"])
        }
    }

    private static func matchesHygiene(_ event: Event, type: HygieneType) -> Bool {
        let text = normalizedText(for: event)
        let isGrooming = event.eventType == EventType.grooming.rawValue ||
            matchesAny(text, ["护理", "groom", "pflege", "洗", "刷", "剪", "耳", "梳"])
        guard isGrooming else { return false }
        switch type {
        case .teeth:
            return matchesAny(text, ["刷牙", "teeth", "tooth", "zahn"])
        case .nails:
            return matchesAny(text, ["剪甲", "剪", "nail", "claw", "kralle"])
        case .ears:
            return matchesAny(text, ["清耳", "耳", "ear", "ohr"])
        case .brushing:
            return matchesAny(text, ["梳", "brush", "comb", "bürst"])
        case .bath:
            return matchesAny(text, ["洗", "澡", "bath", "shower", "bad"])
        }
    }

    private static func normalizedText(for event: Event) -> String {
        "\(event.title) \(event.eventType)".lowercased()
    }

    private static func matchesAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0.lowercased()) }
    }
}

extension CareEventService {
    @MainActor
    static func normalizedTargets(_ targets: [Pet], fallback: Pet) -> [Pet] {
        SharedPetTargetResolver.normalizedTargets(targets, fallback: fallback)
    }

    @MainActor
    static func stockOwnerPet(for targets: [Pet], preferred: Pet, foodKind: FeedFoodKind, context: ModelContext) -> Pet {
        let records = fetchQuickActionReminderModelsOrLog(
            FetchDescriptor<PetFoodRecord>(),
            context: context,
            operation: "fetch food records for stock owner"
        )
        if FeedStockCalculator.activeStockRecord(for: preferred, foodKind: foodKind, foodRecords: records) != nil {
            return preferred
        }
        return targets.first { FeedStockCalculator.activeStockRecord(for: $0, foodKind: foodKind, foodRecords: records) != nil } ?? preferred
    }
}

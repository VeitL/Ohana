//
//  CarePlanCalendarSync.swift
//  Ohana
//
//  将间隔类护理计划同步为 SwiftData `Event`，在应用内「日历」页可见。
//

import Foundation
import SwiftData

enum CarePlanCalendarSync {
    nonisolated static let waterMaintenanceKinds: Set<String> = ["waterChange", "filterClean", "filterReplace"]

    struct PendingSideEffects {
        fileprivate var userDefaultsSets: [(key: String, value: String)] = []

        static let none = PendingSideEffects()

        fileprivate mutating func set(_ value: String, forKey key: String) {
            userDefaultsSets.append((key, value))
        }

        fileprivate mutating func merge(_ other: PendingSideEffects) {
            userDefaultsSets.append(contentsOf: other.userDefaultsSets)
        }

        func commit() {
            for item in userDefaultsSets {
                UserDefaults.standard.set(item.value, forKey: item.key)
            }
        }
    }

    @MainActor
    private static func fetchOrLog<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        context: ModelContext,
        operation: String
    ) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "CarePlanCalendarSync failed to \(operation): \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }

    private nonisolated static func eventStorageKey(kind: String, petKey: String) -> String {
        "careCalendarEventId_\(kind)_\(petKey)"
    }

    private static func defaultSuppressionKey(kind: String, petKey: String) -> String {
        "careCalendarDefaultSuppressed_\(kind)_\(petKey)"
    }

    private static func existingEvent(uuid: UUID, context: ModelContext) -> Event? {
        var d = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == uuid })
        d.fetchLimit = 1
        return fetchOrLog(d, context: context, operation: "fetch existing event").first
    }

    @discardableResult
    private static func tombstoneAndDelete(
        _ event: Event,
        context: ModelContext,
        deletedAt: Date = Date()
    ) -> DomainScheduleDeleteResult {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventMutation(
            event: event,
            writeKind: .care,
            source: .domainService,
            context: context
        ) else { return .notDeleted }
        let result = DomainScheduleWriter.deleteEvent(event, mutation: mutation, context: context, deletedAt: deletedAt)
        DomainScheduleEffectsDispatcher.dispatch(delete: result)
        return result
    }

    @discardableResult
    private static func tombstoneAndDelete(
        _ reminder: Reminder,
        context: ModelContext,
        deletedAt: Date = Date()
    ) -> DomainScheduleDeleteResult {
        guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingReminderMutation(
            reminder: reminder,
            writeKind: .care,
            source: .domainService,
            context: context
        ) else { return .notDeleted }
        let result = DomainScheduleWriter.deleteReminder(reminder, mutation: mutation, context: context, deletedAt: deletedAt)
        DomainScheduleEffectsDispatcher.dispatch(delete: result)
        return result
    }

    private static func canWriteActiveCarePlan(for pet: Pet) -> Bool {
        MemberWritePolicy.disposition(pet: pet, intent: .activeOnly).allowsDerivedEffects
    }

    static func removeActiveCalendarPlans(for pet: Pet, context: ModelContext) {
        let petKey = pet.id.uuidString
        for kind in knownDefaultPlanKinds {
            removeCalendarPlan(kind: kind, petKey: petKey, context: context)
            if let defaultKind = kind.split(separator: "_").last.map(String.init) {
                removeLegacyDefaultPlanEvents(kind: defaultKind, pet: pet, context: context)
            }
        }
        for kind in ["waterChange", "filterClean", "filterReplace", "litterFull", "scoop", "play"] {
            removeCalendarPlan(kind: kind, petKey: petKey, context: context)
        }
    }

    @discardableResult
    static func removeCalendarPlan(kind: String, petKey: String, context: ModelContext) -> Bool {
        let key = eventStorageKey(kind: kind, petKey: petKey)
        guard let idStr = UserDefaults.standard.string(forKey: key),
              let uuid = UUID(uuidString: idStr),
              let ev = existingEvent(uuid: uuid, context: context) else {
            UserDefaults.standard.removeObject(forKey: key)
            return true
        }
        tombstoneAndDelete(ev, context: context)
        if saveCalendarSyncChanges(context: context) {
            UserDefaults.standard.removeObject(forKey: key)
            return true
        }
        return false
    }

    static func suppressDefaultPlan(kind: String, pet: Pet, context: ModelContext) {
        let petKey = pet.id.uuidString
        UserDefaults.standard.set(true, forKey: defaultSuppressionKey(kind: kind, petKey: petKey))
        removeCalendarPlan(kind: "default_\(kind)", petKey: petKey, context: context)
        removeLegacyDefaultPlanEvents(kind: kind, pet: pet, context: context)
    }

    static func reconcileDefaultPlanOverrides(for pet: Pet, context: ModelContext) {
        guard canWriteActiveCarePlan(for: pet) else {
            removeActiveCalendarPlans(for: pet, context: context)
            return
        }
        let petKey = pet.id.uuidString
        for kind in ["feed", "drink", "litter", "waterChange", "filter", "groom", "play"] where shouldSkipDefaultPlan(kind: kind, petKey: petKey, context: context) {
            removeCalendarPlan(kind: "default_\(kind)", petKey: petKey, context: context)
            removeLegacyDefaultPlanEvents(kind: kind, pet: pet, context: context)
        }
    }

    static func shouldShowModeScopedPlanOccurrence(
        _ event: Event,
        occurrenceDate: Date,
        allEvents: [Event],
        pets: [Pet],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else {
            return true
        }

        if FeedRuleMetadata.isAutoFeederEvent(event, pet: pet) {
            guard FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now, calendar: calendar) == .autoFeeder else {
                return false
            }
            return occurrenceMoment(for: event, occurrenceDate: occurrenceDate, calendar: calendar) > now
        }

        if FeedRuleMetadata.isManualReminderEvent(event, pet: pet) {
            return FeedOperatingMode.resolved(pet: pet, allEvents: allEvents, now: now, calendar: calendar) == .manualReminder
        }

        guard calendar.startOfDay(for: occurrenceDate) >= calendar.startOfDay(for: now) else {
            return true
        }

        if WaterPlanWriter.isPlanEvent(event, pet: pet) {
            return WaterRuleState(pet: pet, allEvents: allEvents, now: now, calendar: calendar).operatingMode == .reminder
        }

        return true
    }

    private static func occurrenceMoment(for event: Event, occurrenceDate: Date, calendar: Calendar) -> Date {
        guard event.recurrenceDays > 0 else { return event.startDate }
        let time = calendar.dateComponents([.hour, .minute, .second], from: event.startDate)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: calendar.startOfDay(for: occurrenceDate)
        ) ?? occurrenceDate
    }

    private static func shouldSkipDefaultPlan(kind: String, petKey: String, context: ModelContext) -> Bool {
        if UserDefaults.standard.bool(forKey: defaultSuppressionKey(kind: kind, petKey: petKey)) {
            return true
        }

        switch kind {
        case "feed":
            return hasCustomFeedPlan(petKey: petKey, context: context)
        case "drink":
            return hasCustomWaterPlan(petKey: petKey, context: context)
        case "litter":
            return storedCalendarPlanExists(kind: "scoop", petKey: petKey, context: context)
        case "waterChange":
            return storedCalendarPlanExists(kind: "waterChange", petKey: petKey, context: context)
        case "filter":
            return storedCalendarPlanExists(kind: "filterClean", petKey: petKey, context: context) ||
                storedCalendarPlanExists(kind: "filterReplace", petKey: petKey, context: context)
        case "play":
            return storedCalendarPlanExists(kind: "play", petKey: petKey, context: context)
        default:
            return false
        }
    }

    private static func storedCalendarPlanExists(kind: String, petKey: String, context: ModelContext) -> Bool {
        let key = eventStorageKey(kind: kind, petKey: petKey)
        guard let idStr = UserDefaults.standard.string(forKey: key),
              let uuid = UUID(uuidString: idStr) else { return false }
        if existingEvent(uuid: uuid, context: context) != nil {
            return true
        }
        UserDefaults.standard.removeObject(forKey: key)
        return false
    }

    nonisolated static func waterMaintenanceKind(for event: Event, pet: Pet) -> String? {
        let petKey = pet.id.uuidString
        guard MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: petKey) else { return nil }
        return waterMaintenanceKind(for: event, petKey: petKey)
    }

    /// Stable identity check for an explicit feature plan persisted through
    /// this service. Default recommendation keys use the `default_` prefix and
    /// remain distinguishable from user-enabled plans.
    nonisolated static func isStoredPlan(_ event: Event, kind: String, pet: Pet) -> Bool {
        guard MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
            event,
            petId: pet.id.uuidString
        ) else { return false }
        return UserDefaults.standard.string(
            forKey: eventStorageKey(kind: kind, petKey: pet.id.uuidString)
        ) == event.id.uuidString
    }

    nonisolated static func waterMaintenanceKind(for event: Event) -> String? {
        guard let petId = DomainEntityLinkRegistry.resolvedId(for: DomainEntityLink(event: event), role: .directPet) else {
            return nil
        }
        return waterMaintenanceKind(for: event, petKey: petId.uuidString)
    }

    private nonisolated static func waterMaintenanceKind(for event: Event, petKey: String) -> String? {
        waterMaintenanceKinds.first { kind in
            UserDefaults.standard.string(forKey: eventStorageKey(kind: kind, petKey: petKey)) == event.id.uuidString
        }
    }

    static func isWaterMaintenancePlan(_ event: Event, pet: Pet, kinds: Set<String>) -> Bool {
        guard let kind = waterMaintenanceKind(for: event, pet: pet) else { return false }
        return kinds.contains(kind)
    }

    static func waterMaintenancePlanEvents(pet: Pet, kinds: Set<String>, allEvents: [Event]) -> [Event] {
        allEvents
            .filter { isWaterMaintenancePlan($0, pet: pet, kinds: kinds) }
            .sorted { $0.startDate < $1.startDate }
    }

    private static func hasCustomFeedPlan(petKey: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Event>()
        return fetchOrLog(descriptor, context: context, operation: "fetch custom feed plan").contains {
            MemberLifecycleActiveScheduleResolver.eventBelongsToPet($0, petId: petKey) &&
                !$0.feedRuleKindRaw.isEmpty
        }
    }

    private static func hasCustomWaterPlan(petKey: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<Event>()
        return fetchOrLog(descriptor, context: context, operation: "fetch custom water plan").contains {
            DomainEntityLinkRegistry.role(for: $0) == .petWaterPlan &&
                MemberLifecycleActiveScheduleResolver.eventBelongsToPet($0, petId: petKey)
        }
    }

    private static func removeLegacyDefaultPlanEvents(kind: String, pet: Pet, context: ModelContext) {
        let petKey = pet.id.uuidString
        let titles = defaultPlanTitleCandidates(kind: kind, pet: pet)
        guard !titles.isEmpty else { return }

        let descriptor = FetchDescriptor<Event>()
        let events = fetchOrLog(descriptor, context: context, operation: "fetch legacy default plan events")
        var didDelete = false
        for event in events where MemberLifecycleActiveScheduleResolver.eventBelongsToPet(event, petId: petKey) && titles.contains(event.title) {
            if tombstoneAndDelete(event, context: context).didDelete {
                didDelete = true
            }
        }
        if didDelete {
            _ = saveCalendarSyncChanges(context: context)
        }
    }

    private static func defaultPlanTitleCandidates(kind: String, pet: Pet) -> Set<String> {
        let tokens: [CarePlanTitleToken] = switch kind {
        case "feed":
            [.feed]
        case "drink":
            [.drink]
        case "litter":
            [.litter]
        case "waterChange":
            [.waterChange]
        case "filter":
            [.filterCheck]
        case "groom":
            [.groom, .hairballGroom]
        case "play":
            [.play]
        default:
            []
        }
        var candidates = Set(tokens.flatMap { localizedPlanTitleCandidates($0).map { eventTitle(pet: pet, title: $0) } })
        switch kind {
        case "drink":
            candidates.insert("\(pet.name) 喂水")
        case "litter":
            candidates.insert("\(pet.name) 清理厕所")
        case "play":
            candidates.insert("\(pet.name) 互动")
            candidates.insert("\(pet.name) 放飞互动")
        default:
            break
        }
        return candidates
    }

    private static func upsert(
        pet: Pet,
        kind: String,
        title: String,
        startDate: Date,
        recurrenceDays: Int,
        eventType: EventType = .daily,
        context: ModelContext,
        saveChanges: Bool = true
    ) -> PendingSideEffects {
        var sideEffects = PendingSideEffects()
        let petKey = pet.id.uuidString
        guard canWriteActiveCarePlan(for: pet) else {
            removeCalendarPlan(kind: kind, petKey: petKey, context: context)
            return .none
        }
        let createIntent = DomainScheduleCreateIntent(
            title: title,
            startDate: startDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petKey,
            recurrenceDays: max(1, recurrenceDays),
            writeKind: .care,
            source: .domainService
        )
        let key = eventStorageKey(kind: kind, petKey: petKey)
        if let idStr = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: idStr),
           let ev = existingEvent(uuid: uuid, context: context) {
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
                event: ev,
                intent: createIntent,
                writeKind: .care,
                context: context
            ) else { return .none }
            DomainScheduleWriter.updateEvent(ev, intent: createIntent, mutation: mutation)
            if saveChanges {
                _ = saveCalendarSyncChanges(context: context)
            }
            return .none
        }
        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: createIntent,
            context: context
        ) else { return .none }
        let ev = DomainScheduleWriter.createEvent(plan: plan, context: context).event
        if saveChanges {
            if saveCalendarSyncChanges(context: context) {
                UserDefaults.standard.set(ev.id.uuidString, forKey: key)
            }
        } else {
            sideEffects.set(ev.id.uuidString, forKey: key)
        }
        return sideEffects
    }

    @discardableResult
    private static func upsertWithSingleReminder(
        pet: Pet,
        kind: String,
        title: String,
        startDate: Date,
        recurrenceDays: Int,
        eventType: EventType = .daily,
        preferredEventID: UUID? = nil,
        context: ModelContext
    ) -> Event? {
        let petKey = pet.id.uuidString
        guard canWriteActiveCarePlan(for: pet) else {
            removeCalendarPlan(kind: kind, petKey: petKey, context: context)
            return nil
        }
        let key = eventStorageKey(kind: kind, petKey: petKey)
        let reminderDate = morningReminderDate(on: startDate)
        let createIntent = DomainScheduleCreateIntent(
            title: title,
            startDate: startDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petKey,
            recurrenceDays: max(1, recurrenceDays),
            reminderDates: [reminderDate],
            writeKind: .care,
            source: .domainService
        )

        let storedEvent = UserDefaults.standard.string(forKey: key)
            .flatMap(UUID.init(uuidString:))
            .flatMap { existingEvent(uuid: $0, context: context) }
        let recoveredEvent = preferredEventID.flatMap { existingEvent(uuid: $0, context: context) }
        if let ev = storedEvent ?? recoveredEvent {
            guard let mutation = DomainScheduleWriteAuthorizer.authorizeExistingEventUpdate(
                event: ev,
                intent: createIntent,
                writeKind: .care,
                context: context
            ) else { return nil }
            DomainScheduleWriter.updateEvent(ev, intent: createIntent, mutation: mutation)

            if let reminder = ev.reminders.first {
                DomainScheduleWriter.resetReminderToPending(
                    reminder,
                    scheduledAt: reminderDate,
                    mutation: mutation,
                    resetAt: Date(),
                    context: context
                )
                for extra in ev.reminders.dropFirst() {
                    tombstoneAndDelete(extra, context: context)
                }
            } else {
                DomainScheduleWriter.createReminder(
                    for: ev,
                    scheduledAt: reminderDate,
                    mutation: mutation,
                    context: context
                )
            }
            guard saveCalendarSyncChanges(context: context) else { return nil }
            UserDefaults.standard.set(ev.id.uuidString, forKey: key)
            return ev
        }

        guard let plan = DomainScheduleWriteAuthorizer.authorizeCreate(
            intent: createIntent,
            context: context
        ) else { return nil }
        let ev = DomainScheduleWriter.createEvent(plan: plan, context: context).event
        if let preferredEventID { ev.id = preferredEventID }
        guard saveCalendarSyncChanges(context: context) else { return nil }
        UserDefaults.standard.set(ev.id.uuidString, forKey: key)
        return ev
    }

    @discardableResult
    private static func saveCalendarSyncChanges(context: ModelContext) -> Bool {
        let saveResult = context.safeSaveResult(publishFailureEvent: true)
        guard saveResult.didSave else {
            context.rollback()
            return false
        }
        return true
    }

    private static func morningReminderDate(on date: Date) -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
    }

    private static func nextCycleDate(from base: Date, intervalDays: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var next = cal.date(byAdding: .day, value: max(1, intervalDays), to: cal.startOfDay(for: base)) ?? base
        while next < today {
            next = cal.date(byAdding: .day, value: max(1, intervalDays), to: next) ?? next
        }
        return next
    }

    private struct DefaultPlanItem {
        let kind: String
        let title: String
        let recurrenceDays: Int
        let eventType: EventType
    }

    private enum CarePlanTitleToken {
        case feed
        case drink
        case walk
        case dogHighEnergyExercise
        case dogShortNoseWalk
        case dogLightWalk
        case externalDeworm
        case internalDeworm
        case vaccine
        case groom
        case hairballGroom
        case litter
        case weight
        case waterChange
        case filterCheck
        case temperature
        case cage
        case misting
        case substrate
        case shed
        case breedRiskJointWeight
        case breedRiskBreathingSkin
        case breedRiskDental
        case breedRiskWeightUrine
        case breedRiskHairball
        case breedRiskTeethAppetite
        case breedRiskFeatherBreathing
        case breedRiskHabitat
        case breedRiskWaterQuality
        case filterClean
        case filterReplace
        case litterFullChange
        case scoopPlan
        case play
        case playPlan
    }

    private nonisolated static func eventTitle(pet: Pet, title: String) -> String {
        "\(pet.name) \(title)"
    }

    private nonisolated static func localizedPlanTitleCandidates(_ token: CarePlanTitleToken) -> Set<String> {
        Set(AppLanguage.supported.map { localizedPlanTitle(token, l: L10n($0.code)) })
    }

    private nonisolated static func localizedPlanTitle(_ token: CarePlanTitleToken, l: L10n = .current) -> String {
        switch token {
        case .feed:
            l.tr(zh: "喂食", en: "Feeding", de: "Fütterung")
        case .drink:
            l.tr(zh: "补充饮水", en: "Water refill", de: "Wasser auffüllen")
        case .walk:
            l.tr(zh: "遛狗", en: "Walk", de: "Spaziergang")
        case .dogHighEnergyExercise:
            l.tr(zh: "高强度运动/嗅闻训练", en: "High-energy walk/sniff training", de: "Auslastung/Schnüffeltraining")
        case .dogShortNoseWalk:
            l.tr(zh: "短鼻犬温和散步", en: "Gentle short-nose walk", de: "Sanfter Kurzschnauzen-Spaziergang")
        case .dogLightWalk:
            l.tr(zh: "轻量散步", en: "Light walk", de: "Leichter Spaziergang")
        case .externalDeworm:
            l.tr(zh: "体外驱虫", en: "External deworming", de: "Äußere Entwurmung")
        case .internalDeworm:
            l.tr(zh: "体内驱虫", en: "Internal deworming", de: "Innere Entwurmung")
        case .vaccine:
            l.tr(zh: "疫苗复查", en: "Vaccine check", de: "Impfcheck")
        case .groom:
            l.tr(zh: "毛发护理", en: "Grooming", de: "Fellpflege")
        case .hairballGroom:
            l.tr(zh: "毛球/毛发护理", en: "Hairball/grooming care", de: "Haarballen/Fellpflege")
        case .litter:
            l.tr(zh: "铲屎", en: "Litter scoop", de: "Klo säubern")
        case .weight:
            l.tr(zh: "体重记录", en: "Weight log", de: "Gewicht erfassen")
        case .waterChange:
            l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterCheck:
            l.tr(zh: "过滤检查", en: "Filter check", de: "Filtercheck")
        case .temperature:
            l.tr(zh: "水温检查", en: "Temperature check", de: "Temperaturcheck")
        case .cage:
            l.tr(zh: "清理鸟笼", en: "Cage cleaning", de: "Käfig reinigen")
        case .misting:
            l.tr(zh: "补水/保湿", en: "Hydration/misting", de: "Befeuchten/Sprühen")
        case .substrate:
            l.tr(zh: "环境清洁", en: "Habitat cleaning", de: "Terrarium reinigen")
        case .shed:
            l.tr(zh: "蜕皮观察", en: "Shedding check", de: "Häutungscheck")
        case .breedRiskJointWeight:
            l.tr(zh: "关节/体重观察", en: "Joint/weight check", de: "Gelenk-/Gewichtscheck")
        case .breedRiskBreathingSkin:
            l.tr(zh: "呼吸/皮肤褶皱检查", en: "Breathing/skin-fold check", de: "Atem-/Hautfaltencheck")
        case .breedRiskDental:
            l.tr(zh: "牙齿检查", en: "Dental check", de: "Zahncheck")
        case .breedRiskWeightUrine:
            l.tr(zh: "体重/尿量观察", en: "Weight/urine check", de: "Gewicht-/Urincheck")
        case .breedRiskHairball:
            l.tr(zh: "毛球/皮肤观察", en: "Hairball/skin check", de: "Haarballen-/Hautcheck")
        case .breedRiskTeethAppetite:
            l.tr(zh: "牙齿/食欲观察", en: "Teeth/appetite check", de: "Zähne-/Appetitcheck")
        case .breedRiskFeatherBreathing:
            l.tr(zh: "羽毛/呼吸观察", en: "Feather/breathing check", de: "Feder-/Atemcheck")
        case .breedRiskHabitat:
            l.tr(zh: "环境/进食观察", en: "Habitat/feeding check", de: "Habitat-/Fütterungscheck")
        case .breedRiskWaterQuality:
            l.tr(zh: "水质/食欲观察", en: "Water-quality/appetite check", de: "Wasserqualität-/Appetitcheck")
        case .filterClean:
            l.tr(zh: "清洗滤芯", en: "Clean filter", de: "Filter reinigen")
        case .filterReplace:
            l.tr(zh: "更换滤芯", en: "Replace filter", de: "Filter wechseln")
        case .litterFullChange:
            l.tr(zh: "换猫砂", en: "Litter change", de: "Streu wechseln")
        case .scoopPlan:
            l.tr(zh: "铲屎计划", en: "Scoop plan", de: "Klo-Plan")
        case .play:
            l.tr(zh: "陪玩", en: "Play time", de: "Spielzeit")
        case .playPlan:
            l.tr(zh: "陪玩计划", en: "Play plan", de: "Spielplan")
        }
    }

    @discardableResult
    static func ensureDefaultPlans(
        for pet: Pet,
        context: ModelContext,
        startDate: Date = Date(),
        saveChanges: Bool = true
    ) -> PendingSideEffects {
        guard canWriteActiveCarePlan(for: pet) else {
            removeActiveCalendarPlans(for: pet, context: context)
            return .none
        }
        let items = defaultPlanItems(for: pet)
        guard !items.isEmpty else { return .none }
        var sideEffects = PendingSideEffects()
        let petKey = pet.id.uuidString
        let activeKinds = Set(items.map { "default_\($0.kind)" })
        for kind in knownDefaultPlanKinds where !activeKinds.contains(kind) {
            removeCalendarPlan(kind: kind, petKey: petKey, context: context)
            if let defaultKind = kind.split(separator: "_").last.map(String.init) {
                removeLegacyDefaultPlanEvents(kind: defaultKind, pet: pet, context: context)
            }
        }

        for item in items {
            if shouldSkipDefaultPlan(kind: item.kind, petKey: petKey, context: context) {
                removeCalendarPlan(kind: "default_\(item.kind)", petKey: petKey, context: context)
                continue
            }
            let firstDueDate = item.recurrenceDays > 1
                ? Calendar.current.date(byAdding: .day, value: item.recurrenceDays, to: startDate) ?? startDate
                : startDate
            sideEffects.merge(upsert(
                pet: pet,
                kind: "default_\(item.kind)",
                title: eventTitle(pet: pet, title: item.title),
                startDate: firstDueDate,
                recurrenceDays: item.recurrenceDays,
                eventType: item.eventType,
                context: context,
                saveChanges: saveChanges
            ))
        }
        return sideEffects
    }

    private nonisolated static let knownDefaultPlanKinds: Set<String> = [
        "default_feed",
        "default_drink",
        "default_walk",
        "default_externalDeworm",
        "default_internalDeworm",
        "default_vaccine",
        "default_groom",
        "default_litter",
        "default_play",
        "default_weight",
        "default_waterChange",
        "default_filter",
        "default_temperature",
        "default_cage",
        "default_misting",
        "default_substrate",
        "default_shed",
        "default_breedRiskJointWeight",
        "default_breedRiskBreathingSkin",
        "default_breedRiskDental",
        "default_breedRiskWeightUrine",
        "default_breedRiskHairball",
        "default_breedRiskTeethAppetite",
        "default_breedRiskFeatherBreathing",
        "default_breedRiskHabitat",
        "default_breedRiskWaterQuality"
    ]

    private nonisolated static let storedGeneratedPlanKinds: Set<String> = [
        "waterChange",
        "filterClean",
        "filterReplace",
        "litterFull",
        "scoop",
        "play"
    ]

    private nonisolated static func defaultPlanItems(for pet: Pet) -> [DefaultPlanItem] {
        switch normalizedSpecies(for: pet) {
        case "dog":
            let exercise = dogExercisePlan(for: pet)
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: localizedPlanTitle(.drink), recurrenceDays: 1, eventType: .daily),
                .init(kind: "walk", title: exercise.title, recurrenceDays: exercise.recurrenceDays, eventType: .daily),
                .init(kind: "externalDeworm", title: localizedPlanTitle(.externalDeworm), recurrenceDays: 30, eventType: .externalDeworming),
                .init(kind: "internalDeworm", title: localizedPlanTitle(.internalDeworm), recurrenceDays: 90, eventType: .internalDeworming),
                .init(kind: "vaccine", title: localizedPlanTitle(.vaccine), recurrenceDays: 365, eventType: .vaccine),
                .init(kind: "groom", title: localizedPlanTitle(.groom), recurrenceDays: groomingInterval(for: pet, fallback: 30), eventType: .grooming)
            ] + breedRiskPlanItems(for: pet)
        case "cat":
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: localizedPlanTitle(.drink), recurrenceDays: 1, eventType: .daily),
                .init(kind: "litter", title: localizedPlanTitle(.litter), recurrenceDays: 1, eventType: .litterBox),
                .init(kind: "weight", title: localizedPlanTitle(.weight), recurrenceDays: 30, eventType: .health),
                .init(kind: "groom", title: localizedPlanTitle(.hairballGroom), recurrenceDays: groomingInterval(for: pet, fallback: 14), eventType: .grooming)
            ] + breedRiskPlanItems(for: pet)
        case "fish":
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: 1, eventType: .daily),
                .init(kind: "waterChange", title: localizedPlanTitle(.waterChange), recurrenceDays: fishWaterChangeInterval(for: pet), eventType: .daily),
                .init(kind: "filter", title: localizedPlanTitle(.filterCheck), recurrenceDays: 14, eventType: .daily),
                .init(kind: "temperature", title: localizedPlanTitle(.temperature), recurrenceDays: 1, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        case "bird":
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: localizedPlanTitle(.drink), recurrenceDays: 1, eventType: .daily),
                .init(kind: "cage", title: localizedPlanTitle(.cage), recurrenceDays: 7, eventType: .daily),
                .init(kind: "weight", title: localizedPlanTitle(.weight), recurrenceDays: 14, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        case "rabbit":
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: localizedPlanTitle(.drink), recurrenceDays: 1, eventType: .daily),
                .init(kind: "litter", title: localizedPlanTitle(.litter), recurrenceDays: 1, eventType: .litterBox),
                .init(kind: "groom", title: localizedPlanTitle(.groom), recurrenceDays: groomingInterval(for: pet, fallback: 7), eventType: .grooming),
                .init(kind: "weight", title: localizedPlanTitle(.weight), recurrenceDays: 14, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        case "reptile":
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: reptileFeedingInterval(for: pet), eventType: .daily),
                .init(kind: "misting", title: localizedPlanTitle(.misting), recurrenceDays: 1, eventType: .daily),
                .init(kind: "temperature", title: localizedPlanTitle(.temperature), recurrenceDays: 1, eventType: .health),
                .init(kind: "substrate", title: localizedPlanTitle(.substrate), recurrenceDays: 7, eventType: .daily),
                .init(kind: "shed", title: localizedPlanTitle(.shed), recurrenceDays: 14, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        default:
            return [
                .init(kind: "feed", title: localizedPlanTitle(.feed), recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: localizedPlanTitle(.drink), recurrenceDays: 1, eventType: .daily),
                .init(kind: "weight", title: localizedPlanTitle(.weight), recurrenceDays: 30, eventType: .health)
            ]
        }
    }

    private nonisolated static func normalizedSpecies(for pet: Pet) -> String {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        if text.contains("狗") || text.contains("dog") { return "dog" }
        if text.contains("猫") || text.contains("cat") { return "cat" }
        if text.contains("鱼") || text.contains("fish") || text.contains("锦鲤") || text.contains("金鱼") { return "fish" }
        if text.contains("鸟") || text.contains("鹦鹉") || text.contains("文鸟") || text.contains("bird") { return "bird" }
        if text.contains("兔") || text.contains("rabbit") { return "rabbit" }
        if text.contains("爬") || text.contains("龟") || text.contains("蛇") || text.contains("蜥") || text.contains("守宫") || text.contains("reptile") { return "reptile" }
        return "generic"
    }

    private nonisolated static func dogExercisePlan(for pet: Pet) -> (title: String, recurrenceDays: Int) {
        let text = pet.breed.lowercased()
        if containsAny(text, ["边境牧羊", "哈士奇", "阿拉斯加", "澳大利亚牧羊", "拉布拉多", "金毛", "牧羊犬", "working", "husky", "retriever", "collie"]) {
            return (localizedPlanTitle(.dogHighEnergyExercise), 1)
        }
        if containsAny(text, ["法国斗牛", "英国斗牛", "巴哥", "bulldog", "pug"]) {
            return (localizedPlanTitle(.dogShortNoseWalk), 1)
        }
        if containsAny(text, ["吉娃娃", "博美", "马尔济斯", "约克夏", "小型", "chihuahua", "pomeranian", "maltese", "yorkshire"]) {
            return (localizedPlanTitle(.dogLightWalk), 1)
        }
        return (localizedPlanTitle(.walk), 1)
    }

    private nonisolated static func groomingInterval(for pet: Pet, fallback: Int) -> Int {
        let text = "\(pet.breed) \(pet.coatColor)".lowercased()
        if containsAny(text, ["长毛", "long", "缅因", "布偶", "贵宾", "比熊", "波斯", "挪威森林", "安哥拉"]) {
            return max(3, fallback / 2)
        }
        if containsAny(text, ["短毛", "无毛", "斯芬克斯", "sphynx"]) {
            return max(7, fallback)
        }
        return fallback
    }

    private nonisolated static func fishWaterChangeInterval(for pet: Pet) -> Int {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        if containsAny(text, ["金鱼", "锦鲤", "goldfish", "koi"]) { return 5 }
        return 7
    }

    private nonisolated static func reptileFeedingInterval(for pet: Pet) -> Int {
        let text = pet.breed.lowercased()
        if text.contains("蛇") || text.contains("python") || text.contains("snake") { return 7 }
        if text.contains("龟") || text.contains("turtle") { return 2 }
        return 3
    }

    private nonisolated static func breedRiskPlanItems(for pet: Pet) -> [DefaultPlanItem] {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        var items: [DefaultPlanItem] = []

        if containsAny(text, ["金毛", "拉布拉多", "德国牧羊", "柯基", "腊肠", "retriever", "labrador", "corgi", "dachshund", "shepherd"]) {
            items.append(.init(kind: "breedRiskJointWeight", title: localizedPlanTitle(.breedRiskJointWeight), recurrenceDays: 30, eventType: .health))
        }
        if containsAny(text, ["法国斗牛", "英国斗牛", "巴哥", "bulldog", "pug"]) {
            items.append(.init(kind: "breedRiskBreathingSkin", title: localizedPlanTitle(.breedRiskBreathingSkin), recurrenceDays: 14, eventType: .health))
        }
        if containsAny(text, ["泰迪", "贵宾", "比熊", "马尔济斯", "约克夏", "吉娃娃", "poodle", "bichon", "maltese", "yorkshire", "chihuahua"]) {
            items.append(.init(kind: "breedRiskDental", title: localizedPlanTitle(.breedRiskDental), recurrenceDays: 7, eventType: .health))
        }
        if containsAny(text, ["英国短毛", "美国短毛", "橘猫", "金渐层", "british shorthair", "american shorthair"]) {
            items.append(.init(kind: "breedRiskWeightUrine", title: localizedPlanTitle(.breedRiskWeightUrine), recurrenceDays: 30, eventType: .health))
        }
        if containsAny(text, ["布偶", "缅因", "波斯", "挪威森林", "ragdoll", "maine", "persian"]) {
            items.append(.init(kind: "breedRiskHairball", title: localizedPlanTitle(.breedRiskHairball), recurrenceDays: 7, eventType: .health))
        }
        if containsAny(text, ["兔", "rabbit"]) {
            items.append(.init(kind: "breedRiskTeethAppetite", title: localizedPlanTitle(.breedRiskTeethAppetite), recurrenceDays: 14, eventType: .health))
        }
        if containsAny(text, ["鸟", "鹦鹉", "文鸟", "bird", "parrot"]) {
            items.append(.init(kind: "breedRiskFeatherBreathing", title: localizedPlanTitle(.breedRiskFeatherBreathing), recurrenceDays: 14, eventType: .health))
        }
        if containsAny(text, ["爬", "龟", "蛇", "蜥", "守宫", "reptile", "turtle", "snake", "gecko"]) {
            items.append(.init(kind: "breedRiskHabitat", title: localizedPlanTitle(.breedRiskHabitat), recurrenceDays: 7, eventType: .health))
        }
        if containsAny(text, ["鱼", "金鱼", "锦鲤", "fish", "koi"]) {
            items.append(.init(kind: "breedRiskWaterQuality", title: localizedPlanTitle(.breedRiskWaterQuality), recurrenceDays: 7, eventType: .health))
        }

        return items
    }

    private nonisolated static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    /// 与铲屎计划一致：「起算日」与最近一次换水记录取较晚者为基准，再按间隔推算下次。
    static func syncWaterChangePlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, cycleAnchor: Date) {
        let petKey = pet.id.uuidString
        guard canWriteActiveCarePlan(for: pet) else {
            removeActiveCalendarPlans(for: pet, context: context)
            return
        }
        if intervalDays > 0 {
            suppressDefaultPlan(kind: "waterChange", pet: pet, context: context)
        }
        guard enabled, intervalDays > 0 else {
            removeCalendarPlan(kind: "waterChange", petKey: petKey, context: context)
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let anchorDay = cal.startOfDay(for: cycleAnchor)
        let last = pet.careLogs.filter { $0.type == CareType.waterChange.rawValue }.map(\.date).max()
        var base = anchorDay
        if let last { base = max(base, cal.startOfDay(for: last)) }
        var next = cal.date(byAdding: .day, value: intervalDays, to: base) ?? base
        while next < today {
            next = cal.date(byAdding: .day, value: intervalDays, to: next) ?? next
        }
        upsertWithSingleReminder(
            pet: pet,
            kind: "waterChange",
            title: eventTitle(pet: pet, title: localizedPlanTitle(.waterChange)),
            startDate: next,
            recurrenceDays: intervalDays,
            context: context
        )
    }

    static func syncFilterPlan(
        pet: Pet,
        context: ModelContext,
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        enabled: Bool
    ) {
        let petKey = pet.id.uuidString
        guard canWriteActiveCarePlan(for: pet) else {
            removeActiveCalendarPlans(for: pet, context: context)
            return
        }
        if cleanIntervalDays > 0 || replaceIntervalDays > 0 {
            suppressDefaultPlan(kind: "filter", pet: pet, context: context)
        }
        guard enabled, cleanIntervalDays > 0, replaceIntervalDays > 0 else {
            removeCalendarPlan(kind: "filterClean", petKey: petKey, context: context)
            removeCalendarPlan(kind: "filterReplace", petKey: petKey, context: context)
            return
        }

        let base = pet.careLogs
            .filter { $0.type == CareType.filterClean.rawValue }
            .map(\.date)
            .max() ?? Date()
        let nextClean = nextCycleDate(from: base, intervalDays: cleanIntervalDays)
        let nextReplace = nextCycleDate(from: base, intervalDays: replaceIntervalDays)

        upsertWithSingleReminder(
            pet: pet,
            kind: "filterClean",
            title: eventTitle(pet: pet, title: localizedPlanTitle(.filterClean)),
            startDate: nextClean,
            recurrenceDays: cleanIntervalDays,
            context: context
        )
        upsertWithSingleReminder(
            pet: pet,
            kind: "filterReplace",
            title: eventTitle(pet: pet, title: localizedPlanTitle(.filterReplace)),
            startDate: nextReplace,
            recurrenceDays: replaceIntervalDays,
            context: context
        )
    }

    @discardableResult
    static func syncLitterFullChangePlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, cycleAnchor: Date) -> Event? {
        let petKey = pet.id.uuidString
        guard canWriteActiveCarePlan(for: pet) else {
            removeActiveCalendarPlans(for: pet, context: context)
            return nil
        }
        guard enabled, intervalDays > 0 else {
            removeCalendarPlan(kind: "litterFull", petKey: petKey, context: context)
            return nil
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let anchorDay = cal.startOfDay(for: cycleAnchor)
        let lastTI = UserDefaults.standard.double(forKey: "lastLitterChangeDate_\(petKey)")
        let lastDay = lastTI > 0 ? cal.startOfDay(for: Date(timeIntervalSince1970: lastTI)) : nil
        var next: Date
        if let ld = lastDay {
            var d = cal.date(byAdding: .day, value: intervalDays, to: ld) ?? ld
            while d < today {
                d = cal.date(byAdding: .day, value: intervalDays, to: d) ?? d
            }
            next = d
        } else {
            var d = anchorDay
            while d < today {
                d = cal.date(byAdding: .day, value: intervalDays, to: d) ?? d
            }
            next = d
        }
        return upsertWithSingleReminder(
            pet: pet,
            kind: "litterFull",
            title: eventTitle(pet: pet, title: localizedPlanTitle(.litterFullChange)),
            startDate: next,
            recurrenceDays: intervalDays,
            context: context
        )
    }

    static func persistScoopPlanEvent(
        pet: Pet,
        context: ModelContext,
        intervalDays: Int,
        startDate: Date,
        preferredEventID: UUID? = nil
    ) -> Event? {
        upsertWithSingleReminder(
            pet: pet,
            kind: "scoop",
            title: eventTitle(pet: pet, title: localizedPlanTitle(.scoopPlan)),
            startDate: startDate,
            recurrenceDays: intervalDays,
            preferredEventID: preferredEventID,
            context: context
        )
    }

    @discardableResult
    static func syncPlayPlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, anchor: Date) -> Event? {
        let petKey = pet.id.uuidString
        guard canWriteActiveCarePlan(for: pet) else {
            removeActiveCalendarPlans(for: pet, context: context)
            return nil
        }
        if intervalDays > 0 {
            suppressDefaultPlan(kind: "play", pet: pet, context: context)
        }
        guard enabled, intervalDays > 0 else {
            removeCalendarPlan(kind: "play", petKey: petKey, context: context)
            return nil
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let anchorDay = cal.startOfDay(for: anchor)
        let last = pet.careLogs.filter { $0.type == CareType.play.rawValue }.map(\.date).max()
        var base = anchorDay
        if let last { base = max(base, cal.startOfDay(for: last)) }
        var next = cal.date(byAdding: .day, value: intervalDays, to: base) ?? base
        while next < today {
            next = cal.date(byAdding: .day, value: intervalDays, to: next) ?? next
        }
        return upsertWithSingleReminder(
            pet: pet,
            kind: "play",
            title: eventTitle(pet: pet, title: localizedPlanTitle(.playPlan)),
            startDate: next,
            recurrenceDays: intervalDays,
            context: context
        )
    }
}

extension CarePlanCalendarSync {
    nonisolated static func storedDefaultCalendarPlanEventIDs(for petID: UUID) -> [UUID] {
        storedCalendarPlanEventIDs(kinds: knownDefaultPlanKinds, petID: petID)
    }

    nonisolated static func storedExplicitCalendarPlanEventIDs(for petID: UUID) -> [UUID] {
        storedCalendarPlanEventIDs(kinds: storedGeneratedPlanKinds, petID: petID)
    }

    nonisolated static func defaultGeneratedCalendarPlanTitles(for pet: Pet) -> Set<String> {
        Set(defaultPlanItems(for: pet).map { eventTitle(pet: pet, title: $0.title) })
    }

    private nonisolated static func storedCalendarPlanEventIDs(
        kinds: Set<String>,
        petID: UUID
    ) -> [UUID] {
        let petKey = petID.uuidString
        return kinds.sorted().compactMap { kind in
            UserDefaults.standard.string(forKey: eventStorageKey(kind: kind, petKey: petKey))
                .flatMap(UUID.init(uuidString:))
        }
    }

    /// Calendar display boundary: default recommendation events are implementation
    /// scaffolding, while explicit feature plans remain user-visible.
    nonisolated static func isDefaultGeneratedCalendarPlan(_ event: Event, pets: [Pet]) -> Bool {
        isDefaultGeneratedCalendarPlan(event, pets: pets, hasReminder: !event.reminders.isEmpty)
    }

    nonisolated static func isDefaultGeneratedCalendarPlan(
        _ event: Event,
        pets: [Pet],
        hasReminder: Bool
    ) -> Bool {
        guard let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else { return false }
        let petKey = pet.id.uuidString
        if knownDefaultPlanKinds.contains(where: { kind in
            UserDefaults.standard.string(forKey: eventStorageKey(kind: kind, petKey: petKey)) == event.id.uuidString
        }) {
            return true
        }
        guard event.recurrenceDays > 0, event.feedRuleKindRaw.isEmpty, !hasReminder else { return false }
        let generatedTitles = defaultGeneratedCalendarPlanTitles(for: pet)
        return generatedTitles.contains(event.title)
    }

    nonisolated static func isGeneratedCalendarPlan(_ event: Event, pets: [Pet]) -> Bool {
        isGeneratedCalendarPlan(event, pets: pets, hasReminder: !event.reminders.isEmpty)
    }

    nonisolated static func isGeneratedCalendarPlan(
        _ event: Event,
        pets: [Pet],
        hasReminder: Bool
    ) -> Bool {
        if isDefaultGeneratedCalendarPlan(event, pets: pets, hasReminder: hasReminder) { return true }
        guard let pet = MemberLifecycleActiveScheduleResolver.petTarget(for: event, pets: pets) else { return false }
        let petKey = pet.id.uuidString
        return storedGeneratedPlanKinds.contains { kind in
            UserDefaults.standard.string(forKey: eventStorageKey(kind: kind, petKey: petKey)) == event.id.uuidString
        }
    }
}

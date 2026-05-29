//
//  CarePlanCalendarSync.swift
//  Ohana
//
//  将间隔类护理计划同步为 SwiftData `Event`，在应用内「日历」页可见。
//

import Foundation
import SwiftData

enum CarePlanCalendarSync {
    private static func eventStorageKey(kind: String, petKey: String) -> String {
        "careCalendarEventId_\(kind)_\(petKey)"
    }

    private static func defaultSuppressionKey(kind: String, petKey: String) -> String {
        "careCalendarDefaultSuppressed_\(kind)_\(petKey)"
    }

    private static func existingEvent(uuid: UUID, context: ModelContext) -> Event? {
        var d = FetchDescriptor<Event>(predicate: #Predicate<Event> { $0.id == uuid })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    static func removeCalendarPlan(kind: String, petKey: String, context: ModelContext) {
        let key = eventStorageKey(kind: kind, petKey: petKey)
        guard let idStr = UserDefaults.standard.string(forKey: key),
              let uuid = UUID(uuidString: idStr),
              let ev = existingEvent(uuid: uuid, context: context) else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        context.delete(ev)
        UserDefaults.standard.removeObject(forKey: key)
        context.safeSave()
    }

    static func suppressDefaultPlan(kind: String, pet: Pet, context: ModelContext) {
        let petKey = pet.id.uuidString
        UserDefaults.standard.set(true, forKey: defaultSuppressionKey(kind: kind, petKey: petKey))
        removeCalendarPlan(kind: "default_\(kind)", petKey: petKey, context: context)
        removeKnownDefaultPlanEvents(kind: kind, pet: pet, context: context)
    }

    static func reconcileDefaultPlanOverrides(for pet: Pet, context: ModelContext) {
        let petKey = pet.id.uuidString
        for kind in ["feed", "drink", "litter", "waterChange", "filter", "groom", "play"] where shouldSkipDefaultPlan(kind: kind, petKey: petKey, context: context) {
            removeCalendarPlan(kind: "default_\(kind)", petKey: petKey, context: context)
            removeKnownDefaultPlanEvents(kind: kind, pet: pet, context: context)
        }
    }

    /// Calendar display boundary:
    /// default recommendation events are implementation scaffolding, not user-created calendar items.
    /// Explicit plans created from feature settings use non-default keys or reminder-backed events and remain visible.
    static func isDefaultGeneratedCalendarPlan(_ event: Event, pets: [Pet]) -> Bool {
        let entityType = event.relatedEntityType.lowercased()
        guard entityType == EntityKind.pet.rawValue.lowercased() || entityType == "pet" else {
            return false
        }

        let petKey = event.relatedEntityId
        if knownDefaultPlanKinds.contains(where: { kind in
            UserDefaults.standard.string(forKey: eventStorageKey(kind: kind, petKey: petKey)) == event.id.uuidString
        }) {
            return true
        }

        guard
            event.recurrenceDays > 0,
            event.feedRuleKindRaw.isEmpty,
            event.reminders.isEmpty,
            let pet = pets.first(where: { $0.id.uuidString == petKey })
        else {
            return false
        }

        let generatedTitles = Set(defaultPlanItems(for: pet).map { "\(pet.name) \($0.title)" })
        return generatedTitles.contains(event.title)
    }

    static func shouldShowModeScopedPlanOccurrence(
        _ event: Event,
        occurrenceDate: Date,
        allEvents: [Event],
        pets: [Pet],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let pet = pets.first(where: { $0.id.uuidString == event.relatedEntityId }) else {
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

    private static func hasCustomFeedPlan(petKey: String, context: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> {
                $0.relatedEntityId == petKey && $0.feedRuleKindRaw != ""
            }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor).isEmpty) == false)
    }

    private static func hasCustomWaterPlan(petKey: String, context: ModelContext) -> Bool {
        let entityType = WaterPlanWriter.entityType
        var descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> {
                $0.relatedEntityId == petKey && $0.relatedEntityType == entityType
            }
        )
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor).isEmpty) == false)
    }

    private static func removeKnownDefaultPlanEvents(kind: String, pet: Pet, context: ModelContext) {
        let petKey = pet.id.uuidString
        let titles = defaultPlanTitleCandidates(kind: kind, pet: pet)
        guard !titles.isEmpty else { return }

        let descriptor = FetchDescriptor<Event>(
            predicate: #Predicate<Event> {
                $0.relatedEntityId == petKey
            }
        )
        guard let events = try? context.fetch(descriptor) else { return }
        var didDelete = false
        for event in events where titles.contains(event.title) {
            context.delete(event)
            didDelete = true
        }
        if didDelete {
            context.safeSave()
        }
    }

    private static func defaultPlanTitleCandidates(kind: String, pet: Pet) -> Set<String> {
        switch kind {
        case "feed":
            return ["\(pet.name) 喂食"]
        case "drink":
            return ["\(pet.name) 补充饮水", "\(pet.name) 喂水"]
        case "litter":
            return ["\(pet.name) 铲屎", "\(pet.name) 清理厕所"]
        case "waterChange":
            return ["\(pet.name) 换水"]
        case "filter":
            return ["\(pet.name) 过滤检查"]
        case "groom":
            return ["\(pet.name) 毛发护理", "\(pet.name) 毛球/毛发护理"]
        case "play":
            return ["\(pet.name) 陪玩", "\(pet.name) 互动", "\(pet.name) 放飞互动"]
        default:
            return []
        }
    }

    private static func upsert(
        pet: Pet,
        kind: String,
        title: String,
        startDate: Date,
        recurrenceDays: Int,
        eventType: EventType = .daily,
        context: ModelContext
    ) {
        let petKey = pet.id.uuidString
        let key = eventStorageKey(kind: kind, petKey: petKey)
        if let idStr = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: idStr),
           let ev = existingEvent(uuid: uuid, context: context) {
            ev.title = title
            ev.startDate = startDate
            ev.recurrenceDays = max(1, recurrenceDays)
            ev.relatedEntityType = EntityKind.pet.rawValue
            ev.relatedEntityId = petKey
            ev.eventType = eventType.rawValue
            ev.isAllDay = true
            context.safeSave()
            return
        }
        let ev = Event(
            title: title,
            startDate: startDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petKey
        )
        ev.recurrenceDays = max(1, recurrenceDays)
        context.insert(ev)
        UserDefaults.standard.set(ev.id.uuidString, forKey: key)
        context.safeSave()
    }

    private static func upsertWithSingleReminder(
        pet: Pet,
        kind: String,
        title: String,
        startDate: Date,
        recurrenceDays: Int,
        eventType: EventType = .daily,
        context: ModelContext
    ) {
        let petKey = pet.id.uuidString
        let key = eventStorageKey(kind: kind, petKey: petKey)
        let reminderDate = morningReminderDate(on: startDate)

        if let idStr = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: idStr),
           let ev = existingEvent(uuid: uuid, context: context) {
            ev.title = title
            ev.startDate = startDate
            ev.recurrenceDays = max(1, recurrenceDays)
            ev.relatedEntityType = EntityKind.pet.rawValue
            ev.relatedEntityId = petKey
            ev.eventType = eventType.rawValue
            ev.isAllDay = true

            if let reminder = ev.reminders.first {
                reminder.scheduledAt = reminderDate
                reminder.statusEnum = .pending
                reminder.completedAt = nil
                reminder.completedBy = ""
                for extra in ev.reminders.dropFirst() {
                    context.delete(extra)
                }
            } else {
                context.insert(Reminder(event: ev, scheduledAt: reminderDate))
            }
            context.safeSave()
            return
        }

        let ev = Event(
            title: title,
            startDate: startDate,
            isAllDay: true,
            eventType: eventType.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petKey
        )
        ev.recurrenceDays = max(1, recurrenceDays)
        context.insert(ev)
        context.insert(Reminder(event: ev, scheduledAt: reminderDate))
        UserDefaults.standard.set(ev.id.uuidString, forKey: key)
        context.safeSave()
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

    static func ensureDefaultPlans(for pet: Pet, context: ModelContext, startDate: Date = Date()) {
        let items = defaultPlanItems(for: pet)
        guard !items.isEmpty else { return }
        let petKey = pet.id.uuidString
        let activeKinds = Set(items.map { "default_\($0.kind)" })
        for kind in knownDefaultPlanKinds where !activeKinds.contains(kind) {
            removeCalendarPlan(kind: kind, petKey: petKey, context: context)
            if let defaultKind = kind.split(separator: "_").last.map(String.init) {
                removeKnownDefaultPlanEvents(kind: defaultKind, pet: pet, context: context)
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
            upsert(
                pet: pet,
                kind: "default_\(item.kind)",
                title: "\(pet.name) \(item.title)",
                startDate: firstDueDate,
                recurrenceDays: item.recurrenceDays,
                eventType: item.eventType,
                context: context
            )
        }
    }

    private static let knownDefaultPlanKinds: Set<String> = [
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

    private static func defaultPlanItems(for pet: Pet) -> [DefaultPlanItem] {
        switch normalizedSpecies(for: pet) {
        case "dog":
            let exercise = dogExercisePlan(for: pet)
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: "补充饮水", recurrenceDays: 1, eventType: .daily),
                .init(kind: "walk", title: exercise.title, recurrenceDays: exercise.recurrenceDays, eventType: .daily),
                .init(kind: "externalDeworm", title: "体外驱虫", recurrenceDays: 30, eventType: .externalDeworming),
                .init(kind: "internalDeworm", title: "体内驱虫", recurrenceDays: 90, eventType: .internalDeworming),
                .init(kind: "vaccine", title: "疫苗复查", recurrenceDays: 365, eventType: .vaccine),
                .init(kind: "groom", title: "毛发护理", recurrenceDays: groomingInterval(for: pet, fallback: 30), eventType: .grooming)
            ] + breedRiskPlanItems(for: pet)
        case "cat":
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: "补充饮水", recurrenceDays: 1, eventType: .daily),
                .init(kind: "litter", title: "铲屎", recurrenceDays: 1, eventType: .litterBox),
                .init(kind: "weight", title: "体重记录", recurrenceDays: 30, eventType: .health),
                .init(kind: "groom", title: "毛球/毛发护理", recurrenceDays: groomingInterval(for: pet, fallback: 14), eventType: .grooming)
            ] + breedRiskPlanItems(for: pet)
        case "fish":
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: 1, eventType: .daily),
                .init(kind: "waterChange", title: "换水", recurrenceDays: fishWaterChangeInterval(for: pet), eventType: .daily),
                .init(kind: "filter", title: "过滤检查", recurrenceDays: 14, eventType: .daily),
                .init(kind: "temperature", title: "水温检查", recurrenceDays: 1, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        case "bird":
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: "补充饮水", recurrenceDays: 1, eventType: .daily),
                .init(kind: "cage", title: "清理鸟笼", recurrenceDays: 7, eventType: .daily),
                .init(kind: "weight", title: "体重记录", recurrenceDays: 14, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        case "rabbit":
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: "补充饮水", recurrenceDays: 1, eventType: .daily),
                .init(kind: "litter", title: "清理厕所", recurrenceDays: 1, eventType: .litterBox),
                .init(kind: "groom", title: "毛发护理", recurrenceDays: groomingInterval(for: pet, fallback: 7), eventType: .grooming),
                .init(kind: "weight", title: "体重记录", recurrenceDays: 14, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        case "reptile":
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: reptileFeedingInterval(for: pet), eventType: .daily),
                .init(kind: "misting", title: "补水/保湿", recurrenceDays: 1, eventType: .daily),
                .init(kind: "temperature", title: "温湿度检查", recurrenceDays: 1, eventType: .health),
                .init(kind: "substrate", title: "环境清洁", recurrenceDays: 7, eventType: .daily),
                .init(kind: "shed", title: "蜕皮观察", recurrenceDays: 14, eventType: .health)
            ] + breedRiskPlanItems(for: pet)
        default:
            return [
                .init(kind: "feed", title: "喂食", recurrenceDays: 1, eventType: .daily),
                .init(kind: "drink", title: "补充饮水", recurrenceDays: 1, eventType: .daily),
                .init(kind: "weight", title: "体重记录", recurrenceDays: 30, eventType: .health)
            ]
        }
    }

    private static func normalizedSpecies(for pet: Pet) -> String {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        if text.contains("狗") || text.contains("dog") { return "dog" }
        if text.contains("猫") || text.contains("cat") { return "cat" }
        if text.contains("鱼") || text.contains("fish") || text.contains("锦鲤") || text.contains("金鱼") { return "fish" }
        if text.contains("鸟") || text.contains("鹦鹉") || text.contains("文鸟") || text.contains("bird") { return "bird" }
        if text.contains("兔") || text.contains("rabbit") { return "rabbit" }
        if text.contains("爬") || text.contains("龟") || text.contains("蛇") || text.contains("蜥") || text.contains("守宫") || text.contains("reptile") { return "reptile" }
        return "generic"
    }

    private static func dogExercisePlan(for pet: Pet) -> (title: String, recurrenceDays: Int) {
        let text = pet.breed.lowercased()
        if containsAny(text, ["边境牧羊", "哈士奇", "阿拉斯加", "澳大利亚牧羊", "拉布拉多", "金毛", "牧羊犬", "working", "husky", "retriever", "collie"]) {
            return ("高强度运动/嗅闻训练", 1)
        }
        if containsAny(text, ["法国斗牛", "英国斗牛", "巴哥", "bulldog", "pug"]) {
            return ("短鼻犬温和散步", 1)
        }
        if containsAny(text, ["吉娃娃", "博美", "马尔济斯", "约克夏", "小型", "chihuahua", "pomeranian", "maltese", "yorkshire"]) {
            return ("轻量散步", 1)
        }
        return ("遛狗", 1)
    }

    private static func groomingInterval(for pet: Pet, fallback: Int) -> Int {
        let text = "\(pet.breed) \(pet.coatColor)".lowercased()
        if containsAny(text, ["长毛", "long", "缅因", "布偶", "贵宾", "比熊", "波斯", "挪威森林", "安哥拉"]) {
            return max(3, fallback / 2)
        }
        if containsAny(text, ["短毛", "无毛", "斯芬克斯", "sphynx"]) {
            return max(7, fallback)
        }
        return fallback
    }

    private static func fishWaterChangeInterval(for pet: Pet) -> Int {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        if containsAny(text, ["金鱼", "锦鲤", "goldfish", "koi"]) { return 5 }
        return 7
    }

    private static func reptileFeedingInterval(for pet: Pet) -> Int {
        let text = pet.breed.lowercased()
        if text.contains("蛇") || text.contains("python") || text.contains("snake") { return 7 }
        if text.contains("龟") || text.contains("turtle") { return 2 }
        return 3
    }

    private static func breedRiskPlanItems(for pet: Pet) -> [DefaultPlanItem] {
        let text = "\(pet.species) \(pet.breed)".lowercased()
        var items: [DefaultPlanItem] = []

        if containsAny(text, ["金毛", "拉布拉多", "德国牧羊", "柯基", "腊肠", "retriever", "labrador", "corgi", "dachshund", "shepherd"]) {
            items.append(.init(kind: "breedRiskJointWeight", title: "关节/体重观察", recurrenceDays: 30, eventType: .health))
        }
        if containsAny(text, ["法国斗牛", "英国斗牛", "巴哥", "bulldog", "pug"]) {
            items.append(.init(kind: "breedRiskBreathingSkin", title: "呼吸/皮肤褶皱检查", recurrenceDays: 14, eventType: .health))
        }
        if containsAny(text, ["泰迪", "贵宾", "比熊", "马尔济斯", "约克夏", "吉娃娃", "poodle", "bichon", "maltese", "yorkshire", "chihuahua"]) {
            items.append(.init(kind: "breedRiskDental", title: "牙齿检查", recurrenceDays: 7, eventType: .health))
        }
        if containsAny(text, ["英国短毛", "美国短毛", "橘猫", "金渐层", "british shorthair", "american shorthair"]) {
            items.append(.init(kind: "breedRiskWeightUrine", title: "体重/尿量观察", recurrenceDays: 30, eventType: .health))
        }
        if containsAny(text, ["布偶", "缅因", "波斯", "挪威森林", "ragdoll", "maine", "persian"]) {
            items.append(.init(kind: "breedRiskHairball", title: "毛球/皮肤观察", recurrenceDays: 7, eventType: .health))
        }
        if containsAny(text, ["兔", "rabbit"]) {
            items.append(.init(kind: "breedRiskTeethAppetite", title: "牙齿/食欲观察", recurrenceDays: 14, eventType: .health))
        }
        if containsAny(text, ["鸟", "鹦鹉", "文鸟", "bird", "parrot"]) {
            items.append(.init(kind: "breedRiskFeatherBreathing", title: "羽毛/呼吸观察", recurrenceDays: 14, eventType: .health))
        }
        if containsAny(text, ["爬", "龟", "蛇", "蜥", "守宫", "reptile", "turtle", "snake", "gecko"]) {
            items.append(.init(kind: "breedRiskHabitat", title: "环境/进食观察", recurrenceDays: 7, eventType: .health))
        }
        if containsAny(text, ["鱼", "金鱼", "锦鲤", "fish", "koi"]) {
            items.append(.init(kind: "breedRiskWaterQuality", title: "水质/食欲观察", recurrenceDays: 7, eventType: .health))
        }

        return items
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }

    /// 与铲屎计划一致：「起算日」与最近一次换水记录取较晚者为基准，再按间隔推算下次。
    static func syncWaterChangePlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, cycleAnchor: Date) {
        let petKey = pet.id.uuidString
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
        upsertWithSingleReminder(pet: pet, kind: "waterChange", title: "\(pet.name) 换水", startDate: next, recurrenceDays: intervalDays, context: context)
    }

    static func syncFilterPlan(
        pet: Pet,
        context: ModelContext,
        cleanIntervalDays: Int,
        replaceIntervalDays: Int,
        enabled: Bool
    ) {
        let petKey = pet.id.uuidString
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
            title: "\(pet.name) 清洗滤芯",
            startDate: nextClean,
            recurrenceDays: cleanIntervalDays,
            context: context
        )
        upsertWithSingleReminder(
            pet: pet,
            kind: "filterReplace",
            title: "\(pet.name) 更换滤芯",
            startDate: nextReplace,
            recurrenceDays: replaceIntervalDays,
            context: context
        )
    }

    static func syncLitterFullChangePlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, cycleAnchor: Date) {
        let petKey = pet.id.uuidString
        guard enabled, intervalDays > 0 else {
            removeCalendarPlan(kind: "litterFull", petKey: petKey, context: context)
            return
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
        upsertWithSingleReminder(pet: pet, kind: "litterFull", title: "\(pet.name) 换猫砂", startDate: next, recurrenceDays: intervalDays, context: context)
    }

    static func syncScoopPlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, anchor: Date) {
        let petKey = pet.id.uuidString
        if intervalDays > 0 {
            suppressDefaultPlan(kind: "litter", pet: pet, context: context)
        }
        guard enabled, intervalDays > 0 else {
            removeCalendarPlan(kind: "scoop", petKey: petKey, context: context)
            return
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let anchorDay = cal.startOfDay(for: anchor)
        let last = pet.careLogs.filter { $0.type == CareType.litter.rawValue }.map(\.date).max()
        var base = anchorDay
        if let last { base = max(base, cal.startOfDay(for: last)) }
        var next = cal.date(byAdding: .day, value: intervalDays, to: base) ?? base
        while next < today {
            next = cal.date(byAdding: .day, value: intervalDays, to: next) ?? next
        }
        upsertWithSingleReminder(pet: pet, kind: "scoop", title: "\(pet.name) 铲屎计划", startDate: next, recurrenceDays: intervalDays, context: context)
    }

    static func syncPlayPlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, anchor: Date) {
        let petKey = pet.id.uuidString
        if intervalDays > 0 {
            suppressDefaultPlan(kind: "play", pet: pet, context: context)
        }
        guard enabled, intervalDays > 0 else {
            removeCalendarPlan(kind: "play", petKey: petKey, context: context)
            return
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
        upsertWithSingleReminder(pet: pet, kind: "play", title: "\(pet.name) 陪玩计划", startDate: next, recurrenceDays: intervalDays, context: context)
    }
}

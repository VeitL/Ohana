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
        }

        for item in items {
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
                .init(kind: "play", title: "陪玩", recurrenceDays: 1, eventType: .daily),
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
                .init(kind: "play", title: "放飞互动", recurrenceDays: 1, eventType: .daily),
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
                .init(kind: "play", title: "互动", recurrenceDays: 1, eventType: .daily),
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
        upsert(pet: pet, kind: "waterChange", title: "\(pet.name) 换水", startDate: next, recurrenceDays: intervalDays, context: context)
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
        upsert(pet: pet, kind: "litterFull", title: "\(pet.name) 换猫砂", startDate: next, recurrenceDays: intervalDays, context: context)
    }

    static func syncScoopPlan(pet: Pet, context: ModelContext, intervalDays: Int, enabled: Bool, anchor: Date) {
        let petKey = pet.id.uuidString
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
        upsert(pet: pet, kind: "scoop", title: "\(pet.name) 铲屎计划", startDate: next, recurrenceDays: intervalDays, context: context)
    }
}

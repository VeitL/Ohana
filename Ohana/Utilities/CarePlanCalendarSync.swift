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
            ev.eventType = EventType.daily.rawValue
            ev.isAllDay = true
            context.safeSave()
            return
        }
        let ev = Event(
            title: title,
            startDate: startDate,
            isAllDay: true,
            eventType: EventType.daily.rawValue,
            relatedEntityType: EntityKind.pet.rawValue,
            relatedEntityId: petKey
        )
        ev.recurrenceDays = max(1, recurrenceDays)
        context.insert(ev)
        UserDefaults.standard.set(ev.id.uuidString, forKey: key)
        context.safeSave()
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

//
//  PetTimelineModels.swift
//  Ohana
//
//  统一时间轴条目（岁月史书 / 详情页摘要 / 重要时刻页共用）
//

import SwiftUI

struct UnifiedLogItem: Identifiable {
    let id: UUID
    let date: Date
    let type: String
    let title: String
    let subtitle: String
    let iconName: String
    let color: Color
    var photos: [PetPhotoLog] = []
    var style: PetTimelineItemStyle = .rail
    var isHighlight: Bool = false
}

enum PetTimelineItemStyle {
    case story
    case rail
}

enum PetTimelineDisplayMode: String, CaseIterable, Identifiable {
    case highlights
    case memories
    case health
    case care
    case expense
    case all

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .highlights: return l.tr(zh: "高光", en: "Highlights", de: "Highlights")
        case .memories: return l.tr(zh: "回忆", en: "Memories", de: "Erinnerungen")
        case .health: return l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .care: return l.tr(zh: "照护", en: "Care", de: "Pflege")
        case .expense: return l.tr(zh: "花费", en: "Costs", de: "Kosten")
        case .all: return l.tr(zh: "全部", en: "All", de: "Alle")
        }
    }
}

enum PetTimelineMilestoneKind {
    case birthday
    case together
    case remembrance
    case user
    case photo
    case health
    case weight
}

struct PetTimelineArchiveSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let items: [UnifiedLogItem]
}

enum PetTimelineItemsBuilder {
    /// 构建统一时间轴；`limit` 为 nil 时不截断
    static func items(for pet: Pet, limit: Int? = nil) -> [UnifiedLogItem] {
        var list: [UnifiedLogItem] = []

        for w in pet.walkLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.startDate, type: "walk",
                title: "巡岛 · \(w.distanceText)", subtitle: w.durationText,
                iconName: "figure.walk", color: .goPrimary))
        }
        for p in pet.pottyLogs {
            list.append(UnifiedLogItem(id: p.id, date: p.date, type: "potty",
                title: "噗噗 · \(p.pottyType.emoji)\(p.pottyType.rawValue)", subtitle: "",
                iconName: "drop.fill", color: .goOrange))
        }
        for h in pet.healthLogs {
            list.append(UnifiedLogItem(id: h.id, date: h.date, type: "health",
                title: "\(h.healthLogType.emoji) \(h.type)",
                subtitle: h.note.isEmpty ? (h.vetName.isEmpty ? "" : h.vetName) : h.note,
                iconName: "heart.text.clipboard", color: .goTeal))
        }
        for e in pet.expenseLogs {
            list.append(UnifiedLogItem(id: e.id, date: e.date, type: "expense",
                title: "\(AppCurrency.format(e.amount, fractionDigits: 0)) · \(e.note.isEmpty ? e.category : e.note)",
                subtitle: e.category,
                iconName: "\(AppCurrency.systemIconName).fill", color: .goYellow))
        }
        for w in pet.weightLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.date, type: "weight",
                title: String(format: "体重 %.1f kg", w.weight), subtitle: "",
                iconName: "scalemass.fill", color: .goTeal))
        }
        for c in pet.careLogs {
            list.append(UnifiedLogItem(id: c.id, date: c.date, type: "care",
                title: "护理 · \(c.careType.emoji)\(c.careType.rawValue)", subtitle: c.note,
                iconName: "sparkles", color: .goPurple))
        }

        let sorted = list.sorted { $0.date > $1.date }
        if let limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    static func archiveSections(for pet: Pet, mode: PetTimelineDisplayMode, l: L10n) -> [PetTimelineArchiveSection] {
        let visibleItems = archiveItems(for: pet, mode: mode, l: l)
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleItems) { item in
            calendar.startOfDay(for: item.date)
        }

        return grouped
            .map { day, items in
                let sortedItems = items.sorted { $0.date > $1.date }
                return PetTimelineArchiveSection(
                    id: day.ISO8601Format(),
                    title: friendlyDayTitle(day, l: l),
                    subtitle: sectionSubtitle(for: day, count: sortedItems.count, l: l),
                    items: sortedItems
                )
            }
            .sorted { lhs, rhs in
                guard let left = grouped.keys.first(where: { $0.ISO8601Format() == lhs.id }),
                      let right = grouped.keys.first(where: { $0.ISO8601Format() == rhs.id })
                else { return lhs.title > rhs.title }
                return left > right
            }
    }

    static func archiveItems(for pet: Pet, mode: PetTimelineDisplayMode, l: L10n) -> [UnifiedLogItem] {
        let now = Date()
        let base = items(for: pet, limit: nil)
            .filter { isVisiblePast($0.date, now: now) }
            .map { item in
                var copy = item
                copy.style = .rail
                copy.isHighlight = mode == .all ? false : isImportant(item)
                return copy
            }
        let moments = memoryItems(for: pet, l: l, now: now)
        let generated = generatedMeaningfulMoments(for: pet, l: l, now: now)

        let all: [UnifiedLogItem]
        switch mode {
        case .highlights:
            all = (generated + moments + base.filter(isImportant)).map { item in
                var copy = item
                copy.style = .story
                copy.isHighlight = true
                return copy
            }
        case .memories:
            all = (generated + moments).map { item in
                var copy = item
                copy.style = .story
                copy.isHighlight = true
                return copy
            }
        case .health:
            all = base.filter { $0.type == "health" || $0.type == "weight" }.map { item in
                var copy = item
                copy.style = isImportant(item) ? .story : .rail
                copy.isHighlight = isImportant(item)
                return copy
            }
        case .care:
            all = base.filter { ["walk", "potty", "care"].contains($0.type) }
        case .expense:
            all = base.filter { $0.type == "expense" }
        case .all:
            all = (generated + moments + base).map { item in
                var copy = item
                copy.style = (item.type == "moment" || item.type == "milestone") ? .story : .rail
                copy.isHighlight = copy.style == .story || isImportant(item)
                return copy
            }
        }

        return all
            .filter { isVisiblePast($0.date, now: now) }
            .deduplicatedByDayTitle()
            .sorted { $0.date > $1.date }
    }

    private static func memoryItems(for pet: Pet, l: L10n, now: Date) -> [UnifiedLogItem] {
        let photoGroups = groupedPhotoLogs(for: pet, now: now)
        let photoItems = photoGroups.map { group -> UnifiedLogItem in
            let first = group[0]
            let note = first.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasImage = group.contains { renderableImageData($0.imageData) }
            let title: String
            if hasImage {
                title = group.count > 1
                    ? l.tr(zh: "\(group.count) 张照片", en: "\(group.count) photos", de: "\(group.count) Fotos")
                    : l.tr(zh: "照片时刻", en: "Photo moment", de: "Foto-Moment")
            } else {
                title = l.tr(zh: "文字时刻", en: "Note moment", de: "Notiz-Moment")
            }
            return UnifiedLogItem(
                id: first.id,
                date: first.date,
                type: "moment",
                title: title,
                subtitle: note,
                iconName: hasImage ? "photo.on.rectangle.angled" : "text.quote",
                color: .goPurple,
                photos: group.filter { renderableImageData($0.imageData) },
                style: .story,
                isHighlight: true
            )
        }

        let milestoneItems = pet.milestones
            .filter { isVisiblePast($0.date, now: now) }
            .map { milestone in
                UnifiedLogItem(
                    id: milestone.id,
                    date: milestone.date,
                    type: "milestone",
                    title: milestone.title.isEmpty ? "\(milestone.emoji) \(l.tr(zh: "重要时刻", en: "Milestone", de: "Meilenstein"))" : "\(milestone.emoji) \(milestone.title)",
                    subtitle: milestone.notes,
                    iconName: "sparkles",
                    color: .goPrimary,
                    style: .story,
                    isHighlight: true
                )
            }

        return photoItems + milestoneItems
    }

    private static func groupedPhotoLogs(for pet: Pet, now: Date) -> [[PetPhotoLog]] {
        let sorted = pet.photoLogs
            .filter { isVisiblePast($0.date, now: now) }
            .sorted { $0.date < $1.date }
        var groups: [[PetPhotoLog]] = []

        for log in sorted {
            guard let lastGroup = groups.indices.last,
                  let last = groups[lastGroup].last,
                  abs(log.date.timeIntervalSince(last.date)) < 2,
                  normalizedMomentKey(log) == normalizedMomentKey(last)
            else {
                groups.append([log])
                continue
            }
            groups[lastGroup].append(log)
        }

        return groups.sorted { ($0.first?.date ?? .distantPast) > ($1.first?.date ?? .distantPast) }
    }

    private static func generatedMeaningfulMoments(for pet: Pet, l: L10n, now: Date) -> [UnifiedLogItem] {
        var entries: [UnifiedLogItem] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let lifeEnd = pet.passedAwayDate.map { min($0, now) } ?? now
        let existingMilestones = pet.milestones.filter { isVisiblePast($0.date, now: now) }

        if let birthday = pet.birthday,
           let birthYear = calendar.dateComponents([.year], from: birthday).year,
           let currentYear = calendar.dateComponents([.year], from: today).year {
            let birthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
            for year in birthYear...currentYear {
                let age = year - birthYear
                guard age > 0 else { continue }
                var components = DateComponents()
                components.year = year
                components.month = birthdayComponents.month
                components.day = birthdayComponents.day
                guard let date = calendar.date(from: components),
                      isVisiblePast(date, now: now),
                      date <= lifeEnd,
                      !hasExistingMilestone(on: date, category: .birthday, in: existingMilestones)
                else { continue }
                entries.append(generatedItem(
                    date: date,
                    title: birthdayTitle(age, l: l),
                    subtitle: l.tr(zh: "\(pet.name) 的生日", en: "\(pet.name)'s birthday", de: "\(pet.name)s Geburtstag"),
                    emoji: "🎂",
                    color: .goYellow,
                    idSeed: "birthday-\(year)"
                ))
            }
        }

        if let homeDate = pet.homeDate {
            for days in [100, 365, 500, 730, 1000, 1095, 1500, 1825, 2000, 2190, 2500, 3000] {
                guard let date = calendar.date(byAdding: .day, value: days, to: homeDate),
                      isVisiblePast(date, now: now),
                      date <= lifeEnd,
                      !hasExistingMilestone(on: date, category: .together, in: existingMilestones)
                else { continue }
                entries.append(generatedItem(
                    date: date,
                    title: togetherTitle(days, l: l),
                    subtitle: l.tr(zh: "从到家那天开始计算", en: "Counted from home day", de: "Seit dem Einzug gezählt"),
                    emoji: days >= 1000 ? "🏆" : "🎉",
                    color: days >= 1000 ? .goYellow : .goPrimary,
                    idSeed: "together-\(days)"
                ))
            }
        }

        if let passedAwayDate = pet.passedAwayDate, passedAwayDate <= now {
            for days in [30, 100, 365, 500, 730, 1000, 1095, 1500, 1825] {
                guard let date = calendar.date(byAdding: .day, value: days, to: passedAwayDate),
                      isVisiblePast(date, now: now),
                      !hasExistingMilestone(on: date, category: .remembrance, in: existingMilestones)
                else { continue }
                entries.append(generatedItem(
                    date: date,
                    title: remembranceTitle(days, l: l),
                    subtitle: l.tr(zh: "彩虹桥后的思念", en: "Remembering after the rainbow bridge", de: "Erinnerung nach der Regenbogenbrücke"),
                    emoji: "🌈",
                    color: .goPurple,
                    idSeed: "remembrance-\(days)"
                ))
            }
        }

        return entries
    }

    private static func generatedItem(date: Date, title: String, subtitle: String, emoji: String, color: Color, idSeed: String) -> UnifiedLogItem {
        UnifiedLogItem(
            id: UUID(uuidString: deterministicUUIDSeed(idSeed)) ?? UUID(),
            date: date,
            type: "milestone",
            title: "\(emoji) \(title)",
            subtitle: subtitle,
            iconName: "sparkles",
            color: color,
            style: .story,
            isHighlight: true
        )
    }

    nonisolated private static func isImportant(_ item: UnifiedLogItem) -> Bool {
        switch item.type {
        case "health":
            return item.title.contains("手术") || item.title.contains("急") || item.title.contains("vaccine") || item.title.contains("疫苗") || item.title.contains("体检")
        case "weight":
            return true
        case "walk":
            return item.title.contains("km") || item.title.contains("公里")
        case "milestone", "moment":
            return true
        default:
            return false
        }
    }

    private static func sectionSubtitle(for day: Date, count: Int, l: L10n) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return l.tr(zh: "\(count) 个今天发生的时刻", en: "\(count) moments today", de: "\(count) Momente heute")
        }
        if calendar.isDateInYesterday(day) {
            return l.tr(zh: "\(count) 个昨天的时刻", en: "\(count) moments yesterday", de: "\(count) Momente gestern")
        }
        return l.tr(zh: "\(count) 个时刻", en: "\(count) moments", de: "\(count) Momente")
    }

    private static func friendlyDayTitle(_ day: Date, l: L10n) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return l.tr(zh: "今天", en: "Today", de: "Heute") }
        if calendar.isDateInYesterday(day) { return l.tr(zh: "昨天", en: "Yesterday", de: "Gestern") }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private static func normalizedMomentKey(_ log: PetPhotoLog) -> String {
        [
            log.note.trimmingCharacters(in: .whitespacesAndNewlines),
            log.locationPlacename.trimmingCharacters(in: .whitespacesAndNewlines)
        ].joined(separator: "|")
    }

    private static func renderableImageData(_ data: Data) -> Bool {
        data.count > 8
    }

    private static func isVisiblePast(_ date: Date, now: Date) -> Bool {
        Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: now)
    }

    private static func hasExistingMilestone(on date: Date, category: PetTimelineMilestoneKind, in milestones: [PetMilestone]) -> Bool {
        let calendar = Calendar.current
        return milestones.contains { milestone in
            calendar.isDate(milestone.date, inSameDayAs: date) &&
            milestoneCategory(for: milestone) == category
        }
    }

    private static func milestoneCategory(for milestone: PetMilestone) -> PetTimelineMilestoneKind? {
        let text = "\(milestone.title) \(milestone.notes)".lowercased()
        if text.contains("生日") || text.contains("birthday") || text.contains("geburtstag") {
            return .birthday
        }
        if text.contains("思念") || text.contains("remember") || text.contains("erinner") || text.contains("rainbow") || text.contains("彩虹桥") {
            return .remembrance
        }
        if text.contains("共度") || text.contains("相伴") || text.contains("together") || text.contains("days") || text.contains("tage") || text.contains("纪念") {
            return .together
        }
        return .user
    }

    private static func birthdayTitle(_ age: Int, l: L10n) -> String {
        l.tr(
            zh: age == 1 ? "一岁生日" : "\(age) 岁生日",
            en: age == 1 ? "First Birthday" : "\(age)th Birthday",
            de: age == 1 ? "Erster Geburtstag" : "\(age). Geburtstag"
        )
    }

    private static func togetherTitle(_ days: Int, l: L10n) -> String {
        switch days {
        case 365:
            return l.tr(zh: "相伴一年", en: "One Year Together", de: "Ein Jahr zusammen")
        case 730:
            return l.tr(zh: "相伴两年", en: "Two Years Together", de: "Zwei Jahre zusammen")
        case 1095:
            return l.tr(zh: "相伴三年", en: "Three Years Together", de: "Drei Jahre zusammen")
        case 1825:
            return l.tr(zh: "相伴五年", en: "Five Years Together", de: "Fünf Jahre zusammen")
        default:
            return l.tr(zh: "共度 \(days) 天", en: "\(days) Days Together", de: "\(days) Tage zusammen")
        }
    }

    private static func remembranceTitle(_ days: Int, l: L10n) -> String {
        switch days {
        case 365:
            return l.tr(zh: "思念一年", en: "One Year Remembered", de: "Ein Jahr Erinnerung")
        case 730:
            return l.tr(zh: "思念两年", en: "Two Years Remembered", de: "Zwei Jahre Erinnerung")
        case 1095:
            return l.tr(zh: "思念三年", en: "Three Years Remembered", de: "Drei Jahre Erinnerung")
        case 1825:
            return l.tr(zh: "思念五年", en: "Five Years Remembered", de: "Fünf Jahre Erinnerung")
        default:
            return l.tr(zh: "思念 \(days) 天", en: "\(days) Days Remembered", de: "\(days) Tage Erinnerung")
        }
    }

    private static func deterministicUUIDSeed(_ seed: String) -> String {
        var hash = UInt64(1469598103934665603)
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        let a = UInt32(truncatingIfNeeded: hash)
        let b = UInt16(truncatingIfNeeded: hash >> 32)
        let c = UInt16(truncatingIfNeeded: hash >> 48)
        let d = UInt16(truncatingIfNeeded: hash ^ 0xA11CE)
        let e = UInt64(truncatingIfNeeded: hash ^ 0x0F0F0F0F0F0F0F0F)
        return String(format: "%08X-%04X-%04X-%04X-%012llX", a, b, c, d, e & 0x0000FFFFFFFFFFFF)
    }
}

private extension Array where Element == UnifiedLogItem {
    func deduplicatedByDayTitle() -> [UnifiedLogItem] {
        var seen = Set<String>()
        return filter { item in
            let day = Calendar.current.startOfDay(for: item.date).timeIntervalSince1970
            let key = "\(Int(day))|\(item.title)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

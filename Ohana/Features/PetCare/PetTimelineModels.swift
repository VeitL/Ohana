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
    var sharedSessionID: UUID?
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
        case .highlights: l.tr(zh: "高光", en: "Highlights", de: "Highlights")
        case .memories: l.tr(zh: "回忆", en: "Memories", de: "Erinnerungen")
        case .health: l.tr(zh: "健康", en: "Health", de: "Gesundheit")
        case .care: l.tr(zh: "照护", en: "Care", de: "Pflege")
        case .expense: l.tr(zh: "花费", en: "Costs", de: "Kosten")
        case .all: l.tr(zh: "全部", en: "All", de: "Alle")
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

struct PetTimelineSourceRows {
    var careLogs: [PetCareLog] = []
    var pottyLogs: [PetPottyLog] = []
    var walkLogs: [PetWalkLog] = []
    var healthLogs: [PetHealthLog] = []
    var expenseLogs: [PetExpenseLog] = []
    var weightLogs: [PetWeightLog] = []
    var photoLogs: [PetPhotoLog] = []
    var milestones: [PetMilestone] = []

    static let empty = PetTimelineSourceRows()
}

enum PetTimelineItemsBuilder {
    /// 构建统一时间轴；`limit` 为 nil 时不截断
    static func items(
        for pet: Pet,
        sourceRows: PetTimelineSourceRows,
        limit: Int? = nil,
        sharedCareSessions: [SharedCareSession] = [],
        l: L10n = L10n(AppLanguage.code)
    ) -> [UnifiedLogItem] {
        var list: [UnifiedLogItem] = []
        let sessionsById = sharedSessionLookup(sharedCareSessions)

        for w in sourceRows.walkLogs {
            let session = sharedSession(for: w.sharedSessionId, in: sessionsById)
            list.append(UnifiedLogItem(id: session?.id ?? w.id, date: w.startDate, type: "walk",
                                       title: walkTitle(for: w, session: session, l: l),
                                       subtitle: walkSubtitle(for: w, session: session, l: l),
                                       iconName: "figure.walk", color: .goPrimary,
                                       sharedSessionID: session?.id))
        }
        for p in sourceRows.pottyLogs {
            let session = sharedSession(for: p.sharedSessionId, in: sessionsById)
            list.append(UnifiedLogItem(id: session?.id ?? p.id, date: p.date, type: "potty",
                                       title: "噗噗 · \(p.pottyType.emoji)\(p.pottyType.rawValue)", subtitle: "",
                                       iconName: "drop.fill", color: .goOrange,
                                       sharedSessionID: session?.id))
        }
        for h in sourceRows.healthLogs {
            list.append(UnifiedLogItem(id: h.id, date: h.date, type: "health",
                                       title: "\(h.healthLogType.emoji) \(h.type)",
                                       subtitle: h.note.isEmpty ? (h.vetName.isEmpty ? "" : h.vetName) : h.note,
                                       iconName: "heart.text.clipboard", color: .goTeal))
        }
        for e in sourceRows.expenseLogs {
            let session = sharedSession(for: e.sharedSessionId, in: sessionsById)
            let visibleNote = SharedCareMetadata.visibleNote(e.note)
            list.append(UnifiedLogItem(id: session?.id ?? e.id, date: e.date, type: "expense",
                                       title: expenseTitle(for: e, session: session, visibleNote: visibleNote, l: l),
                                       subtitle: expenseSubtitle(for: e, session: session, visibleNote: visibleNote, l: l),
                                       iconName: "\(AppCurrency.systemIconName).fill", color: .goYellow,
                                       sharedSessionID: session?.id))
        }
        for w in sourceRows.weightLogs {
            list.append(UnifiedLogItem(id: w.id, date: w.date, type: "weight",
                                       title: String(format: "体重 %.1f kg", w.weight), subtitle: "",
                                       iconName: "scalemass.fill", color: .goTeal))
        }
        for c in sourceRows.careLogs {
            let session = sharedSession(for: c.sharedSessionId, in: sessionsById)
            list.append(UnifiedLogItem(id: session?.id ?? c.id, date: c.date, type: "care",
                                       title: careTitle(for: c, session: session, l: l),
                                       subtitle: careSubtitle(for: c, session: session, l: l),
                                       iconName: "sparkles", color: .goPurple,
                                       sharedSessionID: session?.id))
        }

        let sorted = list.sorted { $0.date > $1.date }
        if let limit {
            return Array(sorted.prefix(limit))
        }
        return sorted
    }

    static func archiveSections(
        for pet: Pet,
        mode: PetTimelineDisplayMode,
        sourceRows: PetTimelineSourceRows,
        l: L10n,
        sharedCareSessions: [SharedCareSession] = []
    ) -> [PetTimelineArchiveSection] {
        let visibleItems = archiveItems(for: pet, mode: mode, sourceRows: sourceRows, l: l, sharedCareSessions: sharedCareSessions)
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

    static func archiveItems(
        for pet: Pet,
        mode: PetTimelineDisplayMode,
        sourceRows: PetTimelineSourceRows,
        l: L10n,
        sharedCareSessions: [SharedCareSession] = []
    ) -> [UnifiedLogItem] {
        let now = Date()
        let base = items(for: pet, sourceRows: sourceRows, limit: nil, sharedCareSessions: sharedCareSessions, l: l)
            .filter { isVisiblePast($0.date, now: now) }
            .map { item in
                var copy = item
                copy.style = .rail
                copy.isHighlight = mode == .all ? false : isImportant(item)
                return copy
            }
        let moments = memoryItems(for: pet, sourceRows: sourceRows, l: l, now: now)
        let generated = generatedMeaningfulMoments(for: pet, milestones: sourceRows.milestones, l: l, now: now)

        let all: [UnifiedLogItem] = switch mode {
        case .highlights:
            (generated + moments + base.filter(isImportant)).map { item in
                var copy = item
                copy.style = .story
                copy.isHighlight = true
                return copy
            }
        case .memories:
            (generated + moments).map { item in
                var copy = item
                copy.style = .story
                copy.isHighlight = true
                return copy
            }
        case .health:
            base.filter { $0.type == "health" || $0.type == "weight" }.map { item in
                var copy = item
                copy.style = isImportant(item) ? .story : .rail
                copy.isHighlight = isImportant(item)
                return copy
            }
        case .care:
            base.filter { ["walk", "potty", "care"].contains($0.type) }
        case .expense:
            base.filter { $0.type == "expense" }
        case .all:
            (generated + moments + base).map { item in
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

    private static func careTitle(for log: PetCareLog, session: SharedCareSession?, l: L10n) -> String {
        guard let session else {
            return "护理 · \(log.careType.emoji)\(log.careType.rawValue)"
        }
        return sharedTitle(prefix: sharedCareActionTitle(for: session, fallback: log.careType, l: l), targetCount: targetCount(for: session, note: log.note), l: l)
    }

    private static func careSubtitle(for log: PetCareLog, session: SharedCareSession?, l: L10n) -> String {
        let visibleNote = SharedCareMetadata.visibleNote(log.note)
        guard let session else { return visibleNote }
        var parts: [String] = []
        if session.totalAmountGrams > 0 {
            parts.append(formattedWholeAmount(session.totalAmountGrams, unit: "g"))
            parts.append(session.foodKind.title(l))
        } else if session.totalAmountMl > 0 {
            parts.append(formattedWholeAmount(session.totalAmountMl, unit: "ml"))
        }
        if !visibleNote.isEmpty {
            parts.append(visibleNote)
        }
        return parts.joined(separator: " · ")
    }

    private static func expenseTitle(for log: PetExpenseLog, session: SharedCareSession?, visibleNote: String, l: L10n) -> String {
        guard let session else {
            let amount = AppCurrency.format(log.amount, fractionDigits: 0)
            return "\(amount) · \(visibleNote.isEmpty ? log.category : visibleNote)"
        }
        let amount = AppCurrency.format(session.totalExpenseAmount, fractionDigits: 0)
        return "\(amount) · \(sharedTitle(prefix: l.tr(zh: "共同花费", en: "Shared cost", de: "Gemeinsame Kosten"), targetCount: targetCount(for: session, note: log.note), l: l))"
    }

    private static func expenseSubtitle(for log: PetExpenseLog, session: SharedCareSession?, visibleNote: String, l: L10n) -> String {
        guard let session else { return log.category }
        let detail = visibleNote.isEmpty ? session.expenseCategory.rawValue : visibleNote
        let perPet = AppCurrency.format(log.amount, fractionDigits: 2)
        return l.tr(
            zh: "\(detail) · 本宠 \(perPet)",
            en: "\(detail) · this pet \(perPet)",
            de: "\(detail) · dieses Tier \(perPet)"
        )
    }

    private static func walkTitle(for log: PetWalkLog, session: SharedCareSession?, l: L10n) -> String {
        guard let session else {
            return l.tr(zh: "巡岛 · \(log.distanceText)", en: "Walk · \(log.distanceText)", de: "Spaziergang · \(log.distanceText)")
        }
        let title = sharedTitle(prefix: l.tr(zh: "共同散步", en: "Shared walk", de: "Gemeinsamer Spaziergang"), targetCount: targetCount(for: session, note: ""), l: l)
        let executorCount = session.executorIds.count
        guard executorCount > 1 else { return title }
        return l.tr(
            zh: "\(title) · \(executorCount)人",
            en: "\(title) · \(executorCount) walkers",
            de: "\(title) · \(executorCount) Personen"
        )
    }

    private static func walkSubtitle(for log: PetWalkLog, session: SharedCareSession?, l _: L10n) -> String {
        guard session != nil else { return log.durationText }
        return "\(log.distanceText) · \(log.durationText)"
    }

    private static func sharedTitle(prefix: String, targetCount: Int, l: L10n) -> String {
        guard targetCount > 1 else {
            return prefix
        }
        return l.tr(
            zh: "\(prefix) · \(targetCount)只",
            en: "\(prefix) · \(targetCount) pets",
            de: "\(prefix) · \(targetCount) Tiere"
        )
    }

    private static func sharedCareActionTitle(for session: SharedCareSession, fallback: CareType, l: L10n) -> String {
        switch session.actionKind {
        case .feeding:
            l.tr(zh: "共同喂食", en: "Shared feeding", de: "Gemeinsames Füttern")
        case .watering:
            l.tr(zh: "共同喂水", en: "Shared water", de: "Gemeinsames Wasser")
        case .potty:
            l.tr(zh: "共同便便", en: "Shared potty", de: "Gemeinsames Geschäft")
        case .hygiene:
            l.tr(zh: "共同护理", en: "Shared hygiene", de: "Gemeinsame Pflege")
        case .litterScoop:
            l.tr(zh: "共同铲砂", en: "Shared litter scoop", de: "Gemeinsames Klo-Reinigen")
        case .litterChange:
            l.tr(zh: "共同换砂", en: "Shared litter change", de: "Gemeinsamer Streuwechsel")
        case .waterChange:
            l.tr(zh: "共同换水", en: "Shared water change", de: "Gemeinsamer Wasserwechsel")
        case .filterClean:
            l.tr(zh: "共同清理滤材", en: "Shared filter clean", de: "Gemeinsame Filterreinigung")
        case .cageCleaning:
            l.tr(zh: "共同清理鸟笼", en: "Shared cage clean", de: "Gemeinsame Käfigreinigung")
        case .freeFlight:
            l.tr(zh: "共同放飞互动", en: "Shared free flight", de: "Gemeinsamer Freiflug")
        case .misting:
            l.tr(zh: "共同喷水保湿", en: "Shared misting", de: "Gemeinsames Besprühen")
        case .substrateChange:
            l.tr(zh: "共同换垫材", en: "Shared substrate change", de: "Gemeinsamer Substratwechsel")
        case .play:
            l.tr(zh: "共同逗玩", en: "Shared play", de: "Gemeinsames Spielen")
        case .pottyUnknown, .walk, .expense:
            l.tr(zh: "共同\(fallback.rawValue)", en: "Shared care", de: "Gemeinsame Pflege")
        }
    }

    private static func targetCount(for session: SharedCareSession, note: String) -> Int {
        max(session.targetPetIds.count, SharedCareMetadata.targetCount(from: note) ?? 0)
    }

    private static func sharedSessionLookup(_ sessions: [SharedCareSession]) -> [String: SharedCareSession] {
        Dictionary(uniqueKeysWithValues: sessions.map { ($0.id.uuidString, $0) })
    }

    private static func sharedSession(for id: String, in lookup: [String: SharedCareSession]) -> SharedCareSession? {
        guard !id.isEmpty else { return nil }
        return lookup[id]
    }

    private static func formattedWholeAmount(_ value: Double, unit: String) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return "\(Int(rounded)) \(unit)"
        }
        return String(format: "%.1f %@", value, unit)
    }

    private static func memoryItems(for _: Pet, sourceRows: PetTimelineSourceRows, l: L10n, now: Date) -> [UnifiedLogItem] {
        let photoGroups = groupedPhotoLogs(sourceRows.photoLogs, now: now)
        let photoItems = photoGroups.map { group -> UnifiedLogItem in
            let first = group[0]
            let note = first.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasImage = group.contains { renderableImageData($0.imageData) }
            let title: String = if hasImage {
                group.count > 1
                    ? l.tr(zh: "\(group.count) 张照片", en: "\(group.count) photos", de: "\(group.count) Fotos")
                    : l.tr(zh: "照片时刻", en: "Photo moment", de: "Foto-Moment")
            } else {
                l.tr(zh: "文字时刻", en: "Note moment", de: "Notiz-Moment")
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

        let milestoneItems = sourceRows.milestones
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

    private static func groupedPhotoLogs(_ photoLogs: [PetPhotoLog], now: Date) -> [[PetPhotoLog]] {
        let sorted = photoLogs
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

    private static func generatedMeaningfulMoments(for pet: Pet, milestones: [PetMilestone], l: L10n, now: Date) -> [UnifiedLogItem] {
        var entries: [UnifiedLogItem] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let lifeEnd = pet.passedAwayDate.map { min($0, now) } ?? now
        let existingMilestones = milestones.filter { isVisiblePast($0.date, now: now) }

        if let birthday = pet.birthday,
           let birthYear = calendar.dateComponents([.year], from: birthday).year,
           let currentYear = calendar.dateComponents([.year], from: today).year {
            let birthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
            for year in birthYear ... currentYear {
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

    private nonisolated static func isImportant(_ item: UnifiedLogItem) -> Bool {
        switch item.type {
        case "health":
            item.title.contains("手术") || item.title.contains("急") || item.title.contains("vaccine") || item.title.contains("疫苗") || item.title.contains("体检")
        case "weight":
            true
        case "walk":
            item.title.contains("km") || item.title.contains("公里")
        case "milestone", "moment":
            true
        default:
            false
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
            l.tr(zh: "相伴一年", en: "One Year Together", de: "Ein Jahr zusammen")
        case 730:
            l.tr(zh: "相伴两年", en: "Two Years Together", de: "Zwei Jahre zusammen")
        case 1095:
            l.tr(zh: "相伴三年", en: "Three Years Together", de: "Drei Jahre zusammen")
        case 1825:
            l.tr(zh: "相伴五年", en: "Five Years Together", de: "Fünf Jahre zusammen")
        default:
            l.tr(zh: "共度 \(days) 天", en: "\(days) Days Together", de: "\(days) Tage zusammen")
        }
    }

    private static func remembranceTitle(_ days: Int, l: L10n) -> String {
        switch days {
        case 365:
            l.tr(zh: "思念一年", en: "One Year Remembered", de: "Ein Jahr Erinnerung")
        case 730:
            l.tr(zh: "思念两年", en: "Two Years Remembered", de: "Zwei Jahre Erinnerung")
        case 1095:
            l.tr(zh: "思念三年", en: "Three Years Remembered", de: "Drei Jahre Erinnerung")
        case 1825:
            l.tr(zh: "思念五年", en: "Five Years Remembered", de: "Fünf Jahre Erinnerung")
        default:
            l.tr(zh: "思念 \(days) 天", en: "\(days) Days Remembered", de: "\(days) Tage Erinnerung")
        }
    }

    private static func deterministicUUIDSeed(_ seed: String) -> String {
        var hash = UInt64(1_469_598_103_934_665_603)
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let a = UInt32(truncatingIfNeeded: hash)
        let b = UInt16(truncatingIfNeeded: hash >> 32)
        let c = UInt16(truncatingIfNeeded: hash >> 48)
        let d = UInt16(truncatingIfNeeded: hash ^ 0xA11CE)
        let e = UInt64(truncatingIfNeeded: hash ^ 0x0F0F_0F0F_0F0F_0F0F)
        return String(format: "%08X-%04X-%04X-%04X-%012llX", a, b, c, d, e & 0x0000_FFFF_FFFF_FFFF)
    }
}

private extension [UnifiedLogItem] {
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

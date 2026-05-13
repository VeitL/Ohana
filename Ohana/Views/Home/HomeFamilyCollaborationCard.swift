//
//  HomeFamilyCollaborationCard.swift
//  Ohana
//
//  Compact family collaboration card for the GO home carousel.
//

import SwiftUI

struct HomeFamilyCollaborationCard: View {
    let pet: Pet
    let pendingReminders: [Reminder]
    let humans: [Human]
    var onOpenActivity: () -> Void
    var onOpenWeeklyReport: () -> Void

    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    private var l: L10n { L10n(appLanguage) }

    private var shouldShowFamilyCollaboration: Bool {
        humans.count > 1
    }

    private struct ActivitySnapshot {
        let title: String
        let executorId: String?
        let date: Date
        let iconName: String
        let accent: Color
    }

    private var latestActivity: ActivitySnapshot? {
        var entries: [ActivitySnapshot] = []
        entries += pet.careLogs.map {
            ActivitySnapshot(
                title: localizedCareTitle($0.careType),
                executorId: $0.executorId,
                date: $0.date,
                iconName: $0.careType.systemIconName,
                accent: Color(hex: $0.careType.accentColorHex)
            )
        }
        entries += pet.pottyLogs.map {
            ActivitySnapshot(
                title: localizedPottyTitle($0.pottyType),
                executorId: $0.executorId,
                date: $0.date,
                iconName: $0.pottyType.systemIconName,
                accent: Color.goYellow
            )
        }
        entries += pet.walkLogs.map {
            ActivitySnapshot(
                title: l.tr(zh: "遛狗", en: "Walk", de: "Gassi"),
                executorId: $0.executorId,
                date: $0.startDate,
                iconName: "figure.walk",
                accent: Color.goPrimary
            )
        }
        return entries.max { $0.date < $1.date }
    }

    private var missingTodayText: String {
        let missing = expectedTodayCare.filter { !$0.done }.map { $0.label }
        guard !missing.isEmpty else {
            return l.tr(zh: "今天基础照护已完成", en: "Basic care is done today", de: "Grundpflege ist heute erledigt")
        }
        let joined = missing.prefix(3).joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
        return l.tr(zh: "今天还缺：\(joined)", en: "Still missing today: \(joined)", de: "Heute fehlt noch: \(joined)")
    }

    private var expectedTodayCare: [(label: String, done: Bool)] {
        let cal = Calendar.current
        let lowerSpecies = pet.species.lowercased()
        let isDog = pet.species.contains("狗") || lowerSpecies.contains("dog")
        let isCat = pet.species.contains("猫") || lowerSpecies.contains("cat")
        let isFish = pet.species.contains("鱼") || lowerSpecies.contains("fish")
        let isBird = pet.species.contains("鸟") || lowerSpecies.contains("bird")
        let isRabbit = pet.species.contains("兔") || lowerSpecies.contains("rabbit")
        let isReptile = pet.species.contains("爬") || pet.species.contains("龟") || pet.species.contains("蛇") || pet.species.contains("蜥") || pet.species.contains("守宫") || lowerSpecies.contains("reptile")

        func careDone(_ type: CareType) -> Bool {
            pet.careLogs.contains { $0.careType == type && cal.isDateInToday($0.date) }
        }
        func pottyDone() -> Bool {
            pet.pottyLogs.contains { cal.isDateInToday($0.date) } || careDone(.litter)
        }

        if isFish {
            return [
                (localizedCareTitle(.feeding), careDone(.feeding)),
                (localizedCareTitle(.waterChange), careDone(.waterChange)),
                (l.tr(zh: "过滤", en: "Filter", de: "Filter"), careDone(.filterClean))
            ]
        }
        if isBird {
            return [
                (localizedCareTitle(.feeding), careDone(.feeding)),
                (localizedCareTitle(.watering), careDone(.watering)),
                (localizedCareTitle(.cageCleaning), careDone(.cageCleaning)),
                (localizedCareTitle(.freeFlight), careDone(.freeFlight))
            ]
        }
        if isReptile {
            return [
                (localizedCareTitle(.feeding), careDone(.feeding)),
                (localizedCareTitle(.misting), careDone(.misting)),
                (l.tr(zh: "环境", en: "Habitat", de: "Terrarium"), careDone(.substrateChange))
            ]
        }
        if isDog {
            return [
                (localizedCareTitle(.feeding), careDone(.feeding)),
                (localizedCareTitle(.watering), careDone(.watering)),
                (l.tr(zh: "遛狗", en: "Walk", de: "Gassi"), pet.walkLogs.contains { cal.isDateInToday($0.startDate) })
            ]
        }
        if isCat || isRabbit {
            return [
                (localizedCareTitle(.feeding), careDone(.feeding)),
                (localizedCareTitle(.watering), careDone(.watering)),
                (l.tr(zh: "厕所", en: "Toilet", de: "Toilette"), pottyDone())
            ]
        }
        return [
            (localizedCareTitle(.feeding), careDone(.feeding)),
            (localizedCareTitle(.watering), careDone(.watering)),
            (localizedCareTitle(.play), careDone(.play))
        ]
    }

    private var assignedReminders: [Reminder] {
        let petId = pet.id.uuidString
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return pendingReminders
            .filter { reminder in
                guard let event = reminder.event,
                      let assigneeId = event.assigneeId,
                      !assigneeId.isEmpty else { return false }
                let isThisPet = (event.relatedEntityType == EntityKind.pet.rawValue || event.relatedEntityType == "pet")
                    && event.relatedEntityId == petId
                return isThisPet && reminder.scheduledAt < tomorrow
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var body: some View {
        if shouldShowFamilyCollaboration {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                card
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FAMILY")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.36))
                Text(l.tr(zh: "家庭协作", en: "Family care", de: "Familienpflege"))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.9))
            }
            Spacer()
            Button(action: onOpenWeeklyReport) {
                Label(l.tr(zh: "周报", en: "Weekly", de: "Woche"), systemImage: "chart.bar.doc.horizontal")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.07), in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            topStatusRow

            Text(missingTodayText)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
                .lineLimit(1)

            FamilyActivityStripView(pet: pet, style: .compact, onExpand: onOpenActivity)

            if assignedReminders.isEmpty {
                Text(l.tr(
                    zh: "没有指派待办时，任何家人完成打卡都会更新上次照护状态。",
                    en: "When nothing is assigned, any family check-in updates the latest care status.",
                    de: "Ohne Zuweisung aktualisiert jeder Check-in den letzten Pflegestatus."
                ))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(assignedReminders.prefix(1)) { reminder in
                        assignedReminderRow(reminder)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground(Color.goPrimary))
    }

    private var topStatusRow: some View {
        HStack(spacing: 8) {
            if let latestActivity {
                statusPill(
                    iconName: latestActivity.iconName,
                    title: "\(actorName(for: latestActivity.executorId)) · \(latestActivity.title)",
                    subtitle: relativeTime(from: latestActivity.date),
                    tint: latestActivity.accent
                )
            } else {
                statusPill(
                    iconName: "person.2.fill",
                    title: l.tr(zh: "还没有照护记录", en: "No care yet", de: "Noch keine Pflege"),
                    subtitle: l.tr(zh: "完成一次打卡后同步", en: "Syncs after the first check-in", de: "Nach erstem Check-in synchron"),
                    tint: Color.goBlue
                )
            }

            statusPill(
                iconName: assignedReminders.isEmpty ? "checklist" : "person.crop.circle.badge.clock",
                title: assignedReminders.isEmpty
                    ? l.tr(zh: "无人指派", en: "Unassigned", de: "Nicht zugewiesen")
                    : l.tr(zh: "已指派 \(assignedReminders.count) 个", en: "\(assignedReminders.count) assigned", de: "\(assignedReminders.count) zugewiesen"),
                subtitle: assignedReminders.first.map { $0.scheduledAt.formatted(.dateTime.hour().minute()) }
                    ?? l.tr(zh: "家人可直接接手", en: "Anyone can take over", de: "Jede Person kann übernehmen"),
                tint: assignedReminders.isEmpty ? Color.goTeal : Color.goYellow
            )
        }
    }

    private func statusPill(iconName: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private func actorName(for id: String?) -> String {
        guard let id, let human = humans.first(where: { $0.id.uuidString == id }) else {
            return l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        return human.name.isEmpty ? l.tr(zh: "家人", en: "Family", de: "Familie") : human.name
    }

    private func relativeTime(from date: Date) -> String {
        let cal = Calendar.current
        let now = Date()
        if cal.isDate(date, inSameDayAs: now) {
            let minutes = max(1, Int(now.timeIntervalSince(date) / 60))
            if minutes < 60 {
                return l.tr(zh: "\(minutes)分钟前", en: "\(minutes)m ago", de: "vor \(minutes) Min.")
            }
            return l.tr(zh: "\(minutes / 60)小时前", en: "\(minutes / 60)h ago", de: "vor \(minutes / 60) Std.")
        }
        let days = max(1, cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 1)
        return l.tr(zh: "\(days)天前", en: "\(days)d ago", de: "vor \(days) Tg.")
    }

    private func assignedReminderRow(_ reminder: Reminder) -> some View {
        let event = reminder.event
        let targetHuman: Human? = {
            guard let id = event?.assigneeId, !id.isEmpty else { return nil }
            return humans.first { $0.id.uuidString == id }
        }()
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event?.title ?? l.tr(zh: "家庭待办", en: "Family task", de: "Familienaufgabe"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(reminder.scheduledAt, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 8)

            if let assigneeId = event?.assigneeId {
                AssigneeChip(assigneeId: assigneeId, allHumans: humans)
            }

            if let targetHuman {
                NudgeButton(targetHuman: targetHuman)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func cardBackground(_ accent: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.ohanaCardSurface)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
    }

    private func localizedCareTitle(_ type: CareType) -> String {
        switch type {
        case .feeding: return l.tr(zh: "喂食", en: "Feed", de: "Füttern")
        case .watering: return l.tr(zh: "饮水", en: "Water", de: "Wasser")
        case .litter: return l.tr(zh: "铲屎", en: "Scoop", de: "Klo reinigen")
        case .waterChange: return l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterClean: return l.tr(zh: "清理滤材", en: "Clean filter", de: "Filter reinigen")
        case .cageCleaning: return l.tr(zh: "清鸟笼", en: "Clean cage", de: "Käfig reinigen")
        case .freeFlight: return l.tr(zh: "放飞", en: "Free flight", de: "Freiflug")
        case .misting: return l.tr(zh: "保湿", en: "Mist", de: "Befeuchten")
        case .substrateChange: return l.tr(zh: "换垫材", en: "Substrate", de: "Substrat")
        case .play: return l.tr(zh: "互动", en: "Play", de: "Spielen")
        }
    }

    private func localizedPottyTitle(_ type: PottyType) -> String {
        switch type {
        case .perfectPoop: return l.tr(zh: "完美便便", en: "Good poop", de: "Guter Kot")
        case .softPoop: return l.tr(zh: "软便", en: "Soft stool", de: "Weicher Kot")
        case .liquidPoop: return l.tr(zh: "水便", en: "Diarrhea", de: "Durchfall")
        case .pee: return l.tr(zh: "尿尿", en: "Pee", de: "Urin")
        }
    }
}

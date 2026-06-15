//
//  FamilyCollaborationDashboardView+Activity.swift
//  Ohana
//

import SwiftData
import SwiftUI

extension FamilyCollaborationDashboardView {
    var petCareStatusSection: some View {
        collaborationSection(
            title: l.tr(zh: "按宠物查看", en: "By pet", de: "Nach Tier"),
            icon: "pawprint.fill",
            count: pets.count
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(pets) { pet in
                    petStatusCard(pet)
                }
            }
        }
    }

    var activitySection: some View {
        collaborationSection(
            title: l.tr(zh: "今日动态", en: "Today activity", de: "Aktivität heute"),
            icon: "waveform.path.ecg",
            count: latestActivity.count(where: { Calendar.current.isDateInToday($0.date) })
        ) {
            if latestActivity.isEmpty {
                compactEmpty(
                    icon: "clock",
                    text: l.tr(zh: "完成一次照护后会出现在这里。", en: "Care check-ins will appear here.", de: "Pflegeeinträge erscheinen hier.")
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(latestActivity.prefix(5)) { activity in
                        activityRow(activity)
                    }
                }
            }
        }
    }

    func collaborationSection(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder trailing: () -> some View,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goPrimary)
                Text(title)
                    .font(OhanaFont.caption(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("\(count)")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.goPrimary, in: Capsule())
                Spacer()
                trailing()
            }
            content()
        }
    }

    func collaborationSection(
        title: String,
        icon: String,
        count: Int,
        @ViewBuilder content: () -> some View
    ) -> some View {
        collaborationSection(title: title, icon: icon, count: count, trailing: { EmptyView() }, content: content)
    }

    func reminderTaskRow(_ reminder: Reminder, role: ReminderRole) -> some View {
        let event = reminder.event
        return HStack(spacing: 12) {
            Image(systemName: event?.silhouetteListSymbol ?? "checklist")
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(role == .mine ? Color.goPurple : Color.goTeal)
                .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent

            VStack(alignment: .leading, spacing: 3) {
                Text(reminderTitle(reminder))
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(reminderSubtitle(reminder))
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(reminder.scheduledAt.formatted(.dateTime.hour().minute()))
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .monospacedDigit()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func petCareGapRow(_ pet: Pet) -> some View {
        let labels = careGapLabels(for: pet)
        let openCount = openReminders(for: pet).count
        return Button {
            onOpenPetActivity(pet)
        } label: {
            HStack(spacing: 12) {
                Text(pet.avatarEmoji)
                    .font(OhanaFont.title3(.black))
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent

                VStack(alignment: .leading, spacing: 3) {
                    Text(pet.name)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                    Text(labels.prefix(3).joined(separator: " · "))
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if openCount > 0 {
                    Text("\(openCount)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.arkInk)
                        .monospacedDigit()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.goYellow, in: Capsule())
                }

                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaTertiaryText)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func petStatusCard(_ pet: Pet) -> some View {
        let missing = missingCareLabels(for: pet)
        return Button {
            onOpenPetActivity(pet)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(pet.avatarEmoji)
                        .font(OhanaFont.title3(.black))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pet.name)
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(missing.isEmpty
                            ? l.tr(zh: "今日已稳", en: "Covered today", de: "Heute erledigt")
                            : missing.prefix(2).joined(separator: " · "))
                            .font(OhanaFont.caption2(.bold))
                            .foregroundStyle(missing.isEmpty ? Color.goTeal : Color.goYellow)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                ProgressView(value: missing.isEmpty ? 1 : 0.42)
                    .tint(missing.isEmpty ? Color.goTeal : Color.goYellow)
                    .scaleEffect(x: 1, y: 1.3, anchor: .center)
            }
            .padding(12)
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func activityRow(_ activity: CollaborationActivity) -> some View {
        HStack(spacing: 11) {
            Image(systemName: activity.icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(activity.tint)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            VStack(alignment: .leading, spacing: 2) {
                Text("\(activity.actor) · \(activity.title)")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text("\(activity.petName) · \(relativeTime(from: activity.date))")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    func compactEmpty(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaTertiaryText)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
            Text(text)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
            Spacer()
        }
        .padding(12)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }

    func smallAction(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(OhanaFont.caption(.black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    func isActivePetEvent(_ event: Event) -> Bool {
        MemberLifecycleActiveScheduleResolver.petTarget(
            for: event,
            pets: activePets,
            includePassedAway: false
        ) != nil
    }

    func reminderSubtitle(_ reminder: Reminder) -> String {
        let petName = reminder.event.flatMap { event in
            MemberLifecycleActiveScheduleResolver.petTarget(
                for: event,
                pets: activePets,
                includePassedAway: false
            )?.name
        } ?? l.tr(zh: "家庭", en: "Family", de: "Familie")
        return "\(petName) · \(relativeTime(from: reminder.scheduledAt))"
    }

    func openReminders(for pet: Pet) -> [Reminder] {
        openReminders.filter { reminder in
            guard let event = reminder.event else { return false }
            return MemberLifecycleActiveScheduleResolver.eventBelongsToPet(
                event,
                petId: pet.id.uuidString,
                petMedications: pet.medications,
                insurances: pet.insurances
            )
        }
    }

    func careGapLabels(for pet: Pet) -> [String] {
        let reminderLabels = openReminders(for: pet).compactMap { reminder in
            let title = reminderTitle(reminder, fallback: "")
            return title.isEmpty ? nil : title
        }
        if !reminderLabels.isEmpty { return reminderLabels }
        return missingCareLabels(for: pet)
    }

    func reminderTitle(_ reminder: Reminder, fallback: String? = nil) -> String {
        guard let event = reminder.event else {
            return fallback ?? l.tr(zh: "照护任务", en: "Care task", de: "Pflegeaufgabe")
        }
        return FeedRuleMetadata.localizedTitle(for: event, l: l)
    }

    func missingCareLabels(for pet: Pet) -> [String] {
        let cal = Calendar.current
        func careDone(_ type: CareType) -> Bool {
            pet.careLogs.contains { $0.careType == type && cal.isDateInToday($0.date) }
        }
        func pottyDone() -> Bool {
            pet.pottyLogs.contains { cal.isDateInToday($0.date) } || careDone(.litter)
        }

        let species = pet.species.lowercased()
        let isDog = pet.species.contains("狗") || species.contains("dog")
        let isCat = pet.species.contains("猫") || species.contains("cat")
        let isFish = pet.species.contains("鱼") || species.contains("fish")

        let expected: [(String, Bool)] = if isFish {
            [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.waterChange), careDone(.waterChange)),
                (careTitle(.filterClean), careDone(.filterClean))
            ]
        } else if isDog {
            [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.watering), careDone(.watering)),
                (l.tr(zh: "遛狗", en: "Walk", de: "Gassi"), pet.walkLogs.contains { cal.isDateInToday($0.startDate) })
            ]
        } else if isCat {
            [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.watering), careDone(.watering)),
                (l.tr(zh: "厕所", en: "Toilet", de: "Toilette"), pottyDone())
            ]
        } else {
            [
                (careTitle(.feeding), careDone(.feeding)),
                (careTitle(.watering), careDone(.watering)),
                (careTitle(.play), careDone(.play))
            ]
        }
        return expected.filter { !$0.1 }.map(\.0)
    }

    func actorName(_ id: String?) -> String {
        guard let id, !id.isEmpty else {
            return l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        return humans.first { $0.id.uuidString == id }?.name ?? l.tr(zh: "家人", en: "Family", de: "Familie")
    }

    func actorNames(_ ids: [String]) -> String {
        let names = ids
            .map(actorName)
            .filter { !$0.isEmpty }
        guard !names.isEmpty else {
            return l.tr(zh: "家人", en: "Family", de: "Familie")
        }
        return names.joined(separator: l.tr(zh: "、", en: ", ", de: ", "))
    }

    func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLanguage.effectiveLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func careTitle(_ type: CareType) -> String {
        switch type {
        case .feeding: l.tr(zh: "喂食", en: "Feed", de: "Füttern")
        case .watering: l.tr(zh: "饮水", en: "Water", de: "Wasser")
        case .litter: l.tr(zh: "铲砂", en: "Scoop", de: "Klo reinigen")
        case .waterChange: l.tr(zh: "换水", en: "Water change", de: "Wasserwechsel")
        case .filterClean: l.tr(zh: "滤芯", en: "Filter", de: "Filter")
        case .cageCleaning: l.tr(zh: "清笼", en: "Clean cage", de: "Käfig reinigen")
        case .freeFlight: l.tr(zh: "放飞", en: "Free flight", de: "Freiflug")
        case .misting: l.tr(zh: "保湿", en: "Mist", de: "Befeuchten")
        case .substrateChange: l.tr(zh: "换垫材", en: "Substrate", de: "Substrat")
        case .play: l.tr(zh: "陪玩", en: "Play", de: "Spielen")
        }
    }

    func pottyTitle(_ type: PottyType) -> String {
        type.localizedLabel(l)
    }

    enum ReminderRole {
        case mine
    }

    struct CollaborationActivity: Identifiable {
        let id = UUID()
        let title: String
        let petName: String
        let actor: String
        let date: Date
        let icon: String
        let tint: Color
    }
}

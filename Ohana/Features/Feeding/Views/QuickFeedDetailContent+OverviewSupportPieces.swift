import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func modeInfoPill(title: String, value: String, tint: Color) -> some View {
        QuickFeedModeInfoPill(title: title, value: value, tint: tint)
    }

    func overviewSectionHeader(_ title: String) -> some View {
        QuickFeedSectionHeader(title: title)
    }

    var treatOverviewHero: some View {
        let selectedTitle = draftStore.selectedTreatOverviewKind?.title(l) ?? l.tr(zh: "全部零食", en: "All treats", de: "Alle Snacks")
        let count = filteredTreatLogsToday.count
        let gramsText = filteredTreatGramsToday > 0 ? formattedFoodWeight(filteredTreatGramsToday) : "--"

        return QuickFeedTreatOverviewHero(
            icon: draftStore.selectedTreatOverviewKind?.systemIconName ?? "birthday.cake.fill",
            title: selectedTitle,
            lastSeenText: treatLastSeenText(lastTreatDate(for: draftStore.selectedTreatOverviewKind)),
            todayCount: count,
            todaySubtitle: l.tr(zh: "今日 · \(gramsText)", en: "Today · \(gramsText)", de: "Heute · \(gramsText)"),
            tint: treatTint
        )
    }

    var treatKindFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                treatFilterChip(
                    title: l.tr(zh: "全部", en: "All", de: "Alle"),
                    icon: "square.grid.2x2.fill",
                    count: treatLogsInRange.count,
                    isSelected: draftStore.selectedTreatOverviewKind == nil
                ) {
                    draftStore.selectedTreatOverviewKind = nil
                }

                ForEach(FeedTreatKind.allCases) { kind in
                    let count = treatSnapshot.count(for: kind)
                    treatFilterChip(
                        title: kind.title(l),
                        icon: kind.systemIconName,
                        count: count,
                        isSelected: draftStore.selectedTreatOverviewKind == kind
                    ) {
                        draftStore.selectedTreatOverviewKind = kind
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    func treatFilterChip(
        title: String,
        icon: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        QuickFeedTreatFilterChip(
            title: title,
            icon: icon,
            count: count,
            isSelected: isSelected,
            tint: treatTint,
            isDisabled: count == 0 && !isSelected
        ) {
            guard !isSelected else { return }
            withAnimation(GoMotion.feedback) {
                action()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func lastTreatDate(for kind: FeedTreatKind?) -> Date? {
        treatSnapshot.lastDate(for: kind)
    }

    func treatLastSeenText(_ date: Date?) -> String {
        guard let date else {
            return l.tr(zh: "还没喂过", en: "Never logged", de: "Noch nie")
        }

        let calendar = Calendar.current
        let time = date.formatted(.dateTime.hour().minute())
        if calendar.isDateInToday(date) {
            return l.tr(
                zh: "上次 今天 \(time)",
                en: "Last today \(time)",
                de: "Zuletzt heute \(time)"
            )
        }
        if calendar.isDateInYesterday(date) {
            return l.tr(
                zh: "上次 昨天 \(time)",
                en: "Last yesterday \(time)",
                de: "Zuletzt gestern \(time)"
            )
        }

        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        if days > 1, days < 7 {
            return l.tr(
                zh: "上次 \(days) 天前",
                en: "Last \(days)d ago",
                de: "Zuletzt vor \(days) T."
            )
        }

        let day = date.formatted(.dateTime.month().day())
        return l.tr(
            zh: "上次 \(day)",
            en: "Last \(day)",
            de: "Zuletzt \(day)"
        )
    }

    func avatarView(size: CGFloat) -> some View {
        PetAvatarPortraitView(
            pet: pet,
            fallbackText: pet.avatarEmoji,
            themeColor: themeColor,
            size: size,
            backgroundOpacity: 0.16
        )
    }
}

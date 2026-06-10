import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    func modeInfoPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaSecondaryText)
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
    }

    func overviewSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
            .padding(.top, 2)
    }

    var treatOverviewHero: some View {
        let selectedTitle = draftStore.selectedTreatOverviewKind?.title(l) ?? l.tr(zh: "全部零食", en: "All treats", de: "Alle Snacks")
        let count = filteredTreatLogsToday.count
        let gramsText = filteredTreatGramsToday > 0 ? formattedFoodWeight(filteredTreatGramsToday) : "--"

        return HStack(alignment: .center, spacing: 14) {
            Image(systemName: draftStore.selectedTreatOverviewKind?.systemIconName ?? "birthday.cake.fill")
                .font(OhanaFont.adaptive(size: 22, weight: .black))
                .foregroundStyle(treatTint)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedTitle)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
                Text(treatLastSeenText(lastTreatDate(for: draftStore.selectedTreatOverviewKind)))
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(count)")
                    .font(OhanaFont.adaptive(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(treatTint)
                    .contentTransition(.numericText())
                Text(l.tr(zh: "今日 · \(gramsText)", en: "Today · \(gramsText)", de: "Heute · \(gramsText)"))
                    .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.vertical, 2)
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
        Button {
            guard !isSelected else { return }
            withAnimation(GoMotion.feedback) {
                action()
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 11, weight: .black))
                Text(title)
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
                Text("\(count)")
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(isSelected ? Color.arkInk : treatTint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isSelected ? treatTint : treatTint.opacity(0.12), in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(count == 0 && !isSelected)
        .opacity(count == 0 && !isSelected ? 0.42 : 1)
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
            imageData: pet.avatarImageData,
            fallbackText: pet.avatarEmoji,
            themeColor: themeColor,
            size: size,
            backgroundOpacity: 0.16
        )
    }
}

import Foundation

nonisolated enum SingleMemberFamilyShapePresentation {
    static func isSingleVisibleHumanFamily(humanCount: Int) -> Bool {
        humanCount <= 1
    }

    static func weeklyReportContributionSectionTitle(
        humanCount: Int,
        l: L10n = .current
    ) -> String {
        if isSingleVisibleHumanFamily(humanCount: humanCount) {
            return l.tr(zh: "本周照护者", en: "Caregiver this week", de: "Pflegeperson der Woche")
        }
        return l.tr(zh: "本周照护摘要", en: "Care summary this week", de: "Pflegeueberblick der Woche")
    }

    static func weeklyReportLeaderStory(
        name: String,
        humanCount: Int,
        l: L10n = .current
    ) -> String {
        if isSingleVisibleHumanFamily(humanCount: humanCount) {
            return l.tr(
                zh: "\(name) 记录了本周照护",
                en: "\(name) logged care this week",
                de: "\(name) hat diese Woche Pflege festgehalten"
            )
        }
        return l.tr(
            zh: "\(name) 参与了本周照护",
            en: "\(name) joined this week's care",
            de: "\(name) war diese Woche an der Pflege beteiligt"
        )
    }

    static func weeklyReportLeaderPillSubtitle(
        humanCount: Int,
        l: L10n = .current
    ) -> String {
        if isSingleVisibleHumanFamily(humanCount: humanCount) {
            return l.tr(zh: "本周照护者", en: "Caregiver this week", de: "Pflegeperson der Woche")
        }
        return l.tr(zh: "照护记录", en: "Care records", de: "Pflegeeintraege")
    }

    static func weeklyReportShareLeaderLabel(
        humanCount: Int,
        l: L10n = .current
    ) -> String {
        if isSingleVisibleHumanFamily(humanCount: humanCount) {
            return l.tr(zh: "本周照护者", en: "Caregiver this week", de: "Pflegeperson der Woche")
        }
        return l.tr(zh: "本周照护者", en: "Caregivers this week", de: "Pflegepersonen der Woche")
    }

    static func weeklyReportRecentActivityEmptyText(
        humanCount: Int,
        l: L10n = .current
    ) -> String {
        if isSingleVisibleHumanFamily(humanCount: humanCount) {
            return l.tr(
                zh: "完成一次快捷打卡后，这里会出现本周照护动态",
                en: "After one quick check-in, this week's care activity will appear here.",
                de: "Nach einem schnellen Check-in erscheinen hier die Pflegeaktivitäten dieser Woche."
            )
        }
        return l.tr(
            zh: "完成一次快捷打卡后，这里会出现本周照护动态",
            en: "After one quick check-in, this week's care activity will appear here.",
            de: "Nach einem schnellen Check-in erscheinen hier die Pflegeaktivitäten dieser Woche."
        )
    }

    static func wealthSectionTitle(rowCount: Int, l: L10n = .current) -> String {
        if rowCount <= 1 {
            return l.tr(zh: "椰子账户", en: "Coconut account", de: "Kokoskonto")
        }
        return l.tr(zh: "财富榜", en: "Wealth ranking", de: "Vermögensrang")
    }

    static func wealthEmptyText(visibleMemberCount: Int, l: L10n = .current) -> String {
        if visibleMemberCount <= 1 {
            return l.tr(
                zh: "完成一次打卡后，椰子账户会开始记录收入 ✨",
                en: "After one check-in, the coconut account will start recording income ✨",
                de: "Nach einem Check-in erfasst das Kokoskonto die ersten Einnahmen ✨"
            )
        }
        return l.tr(
            zh: "完成打卡即可解锁财富榜 ✨",
            en: "Complete a check-in to unlock the wealth ranking ✨",
            de: "Schließe einen Check-in ab, um die Vermögensrangliste freizuschalten ✨"
        )
    }

    static func showsWealthRank(rowCount: Int) -> Bool {
        rowCount > 1
    }

    static func familyMemberCountText(memberCount: Int, l: L10n = .current) -> String {
        if l.isEnglish {
            return memberCount == 1 ? "1 member" : "\(memberCount) members"
        }
        if l.isDe {
            return memberCount == 1 ? "1 Mitglied" : "\(memberCount) Mitglieder"
        }
        return l.tr(
            zh: "\(memberCount) 位成员",
            en: memberCount == 1 ? "1 member" : "\(memberCount) members",
            de: "\(memberCount) Mitglieder"
        )
    }
}

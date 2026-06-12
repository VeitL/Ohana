import Testing
@testable import Ohana

struct SingleMemberFamilyShapePresentationTests {
    @Test func weeklyReportSingleHumanCopyAvoidsCompetition() {
        let l = L10n("zh")

        #expect(SingleMemberFamilyShapePresentation.isSingleVisibleHumanFamily(humanCount: 1))
        #expect(SingleMemberFamilyShapePresentation.weeklyReportContributionSectionTitle(humanCount: 1, l: l) == "本周照护者")
        #expect(SingleMemberFamilyShapePresentation.weeklyReportLeaderStory(name: "Guan", humanCount: 1, l: l) == "Guan 记录了本周照护")
        #expect(SingleMemberFamilyShapePresentation.weeklyReportLeaderPillSubtitle(humanCount: 1, l: l) == "本周照护者")
        #expect(SingleMemberFamilyShapePresentation.weeklyReportShareLeaderLabel(humanCount: 1, l: l) == "本周照护者")
        #expect(SingleMemberFamilyShapePresentation.weeklyReportRecentActivityEmptyText(humanCount: 1, l: l).contains("照护动态"))
        #expect(!SingleMemberFamilyShapePresentation.weeklyReportContributionSectionTitle(humanCount: 1, l: l).contains("排行"))
        #expect(!SingleMemberFamilyShapePresentation.weeklyReportLeaderStory(name: "Guan", humanCount: 1, l: l).contains("最多"))
    }

    @Test func multiHumanCopyKeepsRankingWhenThereIsRealComparison() {
        let l = L10n("zh")

        #expect(!SingleMemberFamilyShapePresentation.isSingleVisibleHumanFamily(humanCount: 2))
        #expect(SingleMemberFamilyShapePresentation.weeklyReportContributionSectionTitle(humanCount: 2, l: l) == "照护贡献排行")
        #expect(SingleMemberFamilyShapePresentation.weeklyReportLeaderStory(name: "Guan", humanCount: 2, l: l) == "Guan 照顾最多")
        #expect(SingleMemberFamilyShapePresentation.weeklyReportShareLeaderLabel(humanCount: 2, l: l) == "本周之星")
    }

    @Test func singleWealthRowUsesAccountShapeInsteadOfLeaderboard() {
        let l = L10n("zh")

        #expect(SingleMemberFamilyShapePresentation.wealthSectionTitle(rowCount: 1, l: l) == "椰子账户")
        #expect(SingleMemberFamilyShapePresentation.wealthEmptyText(visibleMemberCount: 1, l: l).contains("椰子账户"))
        #expect(!SingleMemberFamilyShapePresentation.showsWealthRank(rowCount: 1))
        #expect(!SingleMemberFamilyShapePresentation.wealthSectionTitle(rowCount: 1, l: l).contains("榜"))
        #expect(SingleMemberFamilyShapePresentation.wealthSectionTitle(rowCount: 2, l: l) == "财富榜")
        #expect(SingleMemberFamilyShapePresentation.showsWealthRank(rowCount: 2))
    }

    @Test func memberCountCapsuleUsesReadableSingularShape() {
        let zh = L10n("zh")
        let en = L10n("en")

        #expect(SingleMemberFamilyShapePresentation.familyMemberCountText(memberCount: 1, l: zh) == "1 位成员")
        #expect(SingleMemberFamilyShapePresentation.familyMemberCountText(memberCount: 2, l: zh) == "2 位成员")
        #expect(SingleMemberFamilyShapePresentation.familyMemberCountText(memberCount: 1, l: en) == "1 member")
        #expect(SingleMemberFamilyShapePresentation.familyMemberCountText(memberCount: 2, l: en) == "2 members")
    }
}

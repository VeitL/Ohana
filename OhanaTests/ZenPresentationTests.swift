import CoreGraphics
import Foundation
import Testing
@testable import Ohana

struct ZenPresentationTests {
    @Test func shellHasExactlyTheThreeMinimalTabs() {
        #expect(ZenTab.allCases == [.home, .streak, .oasis])
    }

    @Test func ownerStaysFirstThenSubjectsUseKindAndStableOrder() {
        let subjects = [
            subject(id: "plant", kind: .plant, name: "Fern", sortIndex: 0),
            subject(id: "pet-later", kind: .pet, name: "Zora", sortIndex: 2),
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, sortIndex: 5),
            subject(id: "human", kind: .human, name: "Alex", sortIndex: 0),
            subject(id: "pet-first", kind: .pet, name: "Milo", sortIndex: 1)
        ]

        #expect(ZenPresencePresentation.orderedSubjects(subjects).map(\.id) == [
            "owner",
            "human",
            "pet-first",
            "pet-later",
            "plant"
        ])
    }

    @Test func allCheckedPresentationDoesNotTreatAnEmptyHouseholdAsComplete() {
        #expect(!ZenPresencePresentation.allChecked([]))
        #expect(!ZenPresencePresentation.allChecked([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true)
        ]))
        #expect(ZenPresencePresentation.allChecked([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, checkedToday: true)
        ]))
        #expect(!ZenPresencePresentation.canEarnAllCheckedReward([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, checkedToday: true)
        ]))
        #expect(ZenPresencePresentation.canEarnAllCheckedReward([
            subject(id: "owner", kind: .human, name: "Me", isOwner: true, checkedToday: true),
            subject(id: "pet", kind: .pet, name: "Milo", checkedToday: true)
        ]))
    }

    @Test func presenceCardBackgroundsFollowCheckInAndStatusInsteadOfMemberTheme() {
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "pending", kind: .pet, name: "Milo", status: .great)
        ) == .pending)
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "checked", kind: .plant, name: "Fern", checkedToday: true)
        ) == .checked)
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "great", kind: .human, name: "Jo", checkedToday: true, status: .great, themeHex: "FF00FF")
        ) == .score(9))
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "okay", kind: .pet, name: "Milo", checkedToday: true, status: .okay, themeHex: "00FF00")
        ) == .score(7))
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "attention", kind: .plant, name: "Fern", checkedToday: true, status: .needsAttention)
        ) == .score(4))
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "poor", kind: .human, name: "Jo", checkedToday: true, status: .poor)
        ) == .score(2))
        #expect(ZenPresencePresentation.cardBackgroundState(for:
            subject(id: "score", kind: .human, name: "Jo", checkedToday: true, status: .score10)
        ) == .score(10))
    }

    @Test func currentStatusChoicesUseTenScoresAndBridgeLegacyFactsWithoutRewritingThem() {
        #expect(ZenPresenceStatus.selectableCases.map(\.score) == Array(1 ... 10))
        #expect(ZenPresenceStatus.poor.currentPresentationStatus == .score2)
        #expect(ZenPresenceStatus.needsAttention.currentPresentationStatus == .score4)
        #expect(ZenPresenceStatus.okay.currentPresentationStatus == .score7)
        #expect(ZenPresenceStatus.great.currentPresentationStatus == .score9)
        #expect(PresenceStatus.poor.score == 2)
        #expect(PresenceStatus.needsAttention.score == 4)
        #expect(PresenceStatus.okay.score == 7)
        #expect(PresenceStatus.great.score == 9)
        #expect(PresenceStatus(score: 10) == .score10)
        #expect(ZenPresencePresentation.CardBackgroundState.score(1).themeColorHex == "B9565D")
        #expect(ZenPresencePresentation.CardBackgroundState.score(10).themeColorHex == "087C68")
        #expect(ZenPresencePresentation.CardBackgroundState.score(1).themeColorHex !=
            ZenPresencePresentation.CardBackgroundState.score(10).themeColorHex)
    }

    @Test func zenCardDeckUsesTheStandardHomeGeometryForEveryCard() {
        for count in [1, 2, 4, 7, 8] {
            let mode = ZenPresenceCardDeckLayout.mode(cardCount: count)
            let height = ZenPresenceCardDeckLayout.sceneHeight(
                cardCount: count,
                containerWidth: 393,
                minimumViewportHeight: 520
            )
            let sceneSize = CGSize(width: 393, height: height)

            for index in 0 ..< count {
                #expect(ZenPresenceCardDeckLayout.frame(index: index, count: count, in: sceneSize) ==
                    FocusHomeVerticalSolidCollapsedLayoutPolicy.frame(
                        index: index,
                        count: count,
                        in: sceneSize,
                        mode: mode
                    ))
                #expect(ZenPresenceCardDeckLayout.rotation(index: index) ==
                    FocusHomeVerticalSolidCollapsedLayoutPolicy.rotation(index: index))
                #expect(ZenPresenceCardDeckLayout.zIndex(index: index, count: count) ==
                    FocusHomeVerticalSolidCollapsedLayoutPolicy.zIndex(
                        index: index,
                        count: count,
                        mode: mode
                    ))
            }
        }
    }

    @Test func zenExpandedCardUsesTheSharedStandardRatioAndWidthCap() {
        let frame = FocusHomeVerticalSolidExpandedLayoutPolicy.frame(
            in: CGSize(width: 430, height: 840),
            visibleCenterX: 215,
            safeTop: 12,
            safeBottom: 12,
            embedsQuickActionsInCard: true,
            placement: .sceneCenter
        )

        #expect(frame.width <= 386)
        #expect(abs(frame.height / frame.width - 1.58) < 0.001)
        #expect(frame.midX == 215)
    }

    @Test func cardScoreGestureStartsAtFiveOrTheCurrentScoreAndTracksVerticalTravel() {
        #expect(ZenCardScoreSelectionPolicy.initialScore(currentScore: nil) == 5)
        #expect(ZenCardScoreSelectionPolicy.initialScore(currentScore: 8) == 8)
        #expect(ZenCardScoreSelectionPolicy.initialScore(currentScore: -3) == 1)
        #expect(ZenCardScoreSelectionPolicy.initialScore(currentScore: 14) == 10)

        #expect(ZenCardScoreSelectionPolicy.score(startingAt: 5, translationY: 0) == 5)
        #expect(ZenCardScoreSelectionPolicy.score(startingAt: 5, translationY: -17) == 5)
        #expect(ZenCardScoreSelectionPolicy.score(startingAt: 5, translationY: -18) == 6)
        #expect(ZenCardScoreSelectionPolicy.score(startingAt: 5, translationY: 18) == 4)
        #expect(ZenCardScoreSelectionPolicy.score(startingAt: 5, translationY: -200) == 10)
        #expect(ZenCardScoreSelectionPolicy.score(startingAt: 5, translationY: 200) == 1)
    }

    @Test func scoreGestureSuppressesOnlyItsImmediateSyntheticTap() {
        let endedAt = Date(timeIntervalSince1970: 1000)
        let deadline = ZenCardScoreSelectionPolicy.quickTapSuppressionDeadline(after: endedAt)

        #expect(ZenCardScoreSelectionPolicy.suppressesQuickTap(now: endedAt, deadline: deadline))
        #expect(ZenCardScoreSelectionPolicy.suppressesQuickTap(
            now: endedAt.addingTimeInterval(0.17),
            deadline: deadline
        ))
        #expect(!ZenCardScoreSelectionPolicy.suppressesQuickTap(
            now: endedAt.addingTimeInterval(0.18),
            deadline: deadline
        ))
    }

    @Test func checkedCardTapOnlyBringsTheCardToFront() {
        #expect(ZenPresenceCardTapIntent.resolve(checkedToday: false) == .checkIn)
        #expect(ZenPresenceCardTapIntent.resolve(checkedToday: true) == .bringToFront)
    }

    @Test func scoreSelectionAndFocusedCardAlwaysRiseAboveTheStableDeck() {
        let base = ZenPresenceCardDeckLayout.interactiveZIndex(
            subjectID: "base",
            index: 2,
            count: 4,
            frontSubjectID: nil,
            scoreSelectingSubjectID: nil
        )
        let focused = ZenPresenceCardDeckLayout.interactiveZIndex(
            subjectID: "focused",
            index: 0,
            count: 4,
            frontSubjectID: "focused",
            scoreSelectingSubjectID: nil
        )
        let selecting = ZenPresenceCardDeckLayout.interactiveZIndex(
            subjectID: "selecting",
            index: 0,
            count: 4,
            frontSubjectID: "selecting",
            scoreSelectingSubjectID: "selecting"
        )

        #expect(focused > base)
        #expect(selecting > focused)
    }

    @Test func recentSevenDayStatusSummaryPrioritizesTodayAndClassifiesTrends() {
        let rising = ZenRecentStatusSummary.make(
            entries: [
                ZenRecentStatusEntry(dayKey: "2026-07-15", score: 3),
                ZenRecentStatusEntry(dayKey: "2026-07-16", score: 4),
                ZenRecentStatusEntry(dayKey: "2026-07-17", score: 7),
                ZenRecentStatusEntry(dayKey: "2026-07-18", score: 8)
            ],
            todayKey: "2026-07-18"
        )
        #expect(rising.todayScore == 8)
        #expect(rising.latestScore == 8)
        #expect(rising.scoredCount == 4)
        #expect(rising.trend == .rising)

        let steady = ZenRecentStatusSummary.make(
            entries: [
                ZenRecentStatusEntry(dayKey: "2026-07-15", score: 6),
                ZenRecentStatusEntry(dayKey: "2026-07-16", score: 7),
                ZenRecentStatusEntry(dayKey: "2026-07-17", score: 6)
            ],
            todayKey: "2026-07-18"
        )
        #expect(steady.todayScore == nil)
        #expect(steady.latestScore == 6)
        #expect(steady.trend == .steady)

        let softening = ZenRecentStatusSummary.make(
            entries: [
                ZenRecentStatusEntry(dayKey: "2026-07-15", score: 9),
                ZenRecentStatusEntry(dayKey: "2026-07-16", score: 8),
                ZenRecentStatusEntry(dayKey: "2026-07-17", score: 4)
            ],
            todayKey: "2026-07-18"
        )
        #expect(softening.trend == .softening)
        #expect(ZenRecentStatusSummary.make(
            entries: [ZenRecentStatusEntry(dayKey: "2026-07-17", score: 5)],
            todayKey: "2026-07-18"
        ).trend == .insufficient)
    }

    @Test func monthLayoutUsesTheConfiguredFirstWeekdayAndStableSixWeekViewport() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2
        let month = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))

        let slots = ZenCalendarLayout.slots(for: month, calendar: calendar)

        #expect(slots.count == 42)
        #expect(slots[0].date == nil)
        #expect(slots[1].date == nil)
        #expect(calendar.component(.day, from: try #require(slots[2].date)) == 1)
        #expect(calendar.component(.day, from: try #require(slots[32].date)) == 31)
        #expect(slots[33].date == nil)
        #expect(slots[34].date == nil)
        #expect(slots[41].date == nil)
        #expect(ZenCalendarViewportMetrics.pagerHeight(cellHeight: 42) == 308)
        #expect(ZenCalendarViewportMetrics.circleDiameter(cellHeight: 42) == 40)
    }

    @Test func missingHistoricalDayMeansNotParticipatingNotMissed() {
        #expect(ZenCalendarPresentation.participation(for: nil) == .notParticipating)

        let missedParticipatingDay = ZenPresenceDayDTO(
            subjectID: "owner",
            dayKey: "2026-07-17",
            checkedIn: false,
            participation: .participating
        )
        #expect(ZenCalendarPresentation.participation(for: missedParticipatingDay) == .participating)
    }

    @Test func retrospectiveStatusOnlyTargetsPastParticipatingMissesWithinSubjectLifetime() {
        let missedDay = ZenPresenceDayDTO(
            subjectID: "owner",
            dayKey: "2026-07-20",
            checkedIn: false,
            participation: .participating
        )
        #expect(ZenRetrospectiveStatusEligibility.allows(
            day: missedDay,
            targetDayKey: "2026-07-20",
            todayKey: "2026-07-22",
            subjectCreatedDayKey: "2026-07-01",
            subjectInactiveDayKey: nil,
            isAnonymousHistory: false
        ))

        let checkedDay = ZenPresenceDayDTO(
            subjectID: "owner",
            dayKey: "2026-07-20",
            checkedIn: true,
            status: .score8,
            participation: .participating
        )
        #expect(!ZenRetrospectiveStatusEligibility.allows(
            day: checkedDay,
            targetDayKey: "2026-07-20",
            todayKey: "2026-07-22",
            subjectCreatedDayKey: "2026-07-01",
            subjectInactiveDayKey: nil,
            isAnonymousHistory: false
        ))
        #expect(!ZenRetrospectiveStatusEligibility.allows(
            day: missedDay,
            targetDayKey: "2026-07-20",
            todayKey: "2026-07-22",
            subjectCreatedDayKey: "2026-07-21",
            subjectInactiveDayKey: nil,
            isAnonymousHistory: false
        ))
        #expect(!ZenRetrospectiveStatusEligibility.allows(
            day: missedDay,
            targetDayKey: "2026-07-20",
            todayKey: "2026-07-22",
            subjectCreatedDayKey: "2026-07-01",
            subjectInactiveDayKey: "2026-07-19",
            isAnonymousHistory: false
        ))
        #expect(!ZenRetrospectiveStatusEligibility.allows(
            day: missedDay,
            targetDayKey: "2026-07-20",
            todayKey: "2026-07-22",
            subjectCreatedDayKey: "2026-07-01",
            subjectInactiveDayKey: nil,
            isAnonymousHistory: true
        ))
    }

    @Test func personalAnalyticsExcludeStandardModeDaysFromCompletionDenominators() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let subject = subject(id: "owner", kind: .human, name: "Me", isOwner: true)
        let days = [
            analyticsDay(
                subjectID: subject.id,
                dayKey: "2026-07-13",
                checkedIn: true,
                participation: .participating
            ),
            analyticsDay(
                subjectID: subject.id,
                dayKey: "2026-07-14",
                checkedIn: false,
                participation: .participating
            ),
            analyticsDay(
                subjectID: subject.id,
                dayKey: "2026-07-15",
                checkedIn: false,
                participation: .notParticipating
            )
        ]
        let projection = ZenAnalyticsProjection(
            subjects: [subject],
            days: days,
            calendar: calendar
        )

        #expect(projection.participatingDays.count == 2)
        #expect(projection.checkedCount == 1)
        #expect(projection.completionRate == 50)
        #expect(projection.weeklyBins.count == 1)
        #expect(projection.weeklyBins.first?.participatingCount == 2)
        #expect(projection.weeklyBins.first?.rate == 50)
        #expect(projection.comparisonRows.first?.participatingCount == 2)
        #expect(projection.comparisonRows.first?.rate == 50)
    }

    @Test func personalAnalyticsCSVPreservesNotParticipatingSemantics() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let owner = subject(id: "owner", kind: .human, name: "Doe, \"Jo\"", isOwner: true)
        let day = analyticsDay(
            subjectID: owner.id,
            dayKey: "2026-07-15",
            checkedIn: false,
            participation: .notParticipating
        )

        let csv = ZenAnalyticsProjection(
            subjects: [owner],
            days: [day],
            calendar: calendar
        ).csvExport

        #expect(csv.hasPrefix("subject,date,participation,checked,status\n"))
        #expect(csv.contains("\"Doe, \"\"Jo\"\"\",2026-07-15,notParticipating,false,"))
    }

    @Test func personalAnalyticsRangesAreInclusiveAndStable() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 16)))

        let days90 = try #require(ZenAnalyticsRange.days90.cutoffDayKey(calendar: calendar, now: now))
        let year = try #require(ZenAnalyticsRange.year.cutoffDayKey(calendar: calendar, now: now))

        #expect(days90 == "2026-04-20")
        #expect(year == "2025-07-18")
        #expect(ZenAnalyticsRange.all.cutoffDayKey(calendar: calendar, now: now) == nil)
    }

    @Test func dateOnlyKeysStayOnTheSameCivilDayAcrossTimeZones() throws {
        for identifier in ["America/Los_Angeles", "Pacific/Kiritimati"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: identifier))

            let materialized = try #require(ZenDayKey.date("2026-01-01", calendar: calendar))

            #expect(ZenDayKey.key(for: materialized, calendar: calendar) == "2026-01-01")
            #expect(calendar.component(.day, from: materialized) == 1)
        }
    }

    @Test func oasisSnapshotClampsUntrustedDisplayValues() {
        let snapshot = ZenOasisSnapshot(
            isReady: true,
            level: 99,
            progressToNextLevel: .infinity,
            totalEnergy: -4,
            nextLevelThreshold: -1,
            coconutBalance: -20,
            canInjectEnergy: true
        )

        #expect(snapshot.level == 10)
        #expect(snapshot.progressToNextLevel == 0)
        #expect(snapshot.totalEnergy == 0)
        #expect(snapshot.nextLevelThreshold == 0)
        #expect(snapshot.coconutBalance == 0)
    }

    @Test func collapsedCardAccessoryKeepsAFullHitTargetWithoutDrawingAnOversizedBubble() {
        #expect(ZenPresenceCardAccessoryMetrics.minimumHitSize == 44)
        #expect(ZenPresenceCardAccessoryMetrics.collapsedVisualDiameter == 30)
        #expect(
            ZenPresenceCardAccessoryMetrics.collapsedVisualDiameter
                < ZenPresenceCardAccessoryMetrics.minimumHitSize
        )
        #expect(ZenPresenceCardAccessoryMetrics.collapsedSymbolSize == 11)
    }

    @Test func zenSurfacesExposeStableAccessibilityRootsAndAvoidHeavyHomeMounts() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let shell = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenShell.swift"),
            encoding: .utf8
        )
        let home = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenHomeView.swift"),
            encoding: .utf8
        )
        let streak = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenStreakView.swift"),
            encoding: .utf8
        )
        let oasis = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenOasisView.swift"),
            encoding: .utf8
        )
        let members = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenMembersView.swift"),
            encoding: .utf8
        )
        let analytics = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenPersonalAnalyticsView.swift"),
            encoding: .utf8
        )
        let standardCardScene = try String(
            contentsOf: root.appending(path: "Ohana/Features/Home/Views/FocusHomeVerticalSolidScene.swift"),
            encoding: .utf8
        )
        let zenCardBackground = try String(
            contentsOf: root.appending(path: "Ohana/Features/Zen/ZenPresenceCardBackground.swift"),
            encoding: .utf8
        )

        #expect(shell.contains("zen-native-tab-view"))
        #expect(shell.contains("zen-toolbar-coconut-log"))
        #expect(shell.contains("zen-toolbar-members"))
        #expect(shell.contains("zen-toolbar-settings"))
        #expect(home.contains("zen-home-screen"))
        #expect(home.contains("zen-home-expand-"))
        #expect(home.contains("zen-home-collapse-"))
        #expect(home.contains("compactMetricValueOverride:"))
        #expect(home.contains("showsStatusBadge: false"))
        #expect(streak.contains("zen-streak-screen"))
        #expect(streak.contains("zen-streak-month-pager"))
        #expect(streak.contains(".tabViewStyle(.page(indexDisplayMode: .never))"))
        #expect(streak.contains("ZenCalendarViewportMetrics.pagerHeight"))
        #expect(streak.contains("Color.ohanaCardSurface"))
        #expect(streak.contains(".contentTransition(.numericText())"))
        #expect(streak.contains("calendarIsPresented"))
        #expect(streak.contains("day?.status?.score"))
        #expect(oasis.contains("zen-oasis-screen"))
        #expect(oasis.contains("OasisHomeTabHost("))
        #expect(oasis.contains("OasisTreeRenderSnapshot("))
        #expect(oasis.contains("treeLayoutStyle: .zen"))
        #expect(oasis.contains("onOpenAchievements: actions.onOpenAchievements"))
        #expect(oasis.contains("onOpenGrowthRoadmap: actions.onOpenGrowthRoadmap"))
        #expect(!oasis.contains("ZenOasisTreeStageLayout"))
        #expect(!oasis.contains("private var routeGrid"))
        #expect(members.contains("zen-members-screen"))
        #expect(members.contains("ZenPresenceSubjectKind.allCases"))
        #expect(analytics.contains("zen-personal-analytics-screen"))
        #expect(analytics.contains("ShareLink(item: analytics.csvExport)"))
        #expect(analytics.contains("Chart(analytics.weeklyBins)"))
        #expect(home.contains("FocusHomeVerticalSolidCardSurface("))
        #expect(home.contains("LongPressGesture("))
        #expect(home.contains(".sequenced(before: DragGesture("))
        #expect(home.contains("Button(action: handleQuickTap)"))
        #expect(home.contains(".zenCardScoreSelectionGesture("))
        #expect(home.contains("isEnabled: presentation == .collapsed"))
        #expect(home.contains("ZenCardScoreSelectionOverlay("))
        #expect(home.contains("GeometryReader { cardGeometry in"))
        #expect(home.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
        #expect(home.contains("contentStyle: .nameOnly"))
        #expect(!home.contains("ZenCardScoreSelectionSurfaceModifier"))
        #expect(!home.contains("Up · better"))
        #expect(!home.contains("Down · attention"))
        #expect(home.contains("accessibilityAdjustableAction(action)"))
        #expect(home.contains("zen-home-auto-check-in-toast"))
        #expect(home.contains("ZenPresencePendingGlassOverlay("))
        #expect(home.contains("GoMotion.zenCardGlassDissolve"))
        #expect(home.contains("showsBorder: false"))
        #expect(home.contains("usesPlantSpecificBackground: false"))
        #expect(home.contains("ZenPresenceStatus(score: score)"))
        #expect(home.contains("for: .score(gesturePreviewScore),"))
        #expect(home.contains("shouldRunInteractionAnimation"))
        #expect(!home.contains("subject.themeHex"))
        #expect(!home.contains("fallbackThemeColor"))
        #expect(zenCardBackground.contains("CardBackgroundState"))
        #expect(zenCardBackground.contains("ZenPresencePendingGlassOverlay"))
        #expect(!zenCardBackground.contains("PrismaticSweep"))
        #expect(!zenCardBackground.contains("RevealMask"))
        #expect(!zenCardBackground.contains("repeatForever"))
        #expect(!zenCardBackground.contains("TimelineView"))
        #expect(!home.contains(".ohanaShine("))
        #expect(!home.contains("ZenScorePromptPopup"))
        #expect(!home.contains("zen-status-picker"))
        #expect(!home.contains("Slider(value:"))
        #expect(home.contains("ZenPresenceCardDeckLayout.frame("))
        #expect(!home.contains("ZenPresenceCardGrid"))
        #expect(standardCardScene.contains("FocusHomeVerticalSolidCollapsedLayoutPolicy.frame("))
        #expect(!home.contains("@Query"))
        #expect(!home.contains("VerticalSolidHomeView"))
        #expect(!home.contains("TaskCenter"))
        #expect(!home.contains("QuickCare"))
        #expect(!home.contains(".toolbar"))
        #expect(!oasis.contains(".toolbar"))
    }

    private func subject(
        id: String,
        kind: ZenPresenceSubjectKind,
        name: String,
        isOwner: Bool = false,
        sortIndex: Int = 0,
        checkedToday: Bool = false,
        status: ZenPresenceStatus? = nil,
        themeHex: String? = nil
    ) -> ZenPresenceSubjectDTO {
        ZenPresenceSubjectDTO(
            id: id,
            kind: kind,
            name: name,
            themeHex: themeHex,
            isOwner: isOwner,
            sortIndex: sortIndex,
            checkedToday: checkedToday,
            status: status
        )
    }

    private func analyticsDay(
        subjectID: String,
        dayKey: String,
        checkedIn: Bool,
        participation: ZenParticipationState
    ) -> ZenPresenceDayDTO {
        ZenPresenceDayDTO(
            subjectID: subjectID,
            dayKey: dayKey,
            checkedIn: checkedIn,
            participation: participation
        )
    }
}

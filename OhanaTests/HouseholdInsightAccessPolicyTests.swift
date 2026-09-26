import Testing
@testable import Ohana

@MainActor
@Suite(.serialized)
struct HouseholdInsightAccessPolicyTests {
    private let expectedLevels: [HouseholdInsightTab: Int] = [
        .weight: 1,
        .expense: 1,
        .weeklyReport: 6,
        .careAnalysis: 8,
        .reminderHealth: 8,
        .longTermReview: 9
    ]

    @Test func householdTabsHaveStableOrderAndExactTreeRequirements() {
        #expect(HouseholdInsightTab.allCases == [
            .weight,
            .expense,
            .weeklyReport,
            .careAnalysis,
            .reminderHealth,
            .longTermReview
        ])

        for tab in HouseholdInsightTab.allCases {
            let requiredLevel = expectedLevels[tab] ?? -1
            #expect(
                HouseholdInsightAccessPolicy.access(
                    for: tab,
                    currentLevel: max(0, requiredLevel - 1),
                    plan: .free
                ) == .locked(requiredLevel: requiredLevel)
            )
            #expect(
                HouseholdInsightAccessPolicy.access(
                    for: tab,
                    currentLevel: requiredLevel,
                    plan: .free
                ) == .available
            )
        }
    }

    @Test func freeMatrixMatchesEveryLevelFromZeroThroughTen() {
        for level in 0 ... 10 {
            for tab in HouseholdInsightTab.allCases {
                let requiredLevel = expectedLevels[tab] ?? -1
                let expected: HouseholdInsightAccess = level >= requiredLevel
                    ? .available
                    : .locked(requiredLevel: requiredLevel)
                #expect(
                    HouseholdInsightAccessPolicy.access(
                        for: tab,
                        currentLevel: level,
                        plan: .free
                    ) == expected
                )
            }
        }
    }

    @Test func personalAndFamilyOpenEveryInsightAtLevelZero() {
        for plan in [OhanaPlanLevel.personal, .family] {
            #expect(
                HouseholdInsightAccessPolicy.containerAccess(
                    currentLevel: 0,
                    plan: plan
                ) == .availableThroughPersonal
            )
            for tab in HouseholdInsightTab.allCases {
                #expect(
                    HouseholdInsightAccessPolicy.access(
                        for: tab,
                        currentLevel: 0,
                        plan: plan
                    ) == .availableThroughPersonal
                )
                if case .allow(tab.destination) = AppFeatureRouteGuard.functionDestinationDecision(
                    tab.destination,
                    currentLevel: 0,
                    plan: plan
                ) {
                } else {
                    Issue.record("Expected \(plan.rawValue) to open \(tab.rawValue) at Lv0")
                }
            }
        }
    }

    @Test func personalOnlyBypassesHouseholdInsightGates() {
        let retainedExistingPlantAccess = PlantUnlockPolicy.hasExistingPlantData()
        PlantUnlockPolicy.clearExistingPlantData()
        defer {
            if retainedExistingPlantAccess {
                PlantUnlockPolicy.noteExistingPlantData()
            }
        }

        #expect(AppFeatureRouteGuard.availability(
            for: FeatureGroup.householdHub,
            currentLevel: 0,
            plan: .personal
        ).isVisibleInApp)

        #expect(!AppFeatureRouteGuard.availability(
            for: FeatureGroup.healthBody,
            currentLevel: 0,
            plan: .personal
        ).isVisibleInApp)
        #expect(!AppFeatureRouteGuard.availability(
            for: FeatureGroup.plants,
            currentLevel: 3,
            plan: .personal
        ).isVisibleInApp)
        #expect(!AppFeatureRouteGuard.availability(
            for: FMDest.wealthDashboard,
            currentLevel: 4,
            plan: .personal
        ).isVisibleInApp)
        #expect(!AppFeatureRouteGuard.availability(
            for: FMDest.coconutShop,
            currentLevel: 5,
            plan: .personal
        ).isVisibleInApp)
        #expect(!AppFeatureRouteGuard.availability(
            for: FMDest.gacha,
            currentLevel: 6,
            plan: .personal
        ).isVisibleInApp)
        #expect(!GrowthUnlockPolicy.status(for: .mastery, currentLevel: 9).isUnlocked)
    }

    @Test func downgradeLocksOnlyAdvancedScopeAndKeepsTreeEarnedAccess() {
        #expect(HouseholdInsightAccessPolicy.access(
            for: .longTermReview,
            currentLevel: 1,
            plan: .personal
        ) == .availableThroughPersonal)
        #expect(HouseholdInsightAccessPolicy.access(
            for: .longTermReview,
            currentLevel: 1,
            plan: .free
        ) == .locked(requiredLevel: 9))

        #expect(HouseholdInsightAccessPolicy.access(
            for: .weight,
            currentLevel: 1,
            plan: .free
        ) == .available)
        #expect(HouseholdInsightAccessPolicy.access(
            for: .weeklyReport,
            currentLevel: 6,
            plan: .free
        ) == .available)
        #expect(HouseholdInsightAccessPolicy.access(
            for: .longTermReview,
            currentLevel: 9,
            plan: .free
        ) == .available)
    }

    @Test func destinationMappingIsBidirectional() {
        for tab in HouseholdInsightTab.allCases {
            #expect(HouseholdInsightTab.tab(for: tab.destination) == tab)
        }
        #expect(HouseholdInsightTab.tab(for: .gacha) == nil)
        #expect(HouseholdInsightAccessPolicy.includesUngatedSafetySummary(for: .reminderHealth))
        #expect(!HouseholdInsightAccessPolicy.includesUngatedSafetySummary(for: .careAnalysis))
    }

    @Test func coreInsightAndGrowthLabelsCoverEveryRegisteredLanguage() {
        let weeklyTitles = [
            "zh": "周报", "en": "Weekly", "de": "Woche", "es": "Semanal",
            "pt": "Semanal", "fr": "Semaine", "ja": "週間", "ko": "주간", "it": "Settimanale"
        ]
        let lifeCanopyTitles = [
            "zh": "生命树冠", "en": "Life Canopy", "de": "Lebenskrone", "es": "Copa de vida",
            "pt": "Copa da vida", "fr": "Canopée de vie", "ja": "生命の樹冠", "ko": "생명의 수관", "it": "Chioma della vita"
        ]

        #expect(Set(weeklyTitles.keys) == AppLanguage.supportedCodes)
        #expect(Set(lifeCanopyTitles.keys) == AppLanguage.supportedCodes)
        for language in AppLanguage.supportedCodes {
            #expect(HouseholdInsightTab.weeklyReport.title(language: language) == weeklyTitles[language])
            #expect(
                GrowthUnlockPolicy.status(for: .household, currentLevel: 4)
                    .step.title(language: language) == lifeCanopyTitles[language]
            )
        }
    }
}

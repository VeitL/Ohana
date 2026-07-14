import SwiftUI
import Testing
@testable import Ohana

@MainActor
struct QuickActionIconSystemTests {
    @Test func previewBaselineContainsExactlyTheApproved44UniqueGlyphs() {
        let expectedSlugs: Set<String> = [
            "feed", "calendar", "walk", "water", "potty", "medicine", "groom", "health",
            "sleep", "vet", "weight", "reminder", "plant-water", "play", "bath", "task",
            "food-stock", "dry-food", "wet-food", "treat", "food-bag", "feeder",
            "water-change", "filter-change", "litter", "cleanup", "walk-map", "distance",
            "training", "mood", "check-in", "family", "profile", "privacy", "expense",
            "insurance", "document", "photo", "birthday", "reward", "temperature",
            "plant-fertilize", "notification-health", "settings"
        ]
        let actualSlugs = OhanaQuickActionGlyphKind.previewCases.map(\.previewSlug)

        #expect(actualSlugs.count == 44)
        #expect(Set(actualSlugs) == expectedSlugs)
    }

    @Test func everyGlyphHasAccentGeometryAndRoundTripsThroughItsSlug() {
        for kind in OhanaQuickActionGlyphKind.allCases {
            #expect(kind.accentElementCount > 0)
            #expect(
                OhanaQuickActionGlyphKind.resolve(
                    actionType: kind.previewSlug,
                    fallbackSystemName: "questionmark"
                ) == kind
            )
        }
    }

    @Test func everyLiveQuickActionResolvesToItsOwnSemanticGlyph() {
        let cases: [(actionType: String, symbol: String, expected: OhanaQuickActionGlyphKind)] = [
            ("feed", "fork.knife", .feed),
            ("water", "drop.fill", .water),
            ("water", "water.waves", .waterChange),
            ("waterChange", "arrow.2.circlepath", .waterChange),
            ("filterClean", "sparkles", .filterChange),
            ("walk", "figure.walk", .walk),
            ("potty", "allergens", .potty),
            ("litter", "trash.fill", .litter),
            ("groom", "scissors", .groom),
            ("health", "heart.fill", .health),
            ("medication", "pill.fill", .medicine),
            ("expense", "creditcard.fill", .expense),
            ("weight", "scalemass.fill", .weight),
            ("play", "tennisball.fill", .play),
            ("moment", "camera.circle.fill", .photo),
            ("allFeatures", "square.grid.2x2.fill", .allFeatures),
            ("cageCleaning", "basket.fill", .cleanup),
            ("freeFlight", "bird.fill", .freeFlight),
            ("misting", "cloud.drizzle.fill", .misting),
            ("substrateChange", "leaf.fill", .substrateChange),
            ("humanWeight", "scalemass.fill", .weight),
            ("humanExpense", "creditcard.fill", .expense),
            ("humanMedication", "pill.fill", .medicine),
            ("humanWorkout", "figure.run", .workout),
            ("humanNote", "note.text", .document),
            ("plantWater", "drop.fill", .plantWater),
            ("fertilizePlant", "leaf.fill", .plantFertilize),
            ("plantMisting", "cloud.drizzle.fill", .misting),
            ("plantPruning", "scissors", .plantPruning),
            ("plantLeafCleaning", "sparkle.magnifyingglass", .cleanup),
            ("plantPestCheck", "ladybug.fill", .plantPestCheck),
            ("plantRotating", "arrow.triangle.2.circlepath", .plantRotating),
            ("plantRepotting", "shippingbox.fill", .plantRepotting),
            ("plantNewLeaf", "leaf.arrow.triangle.circlepath", .plantNewLeaf),
            ("plantYellowLeaf", "leaf.fill", .plantIssue),
            ("plantPestFound", "exclamationmark.triangle.fill", .plantIssue),
            ("plantNote", "note.text", .document),
            ("plantDetail", "info.circle.fill", .profile)
        ]

        for item in cases {
            #expect(
                OhanaQuickActionGlyphKind.resolve(
                    actionType: item.actionType,
                    fallbackSystemName: item.symbol
                ) == item.expected
            )
        }
    }

    @Test func checkInStatesUseTheApprovedAccentOpacityContract() {
        #expect(OhanaQuickActionIconStatePolicy.accentOpacity(
            isStateful: true,
            isInProgress: false,
            isCompleted: false
        ) == 0.16)
        #expect(OhanaQuickActionIconStatePolicy.accentOpacity(
            isStateful: true,
            isInProgress: true,
            isCompleted: false
        ) == 1)
        #expect(OhanaQuickActionIconStatePolicy.accentOpacity(
            isStateful: true,
            isInProgress: false,
            isCompleted: true
        ) == 1)
        #expect(OhanaQuickActionIconStatePolicy.accentOpacity(
            isStateful: false,
            isInProgress: false,
            isCompleted: false
        ) == 1)
    }

    @Test func stateTransitionsAndRepeatedTapsProduceDistinctAnimationTriggers() {
        let pending = OhanaQuickActionIconStatePolicy.animationTrigger(
            base: 0,
            isInProgress: false,
            isCompleted: false
        )
        let active = OhanaQuickActionIconStatePolicy.animationTrigger(
            base: 0,
            isInProgress: true,
            isCompleted: false
        )
        let completed = OhanaQuickActionIconStatePolicy.animationTrigger(
            base: 0,
            isInProgress: false,
            isCompleted: true
        )
        let nextTap = OhanaQuickActionIconStatePolicy.animationTrigger(
            base: 1,
            isInProgress: false,
            isCompleted: false
        )

        #expect(Set([pending, active, completed, nextTap]).count == 4)
    }

    @Test func highMeaningGlyphsUseTheirDedicatedAccentMotion() {
        #expect(OhanaQuickActionGlyphKind.water.motionKind(for: 0) == .waterDrop)
        #expect(OhanaQuickActionGlyphKind.waterChange.motionKind(for: 0) == .waterChange)
        #expect(OhanaQuickActionGlyphKind.weight.motionKind(for: 0) == .gauge)
        #expect(OhanaQuickActionGlyphKind.litter.motionKind(for: 2) == .litterScoop)
        #expect(OhanaQuickActionGlyphKind.temperature.motionKind(for: 0) == .temperatureMercury)
        #expect(OhanaQuickActionGlyphKind.sleep.motionKind(for: 0) == .sleep)
    }

    @Test func everyGlyphRendersOffscreenInPendingActiveAndCompletedStates() {
        let states = [
            (isInProgress: false, isCompleted: false),
            (isInProgress: true, isCompleted: false),
            (isInProgress: false, isCompleted: true)
        ]

        for kind in OhanaQuickActionGlyphKind.allCases {
            for state in states {
                let renderer = ImageRenderer(content:
                    OhanaQuickActionIcon(
                        actionType: kind.previewSlug,
                        fallbackSystemName: "questionmark",
                        size: 32,
                        color: .goTeal,
                        primaryColor: .goCardWhite,
                        isStateful: true,
                        isInProgress: state.isInProgress,
                        isCompleted: state.isCompleted,
                        showsCompletionBadge: true,
                        animatesStateChanges: false
                    )
                    .background(Color.arkInk)
                )
                renderer.scale = 1

                #expect(renderer.uiImage != nil)
            }
        }
    }
}

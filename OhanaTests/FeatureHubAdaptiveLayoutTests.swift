import Foundation
import Testing

struct FeatureHubAdaptiveLayoutTests {
    @Test func sharedFeatureHubCardsAndMetricsUseAdaptiveLongLanguageLayout() throws {
        let source = try source(
            "Ohana/Shared/Components/FeatureHubComponents.swift",
            rootURL: repositoryRootURL()
        )

        #expect(source.contains("GridItem(.adaptive(minimum: 118)"))
        #expect(source.contains("GridItem(.adaptive(minimum: 156)"))
        #expect(source.contains("struct FeatureHubSummaryPanel"))
        #expect(source.contains("FeatureHubMetricStrip(metrics: metrics)"))
        #expect(source.contains("Text(section.subtitle)"))
        #expect(source.contains("feature-hub-section-\\(section.id)"))
        #expect(source.contains("@Environment(\\.dynamicTypeSize) private var dynamicTypeSize"))
        #expect(source.contains(".lineLimit(2)"))
        #expect(source.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(source.contains(".frame(width: 44, height: 44)"))
        #expect(!source.contains("HStack(spacing: 10) {\n            ForEach(Array(metrics.enumerated())"))
        #expect(!source.contains("LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]"))
        #expect(!source.contains("Text(data.title)\n                        .font(OhanaFont.callout(.black))\n                        .foregroundStyle(Color.ohanaPrimaryText)\n                        .lineLimit(1)"))
    }

    @Test func petAndPlantFeatureCollectionHeadersFallbackForLongStatusText() throws {
        let petSource = try source(
            "Ohana/Features/FunctionMenu/Views/PetFeatureCollectionView.swift",
            rootURL: repositoryRootURL()
        )
        let plantSource = try source(
            "Ohana/Features/FunctionMenu/Views/PlantFeatureCollectionView.swift",
            rootURL: repositoryRootURL()
        )

        #expect(petSource.contains("FeatureHubSummaryPanel("))
        #expect(petSource.contains("summaryPanelStatusText"))
        #expect(try sharedSourceContainsViewThatFits())
        #expect(petSource.contains(".fixedSize(horizontal: false, vertical: true)"))

        #expect(plantSource.contains("commandCenterTitle"))
        #expect(plantSource.contains("commandCenterStatus"))
        #expect(plantSource.contains("commandCenterPillColumns"))
        #expect(plantSource.contains("GridItem(.adaptive(minimum: 112)"))
        #expect(plantSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(plantSource.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(!plantSource.contains("HStack(spacing: 8) {\n                commandCenterMiniPill("))
    }

    @Test func allFeatureHintsAndBannersAllowLongLocalizedCopy() throws {
        let humanSource = try source(
            "Ohana/Features/Members/Views/HumanAllFeaturesSheet.swift",
            rootURL: repositoryRootURL()
        )
        let plantSource = try source(
            "Ohana/Features/Plants/Views/PlantAllFeaturesSheet.swift",
            rootURL: repositoryRootURL()
        )
        let petSource = try source(
            "Ohana/Features/Members/Views/PetAllFeaturesSheet.swift",
            rootURL: repositoryRootURL()
        )
        let sharedSource = try source(
            "Ohana/Shared/Components/FeatureHubComponents.swift",
            rootURL: repositoryRootURL()
        )

        #expect(humanSource.contains("FeatureHubSummaryPanel("))
        #expect(humanSource.contains("human-all-features-summary-panel"))
        #expect(petSource.contains("FeatureHubSummaryPanel("))
        #expect(petSource.contains("pet-all-features-summary-panel"))
        #expect(humanSource.contains("private struct HumanOwnerPrivacyHint"))
        #expect(humanSource.contains("HStack(alignment: .top, spacing: 10)"))
        #expect(humanSource.contains("private struct HumanMemorialBanner"))
        #expect(humanSource.contains("HStack(alignment: .top, spacing: 12)"))
        #expect(humanSource.contains(".lineLimit(3)"))
        #expect(humanSource.contains(".accessibilityElement(children: .combine)"))

        #expect(plantSource.contains("focusActionCopy"))
        #expect(plantSource.contains("ViewThatFits(in: .horizontal)"))
        #expect(plantSource.contains(".lineLimit(3)"))
        #expect(!plantSource.contains("Text(action.title)\n                        .font(OhanaFont.adaptive(size: 16, weight: .black, design: .rounded))\n                        .foregroundStyle(Color.ohanaPrimaryText)\n                        .lineLimit(1)"))

        #expect(sharedSource.contains("struct PetMemorialBanner"))
        #expect(sharedSource.contains("HStack(alignment: .top, spacing: 12)"))
        #expect(sharedSource.contains(".lineLimit(3)"))
        #expect(!sharedSource.contains("struct PetMemorialBanner: View {\n    let pet: Pet\n    @Environment(\\.ohanaAppLanguageCode) private var appLanguage\n\n    private var l: L10n { L10n(appLanguage) }\n\n    var body: some View {\n        HStack(spacing: 12)"))
    }

    @Test func humanAllFeaturesUsesSingleCanonicalFeatureHubRoute() throws {
        let rootURL = repositoryRootURL()
        let routeSource = try source(
            "Ohana/Features/Members/HumanDetailSheetRouteContainer.swift",
            rootURL: rootURL
        )
        let homeRouteSource = try source(
            "Ohana/Features/Home/FocusHomeExpandedFabRouter.swift",
            rootURL: rootURL
        )

        #expect(routeSource.contains("HumanAllFeaturesSheet("))
        #expect(routeSource.contains("HumanAllFeaturesRouteData.load"))
        #expect(homeRouteSource.contains("actions.showHumanAllFeatures"))
        #expect(!sourceTreeContains("ExpandedHumanFeatures", rootURL: rootURL))
        #expect(!fileExists("Ohana/Features/Members/ExpandedHumanFeaturesDataContainer.swift", rootURL: rootURL))
        #expect(!fileExists("Ohana/Features/Members/Views/ExpandedHumanFeaturesSheet.swift", rootURL: rootURL))
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sharedSourceContainsViewThatFits() throws -> Bool {
        let sharedSource = try source(
            "Ohana/Shared/Components/FeatureHubComponents.swift",
            rootURL: repositoryRootURL()
        )
        return sharedSource.contains("ViewThatFits(in: .horizontal)")
    }

    private func fileExists(_ path: String, rootURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: rootURL.appending(path: path).path)
    }

    private func sourceTreeContains(_ needle: String, rootURL: URL) -> Bool {
        let roots = [
            rootURL.appending(path: "Ohana"),
            rootURL.appending(path: "OhanaTests")
        ]
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                guard fileURL.lastPathComponent != "FeatureHubAdaptiveLayoutTests.swift" else {
                    continue
                }
                if let source = try? String(contentsOf: fileURL, encoding: .utf8),
                   source.contains(needle) {
                    return true
                }
            }
        }
        return false
    }

    private func source(_ path: String, rootURL: URL) throws -> String {
        try String(contentsOf: rootURL.appending(path: path), encoding: .utf8)
    }
}

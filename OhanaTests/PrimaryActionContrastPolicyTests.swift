import Foundation
import XCTest
@testable import Ohana

final class PrimaryActionContrastPolicyTests: XCTestCase {
    func testGoPrimaryProminentButtonsDeclareAdaptiveForeground() throws {
        var violations: [String] = []

        for fileURL in try appSwiftSourceURLs() {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = source.components(separatedBy: .newlines)

            for index in lines.indices where lines[index].contains(".buttonStyle(.borderedProminent)") {
                let modifierEnd = min(lines.index(before: lines.endIndex), index + 6)
                let modifierContext = lines[index ... modifierEnd].joined(separator: "\n")
                guard modifierContext.contains(".tint(Color.goPrimary)") else { continue }

                let labelStart = max(lines.startIndex, index - 12)
                let buttonContext = lines[labelStart ... modifierEnd].joined(separator: "\n")
                if !buttonContext.contains(".foregroundStyle(Color.ohanaPrimaryActionText)") {
                    let relativePath = fileURL.path.replacingOccurrences(
                        of: repositoryRootURL().path + "/",
                        with: ""
                    )
                    violations.append("\(relativePath):\(index + 1)")
                }
            }
        }

        XCTAssertEqual(
            violations,
            [],
            "goPrimary prominent buttons must pair with Color.ohanaPrimaryActionText: \(violations.joined(separator: ", "))"
        )
    }

    func testSharedPrimaryButtonModifiersOwnContrastPairing() throws {
        let designSource = try source("Ohana/Shared/Design/OhanaUnifiedComponents.swift")
        let numericInput = try source("Ohana/Shared/Components/InlineNumericInput.swift")

        XCTAssertTrue(designSource.contains("func ohanaPrimaryProminentButton()"))
        XCTAssertTrue(designSource.contains(".foregroundStyle(Color.ohanaPrimaryActionText)"))
        XCTAssertTrue(designSource.contains("private struct OhanaGlassProminentButtonModifier"))
        XCTAssertTrue(numericInput.contains("var accentForeground: Color = .ohanaPrimaryActionText"))
        XCTAssertTrue(numericInput.contains(".foregroundStyle(accentForeground)"))
    }

    func testProminentButtonsNeverRelyOnInheritedAccentForeground() throws {
        var violations: [String] = []

        for fileURL in try appSwiftSourceURLs() {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = source.components(separatedBy: .newlines)

            for index in lines.indices where lines[index].contains(".buttonStyle(.borderedProminent)") {
                let contextStart = max(lines.startIndex, index - 16)
                let contextEnd = min(lines.index(before: lines.endIndex), index + 7)
                let context = lines[contextStart ... contextEnd].joined(separator: "\n")
                let usesExplicitForeground = context.contains(".foregroundStyle(")
                let usesSystemPrimaryChrome = context.contains(".tint(.primary)")
                guard !usesExplicitForeground, !usesSystemPrimaryChrome else { continue }

                let relativePath = fileURL.path.replacingOccurrences(
                    of: repositoryRootURL().path + "/",
                    with: ""
                )
                violations.append("\(relativePath):\(index + 1)")
            }
        }

        XCTAssertEqual(
            violations,
            [],
            "Prominent buttons must not inherit an unknown white foreground: \(violations.joined(separator: ", "))"
        )
    }

    func testAvatarActionsUsePrimaryColorAndCropFramesHaveNoCornerBrackets() throws {
        let avatar = try source("Ohana/Features/Members/Views/EditableProfileAvatarPicker.swift")
        let crop = try source("Ohana/Features/Members/Views/PetImageCropView.swift")
        let creationCrop = try source("Ohana/Features/Members/Views/MemberCardCreationMediaComponents.swift")

        XCTAssertTrue(avatar.contains(".foregroundStyle(Color.ohanaPrimaryActionText)"))
        XCTAssertTrue(avatar.contains(".background(Color.goPrimary, in: RoundedRectangle"))
        XCTAssertFalse(avatar.contains(".background(accentColor, in: RoundedRectangle"))

        XCTAssertTrue(crop.contains("RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)"))
        XCTAssertFalse(crop.contains("CardCropCorners"))
        XCTAssertFalse(crop.contains("private let len: CGFloat = 20"))

        XCTAssertTrue(creationCrop.contains("RoundedRectangle(cornerRadius: OhanaRadius.sheetComfort"))
        XCTAssertFalse(creationCrop.contains("CardCropCorners"))
    }

    func testBrightCustomSurfacesChooseForegroundFromTheirOwnFill() throws {
        let taskCenter = try source("Ohana/Features/Tasks/TaskCenterView.swift")
        let plantSelection = try source("Ohana/Features/Plants/Views/AddPlantView+PlantSelectionStep.swift")
        let symptom = try source("Ohana/Features/Health/Views/AddSymptomSheet.swift")
        let plantBatch = try source("Ohana/Features/Plants/Views/PlantBatchQuickRecordSheet.swift")
        let familyMap = try source("Ohana/Features/FamilyTasks/Views/FamilyCollaborationDashboardView+Map.swift")
        let zenStreak = try source("Ohana/Features/Zen/ZenStreakView.swift")
        let petMedication = try source("Ohana/Features/Medication/Views/PetMedicationView.swift")
        let petHygiene = try source("Ohana/Features/Hygiene/Views/PetHygieneDetailView.swift")

        XCTAssertTrue(taskCenter.contains(".foregroundStyle(Color.arkInk)"))
        XCTAssertTrue(taskCenter.contains(".background(Color.goTeal, in: Circle())"))
        XCTAssertTrue(plantSelection.contains("isSelected ? Color.arkInk : Color.ohanaTertiaryText"))
        XCTAssertTrue(symptom.contains("severity == level ? severityForeground(level)"))
        XCTAssertTrue(plantBatch.contains("careForeground(for: selectedCareType)"))
        XCTAssertTrue(familyMap.contains("selectedForeground: Color.arkInk"))
        XCTAssertTrue(zenStreak.contains("private var checkedInForeground: Color"))
        XCTAssertTrue(petMedication.contains("OhanaResolvedPrimaryAccent(customHex: med.colorHex)?.actionTextColor"))
        XCTAssertTrue(petHygiene.contains("private var themeActionForeground: Color"))
        XCTAssertTrue(petHygiene.contains(".foregroundStyle(themeActionForeground)"))
    }

    func testEveryPetThemeColorResolvesAReadableActionForeground() throws {
        for theme in PetThemeColor.allCases {
            let resolved = try XCTUnwrap(OhanaResolvedPrimaryAccent(customHex: theme.hexValue))
            XCTAssertGreaterThanOrEqual(
                contrastRatio(resolved.primaryHex, resolved.actionTextHex),
                4.5,
                "Pet theme \(theme.rawValue) must keep solid-button text readable"
            )
        }
    }

    func testAuditedFeatureAreasDoNotPairGoPrimaryWithFixedInk() throws {
        let auditedPrefixes = [
            "Ohana/Features/Achievements/",
            "Ohana/Features/Calendar/",
            "Ohana/Features/Economy/",
            "Ohana/Features/FamilyTasks/",
            "Ohana/Features/Gacha/",
            "Ohana/Features/Health/",
            "Ohana/Features/HumanNotes/",
            "Ohana/Features/Hygiene/",
            "Ohana/Features/Medication/",
            "Ohana/Features/Moments/",
            "Ohana/Features/Onboarding/",
            "Ohana/Features/SupporterPack/",
            "Ohana/Features/Walks/",
            "Ohana/Shared/Components/",
            "Ohana/Shared/Design/"
        ]
        let violations = try fixedForegroundViolations(
            foregroundMarkers: ["arkInk", "goCardWhite", "Color.white", ".white", "Color.black", ".black"],
            surfaceMarkers: ["Color.goPrimary"]
        ).filter { violation in
            auditedPrefixes.contains { violation.hasPrefix($0) } &&
                !violation.hasPrefix("Ohana/Shared/Components/FeatureHubComponents.swift:")
        }

        XCTAssertEqual(violations, [], "Audited goPrimary surfaces require adaptive action text: \(violations)")
    }

    func testSolidGoPrimarySurfacesNeverUseFixedInk() throws {
        let violations = try fixedForegroundViolations(
            foregroundMarkers: ["arkInk", "goCardWhite", "Color.white", ".white", "Color.black", ".black"],
            surfaceMarkers: ["Color.goPrimary"]
        )

        XCTAssertEqual(violations, [], "Solid goPrimary surfaces require adaptive action text: \(violations)")
    }

    func testTealAndOrangeSolidSurfacesNeverUseWhiteInk() throws {
        let violations = try fixedForegroundViolations(
            foregroundMarkers: ["goCardWhite", "Color.white", ".white"],
            surfaceMarkers: [
                "Color.goTeal",
                "Color.goOrange",
                "Color(hex: \"00D4AA\")",
                "Color(hex: \"FF8C42\")",
                "Color(hex: \"FF5A00\")"
            ]
        )

        XCTAssertEqual(violations, [], "Bright teal/orange surfaces require dark readable ink: \(violations)")
    }

    func testDynamicHexSurfacesNeverUseFixedInk() throws {
        let violations = try fixedForegroundViolations(
            foregroundMarkers: ["arkInk", "goCardWhite", "Color.white", ".white", "Color.black", ".black"],
            surfaceMarkers: ["Color(hex:"]
        )

        XCTAssertEqual(violations, [], "Dynamic hex surfaces must resolve their own readable action text: \(violations)")
    }

    func testResolvedCustomAccentAlwaysChoosesAAActionText() throws {
        for red in stride(from: 0, through: 255, by: 17) {
            for green in stride(from: 0, through: 255, by: 17) {
                for blue in stride(from: 0, through: 255, by: 17) {
                    let hex = String(format: "%02X%02X%02X", red, green, blue)
                    let resolved = try XCTUnwrap(OhanaResolvedPrimaryAccent(customHex: hex))
                    XCTAssertGreaterThanOrEqual(
                        contrastRatio(resolved.primaryHex, resolved.actionTextHex),
                        4.5,
                        "Dynamic accent #\(hex) must resolve readable action text"
                    )
                }
            }
        }
    }

    private func fixedForegroundViolations(
        foregroundMarkers: [String],
        surfaceMarkers: [String]
    ) throws -> [String] {
        var violations: [String] = []
        for fileURL in try appSwiftSourceURLs() {
            let lines = try String(contentsOf: fileURL, encoding: .utf8).components(separatedBy: .newlines)
            for index in lines.indices {
                let foregroundLine = lines[index]
                guard foregroundLine.contains(".foregroundStyle(") else { continue }
                guard !foregroundLine.contains("ohanaPrimaryActionText"),
                      !foregroundLine.contains("actionTextColor"),
                      !foregroundLine.contains("Foreground") else { continue }
                guard foregroundMarkers.contains(where: { foregroundLine.contains($0) }) else { continue }

                let indentation = foregroundLine.prefix(while: { $0 == " " || $0 == "\t" }).count
                let searchEnd = min(lines.index(before: lines.endIndex), index + 14)
                guard index < searchEnd else { continue }

                var surfaceIndex: Int?
                for candidate in index + 1 ... searchEnd {
                    let line = lines[candidate]
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmedLine.isEmpty else { continue }

                    let candidateIndentation = line.prefix(while: { $0 == " " || $0 == "\t" }).count
                    if candidateIndentation < indentation { break }
                    guard candidateIndentation == indentation else { continue }

                    if trimmedLine.hasPrefix(".background(") || trimmedLine.hasPrefix(".fill(") {
                        surfaceIndex = candidate
                        break
                    }
                    if !trimmedLine.hasPrefix("."),
                       !trimmedLine.hasPrefix(")"),
                       !trimmedLine.hasPrefix("}"),
                       !trimmedLine.hasPrefix("]") {
                        break
                    }
                }
                guard let surfaceIndex else { continue }

                let contextEnd = min(lines.index(before: lines.endIndex), surfaceIndex + 4)
                let surfaceContext = lines[surfaceIndex ... contextEnd].joined(separator: "\n")
                guard surfaceMarkers.contains(where: { containsOpaqueSurfaceMarker($0, in: surfaceContext) }) else { continue }

                let relativePath = fileURL.path.replacingOccurrences(
                    of: repositoryRootURL().path + "/",
                    with: ""
                )
                violations.append("\(relativePath):\(index + 1)")
            }
        }
        return violations
    }

    private func containsOpaqueSurfaceMarker(_ marker: String, in context: String) -> Bool {
        guard marker == "Color.goPrimary" else { return context.contains(marker) }

        var remainder = context[...]
        while let range = remainder.range(of: marker) {
            let suffix = remainder[range.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
            if !suffix.hasPrefix(".opacity(") { return true }
            remainder = suffix.dropFirst()
        }
        return false
    }

    private func appSwiftSourceURLs() throws -> [URL] {
        let appRoot = repositoryRootURL().appendingPathComponent("Ohana", isDirectory: true)
        let enumerator = try XCTUnwrap(
            FileManager.default.enumerator(
                at: appRoot,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        )
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "swift" else { return nil }
            return url
        }
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repositoryRootURL().appendingPathComponent(path), encoding: .utf8)
    }

    private func repositoryRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func contrastRatio(_ firstHex: String, _ secondHex: String) -> Double {
        let firstLuminance = relativeLuminance(firstHex)
        let secondLuminance = relativeLuminance(secondHex)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func relativeLuminance(_ hex: String) -> Double {
        guard let value = UInt64(hex, radix: 16) else { return 0 }
        let components = [
            Double((value >> 16) & 0xFF),
            Double((value >> 8) & 0xFF),
            Double(value & 0xFF)
        ].map { channel -> Double in
            let normalized = channel / 255
            return normalized <= 0.03928
                ? normalized / 12.92
                : pow((normalized + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]
    }
}

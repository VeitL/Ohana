import SwiftUI
import Testing
import UIKit
@testable import Ohana

struct ColorTokenPolicyTests {
    @Test func goPrimaryUsesChosenIslandPalette() {
        #expect(OhanaThemeColorPolicy.lightPrimaryHex == "2563EB")
        #expect(OhanaThemeColorPolicy.darkPrimaryHex == "C8F34A")
        #expect(hex(Color.goPrimary, style: .light) == "2563EB")
        #expect(hex(Color.goPrimary, style: .dark) == "C8F34A")
        #expect(hex(Color.goBlue, style: .light) == "2563EB")
        #expect(hex(Color.goLime, style: .dark) == "C8F34A")
    }

    @Test func primaryToneAliasesResolveForBothAppearances() {
        #expect(hex(Color.goPrimaryLight, style: .light) == "60A5FA")
        #expect(hex(Color.goPrimaryDark, style: .light) == "1D4ED8")
        #expect(hex(Color.goPrimaryLight, style: .dark) == "E3FA97")
        #expect(hex(Color.goPrimaryDark, style: .dark) == "91B82E")
        #expect(hex(Color.ohanaPrimaryActionText, style: .light) == "FFFFFF")
        #expect(hex(Color.ohanaPrimaryActionText, style: .dark) == "1A1A2E")
    }

    @Test func currentAndLegacyBrandColorsRemainUnavailableForMemberThemes() {
        #expect(OhanaThemeColorPolicy.isReservedMemberThemeHex("2563EB"))
        #expect(OhanaThemeColorPolicy.isReservedMemberThemeHex("C8F34A"))
        #expect(OhanaThemeColorPolicy.isReservedMemberThemeHex("3B82F6"))
        #expect(OhanaThemeColorPolicy.isReservedMemberThemeHex("C8FF00"))
    }

    @Test func chosenPaletteMaintainsInterfaceAndActionTextContrast() {
        let lightPrimary = OhanaThemeColorPolicy.lightPrimaryHex
        let darkPrimary = OhanaThemeColorPolicy.darkPrimaryHex
        let lightSurface = hex(Color.ohanaCardSurface, style: .light)
        let darkSurface = hex(Color.ohanaCardSurface, style: .dark)

        #expect(contrastRatio(lightPrimary, lightSurface) >= 3)
        #expect(contrastRatio(darkPrimary, darkSurface) >= 3)
        #expect(contrastRatio(lightPrimary, "FFFFFF") >= 4.5)
        #expect(contrastRatio(darkPrimary, "1A1A2E") >= 4.5)
    }

    @Test func debugAccentCandidatesResolveIndependentlyByAppearance() {
        #expect(OhanaPrimaryAccentPreferences.candidate(
            for: .light,
            lightRawValue: OhanaPrimaryAccentCandidate.orange.rawValue,
            darkRawValue: OhanaPrimaryAccentCandidate.purple.rawValue,
            allowsDeveloperOverride: true
        ) == .orange)
        #expect(OhanaPrimaryAccentPreferences.candidate(
            for: .dark,
            lightRawValue: OhanaPrimaryAccentCandidate.orange.rawValue,
            darkRawValue: OhanaPrimaryAccentCandidate.purple.rawValue,
            allowsDeveloperOverride: true
        ) == .purple)
    }

    @Test func releaseAndInvalidDebugAccentSelectionsFallBackToProductDefaults() {
        #expect(OhanaPrimaryAccentPreferences.candidate(
            for: .light,
            lightRawValue: OhanaPrimaryAccentCandidate.orange.rawValue,
            darkRawValue: OhanaPrimaryAccentCandidate.purple.rawValue,
            allowsDeveloperOverride: false
        ) == .blue)
        #expect(OhanaPrimaryAccentPreferences.candidate(
            for: .dark,
            lightRawValue: "unknown",
            darkRawValue: "unknown",
            allowsDeveloperOverride: true
        ) == .lime)
    }

    @Test func everyDebugAccentDefinesAReadableSolidButtonForeground() {
        #expect(OhanaPrimaryAccentCandidate.allCases.count >= 12)
        for candidate in OhanaPrimaryAccentCandidate.allCases {
            #expect(candidate.actionTextHex == "FFFFFF" || candidate.actionTextHex == "1A1A2E")
        }
        #expect(OhanaPrimaryAccentCandidate.blue.actionTextHex == "FFFFFF")
        #expect(OhanaPrimaryAccentCandidate.lime.actionTextHex == "1A1A2E")
    }

    @Test func customDebugAccentsResolveWithGeneratedToneScale() throws {
        let stored = try #require(OhanaPrimaryAccentPreferences.customStorageRawValue(hex: "#123456"))
        let custom = OhanaPrimaryAccentPreferences.resolvedAccent(
            for: .light,
            lightRawValue: stored,
            darkRawValue: OhanaPrimaryAccentCandidate.lime.rawValue,
            allowsDeveloperOverride: true
        )

        #expect(stored == "custom:123456")
        #expect(custom.isCustom)
        #expect(custom.primaryHex == "123456")
        #expect(custom.lighterHex == "597189")
        #expect(custom.darkerHex == "0E2841")
        #expect(custom.actionTextHex == "FFFFFF")
    }

    @Test func releaseAndMalformedCustomAccentsStillUseProductDefaults() {
        let validCustom = OhanaPrimaryAccentPreferences.resolvedAccent(
            for: .dark,
            lightRawValue: "custom:123456",
            darkRawValue: "custom:123456",
            allowsDeveloperOverride: false
        )
        let malformedCustom = OhanaPrimaryAccentPreferences.resolvedAccent(
            for: .light,
            lightRawValue: "custom:not-a-color",
            darkRawValue: nil,
            allowsDeveloperOverride: true
        )

        #expect(validCustom == OhanaResolvedPrimaryAccent(candidate: .lime))
        #expect(malformedCustom == OhanaResolvedPrimaryAccent(candidate: .blue))
    }

    private func hex(_ color: Color, style: UIUserInterfaceStyle) -> String {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: trait)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private func contrastRatio(_ firstHex: String, _ secondHex: String) -> Double {
        let firstLuminance = relativeLuminance(firstHex)
        let secondLuminance = relativeLuminance(secondHex)
        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
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

import SwiftUI
import Testing
import UIKit
@testable import Ohana

struct ColorTokenPolicyTests {
    @Test func goPrimaryResolvesToBlueInLightModeAndLimeInDarkMode() {
        #expect(hex(Color.goPrimary, style: .light) == OhanaThemeColorPolicy.lightPrimaryHex)
        #expect(hex(Color.goPrimary, style: .dark) == OhanaThemeColorPolicy.darkPrimaryHex)
    }

    @Test func primaryLightAndDarkAliasesAvoidLiteralLimeInLightMode() {
        #expect(hex(Color.goPrimaryLight, style: .light) == "60A5FA")
        #expect(hex(Color.goPrimaryDark, style: .light) == "2563EB")
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
}

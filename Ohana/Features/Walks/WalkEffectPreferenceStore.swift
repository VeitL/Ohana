import Foundation

enum WalkEffectPreferenceStore {
    static let rainbowRouteKey = "shop_equip_fx_rainbow"
    static let rainbowPoopKey = "shop_equip_fx_rainbow_poop"

    static func isRainbowRouteEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: rainbowRouteKey)
    }

    static func isRainbowPoopEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: rainbowPoopKey)
    }
}

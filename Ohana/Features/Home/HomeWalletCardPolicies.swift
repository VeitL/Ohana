//
//  HomeWalletCardPolicies.swift
//  Ohana
//
//  Home wallet-card theme, visibility, and active-human sync policies.
//

import SwiftUI
import UIKit

// MARK: - 钱包宠物卡共享视觉（向导草稿卡 + 首页持久化卡保持一致）

enum WalletPetCardTheme {
    /// 与 `WalletPetCardDraftFront` 一致：由 `themeColorHex` 推导顶/底渐变
    static func gradientPair(for hex: String) -> (Color, Color) {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let tc = PetThemeColor.allCases.first(where: { $0.hexValue.uppercased() == normalized }) {
            return (tc.color, tc.deepColor)
        }
        let c = Color(hex: hex)
        let ui = UIColor(c)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        guard ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) else {
            return (Color(hex: "233BFF"), Color(hex: "141FAE"))
        }
        let topB = min(1.0, bri * 1.1)
        let botB = max(0.12, bri * 0.4)
        let top = Color(UIColor(hue: hue, saturation: min(1, sat * 0.92), brightness: topB, alpha: alpha))
        let bottom = Color(UIColor(hue: hue, saturation: min(1, sat * 1.02), brightness: botB, alpha: alpha))
        return (top, bottom)
    }

    /// 与草稿卡一致：约 6 字内满幅，更长则缩小
    static func headlinePointSize(cardWidth w: CGFloat, headlineCount: Int) -> CGFloat {
        let n = max(1, headlineCount)
        let base = w * 0.24
        if n <= 6 { return base }
        let ratio = 6.0 / Double(n)
        let softened = pow(ratio, 0.82)
        return max(w * 0.074, base * CGFloat(softened))
    }

    /// 与添加向导 `resolvedCoatColor` 一致，供首页剪影（`pet.coatColor` 存展示名而非 hex）
    nonisolated static func silhouetteCoatColor(for pet: Pet) -> Color {
        let name = pet.coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return Color(hex: "E8C49A") }
        if name == "自定义" { return Color(hex: "E8C49A") }
        if let pattern = PetCoatPattern.allCases.first(where: { $0.displayName == name }) {
            switch pattern {
            case .calico: return Color(hex: "D4B896")
            case .silverChinchilla: return Color(hex: "C8C8C8")
            case .tortoiseshell: return Color(hex: "6E2C00")
            case .cowPattern: return .white
            case .bicolor: return Color(hex: "95ADBE")
            }
        }
        let bi = PetBreedDatabase.breeds(for: pet.species).first { $0.name == pet.breed }
        let coatItems = bi?.coatColors ?? PetBreedDatabase.genericCoatColors
        if let found = coatItems.first(where: { $0.name == name }) { return found.color }
        if name.count == 6, name.allSatisfy(\.isHexDigit) { return Color(hex: name) }
        return Color(hex: "E8C49A")
    }

    nonisolated static func silhouetteEyeColor(for pet: Pet) -> Color {
        let name = pet.eyeColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return Color(hex: "6B3A2A") }
        if name == "自定义" { return Color(hex: "6B3A2A") }
        let bi = PetBreedDatabase.breeds(for: pet.species).first { $0.name == pet.breed }
        let eyeItems = bi?.eyeColors ?? PetBreedDatabase.genericEyeColors
        if let found = eyeItems.first(where: { $0.name == name }) { return found.color }
        if name.count == 6, name.allSatisfy(\.isHexDigit) { return Color(hex: name) }
        return Color(hex: "6B3A2A")
    }

    nonisolated static func coatPatternName(for pet: Pet) -> String? {
        PetCoatPattern.allCases.first { $0.displayName == pet.coatColor }?.displayName
    }

    /// Generate 3x3 mesh gradient colors derived from themeColorHex
    static func meshColors(for hex: String) -> [Color] {
        let (top, bottom) = gradientPair(for: hex)
        let ui = UIColor(top)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return Array(repeating: top, count: 9)
        }
        let lighter = Color(UIColor(hue: h, saturation: max(0, s * 0.68), brightness: min(1.0, b * 1.22), alpha: a))
        let light = Color(UIColor(hue: h, saturation: s, brightness: min(1.0, b * 1.06), alpha: a))
        let darker = Color(UIColor(hue: h, saturation: min(1.0, s * 1.12), brightness: max(0.08, b * 0.22), alpha: a))
        return [
            lighter, light, top,
            light, top, bottom,
            top, bottom, darker
        ]
    }

    static func prefersDarkForeground(for hex: String) -> Bool {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let sourceHex = PetThemeColor.allCases.first(where: { $0.hexValue.uppercased() == normalized })?.hexValue ?? normalized
        guard sourceHex.count == 6,
              let r = Int(sourceHex.prefix(2), radix: 16),
              let g = Int(sourceHex.dropFirst(2).prefix(2), radix: 16),
              let b = Int(sourceHex.dropFirst(4), radix: 16)
        else {
            return false
        }
        func channel(_ value: Int) -> Double {
            let s = Double(value) / 255.0
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        return luminance > 0.50
    }

    static func foreground(for hex: String, opacity: Double = 1) -> Color {
        prefersDarkForeground(for: hex)
            ? Color.arkInk.opacity(opacity)
            : Color.goCardWhite.opacity(opacity)
    }
}

enum HomeCardVisibility {
    static let hiddenPetIDsKey = "hiddenHomePetIDs.v1"
    static let maxVisibleCards = FocusHomeCardDataSource.maxCardsPerPage

    static func storedHiddenPetIDsRaw(defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: hiddenPetIDsKey) ?? ""
    }

    static func storedHiddenPetIDsRawIfPresent(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: hiddenPetIDsKey)
    }

    static func persistHiddenPetIDsRaw(_ raw: String, defaults: UserDefaults = .standard) {
        defaults.set(raw, forKey: hiddenPetIDsKey)
    }

    static func restoreHiddenPetIDsRaw(_ previousRaw: String?, defaults: UserDefaults = .standard) {
        if let previousRaw {
            defaults.set(previousRaw, forKey: hiddenPetIDsKey)
        } else {
            defaults.removeObject(forKey: hiddenPetIDsKey)
        }
    }

    @discardableResult
    static func setPetVisible(
        _ pet: Pet,
        visible: Bool,
        raw: String,
        defaults: UserDefaults = .standard
    ) -> String {
        let updated = rawBySettingPet(pet, visible: visible, raw: raw)
        persistHiddenPetIDsRaw(updated, defaults: defaults)
        return updated
    }

    nonisolated static func isPetIDVisible(_ id: UUID, raw: String? = nil) -> Bool {
        !hiddenPetIDs(from: raw ?? "")
            .contains(id.uuidString)
    }

    nonisolated static func isPetVisible(_ pet: Pet, raw: String? = nil) -> Bool {
        isPetIDVisible(pet.id, raw: raw)
    }

    static func visibleCardCount(pets: [Pet], humans: [Human], raw: String? = nil) -> Int {
        let hiddenRaw = raw ?? ""
        let petCount = pets.count(where: { !$0.hasPassedAway && isPetVisible($0, raw: hiddenRaw) })
        let humanCount = humans.filter(\.shouldShowOnHome).count
        return petCount + humanCount
    }

    static func canShowPet(_ pet: Pet, pets: [Pet], humans: [Human], raw: String? = nil) -> Bool {
        if isPetVisible(pet, raw: raw) { return true }
        return visibleCardCount(pets: pets, humans: humans, raw: raw) < maxVisibleCards
    }

    static func canShowHuman(_ human: Human, pets: [Pet], humans: [Human], raw: String? = nil) -> Bool {
        if human.shouldShowOnHome { return true }
        return visibleCardCount(pets: pets, humans: humans, raw: raw) < maxVisibleCards
    }

    static func rawBySettingPet(_ pet: Pet, visible: Bool, raw: String) -> String {
        var ids = hiddenPetIDs(from: raw)
        if visible {
            ids.remove(pet.id.uuidString)
        } else {
            ids.insert(pet.id.uuidString)
        }
        return encodedHiddenPetIDs(ids)
    }

    private nonisolated static func hiddenPetIDs(from raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init))
    }

    private static func encodedHiddenPetIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }
}

@MainActor
enum HomeActiveHumanCardSync {
    static func applyAfterAccountSwitch(
        from oldHumanIdRaw: String,
        to newHuman: Human,
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet] = [],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: inout String
    ) -> Bool {
        let newId = newHuman.id.uuidString
        let oldId = UUID(uuidString: oldHumanIdRaw)?.uuidString
        let stackIds = currentHomeStackIds(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw
        )

        guard !stackIds.contains(newId) else { return false }

        if stackIds.count < HomeCardVisibility.maxVisibleCards {
            let oldOrderRaw = homeCardOrderRaw
            let wasShown = newHuman.shouldShowOnHome
            newHuman.shouldShowOnHome = true
            homeCardOrderRaw = orderRawByInserting(
                newId,
                after: oldId,
                currentRaw: homeCardOrderRaw,
                currentStackIds: stackIds
            )
            return !wasShown || homeCardOrderRaw != oldOrderRaw
        }

        guard let oldId,
              oldId != newId,
              let oldHuman = humans.first(where: { $0.id.uuidString == oldId }),
              oldHuman.shouldShowOnHome else {
            return false
        }

        let oldOrderRaw = homeCardOrderRaw
        let oldWasShown = oldHuman.shouldShowOnHome
        let newWasShown = newHuman.shouldShowOnHome
        oldHuman.shouldShowOnHome = false
        newHuman.shouldShowOnHome = true
        homeCardOrderRaw = orderRawByReplacing(
            oldId,
            with: newId,
            currentRaw: homeCardOrderRaw,
            currentStackIds: stackIds
        )
        return oldWasShown || !newWasShown || homeCardOrderRaw != oldOrderRaw
    }

    private static func currentHomeStackIds(
        pets: [Pet],
        humans: [Human],
        electronicPets: [OasisElectronicPet],
        hiddenPetIDsRaw: String,
        homeCardOrderRaw: String
    ) -> [String] {
        FocusHomeCardDataSource.buildSnapshot(
            pets: pets,
            humans: humans,
            electronicPets: electronicPets,
            hiddenPetIDsRaw: hiddenPetIDsRaw,
            homeCardOrderRaw: homeCardOrderRaw,
            showDummyCards: false
        )
        .prefix(HomeCardVisibility.maxVisibleCards)
        .map(\.id.uuidString)
    }

    private static func orderRawByInserting(
        _ newId: String,
        after oldId: String?,
        currentRaw: String,
        currentStackIds: [String]
    ) -> String {
        var ids = normalizedOrder(currentRaw: currentRaw, currentStackIds: currentStackIds)
        ids.removeAll { $0 == newId }
        if let oldId, let oldIndex = ids.firstIndex(of: oldId) {
            ids.insert(newId, at: min(oldIndex + 1, ids.count))
        } else {
            ids.insert(newId, at: 0)
        }
        return encodedOrder(ids)
    }

    private static func orderRawByReplacing(
        _ oldId: String,
        with newId: String,
        currentRaw: String,
        currentStackIds: [String]
    ) -> String {
        var ids = normalizedOrder(currentRaw: currentRaw, currentStackIds: currentStackIds)
        if let oldIndex = ids.firstIndex(of: oldId) {
            ids[oldIndex] = newId
        } else {
            ids.insert(newId, at: 0)
        }
        ids.removeAll { $0 == oldId }
        return encodedOrder(ids)
    }

    private static func normalizedOrder(currentRaw: String, currentStackIds: [String]) -> [String] {
        unique(currentStackIds + decodedOrder(currentRaw))
    }

    private static func decodedOrder(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map(String.init)
            .filter { UUID(uuidString: $0) != nil }
    }

    private static func encodedOrder(_ ids: [String]) -> String {
        unique(ids).joined(separator: ",")
    }

    private static func unique(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }
}

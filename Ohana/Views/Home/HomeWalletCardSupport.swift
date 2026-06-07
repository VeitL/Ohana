//
//  HomeWalletCardSupport.swift
//  Ohana
//
//  Shared home wallet card theme, visibility, photo, and creation-preview support.
//

import SwiftData
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
    static func silhouetteCoatColor(for pet: Pet) -> Color {
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
        if name.count == 6, name.allSatisfy({ $0.isHexDigit }) { return Color(hex: name) }
        return Color(hex: "E8C49A")
    }

    static func silhouetteEyeColor(for pet: Pet) -> Color {
        let name = pet.eyeColor.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return Color(hex: "6B3A2A") }
        if name == "自定义" { return Color(hex: "6B3A2A") }
        let bi = PetBreedDatabase.breeds(for: pet.species).first { $0.name == pet.breed }
        let eyeItems = bi?.eyeColors ?? PetBreedDatabase.genericEyeColors
        if let found = eyeItems.first(where: { $0.name == name }) { return found.color }
        if name.count == 6, name.allSatisfy({ $0.isHexDigit }) { return Color(hex: name) }
        return Color(hex: "6B3A2A")
    }

    static func coatPatternName(for pet: Pet) -> String? {
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
            top, bottom, darker,
        ]
    }

    static func prefersDarkForeground(for hex: String) -> Bool {
        let normalized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let sourceHex = PetThemeColor.allCases.first(where: { $0.hexValue.uppercased() == normalized })?.hexValue ?? normalized
        guard sourceHex.count == 6,
              let r = Int(sourceHex.prefix(2), radix: 16),
              let g = Int(sourceHex.dropFirst(2).prefix(2), radix: 16),
              let b = Int(sourceHex.dropFirst(4).prefix(2), radix: 16)
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

    static func isPetIDVisible(_ id: UUID, raw: String? = nil) -> Bool {
        !hiddenPetIDs(from: raw ?? UserDefaults.standard.string(forKey: hiddenPetIDsKey) ?? "")
            .contains(id.uuidString)
    }

    static func isPetVisible(_ pet: Pet, raw: String? = nil) -> Bool {
        isPetIDVisible(pet.id, raw: raw)
    }

    static func visibleCardCount(pets: [Pet], humans: [Human], raw: String? = nil) -> Int {
        let hiddenRaw = raw ?? UserDefaults.standard.string(forKey: hiddenPetIDsKey) ?? ""
        let petCount = pets.filter { !$0.hasPassedAway && isPetVisible($0, raw: hiddenRaw) }.count
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

    private static func hiddenPetIDs(from raw: String) -> Set<String> {
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
        .map { $0.id.uuidString }
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

// MARK: - 钱包卡右侧可读性叠层（材质模糊 + 压暗；全幅绘制 + 软 mask，避免中间竖向硬分界）

struct WalletCardTrailingReadabilityOverlay: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let width: CGFloat
    let height: CGFloat

    /// 控制叠层从左到右逐渐显现，与照片做长距离柔和过渡（非矩形裁切左缘）
    private var edgeSoftMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.06), location: 0.34),
                .init(color: .white.opacity(0.42), location: 0.48),
                .init(color: .white.opacity(0.88), location: 0.66),
                .init(color: .white, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// 压暗随横向连续加深，最暗在右缘（文案区），左侧与照片自然衔接
    private var darkenGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0), location: 0),
                .init(color: .black.opacity(reduceTransparency ? 0.12 : 0.06), location: 0.38),
                .init(color: .black.opacity(reduceTransparency ? 0.52 : 0.28), location: 0.72),
                .init(color: .black.opacity(reduceTransparency ? 0.82 : 0.58), location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            if reduceTransparency {
                Rectangle()
                    .fill(Color(UIColor.systemBackground).opacity(0.94))
            } else {
                Rectangle()
                    .fill(Color.ohanaCardSurface)
            }
            Rectangle()
                .fill(darkenGradient)
                .allowsHitTesting(false)
        }
        .frame(width: width, height: height)
        .mask(edgeSoftMask)
        .allowsHitTesting(false)
    }
}

struct WalletCardAdaptivePhotoLayer: View {
    enum Mode { case compact, expanded }

    let image: UIImage
    let width: CGFloat
    let height: CGFloat
    var mode: Mode = .compact

    var body: some View {
        ZStack(alignment: .leading) {
            if mode == .expanded {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                WalletCardTrailingReadabilityOverlay(width: width, height: height)
                WalletCardBottomRightTextShadow(width: width, height: height, isExpanded: true)
            } else {
                let photoW = compactPhotoRenderedWidth
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: photoW, height: height)
                    .clipped()
                    .frame(width: width, height: height, alignment: .leading)
                    .saturation(1.04)
                    .contrast(1.02)
                    .mask(WalletCardCompactPhotoMask(width: width, height: height))
                WalletCardBottomRightTextShadow(width: width, height: height, isExpanded: false)
            }
        }
        .allowsHitTesting(false)
    }

    private var compactPhotoRenderedWidth: CGFloat {
        guard image.size.height > 0 else { return width }
        return max(width, height * image.size.width / image.size.height)
    }
}

struct WalletCardVerticalPhotoBlendLayer: View {
    let image: UIImage
    let width: CGFloat
    let height: CGFloat
    let themeColorHex: String
    var shadowDepth: Double = 1

    private var themeTop: Color {
        WalletPetCardTheme.gradientPair(for: themeColorHex).0
    }

    private var themeBottom: Color {
        WalletPetCardTheme.gradientPair(for: themeColorHex).1
    }

    var body: some View {
        ZStack(alignment: .top) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: width, height: height, alignment: .top)
                .clipped()
                .saturation(1.03)
                .contrast(1.03)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.00), location: 0.00),
                    .init(color: .black.opacity(0.03 * shadowDepth), location: 0.34),
                    .init(color: .black.opacity(0.14 * shadowDepth), location: 0.52),
                    .init(color: .black.opacity(0.34 * shadowDepth), location: 0.70),
                    .init(color: .black.opacity(0.56 * shadowDepth), location: 0.88),
                    .init(color: .black.opacity(0.70 * shadowDepth), location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: .clear, location: 0.43),
                    .init(color: themeTop.opacity(0.10), location: 0.54),
                    .init(color: themeTop.opacity(0.34), location: 0.66),
                    .init(color: themeBottom.opacity(0.74), location: 0.82),
                    .init(color: themeBottom, location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
    }
}

private struct WalletCardCompactPhotoMask: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: 0.46),
                .init(color: .white.opacity(0.72), location: 0.60),
                .init(color: .white.opacity(0.18), location: 0.76),
                .init(color: .clear, location: 0.92),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width, height: height)
    }
}

private struct WalletCardBottomRightTextShadow: View {
    let width: CGFloat
    let height: CGFloat
    var isExpanded: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black.opacity(isExpanded ? 0.18 : 0.10), location: 0.38),
                    .init(color: .black.opacity(isExpanded ? 0.44 : 0.32), location: 0.76),
                    .init(color: .black.opacity(isExpanded ? 0.62 : 0.46), location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    .black.opacity(isExpanded ? 0.56 : 0.42),
                    .black.opacity(isExpanded ? 0.28 : 0.20),
                    .clear,
                ],
                center: .bottomTrailing,
                startRadius: 8,
                endRadius: min(width, height) * (isExpanded ? 0.78 : 0.66)
            )
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Pet Card Front (Wizard Draft)

/// 添加宠物向导顶部固定预览：数据随表单逐步填充，不依赖 SwiftData `Pet`。
struct WalletPetCardDraftFront: View {
    var name: String
    var species: String
    /// 脚注用品种文案（已解析「其他」+ 自定义）
    var breedFootnote: String
    var avatarImageData: Data?
    /// 父视图异步解码，避免每次重绘时重复 `UIImage(data:)` / 透明检测
    var decodedAvatar: UIImage? = nil
    var decodedAvatarIsTransparent: Bool = false
    var coatColor: Color
    var eyeColor: Color
    var coatPatternName: String?
    var hasBirthday: Bool
    /// 与 `Pet.ageText` 风格一致的一句年龄（空则脚注省略年龄）
    var ageFootnote: String
    var hasHomeDate: Bool
    var daysTogether: Int
    /// 与主题色选择同步的卡面渐变（与 `Pet.themeColorHex` 一致）
    var themeColorHex: String
    let cornerRadius: CGFloat

    private let accent = Color(hex: "FF5A3D")

    private var cardGradientTop: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).0 }
    private var cardGradientBottom: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).1 }

    private var headlineText: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return trimmed.uppercased()
    }

    private var footnote: String {
        var parts: [String] = []
        if hasBirthday, !ageFootnote.isEmpty { parts.append(ageFootnote) }
        if !breedFootnote.isEmpty { parts.append(breedFootnote) }
        else if !species.isEmpty { parts.append(species) }
        if parts.isEmpty { parts.append("Ohana PET ID") }
        return parts.joined(separator: " · ")
    }

    private var daysTogetherLabel: String {
        guard hasHomeDate else { return "—" }
        let d = daysTogether
        if d < 0 { return "\(abs(d))" }
        return "\(d)"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = decodedAvatar
            let isTransparent: Bool = {
                if decodedAvatar != nil { return decodedAvatarIsTransparent }
                return false
            }()
            let hasPopout = isTransparent && avatarImage != nil
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent
            let useDarkText = !usesFullBleedPhoto && WalletPetCardTheme.prefersDarkForeground(for: themeColorHex)
            let primaryText = useDarkText ? Color.arkInk : Color.goCardWhite
            let secondaryText = primaryText.opacity(useDarkText ? 0.72 : 0.70)

            ZStack {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                        SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                        SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
                    ],
                    colors: WalletPetCardTheme.meshColors(for: themeColorHex)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                useDarkText
                                    ? Color.goCardWhite.opacity(0.20)
                                    : Color.arkInk.opacity(usesFullBleedPhoto ? 0.12 : 0.22),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if let img = avatarImage, !isTransparent {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                        .allowsHitTesting(false)
                }

                Text(headlineText)
                    .font(.system(size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: headlineText.count), weight: .black, design: .rounded))
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)

                if avatarImage == nil || hasPopout {
                    draftAvatarLayer(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                        .frame(width: w, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                VStack(alignment: .trailing, spacing: 5) {
                    Spacer()

                    Text(daysTogetherLabel)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text("Days Together")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText.opacity(useDarkText ? 0.82 : 0.92))

                    Text(footnote)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    draftBarcode(foreground: primaryText)
                        .padding(.top, 8)
                }
                .padding(.trailing, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func draftAvatarLayer(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage {
            if isTransparent {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.68, height: h * 1.42, alignment: .bottom)
                    .frame(width: w, height: h, alignment: .bottomLeading)
                    .offset(x: w * 0.01, y: h * 0.42)
                    .shadow(color: Color.goCardWhite.opacity(0.50), radius: 3, x: 0, y: 0) // ui-v4: allow transparent draft avatar halo.
                    .shadow(color: Color.arkInk.opacity(0.30), radius: 18, x: 0, y: 12) // ui-v4: allow transparent draft avatar grounding shadow.
            } else {
                EmptyView()
            }
        } else {
            let sp = species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let silSpecies = (sp == "dog" || species == "狗") ? "狗" :
                (sp == "cat" || species == "猫") ? "猫" : species
            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.16))
                    .frame(width: w * 0.28, height: 24)
                    .blur(radius: 10)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: silSpecies,
                    coatColor: coatColor,
                    eyeColor: eyeColor,
                    patternName: coatPatternName,
                    isAnimationEnabled: false
                )
                .scaleEffect(0.92)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func draftBarcode(foreground: Color = .white) -> some View {
        let pattern: [CGFloat] = [18, 6, 10, 14, 5, 12, 8, 16, 7, 10, 13, 6]
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                        .fill(foreground.opacity(0.95))
                        .frame(width: 2, height: height)
                }
            }
            Text("O H A N A   P E T")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(foreground.opacity(0.82))
                .tracking(1.2)
        }
    }
}

// MARK: - Human Silhouette

struct HumanSilhouetteView: View {
    let gender: String
    var accent: Color = Color.goCardWhite.opacity(0.8)

    private var normalizedGender: String {
        HumanProfileOptions.normalizedGender(gender)
    }

    private var isFemale: Bool {
        normalizedGender == "女"
    }

    private var isNeutral: Bool {
        normalizedGender != "女" && normalizedGender != "男"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w * 0.5
            let head = min(w, h) * 0.26
            let bodyTop = h * 0.43

            ZStack {
                Ellipse()
                    .fill(Color.arkInk.opacity(0.18))
                    .frame(width: w * 0.56, height: h * 0.08)
                    .blur(radius: 7)
                    .position(x: cx, y: h * 0.91)

                if isFemale {
                    RoundedRectangle(cornerRadius: head * 0.42, style: .continuous)
                        .fill(accent.mix(with: .black, by: 0.22))
                        .frame(width: head * 1.2, height: head * 1.32)
                        .position(x: cx, y: h * 0.25)
                }

                Circle()
                    .fill(accent)
                    .frame(width: head, height: head)
                    .position(x: cx, y: h * 0.24)

                Capsule()
                    .fill(accent.opacity(0.92))
                    .frame(width: w * 0.16, height: h * 0.19)
                    .rotationEffect(.degrees(20))
                    .position(x: w * 0.3, y: h * 0.61)

                Capsule()
                    .fill(accent.opacity(0.92))
                    .frame(width: w * 0.16, height: h * 0.19)
                    .rotationEffect(.degrees(-20))
                    .position(x: w * 0.7, y: h * 0.61)

                if isFemale {
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.34, y: bodyTop))
                        path.addQuadCurve(to: CGPoint(x: w * 0.66, y: bodyTop), control: CGPoint(x: cx, y: h * 0.36))
                        path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.82))
                        path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.82), control: CGPoint(x: cx, y: h * 0.9))
                        path.closeSubpath()
                    }
                    .fill(accent)
                } else if isNeutral {
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: w * 0.48, height: h * 0.46)
                        .position(x: cx, y: h * 0.64)
                } else {
                    RoundedRectangle(cornerRadius: w * 0.12, style: .continuous)
                        .fill(accent)
                        .frame(width: w * 0.46, height: h * 0.42)
                        .position(x: cx, y: h * 0.63)
                }

                Capsule()
                    .fill(accent.mix(with: .black, by: 0.1))
                    .frame(width: w * 0.16, height: h * 0.28)
                    .position(x: w * 0.42, y: h * 0.83)

                Capsule()
                    .fill(accent.mix(with: .black, by: 0.1))
                    .frame(width: w * 0.16, height: h * 0.28)
                    .position(x: w * 0.58, y: h * 0.83)
            }
            .shadow(color: Color.arkInk.opacity(0.22), radius: 12, x: 0, y: 8) // ui-v4: allow silhouette grounding shadow inside wallet art.
        }
        .aspectRatio(0.72, contentMode: .fit)
    }
}

// MARK: - Human Card Front (Wizard Draft)

/// 添加家庭成员向导顶部固定预览：与宠物 `WalletPetCardDraftFront` 相同比例与层次。
struct WalletHumanCardDraftFront: View {
    var name: String
    var gender: String
    var avatarImageData: Data?
    var decodedAvatar: UIImage?
    var decodedAvatarTransparent: Bool
    var themeColorHex: String
    /// 阳历星座（有生日时由父视图传入）
    var zodiacText: String? = nil
    /// MBTI（可选，由父视图传入）
    var mbtiText: String? = nil
    /// 卡面底部一句摘要（关系 / 国籍 / 现居地 / 年龄等，由父视图拼好）
    var subtitle: String
    let cornerRadius: CGFloat

    private var gradientTop: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).0 }
    private var gradientBottom: Color { WalletPetCardTheme.gradientPair(for: themeColorHex).1 }

    private var headline: String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "OHANA" }
        return t.uppercased()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = decodedAvatar
            let isTransparent: Bool = {
                if decodedAvatar != nil { return decodedAvatarTransparent }
                return false
            }()
            let hasPopout = isTransparent && avatarImage != nil
            let usesFullBleedPhoto = avatarImage != nil && !isTransparent
            let useDarkText = !usesFullBleedPhoto && WalletPetCardTheme.prefersDarkForeground(for: themeColorHex)
            let primaryText = useDarkText ? Color.arkInk : Color.goCardWhite

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [gradientTop, gradientBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.goTeal.opacity(0.12))
                    .blendMode(.plusLighter)

                Text(String(name.prefix(4)).uppercased())
                    .font(.system(size: w * 0.2, weight: .black, design: .rounded))
                    .foregroundStyle(Color.goCardWhite.opacity(0.22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let img = avatarImage, usesFullBleedPhoto {
                    WalletCardAdaptivePhotoLayer(image: img, width: w, height: h, mode: .compact)
                        .allowsHitTesting(false)
                }

                if avatarImage == nil || hasPopout {
                    draftHumanAvatar(avatarImage: avatarImage, isTransparent: hasPopout, w: w, h: h)
                        .frame(width: w * 0.48, height: h, alignment: .leading)
                        .clipped()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                VStack(alignment: .trailing, spacing: 6) {
                    Spacer()
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.current.humanWalletNewMember : name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.opacity)
                    Text(L10n.current.humanWalletResident)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText.opacity(useDarkText ? 0.72 : 0.62))
                    if (zodiacText?.isEmpty == false) || (mbtiText?.isEmpty == false) {
                        HStack(spacing: 6) {
                            if let zodiacText, !zodiacText.isEmpty {
                                Text(zodiacText)
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(primaryText.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(primaryText.opacity(useDarkText ? 0.12 : 0.22)))
                            }
                            if let mbtiText, !mbtiText.isEmpty {
                                Text(mbtiText.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(primaryText.opacity(0.95))
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Capsule().fill(primaryText.opacity(useDarkText ? 0.12 : 0.22)))
                            }
                        }
                    }
                    Text(subtitle.isEmpty ? L10n.current.humanWalletSubtitlePlaceholder : subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(primaryText.opacity(0.72))
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.numericText())
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach([14, 8, 12, 6, 10, 16, 5, 11, 9, 13], id: \.self) { bh in
                            RoundedRectangle(cornerRadius: 1.2)
                                .fill(primaryText.opacity(0.85))
                                .frame(width: 2, height: CGFloat(bh))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.goCardWhite.opacity(0.15), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func draftHumanAvatar(avatarImage: UIImage?, isTransparent: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let img = avatarImage {
            if isTransparent {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: w * 0.46, height: h * 1.02, alignment: .bottom)
                    .frame(width: w * 0.48, height: h, alignment: .bottomLeading)
                    .offset(x: w * 0.015, y: h * 0.025)
                    .shadow(color: Color.goCardWhite.opacity(0.50), radius: 3, x: 0, y: 0) // ui-v4: allow transparent draft human avatar halo.
                    .shadow(color: Color.arkInk.opacity(0.30), radius: 18, x: 0, y: 12) // ui-v4: allow transparent draft human avatar grounding shadow.
            } else {
                EmptyView()
            }
        } else {
            HumanSilhouetteView(gender: gender, accent: Color.goCardWhite.opacity(0.76))
                .scaleEffect(0.9)
                .frame(width: w * 0.34, height: h * 0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.leading, w * 0.07)
        }
    }
}

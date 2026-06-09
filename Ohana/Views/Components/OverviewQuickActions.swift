//
//  OverviewQuickActions.swift
//  Ohana
//
//  首页快速动作组件
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - 快捷操作候选（与 QACardType.available 物种规则一致，供添加面板共用）
enum QuickActionPickerCatalog {
    struct Option: Identifiable, Hashable {
        let id: String
        let label: String
        let icon: String
        let colorHex: String
    }

    private static var all: [Option] {
        [
        Option(id: "walk", label: "遛狗", icon: "figure.walk", colorHex: "14B8A6"),
        Option(id: "feed", label: "喂食", icon: "fork.knife", colorHex: "FFDD44"),
        Option(id: "water", label: "喂水", icon: "drop.fill", colorHex: "00D4AA"),
        Option(id: "potty", label: "便便", icon: "allergens", colorHex: "FF8C42"),
        Option(id: "litter", label: "铲屎", icon: "trash.fill", colorHex: "5B6AFF"),
        Option(id: "waterChange", label: "换水", icon: "arrow.2.circlepath", colorHex: "4ECDC4"),
        Option(id: "filterClean", label: "清滤材", icon: "sparkles", colorHex: "A78BFA"),
        Option(id: "groom", label: "护理", icon: "scissors", colorHex: "FF8C42"),
        Option(id: "health", label: "健康", icon: "heart.fill", colorHex: "FF4757"),
        Option(id: "medication", label: "用药", icon: "pill.fill", colorHex: "A855F7"),
        Option(id: "expense", label: "花费", icon: AppCurrency.systemIconName, colorHex: "A78BFA"),
        Option(id: "weight", label: "体重", icon: "scalemass.fill", colorHex: "80FFEA"),
        Option(id: "play", label: "陪玩", icon: "tennisball.fill", colorHex: "FF6B6B"),
        Option(id: "moment", label: "记录", icon: "camera.circle.fill", colorHex: "FF6B9D"),
        Option(id: "cageCleaning", label: "清鸟笼", icon: "basket.fill", colorHex: "FFD166"),
        Option(id: "freeFlight", label: "放飞", icon: "bird.fill", colorHex: "06D6A0"),
        Option(id: "misting", label: "喷水", icon: "cloud.drizzle.fill", colorHex: "118AB2"),
        Option(id: "substrateChange", label: "换垫材", icon: "leaf.fill", colorHex: "07DB8B"),
        ]
    }

    /// 当前物种可出现的 actionType 集合（与 QACardType.available 物种规则一致）
    static func allowedActionTypeIds(forSpecies species: String) -> Set<String> {
        var allowed = Set(QACardType.available(for: species).map(\.rawValue))
        if allowed.contains("care") { allowed.insert("groom") }
        allowed.insert("water")
        allowed.insert("moment")
        allowed.insert("medication")
        if species.contains("猫") || species.lowercased().contains("cat") {
            allowed.insert("litter")
            allowed.insert("play")
            allowed.insert("weight")
        }
        if species.contains("狗") || species.lowercased().contains("dog") {
            allowed.insert("walk")
            allowed.insert("groom")
            allowed.insert("weight")
        }
        return allowed
    }

    static func options(for pet: Pet) -> [Option] {
        let allowed = allowedActionTypeIds(forSpecies: pet.species)
        return all.filter { allowed.contains($0.id) }
    }

    static func available(for pet: Pet, existingActionTypes: Set<String>) -> [Option] {
        let existing = normalizedExistingActionTypes(existingActionTypes)
        return options(for: pet).filter { !existing.contains($0.id) }
    }

    private static func normalizedExistingActionTypes(_ actionTypes: Set<String>) -> Set<String> {
        var result = actionTypes
        if result.contains("water") || !result.isDisjoint(with: WaterQuickActionPolicy.foldedActionTypes) {
            result.insert("water")
            result.formUnion(WaterQuickActionPolicy.foldedActionTypes)
        }
        return result
    }
}

// MARK: - QuickActionItem Data Model
struct QuickActionItem: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var icon: String
    var colorHex: String
    var petId: UUID?
    var entityId: UUID?
    var entityKindRaw: String?
    var actionType: String   // "walk","health","groom","potty","feed","calendar","add","waterPlant","fertilizePlant"

    var entityKind: EntityKind? {
        get { entityKindRaw.flatMap { EntityKind(rawValue: $0) } }
        set { entityKindRaw = newValue?.rawValue }
    }

    var resolvedEntityId: UUID? { entityId ?? petId }

    init(id: String = UUID().uuidString, label: String, icon: String,
         colorHex: String, petId: UUID? = nil, actionType: String,
         entityId: UUID? = nil, entityKind: EntityKind? = nil) {
        self.id = id; self.label = label; self.icon = icon
        self.colorHex = colorHex; self.petId = petId; self.actionType = actionType
        self.entityId = entityId; self.entityKindRaw = entityKind?.rawValue
    }
}

enum OhanaQuickActionGlyphKind {
    case feed
    case dryFood
    case wetFood
    case foodInventory
    case calendar
    case walk
    case water
    case waterChange
    case potty
    case litter
    case groom
    case health
    case medicine
    case weight
    case expense
    case play
    case rest
    case photo
    case cleanup
    case training
    case plantFertilize
    case document
    case settings

    static func resolve(actionType: String, fallbackSystemName: String) -> OhanaQuickActionGlyphKind? {
        let action = actionType.lowercased()
        let symbol = fallbackSystemName.lowercased()

        if action == "water", symbol.contains("water.waves") {
            return .waterChange
        }

        switch action {
        case "feed":
            return .feed
        case "dryfood", "fooddry", "dry":
            return .dryFood
        case "wetfood", "foodwet", "wet", "canned", "can":
            return .wetFood
        case "foodinventory", "foodstock", "inventory", "stock", "restock":
            return .foodInventory
        case "calendar":
            return .calendar
        case "walk":
            return .walk
        case "water":
            return .water
        case "waterchange", "filterclean":
            return .waterChange
        case "potty":
            return .potty
        case "litter":
            return .litter
        case "groom":
            return .groom
        case "health":
            return .health
        case "medication", "humanmedication":
            return .medicine
        case "weight", "humanweight":
            return .weight
        case "expense", "humanexpense":
            return .expense
        case "play":
            return .play
        case "rest", "sleep":
            return .rest
        case "moment":
            return .photo
        case "cagecleaning":
            return .cleanup
        case "freeflight", "humanworkout":
            return .training
        case "misting":
            return .water
        case "substratechange", "fertilizeplant":
            return .plantFertilize
        case "humannote", "note":
            return .document
        case "settings", "setting":
            return .settings
        default:
            break
        }

        if action.contains("dryfood") || action.contains("fooddry") || symbol.contains("hexagongrid") { return .dryFood }
        if action.contains("wetfood") || action.contains("foodwet") || action.contains("canned") || symbol.contains("takeoutbag") { return .wetFood }
        if action.contains("inventory") || action.contains("stock") || action.contains("restock") || symbol.contains("shippingbox") { return .foodInventory }
        if action.contains("feed") || action.contains("food") || symbol.contains("fork") { return .feed }
        if symbol.contains("calendar") { return .calendar }
        if action.contains("walk") || symbol.contains("figure.walk") { return .walk }
        if action.contains("waterchange") || action.contains("filterclean") || symbol.contains("water.waves") || symbol.contains("arrow.2.circlepath") { return .waterChange }
        if action.contains("water") || action.contains("misting") || symbol.contains("drop") || symbol.contains("cloud.drizzle") { return .water }
        if action.contains("potty") || action.contains("poop") || action == "pee" || symbol.contains("allergens") { return .potty }
        if action.contains("litter") || symbol.contains("trash") { return .litter }
        if action.contains("groom") || action.contains("hygiene") || action.contains("bath") || action.contains("teeth") || action.contains("nails") || action.contains("brushing") || action.contains("ears") || symbol.contains("scissors") || symbol.contains("comb") || symbol.contains("bubbles") { return .groom }
        if action.contains("health") || action.contains("visit") || symbol.contains("heart") || symbol.contains("stethoscope") || symbol.contains("cross") { return .health }
        if action.contains("medication") || action.contains("medicine") || action.contains("vaccine") || action.contains("deworming") || symbol.contains("pill") || symbol.contains("syringe") || symbol.contains("shield") { return .medicine }
        if action.contains("weight") || symbol.contains("scale") { return .weight }
        if action.contains("expense") || symbol.contains("credit") || symbol.contains("banknote") || symbol.contains("yensign") || symbol.contains("dollarsign") || symbol.contains("eurosign") || symbol.contains("sterlingsign") { return .expense }
        if action.contains("play") || symbol.contains("gamecontroller") || symbol.contains("tennisball") { return .play }
        if action.contains("rest") || action.contains("sleep") || symbol.contains("zzz") || symbol.contains("tent") { return .rest }
        if action.contains("moment") || symbol.contains("camera") { return .photo }
        if action.contains("cagecleaning") || symbol.contains("basket") { return .cleanup }
        if action.contains("freeflight") || action.contains("workout") { return .training }
        if action.contains("substratechange") || action.contains("fertilizeplant") || symbol.contains("leaf") { return .plantFertilize }
        if action.contains("note") || action.contains("document") || symbol.contains("note") || symbol.contains("doc") { return .document }
        if action.contains("settings") || action.contains("setting") || symbol.contains("gear") { return .settings }
        return nil
    }
}

struct OhanaQuickActionIcon: View {
    let actionType: String
    let fallbackSystemName: String
    var size: CGFloat = 32
    var color: Color = Color.ohanaFunctionalIcon
    var isCompleted: Bool = false
    var showsCompletionBadge: Bool = false
    var animationTrigger: Int = 0
    var animatesStateChanges: Bool = true

    private var glyphKind: OhanaQuickActionGlyphKind? {
        OhanaQuickActionGlyphKind.resolve(actionType: actionType, fallbackSystemName: fallbackSystemName)
    }

    var body: some View {
        iconBody
            .ohanaPhasePop(trigger: animationKey, enabled: animatesStateChanges)
            .animation(GoMotion.stateChange, value: isCompleted)
            .animation(GoMotion.stateChange, value: showsCompletionBadge)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var iconBody: some View {
        ZStack(alignment: .bottomTrailing) {
            glyphLayer

            if showsCompletionBadge && isCompleted {
                completionBadge
                    .offset(x: size * 0.08, y: size * 0.08)
                    .transition(.scale(scale: 0.82).combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var glyphLayer: some View {
        if let glyphKind {
            ZStack {
                OhanaQuickActionGlyph(kind: glyphKind, color: color)
                OhanaQuickActionGlyphStateOverlay(
                    kind: glyphKind,
                    color: color,
                    isCompleted: isCompleted
                )
            }
            .frame(width: size, height: size)
        } else {
            Image(systemName: fallbackSystemName)
                .font(.system(size: size * 0.62, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
                .frame(width: size, height: size)
        }
    }

    private var animationKey: String {
        "\(isCompleted)-\(showsCompletionBadge)-\(animationTrigger)"
    }

    private var completionBadge: some View {
        let badgeSize = max(12, size * 0.36)
        return ZStack {
            Circle()
                .fill(Color.goPrimary)
            Image(systemName: "checkmark")
                .font(.system(size: badgeSize * 0.52, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
        }
        .frame(width: badgeSize, height: badgeSize)
        .overlay {
            Circle()
                .strokeBorder(Color.ohanaCardSurface.opacity(0.85), lineWidth: max(1, size * 0.035))
        }
    }
}

private struct OhanaQuickActionGlyph: View {
    let kind: OhanaQuickActionGlyphKind
    let color: Color

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            var iconContext = context
            iconContext.translateBy(
                x: (size.width - side) / 2,
                y: (size.height - side) / 2
            )
            iconContext.scaleBy(x: side / 32, y: side / 32)
            draw(kind, in: &iconContext)
        }
    }

    private func draw(_ kind: OhanaQuickActionGlyphKind, in context: inout GraphicsContext) {
        switch kind {
        case .feed:
            fill(ellipse(x: 6.6, y: 9.8, width: 18.8, height: 8.8), in: &context, opacity: 0.2)
            fill(bowlPath(x: 5.5, y: 14.7, width: 21, height: 11.3), in: &context)

        case .dryFood:
            fill(bowlPath(x: 6.2, y: 18.5, width: 19.6, height: 7.4), in: &context)
            for point in [
                CGPoint(x: 11, y: 16),
                CGPoint(x: 15.1, y: 14.4),
                CGPoint(x: 19.2, y: 15.9),
                CGPoint(x: 13, y: 19),
                CGPoint(x: 17.2, y: 19.1),
                CGPoint(x: 21.1, y: 18.3)
            ] {
                fill(hexFoodPiece(center: point, radius: 1.75), in: &context, opacity: 0.82)
            }

        case .wetFood:
            fill(ellipse(x: 8.4, y: 7.1, width: 15.2, height: 5.6), in: &context)
            fill(roundedRect(x: 8.4, y: 9.8, width: 15.2, height: 15.4, radius: 4), in: &context)
            fill(ellipse(x: 8.4, y: 21.8, width: 15.2, height: 5), in: &context, opacity: 0.36)
            fill(capsule(x: 11.3, y: 13.2, width: 9.4, height: 5.4), in: &context, opacity: 0.22)
            fill(circle(cx: 16, cy: 16, r: 2.35), in: &context, opacity: 0.42)

        case .foodInventory:
            fill(foodBagPath(), in: &context)
            fill(capsule(x: 11, y: 8.8, width: 10, height: 2.7), in: &context, opacity: 0.2)
            fill(capsule(x: 10, y: 15.1, width: 12, height: 2.3), in: &context, opacity: 0.56)
            fill(capsule(x: 10, y: 19, width: 9.2, height: 2.3), in: &context, opacity: 0.38)
            fill(capsule(x: 10, y: 22.9, width: 6.4, height: 2.3), in: &context, opacity: 0.24)

        case .calendar:
            fill(roundedRect(x: 5.5, y: 6.5, width: 21, height: 20, radius: 5.5), in: &context)
            fill(capsule(x: 9, y: 10, width: 14, height: 3), in: &context, opacity: 0.42)
            fill(circle(cx: 11.3, cy: 17.3, r: 1.55), in: &context, opacity: 0.42)
            fill(circle(cx: 16, cy: 17.3, r: 1.55), in: &context, opacity: 0.24)
            fill(circle(cx: 20.7, cy: 17.3, r: 1.55), in: &context, opacity: 0.24)
            fill(capsule(x: 14.1, y: 20.2, width: 7.9, height: 3.2), in: &context, opacity: 0.42)

        case .walk:
            var leash = Path()
            leash.move(to: CGPoint(x: 6.6, y: 8.8))
            leash.addCurve(to: CGPoint(x: 15.5, y: 14.7), control1: CGPoint(x: 9.3, y: 8.4), control2: CGPoint(x: 11.6, y: 12.4))
            stroke(leash, in: &context, width: 2.1, opacity: 0.52)
            fill(circle(cx: 6.6, cy: 8.8, r: 1.9), in: &context, opacity: 0.34)
            fill(roundedRect(x: 11.3, y: 15, width: 11.4, height: 6.7, radius: 3.2), in: &context)
            fill(circle(cx: 23.5, cy: 14.9, r: 4.1), in: &context)
            fill(triangle(points: [
                CGPoint(x: 21.7, y: 11.9),
                CGPoint(x: 23.2, y: 7.9),
                CGPoint(x: 25.3, y: 12.6)
            ]), in: &context, opacity: 0.64)
            fill(circle(cx: 25.1, cy: 14.7, r: 0.9), in: &context, opacity: 0.36)
            stroke(capsule(x: 8.1, y: 14.2, width: 5.2, height: 2.3), in: &context, width: 2.1, opacity: 0.76)
            fill(capsule(x: 13.1, y: 20.2, width: 2.2, height: 5.2), in: &context)
            fill(capsule(x: 19.4, y: 20.2, width: 2.2, height: 5.2), in: &context)

        case .water:
            fill(dropPath(), in: &context)
            fill(bowlPath(x: 7.2, y: 20.2, width: 17.6, height: 5.8), in: &context, opacity: 0.38)
            fill(ellipse(x: 7.2, y: 17.3, width: 17.6, height: 6), in: &context, opacity: 0.18)

        case .waterChange:
            fill(dropPath().applying(CGAffineTransform(translationX: -3.2, y: 1.4).scaledBy(x: 0.86, y: 0.86)), in: &context)
            stroke(arcArrowPath(clockwise: true), in: &context, width: 2.55, opacity: 0.84)
            stroke(arcArrowPath(clockwise: false), in: &context, width: 2.55, opacity: 0.84)

        case .potty:
            fill(bowlPath(x: 7, y: 17.2, width: 18, height: 8.8), in: &context)
            fill(roundedRect(x: 7.8, y: 7.4, width: 16.4, height: 10.8, radius: 4), in: &context, opacity: 0.24)
            drawLabel("WC", at: CGPoint(x: 16, y: 13.2), size: 7.5, opacity: 0.62, in: &context)

        case .litter:
            fill(bowlPath(x: 6.5, y: 17.2, width: 19, height: 8.8), in: &context)
            fill(ellipse(x: 6.5, y: 12.7, width: 19, height: 7.8), in: &context, opacity: 0.18)

        case .groom:
            fill(roundedRect(x: 6.5, y: 8.5, width: 19, height: 6, radius: 3), in: &context)
            fill(capsule(x: 22.6, y: 10.2, width: 4.2, height: 11.2), in: &context, opacity: 0.42)
            for x in [8.5, 11.4, 14.3, 17.2, 20.1] {
                fill(capsule(x: x, y: 13.2, width: 1.55, height: 10.7), in: &context, opacity: 0.68)
            }

        case .health:
            fill(roundedRect(x: 7, y: 6, width: 18, height: 21, radius: 5.2), in: &context)
            fill(capsule(x: 11, y: 9.7, width: 10, height: 2.8), in: &context, opacity: 0.18)
            fill(heartPath(), in: &context, opacity: 0.54)

        case .medicine:
            let outer = rotated(capsule(x: 5.4, y: 12, width: 21.2, height: 8), degrees: -35, center: CGPoint(x: 16, y: 16))
            let inner = rotated(capsule(x: 16, y: 12.4, width: 10.1, height: 7.2), degrees: -35, center: CGPoint(x: 16, y: 16))
            fill(outer, in: &context)
            fill(inner, in: &context, opacity: 0.42)
            fill(rotated(circle(cx: 11.8, cy: 16, r: 2.1), degrees: -35, center: CGPoint(x: 16, y: 16)), in: &context, opacity: 0.18)

        case .weight:
            fill(roundedRect(x: 5.5, y: 8, width: 21, height: 18.5, radius: 6), in: &context)
            fill(capsule(x: 10, y: 11, width: 12, height: 3), in: &context, opacity: 0.18)
            var needle = Path()
            needle.move(to: CGPoint(x: 16, y: 17.3))
            needle.addLine(to: CGPoint(x: 20, y: 13.5))
            stroke(needle, in: &context, width: 2.4, opacity: 0.48)
            fill(circle(cx: 16, cy: 17.3, r: 2.45), in: &context, opacity: 0.48)

        case .expense:
            fill(roundedRect(x: 6, y: 9, width: 20, height: 15.8, radius: 5), in: &context)
            fill(capsule(x: 8.6, y: 12, width: 14.8, height: 3), in: &context, opacity: 0.4)
            drawLabel(AppCurrency.symbol, at: CGPoint(x: 16, y: 20.2), size: AppCurrency.symbol.count > 1 ? 6.8 : 8.8, opacity: 0.58, in: &context)

        case .play:
            fill(roundedRect(x: 5.8, y: 12.4, width: 20.4, height: 11.8, radius: 5.8), in: &context)
            fill(circle(cx: 10.8, cy: 22.1, r: 3.1), in: &context)
            fill(circle(cx: 21.2, cy: 22.1, r: 3.1), in: &context)
            fill(capsule(x: 9.2, y: 16.6, width: 6.1, height: 1.8), in: &context, opacity: 0.46)
            fill(capsule(x: 11.3, y: 14.45, width: 1.8, height: 6.1), in: &context, opacity: 0.46)
            fill(circle(cx: 20.3, cy: 15.8, r: 1.45), in: &context, opacity: 0.52)
            fill(circle(cx: 23.2, cy: 17.9, r: 1.2), in: &context, opacity: 0.34)

        case .rest:
            fill(tentPath(), in: &context)
            fill(triangle(points: [
                CGPoint(x: 15.9, y: 14.1),
                CGPoint(x: 20.6, y: 25.8),
                CGPoint(x: 11.2, y: 25.8)
            ]), in: &context, opacity: 0.2)
            drawLabel("Z", at: CGPoint(x: 21.1, y: 8.4), size: 7.4, opacity: 0.62, in: &context)
            drawLabel("z", at: CGPoint(x: 25, y: 12.4), size: 5.9, opacity: 0.38, in: &context)

        case .photo:
            fill(roundedRect(x: 6, y: 8, width: 20, height: 16, radius: 5), in: &context)
            fill(circle(cx: 20.8, cy: 12.6, r: 2.1), in: &context, opacity: 0.48)
            var mountain = Path()
            mountain.move(to: CGPoint(x: 9.4, y: 22.2))
            mountain.addLine(to: CGPoint(x: 14, y: 16.8))
            mountain.addLine(to: CGPoint(x: 17.4, y: 20.6))
            mountain.addLine(to: CGPoint(x: 19.5, y: 18.3))
            mountain.addLine(to: CGPoint(x: 23, y: 22.2))
            mountain.closeSubpath()
            fill(mountain, in: &context, opacity: 0.32)

        case .cleanup:
            fill(rotated(capsule(x: 8.4, y: 17.4, width: 15.8, height: 6.2), degrees: -18, center: CGPoint(x: 16.3, y: 20.5)), in: &context)
            fill(rotated(capsule(x: 13.5, y: 7, width: 4, height: 13.5), degrees: -18, center: CGPoint(x: 15.5, y: 13.8)), in: &context)
            fill(circle(cx: 22.7, cy: 8.5, r: 2.2), in: &context, opacity: 0.42)
            fill(circle(cx: 25.4, cy: 13, r: 1.35), in: &context, opacity: 0.22)
            fill(circle(cx: 8.2, cy: 24.5, r: 1.5), in: &context, opacity: 0.22)

        case .training:
            fill(circle(cx: 16, cy: 16, r: 10.4), in: &context)
            fill(circle(cx: 16, cy: 16, r: 6.2), in: &context, opacity: 0.22)
            fill(circle(cx: 16, cy: 16, r: 2.7), in: &context, opacity: 0.54)
            fill(rotated(capsule(x: 22.2, y: 5.5, width: 5.4, height: 3.2), degrees: 35, center: CGPoint(x: 24.9, y: 7.1)), in: &context, opacity: 0.54)

        case .plantFertilize:
            fill(bowlPath(x: 9.1, y: 18, width: 13.8, height: 8), in: &context)
            fill(leafPath(start: CGPoint(x: 15.5, y: 17.8), left: true), in: &context)
            fill(leafPath(start: CGPoint(x: 16.7, y: 17.2), left: false), in: &context)
            fill(circle(cx: 23.8, cy: 20.5, r: 2), in: &context, opacity: 0.44)
            fill(circle(cx: 25.8, cy: 15.6, r: 1.4), in: &context, opacity: 0.22)

        case .document:
            fill(documentPath(), in: &context)
            fill(foldPath(), in: &context, opacity: 0.24)
            fill(capsule(x: 12, y: 15.1, width: 8, height: 2.4), in: &context, opacity: 0.42)
            fill(capsule(x: 12, y: 19.6, width: 6.2, height: 2.4), in: &context, opacity: 0.24)

        case .settings:
            fill(gearPath(), in: &context)
            fill(circle(cx: 16, cy: 16, r: 4.1), in: &context, opacity: 0.18)
        }
    }

    private func fill(_ path: Path, in context: inout GraphicsContext, opacity: Double = 1) {
        context.fill(path, with: .color(color.opacity(opacity)))
    }

    private func stroke(_ path: Path, in context: inout GraphicsContext, width: CGFloat, opacity: Double = 1) {
        context.stroke(
            path,
            with: .color(color.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func circle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        ellipse(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
    }

    private func ellipse(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: x, y: y, width: width, height: height))
        return path
    }

    private func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: x, y: y, width: width, height: height),
            cornerSize: CGSize(width: radius, height: radius),
            style: .continuous
        )
        return path
    }

    private func capsule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        roundedRect(x: x, y: y, width: width, height: height, radius: min(width, height) / 2)
    }

    private func rotated(_ path: Path, degrees: CGFloat, center: CGPoint) -> Path {
        var transform = CGAffineTransform(translationX: center.x, y: center.y)
        transform = transform.rotated(by: degrees * .pi / 180)
        transform = transform.translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }

    private func triangle(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func hexFoodPiece(center: CGPoint, radius: CGFloat) -> Path {
        var points: [CGPoint] = []
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3 + .pi / 6
            points.append(CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            ))
        }
        return triangleFan(points: points)
    }

    private func triangleFan(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private func drawLabel(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        context.draw(
            Text(text)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(color.opacity(opacity)),
            at: point,
            anchor: .center
        )
    }

    private func bowlPath(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> Path {
        let bottom = y + height
        var path = Path()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + width, y: y))
        path.addLine(to: CGPoint(x: x + width - width * 0.08, y: bottom - height * 0.28))
        path.addQuadCurve(
            to: CGPoint(x: x + width * 0.72, y: bottom),
            control: CGPoint(x: x + width * 0.92, y: bottom)
        )
        path.addLine(to: CGPoint(x: x + width * 0.28, y: bottom))
        path.addQuadCurve(
            to: CGPoint(x: x + width * 0.08, y: bottom - height * 0.28),
            control: CGPoint(x: x + width * 0.08, y: bottom)
        )
        path.closeSubpath()
        return path
    }

    private func foodBagPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 10, y: 6.2))
        path.addLine(to: CGPoint(x: 22, y: 6.2))
        path.addLine(to: CGPoint(x: 25, y: 26.2))
        path.addLine(to: CGPoint(x: 7, y: 26.2))
        path.closeSubpath()
        return path
    }

    private func tentPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 6.4))
        path.addLine(to: CGPoint(x: 27, y: 26.2))
        path.addLine(to: CGPoint(x: 5, y: 26.2))
        path.closeSubpath()
        return path
    }

    private func gearPath() -> Path {
        var path = Path()
        let center = CGPoint(x: 16, y: 16)
        for index in 0..<16 {
            let angle = CGFloat(index) * .pi / 8
            let radius: CGFloat = index.isMultiple(of: 2) ? 11.2 : 8.7
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func dropPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 4.8))
        path.addCurve(to: CGPoint(x: 23.1, y: 17.9), control1: CGPoint(x: 20.8, y: 10.5), control2: CGPoint(x: 23.1, y: 14.3))
        path.addCurve(to: CGPoint(x: 16, y: 25), control1: CGPoint(x: 23.1, y: 22), control2: CGPoint(x: 20, y: 25))
        path.addCurve(to: CGPoint(x: 8.9, y: 17.9), control1: CGPoint(x: 12, y: 25), control2: CGPoint(x: 8.9, y: 22))
        path.addCurve(to: CGPoint(x: 16, y: 4.8), control1: CGPoint(x: 8.9, y: 14.3), control2: CGPoint(x: 11.2, y: 10.5))
        path.closeSubpath()
        return path
    }

    private func heartPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 16, y: 23.1))
        path.addCurve(to: CGPoint(x: 10.6, y: 16.3), control1: CGPoint(x: 13.9, y: 21.8), control2: CGPoint(x: 10.6, y: 19.4))
        path.addCurve(to: CGPoint(x: 13.7, y: 12.9), control1: CGPoint(x: 10.6, y: 14.3), control2: CGPoint(x: 11.9, y: 12.9))
        path.addCurve(to: CGPoint(x: 16, y: 14.2), control1: CGPoint(x: 14.8, y: 12.9), control2: CGPoint(x: 15.6, y: 13.4))
        path.addCurve(to: CGPoint(x: 18.3, y: 12.9), control1: CGPoint(x: 16.4, y: 13.4), control2: CGPoint(x: 17.2, y: 12.9))
        path.addCurve(to: CGPoint(x: 21.4, y: 16.3), control1: CGPoint(x: 20.1, y: 12.9), control2: CGPoint(x: 21.4, y: 14.3))
        path.addCurve(to: CGPoint(x: 16, y: 23.1), control1: CGPoint(x: 21.4, y: 19.4), control2: CGPoint(x: 18.1, y: 21.8))
        path.closeSubpath()
        return path
    }

    private func arcArrowPath(clockwise: Bool) -> Path {
        var path = Path()
        if clockwise {
            path.addArc(center: CGPoint(x: 19, y: 12), radius: 6, startAngle: .degrees(-45), endAngle: .degrees(74), clockwise: false)
            path.move(to: CGPoint(x: 22.3, y: 17.1))
            path.addLine(to: CGPoint(x: 26.4, y: 16.6))
            path.move(to: CGPoint(x: 22.3, y: 17.1))
            path.addLine(to: CGPoint(x: 25.6, y: 13.1))
        } else {
            path.addArc(center: CGPoint(x: 13, y: 12), radius: 6, startAngle: .degrees(135), endAngle: .degrees(255), clockwise: false)
            path.move(to: CGPoint(x: 9.6, y: 6.9))
            path.addLine(to: CGPoint(x: 5.6, y: 7.4))
            path.move(to: CGPoint(x: 9.6, y: 6.9))
            path.addLine(to: CGPoint(x: 6.4, y: 10.9))
        }
        return path
    }

    private func leafPath(start: CGPoint, left: Bool) -> Path {
        var path = Path()
        path.move(to: start)
        if left {
            path.addCurve(to: CGPoint(x: 7.2, y: 11.3), control1: CGPoint(x: 14.3, y: 13.4), control2: CGPoint(x: 11.2, y: 11.2))
            path.addCurve(to: start, control1: CGPoint(x: 8.2, y: 15.4), control2: CGPoint(x: 11.2, y: 17.6))
        } else {
            path.addCurve(to: CGPoint(x: 24.5, y: 9.2), control1: CGPoint(x: 17.5, y: 12.4), control2: CGPoint(x: 20.3, y: 9.7))
            path.addCurve(to: start, control1: CGPoint(x: 24.1, y: 13.9), control2: CGPoint(x: 21.2, y: 16.8))
        }
        path.closeSubpath()
        return path
    }

    private func documentPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 9, y: 5.5))
        path.addLine(to: CGPoint(x: 19.4, y: 5.5))
        path.addLine(to: CGPoint(x: 23.5, y: 9.7))
        path.addLine(to: CGPoint(x: 23.5, y: 26.5))
        path.addLine(to: CGPoint(x: 9, y: 26.5))
        path.closeSubpath()
        return path
    }

    private func foldPath() -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 19.1, y: 5.6))
        path.addLine(to: CGPoint(x: 23.6, y: 10.6))
        path.addLine(to: CGPoint(x: 19.1, y: 10.6))
        path.closeSubpath()
        return path
    }
}

private struct OhanaQuickActionGlyphStateOverlay: View {
    let kind: OhanaQuickActionGlyphKind
    let color: Color
    let isCompleted: Bool

    private struct Dot: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let delay: Double
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content(in: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        switch kind {
        case .feed:
            ForEach(feedDots) { dot in
                dotView(dot, in: size, activeOpacity: 0.94, inactiveOpacity: 0.18)
            }
        case .litter:
            ForEach(litterDots) { dot in
                dotView(dot, in: size, activeOpacity: 0.72, inactiveOpacity: 0.32)
            }
        case .water, .waterChange:
            dotView(
                Dot(id: 0, x: 21.6, y: 8.3, radius: 1.55, delay: 0),
                in: size,
                activeOpacity: 0.72,
                inactiveOpacity: 0.18
            )
        case .play:
            dotView(
                Dot(id: 0, x: 20.3, y: 15.8, radius: 1.45, delay: 0),
                in: size,
                activeOpacity: 0.7,
                inactiveOpacity: 0.34
            )
            dotView(
                Dot(id: 1, x: 23.2, y: 17.9, radius: 1.2, delay: 0.035),
                in: size,
                activeOpacity: 0.58,
                inactiveOpacity: 0.24
            )
        default:
            EmptyView()
        }
    }

    private func dotView(
        _ dot: Dot,
        in size: CGSize,
        activeOpacity: Double,
        inactiveOpacity: Double
    ) -> some View {
        let side = min(size.width, size.height)
        return Circle()
            .fill(color.opacity(isCompleted ? activeOpacity : inactiveOpacity))
            .frame(width: dot.radius * 2 * side / 32, height: dot.radius * 2 * side / 32)
            .position(x: dot.x * side / 32, y: dot.y * side / 32)
            .scaleEffect(isCompleted ? 1 : 0.72)
            .animation(GoMotion.feedback.delay(dot.delay), value: isCompleted)
    }

    private var feedDots: [Dot] {
        [
            Dot(id: 0, x: 12.2, y: 12.1, radius: 2.2, delay: 0),
            Dot(id: 1, x: 16.4, y: 11.1, radius: 2.55, delay: 0.035),
            Dot(id: 2, x: 20.4, y: 12.6, radius: 2.1, delay: 0.07)
        ]
    }

    private var litterDots: [Dot] {
        [
            Dot(id: 0, x: 10.2, y: 15.3, radius: 1.05, delay: 0),
            Dot(id: 1, x: 13.3, y: 14.1, radius: 0.86, delay: 0.02),
            Dot(id: 2, x: 16.4, y: 15.5, radius: 1.18, delay: 0.04),
            Dot(id: 3, x: 19.6, y: 14.2, radius: 0.94, delay: 0.06),
            Dot(id: 4, x: 22.1, y: 16.1, radius: 0.78, delay: 0.08)
        ]
    }
}

enum QuickActionLimit {
    static let maxItemsPerEntity = 8
    static let title = "快捷操作已达上限"
    static let message = "快捷操作区最多只能添加 8 个。更多功能可以在「全部功能」里查看和使用。"

    static func count(for pet: Pet, in items: [QuickActionItem]) -> Int {
        items.filter { $0.petId == pet.id && $0.entityKind != .human }.count
    }
}

enum WaterQuickActionPolicy {
    static let foldedActionTypes: Set<String> = ["waterChange", "filterClean"]

    static func isAquatic(species: String) -> Bool {
        let lower = species.lowercased()
        return species.contains("鱼") ||
            species.contains("水族") ||
            lower.contains("fish") ||
            lower.contains("aquarium")
    }

    static func normalizedItems(
        _ items: [QuickActionItem],
        for pet: Pet,
        waterLabel: String,
        managementLabel: String
    ) -> [QuickActionItem] {
        var result = items.filter { !foldedActionTypes.contains($0.actionType) }
        let hadFoldedWaterAction = items.contains { foldedActionTypes.contains($0.actionType) }
        let hasWater = result.contains { $0.actionType == "water" }
        guard !hasWater, hadFoldedWaterAction else { return result }

        let firstFoldedIndex = items.firstIndex { foldedActionTypes.contains($0.actionType) } ?? result.count
        let insertIndex = min(firstFoldedIndex, result.count)
        let item = QuickActionItem(
            label: isAquatic(species: pet.species) ? managementLabel : waterLabel,
            icon: isAquatic(species: pet.species) ? "water.waves" : "drop.fill",
            colorHex: "00D4AA",
            petId: pet.id,
            actionType: "water",
            entityId: pet.id,
            entityKind: .pet
        )
        result.insert(item, at: insertIndex)
        return result
    }

    static func titleOverride(for item: QuickActionItem, pet: Pet, managementLabel: String) -> String? {
        item.actionType == "water" && isAquatic(species: pet.species) ? managementLabel : nil
    }

    static func iconOverride(for item: QuickActionItem, pet: Pet) -> String? {
        item.actionType == "water" && isAquatic(species: pet.species) ? "water.waves" : nil
    }
}

// MARK: - Go Quick Action Card (毛玻璃正方形)
struct GoQuickActionCard: View {
    let item: QuickActionItem
    let isPressed: Bool
    let petAvatar: UIImage?
    var petThemeColorHex: String? = nil
    /// 覆盖 `item.icon`（如喂水卡按「换水」模式显示不同 SF Symbol）
    var displayIcon: String? = nil
    /// 覆盖主标题（如首页喂水快捷项在「换水」模式下显示「换水」）
    var titleLabelOverride: String? = nil
    var pendingReminder: Reminder? = nil
    var showsAttentionDot: Bool = false
    var countText: String? = nil
    var privacyBadgeText: String? = nil
    var privacyIconName: String? = nil
    var privacyIconTint: Color = Color.goYellow
    var isPrivacyLocked: Bool = false
    var isCompletedToday: Bool = false
    var prefersLightForeground: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    /// 护理卡：点击后由外部执行打卡（传入 HygieneType raw string）
    var onGroomCheckIn: ((String) -> Void)? = nil
    /// 便便卡：点击后弹出类型选择（传入 PottyType raw string）
    var onPottySelect: ((String) -> Void)? = nil
    /// 健康卡：点击后弹出健康快速记录选项（传入 HealthQuickAction raw string）
    var onHealthSelect: ((String) -> Void)? = nil
    /// 长按→添加待办 sheet 回调
    var onAddReminder: (() -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var showGroomMenu = false
    @State private var showPottyMenu = false
    @State private var showHealthMenu = false
    @Environment(\.modelContext) private var modelContext

    private var isGroom: Bool { item.actionType == "groom" }
    private var isPotty: Bool { item.actionType == "potty" }
    private var isHealth: Bool { item.actionType == "health" }

    /// 根据 actionType 获取干净的显示名（不含宠物名）
    private var cleanLabel: String {
        let map: [String: String] = [
            "walk": "遛狗", "feed": "喂食", "water": "喂水",
            "potty": "便便", "litter": "铲屎", "groom": "护理",
            "health": "健康", "expense": "花费", "weight": "体重",
            "play": "陪玩", "moment": "记录", "waterChange": "换水",
            "filterClean": "清滤材", "cageCleaning": "清鸟笼",
            "freeFlight": "放飞", "misting": "喷水", "substrateChange": "换垫材"
        ]
        return map[item.actionType] ?? item.label
    }
    
    // 高级极简的规则圆角，取代不规则圆角
    private let premiumShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    private var cardBgColor: Color {
        if isCompletedToday { return Color.goPrimary.opacity(0.18) }
        if isWarningState {
            return Color.goRed.mix(with: Color.ohanaCardSurface, by: colorScheme == .dark ? 0.52 : 0.72)
        }
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.16) : Color.ohanaCardSurface
    }
    private var cardBorderColor: Color {
        if isCompletedToday { return Color.goPrimary.opacity(0.68) }
        if isWarningState { return Color.goRed.opacity(0.72) }
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.54) : Color.ohanaGlassStroke.opacity(0.42)
    }

    private var isWarningState: Bool {
        showsAttentionDot
    }

    /// 今日已打卡时图标/水浪用色：优先宠物主题色，否则快捷项自带色
    private var checkInAccentColor: Color {
        Color.ohanaFunctionalIcon
    }

    private var isWaterAction: Bool { item.actionType == "water" }
    private var isFeedAction: Bool { item.actionType == "feed" }

    /// V4: 功能 icon 统一为 goPrimary 单色 glyph，状态由卡片/数字/徽标表达。
    private var quickActionIconForeground: Color {
        Color.ohanaFunctionalIcon.opacity(isCompletedToday ? 1 : 0.9)
    }

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }
    private var usesLightForeground: Bool { prefersLightForeground || isDarkMode }
    private var titleForeground: Color {
        if isCompletedToday { return Color.goPrimary }
        return Color.ohanaPrimaryText.opacity(usesLightForeground ? 0.9 : 0.75)
    }
    private var subtitleForeground: Color {
        Color.ohanaSecondaryText.opacity(usesLightForeground ? 1.0 : 0.72)
    }
    
    @State private var animateGlow = false
    @State private var pendingSingleTapWorkItem: DispatchWorkItem? = nil
    @State private var lastTapDate: Date? = nil
    /// 长按成功后，手指抬起仍会触发 `DragGesture.onEnded`，需忽略紧随其后的那次「伪点击」（否则花费等会先开详情再弹出记账）
    @State private var ignoreNextDragEndTap: Bool = false
    private let tapMovementThreshold: CGFloat = 10
    private let doubleTapInterval: TimeInterval = 0.28

    private var resolvedIcon: String { displayIcon ?? item.icon }
    private var iconTileColor: Color {
        Color.ohanaFunctionalIcon.opacity(isCompletedToday ? 0.18 : 0.12)
    }

    /// 无菜单项时不挂 contextMenu，避免与长按打开详情 sheet 冲突（系统菜单盖住 sheet）
    private var hasContextMenuContent: Bool {
        // 护理 / 健康：长按只进详情，不弹系统二级菜单；点击弹出 popover
        if isGroom || isHealth { return false }
        return pendingReminder != nil
            || (isPotty && onAddReminder != nil)
            || onDelete != nil
    }

    var body: some View {
        // Avoid wrapping the card in Button/ExclusiveGesture here, because that
        // competes with the parent vertical ScrollView and makes the quick-action
        // area feel "stuck" when the user starts a vertical drag on a card.
        let core = cardContent
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .onLongPressGesture(minimumDuration: 0.45) {
                guard let lp = onLongPress else { return }
                cancelPendingSingleTap()
                lastTapDate = nil
                ignoreNextDragEndTap = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                lp()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        if ignoreNextDragEndTap {
                            ignoreNextDragEndTap = false
                            return
                        }
                        let movedFarEnough =
                            abs(value.translation.width) > tapMovementThreshold ||
                            abs(value.translation.height) > tapMovementThreshold
                        guard !movedFarEnough else {
                            cancelPendingSingleTap()
                            lastTapDate = nil
                            return
                        }
                        handleTapCandidate()
                    }
            )

        Group {
            if hasContextMenuContent {
                core.contextMenu {
                    if let reminder = pendingReminder {
                        Button {
                            let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                            ReminderCommandExecutor(context: modelContext).complete(
                                reminder,
                                by: activeHumanId,
                                note: "overview.quick.action.reminder.complete"
                            )
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("完成待办", systemImage: "checkmark.circle.fill")
                        }
                    }
                    if isGroom, let onAdd = onAddReminder {
                        Button { onAdd() } label: {
                            Label("添加护理待办", systemImage: "bell.badge.plus")
                        }
                    }
                    if onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("移除快捷入口", systemImage: "trash")
                        }
                    }
                }
            } else {
                core
            }
        }
        .confirmationDialog("移除「\(item.label)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("移除", role: .destructive) { onDelete?() }
            Button("取消", role: .cancel) {}
        }
    }

    private var cardContent: some View {
        VStack(spacing: 6) {
            // Icon — keep the function glyph visible; completion is an additive badge/state.
            ZStack {
                OhanaQuickActionIcon(
                    actionType: item.actionType,
                    fallbackSystemName: resolvedIcon,
                    size: 34,
                    color: quickActionIconForeground,
                    isCompleted: isCompletedToday,
                    showsCompletionBadge: isCompletedToday
                )
                .scaleEffect(isPressed ? 0.90 : 1.0)
                .ohanaSymbolPulse(trigger: isCompletedToday)

                if pendingReminder != nil || showsAttentionDot {
                    Circle()
                        .fill(Color.goRed)
                        .frame(width: 7, height: 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 2, y: -2)
                }

                if let privacyIconName {
                    Image(systemName: privacyIconName)
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(privacyIconTint)
                        .shadow(color: Color.arkInk.opacity(0.35), radius: 2, x: 0, y: 1) // ui-v4: allow tiny privacy badge legibility lift
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 3, y: -4)
                }
            }
            .frame(width: 44, height: 44)
            .popover(isPresented: $showGroomMenu, arrowEdge: .top) {
                GroomPopoverContent(onSelect: { raw in
                    onGroomCheckIn?(raw)
                }, themeColor: petThemeColorHex.map { Color(hex: $0) } ?? Color.goPrimary)
                .presentationCompactAdaptation(.popover)
            }
            .popover(isPresented: $showPottyMenu, arrowEdge: .top) {
                PottyPopoverContent(onSelect: { raw in
                    onPottySelect?(raw)
                })
                .presentationCompactAdaptation(.popover)
            }
            .popover(isPresented: $showHealthMenu, arrowEdge: .top) {
                HealthPopoverContent(onSelect: { raw in
                    onHealthSelect?(raw)
                }, petThemeColorHex: petThemeColorHex)
                .presentationCompactAdaptation(.popover)
            }

            // 文字
            VStack(spacing: 1) {
                Text(titleLabelOverride ?? cleanLabel)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(titleForeground)
                    .lineLimit(1)

                if let badge = privacyBadgeText {
                    Label(badge, systemImage: isPrivacyLocked ? "lock.fill" : "globe.asia.australia.fill")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(isPrivacyLocked ? Color.goYellow : subtitleForeground)
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                } else if let subtitle = countText ?? pendingReminder?.event?.title {
                    Text(subtitle)
                        .font(OhanaFont.caption2(.medium))
                        .foregroundStyle(subtitleForeground)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                }
            }
        }
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .frame(maxWidth: .infinity, minHeight: 82)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(cardBgColor, in: premiumShape)
        .overlay {
            premiumShape
                .strokeBorder(cardBorderColor, lineWidth: isWarningState ? 1.2 : 1)
        }
        .animation(GoMotion.feedback, value: isPressed)
        .animation(GoMotion.feedback, value: isCompletedToday)
        .animation(GoMotion.feedback, value: isWarningState)
        .ohanaSelectionMotion(isSelected: isCompletedToday, scale: 1.015)
        .ohanaStateMotion(pendingReminder?.id)
    }

    private func handleTapCandidate() {
        guard onDoubleTap != nil else {
            handlePrimaryTap()
            return
        }

        let now = Date()
        if let lastTapDate, now.timeIntervalSince(lastTapDate) <= doubleTapInterval {
            cancelPendingSingleTap()
            self.lastTapDate = nil
            onDoubleTap?()
            return
        }

        self.lastTapDate = now
        let workItem = DispatchWorkItem {
            handlePrimaryTap()
            self.lastTapDate = nil
            self.pendingSingleTapWorkItem = nil
        }
        pendingSingleTapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapInterval, execute: workItem)
    }

    private func cancelPendingSingleTap() {
        pendingSingleTapWorkItem?.cancel()
        pendingSingleTapWorkItem = nil
    }

    private func handlePrimaryTap() {
        if isGroom && onGroomCheckIn != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showGroomMenu = true
        } else if isPotty && onPottySelect != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showPottyMenu = true
        } else if isHealth && onHealthSelect != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showHealthMenu = true
        } else {
            onTap()
        }
    }
}

// MARK: - Groom Popover (紧凑气泡弹出)
private struct GroomPopoverContent: View {
    let onSelect: (String) -> Void
    var themeColor: Color = Color.goPrimary
    @Environment(\.dismiss) private var dismiss

    private struct GroomOption: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private let options: [GroomOption] = [
        GroomOption(id: "bath",     icon: "drop.fill",   label: "洗澡"),
        GroomOption(id: "teeth",    icon: "mouth.fill",  label: "刷牙"),
        GroomOption(id: "nails",    icon: "scissors",    label: "剪甲"),
        GroomOption(id: "brushing", icon: "comb.fill",   label: "梳毛"),
        GroomOption(id: "ears",     icon: "ear.fill",    label: "清耳"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(themeColor)
                            .frame(width: 48, height: 48)
                        Text(LocalizedStringKey(opt.label))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Potty Popover (便便类型选择气泡)
private struct PottyPopoverContent: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct PottyOption: Identifiable {
        let id: String
        let icon: String
        let label: String
        let colorHex: String
    }

    private let options: [PottyOption] = [
        PottyOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill",                    label: "完美", colorHex: "8B6914"),
        PottyOption(id: PottyType.softPoop.rawValue,    icon: "circle.dashed",                label: "软便", colorHex: "F59E0B"),
        PottyOption(id: PottyType.liquidPoop.rawValue,  icon: "exclamationmark.triangle.fill", label: "水便", colorHex: "EF4444"),
        PottyOption(id: PottyType.pee.rawValue,         icon: "drop.fill",                    label: "尿尿", colorHex: "06B6D4"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.ohanaFunctionalIcon)
                            .frame(width: 48, height: 48)
                        Text(LocalizedStringKey(opt.label))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Health Popover (健康快速记录选项气泡)
private struct HealthPopoverContent: View {
    let onSelect: (String) -> Void
    var petThemeColorHex: String? = nil
    @Environment(\.dismiss) private var dismiss

    private struct HealthOption: Identifiable {
        let id: String
        let icon: String
        let label: String
        let colorHex: String
    }

    private let options: [HealthOption] = [
        HealthOption(id: "symptom",    icon: "exclamationmark.triangle.fill", label: "症状",   colorHex: "EF4444"),
        HealthOption(id: "vaccine",    icon: "syringe.fill",                  label: "疫苗",   colorHex: "10B981"),
        HealthOption(id: "deworming",  icon: "pills.fill",                    label: "驱虫",   colorHex: "8B5CF6"),
        HealthOption(id: "visit",      icon: "stethoscope",                   label: "就诊",   colorHex: "F59E0B"),
        HealthOption(id: "heatCycle",  icon: "heart.circle.fill",            label: "生理期", colorHex: "EC4899"),
    ]

    private var themeColor: Color {
        petThemeColorHex.map { Color(hex: $0) } ?? Color.goPrimary
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.ohanaFunctionalIcon)
                            .frame(width: 48, height: 48)
                        Text(opt.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - QA Manage Sheet
struct QAManageSheet: View {
    let pets: [Pet]
    let defaultPetId: UUID?
    @Binding var savedItems: [QuickActionItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(savedItems, id: \.id) { item in
                    HStack(spacing: 12) {
                        OhanaQuickActionIcon(
                            actionType: item.actionType,
                            fallbackSystemName: item.icon,
                            size: 28,
                            color: Color.ohanaFunctionalIcon
                        )
                        .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                                Text(pet.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            } else {
                                Text("通用")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indices in
                    savedItems.remove(atOffsets: indices)
                }
                .onMove { indices, newOffset in
                    savedItems.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .navigationTitle("编辑快捷操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showingAddSheet = true } label: {
                            Image(systemName: "plus")
                        }
                        Button("完成") { dismiss() }
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddQuickActionSheet(
                    pets: pets,
                    defaultPetId: defaultPetId,
                    existingItems: savedItems
                ) { newItem in
                    if let petId = newItem.petId,
                       let pet = pets.first(where: { $0.id == petId }),
                       QuickActionLimit.count(for: pet, in: savedItems) >= QuickActionLimit.maxItemsPerEntity {
                        return
                    }
                    savedItems.append(newItem)
                }
            }
        }
    }
}

// MARK: - Add Quick Action Sheet
struct AddQuickActionSheet: View {
    let pets: [Pet]
    let defaultPetId: UUID?
    let existingItems: [QuickActionItem]
    let onAdd: (QuickActionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @State private var step: Int = 1
    @State private var selectedPet: Pet? = nil
    @State private var showLimitAlert = false

    /// F3: 实时读取 AppStorage 中的 item 数量（而非快照）
    private var liveItems: [QuickActionItem] {
        (try? JSONDecoder().decode([QuickActionItem].self, from: Data(quickActionItemsJSON.utf8))) ?? []
    }
    private var selectedPetItemCount: Int {
        guard let pet = selectedPet else { return 0 }
        return QuickActionLimit.count(for: pet, in: liveItems)
    }

    private func availableActions(for pet: Pet) -> [QuickActionPickerCatalog.Option] {
        let existingTypes = Set(liveItems.filter { $0.petId == pet.id }.map { $0.actionType })
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existingTypes)
    }

    @State private var pressedActionId: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.22))
                .zIndex(1)

            VStack(spacing: 0) {
                Color.clear.frame(height: 22)
                if step == 1 {
                    petStep
                } else {
                    actionStep
                }
                Spacer(minLength: 32)
            }
        }
        .ohanaCompactSheetPresentation(detents: [.height(380), .medium])
        .onAppear {
            if let pid = defaultPetId, let pet = pets.first(where: { $0.id == pid }) {
                selectedPet = pet
                step = 2
            }
        }
        .alert(QuickActionLimit.title, isPresented: $showLimitAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(QuickActionLimit.message)
        }
    }

    private var petStep: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择宠物")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("为哪只宠物添加快速入口")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { dismiss() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // 宠物列表
            VStack(spacing: 10) {
                ForEach(pets) { pet in
                    Button {
                        selectedPet = pet
                        withAnimation(GoMotion.selection) { step = 2 }
                    } label: {
                        HStack(spacing: 14) {
                            PetAvatarPortraitView(
                                imageData: pet.avatarImageData,
                                fallbackText: pet.avatarEmoji,
                                themeColor: Color(hex: pet.safeThemeColorHex),
                                size: 48,
                                backgroundOpacity: 0.22
                            )
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text("\(pet.species) · \(pet.breed)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: pet.themeColorHex))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .goGlassBackground(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var actionStep: some View {
        VStack(spacing: 20) {
            // 头部：返回按鈕 + 宠物头像与名字融为一体
            HStack(spacing: 12) {
                Button {
                    withAnimation(GoMotion.selection) { step = 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 32, height: 32)
                        .background(.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())

                if let pet = selectedPet {
                    PetAvatarPortraitView(
                        imageData: pet.avatarImageData,
                        fallbackText: pet.avatarEmoji,
                        themeColor: Color(hex: pet.safeThemeColorHex),
                        size: 36,
                        backgroundOpacity: 0.2
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pet.name)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                        Text("选择快捷功能")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
                Spacer()
                OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) { dismiss() }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // iOS 控制中心风格图标网格
            if let pet = selectedPet {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        let available = availableActions(for: pet)
                        if selectedPetItemCount >= QuickActionLimit.maxItemsPerEntity {
                            VStack(spacing: 8) {
                                Text("最多 8 个快捷操作")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(Color.ohanaPrimaryText)
                                Text("更多功能可以去「全部功能」里查看。")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if available.isEmpty {
                            Text("所有快捷入口已添加")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaSecondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        }
                        ForEach(available) { action in
                            let accentColor = Color.ohanaFunctionalIcon
                            let isPressed = pressedActionId == action.id
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                guard selectedPetItemCount < QuickActionLimit.maxItemsPerEntity else {
                                    showLimitAlert = true
                                    return
                                }
                                onAdd(QuickActionItem(
                                    label: action.label,
                                    icon: action.icon, colorHex: action.colorHex,
                                    petId: pet.id, actionType: action.id
                                ))
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    OhanaQuickActionIcon(
                                        actionType: action.id,
                                        fallbackSystemName: action.icon,
                                        size: 34,
                                        color: Color.ohanaFunctionalIcon
                                    )
                                    .frame(width: 44, height: 44)
                                    Text(action.label)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.ohanaPrimaryText)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isPressed ? accentColor.opacity(0.1) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .scaleEffect(isPressed ? 0.90 : 1.0)
                                .animation(GoMotion.tap, value: isPressed)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(selectedPetItemCount >= QuickActionLimit.maxItemsPerEntity)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in pressedActionId = action.id }
                                    .onEnded   { _ in pressedActionId = nil }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Quick Feed Sheet
struct QuickFeedSheet: View {
    let pet: Pet
    let actionType: String
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var setAsDefault = false

    private var isWater: Bool { actionType == "water" }
    private var unit: String { isWater ? "ml" : "g" }
    private var defaultAmount: Double { isWater ? 200 : pet.dailyPortionGrams }
    private var isCasual: Bool { !isWater && pet.foodTrackingMode == .casual }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground()
                VStack(spacing: 24) {
                    petHeader
                    HStack {
                        ExecutorPickerBar(tint: Color.goPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    if isCasual {
                        casualBody
                    } else {
                        preciseBody
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                }
            }
        }
    }

    private var petHeader: some View {
        HStack(spacing: 12) {
            PetAvatarPortraitView(
                imageData: pet.avatarImageData,
                fallbackText: pet.avatarEmoji,
                themeColor: Color(hex: pet.safeThemeColorHex),
                size: 52,
                backgroundOpacity: 0.15
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.body(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isWater ? "喂水打卡" : (isCasual ? "佛系喂食 🐾" : "精准喂食 📊"))
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
            }
            Spacer()
            Text(isWater ? "💧" : "🍗").font(.system(size: 30))
        }
        .padding(.horizontal, 20)
    }

    private var casualBody: some View {
        VStack(spacing: 20) {
            UltimateGlassCard {
                VStack(spacing: 12) {
                    Text(casualCopyText)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .multilineTextAlignment(.center)
                    Text("打卡后获得 +1🥥 椰子奖励")
                        .font(OhanaFont.footnote(.medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                }
                .padding(24)
            }
            .padding(.horizontal, 20)

            Button { commitFeed(amount: 0) } label: {
                HStack(spacing: 8) {
                    Text("✅")
                    Text("确认喂食  +1🥥")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)

        }
    }

    private var preciseBody: some View {
        VStack(spacing: 16) {
            UltimateGlassCard {
                VStack(spacing: 12) {
                    Text("输入\(isWater ? "饮水量" : "喂食量")")
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.6))
                    InlineNumericInput(
                        text: $amountText,
                        placeholder: "默认 \(Int(defaultAmount))",
                        unit: unit,
                        maxFractionDigits: 0,
                        accent: Color.goPrimary,
                        step: isWater ? 50 : 5,
                        valueFont: OhanaFont.metric(size: 32),
                        unitFont: OhanaFont.title3(.bold),
                        fill: Color.ohanaControlFill,
                        cornerRadius: 16,
                        horizontalPadding: 12,
                        verticalPadding: 10
                    )
                    Toggle(isOn: $setAsDefault) {
                        Text("设为默认\(isWater ? "饮水量" : "每日份量")")
                            .font(OhanaFont.footnote(.medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.7))
                    }
                    .tint(Color.goPrimary)
                }
                .padding(20)
            }
            .padding(.horizontal, 20)

            Button {
                let amount = CountryDecimalInput.parse(amountText, countryCode: AppCountry.code) ?? defaultAmount
                commitFeed(amount: amount)
            } label: {
                Text("打卡 +1🥥")
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)

        }
    }

    private var casualCopyText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:  return "早餐时间到了！\n主子今天胃口好吗？🌅"
        case 10..<14: return "午饭打卡！\n记得让 \(pet.name) 多喝水哦 💦"
        case 14..<18: return "下午喂食 ☀️\n\(pet.name) 今天乖吗？"
        case 18..<22: return "晚餐时间！\n今天辛苦啦，\(pet.name) 也一样 🌙"
        default:       return "\(pet.name) 的宵夜时间？\n记录一下也没关系 😄"
        }
    }

    private func commitFeed(amount: Double) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap {
            $0.isEmpty ? nil : $0
        }
        if isWater {
            let waterAmount = amount > 0 ? amount : defaultAmount
            CareEventService.recordCare(pet: pet, type: .watering, amountMl: waterAmount, context: modelContext, executorId: executorId, reward: .water)
        } else {
            if !isCasual && setAsDefault && amount > 0 { pet.dailyPortionGrams = amount }
            CareEventService.recordManualFeed(
                pet: pet,
                amountGrams: amount,
                context: modelContext,
                executorId: executorId,
                foodKind: pet.mainFoodKind
            )
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - 喂水已打卡：水滴内下半部水浪（浪线仅画在 drop 下半区，再按水滴形 mask）
private struct QuickActionWaterDropWithWaves: View {
    let accent: Color
    var isPressed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var dropSize: CGFloat { 30 }
    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.ambientMotionBudget(isVisible: true) == .static
    }

    var body: some View {
        let frame = dropSize * 1.2
        ZStack {
            Image(systemName: "drop.fill")
                .font(.system(size: dropSize, weight: .semibold))
                .foregroundStyle(accent)

            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: shouldReduceWork)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let yMin = h * 0.48
                    let bandH = max(4, h - yMin)
                    for i in 0..<5 {
                        var path = Path()
                        let row = CGFloat(i)
                        let yBase = yMin + bandH * (0.12 + row * 0.17)
                        path.move(to: CGPoint(x: -1, y: yBase))
                        let steps = max(12, Int(w / 2))
                        for s in 0...steps {
                            let px = CGFloat(s) / CGFloat(steps) * (w + 2)
                            let phase = CGFloat(t * 1.75) + row * 0.55
                            let wave = sin((px / 6.8 + phase) * .pi / 2.2) * 2.4
                            path.addLine(to: CGPoint(x: px, y: yBase + wave))
                        }
                        context.stroke(
                            path,
                            with: .color(Color.ohanaPrimaryText.opacity(0.22 + 0.06 * (1 - Double(i) / 5))),
                            lineWidth: i < 2 ? 1.15 : 0.95
                        )
                    }
                }
                .frame(width: frame, height: frame)
                .mask {
                    Image(systemName: "drop.fill")
                        .font(.system(size: dropSize, weight: .semibold))
                        .frame(width: frame, height: frame)
                }
            }

            Image(systemName: "drop.fill")
                .font(.system(size: dropSize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(isPressed ? 0.90 : 1.0)
        .accessibilityLabel("喂水，今日已打卡")
    }
}

// MARK: - QA Quick Add Popover（与 GoQuickActionCard 同款 SF Symbol + 前景色，圆环色圈 + 横滑）
struct QAQuickAddPopoverContent: View {
    let pet: Pet
    let existingItems: [QuickActionItem]
    let onAdd: (QuickActionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var qaColorScheme
    @State private var showLimitAlert = false

    private var petItemCount: Int {
        QuickActionLimit.count(for: pet, in: existingItems)
    }

    private var isAtLimit: Bool {
        petItemCount >= QuickActionLimit.maxItemsPerEntity
    }

    private var options: [QuickActionPickerCatalog.Option] {
        let existing = Set(existingItems.filter { $0.petId == pet.id }.map(\.actionType))
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existing)
    }

    /// 与 `GoQuickActionCard.quickActionIconForeground` 一致（添加面板无「今日已打卡」态）
    private func pickerIconForeground(actionType: String) -> Color {
        if qaColorScheme == .dark { return .white.opacity(actionType == "feed" ? 0.72 : 0.92) }
        if actionType == "feed" { return Color.secondary }
        return Color.primary.opacity(0.75)
    }

    var body: some View {
        Group {
            if isAtLimit {
                VStack(spacing: 8) {
                    Text("8/8").font(.system(size: 24, weight: .black, design: .rounded))
                    Text("快捷操作已满")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("更多功能请去「全部功能」查看")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if options.isEmpty {
                VStack(spacing: 8) {
                    Text("✅").font(.system(size: 26))
                    Text("已全部添加")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(options) { opt in
                            let accent = Color(hex: opt.colorHex)
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                guard !isAtLimit else {
                                    showLimitAlert = true
                                    return
                                }
                                onAdd(QuickActionItem(
                                    label: opt.label,
                                    icon: opt.icon,
                                    colorHex: opt.colorHex,
                                    petId: pet.id,
                                    actionType: opt.id
                                ))
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(accent.opacity(0.18))
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Circle().strokeBorder(accent.opacity(0.4), lineWidth: 1)
                                            )
                                        OhanaQuickActionIcon(
                                            actionType: opt.id,
                                            fallbackSystemName: opt.icon,
                                            size: 34,
                                            color: pickerIconForeground(actionType: opt.id)
                                        )
                                    }
                                    Text(opt.label)
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(qaColorScheme == .dark ? .white.opacity(0.9) : .primary)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .presentationCompactAdaptation(.popover)
        .alert(QuickActionLimit.title, isPresented: $showLimitAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(QuickActionLimit.message)
        }
    }
}

/// 编辑模式拖拽排序：系统预览仅显示图标+文字，无卡片矩形底
struct QuickActionReorderDragPreview: View {
    let item: QuickActionItem
    var themeHex: String?

    var body: some View {
        VStack(spacing: 6) {
            OhanaQuickActionIcon(
                actionType: item.actionType,
                fallbackSystemName: item.icon,
                size: 34,
                color: Color.ohanaFunctionalIcon
            )
            .frame(width: 44, height: 44)
            Text(item.label)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .fixedSize()
    }
}

/// 编辑模式拖拽层：自定义预览仅图标+标题（无整张卡片矩形）。
struct QAEditModeDragLayer: View {
    let item: QuickActionItem
    let themeHex: String?
    @Binding var draggingItemId: String?

    var body: some View {
        Color.clear
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onDrag {
                OhanaFeedback.light()
                withAnimation(GoMotion.selection) {
                    draggingItemId = item.id
                }
                return NSItemProvider(object: item.id as NSString)
            } preview: {
                QuickActionReorderDragPreview(item: item, themeHex: themeHex)
            }
    }
}

struct QADropDelegate: DropDelegate {
    let targetItem: QuickActionItem
    @Binding var items: [QuickActionItem]
    @Binding var draggingItemId: String?
    @Binding var lastDropTargetId: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingItemId = nil
        lastDropTargetId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard lastDropTargetId != targetItem.id else { return }

        if let draggingItemId {
            moveItem(fromId: draggingItemId)
            return
        }

        let types: [UTType] = [.plainText, .utf8PlainText]
        guard let provider = info.itemProviders(for: types).first else { return }
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let ns = obj as? NSString else { return }
            let fromId = ns as String
            DispatchQueue.main.async {
                moveItem(fromId: fromId)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if lastDropTargetId == targetItem.id {
            lastDropTargetId = nil
        }
    }

    private func moveItem(fromId: String) {
        guard fromId != targetItem.id,
              let fromIdx = items.firstIndex(where: { $0.id == fromId }),
              let toIdx = items.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        lastDropTargetId = targetItem.id
        OhanaFeedback.light()
        withAnimation(GoMotion.selection) {
            items.move(
                fromOffsets: IndexSet(integer: fromIdx),
                toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
            )
        }
    }
}

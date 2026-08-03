import Foundation
import SwiftUI

nonisolated struct AppIconShopDescriptor: Identifiable, Equatable {
    let itemId: String
    let alternateIconName: String?
    let previewSymbol: String
    let gradientHex: [String]

    var id: String { itemId }
    var isDefault: Bool { alternateIconName == nil }
    var assetName: String { "\(alternateIconName ?? "AppIcon")Preview" }
}

nonisolated enum ShopApplicationRequirement: String, Equatable, Sendable {
    case none
    case activePet
    case activeDog
}

nonisolated enum ShopEffectKind: String, Equatable, Sendable {
    case popoutCard
    case limeGlow
    case rainbowTrail
    case rainbowPoop
    case starfall
    case firework
}

nonisolated enum ShopProductApplication: Equatable, Sendable {
    case appIcon
    case avatarPass
    case effect(ShopEffectKind)
    case plantDecor
    case title
    case goldenLuck
    case streakShield
    case backdatePasses(Int)
    case treeEnergy(Int)
    case unsupported

    var isInventoryConsumable: Bool {
        switch self {
        case .avatarPass, .goldenLuck, .streakShield, .backdatePasses:
            true
        default:
            false
        }
    }
}

/// Single catalog-to-runtime mapping. Every sellable item must resolve to a
/// concrete application path so a successful purchase can never become inert
/// inventory.
nonisolated enum ShopProductApplicationCatalog {
    static func application(for itemID: String) -> ShopProductApplication {
        if AppIconCatalog.descriptor(forItemId: itemID) != nil {
            return .appIcon
        }
        if itemID == Avatar2DAccess.shopItemId {
            return .avatarPass
        }
        switch itemID {
        case "fx_popout_card":
            return .effect(.popoutCard)
        case "fx_lime_glow":
            return .effect(.limeGlow)
        case "fx_rainbow":
            return .effect(.rainbowTrail)
        case "fx_rainbow_poop":
            return .effect(.rainbowPoop)
        case "fx_stars":
            return .effect(.starfall)
        case "fx_firework":
            return .effect(.firework)
        case "title_guardian", "title_pioneer", "title_chef":
            return .title
        case "boost_double":
            return .goldenLuck
        case "boost_streak":
            return .streakShield
        case "boost_backdate_single":
            return .backdatePasses(1)
        case "boost_backdate_pack":
            return .backdatePasses(3)
        case "boost_tree":
            return .treeEnergy(OasisTreeEnergyInjectionPolicy.starterPackageXP)
        case "boost_tree_large":
            return .treeEnergy(OasisTreeEnergyInjectionPolicy.largePackageXP)
        default:
            return OasisPlantDecorID.isPlantDecor(itemID) ? .plantDecor : .unsupported
        }
    }

    static func requirement(for itemID: String) -> ShopApplicationRequirement {
        switch application(for: itemID) {
        case .effect(.popoutCard), .effect(.limeGlow):
            .activePet
        case .effect(.rainbowTrail), .effect(.rainbowPoop):
            .activeDog
        default:
            .none
        }
    }
}

nonisolated struct ShopItem: Identifiable, Equatable {
    nonisolated enum ShopCategory: String, CaseIterable, Identifiable {
        case appIcon
        case avatar2d
        case cashExchange
        case effect
        case plantDecor
        case title_
        case boost

        var id: String { rawValue }

        static var visibleCases: [ShopCategory] {
            [
                .effect,
                .plantDecor,
                .appIcon,
                .avatar2d,
                .title_,
                .boost,
                .cashExchange
            ].filter(\.isVisibleInFirstRelease)
        }

        var isVisibleInFirstRelease: Bool {
            self != .cashExchange || CoconutExchangeFeatureGate.isEnabled
        }

        func title(_ l: L10n = L10n()) -> String {
            switch self {
            case .appIcon:
                l.tr(zh: "App Icon", en: "App Icon", de: "App Icon")
            case .avatar2d:
                l.tr(zh: "2.5D 头像", en: "2.5D Avatar", de: "2,5D-Avatar")
            case .cashExchange:
                l.tr(zh: "货币兑换", en: "Cash Exchange", de: "Geldtausch")
            case .effect:
                l.tr(zh: "外观特效", en: "Effects", de: "Effekte")
            case .plantDecor:
                l.tr(zh: "植物装饰", en: "Plant Decor", de: "Pflanzendeko")
            case .title_:
                l.tr(zh: "称号", en: "Titles", de: "Titel")
            case .boost:
                l.tr(zh: "加成道具", en: "Boosts", de: "Boosts")
            }
        }

        var icon: String {
            switch self {
            case .appIcon: "app.badge.fill"
            case .avatar2d: "person.crop.square.fill"
            case .cashExchange: "banknote.fill"
            case .effect: "sparkles"
            case .plantDecor: "leaf.fill"
            case .title_: "rosette"
            case .boost: "bolt.fill"
            }
        }
    }

    let id: String
    let emoji: String
    let nameText: AppLocalizedText
    let descriptionText: AppLocalizedText
    let cost: Int
    let category: ShopCategory
    var isConsumable: Bool = false
    var appIcon: AppIconShopDescriptor?
    var isPurchased: Bool = false

    var name: String { nameText.resolve() }
    var description: String { descriptionText.resolve() }

    func name(_ l: L10n) -> String { l.text(nameText) }
    func description(_ l: L10n) -> String { l.text(descriptionText) }
    var application: ShopProductApplication { ShopProductApplicationCatalog.application(for: id) }
    var applicationRequirement: ShopApplicationRequirement {
        ShopProductApplicationCatalog.requirement(for: id)
    }
}

nonisolated enum AppIconCatalog {
    static let selectedIconKey = "shop_selected_app_icon"
    static let defaultItemId = "appicon_default"

    static let icons: [AppIconShopDescriptor] = [
        AppIconShopDescriptor(
            itemId: defaultItemId,
            alternateIconName: nil,
            previewSymbol: "o.circle.fill",
            gradientHex: ["FFFFFF", "1A1A2E", "000000"]
        ),
        AppIconShopDescriptor(
            itemId: "appicon_lime_night",
            alternateIconName: "AppIconLimeNight",
            previewSymbol: "moon.stars.fill",
            gradientHex: ["0A1020", "C8FF00", "213000"]
        ),
        AppIconShopDescriptor(
            itemId: "appicon_clean_blue",
            alternateIconName: "AppIconCleanBlue",
            previewSymbol: "sparkles",
            gradientHex: ["D8E9FF", "3B82F6", "0F2A5C"]
        ),
        AppIconShopDescriptor(
            itemId: "appicon_coconut",
            alternateIconName: "AppIconCoconut",
            previewSymbol: "circle.hexagongrid.fill",
            gradientHex: ["FFF4D7", "B8834D", "3B2413"]
        ),
        AppIconShopDescriptor(
            itemId: "appicon_paw_duo",
            alternateIconName: "AppIconPawDuo",
            previewSymbol: "pawprint.fill",
            gradientHex: ["231942", "E0B1CB", "5E548E"]
        ),
        AppIconShopDescriptor(
            itemId: "appicon_minimal_o",
            alternateIconName: "AppIconMinimalO",
            previewSymbol: "circle",
            gradientHex: ["F8FAFC", "1A1A2E", "8EA4FF"]
        ),
        AppIconShopDescriptor(
            itemId: "appicon_neon_smile",
            alternateIconName: "AppIconNeonSmile",
            previewSymbol: "face.smiling.inverse",
            gradientHex: ["000000", "C8FF00", "0A2A00"]
        )
    ]

    static func descriptor(forItemId id: String) -> AppIconShopDescriptor? {
        icons.first { $0.itemId == id }
    }

    static func descriptor(forAlternateIconName name: String?) -> AppIconShopDescriptor {
        icons.first { $0.alternateIconName == name } ?? icons[0]
    }
}

nonisolated enum ShopCatalog {
    static func allItems(purchasedSet: Set<String> = []) -> [ShopItem] {
        sellableItems.map { decorated($0, purchasedSet: purchasedSet) }
    }

    static func item(id: String, purchasedSet: Set<String> = []) -> ShopItem? {
        allCatalogItems
            .first { $0.id == id }
            .map { decorated($0, purchasedSet: purchasedSet) }
    }

    static func isSellable(itemID: String) -> Bool {
        sellableItems.contains { $0.id == itemID }
    }

    static var allCatalogIDsHaveApplications: Bool {
        allCatalogItems.allSatisfy { $0.application != .unsupported }
    }

    private static func decorated(_ item: ShopItem, purchasedSet: Set<String>) -> ShopItem {
        var copy = item
        if item.appIcon?.isDefault == true {
            copy.isPurchased = true
        } else if !item.isConsumable {
            copy.isPurchased = purchasedSet.contains(item.id)
        }
        return copy
    }

    private static let sellableItems: [ShopItem] =
        appIconItems + avatarItems + effectItems + plantDecorItems + titleItems + boostItems

    /// Retained only so historical in-flight purchases can finish after an app
    /// update. Tree energy remains available from Oasis itself, not as a
    /// duplicated shop shelf. Backdate passes remain recoverable for old
    /// receipts and backups, but are not sold while the retired makeup command
    /// has no supported Presence write path.
    private static let legacyFulfillmentItems: [ShopItem] = [
        ShopItem(
            id: "boost_tree",
            emoji: "🌱",
            nameText: .init(
                zh: "树能量 +\(OasisTreeEnergyInjectionPolicy.starterPackageXP)XP",
                en: "Tree XP +\(OasisTreeEnergyInjectionPolicy.starterPackageXP)",
                de: "Baum-XP +\(OasisTreeEnergyInjectionPolicy.starterPackageXP)"
            ),
            descriptionText: .init(
                zh: "旧版商店树能量订单；新注入请前往绿洲。基础植物照护不靠购买。",
                en: "Legacy shop tree-energy order. New injections live in Oasis; basic plant care is never purchased.",
                de: "Ältere Baumenergie-Bestellung. Neue Energie wird in Oasis eingespeist; grundlegende Pflanzenpflege wird nie gekauft."
            ),
            cost: OasisTreeEnergyInjectionPolicy.starterPackageCost,
            category: .boost,
            isConsumable: true
        ),
        ShopItem(
            id: "boost_tree_large",
            emoji: "🌳",
            nameText: .init(
                zh: "树能量包 +\(OasisTreeEnergyInjectionPolicy.largePackageXP)XP",
                en: "Tree XP Pack +\(OasisTreeEnergyInjectionPolicy.largePackageXP)",
                de: "Baum-XP-Paket +\(OasisTreeEnergyInjectionPolicy.largePackageXP)"
            ),
            descriptionText: .init(
                zh: "旧版商店树能量订单；新注入请前往绿洲。基础植物照护不靠购买。",
                en: "Legacy shop tree-energy order. New injections live in Oasis; basic plant care is never purchased.",
                de: "Ältere Baumenergie-Bestellung. Neue Energie wird in Oasis eingespeist; grundlegende Pflanzenpflege wird nie gekauft."
            ),
            cost: OasisTreeEnergyInjectionPolicy.largePackageCost,
            category: .boost,
            isConsumable: true
        ),
        ShopItem(
            id: "boost_backdate_single",
            emoji: "📅",
            nameText: .init(zh: "补签券 ×1", en: "Backdate Pass ×1", de: "Nachtragspass ×1"),
            descriptionText: .init(
                zh: "旧版补签券库存；当前版本不再新增出售。",
                en: "Legacy backdate inventory; no longer sold in this version.",
                de: "Älterer Nachtragspass; in dieser Version nicht mehr erhältlich."
            ),
            cost: 240,
            category: .boost,
            isConsumable: true
        ),
        ShopItem(
            id: "boost_backdate_pack",
            emoji: "🗓️",
            nameText: .init(zh: "补签券 ×3", en: "Backdate Pass ×3", de: "Nachtragspass ×3"),
            descriptionText: .init(
                zh: "旧版补签券库存；当前版本不再新增出售。",
                en: "Legacy backdate inventory; no longer sold in this version.",
                de: "Ältere Nachtragspässe; in dieser Version nicht mehr erhältlich."
            ),
            cost: 580,
            category: .boost,
            isConsumable: true
        )
    ]

    private static let allCatalogItems = sellableItems + legacyFulfillmentItems

    private static let appIconItems: [ShopItem] = [
        ShopItem(
            id: AppIconCatalog.defaultItemId,
            emoji: "◎",
            nameText: .init(zh: "默认 Ohana", en: "Default Ohana", de: "Ohana Standard"),
            descriptionText: .init(zh: "恢复系统默认图标。", en: "Restore the default app icon.", de: "Stellt das Standard-App-Symbol wieder her."),
            cost: 0,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[0]
        ),
        ShopItem(
            id: "appicon_lime_night",
            emoji: "☾",
            nameText: .init(zh: "Lime Night", en: "Lime Night", de: "Lime Night"),
            descriptionText: .init(zh: "深色模式感最强的青柠夜光图标。", en: "A lime night icon for dark-mode energy.", de: "Ein Lime-Nacht-Symbol für dunkle Energie."),
            cost: 700,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[1]
        ),
        ShopItem(
            id: "appicon_clean_blue",
            emoji: "✦",
            nameText: .init(zh: "Clean Blue", en: "Clean Blue", de: "Clean Blue"),
            descriptionText: .init(zh: "清爽蓝白图标，适合浅色主屏。", en: "A clean blue icon for bright Home Screens.", de: "Ein klares blaues Symbol für helle Homescreens."),
            cost: 600,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[2]
        ),
        ShopItem(
            id: "appicon_coconut",
            emoji: "🥥",
            nameText: .init(zh: "Coconut", en: "Coconut", de: "Kokosnuss"),
            descriptionText: .init(zh: "椰子奖励主题，轻松但醒目。", en: "A playful coconut reward theme.", de: "Ein verspieltes Kokosnuss-Belohnungsthema."),
            cost: 600,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[3]
        ),
        ShopItem(
            id: "appicon_paw_duo",
            emoji: "🐾",
            nameText: .init(zh: "Paw Duo", en: "Paw Duo", de: "Paw Duo"),
            descriptionText: .init(zh: "人宠陪伴感更强的柔紫爪印。", en: "A warm paw icon for family care.", de: "Ein warmes Pfoten-Symbol für Familienpflege."),
            cost: 800,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[4]
        ),
        ShopItem(
            id: "appicon_minimal_o",
            emoji: "O",
            nameText: .init(zh: "Minimal O", en: "Minimal O", de: "Minimal O"),
            descriptionText: .init(zh: "高级极简 O 标识。", en: "A premium minimal O mark.", de: "Ein hochwertiges minimalistisches O."),
            cost: 900,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[5]
        ),
        ShopItem(
            id: "appicon_neon_smile",
            emoji: "☻",
            nameText: .init(zh: "霓虹笑脸", en: "Neon Smile", de: "Neon Smile"),
            descriptionText: .init(zh: "黑底荧光绿的招牌笑脸，深色主屏最抢眼。", en: "The signature smile in neon lime on black — boldest on dark Home Screens.", de: "Das Markenlächeln in Neon-Limette auf Schwarz – am auffälligsten auf dunklen Homescreens."),
            cost: 700,
            category: .appIcon,
            appIcon: AppIconCatalog.icons[6]
        )
    ]

    private static let avatarItems: [ShopItem] = [
        ShopItem(
            id: Avatar2DAccess.shopItemId,
            emoji: "🖼️",
            nameText: .init(zh: "2.5D 头像券", en: "2.5D Avatar Pass", de: "2,5D-Avatarpass"),
            descriptionText: .init(zh: "购买后指定 1 位人类或宠物升级 2.5D 头像。", en: "Upgrade one human or pet to a 2.5D avatar.", de: "Wertet einen Menschen oder ein Tier auf einen 2,5D-Avatar auf."),
            cost: 1200,
            category: .avatar2d,
            isConsumable: true
        )
    ]

    private static let effectItems: [ShopItem] = [
        ShopItem(id: "fx_popout_card", emoji: "🃏", nameText: .init(zh: "3D 破框卡片", en: "3D Popout Card", de: "3D-Popout-Karte"), descriptionText: .init(zh: "宠物主体从卡片破框悬浮而出，需配合透明抠图使用。", en: "Let a pet pop out from its card when cutout assets are available.", de: "Lässt ein Tier aus der Karte hervortreten, wenn Freisteller verfügbar sind."), cost: 800, category: .effect),
        ShopItem(
            id: "fx_lime_glow",
            emoji: "💚",
            nameText: .init(
                zh: "青柠光晕",
                en: "Lime Glow",
                de: "Lime-Leuchten",
                es: "Brillo lima",
                pt: "Brilho lima",
                fr: "Halo citron vert",
                ja: "ライムグロー",
                ko: "라임 글로우",
                it: "Bagliore lime"
            ),
            descriptionText: .init(
                zh: "让主页上的在世宠物卡片散发青柠光晕。",
                en: "Adds a lime glow to active pet cards on Home.",
                de: "Verleiht aktiven Tierkarten auf der Startseite ein Lime-Leuchten.",
                es: "Añade un brillo lima a las tarjetas de mascotas activas en Inicio.",
                pt: "Adiciona um brilho lima aos cartões de pets ativos na tela inicial.",
                fr: "Ajoute un halo citron vert aux cartes des animaux actifs sur l’accueil.",
                ja: "ホームにいる有効なペットカードへライム色の光を加えます。",
                ko: "홈의 활성 반려동물 카드에 라임빛 광채를 더합니다.",
                it: "Aggiunge un bagliore lime alle schede degli animali attivi nella Home."
            ),
            cost: 300,
            category: .effect
        ),
        ShopItem(id: "fx_rainbow", emoji: "🌈", nameText: .init(zh: "彩虹轨迹", en: "Rainbow Trail", de: "Regenbogenroute"), descriptionText: .init(zh: "遛狗路线地图显示彩虹轨迹风格。", en: "Shows dog-walk routes with a rainbow trail.", de: "Zeigt Spaziergänge als Regenbogenroute."), cost: 650, category: .effect),
        ShopItem(id: "fx_rainbow_poop", emoji: "💩", nameText: .init(zh: "彩虹便便", en: "Rainbow Poop", de: "Regenbogenkot"), descriptionText: .init(zh: "遛狗便便标记显示流动彩虹光圈。", en: "Adds a flowing rainbow ring to walk poop markers.", de: "Fügt Gassi-Kotmarkierungen einen fließenden Regenbogenring hinzu."), cost: 420, category: .effect),
        ShopItem(
            id: "fx_stars",
            emoji: "⭐️",
            nameText: .init(
                zh: "星光落雨",
                en: "Starfall",
                de: "Sternenregen",
                es: "Lluvia estelar",
                pt: "Chuva de estrelas",
                fr: "Pluie d’étoiles",
                ja: "星降る光",
                ko: "별빛 비",
                it: "Pioggia di stelle"
            ),
            descriptionText: .init(
                zh: "完成每日委托时触发星光粒子特效；它不是伙伴星光货币。",
                en: "Adds starfall particles to daily quest completions. This is not companion stardust currency.",
                de: "Zeigt Sternenregen bei Tagesaufgaben. Dies ist keine Begleiter-Sternenstaubwährung.",
                es: "Añade partículas de estrellas al completar encargos diarios. No es la moneda de compañeros.",
                pt: "Adiciona partículas de estrelas ao concluir tarefas diárias. Não é a moeda dos companheiros.",
                fr: "Ajoute une pluie d’étoiles aux quêtes quotidiennes. Ce n’est pas la monnaie des compagnons.",
                ja: "デイリー依頼の完了時に星の粒子を表示します。仲間用通貨ではありません。",
                ko: "일일 의뢰 완료 시 별빛 입자를 표시합니다. 동료 재화가 아닙니다.",
                it: "Aggiunge particelle stellari alle missioni giornaliere. Non è la valuta dei compagni."
            ),
            cost: 350,
            category: .effect
        ),
        ShopItem(id: "fx_firework", emoji: "🎆", nameText: .init(zh: "烟花庆典", en: "Firework", de: "Feuerwerk"), descriptionText: .init(zh: "达成里程碑时升级烟花动画。", en: "Upgrades milestone celebrations with fireworks.", de: "Erweitert Meilensteinfeiern mit Feuerwerk."), cost: 720, category: .effect)
    ]

    private static let plantDecorItems: [ShopItem] = [
        ShopItem(
            id: OasisPlantDecorID.greenhouseCorner,
            emoji: "▱",
            nameText: .init(zh: "温室角落", en: "Greenhouse Corner", de: "Gewächshaus-Ecke"),
            descriptionText: .init(
                zh: "让绿洲多一个植物角；只改变氛围，不影响护理计划或提醒。",
                en: "Adds a plant corner to the Oasis. Cosmetic only; care plans and reminders stay free.",
                de: "Pflanzenecke für Oasis. Nur Deko; Pflegepläne und Erinnerungen bleiben kostenlos."
            ),
            cost: 520,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.balconyPlanters,
            emoji: "▰",
            nameText: .init(zh: "阳台花箱", en: "Balcony Planters", de: "Balkonkästen"),
            descriptionText: .init(
                zh: "给岛屿边缘放上花箱；不出售植物识别、提醒或护理能力。",
                en: "Places planters along the island edge. It does not sell recognition, reminders, or care.",
                de: "Pflanzkästen am Inselrand. Verkauft keine Erkennung, Erinnerung oder Pflege."
            ),
            cost: 420,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.seasonalMiniScape,
            emoji: "✤",
            nameText: .init(zh: "季节小景观", en: "Seasonal Mini-Scape", de: "Saison-Miniatur"),
            descriptionText: .init(
                zh: "把植物照护的成就感变成季节小景观；核心植物管理仍然免费。",
                en: "Turns plant-care momentum into a seasonal scene. Core plant management remains free.",
                de: "Macht Pflanzenpflege sichtbar als Saisonbild. Grundpflege bleibt kostenlos."
            ),
            cost: 680,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.mossPath,
            emoji: "⌁",
            nameText: .init(zh: "苔藓小径", en: "Moss Path", de: "Moospfad"),
            descriptionText: .init(
                zh: "给绿洲铺一条柔软苔藓路；只改变岛屿外观，不影响植物提醒。",
                en: "Adds a soft moss path to the Oasis. Cosmetic only; plant reminders stay free.",
                de: "Ein weicher Moospfad für Oasis. Nur Deko; Pflanzenerinnerungen bleiben kostenlos."
            ),
            cost: 360,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.hangingVines,
            emoji: "⌇",
            nameText: .init(zh: "垂藤帘", en: "Hanging Vines", de: "Hängende Ranken"),
            descriptionText: .init(
                zh: "给生命之树旁加一层垂藤；不出售植物识别、诊断或护理计划。",
                en: "Adds hanging vines near the life tree. Recognition, diagnosis, and care plans are not sold here.",
                de: "Hängende Ranken am Lebensbaum. Erkennung, Diagnose und Pflegepläne werden hier nicht verkauft."
            ),
            cost: 760,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.ceramicPotSkin,
            emoji: "◍",
            nameText: .init(zh: "陶盆皮肤", en: "Ceramic Pot Skin", de: "Keramiktopf-Skin"),
            descriptionText: .init(
                zh: "给绿洲植物换上陶盆外观；不会改变任何浇水或施肥规则。",
                en: "Gives Oasis plants a ceramic pot look. Watering and fertilizing rules do not change.",
                de: "Keramiktopf-Look für Oasis-Pflanzen. Gieß- und Düngepläne bleiben gleich."
            ),
            cost: 260,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.terracottaPotSkin,
            emoji: "▣",
            nameText: .init(zh: "赤陶盆皮肤", en: "Terracotta Pot Skin", de: "Terrakotta-Skin"),
            descriptionText: .init(
                zh: "给绿洲植物换成赤陶盆；只是装饰，不改变浇水周期。",
                en: "Switches Oasis plants to terracotta pots. Cosmetic only; watering cadence does not change.",
                de: "Terrakotta-Töpfe für Oasis-Pflanzen. Nur Deko; Gießrhythmen bleiben gleich."
            ),
            cost: 320,
            category: .plantDecor
        ),
        ShopItem(
            id: OasisPlantDecorID.glassTerrariumSkin,
            emoji: "◇",
            nameText: .init(zh: "玻璃生态瓶", en: "Glass Terrarium", de: "Glas-Terrarium"),
            descriptionText: .init(
                zh: "给绿洲摆上玻璃生态瓶；核心植物管理、资料库和提醒仍然免费。",
                en: "Adds glass terrariums to the Oasis. Core plant management, catalog, and reminders remain free.",
                de: "Glas-Terrarien für Oasis. Pflanzenverwaltung, Katalog und Erinnerungen bleiben kostenlos."
            ),
            cost: 460,
            category: .plantDecor
        )
    ]

    private static let titleItems: [ShopItem] = [
        ShopItem(id: "title_guardian", emoji: "🛡️", nameText: .init(zh: "守护者", en: "Guardian", de: "Beschützer"), descriptionText: .init(zh: "称号 · 显示在首页头像旁。", en: "Title shown near your Home avatar.", de: "Titel neben deinem Startseiten-Avatar."), cost: 500, category: .title_),
        ShopItem(id: "title_pioneer", emoji: "🚀", nameText: .init(zh: "先行者", en: "Pioneer", de: "Pionier"), descriptionText: .init(zh: "称号 · 解锁岛屿探索徽章。", en: "Title for island exploration energy.", de: "Titel für Insel-Erkundung."), cost: 650, category: .title_),
        ShopItem(id: "title_chef", emoji: "👨‍🍳", nameText: .init(zh: "首席厨师", en: "Head Chef", de: "Chefkoch"), descriptionText: .init(zh: "称号 · 显示你的喂养担当身份。", en: "Title · shows your feeding lead role.", de: "Titel · zeigt deine Fütterungsrolle."), cost: 900, category: .title_)
    ]

    private static let boostItems: [ShopItem] = [
        ShopItem(id: "boost_double", emoji: "⚡️", nameText: .init(zh: "金色幸运券", en: "Golden Luck", de: "Goldenes Glück"), descriptionText: .init(zh: "下次普通照护触发金色幸运，受每日预算控制。", en: "Turns the next regular care reward into Golden Luck, within the daily budget.", de: "Macht die nächste normale Pflege zu goldenem Glück, im Tagesbudget."), cost: 20, category: .boost, isConsumable: true),
        ShopItem(id: "boost_streak", emoji: "🛡️", nameText: .init(zh: "Streak 保护盾", en: "Streak Shield", de: "Streak-Schild"), descriptionText: .init(zh: "48 小时内漏签 1 天也不断连胜。", en: "Protects one missed day within 48 hours.", de: "Schützt einen verpassten Tag innerhalb von 48 Stunden."), cost: 180, category: .boost, isConsumable: true)
    ]
}

import Foundation
import SwiftUI

nonisolated struct AppIconShopDescriptor: Identifiable, Equatable {
    let itemId: String
    let alternateIconName: String?
    let previewSymbol: String
    let gradientHex: [String]

    var id: String { itemId }
    var isDefault: Bool { alternateIconName == nil }
}

struct ShopItem: Identifiable, Equatable {
    enum ShopCategory: String, CaseIterable, Identifiable {
        case appIcon
        case avatar2d
        case cashExchange
        case effect
        case title_
        case boost

        var id: String { rawValue }

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
}

nonisolated enum AppIconCatalog {
    static let selectedIconKey = "shop_selected_app_icon"
    static let defaultItemId = "appicon_default"

    static let icons: [AppIconShopDescriptor] = [
        AppIconShopDescriptor(
            itemId: defaultItemId,
            alternateIconName: nil,
            previewSymbol: "o.circle.fill",
            gradientHex: ["C8FF00", "3B82F6", "1A1A2E"]
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
        )
    ]

    static func descriptor(forItemId id: String) -> AppIconShopDescriptor? {
        icons.first { $0.itemId == id }
    }

    static func descriptor(forAlternateIconName name: String?) -> AppIconShopDescriptor {
        icons.first { $0.alternateIconName == name } ?? icons[0]
    }
}

enum ShopCatalog {
    static func allItems(purchasedSet: Set<String> = []) -> [ShopItem] {
        rawItems.map { item in
            var copy = item
            if item.appIcon?.isDefault == true {
                copy.isPurchased = true
            } else if !item.isConsumable {
                copy.isPurchased = purchasedSet.contains(item.id)
            }
            return copy
        }
    }

    static func item(id: String, purchasedSet: Set<String> = []) -> ShopItem? {
        allItems(purchasedSet: purchasedSet).first { $0.id == id }
    }

    private static let rawItems: [ShopItem] = appIconItems + avatarItems + effectItems + titleItems + boostItems

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
        )
    ]

    private static let avatarItems: [ShopItem] = [
        ShopItem(
            id: Avatar2DAccess.shopItemId,
            emoji: "🖼️",
            nameText: .init(zh: "2.5D 头像券", en: "2.5D Avatar Pass", de: "2,5D-Avatarpass"),
            descriptionText: .init(zh: "购买后指定 1 位人类或宠物升级 2.5D 头像。", en: "Upgrade one human or pet to a 2.5D avatar.", de: "Wertet einen Menschen oder ein Tier auf einen 2,5D-Avatar auf."),
            cost: 1500,
            category: .avatar2d,
            isConsumable: true
        )
    ]

    private static let effectItems: [ShopItem] = [
        ShopItem(id: "fx_popout_card", emoji: "🃏", nameText: .init(zh: "3D 破框卡片", en: "3D Popout Card", de: "3D-Popout-Karte"), descriptionText: .init(zh: "宠物主体从卡片破框悬浮而出，需配合透明抠图使用。", en: "Let a pet pop out from its card when cutout assets are available.", de: "Lässt ein Tier aus der Karte hervortreten, wenn Freisteller verfügbar sind."), cost: 800, category: .effect),
        ShopItem(id: "fx_lime_glow", emoji: "💚", nameText: .init(zh: "青柠光晕", en: "Lime Glow", de: "Lime-Leuchten"), descriptionText: .init(zh: "打卡时宠物卡片发出青柠光芒特效。", en: "Adds a lime glow to pet check-ins.", de: "Fügt Check-ins ein Lime-Leuchten hinzu."), cost: 300, category: .effect),
        ShopItem(id: "fx_rainbow", emoji: "🌈", nameText: .init(zh: "彩虹轨迹", en: "Rainbow Trail", de: "Regenbogenroute"), descriptionText: .init(zh: "遛狗路线地图显示彩虹轨迹风格。", en: "Shows dog-walk routes with a rainbow trail.", de: "Zeigt Spaziergänge als Regenbogenroute."), cost: 650, category: .effect),
        ShopItem(id: "fx_rainbow_poop", emoji: "💩", nameText: .init(zh: "彩虹便便", en: "Rainbow Poop", de: "Regenbogenkot"), descriptionText: .init(zh: "遛狗便便标记显示流动彩虹光圈。", en: "Adds a flowing rainbow ring to walk poop markers.", de: "Fügt Gassi-Kotmarkierungen einen fließenden Regenbogenring hinzu."), cost: 420, category: .effect),
        ShopItem(id: "fx_stars", emoji: "⭐️", nameText: .init(zh: "星尘落雨", en: "Stardust", de: "Sternenstaub"), descriptionText: .init(zh: "完成每日委托时触发星尘粒子特效。", en: "Adds stardust particles to daily quest completions.", de: "Fügt Tagesaufgaben Sternenstaub-Partikel hinzu."), cost: 350, category: .effect),
        ShopItem(id: "fx_firework", emoji: "🎆", nameText: .init(zh: "烟花庆典", en: "Firework", de: "Feuerwerk"), descriptionText: .init(zh: "达成里程碑时升级烟花动画。", en: "Upgrades milestone celebrations with fireworks.", de: "Erweitert Meilensteinfeiern mit Feuerwerk."), cost: 720, category: .effect)
    ]

    private static let titleItems: [ShopItem] = [
        ShopItem(id: "title_guardian", emoji: "🛡️", nameText: .init(zh: "守护者", en: "Guardian", de: "Beschützer"), descriptionText: .init(zh: "称号 · 显示在首页头像旁。", en: "Title shown near your Home avatar.", de: "Titel neben deinem Startseiten-Avatar."), cost: 500, category: .title_),
        ShopItem(id: "title_pioneer", emoji: "🚀", nameText: .init(zh: "先行者", en: "Pioneer", de: "Pionier"), descriptionText: .init(zh: "称号 · 解锁岛屿探索徽章。", en: "Title for island exploration energy.", de: "Titel für Insel-Erkundung."), cost: 650, category: .title_),
        ShopItem(id: "title_chef", emoji: "👨‍🍳", nameText: .init(zh: "首席厨师", en: "Head Chef", de: "Chefkoch"), descriptionText: .init(zh: "称号 · 显示你的喂养担当身份。", en: "Title · shows your feeding lead role.", de: "Titel · zeigt deine Fütterungsrolle."), cost: 900, category: .title_)
    ]

    private static let boostItems: [ShopItem] = [
        ShopItem(id: "boost_double", emoji: "⚡️", nameText: .init(zh: "金色幸运券", en: "Golden Luck", de: "Goldenes Glück"), descriptionText: .init(zh: "下次普通照护触发金色幸运，受每日预算控制。", en: "Turns the next regular care reward into Golden Luck, within the daily budget.", de: "Macht die nächste normale Pflege zu goldenem Glück, im Tagesbudget."), cost: 220, category: .boost, isConsumable: true),
        ShopItem(id: "boost_streak", emoji: "🛡️", nameText: .init(zh: "Streak 保护盾", en: "Streak Shield", de: "Streak-Schild"), descriptionText: .init(zh: "48 小时内漏签 1 天也不断连胜。", en: "Protects one missed day within 48 hours.", de: "Schützt einen verpassten Tag innerhalb von 48 Stunden."), cost: 260, category: .boost, isConsumable: true),
        ShopItem(id: "boost_tree", emoji: "🌱", nameText: .init(zh: "每日树能量 +20XP", en: "Daily Tree XP +20", de: "Tägliche Baum-XP +20"), descriptionText: .init(zh: "每天 1 次，为生命之树轻度加速。", en: "Once per day, gently speeds up Life Tree growth.", de: "Einmal täglich, beschleunigt den Lebensbaum leicht."), cost: 80, category: .boost, isConsumable: true),
        ShopItem(id: "boost_tree_large", emoji: "🌳", nameText: .init(zh: "周树能量 +60XP", en: "Weekly Tree XP +60", de: "Wöchentliche Baum-XP +60"), descriptionText: .init(zh: "Lv.5 后每周 1 次，不能买穿核心功能。", en: "Once per week after Lv.5; cannot skip the core progression.", de: "Ab Lv.5 einmal pro Woche; überspringt keine Kernprogression."), cost: 220, category: .boost, isConsumable: true),
        ShopItem(id: "boost_backdate_single", emoji: "📅", nameText: .init(zh: "补签券 ×1", en: "Backdate Pass ×1", de: "Nachtragspass ×1"), descriptionText: .init(zh: "获得 1 张昨日补签券，放入百宝箱。", en: "Adds one yesterday backdate pass.", de: "Fügt einen Nachtragspass für gestern hinzu."), cost: 150, category: .boost, isConsumable: true),
        ShopItem(id: "boost_backdate_pack", emoji: "🗓️", nameText: .init(zh: "补签券 ×3", en: "Backdate Pass ×3", de: "Nachtragspass ×3"), descriptionText: .init(zh: "获得 3 张昨日补签券，适合连续补签。", en: "Adds three backdate passes.", de: "Fügt drei Nachtragspässe hinzu."), cost: 350, category: .boost, isConsumable: true)
    ]
}

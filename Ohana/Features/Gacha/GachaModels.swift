//
//  GachaModels.swift
//  Ohana
//
//  Series-based blind box gacha. Catalog entries stay static so future avatar
//  art can be added without migrating user collections.
//

import Foundation
import SwiftData

enum GachaRarity: String, Codable, CaseIterable, Identifiable {
    case common
    case rare
    case superRare
    case hidden

    var id: String { rawValue }

    func name(_ l: L10n) -> String {
        switch self {
        case .common:
            l.tr(zh: "普通", en: "Common", de: "Normal")
        case .rare:
            l.tr(zh: "稀有", en: "Rare", de: "Selten")
        case .superRare:
            l.tr(zh: "超稀有", en: "Super Rare", de: "Superselten")
        case .hidden:
            l.tr(zh: "隐藏款", en: "Secret", de: "Geheim")
        }
    }
}

enum GachaOutcomeKind: String, Codable, CaseIterable, Identifiable {
    case collectible
    case instantReward
    case message

    var id: String { rawValue }

    func name(_ l: L10n) -> String {
        switch self {
        case .collectible:
            l.tr(zh: "盲盒款", en: "Collectible", de: "Sammelfigur")
        case .instantReward:
            l.tr(zh: "小奖励", en: "Tiny reward", de: "Kleine Belohnung")
        case .message:
            l.tr(zh: "祝福", en: "Blessing", de: "Segen")
        }
    }
}

struct GachaSeriesEntry: Identifiable, Equatable {
    let id: String
    let name: AppLocalizedText
    let subtitle: AppLocalizedText
    let items: [GachaItemEntry]
    let instantResults: [GachaInstantResultEntry]

    func localizedName(_ l: L10n) -> String { l.text(name) }
    func localizedSubtitle(_ l: L10n) -> String { l.text(subtitle) }

    nonisolated var probabilityTotalBasisPoints: Int {
        collectibleProbabilityBasisPoints + instantResultProbabilityBasisPoints
    }

    nonisolated var hiddenItem: GachaItemEntry? {
        items.first(where: \.isHidden)
    }

    nonisolated var commonItems: [GachaItemEntry] {
        items.filter { $0.rarity == .common && !$0.isHidden }
    }

    nonisolated var collectibleProbabilityBasisPoints: Int {
        items.reduce(0) { $0 + $1.probabilityBasisPoints }
    }

    nonisolated var commonProbabilityBasisPoints: Int {
        commonItems.reduce(0) { $0 + $1.probabilityBasisPoints }
    }

    nonisolated var hiddenProbabilityBasisPoints: Int {
        items.filter(\.isHidden).reduce(0) { $0 + $1.probabilityBasisPoints }
    }

    nonisolated var instantResultProbabilityBasisPoints: Int {
        instantResults.reduce(0) { $0 + $1.probabilityBasisPoints }
    }
}

struct GachaItemEntry: Identifiable, Equatable {
    let id: String
    let seriesId: String
    let name: AppLocalizedText
    let rarity: GachaRarity
    let probabilityBasisPoints: Int
    let placeholderSymbol: String
    let imageAssetName: String
    let silhouetteAssetName: String
    let boxAssetName: String
    let motto: AppLocalizedText
    let personality: AppLocalizedText
    let isHidden: Bool

    func localizedName(_ l: L10n) -> String { l.text(name) }
    func localizedMotto(_ l: L10n) -> String { l.text(motto) }
    func localizedPersonality(_ l: L10n) -> String { l.text(personality) }

    var probabilityPercentText: String {
        let value = Double(probabilityBasisPoints) / 100.0
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return String(format: "%.1f%%", value)
    }
}

struct GachaInstantResultEntry: Identifiable, Equatable {
    let id: String
    let kind: GachaOutcomeKind
    let title: AppLocalizedText
    let detail: AppLocalizedText
    let probabilityBasisPoints: Int
    let symbol: String
    let coconutDelta: Int

    func localizedTitle(_ l: L10n) -> String { l.text(title) }
    func localizedDetail(_ l: L10n) -> String { l.text(detail) }
}

nonisolated enum GachaSeriesCatalog {
    static let totalBasisPoints = 10000
    static let hiddenBasisPoints = 200
    static let commonBasisPoints = 2000
    static let coconutGrandBundleBasisPoints = 500
    static let otherBasisPoints = 7800
    static let coconutGrandBundleResultId = "coconut_grand_bundle_500"
    static let defaultSeriesId = "plush_coconut_squad_v1"
    static let noirSeriesId = "midnight_atelier_v1"

    static let allSeries: [GachaSeriesEntry] = [
        GachaSeriesEntry(
            id: defaultSeriesId,
            name: AppLocalizedText(
                zh: "Nana Ohana 海岛盲盒",
                en: "Nana Ohana Island Plush",
                de: "Nana Ohana Inselplüsch"
            ),
            subtitle: AppLocalizedText(
                zh: "8 个基本款 + 1 个隐藏款；更多时候会收到小奖励或一句话",
                en: "8 regulars + 1 secret; most openings bring a tiny reward or note",
                de: "8 normale + 1 geheime Figur; meistens gibt es eine kleine Belohnung oder Notiz"
            ),
            items: [
                item("plush_coconut_sleepy", "Nana Coconut Nap", "Nana Coconut Nap", "Nana Kokos-Schlaf", .common, 250, "🌙", "GachaNanaCoconutNap"),
                item("plush_coconut_sunny", "Nana Tidal Shell", "Nana Tidal Shell", "Nana Gezeiten-Muschel", .common, 250, "🐚", "GachaNanaTidalShell"),
                item("plush_coconut_leaf", "Nana Hibiscus Hug", "Nana Hibiscus Hug", "Nana Hibiskus-Umarmung", .common, 250, "🌺", "GachaNanaHibiscusHug"),
                item("plush_coconut_milk", "Nana Starry Tide", "Nana Starry Tide", "Nana Sternenflut", .common, 250, "⭐️", "GachaNanaStarryTide"),
                item("plush_coconut_star", "Nana Palm Sprout", "Nana Palm Sprout", "Nana Palmenspross", .common, 250, "🌱", "GachaNanaPalmSprout"),
                item("plush_coconut_blush", "Nana Toasty Cocoa", "Nana Toasty Cocoa", "Nana Kakao-Wärme", .common, 250, "☕️", "GachaNanaToastyCocoa"),
                item("plush_coconut_cloud", "Nana Rain Puddle", "Nana Rain Puddle", "Nana Regenpfütze", .common, 250, "🌧️", "GachaNanaRainPuddle"),
                item("plush_coconut_moss", "Nana Lime Spark", "Nana Lime Spark", "Nana Limettenfunke", .common, 250, "⚡️", "GachaNanaLimeSpark"),
                item("plush_coconut_secret", "Nana Ohana Glow", "Nana Ohana Glow", "Nana Ohana-Glanz", .hidden, 200, "✨", "GachaNanaOhanaGlow", isHidden: true)
            ],
            instantResults: [
                instant("coconut_echo_5", .instantReward, "椰子回声", "Coconut Echo", "Kokos-Echo", "椰壳里滚出 5 颗椰子。", "5 coconuts rolled out of the shell.", "5 Kokosnüsse kullern aus der Schale.", 1000, "🥥", coconutDelta: 5),
                instant("coconut_echo_8", .instantReward, "椰奶返礼", "Coconut Milk Treat", "Kokosmilch-Gruß", "nana 偷偷塞回 8 颗椰子。", "nana quietly returns 8 coconuts.", "nana gibt heimlich 8 Kokosnüsse zurück.", 900, "🥥", coconutDelta: 8),
                instant("lucky_leaf_10", .instantReward, "幸运叶片", "Lucky Leaf", "Glücksblatt", "叶片亮了一下，返还 10 颗椰子。", "A leaf glows and returns 10 coconuts.", "Ein Blatt leuchtet und gibt 10 Kokosnüsse zurück.", 900, "🍃", coconutDelta: 10),
                instant(coconutGrandBundleResultId, .instantReward, "椰子大礼包", "Coconut Grand Bundle", "Großes Kokospaket", "哗啦啦，500 颗椰子从盒子里掉下来！", "A grand bundle drops 500 coconuts from the box!", "Ein großes Paket lässt 500 Kokosnüsse herausfallen!", coconutGrandBundleBasisPoints, "🎁", coconutDelta: 500),
                instant("message_soft_paw", .message, "软爪留言", "Soft Paw Note", "Weiche-Pfote-Notiz", "今天也被好好照顾了，辛苦啦。", "Someone is cared for today. Nice work.", "Heute wurde jemand gut umsorgt. Gut gemacht.", 1200, "💌"),
                instant("message_coconut_oracle", .message, "椰壳占卜", "Coconut Oracle", "Kokos-Orakel", "椰壳说：再敲一次之前先喝口水。", "The shell says: sip water before the next crack.", "Die Schale sagt: vor dem nächsten Öffnen Wasser trinken.", 1200, "🔮"),
                instant("message_nana_wink", .message, "nana 眨眼", "nana Wink", "nana zwinkert", "nana 眨了一下眼：好运已经在排队。", "nana winks: luck is already lining up.", "nana zwinkert: Das Glück steht schon an.", 1050, "✨"),
                instant("message_ohana_breeze", .message, "Ohana 微风", "Ohana Breeze", "Ohana-Brise", "一阵海风路过，把家里的疲惫吹轻了一点。", "A sea breeze passes and lightens the day.", "Eine Meeresbrise macht den Tag leichter.", 1050, "🌴")
            ]
        ),
        GachaSeriesEntry(
            id: noirSeriesId,
            name: AppLocalizedText(
                zh: "Midnight Atelier 夜潮盲盒",
                en: "Midnight Atelier Blind Box",
                de: "Midnight Atelier Blindbox"
            ),
            subtitle: AppLocalizedText(
                zh: "暗黑时装收藏系列；集齐 Nana 8 个普通款后解锁",
                en: "A noir couture collectible series; unlocks after all 8 Nana regulars",
                de: "Eine Noir-Couture-Sammelserie; frei nach allen 8 normalen Nana-Figuren"
            ),
            items: [
                item("noir_moon_rain", "Moon Rain Oracle", "Moon Rain Oracle", "Moon Rain Oracle", .common, 250, "☂️", "GachaNoirMoonRain", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_pearl_diver", "Pearl Diver Muse", "Pearl Diver Muse", "Pearl Diver Muse", .common, 250, "⚪️", "GachaNoirPearlDiver", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_velvet_comet", "Velvet Comet", "Velvet Comet", "Velvet Comet", .common, 250, "☄️", "GachaNoirVelvetComet", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_glass_umbrella", "Glass Umbrella Page", "Glass Umbrella Page", "Glass Umbrella Page", .common, 250, "🌂", "GachaNoirGlassUmbrella", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_tide_courier", "Tide Courier", "Tide Courier", "Tide Courier", .common, 250, "✉️", "GachaNoirTideCourier", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_shell_beret", "Shell Beret", "Shell Beret", "Shell Beret", .common, 250, "🪩", "GachaNoirShellBeret", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_neon_jelly", "Neon Jelly Veil", "Neon Jelly Veil", "Neon Jelly Veil", .common, 250, "🫧", "GachaNoirNeonJelly", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_lullaby_cloak", "Lullaby Cloak", "Lullaby Cloak", "Lullaby Cloak", .common, 250, "🌙", "GachaNoirLullabyCloak", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox"),
                item("noir_eclipse_secret", "Eclipse Regent", "Eclipse Regent", "Eclipse Regent", .hidden, 200, "🌘", "GachaNoirEclipseSecret", seriesId: noirSeriesId, boxAssetName: "GachaNoirAtelierBlindBox", isHidden: true)
            ],
            instantResults: [
                instant("noir_pearl_return_5", .instantReward, "珍珠回声", "Pearl Echo", "Perlen-Echo", "盒底滚出 5 颗椰子。", "5 coconuts roll out from the box.", "5 Kokosnüsse rollen aus der Box.", 1000, "🥥", coconutDelta: 5),
                instant("noir_ribbon_return_8", .instantReward, "黑缎返礼", "Satin Return", "Satin-Gruß", "缎带一抖，返还 8 颗椰子。", "A satin ribbon flicks back 8 coconuts.", "Ein Satinband gibt 8 Kokosnüsse zurück.", 900, "🥥", coconutDelta: 8),
                instant("noir_moon_return_10", .instantReward, "月相折扣", "Moon Phase Refund", "Mondphasen-Erstattung", "月相扣轻轻亮起，返还 10 颗椰子。", "The moon clasp glows and returns 10 coconuts.", "Die Mondspange leuchtet und gibt 10 Kokosnüsse zurück.", 900, "🌙", coconutDelta: 10),
                instant(coconutGrandBundleResultId, .instantReward, "椰子大礼包", "Coconut Grand Bundle", "Großes Kokospaket", "黑盒突然打开，500 颗椰子落下来！", "The noir box bursts open with 500 coconuts!", "Die Noir-Box öffnet sich mit 500 Kokosnüssen!", coconutGrandBundleBasisPoints, "🎁", coconutDelta: 500),
                instant("noir_message_after_rain", .message, "雨后便签", "After-Rain Note", "Nach-dem-Regen-Notiz", "雨会停，衣角的光会留下。", "Rain passes; the little shine stays.", "Regen vergeht; der kleine Glanz bleibt.", 1200, "💌"),
                instant("noir_message_velvet", .message, "丝绒低语", "Velvet Whisper", "Samtflüstern", "今天也可以低调地漂亮。", "Today can be quietly beautiful.", "Heute darf still schön sein.", 1200, "✦"),
                instant("noir_message_oracle", .message, "夜潮预言", "Night Tide Oracle", "Nachttide-Orakel", "下一次惊喜，正在慢慢靠近。", "The next surprise is drifting closer.", "Die nächste Überraschung treibt näher.", 1050, "🔮"),
                instant("noir_message_ohana", .message, "Ohana 银线", "Ohana Silver Thread", "Ohana-Silberfaden", "有些连接安静，却从不松开。", "Some bonds are quiet and never loosen.", "Manche Bande sind leise und lösen sich nie.", 1050, "○")
            ]
        )
    ]

    static func series(id: String) -> GachaSeriesEntry {
        allSeries.first(where: { $0.id == id }) ?? allSeries[0]
    }

    static func item(seriesId: String, itemId: String) -> GachaItemEntry? {
        series(id: seriesId).items.first { $0.id == itemId }
    }

    static func validateProbabilities() -> Bool {
        allSeries.allSatisfy { series in
            series.probabilityTotalBasisPoints == totalBasisPoints &&
                series.commonItems.count == 8 &&
                series.items.filter(\.isHidden).count == 1 &&
                series.commonProbabilityBasisPoints == commonBasisPoints &&
                series.hiddenProbabilityBasisPoints == hiddenBasisPoints &&
                series.instantResults.filter { $0.id == coconutGrandBundleResultId }.reduce(0) { $0 + $1.probabilityBasisPoints } == coconutGrandBundleBasisPoints &&
                series.instantResultProbabilityBasisPoints == otherBasisPoints
        }
    }

    static func validateStaticAssets() -> Bool {
        allSeries.allSatisfy { series in
            series.items.allSatisfy { item in
                !item.imageAssetName.isEmpty &&
                    !item.silhouetteAssetName.isEmpty &&
                    !item.boxAssetName.isEmpty
            }
        }
    }

    private static func item(
        _ id: String,
        _ zh: String,
        _ en: String,
        _ de: String,
        _ rarity: GachaRarity,
        _ probabilityBasisPoints: Int,
        _ placeholderSymbol: String,
        _ imageAssetName: String,
        seriesId: String = defaultSeriesId,
        boxAssetName: String = "GachaNanaBlindBox",
        isHidden: Bool = false
    ) -> GachaItemEntry {
        let profile = itemProfile(id)
        return GachaItemEntry(
            id: id,
            seriesId: seriesId,
            name: AppLocalizedText(zh: zh, en: en, de: de),
            rarity: rarity,
            probabilityBasisPoints: probabilityBasisPoints,
            placeholderSymbol: placeholderSymbol,
            imageAssetName: imageAssetName,
            silhouetteAssetName: "\(imageAssetName)Silhouette",
            boxAssetName: boxAssetName,
            motto: profile.motto,
            personality: profile.personality,
            isHidden: isHidden
        )
    }

    private static func itemProfile(_ id: String) -> (motto: AppLocalizedText, personality: AppLocalizedText) {
        switch id {
        case "plush_coconut_sleepy":
            (
                AppLocalizedText(zh: "慢一点，梦会自己发芽。", en: "Go slow. Dreams sprout on their own.", de: "Langsam. Träume keimen von selbst."),
                AppLocalizedText(zh: "慵懒、会把安静变成小窝。", en: "Sleepy, soft, and good at turning quiet into a nest.", de: "Schläfrig, weich und macht aus Ruhe ein Nest.")
            )
        case "plush_coconut_sunny":
            (
                AppLocalizedText(zh: "潮水会退，勇气会留下。", en: "The tide goes out. Courage stays.", de: "Die Flut geht. Mut bleibt."),
                AppLocalizedText(zh: "清爽、爱收集贝壳和新的开始。", en: "Breezy, curious, and always collecting fresh starts.", de: "Frisch, neugierig und sammelt neue Anfänge.")
            )
        case "plush_coconut_leaf":
            (
                AppLocalizedText(zh: "拥抱之前，先给世界一朵花。", en: "Offer the world a flower before the hug.", de: "Schenk der Welt eine Blume vor der Umarmung."),
                AppLocalizedText(zh: "热情、亲近人，喜欢把疲惫揉软。", en: "Warm, affectionate, and softens tired days.", de: "Warm, anhänglich und macht müde Tage weich.")
            )
        case "plush_coconut_milk":
            (
                AppLocalizedText(zh: "星星不催你，它只陪你亮。", en: "Stars do not rush you. They just glow with you.", de: "Sterne drängen nicht. Sie leuchten mit dir."),
                AppLocalizedText(zh: "安静、浪漫，适合夜晚陪伴。", en: "Quiet, dreamy, and made for night companionship.", de: "Ruhig, verträumt und für Nachtbegleitung gemacht.")
            )
        case "plush_coconut_star":
            (
                AppLocalizedText(zh: "今天的小芽，明天会很厉害。", en: "Today's tiny sprout gets mighty tomorrow.", de: "Der kleine Spross von heute wird morgen stark."),
                AppLocalizedText(zh: "乐观、行动快，总想第一个冒头。", en: "Optimistic, quick, and always first to pop up.", de: "Optimistisch, flink und immer als Erstes da.")
            )
        case "plush_coconut_blush":
            (
                AppLocalizedText(zh: "暖一点，坏天气也会坐下来。", en: "Add warmth, and bad weather sits down.", de: "Mit Wärme setzt sich schlechtes Wetter hin."),
                AppLocalizedText(zh: "温暖、护短，像一杯小小热可可。", en: "Protective, cozy, and a little cup of cocoa energy.", de: "Beschützend, gemütlich und wie eine kleine Tasse Kakao.")
            )
        case "plush_coconut_cloud":
            (
                AppLocalizedText(zh: "水坑里也可以有天空。", en: "Even a puddle can hold the sky.", de: "Auch eine Pfütze kann Himmel tragen."),
                AppLocalizedText(zh: "敏感、会观察，擅长发现小惊喜。", en: "Sensitive, observant, and great at spotting tiny wonders.", de: "Feinfühlig, aufmerksam und findet kleine Wunder.")
            )
        case "plush_coconut_moss":
            (
                AppLocalizedText(zh: "亮一下，就算赢。", en: "One spark counts as a win.", de: "Ein Funke zählt als Sieg."),
                AppLocalizedText(zh: "俏皮、反应快，像一颗会眨眼的青柠火花。", en: "Playful, quick, and bright like a winking lime spark.", de: "Verspielt, schnell und hell wie ein zwinkernder Limettenfunke.")
            )
        case "plush_coconut_secret":
            (
                AppLocalizedText(zh: "真正的光，会先藏起来。", en: "Real glow hides first.", de: "Echtes Leuchten versteckt sich zuerst."),
                AppLocalizedText(zh: "神秘、骄傲，只在信任时发光。", en: "Mysterious, proud, and glows only when it trusts you.", de: "Geheimnisvoll, stolz und leuchtet nur bei Vertrauen.")
            )
        case "noir_moon_rain":
            (
                AppLocalizedText(zh: "雨停之前，先把姿态站稳。", en: "Hold your poise before the rain stops.", de: "Halte Haltung, bevor der Regen endet."),
                AppLocalizedText(zh: "冷静、讲究，像夜雨里的小小预言家。", en: "Composed and precise, like a tiny oracle in night rain.", de: "Gefasst und genau, wie ein kleines Orakel im Nachtregen.")
            )
        case "noir_pearl_diver":
            (
                AppLocalizedText(zh: "越深的地方，越适合发亮。", en: "The deeper it gets, the better it glows.", de: "Je tiefer es wird, desto schöner leuchtet es."),
                AppLocalizedText(zh: "安静、勇敢，喜欢把秘密打磨成珍珠。", en: "Quiet and brave, polishing secrets into pearls.", de: "Still und mutig, poliert Geheimnisse zu Perlen.")
            )
        case "noir_velvet_comet":
            (
                AppLocalizedText(zh: "划过黑夜，也要有丝绒边。", en: "Cross the night with a velvet edge.", de: "Durchquere die Nacht mit Samtrand."),
                AppLocalizedText(zh: "骄傲、戏剧感强，出现时自带小型谢幕。", en: "Proud and theatrical, arriving with a tiny curtain call.", de: "Stolz und theatralisch, mit kleinem Schlussapplaus.")
            )
        case "noir_glass_umbrella":
            (
                AppLocalizedText(zh: "透明不是脆弱，是把光藏好。", en: "Transparency is not fragility. It is kept light.", de: "Transparenz ist keine Zerbrechlichkeit. Sie bewahrt Licht."),
                AppLocalizedText(zh: "敏锐、优雅，擅长在坏天气里保持漂亮。", en: "Sharp and elegant, staying beautiful in bad weather.", de: "Feinsinnig und elegant, bleibt bei schlechtem Wetter schön.")
            )
        case "noir_tide_courier":
            (
                AppLocalizedText(zh: "把没说出口的，也好好送达。", en: "Deliver what words could not say.", de: "Liefere auch, was Worte nicht sagen konnten."),
                AppLocalizedText(zh: "可靠、机灵，永远把小心意藏在内袋。", en: "Reliable and clever, hiding tiny care in an inner pocket.", de: "Verlässlich und klug, mit Fürsorge in der Innentasche.")
            )
        case "noir_shell_beret":
            (
                AppLocalizedText(zh: "优雅可以很小，但不能随便。", en: "Elegance can be tiny, never careless.", de: "Eleganz darf klein sein, aber nie nachlässig."),
                AppLocalizedText(zh: "挑剔、会搭配，喜欢把日常变成展柜。", en: "Selective and stylish, turning daily life into a showcase.", de: "Wählerisch und stilvoll, macht Alltag zur Vitrine.")
            )
        case "noir_neon_jelly":
            (
                AppLocalizedText(zh: "柔软地发光，也很厉害。", en: "Glowing softly is still powerful.", de: "Sanftes Leuchten ist auch stark."),
                AppLocalizedText(zh: "梦幻、慢热，熟悉后会冒出很多小灵感。", en: "Dreamy and slow to warm, full of tiny ideas once close.", de: "Verträumt und langsam warm, dann voller kleiner Ideen.")
            )
        case "noir_lullaby_cloak":
            (
                AppLocalizedText(zh: "困意也是一种高级的暂停。", en: "Sleepiness is a luxurious pause.", de: "Müdigkeit ist eine luxuriöse Pause."),
                AppLocalizedText(zh: "慵懒、会照顾气氛，像会走路的晚安。", en: "Sleepy and atmospheric, like a walking goodnight.", de: "Müde und stimmungsvoll, wie ein laufendes Gute Nacht.")
            )
        case "noir_eclipse_secret":
            (
                AppLocalizedText(zh: "不是所有王冠，都需要白天看见。", en: "Not every crown needs daylight.", de: "Nicht jede Krone braucht Tageslicht."),
                AppLocalizedText(zh: "神秘、克制，稀有到像一次黑金色的月食。", en: "Mysterious and restrained, rare as a black-gold eclipse.", de: "Geheimnisvoll und zurückhaltend, selten wie eine schwarzgoldene Finsternis.")
            )
        default:
            (
                AppLocalizedText(zh: "小小好运，也值得认真收下。", en: "Tiny luck is worth keeping.", de: "Kleines Glück darf bleiben."),
                AppLocalizedText(zh: "柔软、亲切，带一点海岛的小调皮。", en: "Soft, kind, with a little island mischief.", de: "Weich, freundlich und ein bisschen inselschelmisch.")
            )
        }
    }

    private static func instant(
        _ id: String,
        _ kind: GachaOutcomeKind,
        _ titleZh: String,
        _ titleEn: String,
        _ titleDe: String,
        _ detailZh: String,
        _ detailEn: String,
        _ detailDe: String,
        _ probabilityBasisPoints: Int,
        _ symbol: String,
        coconutDelta: Int = 0
    ) -> GachaInstantResultEntry {
        GachaInstantResultEntry(
            id: id,
            kind: kind,
            title: AppLocalizedText(zh: titleZh, en: titleEn, de: titleDe),
            detail: AppLocalizedText(zh: detailZh, en: detailEn, de: detailDe),
            probabilityBasisPoints: probabilityBasisPoints,
            symbol: symbol,
            coconutDelta: coconutDelta
        )
    }
}

@Model
final class GachaOwnedItem {
    #Index<GachaOwnedItem>([\.ownerHumanId], [\.seriesId], [\.itemId])

    var id: UUID = UUID()
    var ownerHumanId: String = ""
    var seriesId: String = ""
    var itemId: String = ""
    var rarityRaw: String = GachaRarity.common.rawValue
    var isHidden: Bool = false
    var ownedCount: Int = 0
    var firstObtainedAt: Date = Date()
    var latestObtainedAt: Date = Date()
    var createdAt: Date = Date()

    init(
        ownerHumanId: String = "",
        seriesId: String = "",
        itemId: String = "",
        rarity: GachaRarity = .common,
        isHidden: Bool = false,
        ownedCount: Int = 1,
        firstObtainedAt: Date = Date(),
        latestObtainedAt: Date = Date()
    ) {
        self.id = UUID()
        self.ownerHumanId = ownerHumanId
        self.seriesId = seriesId
        self.itemId = itemId
        self.rarityRaw = rarity.rawValue
        self.isHidden = isHidden
        self.ownedCount = ownedCount
        self.firstObtainedAt = firstObtainedAt
        self.latestObtainedAt = latestObtainedAt
        self.createdAt = Date()
    }

    var rarity: GachaRarity {
        GachaRarity(rawValue: rarityRaw) ?? .common
    }
}

@Model
final class GachaDrawLog {
    #Index<GachaDrawLog>([\.ownerHumanId], [\.seriesId], [\.drawDate])

    var id: UUID = UUID()
    var ownerHumanId: String = ""
    var ownerName: String = ""
    var seriesId: String = ""
    var itemId: String = ""
    var rarityRaw: String = GachaRarity.common.rawValue
    var isHidden: Bool = false
    var isNew: Bool = false
    var outcomeKindRaw: String = GachaOutcomeKind.collectible.rawValue
    var instantResultId: String = ""
    var instantTitleZh: String = ""
    var instantTitleEn: String = ""
    var instantTitleDe: String = ""
    var instantDetailZh: String = ""
    var instantDetailEn: String = ""
    var instantDetailDe: String = ""
    var instantSymbol: String = ""
    var instantCoconutDelta: Int = 0
    var costCoconuts: Int = 80
    var dailySequence: Int = 1
    var drawDate: Date = Date()
    var createdAt: Date = Date()

    init(
        ownerHumanId: String = "",
        ownerName: String = "",
        seriesId: String = "",
        itemId: String = "",
        rarity: GachaRarity = .common,
        isHidden: Bool = false,
        isNew: Bool = false,
        outcomeKind: GachaOutcomeKind = .collectible,
        instantResult: GachaInstantResultEntry? = nil,
        costCoconuts: Int = GachaDrawService.costPerDraw,
        dailySequence: Int = 1,
        drawDate: Date = Date()
    ) {
        self.id = UUID()
        self.ownerHumanId = ownerHumanId
        self.ownerName = ownerName
        self.seriesId = seriesId
        self.itemId = itemId
        self.rarityRaw = rarity.rawValue
        self.isHidden = isHidden
        self.isNew = isNew
        self.outcomeKindRaw = outcomeKind.rawValue
        self.instantResultId = instantResult?.id ?? ""
        self.instantTitleZh = instantResult?.title.translations["zh"] ?? ""
        self.instantTitleEn = instantResult?.title.translations["en"] ?? ""
        self.instantTitleDe = instantResult?.title.translations["de"] ?? ""
        self.instantDetailZh = instantResult?.detail.translations["zh"] ?? ""
        self.instantDetailEn = instantResult?.detail.translations["en"] ?? ""
        self.instantDetailDe = instantResult?.detail.translations["de"] ?? ""
        self.instantSymbol = instantResult?.symbol ?? ""
        self.instantCoconutDelta = instantResult?.coconutDelta ?? 0
        self.costCoconuts = costCoconuts
        self.dailySequence = dailySequence
        self.drawDate = drawDate
        self.createdAt = Date()
    }

    var rarity: GachaRarity {
        GachaRarity(rawValue: rarityRaw) ?? .common
    }

    var outcomeKind: GachaOutcomeKind {
        get { GachaOutcomeKind(rawValue: outcomeKindRaw) ?? .collectible }
        set { outcomeKindRaw = newValue.rawValue }
    }

    func instantTitle(_ l: L10n) -> String {
        l.tr(zh: instantTitleZh, en: instantTitleEn, de: instantTitleDe)
    }

    func instantDetail(_ l: L10n) -> String {
        l.tr(zh: instantDetailZh, en: instantDetailEn, de: instantDetailDe)
    }
}

enum GachaDrawError: Error, Equatable {
    case missingHuman
    case insufficientBalance(missing: Int)
    case invalidSeries
    case lockedSeries
}

struct GachaDrawOutcome {
    let item: GachaItemEntry?
    let instantResult: GachaInstantResultEntry?
    let ownedItem: GachaOwnedItem?
    let log: GachaDrawLog

    var outcomeKind: GachaOutcomeKind { log.outcomeKind }

    var displaySymbol: String {
        item?.placeholderSymbol ?? instantResult?.symbol ?? "✨"
    }
}

struct GachaRollResult: Equatable {
    let kind: GachaOutcomeKind
    let item: GachaItemEntry?
    let instantResult: GachaInstantResultEntry?
}

enum GachaDrawService {
    static let costPerDraw = 80

    static func dailyDrawCount(
        for humanId: String,
        in logs: [GachaDrawLog],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard !humanId.isEmpty else { return 0 }
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return logs.count(where: { log in
            log.ownerHumanId == humanId && log.drawDate >= start && log.drawDate < end
        })
    }

    @MainActor
    private static func dailyDrawLogs(
        for humanId: String,
        context: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [GachaDrawLog] {
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let ownerId = humanId
        let descriptor = FetchDescriptor<GachaDrawLog>(
            predicate: #Predicate<GachaDrawLog> { log in
                log.ownerHumanId == ownerId && log.drawDate >= start && log.drawDate < end
            }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[GachaDrawService] failed to fetch daily draw logs for humanId=\(ownerId): \(error.localizedDescription)",
                category: "Gacha"
            )
            return []
        }
    }

    @MainActor
    private static func ownedItems(for humanId: String, context: ModelContext) -> [GachaOwnedItem] {
        let ownerId = humanId
        let descriptor = FetchDescriptor<GachaOwnedItem>(
            predicate: #Predicate<GachaOwnedItem> { item in
                item.ownerHumanId == ownerId
            }
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            OhanaLog.warning(
                "[GachaDrawService] failed to fetch owned items for humanId=\(ownerId): \(error.localizedDescription)",
                category: "Gacha"
            )
            return []
        }
    }

    static func collectionProgress(
        humanId: String,
        seriesId: String,
        ownedItems: [GachaOwnedItem]
    ) -> (owned: Int, total: Int) {
        let series = GachaSeriesCatalog.series(id: seriesId)
        let ownedIds = Set(ownedItems
            .filter { $0.ownerHumanId == humanId && $0.seriesId == seriesId && $0.ownedCount > 0 }
            .map(\.itemId))
        return (ownedIds.count, series.items.count)
    }

    static func hasCompletedCommonCollection(
        humanId: String,
        series: GachaSeriesEntry,
        ownedItems: [GachaOwnedItem]
    ) -> Bool {
        let ownedIds = Set(ownedItems
            .filter { $0.ownerHumanId == humanId && $0.seriesId == series.id && $0.ownedCount > 0 }
            .map(\.itemId))
        return series.commonItems.allSatisfy { ownedIds.contains($0.id) }
    }

    static func isSeriesUnlocked(
        seriesId: String,
        humanId: String,
        ownedItems: [GachaOwnedItem]
    ) -> Bool {
        guard seriesId != GachaSeriesCatalog.defaultSeriesId else { return true }
        guard !humanId.isEmpty else { return false }
        let firstSeries = GachaSeriesCatalog.series(id: GachaSeriesCatalog.defaultSeriesId)
        return hasCompletedCommonCollection(humanId: humanId, series: firstSeries, ownedItems: ownedItems)
    }

    @MainActor
    static func draw(
        seriesId: String = GachaSeriesCatalog.defaultSeriesId,
        human: Human?,
        context: ModelContext,
        now: Date = Date(),
        forcedRoll: Int? = nil,
        wallet providedWallet: CoconutWalletManaging? = nil,
        careLedger providedCareLedger: CareLedgerRecording? = nil,
        projectionManager: QuestManager? = nil
    ) throws -> GachaDrawOutcome {
        let wallet: CoconutWalletManaging = providedWallet ?? SwiftDataCoconutWalletManager()
        let careLedger: CareLedgerRecording = providedCareLedger ?? CareLedgerService()
        guard let human else { throw GachaDrawError.missingHuman }
        let series = GachaSeriesCatalog.series(id: seriesId)
        guard series.probabilityTotalBasisPoints == GachaSeriesCatalog.totalBasisPoints else {
            throw GachaDrawError.invalidSeries
        }

        let logs = dailyDrawLogs(for: human.id.uuidString, context: context, now: now)
        let usedToday = dailyDrawCount(for: human.id.uuidString, in: logs, now: now)
        let humanBalance = CoconutWalletService.balance(for: human, context: context)
        guard humanBalance >= costPerDraw else {
            throw GachaDrawError.insufficientBalance(missing: costPerDraw - humanBalance)
        }

        let ownedItems = ownedItems(for: human.id.uuidString, context: context)
        guard isSeriesUnlocked(seriesId: series.id, humanId: human.id.uuidString, ownedItems: ownedItems) else {
            throw GachaDrawError.lockedSeries
        }
        let canDrawHidden = hasCompletedCommonCollection(
            humanId: human.id.uuidString,
            series: series,
            ownedItems: ownedItems
        )
        let rollResult = roll(in: series, forcedRoll: forcedRoll, allowsHidden: canDrawHidden)
        let item = rollResult.item
        var isNew = false
        var owned: GachaOwnedItem?
        if let item {
            let existing = ownedItems.first {
                $0.ownerHumanId == human.id.uuidString &&
                    $0.seriesId == series.id &&
                    $0.itemId == item.id
            }
            isNew = existing == nil
            if let existing {
                existing.ownedCount += 1
                existing.latestObtainedAt = now
                owned = existing
            } else {
                let created = GachaOwnedItem(
                    ownerHumanId: human.id.uuidString,
                    seriesId: series.id,
                    itemId: item.id,
                    rarity: item.rarity,
                    isHidden: item.isHidden,
                    ownedCount: 1,
                    firstObtainedAt: now,
                    latestObtainedAt: now
                )
                context.insert(created)
                owned = created
            }
        }

        let instantCoconutDelta = rollResult.instantResult?.coconutDelta ?? 0
        let log = GachaDrawLog(
            ownerHumanId: human.id.uuidString,
            ownerName: human.name,
            seriesId: series.id,
            itemId: item?.id ?? "",
            rarity: item?.rarity ?? .common,
            isHidden: item?.isHidden ?? false,
            isNew: isNew,
            outcomeKind: rollResult.kind,
            instantResult: rollResult.instantResult,
            costCoconuts: costPerDraw,
            dailySequence: usedToday + 1,
            drawDate: now
        )
        context.insert(log)

        let baseMetadata = "\"seriesId\":\"\(series.id)\",\"outcomeKind\":\"\(rollResult.kind.rawValue)\",\"itemId\":\"\(item?.id ?? "")\",\"instantResultId\":\"\(rollResult.instantResult?.id ?? "")\",\"instantCoconutDelta\":\(instantCoconutDelta),\"rarity\":\"\(item?.rarity.rawValue ?? "")\",\"hidden\":\(item?.isHidden ?? false)"

        let costLedger = careLedger.record(
            occurredAt: now,
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "gachaDrawCost",
            amountValue: Double(costPerDraw),
            amountUnit: "coconut",
            note: "Blind box cost · \(series.id)",
            source: .economy,
            sourceEventId: nil,
            sourceReminderId: nil,
            legacyModelName: "GachaDrawLog",
            legacyModelId: log.id.uuidString,
            coconutDelta: -costPerDraw,
            rewardLogId: nil,
            privacyFieldRaw: nil,
            metadataJSON: "{\(baseMetadata),\"ledgerPart\":\"cost\"}",
            context: context,
            save: false
        )
        var walletDeltas: [CoconutWalletDelta] = [
            .human(
                human,
                delta: -costPerDraw,
                entryKind: .spend,
                source: .gacha,
                title: "盲盒抽取",
                emoji: "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .system,
                subjectId: nil,
                sourceModelName: "GachaDrawLog",
                sourceModelId: log.id.uuidString,
                careLedgerEventId: costLedger.id.uuidString,
                metadataJSON: "{\(baseMetadata),\"ledgerPart\":\"cost\"}",
                transactionKey: "gacha:\(log.id.uuidString):cost"
            )
        ]
        if instantCoconutDelta > 0 {
            let instantLedger = careLedger.record(
                occurredAt: now,
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .system,
                subjectId: nil,
                eventKind: .coconut,
                actionType: "gachaInstantReward",
                amountValue: Double(instantCoconutDelta),
                amountUnit: "coconut",
                note: rollResult.instantResult?.id ?? "instantReward",
                source: .economy,
                sourceEventId: nil,
                sourceReminderId: nil,
                legacyModelName: "GachaDrawLog",
                legacyModelId: log.id.uuidString,
                coconutDelta: instantCoconutDelta,
                rewardLogId: nil,
                privacyFieldRaw: nil,
                metadataJSON: "{\(baseMetadata),\"ledgerPart\":\"instantReward\"}",
                context: context,
                save: false
            )
            walletDeltas.append(.human(
                human,
                delta: instantCoconutDelta,
                entryKind: .reward,
                source: .gacha,
                title: rollResult.instantResult?.title.translations["zh"] ?? "盲盒即时返还",
                emoji: rollResult.instantResult?.symbol ?? "🥥",
                actorId: human.id.uuidString,
                actorName: human.name,
                subjectKind: .system,
                subjectId: nil,
                sourceModelName: "GachaDrawLog",
                sourceModelId: log.id.uuidString,
                careLedgerEventId: instantLedger.id.uuidString,
                metadataJSON: "{\(baseMetadata),\"ledgerPart\":\"instantReward\"}",
                transactionKey: "gacha:\(log.id.uuidString):instantReward"
            ))
        }

        do {
            try wallet.apply(
                deltas: walletDeltas,
                context: context,
                save: false,
                postsRewardFeedback: true,
                updatesProjection: true,
                projectionManager: projectionManager
            )
            try context.save()
        } catch {
            context.rollback()
            wallet.refreshQuestProjection(context: context, manager: projectionManager)
            throw error
        }

        return GachaDrawOutcome(
            item: item,
            instantResult: rollResult.instantResult,
            ownedItem: owned,
            log: log
        )
    }

    static func roll(
        in series: GachaSeriesEntry,
        forcedRoll: Int? = nil,
        allowsHidden: Bool = true
    ) -> GachaRollResult {
        let rawRoll = forcedRoll ?? Int.random(in: 0 ..< GachaSeriesCatalog.totalBasisPoints)
        let roll = max(0, min(rawRoll, GachaSeriesCatalog.totalBasisPoints - 1))
        let hiddenLimit = series.hiddenProbabilityBasisPoints
        let commonLimit = hiddenLimit + series.commonProbabilityBasisPoints

        if roll < hiddenLimit {
            if allowsHidden, let hidden = series.hiddenItem {
                return GachaRollResult(kind: .collectible, item: hidden, instantResult: nil)
            }
            let instantRoll = forcedRoll == nil
                ? Int.random(in: 0 ..< max(1, series.instantResultProbabilityBasisPoints))
                : roll
            let result = instantResult(in: series, forcedRoll: instantRoll)
            return GachaRollResult(kind: result.kind, item: nil, instantResult: result)
        }

        if roll < commonLimit {
            return GachaRollResult(
                kind: .collectible,
                item: weightedCommonItem(in: series, roll: roll - hiddenLimit),
                instantResult: nil
            )
        }

        let result = instantResult(in: series, forcedRoll: roll - commonLimit)
        return GachaRollResult(kind: result.kind, item: nil, instantResult: result)
    }

    private static func weightedCommonItem(in series: GachaSeriesEntry, roll: Int) -> GachaItemEntry {
        var remaining = max(0, min(roll, max(0, series.commonProbabilityBasisPoints - 1)))
        for item in series.commonItems {
            remaining -= item.probabilityBasisPoints
            if remaining < 0 { return item }
        }
        return series.commonItems.last ?? series.items[0]
    }

    private static func instantResult(
        in series: GachaSeriesEntry,
        preferredKind: GachaOutcomeKind? = nil,
        forcedRoll: Int
    ) -> GachaInstantResultEntry {
        let candidates = preferredKind.map { kind in
            series.instantResults.filter { $0.kind == kind }
        } ?? series.instantResults
        let safeCandidates = candidates.isEmpty ? series.instantResults : candidates
        let total = max(1, safeCandidates.reduce(0) { $0 + $1.probabilityBasisPoints })
        var roll = max(0, forcedRoll) % total
        for result in safeCandidates {
            roll -= result.probabilityBasisPoints
            if roll < 0 { return result }
        }
        return safeCandidates.last!
    }
}

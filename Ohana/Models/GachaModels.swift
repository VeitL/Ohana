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
            return l.tr(zh: "普通", en: "Common", de: "Normal")
        case .rare:
            return l.tr(zh: "稀有", en: "Rare", de: "Selten")
        case .superRare:
            return l.tr(zh: "超稀有", en: "Super Rare", de: "Superselten")
        case .hidden:
            return l.tr(zh: "隐藏款", en: "Secret", de: "Geheim")
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
            return l.tr(zh: "盲盒款", en: "Collectible", de: "Sammelfigur")
        case .instantReward:
            return l.tr(zh: "小奖励", en: "Tiny reward", de: "Kleine Belohnung")
        case .message:
            return l.tr(zh: "祝福", en: "Blessing", de: "Segen")
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
    static let totalBasisPoints = 10_000
    static let hiddenBasisPoints = 500
    static let commonBasisPoints = 2_000
    static let otherBasisPoints = 7_500
    static let defaultSeriesId = "plush_coconut_squad_v1"

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
                item("plush_coconut_secret", "Nana Ohana Glow", "Nana Ohana Glow", "Nana Ohana-Glanz", .hidden, 500, "✨", "GachaNanaOhanaGlow", isHidden: true)
            ],
            instantResults: [
                instant("coconut_echo_5", .instantReward, "椰子回声", "Coconut Echo", "Kokos-Echo", "椰壳里滚出 5 颗椰子。", "5 coconuts rolled out of the shell.", "5 Kokosnüsse kullern aus der Schale.", 1_000, "🥥", coconutDelta: 5),
                instant("coconut_echo_8", .instantReward, "椰奶返礼", "Coconut Milk Treat", "Kokosmilch-Gruß", "nana 偷偷塞回 8 颗椰子。", "nana quietly returns 8 coconuts.", "nana gibt heimlich 8 Kokosnüsse zurück.", 900, "🥥", coconutDelta: 8),
                instant("lucky_leaf_10", .instantReward, "幸运叶片", "Lucky Leaf", "Glücksblatt", "叶片亮了一下，返还 10 颗椰子。", "A leaf glows and returns 10 coconuts.", "Ein Blatt leuchtet und gibt 10 Kokosnüsse zurück.", 900, "🍃", coconutDelta: 10),
                instant("message_soft_paw", .message, "软爪留言", "Soft Paw Note", "Weiche-Pfote-Notiz", "今天也被好好照顾了，辛苦啦。", "Someone is cared for today. Nice work.", "Heute wurde jemand gut umsorgt. Gut gemacht.", 1_200, "💌"),
                instant("message_coconut_oracle", .message, "椰壳占卜", "Coconut Oracle", "Kokos-Orakel", "椰壳说：再敲一次之前先喝口水。", "The shell says: sip water before the next crack.", "Die Schale sagt: vor dem nächsten Öffnen Wasser trinken.", 1_200, "🔮"),
                instant("message_nana_wink", .message, "nana 眨眼", "nana Wink", "nana zwinkert", "nana 眨了一下眼：好运已经在排队。", "nana winks: luck is already lining up.", "nana zwinkert: Das Glück steht schon an.", 1_150, "✨"),
                instant("message_ohana_breeze", .message, "Ohana 微风", "Ohana Breeze", "Ohana-Brise", "一阵海风路过，把家里的疲惫吹轻了一点。", "A sea breeze passes and lightens the day.", "Eine Meeresbrise macht den Tag leichter.", 1_150, "🌴")
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
        isHidden: Bool = false
    ) -> GachaItemEntry {
        let profile = itemProfile(id)
        return GachaItemEntry(
            id: id,
            seriesId: defaultSeriesId,
            name: AppLocalizedText(zh: zh, en: en, de: de),
            rarity: rarity,
            probabilityBasisPoints: probabilityBasisPoints,
            placeholderSymbol: placeholderSymbol,
            imageAssetName: imageAssetName,
            silhouetteAssetName: "\(imageAssetName)Silhouette",
            boxAssetName: "GachaNanaBlindBox",
            motto: profile.motto,
            personality: profile.personality,
            isHidden: isHidden
        )
    }

    private static func itemProfile(_ id: String) -> (motto: AppLocalizedText, personality: AppLocalizedText) {
        switch id {
        case "plush_coconut_sleepy":
            return (
                AppLocalizedText(zh: "慢一点，梦会自己发芽。", en: "Go slow. Dreams sprout on their own.", de: "Langsam. Träume keimen von selbst."),
                AppLocalizedText(zh: "慵懒、会把安静变成小窝。", en: "Sleepy, soft, and good at turning quiet into a nest.", de: "Schläfrig, weich und macht aus Ruhe ein Nest.")
            )
        case "plush_coconut_sunny":
            return (
                AppLocalizedText(zh: "潮水会退，勇气会留下。", en: "The tide goes out. Courage stays.", de: "Die Flut geht. Mut bleibt."),
                AppLocalizedText(zh: "清爽、爱收集贝壳和新的开始。", en: "Breezy, curious, and always collecting fresh starts.", de: "Frisch, neugierig und sammelt neue Anfänge.")
            )
        case "plush_coconut_leaf":
            return (
                AppLocalizedText(zh: "拥抱之前，先给世界一朵花。", en: "Offer the world a flower before the hug.", de: "Schenk der Welt eine Blume vor der Umarmung."),
                AppLocalizedText(zh: "热情、亲近人，喜欢把疲惫揉软。", en: "Warm, affectionate, and softens tired days.", de: "Warm, anhänglich und macht müde Tage weich.")
            )
        case "plush_coconut_milk":
            return (
                AppLocalizedText(zh: "星星不催你，它只陪你亮。", en: "Stars do not rush you. They just glow with you.", de: "Sterne drängen nicht. Sie leuchten mit dir."),
                AppLocalizedText(zh: "安静、浪漫，适合夜晚陪伴。", en: "Quiet, dreamy, and made for night companionship.", de: "Ruhig, verträumt und für Nachtbegleitung gemacht.")
            )
        case "plush_coconut_star":
            return (
                AppLocalizedText(zh: "今天的小芽，明天会很厉害。", en: "Today's tiny sprout gets mighty tomorrow.", de: "Der kleine Spross von heute wird morgen stark."),
                AppLocalizedText(zh: "乐观、行动快，总想第一个冒头。", en: "Optimistic, quick, and always first to pop up.", de: "Optimistisch, flink und immer als Erstes da.")
            )
        case "plush_coconut_blush":
            return (
                AppLocalizedText(zh: "暖一点，坏天气也会坐下来。", en: "Add warmth, and bad weather sits down.", de: "Mit Wärme setzt sich schlechtes Wetter hin."),
                AppLocalizedText(zh: "温暖、护短，像一杯小小热可可。", en: "Protective, cozy, and a little cup of cocoa energy.", de: "Beschützend, gemütlich und wie eine kleine Tasse Kakao.")
            )
        case "plush_coconut_cloud":
            return (
                AppLocalizedText(zh: "水坑里也可以有天空。", en: "Even a puddle can hold the sky.", de: "Auch eine Pfütze kann Himmel tragen."),
                AppLocalizedText(zh: "敏感、会观察，擅长发现小惊喜。", en: "Sensitive, observant, and great at spotting tiny wonders.", de: "Feinfühlig, aufmerksam und findet kleine Wunder.")
            )
        case "plush_coconut_moss":
            return (
                AppLocalizedText(zh: "亮一下，就算赢。", en: "One spark counts as a win.", de: "Ein Funke zählt als Sieg."),
                AppLocalizedText(zh: "俏皮、反应快，像一颗会眨眼的青柠火花。", en: "Playful, quick, and bright like a winking lime spark.", de: "Verspielt, schnell und hell wie ein zwinkernder Limettenfunke.")
            )
        case "plush_coconut_secret":
            return (
                AppLocalizedText(zh: "真正的光，会先藏起来。", en: "Real glow hides first.", de: "Echtes Leuchten versteckt sich zuerst."),
                AppLocalizedText(zh: "神秘、骄傲，只在信任时发光。", en: "Mysterious, proud, and glows only when it trusts you.", de: "Geheimnisvoll, stolz und leuchtet nur bei Vertrauen.")
            )
        default:
            return (
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
        return logs.filter { log in
            log.ownerHumanId == humanId && log.drawDate >= start && log.drawDate < end
        }.count
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

    @MainActor
    static func draw(
        seriesId: String = GachaSeriesCatalog.defaultSeriesId,
        human: Human?,
        context: ModelContext,
        now: Date = Date(),
        forcedRoll: Int? = nil
    ) throws -> GachaDrawOutcome {
        guard let human else { throw GachaDrawError.missingHuman }
        let series = GachaSeriesCatalog.series(id: seriesId)
        guard series.probabilityTotalBasisPoints == GachaSeriesCatalog.totalBasisPoints else {
            throw GachaDrawError.invalidSeries
        }

        let logs = (try? context.fetch(FetchDescriptor<GachaDrawLog>())) ?? []
        let usedToday = dailyDrawCount(for: human.id.uuidString, in: logs, now: now)
        guard human.coconutBalance >= costPerDraw else {
            throw GachaDrawError.insufficientBalance(missing: costPerDraw - human.coconutBalance)
        }

        let rollResult = roll(in: series, forcedRoll: forcedRoll)
        let ownedItems = (try? context.fetch(FetchDescriptor<GachaOwnedItem>())) ?? []
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

        let previousBalance = human.coconutBalance
        let instantCoconutDelta = rollResult.instantResult?.coconutDelta ?? 0
        human.coconutBalance -= costPerDraw
        human.coconutBalance += instantCoconutDelta
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

        CareLedgerService.record(
            actorKind: .human,
            actorId: human.id.uuidString,
            subjectKind: .system,
            subjectId: nil,
            eventKind: .coconut,
            actionType: "gachaDrawCost",
            note: "Blind box cost · \(series.id)",
            source: .economy,
            coconutDelta: -costPerDraw,
            metadataJSON: "{\(baseMetadata),\"ledgerPart\":\"cost\"}",
            context: context,
            save: false
        )
        if instantCoconutDelta > 0 {
            CareLedgerService.record(
                actorKind: .human,
                actorId: human.id.uuidString,
                subjectKind: .system,
                subjectId: nil,
                eventKind: .coconut,
                actionType: "gachaInstantReward",
                note: rollResult.instantResult?.id ?? "instantReward",
                source: .economy,
                coconutDelta: instantCoconutDelta,
                metadataJSON: "{\(baseMetadata),\"ledgerPart\":\"instantReward\"}",
                context: context,
                save: false
            )
        }

        do {
            try context.save()
            QuestManager.shared.recordCoconutDelta(
                -costPerDraw,
                emoji: "🥥",
                title: "盲盒抽取",
                actorId: human.id.uuidString,
                actorName: human.name
            )
            if instantCoconutDelta > 0 {
                QuestManager.shared.recordCoconutDelta(
                    instantCoconutDelta,
                    emoji: rollResult.instantResult?.symbol ?? "🥥",
                    title: rollResult.instantResult?.title.translations["zh"] ?? "盲盒即时返还",
                    actorId: human.id.uuidString,
                    actorName: human.name
                )
            }
        } catch {
            human.coconutBalance = previousBalance
            context.delete(log)
            if isNew, let owned {
                context.delete(owned)
            } else if let owned {
                owned.ownedCount = max(0, owned.ownedCount - 1)
                owned.latestObtainedAt = owned.firstObtainedAt
            }
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
        forcedRoll: Int? = nil
    ) -> GachaRollResult {
        let rawRoll = forcedRoll ?? Int.random(in: 0..<GachaSeriesCatalog.totalBasisPoints)
        let roll = max(0, min(rawRoll, GachaSeriesCatalog.totalBasisPoints - 1))
        let hiddenLimit = series.hiddenProbabilityBasisPoints
        let commonLimit = hiddenLimit + series.commonProbabilityBasisPoints

        if roll < hiddenLimit, let hidden = series.hiddenItem {
            return GachaRollResult(kind: .collectible, item: hidden, instantResult: nil)
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

import Foundation

nonisolated struct PlantCatalogMedia: Equatable, Sendable {
    let assetName: String
    let altTextZh: String
    let altTextEn: String

    static let localFoliage = PlantCatalogMedia(
        assetName: "plant_catalog_foliage",
        altTextZh: "本地植物资料库插图",
        altTextEn: "Local plant catalog illustration"
    )

    static func avatarAssetName(forCatalogID id: String) -> String {
        "PlantAvatarAssets/plant_\(id.replacingOccurrences(of: "-", with: "_")).png"
    }

    static func bundledAvatarAssetName(forCatalogID id: String) -> String {
        avatarAssetName(forCatalogID: id)
    }
}

nonisolated struct PlantCatalogSourceAttribution: Equatable, Sendable {
    let title: String
    let license: String
    let sourceURL: String

    static let ohanaLocalGuide = PlantCatalogSourceAttribution(
        title: "Ohana local starter plant guide",
        license: "Ohana bundled reference copy and generated local illustration",
        sourceURL: "local://ohana/plant-catalog-v1"
    )
}

nonisolated struct PlantCatalogEntry: Identifiable, Equatable, Sendable {
    let id: String
    let commonName: String
    let latinName: String
    let aliases: [String]
    let imageName: String
    let summary: String
    let habitNotes: String
    let careTips: [String]
    let cautionNotes: [String]
    let media: PlantCatalogMedia
    let sourceAttribution: PlantCatalogSourceAttribution
    let lightRequirement: PlantLightLevel
    let wateringPreference: String
    let humidity: String
    let temperature: String
    let soil: String
    let fertilizing: String
    let propagation: String
    let pruning: String
    let commonIssues: String
    let toxicity: String
    let careDifficulty: String
    let isToxicToCats: Bool
    let isToxicToDogs: Bool
    let isToxicToChildren: Bool
    let isIndoorSuitable: Bool
    let defaultWateringDays: Int
    let defaultFertilizingDays: Int

    init(
        id: String,
        commonName: String,
        latinName: String,
        aliases: [String],
        imageName: String,
        summary: String = "",
        habitNotes: String = "",
        careTips: [String] = [],
        cautionNotes: [String] = [],
        media: PlantCatalogMedia = .localFoliage,
        sourceAttribution: PlantCatalogSourceAttribution = .ohanaLocalGuide,
        lightRequirement: PlantLightLevel,
        wateringPreference: String,
        humidity: String,
        temperature: String,
        soil: String,
        fertilizing: String,
        propagation: String,
        pruning: String,
        commonIssues: String,
        toxicity: String,
        careDifficulty: String,
        isToxicToCats: Bool,
        isToxicToDogs: Bool,
        isToxicToChildren: Bool,
        isIndoorSuitable: Bool,
        defaultWateringDays: Int,
        defaultFertilizingDays: Int
    ) {
        self.id = id
        self.commonName = commonName
        self.latinName = latinName
        self.aliases = aliases
        self.imageName = imageName
        self.summary = summary.isEmpty
            ? Self.defaultSummary(commonName: commonName, lightRequirement: lightRequirement)
            : summary
        self.habitNotes = habitNotes.isEmpty
            ? Self.defaultHabitNotes(lightRequirement: lightRequirement, humidity: humidity, defaultWateringDays: defaultWateringDays)
            : habitNotes
        self.careTips = careTips.isEmpty
            ? Self.defaultCareTips(defaultFertilizingDays: defaultFertilizingDays)
            : careTips
        self.cautionNotes = cautionNotes.isEmpty
            ? Self.defaultCautionNotes(
                isToxicToCats: isToxicToCats,
                isToxicToDogs: isToxicToDogs,
                isToxicToChildren: isToxicToChildren,
                commonIssues: commonIssues
            )
            : cautionNotes
        self.media = media
        self.sourceAttribution = sourceAttribution
        self.lightRequirement = lightRequirement
        self.wateringPreference = wateringPreference
        self.humidity = humidity
        self.temperature = temperature
        self.soil = soil
        self.fertilizing = fertilizing
        self.propagation = propagation
        self.pruning = pruning
        self.commonIssues = commonIssues
        self.toxicity = toxicity
        self.careDifficulty = careDifficulty
        self.isToxicToCats = isToxicToCats
        self.isToxicToDogs = isToxicToDogs
        self.isToxicToChildren = isToxicToChildren
        self.isIndoorSuitable = isIndoorSuitable
        self.defaultWateringDays = defaultWateringDays
        self.defaultFertilizingDays = defaultFertilizingDays
    }

    var localizedCommonName: String {
        PlantCatalogLocalization.commonName(
            id: id,
            zh: commonName,
            latinName: latinName,
            aliases: aliases
        )
    }

    var catalogImageAssetName: String {
        if !imageName.isEmpty {
            return imageName
        }
        return media.assetName.isEmpty ? PlantCatalogMedia.localFoliage.assetName : media.assetName
    }

    var localizedSummary: String { PlantCatalogLocalization.summary(for: self) }
    var localizedHabitNotes: String { PlantCatalogLocalization.habitNotes(for: self) }
    var localizedCareTips: [String] { PlantCatalogLocalization.careTips(for: self) }
    var localizedCautionNotes: [String] { PlantCatalogLocalization.cautionNotes(for: self) }
    var localizedWateringPreference: String { PlantCatalogLocalization.text(wateringPreference) }
    var localizedHumidity: String { PlantCatalogLocalization.text(humidity) }
    var localizedTemperature: String { PlantCatalogLocalization.text(temperature) }
    var localizedSoil: String { PlantCatalogLocalization.text(soil) }
    var localizedFertilizing: String { PlantCatalogLocalization.text(fertilizing) }
    var localizedPropagation: String { PlantCatalogLocalization.text(propagation) }
    var localizedPruning: String { PlantCatalogLocalization.text(pruning) }
    var localizedCommonIssues: String { PlantCatalogLocalization.text(commonIssues) }
    var localizedToxicity: String { PlantCatalogLocalization.text(toxicity) }
    var localizedCareDifficulty: String { PlantCatalogLocalization.text(careDifficulty) }

    private static func defaultSummary(commonName: String, lightRequirement: PlantLightLevel) -> String {
        "\(commonName) 是适合家庭管理的常见植物，建档时重点记录\(lightRequirement.displayName)、浇水节奏和摆放安全。"
    }

    private static func defaultHabitNotes(
        lightRequirement: PlantLightLevel,
        humidity: String,
        defaultWateringDays: Int
    ) -> String {
        if defaultWateringDays >= 14 {
            return "偏耐旱，适合等介质明显变干再浇；弱光或冬季继续拉长间隔。"
        }
        if humidity.contains("高湿") || humidity.contains("偏高") || humidity.contains("中高") {
            return "喜欢稳定湿度和柔和光线，叶片状态会较快反映干燥、冷风或暴晒。"
        }
        if lightRequirement == .direct {
            return "需要更强光线才会紧凑生长或开花，室内应靠近明亮窗边。"
        }
        return "适合明亮到中等室内光线，保持稳定位置比频繁移动更重要。"
    }

    private static func defaultCareTips(defaultFertilizingDays: Int) -> [String] {
        var tips = [
            "浇水前摸表土或掂盆重，不要只按固定日期。",
            "新买回家先观察 1-2 周，再换盆或重剪。"
        ]
        tips.append(
            defaultFertilizingDays <= 30
                ? "生长期薄肥即可，状态紧张或冬季先暂停施肥。"
                : "施肥需求不高，少量低浓度比一次重肥更安全。"
        )
        return tips
    }

    private static func defaultCautionNotes(
        isToxicToCats: Bool,
        isToxicToDogs: Bool,
        isToxicToChildren: Bool,
        commonIssues: String
    ) -> [String] {
        var notes = [
            (isToxicToCats || isToxicToDogs || isToxicToChildren)
                ? "有误食风险，家中有宠物或儿童时请放到够不到的位置。"
                : "通常属于家庭低风险植物，但仍建议避免宠物或儿童啃咬。"
        ]
        notes.append(
            (commonIssues.contains("黄叶") || commonIssues.contains("烂根"))
                ? "黄叶、软茎或异味通常先检查积水和根系。"
                : "突然换位置后先观察新叶和叶缘，避免连续调整。"
        )
        return notes
    }
}

nonisolated struct PlantCatalogSearchResult: Identifiable, Equatable, Sendable {
    let entry: PlantCatalogEntry
    let score: Int
    let matchSummary: String

    var id: String { entry.id }
}

nonisolated struct PlantCatalogStore: Sendable {
    static let shared = PlantCatalogStore()

    let entries: [PlantCatalogEntry]

    private init(entries: [PlantCatalogEntry] = PlantCatalog.entries) {
        self.entries = entries
    }
}

import Foundation

enum PlantCatalogQuickFilter: String, CaseIterable, Identifiable {
    case beginner
    case petSafe
    case lowLight
    case balcony
    case flowering
    case succulent

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .beginner: l.tr(zh: "新手友好", en: "Beginner", de: "Einfach")
        case .petSafe: l.tr(zh: "宠物家庭", en: "Pet family", de: "Haustiere")
        case .lowLight: l.tr(zh: "弱光", en: "Low light", de: "Wenig Licht")
        case .balcony: l.tr(zh: "阳台", en: "Balcony", de: "Balkon")
        case .flowering: l.tr(zh: "开花", en: "Flowering", de: "Blüht")
        case .succulent: l.tr(zh: "多肉", en: "Succulent", de: "Sukkulent")
        }
    }

    func includes(_ entry: PlantCatalogEntry) -> Bool {
        let searchText = ([entry.commonName, entry.latinName, entry.careDifficulty, entry.soil, entry.wateringPreference] + entry.aliases)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
        switch self {
        case .beginner:
            return entry.careDifficulty == "简单" || entry.defaultWateringDays >= 7
        case .petSafe:
            return !entry.isToxicToCats && !entry.isToxicToDogs && !entry.isToxicToChildren
        case .lowLight:
            return entry.lightRequirement == .low ||
                (entry.lightRequirement == .medium && entry.defaultWateringDays >= 10) ||
                searchText.contains("low light")
        case .balcony:
            return entry.lightRequirement == .direct ||
                entry.lightRequirement == .brightIndirect ||
                searchText.contains("herb") ||
                searchText.contains("citrus")
        case .flowering:
            return searchText.contains("flower") ||
                searchText.contains("orchid") ||
                searchText.contains("兰") ||
                searchText.contains("花") ||
                searchText.contains("凤梨")
        case .succulent:
            return searchText.contains("多肉") ||
                searchText.contains("仙人掌") ||
                searchText.contains("succulent") ||
                searchText.contains("cactus") ||
                searchText.contains("芦荟")
        }
    }
}

enum PlantCatalogBrowsingGroup: String, CaseIterable, Identifiable {
    case recommended
    case foliageVines
    case lowLight
    case petSafe
    case succulentCactus
    case floweringBalcony

    var id: String { rawValue }

    func title(_ l: L10n) -> String {
        switch self {
        case .recommended: l.tr(zh: "推荐", en: "Recommended", de: "Empfohlen")
        case .foliageVines: l.tr(zh: "观叶藤本", en: "Foliage & vines", de: "Blatt & Ranken")
        case .lowLight: l.tr(zh: "弱光耐养", en: "Low light", de: "Wenig Licht")
        case .petSafe: l.tr(zh: "宠物家庭", en: "Pet friendly", de: "Haustiere")
        case .succulentCactus: l.tr(zh: "多肉仙人掌", en: "Succulents", de: "Sukkulenten")
        case .floweringBalcony: l.tr(zh: "开花阳台", en: "Flowers & balcony", de: "Blüten & Balkon")
        }
    }

    func subtitle(_ l: L10n) -> String {
        switch self {
        case .recommended:
            l.tr(zh: "最常见，适合快速建档", en: "Common choices for quick setup", de: "Häufige Auswahl für schnelles Anlegen")
        case .foliageVines:
            l.tr(zh: "绿萝、龟背竹、蔓绿绒等", en: "Pothos, monstera, philodendron, and more", de: "Efeutute, Monstera, Philodendron und mehr")
        case .lowLight:
            l.tr(zh: "适合室内较暗位置", en: "For darker indoor spots", de: "Für dunklere Innenbereiche")
        case .petSafe:
            l.tr(zh: "优先低误食风险", en: "Prioritizes low ingestion risk", de: "Bevorzugt geringes Verschluckrisiko")
        case .succulentCactus:
            l.tr(zh: "少浇水，偏干养护", en: "Drier care with less watering", de: "Trockenere Pflege mit weniger Gießen")
        case .floweringBalcony:
            l.tr(zh: "强光、开花和香草类", en: "Bright, flowering, and herb plants", de: "Helle, blühende und Kräuterpflanzen")
        }
    }

    func includes(_ entry: PlantCatalogEntry) -> Bool {
        let searchText = ([entry.commonName, entry.latinName, entry.careDifficulty, entry.soil, entry.wateringPreference] + entry.aliases)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
        switch self {
        case .recommended:
            return entry.careDifficulty == "简单" || entry.defaultWateringDays >= 7
        case .foliageVines:
            return searchText.contains("绿萝") ||
                searchText.contains("龟背") ||
                searchText.contains("蔓绿绒") ||
                searchText.contains("葛") ||
                searchText.contains("pothos") ||
                searchText.contains("monstera") ||
                searchText.contains("philodendron") ||
                searchText.contains("scindapsus") ||
                searchText.contains("syngonium")
        case .lowLight:
            return PlantCatalogQuickFilter.lowLight.includes(entry)
        case .petSafe:
            return PlantCatalogQuickFilter.petSafe.includes(entry)
        case .succulentCactus:
            return PlantCatalogQuickFilter.succulent.includes(entry)
        case .floweringBalcony:
            return PlantCatalogQuickFilter.flowering.includes(entry) ||
                PlantCatalogQuickFilter.balcony.includes(entry)
        }
    }
}

enum AddPlantCatalogPickerModel {
    private static let entriesByBrowsingGroup: [PlantCatalogBrowsingGroup: [PlantCatalogEntry]] = Dictionary(uniqueKeysWithValues: PlantCatalogBrowsingGroup.allCases.map { group in
            (group, makeEntries(for: group))
        })

    static func commonEntries(for filter: PlantCatalogQuickFilter) -> [PlantCatalogEntry] {
        let preferredIDs = [
            "epipremnum-aureum",
            "monstera-deliciosa",
            "chlorophytum-comosum",
            "sansevieria-trifasciata",
            "zamioculcas-zamiifolia",
            "pilea-peperomioides",
            "spathiphyllum-wallisii",
            "phalaenopsis-amabilis",
            "hoya-carnosa",
            "echeveria-elegans"
        ]
        let preferred = preferredIDs
            .compactMap { PlantCatalog.entry(id: $0) }
            .filter(filter.includes)
        let expanded = PlantCatalogStore.shared.entries.filter(filter.includes)
        return Array((preferred + expanded).uniquedByID().prefix(12))
    }

    static func entries(for group: PlantCatalogBrowsingGroup) -> [PlantCatalogEntry] {
        entriesByBrowsingGroup[group] ?? []
    }

    private static func makeEntries(for group: PlantCatalogBrowsingGroup) -> [PlantCatalogEntry] {
        let preferredIDs = preferredIDs(for: group)
        let preferred = preferredIDs
            .compactMap { PlantCatalog.entry(id: $0) }
            .filter(group.includes)
        let expanded = PlantCatalogStore.shared.entries.filter(group.includes)
        return Array((preferred + expanded).uniquedByID().prefix(18))
    }

    private static func preferredIDs(for group: PlantCatalogBrowsingGroup) -> [String] {
        switch group {
        case .recommended:
            [
                "epipremnum-aureum",
                "monstera-deliciosa",
                "chlorophytum-comosum",
                "sansevieria-trifasciata",
                "zamioculcas-zamiifolia",
                "pilea-peperomioides",
                "spathiphyllum-wallisii",
                "hoya-carnosa"
            ]
        case .foliageVines:
            [
                "epipremnum-aureum",
                "monstera-deliciosa",
                "philodendron-hederaceum",
                "scindapsus-pictus",
                "syngonium-podophyllum",
                "rhaphidophora-tetrasperma"
            ]
        case .lowLight:
            [
                "zamioculcas-zamiifolia",
                "sansevieria-trifasciata",
                "aglaonema-commutatum",
                "aspidistra-elatior",
                "dracaena-fragrans"
            ]
        case .petSafe:
            [
                "chlorophytum-comosum",
                "pilea-peperomioides",
                "fittonia-albivenis",
                "chamaedorea-elegans",
                "peperomia-obtusifolia"
            ]
        case .succulentCactus:
            [
                "haworthiopsis-attenuata",
                "echeveria-elegans",
                "schlumbergera-truncata",
                "aloe-vera",
                "opuntia-microdasys"
            ]
        case .floweringBalcony:
            [
                "phalaenopsis-amabilis",
                "saintpaulia-ionantha",
                "jasminum-sambac",
                "ocimum-basilicum",
                "salvia-rosmarinus"
            ]
        }
    }
}

enum AddPlantChoiceLibrary {
    static func roomOptions(_ l: L10n) -> [String] {
        [
            l.tr(zh: "客厅", en: "Living room", de: "Wohnzimmer"),
            l.tr(zh: "阳台", en: "Balcony", de: "Balkon"),
            l.tr(zh: "卧室", en: "Bedroom", de: "Schlafzimmer"),
            l.tr(zh: "厨房", en: "Kitchen", de: "Küche"),
            l.tr(zh: "书房", en: "Study", de: "Arbeitszimmer"),
            l.tr(zh: "浴室", en: "Bathroom", de: "Bad"),
            l.tr(zh: "办公室", en: "Office", de: "Büro")
        ]
    }

    static func spotOptions(_ l: L10n) -> [String] {
        [
            l.tr(zh: "南窗边", en: "South window", de: "Südfenster"),
            l.tr(zh: "东窗边", en: "East window", de: "Ostfenster"),
            l.tr(zh: "西窗边", en: "West window", de: "Westfenster"),
            l.tr(zh: "北窗边", en: "North window", de: "Nordfenster"),
            l.tr(zh: "窗台", en: "Window sill", de: "Fensterbank"),
            l.tr(zh: "书桌", en: "Desk", de: "Schreibtisch"),
            l.tr(zh: "花架", en: "Plant stand", de: "Pflanzenregal")
        ]
    }

    static func potMaterialOptions(_ l: L10n) -> [String] {
        [
            l.tr(zh: "陶盆", en: "Terracotta", de: "Terrakotta"),
            l.tr(zh: "塑料盆", en: "Plastic", de: "Kunststoff"),
            l.tr(zh: "釉面陶瓷", en: "Glazed ceramic", de: "Glasierte Keramik"),
            l.tr(zh: "自吸水盆", en: "Self-watering", de: "Selbstbewässernd")
        ]
    }

    static func soilOptions(_ l: L10n) -> [String] {
        [
            l.tr(zh: "疏松排水型通用土", en: "Loose all-purpose mix", de: "Lockere Universalerde"),
            l.tr(zh: "多肉/仙人掌土", en: "Succulent mix", de: "Sukkulentenerde"),
            l.tr(zh: "观叶植物土", en: "Foliage plant mix", de: "Grünpflanzenerde"),
            l.tr(zh: "树皮颗粒混合土", en: "Bark chunky mix", de: "Rindensubstrat")
        ]
    }

    static func sourceOptions(_ l: L10n) -> [String] {
        [
            l.tr(zh: "花市", en: "Plant market", de: "Pflanzenmarkt"),
            l.tr(zh: "花店", en: "Plant shop", de: "Pflanzengeschäft"),
            l.tr(zh: "朋友分株", en: "Friend's cutting", de: "Ableger von Freunden"),
            l.tr(zh: "网购", en: "Online order", de: "Online bestellt")
        ]
    }
}

private extension [PlantCatalogEntry] {
    func uniquedByID() -> [PlantCatalogEntry] {
        var seen = Set<String>()
        return filter { entry in
            seen.insert(entry.id).inserted
        }
    }
}

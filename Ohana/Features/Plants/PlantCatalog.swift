//
//  PlantCatalog.swift
//  Ohana
//
//  Local starter plant knowledge used by the free plant-care launch surface.
//

import Foundation

nonisolated enum PlantCatalog {
    static let entries: [PlantCatalogEntry] = coreEntries + commonIndoorEntries

    private static let coreEntries: [PlantCatalogEntry] = [
        PlantCatalogEntry(
            id: "epipremnum-aureum",
            commonName: "绿萝",
            latinName: "Epipremnum aureum",
            aliases: ["pothos", "黄金葛", "devils ivy"],
            imageName: PlantCatalogMedia.avatarAssetName(forCatalogID: "epipremnum-aureum"),
            lightRequirement: .brightIndirect,
            wateringPreference: "表土 2-3 cm 变干后浇透",
            humidity: "普通室内湿度即可",
            temperature: "18-30 C",
            soil: "疏松排水型通用土",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "带节茎插水培或土培",
            pruning: "修剪过长藤蔓，促进分枝",
            commonIssues: "黄叶常见于过浇、低温或光照突变",
            toxicity: "对猫狗和儿童有刺激性，避免误食",
            careDifficulty: "简单",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: true,
            isIndoorSuitable: true,
            defaultWateringDays: 7,
            defaultFertilizingDays: 35
        ),
        PlantCatalogEntry(
            id: "monstera-deliciosa",
            commonName: "龟背竹",
            latinName: "Monstera deliciosa",
            aliases: ["monstera", "swiss cheese plant"],
            imageName: PlantCatalogMedia.avatarAssetName(forCatalogID: "monstera-deliciosa"),
            lightRequirement: .brightIndirect,
            wateringPreference: "上层土干后浇透，避免长期积水",
            humidity: "偏高湿度更佳",
            temperature: "18-29 C",
            soil: "粗颗粒、树皮和通用土混合",
            fertilizing: "春夏每月薄肥",
            propagation: "带气根和节位扦插",
            pruning: "剪除老叶和过密枝叶",
            commonIssues: "焦边多与干燥、盐分或直晒有关",
            toxicity: "对猫狗和儿童有刺激性，避免误食",
            careDifficulty: "中等",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: true,
            isIndoorSuitable: true,
            defaultWateringDays: 8,
            defaultFertilizingDays: 30
        ),
        PlantCatalogEntry(
            id: "chlorophytum-comosum",
            commonName: "吊兰",
            latinName: "Chlorophytum comosum",
            aliases: ["spider plant", "airplane plant"],
            imageName: PlantCatalogMedia.avatarAssetName(forCatalogID: "chlorophytum-comosum"),
            lightRequirement: .medium,
            wateringPreference: "保持轻微湿润，冬季减少",
            humidity: "普通室内湿度",
            temperature: "15-27 C",
            soil: "排水良好的通用土",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "分株或小吊兰落地",
            pruning: "剪除干尖和老叶",
            commonIssues: "叶尖干枯常见于干燥、盐分或缺水",
            toxicity: "通常对猫狗低风险",
            careDifficulty: "简单",
            isToxicToCats: false,
            isToxicToDogs: false,
            isToxicToChildren: false,
            isIndoorSuitable: true,
            defaultWateringDays: 6,
            defaultFertilizingDays: 40
        ),
        PlantCatalogEntry(
            id: "sansevieria-trifasciata",
            commonName: "虎尾兰",
            latinName: "Dracaena trifasciata",
            aliases: ["snake plant", "虎皮兰"],
            imageName: PlantCatalogMedia.avatarAssetName(forCatalogID: "sansevieria-trifasciata"),
            lightRequirement: .medium,
            wateringPreference: "土壤完全干透后再浇",
            humidity: "耐普通偏干环境",
            temperature: "16-30 C",
            soil: "多肉或仙人掌型排水土",
            fertilizing: "生长期 6-8 周一次薄肥",
            propagation: "分株或叶插",
            pruning: "剪除受损老叶",
            commonIssues: "根腐多由过浇或盆土不透气导致",
            toxicity: "对猫狗有轻中度风险，避免误食",
            careDifficulty: "简单",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: false,
            isIndoorSuitable: true,
            defaultWateringDays: 18,
            defaultFertilizingDays: 60
        ),
        PlantCatalogEntry(
            id: "ficus-lyrata",
            commonName: "琴叶榕",
            latinName: "Ficus lyrata",
            aliases: ["fiddle leaf fig"],
            imageName: PlantCatalogMedia.avatarAssetName(forCatalogID: "ficus-lyrata"),
            lightRequirement: .brightIndirect,
            wateringPreference: "表土明显变干后浇透，保持节奏稳定",
            humidity: "中高湿更佳",
            temperature: "18-29 C，避免冷风",
            soil: "排水良好的室内观叶土",
            fertilizing: "生长期每月薄肥",
            propagation: "枝条扦插",
            pruning: "修剪顶部促进分枝",
            commonIssues: "掉叶常见于搬动、冷风、过浇或光照变化",
            toxicity: "对猫狗和儿童有刺激性，避免误食汁液",
            careDifficulty: "进阶",
            isToxicToCats: true,
            isToxicToDogs: true,
            isToxicToChildren: true,
            isIndoorSuitable: true,
            defaultWateringDays: 7,
            defaultFertilizingDays: 30
        )
    ]

    private static let commonIndoorEntries: [PlantCatalogEntry] = commonIndoorSeeds.map(makeEntry)

    private static let commonIndoorSeeds: [CatalogSeed] = [
        CatalogSeed("zamioculcas-zamiifolia", "金钱树", "Zamioculcas zamiifolia", ["zz plant", "雪铁芋"], .lowLightToxic),
        CatalogSeed("spathiphyllum-wallisii", "白掌", "Spathiphyllum wallisii", ["peace lily", "一帆风顺"], .floweringToxic),
        CatalogSeed("philodendron-hederaceum", "心叶蔓绿绒", "Philodendron hederaceum", ["heartleaf philodendron"], .aroid),
        CatalogSeed("philodendron-birkin", "白锦蔓绿绒", "Philodendron Birkin", ["birkin philodendron"], .aroid),
        CatalogSeed("philodendron-micans", "丝绒蔓绿绒", "Philodendron hederaceum micans", ["philodendron micans"], .aroid),
        CatalogSeed("scindapsus-pictus", "银斑葛", "Scindapsus pictus", ["satin pothos", "silver pothos"], .aroidVine),
        CatalogSeed("syngonium-podophyllum", "合果芋", "Syngonium podophyllum", ["arrowhead plant"], .aroid),
        CatalogSeed("aglaonema-commutatum", "广东万年青", "Aglaonema commutatum", ["chinese evergreen"], .lowLightToxic),
        CatalogSeed("dieffenbachia-seguine", "花叶万年青", "Dieffenbachia seguine", ["dumb cane"], .lowLightToxic),
        CatalogSeed("calathea-orbifolia", "圆叶竹芋", "Goeppertia orbifolia", ["calathea orbifolia"], .prayerPlant),
        CatalogSeed("calathea-makoyana", "孔雀竹芋", "Goeppertia makoyana", ["peacock plant", "calathea makoyana"], .prayerPlant),
        CatalogSeed("goeppertia-ornata", "纹叶竹芋", "Goeppertia ornata", ["pinstripe calathea"], .prayerPlant),
        CatalogSeed("maranta-leuconeura", "红脉豹纹竹芋", "Maranta leuconeura", ["prayer plant"], .prayerPlant),
        CatalogSeed("stromanthe-triostar", "三色肖竹芋", "Stromanthe sanguinea Triostar", ["triostar stromanthe"], .prayerPlant),
        CatalogSeed("peperomia-obtusifolia", "圆叶椒草", "Peperomia obtusifolia", ["baby rubber plant"], .peperomia),
        CatalogSeed("peperomia-argyreia", "西瓜皮椒草", "Peperomia argyreia", ["watermelon peperomia"], .peperomia),
        CatalogSeed("pilea-peperomioides", "镜面草", "Pilea peperomioides", ["chinese money plant"], .petSafeEasy),
        CatalogSeed("hoya-carnosa", "球兰", "Hoya carnosa", ["wax plant"], .hoya),
        CatalogSeed("hoya-kerrii", "心叶球兰", "Hoya kerrii", ["sweetheart hoya"], .hoya),
        CatalogSeed("dischidia-nummularia", "纽扣玉藤", "Dischidia nummularia", ["string of nickels"], .hoya),
        CatalogSeed("ceropegia-woodii", "爱之蔓", "Ceropegia woodii", ["string of hearts"], .succulentSafe),
        CatalogSeed("senecio-rowleyanus", "珍珠吊兰", "Curio rowleyanus", ["string of pearls"], .succulentToxic),
        CatalogSeed("tradescantia-zebrina", "吊竹梅", "Tradescantia zebrina", ["inch plant"], .petIrritant),
        CatalogSeed("fittonia-albivenis", "网纹草", "Fittonia albivenis", ["nerve plant"], .petSafeEasy),
        CatalogSeed("soleirolia-soleirolii", "婴儿泪", "Soleirolia soleirolii", ["baby tears"], .petSafeMoist),
        CatalogSeed("nephrolepis-exaltata", "波士顿蕨", "Nephrolepis exaltata", ["boston fern"], .fern),
        CatalogSeed("asplenium-nidus", "鸟巢蕨", "Asplenium nidus", ["bird nest fern"], .fern),
        CatalogSeed("adiantum-raddianum", "铁线蕨", "Adiantum raddianum", ["maidenhair fern"], .fernAdvanced),
        CatalogSeed("platycerium-bifurcatum", "鹿角蕨", "Platycerium bifurcatum", ["staghorn fern"], .fernAdvanced),
        CatalogSeed("davallia-fejeensis", "兔脚蕨", "Davallia fejeensis", ["rabbit foot fern"], .fern),
        CatalogSeed("ficus-elastica", "橡皮树", "Ficus elastica", ["rubber plant"], .ficus),
        CatalogSeed("ficus-benjamina", "垂叶榕", "Ficus benjamina", ["weeping fig"], .ficus),
        CatalogSeed("ficus-microcarpa-ginseng", "人参榕", "Ficus microcarpa Ginseng", ["ginseng ficus"], .ficus),
        CatalogSeed("schefflera-arboricola", "鹅掌柴", "Schefflera arboricola", ["umbrella plant"], .woodyToxic),
        CatalogSeed("pachira-aquatica", "发财树", "Pachira aquatica", ["money tree"], .petSafeWoody),
        CatalogSeed("dracaena-marginata", "龙血树", "Dracaena marginata", ["dragon tree"], .lowLightToxic),
        CatalogSeed("dracaena-fragrans", "巴西木", "Dracaena fragrans", ["corn plant"], .lowLightToxic),
        CatalogSeed("dracaena-reflexa", "百合竹", "Dracaena reflexa", ["song of india"], .lowLightToxic),
        CatalogSeed("beaucarnea-recurvata", "酒瓶兰", "Beaucarnea recurvata", ["ponytail palm"], .succulentSafe),
        CatalogSeed("chamaedorea-elegans", "袖珍椰子", "Chamaedorea elegans", ["parlor palm"], .palm),
        CatalogSeed("dypsis-lutescens", "散尾葵", "Dypsis lutescens", ["areca palm"], .palm),
        CatalogSeed("howea-forsteriana", "肯氏椰子", "Howea forsteriana", ["kentia palm"], .palm),
        CatalogSeed("rhapis-excelsa", "棕竹", "Rhapis excelsa", ["lady palm"], .palm),
        CatalogSeed("chamaedorea-metallica", "金属袖珍椰子", "Chamaedorea metallica", ["metallic palm"], .palm),
        CatalogSeed("strelitzia-nicolai", "天堂鸟", "Strelitzia nicolai", ["bird of paradise"], .woodyToxic),
        CatalogSeed("musa-acuminata-dwarf-cavendish", "矮生香蕉", "Musa acuminata Dwarf Cavendish", ["dwarf banana"], .petSafeBright),
        CatalogSeed("alocasia-amazonica", "亚马逊海芋", "Alocasia amazonica", ["alocasia polly"], .aroidAdvanced),
        CatalogSeed("colocasia-esculenta", "海芋", "Colocasia esculenta", ["elephant ear"], .aroidAdvanced),
        CatalogSeed("anthurium-andraeanum", "红掌", "Anthurium andraeanum", ["flamingo flower"], .aroid),
        CatalogSeed("anthurium-clarinervium", "丝绒花烛", "Anthurium clarinervium", ["velvet cardboard anthurium"], .aroidAdvanced),
        CatalogSeed("epipremnum-pinnatum-cebu-blue", "蓝星绿萝", "Epipremnum pinnatum Cebu Blue", ["cebu blue pothos"], .aroidVine),
        CatalogSeed("rhaphidophora-tetrasperma", "姬龟背", "Rhaphidophora tetrasperma", ["mini monstera"], .aroid),
        CatalogSeed("monstera-adansonii", "仙洞龟背竹", "Monstera adansonii", ["swiss cheese vine"], .aroid),
        CatalogSeed("monstera-standleyana", "五孔龟背竹", "Monstera standleyana", ["philodendron cobra"], .aroid),
        CatalogSeed("thaumatophyllum-bipinnatifidum", "裂叶喜林芋", "Thaumatophyllum bipinnatifidum", ["tree philodendron"], .aroid),
        CatalogSeed("peperomia-prostrata", "串钱龟椒草", "Peperomia prostrata", ["string of turtles"], .peperomia),
        CatalogSeed("begonia-maculata", "鳟鱼秋海棠", "Begonia maculata", ["polka dot begonia"], .floweringToxic),
        CatalogSeed("begonia-rex-cultorum", "蟆叶秋海棠", "Begonia rex-cultorum", ["rex begonia"], .floweringToxic),
        CatalogSeed("oxalis-triangularis", "紫叶酢浆草", "Oxalis triangularis", ["purple shamrock"], .petIrritant),
        CatalogSeed("hypoestes-phyllostachya", "彩叶草", "Hypoestes phyllostachya", ["polka dot plant"], .petIrritant),
        CatalogSeed("hedera-helix", "常春藤", "Hedera helix", ["english ivy"], .trailingToxic),
        CatalogSeed("fatsia-japonica", "八角金盘", "Fatsia japonica", ["paperplant"], .petSafeWoody),
        CatalogSeed("clivia-miniata", "君子兰", "Clivia miniata", ["bush lily"], .floweringToxic),
        CatalogSeed("saintpaulia-ionantha", "非洲堇", "Saintpaulia ionantha", ["african violet"], .petSafeFlowering),
        CatalogSeed("streptocarpus-cape-primrose", "堇兰", "Streptocarpus", ["cape primrose"], .petSafeFlowering),
        CatalogSeed("schlumbergera-truncata", "蟹爪兰", "Schlumbergera truncata", ["thanksgiving cactus"], .succulentSafe),
        CatalogSeed("rhipsalidopsis-gaertneri", "复活节仙人掌", "Rhipsalidopsis gaertneri", ["easter cactus"], .succulentSafe),
        CatalogSeed("rhipsalis-baccifera", "丝苇", "Rhipsalis baccifera", ["mistletoe cactus"], .succulentSafe),
        CatalogSeed("epiphyllum-oxypetalum", "昙花", "Epiphyllum oxypetalum", ["queen of the night"], .succulentSafe),
        CatalogSeed("aloe-vera", "芦荟", "Aloe vera", ["aloe"], .succulentToxic),
        CatalogSeed("haworthiopsis-attenuata", "条纹十二卷", "Haworthiopsis attenuata", ["zebra haworthia"], .succulentSafe),
        CatalogSeed("echeveria-elegans", "月影", "Echeveria elegans", ["mexican snowball"], .succulentSafe),
        CatalogSeed("crassula-ovata", "玉树", "Crassula ovata", ["jade plant"], .succulentToxic),
        CatalogSeed("kalanchoe-blossfeldiana", "长寿花", "Kalanchoe blossfeldiana", ["flaming katy"], .succulentToxic),
        CatalogSeed("sedum-morganianum", "玉缀", "Sedum morganianum", ["burro tail"], .succulentSafe),
        CatalogSeed("aeonium-arboreum", "黑法师", "Aeonium arboreum", ["tree aeonium"], .succulentSafe),
        CatalogSeed("lithops-lesliei", "生石花", "Lithops lesliei", ["living stones"], .succulentAdvanced),
        CatalogSeed("euphorbia-trigona", "龙骨", "Euphorbia trigona", ["african milk tree"], .euphorbia),
        CatalogSeed("opuntia-microdasys", "兔耳仙人掌", "Opuntia microdasys", ["bunny ear cactus"], .cactus),
        CatalogSeed("mammillaria-elongata", "金手指", "Mammillaria elongata", ["ladyfinger cactus"], .cactus),
        CatalogSeed("gymnocalycium-mihanovichii", "绯花玉锦", "Gymnocalycium mihanovichii", ["moon cactus"], .cactus),
        CatalogSeed("asparagus-setaceus", "文竹", "Asparagus setaceus", ["asparagus fern"], .petIrritant),
        CatalogSeed("codiaeum-variegatum", "变叶木", "Codiaeum variegatum", ["croton"], .woodyToxic),
        CatalogSeed("cordyline-fruticosa", "朱蕉", "Cordyline fruticosa", ["ti plant"], .woodyToxic),
        CatalogSeed("polyscias-fruticosa", "南洋森", "Polyscias fruticosa", ["ming aralia"], .woodyToxic),
        CatalogSeed("plerandra-elegantissima", "细叶伞树", "Plerandra elegantissima", ["false aralia"], .woodyToxic),
        CatalogSeed("yucca-elephantipes", "无刺丝兰", "Yucca elephantipes", ["spineless yucca"], .woodyToxic),
        CatalogSeed("citrus-meyerii", "香水柠檬", "Citrus x meyeri", ["meyer lemon"], .sunnyToxic),
        CatalogSeed("lavandula-angustifolia", "薰衣草", "Lavandula angustifolia", ["lavender"], .sunnyPetIrritant),
        CatalogSeed("salvia-rosmarinus", "迷迭香", "Salvia rosmarinus", ["rosemary"], .herb),
        CatalogSeed("ocimum-basilicum", "罗勒", "Ocimum basilicum", ["basil"], .herb),
        CatalogSeed("mentha-spicata", "留兰香薄荷", "Mentha spicata", ["spearmint"], .herb),
        CatalogSeed("pelargonium-graveolens", "香叶天竺葵", "Pelargonium graveolens", ["scented geranium"], .floweringToxic),
        CatalogSeed("gardenia-jasminoides", "栀子花", "Gardenia jasminoides", ["gardenia"], .floweringToxic),
        CatalogSeed("jasminum-polyanthum", "多花素馨", "Jasminum polyanthum", ["pink jasmine"], .petSafeFlowering),
        CatalogSeed("hoya-pubicalyx", "紫花球兰", "Hoya pubicalyx", ["wax plant pubicalyx"], .hoya),
        CatalogSeed("hoya-linearis", "线叶球兰", "Hoya linearis", ["hoya linearis"], .hoyaAdvanced),
        CatalogSeed("epipremnum-aureum-neon", "霓虹绿萝", "Epipremnum aureum Neon", ["neon pothos"], .aroidVine),
        CatalogSeed("philodendron-erubescens", "红柄蔓绿绒", "Philodendron erubescens", ["blushing philodendron"], .aroid),
        CatalogSeed("scindapsus-treubii", "月光银葛", "Scindapsus treubii", ["moonlight scindapsus"], .aroidVine),
        CatalogSeed("aglaonema-silver-bay", "银皇后", "Aglaonema Silver Bay", ["silver bay chinese evergreen"], .lowLightToxic),
        CatalogSeed("aglaonema-red-siam", "红暹罗万年青", "Aglaonema Red Siam", ["red siam aglaonema"], .lowLightToxic),
        CatalogSeed("pilea-cadierei", "冷水花", "Pilea cadierei", ["aluminum plant"], .petSafeEasy),
        CatalogSeed("peperomia-caperata", "皱叶椒草", "Peperomia caperata", ["emerald ripple peperomia"], .peperomia),
        CatalogSeed("peperomia-hope", "希望椒草", "Peperomia Hope", ["peperomia tetraphylla hope"], .peperomia),
        CatalogSeed("dracaena-angolensis", "棒叶虎尾兰", "Dracaena angolensis", ["cylindrical snake plant"], .lowLightToxic),
        CatalogSeed("dracaena-sanderiana", "富贵竹", "Dracaena sanderiana", ["lucky bamboo"], .lowLightToxic),
        CatalogSeed("caladium-bicolor", "五彩芋", "Caladium bicolor", ["caladium"], .aroidAdvanced),
        CatalogSeed("cyclamen-persicum", "仙客来", "Cyclamen persicum", ["cyclamen"], .floweringToxic),
        CatalogSeed("phalaenopsis-amabilis", "蝴蝶兰", "Phalaenopsis amabilis", ["moth orchid"], .orchid),
        CatalogSeed("dendrobium-nobile", "石斛兰", "Dendrobium nobile", ["dendrobium orchid"], .orchid),
        CatalogSeed("guzmania-lingulata", "擎天凤梨", "Guzmania lingulata", ["scarlet star bromeliad"], .bromeliad),
        CatalogSeed("vriesea-splendens", "火剑凤梨", "Vriesea splendens", ["flaming sword"], .bromeliad),
        CatalogSeed("tillandsia-ionantha", "空气凤梨", "Tillandsia ionantha", ["air plant"], .bromeliadAdvanced),
        CatalogSeed("cryptanthus-bivittatus", "姬凤梨", "Cryptanthus bivittatus", ["earth star"], .bromeliad),
        CatalogSeed("philodendron-gloriosum", "荣耀蔓绿绒", "Philodendron gloriosum", ["gloriosum philodendron"], .aroidAdvanced),
        CatalogSeed("philodendron-prince-of-orange", "橙王子蔓绿绒", "Philodendron Prince of Orange", ["prince of orange philodendron"], .aroid),
        CatalogSeed("philodendron-rojo-congo", "红刚果蔓绿绒", "Philodendron Rojo Congo", ["rojo congo philodendron"], .aroid),
        CatalogSeed("philodendron-xanadu", "小天使蔓绿绒", "Thaumatophyllum xanadu", ["xanadu philodendron"], .aroid),
        CatalogSeed("scindapsus-pictus-exotica", "大叶银斑葛", "Scindapsus pictus Exotica", ["satin pothos exotica"], .aroidVine),
        CatalogSeed("scindapsus-pictus-argyraeus", "银星葛", "Scindapsus pictus Argyraeus", ["argyraeus pothos"], .aroidVine),
        CatalogSeed("epipremnum-aureum-marble-queen", "雪花绿萝", "Epipremnum aureum Marble Queen", ["marble queen pothos"], .aroidVine),
        CatalogSeed("epipremnum-aureum-njoy", "N'Joy 绿萝", "Epipremnum aureum N'Joy", ["njoy pothos"], .aroidVine),
        CatalogSeed("epipremnum-aureum-manjula", "曼珠绿萝", "Epipremnum aureum Manjula", ["manjula pothos"], .aroidVine),
        CatalogSeed("epipremnum-aureum-global-green", "环球绿萝", "Epipremnum aureum Global Green", ["global green pothos"], .aroidVine),
        CatalogSeed("monstera-thai-constellation", "泰国星座龟背竹", "Monstera deliciosa Thai Constellation", ["thai constellation monstera"], .aroidAdvanced),
        CatalogSeed("monstera-albo-variegata", "白锦龟背竹", "Monstera deliciosa Albo Variegata", ["albo monstera"], .aroidAdvanced),
        CatalogSeed("monstera-siltepecana", "银脉龟背藤", "Monstera siltepecana", ["silver monstera"], .aroid),
        CatalogSeed("rhaphidophora-decursiva", "龙鳞藤", "Rhaphidophora decursiva", ["dragon tail plant"], .aroid),
        CatalogSeed("syngonium-neon-robusta", "粉合果芋", "Syngonium Neon Robusta", ["pink arrowhead plant"], .aroid),
        CatalogSeed("syngonium-albo-variegatum", "白锦合果芋", "Syngonium podophyllum Albo Variegatum", ["variegated arrowhead plant"], .aroidAdvanced),
        CatalogSeed("aglaonema-pictum-tricolor", "迷彩万年青", "Aglaonema pictum Tricolor", ["camouflage aglaonema"], .lowLightToxic),
        CatalogSeed("aglaonema-pink-valentine", "粉色万年青", "Aglaonema Pink Valentine", ["pink valentine aglaonema"], .lowLightToxic),
        CatalogSeed("dieffenbachia-camille", "卡米拉花叶万年青", "Dieffenbachia Camille", ["camille dumb cane"], .lowLightToxic),
        CatalogSeed("dieffenbachia-tropic-snow", "雪斑万年青", "Dieffenbachia Tropic Snow", ["tropic snow dumb cane"], .lowLightToxic),
        CatalogSeed("calathea-lancifolia", "响尾蛇竹芋", "Goeppertia insignis", ["rattlesnake plant"], .prayerPlant),
        CatalogSeed("calathea-roseopicta", "玫瑰竹芋", "Goeppertia roseopicta", ["rose painted calathea"], .prayerPlant),
        CatalogSeed("calathea-medallion", "勋章竹芋", "Goeppertia veitchiana Medallion", ["medallion calathea"], .prayerPlant),
        CatalogSeed("ctenanthe-burle-marxii", "鱼骨竹芋", "Ctenanthe burle-marxii", ["fishbone prayer plant"], .prayerPlant),
        CatalogSeed("ctenanthe-setosa", "灰星竹芋", "Ctenanthe setosa", ["grey star ctenanthe"], .prayerPlant),
        CatalogSeed("maranta-kim", "锦叶豹纹竹芋", "Maranta leuconeura Kim", ["kim prayer plant"], .prayerPlant),
        CatalogSeed("peperomia-rosso", "红背椒草", "Peperomia Rosso", ["rosso peperomia"], .peperomia),
        CatalogSeed("peperomia-graveolens", "红边豆瓣绿", "Peperomia graveolens", ["ruby glow peperomia"], .peperomia),
        CatalogSeed("peperomia-raindrop", "雨滴椒草", "Peperomia polybotrya", ["raindrop peperomia"], .peperomia),
        CatalogSeed("pilea-glauca", "蓝叶冷水花", "Pilea glauca", ["silver sparkle pilea"], .petSafeEasy),
        CatalogSeed("pilea-depressa", "迷你冷水花", "Pilea depressa", ["baby tears pilea"], .petSafeMoist),
        CatalogSeed("hoya-obovata", "圆叶球兰", "Hoya obovata", ["obovata hoya"], .hoya),
        CatalogSeed("hoya-compacta", "卷叶球兰", "Hoya carnosa Compacta", ["hindu rope hoya"], .hoya),
        CatalogSeed("hoya-australis", "澳洲球兰", "Hoya australis", ["australis hoya"], .hoya),
        CatalogSeed("hoya-mathilde", "玛蒂尔达球兰", "Hoya Mathilde", ["mathilde hoya"], .hoya),
        CatalogSeed("ceropegia-linearis", "细叶爱之蔓", "Ceropegia linearis", ["string of needles"], .succulentSafe),
        CatalogSeed("dischidia-ovata", "西瓜藤", "Dischidia ovata", ["watermelon dischidia"], .hoya),
        CatalogSeed("senecio-radicans", "佛珠香蕉", "Curio radicans", ["string of bananas"], .succulentToxic),
        CatalogSeed("tradescantia-fluminensis", "白花紫露草", "Tradescantia fluminensis", ["wandering jew plant"], .petIrritant),
        CatalogSeed("tradescantia-nanouk", "粉紫露草", "Tradescantia Nanouk", ["nanouk tradescantia"], .petIrritant),
        CatalogSeed("episcia-cupreata", "红桐草", "Episcia cupreata", ["flame violet"], .petSafeFlowering),
        CatalogSeed("selaginella-kraussiana", "卷柏", "Selaginella kraussiana", ["spikemoss"], .petSafeMoist),
        CatalogSeed("selaginella-martensii", "翠云草", "Selaginella martensii", ["frosty fern"], .petSafeMoist),
        CatalogSeed("nephrolepis-cordifolia", "肾蕨", "Nephrolepis cordifolia", ["tuberous sword fern"], .fern),
        CatalogSeed("blechnum-gibbum", "银蕨", "Blechnum gibbum", ["silver lady fern"], .fern),
        CatalogSeed("pteris-cretica", "凤尾蕨", "Pteris cretica", ["cretan brake fern"], .fern),
        CatalogSeed("ficus-lyrata-bambino", "小提琴叶榕", "Ficus lyrata Bambino", ["bambino fiddle leaf fig"], .ficus),
        CatalogSeed("ficus-alii", "长叶榕", "Ficus binnendijkii Alii", ["alii ficus"], .ficus),
        CatalogSeed("ficus-audrey", "奥黛丽榕", "Ficus benghalensis Audrey", ["audrey ficus"], .ficus),
        CatalogSeed("ficus-pumila", "爬墙虎榕", "Ficus pumila", ["creeping fig"], .trailingToxic),
        CatalogSeed("schefflera-actinophylla", "大叶鹅掌柴", "Schefflera actinophylla", ["octopus tree"], .woodyToxic),
        CatalogSeed("polyscias-scutellaria-fabian", "法比安南洋森", "Polyscias scutellaria Fabian", ["fabian aralia"], .woodyToxic),
        CatalogSeed("dracaena-compacta", "密叶龙血树", "Dracaena fragrans Compacta", ["compact dracaena"], .lowLightToxic),
        CatalogSeed("dracaena-lemon-lime", "柠檬青龙血树", "Dracaena Lemon Lime", ["lemon lime dracaena"], .lowLightToxic),
        CatalogSeed("dracaena-gold-star", "金星龙血树", "Dracaena Gold Star", ["gold star dracaena"], .lowLightToxic),
        CatalogSeed("aspidistra-elatior", "一叶兰", "Aspidistra elatior", ["cast iron plant"], .petSafeEasy),
        CatalogSeed("chlorophytum-comosum-bonnie", "卷叶吊兰", "Chlorophytum comosum Bonnie", ["bonnie spider plant"], .petSafeEasy),
        CatalogSeed("dracaena-trifasciata-moonshine", "月光虎尾兰", "Dracaena trifasciata Moonshine", ["moonshine snake plant"], .lowLightToxic),
        CatalogSeed("dracaena-trifasciata-golden-hahnii", "金边短叶虎尾兰", "Dracaena trifasciata Golden Hahnii", ["golden bird nest snake plant"], .lowLightToxic),
        CatalogSeed("chamaedorea-seifrizii", "竹棕", "Chamaedorea seifrizii", ["bamboo palm"], .palm),
        CatalogSeed("phoenix-roebelenii", "袖珍海枣", "Phoenix roebelenii", ["pygmy date palm"], .palm),
        CatalogSeed("cycas-revoluta", "苏铁", "Cycas revoluta", ["sago palm"], .woodyToxic),
        CatalogSeed("ravenea-rivularis", "国王椰子", "Ravenea rivularis", ["majesty palm"], .palm),
        CatalogSeed("alocasia-frydek", "绿天鹅绒海芋", "Alocasia micholitziana Frydek", ["frydek alocasia"], .aroidAdvanced),
        CatalogSeed("alocasia-black-velvet", "黑天鹅绒海芋", "Alocasia reginula", ["black velvet alocasia"], .aroidAdvanced),
        CatalogSeed("alocasia-zebrina", "斑马海芋", "Alocasia zebrina", ["zebrina alocasia"], .aroidAdvanced),
        CatalogSeed("anthurium-crystallinum", "水晶花烛", "Anthurium crystallinum", ["crystal anthurium"], .aroidAdvanced),
        CatalogSeed("anthurium-warocqueanum", "皇后花烛", "Anthurium warocqueanum", ["queen anthurium"], .aroidAdvanced),
        CatalogSeed("begonia-escargot", "蜗牛秋海棠", "Begonia Escargot", ["escargot begonia"], .floweringToxic),
        CatalogSeed("begonia-angel-wing", "天使翼秋海棠", "Begonia Angel Wing", ["angel wing begonia"], .floweringToxic),
        CatalogSeed("begonia-erythrophylla", "牛排秋海棠", "Begonia erythrophylla", ["beefsteak begonia"], .floweringToxic),
        CatalogSeed("sinningia-speciosa", "大岩桐", "Sinningia speciosa", ["gloxinia"], .petSafeFlowering),
        CatalogSeed("nematanthus-gregarius", "金鱼花", "Nematanthus gregarius", ["goldfish plant"], .petSafeFlowering),
        CatalogSeed("columnea-gloriosa", "鲸鱼花", "Columnea gloriosa", ["columnea"], .petSafeFlowering),
        CatalogSeed("eschynanthus-radicans", "口红花", "Aeschynanthus radicans", ["lipstick plant"], .petSafeFlowering),
        CatalogSeed("schlumbergera-bridgesii", "圣诞仙人掌", "Schlumbergera bridgesii", ["christmas cactus"], .succulentSafe),
        CatalogSeed("hatiora-salicornioides", "珊瑚仙人掌", "Hatiora salicornioides", ["dancing bones cactus"], .succulentSafe),
        CatalogSeed("rhipsalis-cereuscula", "米粒仙人掌", "Rhipsalis cereuscula", ["rice cactus"], .succulentSafe),
        CatalogSeed("epiphyllum-anguliger", "鱼骨令箭", "Disocactus anguliger", ["fishbone cactus"], .succulentSafe),
        CatalogSeed("aloe-aristata", "绫锦芦荟", "Aristaloe aristata", ["lace aloe"], .succulentSafe),
        CatalogSeed("aloe-humilis", "矮芦荟", "Aloe humilis", ["spider aloe"], .succulentToxic),
        CatalogSeed("haworthia-cooperi", "水晶寿", "Haworthia cooperi", ["cooper haworthia"], .succulentSafe),
        CatalogSeed("gasteria-little-warty", "小疣卧牛", "Gasteria Little Warty", ["little warty gasteria"], .succulentSafe),
        CatalogSeed("echeveria-perle-von-nurnberg", "紫珍珠", "Echeveria Perle von Nurnberg", ["perle von nurnberg echeveria"], .succulentSafe),
        CatalogSeed("echeveria-lola", "劳尔拟石莲", "Echeveria Lola", ["lola echeveria"], .succulentSafe),
        CatalogSeed("graptopetalum-paraguayense", "胧月", "Graptopetalum paraguayense", ["ghost plant"], .succulentSafe),
        CatalogSeed("graptoveria-fred-ives", "弗雷德多肉", "Graptoveria Fred Ives", ["fred ives succulent"], .succulentSafe),
        CatalogSeed("sedum-rubrotinctum", "虹之玉", "Sedum rubrotinctum", ["jelly bean plant"], .succulentSafe),
        CatalogSeed("sedum-adolphii", "铭月", "Sedum adolphii", ["golden sedum"], .succulentSafe),
        CatalogSeed("crassula-muscosa", "青锁龙", "Crassula muscosa", ["watch chain plant"], .succulentToxic),
        CatalogSeed("crassula-perforata", "串钱景天", "Crassula perforata", ["string of buttons"], .succulentToxic),
        CatalogSeed("portulacaria-afra", "金枝玉叶", "Portulacaria afra", ["elephant bush"], .succulentSafe),
        CatalogSeed("pachyphytum-oviferum", "桃美人", "Pachyphytum oviferum", ["moonstones succulent"], .succulentSafe),
        CatalogSeed("sempervivum-tectorum", "观音莲", "Sempervivum tectorum", ["hens and chicks"], .succulentSafe),
        CatalogSeed("kalanchoe-tomentosa", "月兔耳", "Kalanchoe tomentosa", ["panda plant"], .succulentToxic),
        CatalogSeed("kalanchoe-thyrsiflora", "唐印", "Kalanchoe thyrsiflora", ["paddle plant"], .succulentToxic),
        CatalogSeed("euphorbia-milii", "虎刺梅", "Euphorbia milii", ["crown of thorns"], .euphorbia),
        CatalogSeed("euphorbia-lactea", "白斑麒麟", "Euphorbia lactea", ["dragon bones tree"], .euphorbia),
        CatalogSeed("cereus-repandus", "秘鲁天轮柱", "Cereus repandus", ["peruvian apple cactus"], .cactus),
        CatalogSeed("echinocactus-grusonii", "金琥", "Echinocactus grusonii", ["golden barrel cactus"], .cactus),
        CatalogSeed("parodia-leninghausii", "金晃丸", "Parodia leninghausii", ["golden ball cactus"], .cactus),
        CatalogSeed("myrtillocactus-geometrizans", "蓝柱", "Myrtillocactus geometrizans", ["blue candle cactus"], .cactus),
        CatalogSeed("disocactus-ackermannii", "红花令箭", "Disocactus ackermannii", ["red orchid cactus"], .succulentSafe),
        CatalogSeed("asparagus-densiflorus", "狐尾武竹", "Asparagus densiflorus", ["foxtail fern"], .petIrritant),
        CatalogSeed("codiaeum-petra", "佩特拉变叶木", "Codiaeum variegatum Petra", ["petra croton"], .woodyToxic),
        CatalogSeed("strelitzia-reginae", "鹤望兰", "Strelitzia reginae", ["orange bird of paradise"], .woodyToxic),
        CatalogSeed("citrus-calamondin", "四季桔", "Citrus microcarpa", ["calamondin orange"], .sunnyToxic),
        CatalogSeed("olea-europaea", "橄榄树", "Olea europaea", ["olive tree"], .sunnyPetIrritant),
        CatalogSeed("ficus-carica", "无花果", "Ficus carica", ["fig tree"], .sunnyToxic),
        CatalogSeed("thymus-vulgaris", "百里香", "Thymus vulgaris", ["thyme"], .herb),
        CatalogSeed("origanum-vulgare", "牛至", "Origanum vulgare", ["oregano"], .herb),
        CatalogSeed("petroselinum-crispum", "欧芹", "Petroselinum crispum", ["parsley"], .herb),
        CatalogSeed("coriandrum-sativum", "香菜", "Coriandrum sativum", ["cilantro", "coriander"], .herb),
        CatalogSeed("capsicum-annuum", "观赏辣椒", "Capsicum annuum", ["ornamental pepper"], .sunnyPetIrritant),
        CatalogSeed("fragaria-vesca", "草莓", "Fragaria vesca", ["wild strawberry"], .herb),
        CatalogSeed("pelargonium-zonale", "天竺葵", "Pelargonium zonale", ["zonal geranium"], .floweringToxic),
        CatalogSeed("hibiscus-rosa-sinensis", "扶桑", "Hibiscus rosa-sinensis", ["hibiscus"], .petSafeFlowering),
        CatalogSeed("bougainvillea-glabra", "三角梅", "Bougainvillea glabra", ["bougainvillea"], .sunnyPetIrritant),
        CatalogSeed("passiflora-caerulea", "蓝花西番莲", "Passiflora caerulea", ["passion flower"], .petSafeFlowering),
        CatalogSeed("jasminum-sambac", "茉莉花", "Jasminum sambac", ["arabian jasmine"], .petSafeFlowering),
        CatalogSeed("stephanotis-floribunda", "非洲茉莉藤", "Stephanotis floribunda", ["madagascar jasmine"], .petSafeFlowering),
        CatalogSeed("oncidium-sharry-baby", "巧克力文心兰", "Oncidium Sharry Baby", ["sharry baby orchid"], .orchid),
        CatalogSeed("paphiopedilum-maudiae", "兜兰", "Paphiopedilum Maudiae", ["lady slipper orchid"], .orchid),
        CatalogSeed("cattleya-hybrid", "卡特兰", "Cattleya Hybrid", ["cattleya orchid"], .orchid),
        CatalogSeed("ludisia-discolor", "宝石兰", "Ludisia discolor", ["jewel orchid"], .orchid),
        CatalogSeed("aechmea-fasciata", "银叶凤梨", "Aechmea fasciata", ["silver vase bromeliad"], .bromeliad),
        CatalogSeed("neoregelia-carolinae", "彩叶凤梨", "Neoregelia carolinae", ["blushing bromeliad"], .bromeliad),
        CatalogSeed("tillandsia-xerographica", "霸王空气凤梨", "Tillandsia xerographica", ["xerographica air plant"], .bromeliadAdvanced)
    ]

    private enum CatalogCareProfile {
        case aroid
        case aroidVine
        case aroidAdvanced
        case lowLightToxic
        case prayerPlant
        case peperomia
        case petSafeEasy
        case petSafeMoist
        case hoya
        case hoyaAdvanced
        case petIrritant
        case fern
        case fernAdvanced
        case ficus
        case woodyToxic
        case petSafeWoody
        case palm
        case petSafeBright
        case trailingToxic
        case petSafeFlowering
        case floweringToxic
        case succulentSafe
        case succulentToxic
        case succulentAdvanced
        case euphorbia
        case cactus
        case sunnyToxic
        case sunnyPetIrritant
        case herb
        case orchid
        case bromeliad
        case bromeliadAdvanced
    }

    private struct CatalogSeed {
        let id: String
        let commonName: String
        let latinName: String
        let aliases: [String]
        let profile: CatalogCareProfile

        init(
            _ id: String,
            _ commonName: String,
            _ latinName: String,
            _ aliases: [String],
            _ profile: CatalogCareProfile
        ) {
            self.id = id
            self.commonName = commonName
            self.latinName = latinName
            self.aliases = aliases
            self.profile = profile
        }
    }

    private struct CatalogCareDefaults {
        let light: PlantLightLevel
        let watering: String
        let humidity: String
        let temperature: String
        let soil: String
        let fertilizing: String
        let propagation: String
        let pruning: String
        let commonIssues: String
        let toxicity: String
        let difficulty: String
        let toxicCats: Bool
        let toxicDogs: Bool
        let toxicChildren: Bool
        let indoor: Bool
        let wateringDays: Int
        let fertilizingDays: Int
    }

    private static func makeEntry(_ seed: CatalogSeed) -> PlantCatalogEntry {
        let defaults = defaults(for: seed.profile)
        return PlantCatalogEntry(
            id: seed.id,
            commonName: seed.commonName,
            latinName: seed.latinName,
            aliases: seed.aliases,
            imageName: PlantCatalogMedia.bundledAvatarAssetName(forCatalogID: seed.id),
            lightRequirement: defaults.light,
            wateringPreference: defaults.watering,
            humidity: defaults.humidity,
            temperature: defaults.temperature,
            soil: defaults.soil,
            fertilizing: defaults.fertilizing,
            propagation: defaults.propagation,
            pruning: defaults.pruning,
            commonIssues: defaults.commonIssues,
            toxicity: defaults.toxicity,
            careDifficulty: defaults.difficulty,
            isToxicToCats: defaults.toxicCats,
            isToxicToDogs: defaults.toxicDogs,
            isToxicToChildren: defaults.toxicChildren,
            isIndoorSuitable: defaults.indoor,
            defaultWateringDays: defaults.wateringDays,
            defaultFertilizingDays: defaults.fertilizingDays
        )
    }

    private static func defaults(for profile: CatalogCareProfile) -> CatalogCareDefaults {
        switch profile {
        case .aroid:
            toxicAroid(wateringDays: 7, fertilizingDays: 30, difficulty: "中等")
        case .aroidVine:
            toxicAroid(wateringDays: 7, fertilizingDays: 35, difficulty: "简单")
        case .aroidAdvanced:
            toxicAroid(wateringDays: 5, fertilizingDays: 28, difficulty: "进阶")
        case .lowLightToxic:
            CatalogCareDefaults(
                light: .medium,
                watering: "土壤大半干后再浇，弱光环境延长间隔",
                humidity: "普通室内湿度即可",
                temperature: "18-30 C",
                soil: "疏松排水型通用土",
                fertilizing: "生长期每 6-8 周薄肥",
                propagation: "分株或茎段扦插",
                pruning: "剪除黄叶和受损叶片",
                commonIssues: "黄叶多与积水、低温或长期弱光有关",
                toxicity: "对猫狗有误食风险，儿童也应避免入口",
                difficulty: "简单",
                toxicCats: true,
                toxicDogs: true,
                toxicChildren: true,
                indoor: true,
                wateringDays: 14,
                fertilizingDays: 60
            )
        case .prayerPlant:
            CatalogCareDefaults(
                light: .brightIndirect,
                watering: "保持微湿但不积水，避免完全干透",
                humidity: "偏高湿度更佳",
                temperature: "18-28 C，避免冷风和干热风",
                soil: "保水但透气的观叶土",
                fertilizing: "生长期每 4 周半量肥",
                propagation: "分株或带节点扦插",
                pruning: "剪除卷曲、焦边或老叶",
                commonIssues: "焦边常见于低湿、硬水、盐分或直晒",
                toxicity: "通常对猫狗低风险",
                difficulty: "进阶",
                toxicCats: false,
                toxicDogs: false,
                toxicChildren: false,
                indoor: true,
                wateringDays: 5,
                fertilizingDays: 30
            )
        case .peperomia:
            petSafeCompact(wateringDays: 10, fertilizingDays: 45, light: .brightIndirect, difficulty: "简单")
        case .petSafeEasy:
            petSafeCompact(wateringDays: 7, fertilizingDays: 40, light: .medium, difficulty: "简单")
        case .petSafeMoist:
            CatalogCareDefaults(
                light: .medium,
                watering: "保持轻微湿润，避免暴晒和彻底干透",
                humidity: "偏高湿度更佳",
                temperature: "16-26 C",
                soil: "细颗粒保水型通用土",
                fertilizing: "生长期每 4-6 周薄肥",
                propagation: "分株或枝条扦插",
                pruning: "修剪过密枝叶保持通风",
                commonIssues: "干枯常见于缺水、低湿或强光",
                toxicity: "通常对猫狗低风险",
                difficulty: "中等",
                toxicCats: false,
                toxicDogs: false,
                toxicChildren: false,
                indoor: true,
                wateringDays: 4,
                fertilizingDays: 35
            )
        case .hoya:
            hoyaDefaults(wateringDays: 10, fertilizingDays: 45, difficulty: "中等")
        case .hoyaAdvanced:
            hoyaDefaults(wateringDays: 8, fertilizingDays: 35, difficulty: "进阶")
        case .petIrritant:
            CatalogCareDefaults(
                light: .brightIndirect,
                watering: "表土变干后浇透，避免长期积水",
                humidity: "普通到偏高湿度",
                temperature: "18-28 C",
                soil: "排水良好的通用土",
                fertilizing: "生长期每 4-6 周薄肥",
                propagation: "枝条扦插或分株",
                pruning: "修剪徒长枝和受损叶",
                commonIssues: "徒长多与光照不足有关，焦边多与干燥有关",
                toxicity: "可能刺激宠物或儿童口腔，避免误食",
                difficulty: "简单",
                toxicCats: true,
                toxicDogs: true,
                toxicChildren: false,
                indoor: true,
                wateringDays: 7,
                fertilizingDays: 35
            )
        case .fern:
            fernDefaults(wateringDays: 4, fertilizingDays: 35, difficulty: "中等")
        case .fernAdvanced:
            fernDefaults(wateringDays: 3, fertilizingDays: 30, difficulty: "进阶")
        case .ficus:
            CatalogCareDefaults(
                light: .brightIndirect,
                watering: "表土明显变干后浇透，保持节奏稳定",
                humidity: "普通到中高湿度",
                temperature: "18-29 C，避免冷风",
                soil: "排水良好的室内观叶土",
                fertilizing: "春夏每月薄肥",
                propagation: "枝条扦插或压条",
                pruning: "修剪过密枝叶，保持树形",
                commonIssues: "掉叶常见于搬动、冷风、过浇或光照变化",
                toxicity: "汁液可能刺激猫狗和儿童，避免误食",
                difficulty: "进阶",
                toxicCats: true,
                toxicDogs: true,
                toxicChildren: true,
                indoor: true,
                wateringDays: 7,
                fertilizingDays: 30
            )
        case .woodyToxic:
            woodyDefaults(toxic: true, wateringDays: 8, fertilizingDays: 35, difficulty: "中等")
        case .petSafeWoody:
            woodyDefaults(toxic: false, wateringDays: 7, fertilizingDays: 35, difficulty: "中等")
        case .palm:
            CatalogCareDefaults(
                light: .brightIndirect,
                watering: "表土 2-3 cm 变干后浇透",
                humidity: "普通到偏高湿度",
                temperature: "18-30 C",
                soil: "排水良好的棕榈或观叶土",
                fertilizing: "生长期每 4-6 周薄肥",
                propagation: "多为分株或种子，家庭繁殖较慢",
                pruning: "只剪除完全枯黄叶片",
                commonIssues: "叶尖焦枯常见于低湿、盐分或缺水",
                toxicity: "通常对猫狗低风险",
                difficulty: "中等",
                toxicCats: false,
                toxicDogs: false,
                toxicChildren: false,
                indoor: true,
                wateringDays: 7,
                fertilizingDays: 40
            )
        case .petSafeBright:
            petSafeCompact(wateringDays: 5, fertilizingDays: 30, light: .brightIndirect, difficulty: "中等")
        case .trailingToxic:
            toxicAroid(wateringDays: 6, fertilizingDays: 35, difficulty: "简单")
        case .petSafeFlowering:
            floweringDefaults(toxic: false, wateringDays: 5, fertilizingDays: 28, difficulty: "中等")
        case .floweringToxic:
            floweringDefaults(toxic: true, wateringDays: 5, fertilizingDays: 28, difficulty: "中等")
        case .succulentSafe:
            succulentDefaults(toxic: false, wateringDays: 16, fertilizingDays: 60, difficulty: "简单")
        case .succulentToxic:
            succulentDefaults(toxic: true, wateringDays: 18, fertilizingDays: 60, difficulty: "简单")
        case .succulentAdvanced:
            succulentDefaults(toxic: false, wateringDays: 24, fertilizingDays: 75, difficulty: "进阶")
        case .euphorbia:
            CatalogCareDefaults(
                light: .direct,
                watering: "土壤完全干透后少量浇透，冬季大幅减少",
                humidity: "耐普通偏干环境",
                temperature: "18-30 C",
                soil: "仙人掌或多肉型排水土",
                fertilizing: "生长期 6-8 周一次低浓度肥",
                propagation: "枝条晾干伤口后扦插",
                pruning: "戴手套处理折断或过长枝条",
                commonIssues: "腐烂多由低温积水导致，徒长多与光照不足有关",
                toxicity: "白色汁液有刺激性，远离猫狗和儿童",
                difficulty: "中等",
                toxicCats: true,
                toxicDogs: true,
                toxicChildren: true,
                indoor: true,
                wateringDays: 20,
                fertilizingDays: 60
            )
        case .cactus:
            succulentDefaults(toxic: false, wateringDays: 21, fertilizingDays: 75, difficulty: "中等")
        case .sunnyToxic:
            sunnyDefaults(toxic: true, wateringDays: 4, fertilizingDays: 21, difficulty: "进阶")
        case .sunnyPetIrritant:
            sunnyDefaults(toxic: true, wateringDays: 5, fertilizingDays: 28, difficulty: "中等")
        case .herb:
            sunnyDefaults(toxic: false, wateringDays: 3, fertilizingDays: 21, difficulty: "简单")
        case .orchid:
            CatalogCareDefaults(
                light: .brightIndirect,
                watering: "介质接近干透后浇透，避免叶心积水",
                humidity: "中高湿更佳但要通风",
                temperature: "18-28 C，昼夜温差有利开花",
                soil: "兰花树皮、水苔或颗粒介质",
                fertilizing: "生长期每 2-4 周低浓度兰花肥",
                propagation: "分株或高芽繁殖",
                pruning: "花后剪除枯萎花梗",
                commonIssues: "烂根常见于介质长期潮湿或通风不足",
                toxicity: "通常对猫狗低风险",
                difficulty: "中等",
                toxicCats: false,
                toxicDogs: false,
                toxicChildren: false,
                indoor: true,
                wateringDays: 7,
                fertilizingDays: 21
            )
        case .bromeliad:
            bromeliadDefaults(wateringDays: 7, fertilizingDays: 45, difficulty: "中等")
        case .bromeliadAdvanced:
            bromeliadDefaults(wateringDays: 4, fertilizingDays: 45, difficulty: "进阶")
        }
    }

    private static func toxicAroid(wateringDays: Int, fertilizingDays: Int, difficulty: String) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .brightIndirect,
            watering: "表土 2-3 cm 变干后浇透，避免盆底积水",
            humidity: "普通到偏高湿度",
            temperature: "18-30 C",
            soil: "树皮、珍珠岩和通用土混合的疏松介质",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "带节点茎插或分株",
            pruning: "剪除老叶和过长藤蔓",
            commonIssues: "黄叶常见于过浇、低温或光照突变",
            toxicity: "含刺激性草酸钙，远离猫狗和儿童",
            difficulty: difficulty,
            toxicCats: true,
            toxicDogs: true,
            toxicChildren: true,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func petSafeCompact(
        wateringDays: Int,
        fertilizingDays: Int,
        light: PlantLightLevel,
        difficulty: String
    ) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: light,
            watering: "表土变干后浇透，避免长期积水",
            humidity: "普通室内湿度即可",
            temperature: "18-28 C",
            soil: "排水良好的通用土",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "分株、叶插或枝条扦插",
            pruning: "剪除老叶和受损叶",
            commonIssues: "徒长多与光照不足有关，黄叶多与过浇有关",
            toxicity: "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: false,
            toxicDogs: false,
            toxicChildren: false,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func hoyaDefaults(wateringDays: Int, fertilizingDays: Int, difficulty: String) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .brightIndirect,
            watering: "介质大半干后再浇，耐短暂偏干",
            humidity: "普通到偏高湿度",
            temperature: "18-30 C",
            soil: "树皮、珍珠岩和粗颗粒混合介质",
            fertilizing: "生长期每 4-6 周薄肥",
            propagation: "带节点枝条扦插",
            pruning: "保留花梗，只修剪枯枝和过长藤蔓",
            commonIssues: "不开花常见于光照不足或频繁移动",
            toxicity: "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: false,
            toxicDogs: false,
            toxicChildren: false,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func fernDefaults(wateringDays: Int, fertilizingDays: Int, difficulty: String) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .medium,
            watering: "保持轻微湿润，避免完全干透",
            humidity: "偏高湿度更佳",
            temperature: "16-26 C",
            soil: "保水但透气的蕨类或观叶土",
            fertilizing: "生长期每 4-6 周低浓度肥",
            propagation: "分株或孢子，家庭以分株为主",
            pruning: "剪除枯黄羽叶保持通风",
            commonIssues: "焦叶常见于低湿、缺水或强光",
            toxicity: "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: false,
            toxicDogs: false,
            toxicChildren: false,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func woodyDefaults(
        toxic: Bool,
        wateringDays: Int,
        fertilizingDays: Int,
        difficulty: String
    ) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .brightIndirect,
            watering: "表土明显变干后浇透，避免忽干忽湿",
            humidity: "普通到中高湿度",
            temperature: "18-29 C",
            soil: "排水良好的观叶或木本植物土",
            fertilizing: "生长期每月薄肥",
            propagation: "枝条扦插或压条",
            pruning: "修剪徒长枝和交叉枝，保持株形",
            commonIssues: "掉叶常见于搬动、冷风、积水或长期弱光",
            toxicity: toxic ? "可能刺激猫狗或儿童，避免误食" : "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: toxic,
            toxicDogs: toxic,
            toxicChildren: toxic,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func floweringDefaults(
        toxic: Bool,
        wateringDays: Int,
        fertilizingDays: Int,
        difficulty: String
    ) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .brightIndirect,
            watering: "表土变干后浇透，花期避免长期缺水",
            humidity: "普通到偏高湿度",
            temperature: "16-28 C",
            soil: "疏松排水型开花植物土",
            fertilizing: "生长期或花期每 2-4 周薄肥",
            propagation: "分株、叶插或枝条扦插，依品种而定",
            pruning: "摘除残花和黄叶，保持通风",
            commonIssues: "不开花常见于光照不足、温差不足或肥水不稳",
            toxicity: toxic ? "可能对猫狗和儿童有误食风险" : "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: toxic,
            toxicDogs: toxic,
            toxicChildren: toxic,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func succulentDefaults(
        toxic: Bool,
        wateringDays: Int,
        fertilizingDays: Int,
        difficulty: String
    ) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .direct,
            watering: "土壤完全干透后再浇透，冬季减少",
            humidity: "耐普通偏干环境",
            temperature: "16-30 C，避免低温潮湿",
            soil: "多肉或仙人掌型排水土",
            fertilizing: "生长期 6-8 周一次低浓度肥",
            propagation: "叶插、枝插或分株",
            pruning: "剪除徒长、腐烂或干枯部分",
            commonIssues: "徒长多与光照不足有关，根腐多与过浇有关",
            toxicity: toxic ? "可能对猫狗有误食风险，放在够不到处" : "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: toxic,
            toxicDogs: toxic,
            toxicChildren: false,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func sunnyDefaults(
        toxic: Bool,
        wateringDays: Int,
        fertilizingDays: Int,
        difficulty: String
    ) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .direct,
            watering: "光照充足时保持规律浇透，盆土表层变干后再浇",
            humidity: "普通室内湿度即可",
            temperature: "16-30 C",
            soil: "排水良好的通用土或香草土",
            fertilizing: "生长期每 2-4 周薄肥",
            propagation: "枝条扦插、分株或播种",
            pruning: "定期摘心或修剪，保持株形和通风",
            commonIssues: "徒长常见于光照不足，萎蔫常见于缺水或根系受损",
            toxicity: toxic ? "可能刺激猫狗或儿童，避免误食" : "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: toxic,
            toxicDogs: toxic,
            toxicChildren: false,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    private static func bromeliadDefaults(wateringDays: Int, fertilizingDays: Int, difficulty: String) -> CatalogCareDefaults {
        CatalogCareDefaults(
            light: .brightIndirect,
            watering: "保持叶杯或介质微湿，定期换水防止腐烂",
            humidity: "中高湿更佳但要通风",
            temperature: "18-30 C",
            soil: "凤梨或兰花型疏松介质",
            fertilizing: "生长期每 6-8 周低浓度肥",
            propagation: "母株开花后侧芽分株",
            pruning: "剪除枯花和老化叶片",
            commonIssues: "叶心腐烂常见于积水不换或低温",
            toxicity: "通常对猫狗低风险",
            difficulty: difficulty,
            toxicCats: false,
            toxicDogs: false,
            toxicChildren: false,
            indoor: true,
            wateringDays: wateringDays,
            fertilizingDays: fertilizingDays
        )
    }

    static func entry(id: String) -> PlantCatalogEntry? {
        entries.first { $0.id == id }
    }

    static func search(_ query: String) -> [PlantCatalogEntry] {
        searchResults(query).map(\.entry)
    }

    static func searchResults(_ query: String, limit: Int? = nil) -> [PlantCatalogSearchResult] {
        let normalized = normalizedSearchText(query)
        guard !normalized.isEmpty else {
            let results = entries.map {
                PlantCatalogSearchResult(
                    entry: $0,
                    score: 0,
                    matchSummary: L10n.current.tr(zh: "常见室内植物", en: "Common indoor plant", de: "Häufige Zimmerpflanze")
                )
            }
            return limit.map { Array(results.prefix($0)) } ?? results
        }
        let tokens = normalized.split(separator: " ").map(String.init)
        let matches = entries.enumerated().compactMap { offset, entry -> (offset: Int, result: PlantCatalogSearchResult)? in
            let scored = searchScore(entry: entry, normalizedQuery: normalized, tokens: tokens)
            guard scored.score > 0 else { return nil }
            return (
                offset,
                PlantCatalogSearchResult(
                    entry: entry,
                    score: scored.score,
                    matchSummary: scored.labels.prefix(2).joined(separator: " · ")
                )
            )
        }
        let sorted = matches.sorted {
            if $0.result.score != $1.result.score {
                return $0.result.score > $1.result.score
            }
            return $0.offset < $1.offset
        }.map(\.result)
        return limit.map { Array(sorted.prefix($0)) } ?? sorted
    }

    static func bestMatch(commonName: String, latinName: String = "") -> PlantCatalogEntry? {
        let name = normalizedSearchText(commonName)
        let latin = normalizedSearchText(latinName)
        return entries.first { entry in
            normalizedSearchText(entry.commonName) == name ||
                normalizedSearchText(entry.latinName) == latin ||
                entry.aliases.contains {
                    let alias = normalizedSearchText($0)
                    return alias == name || alias == latin
                }
        }
    }

    private static func searchScore(
        entry: PlantCatalogEntry,
        normalizedQuery: String,
        tokens: [String]
    ) -> (score: Int, labels: [String]) {
        var score = 0
        var labels: [String] = []

        func matchScore(_ value: String, weight: Int) -> Int {
            let normalizedValue = normalizedSearchText(value)
            guard !normalizedValue.isEmpty else { return 0 }
            let exact = normalizedValue == normalizedQuery
            let prefix = normalizedValue.hasPrefix(normalizedQuery)
            let fullContains = normalizedValue.contains(normalizedQuery)
            let tokenHits = tokens.count(where: { normalizedValue.contains($0) })
            guard exact || prefix || fullContains || tokenHits > 0 else { return 0 }
            if exact { return weight * 5 }
            if prefix { return weight * 4 }
            if fullContains { return weight * 3 }
            return weight * tokenHits
        }

        func add(_ value: String, weight: Int, label: String) {
            let fieldScore = matchScore(value, weight: weight)
            guard fieldScore > 0 else { return }
            score += fieldScore
            if !labels.contains(label) {
                labels.append(label)
            }
        }

        func addBest(_ values: [String], weight: Int, label: String) {
            let bestScore = values.map { matchScore($0, weight: weight) }.max() ?? 0
            guard bestScore > 0 else { return }
            score += bestScore
            if !labels.contains(label) {
                labels.append(label)
            }
        }

        add(entry.commonName, weight: 24, label: L10n.current.tr(zh: "俗名", en: "Common name", de: "Trivialname"))
        add(entry.localizedCommonName, weight: 24, label: L10n.current.tr(zh: "俗名", en: "Common name", de: "Trivialname"))
        add(entry.latinName, weight: 22, label: L10n.current.tr(zh: "拉丁名", en: "Latin name", de: "Lateinischer Name"))
        addBest(entry.aliases, weight: 20, label: L10n.current.tr(zh: "别名", en: "Alias", de: "Alias"))
        add(entry.careDifficulty, weight: 10, label: L10n.current.tr(zh: "难度", en: "Difficulty", de: "Schwierigkeit"))
        add(entry.localizedCareDifficulty, weight: 10, label: L10n.current.tr(zh: "难度", en: "Difficulty", de: "Schwierigkeit"))
        add(entry.lightRequirement.displayName, weight: 9, label: L10n.current.tr(zh: "光照", en: "Light", de: "Licht"))
        add(entry.lightRequirement.rawValue, weight: 9, label: L10n.current.tr(zh: "光照", en: "Light", de: "Licht"))
        add(lightSearchText(for: entry), weight: 10, label: L10n.current.tr(zh: "光照", en: "Light", de: "Licht"))
        add(entry.wateringPreference, weight: 7, label: L10n.current.tr(zh: "浇水", en: "Watering", de: "Gießen"))
        add(entry.localizedWateringPreference, weight: 7, label: L10n.current.tr(zh: "浇水", en: "Watering", de: "Gießen"))
        add(entry.localizedSummary, weight: 7, label: L10n.current.tr(zh: "简介", en: "Summary", de: "Kurzinfo"))
        add(entry.localizedHabitNotes, weight: 7, label: L10n.current.tr(zh: "习性", en: "Habit", de: "Wuchs"))
        addBest(entry.localizedCareTips, weight: 6, label: L10n.current.tr(zh: "提示", en: "Tip", de: "Tipp"))
        addBest(entry.localizedCautionNotes, weight: 6, label: L10n.current.tr(zh: "注意", en: "Caution", de: "Achtung"))
        add(entry.humidity, weight: 7, label: L10n.current.tr(zh: "湿度", en: "Humidity", de: "Luftfeuchte"))
        add(entry.localizedHumidity, weight: 7, label: L10n.current.tr(zh: "湿度", en: "Humidity", de: "Luftfeuchte"))
        add(entry.soil, weight: 6, label: L10n.current.tr(zh: "土壤", en: "Soil", de: "Erde"))
        add(entry.localizedSoil, weight: 6, label: L10n.current.tr(zh: "土壤", en: "Soil", de: "Erde"))
        add(entry.toxicity, weight: 6, label: L10n.current.tr(zh: "安全", en: "Safety", de: "Sicherheit"))
        add(entry.localizedToxicity, weight: 6, label: L10n.current.tr(zh: "安全", en: "Safety", de: "Sicherheit"))
        add(safetySearchText(for: entry), weight: 8, label: L10n.current.tr(zh: "安全", en: "Safety", de: "Sicherheit"))
        return (score, labels.isEmpty ? [L10n.current.tr(zh: "匹配", en: "Match", de: "Treffer")] : labels)
    }

    private static func safetySearchText(for entry: PlantCatalogEntry) -> String {
        if entry.isToxicToCats || entry.isToxicToDogs || entry.isToxicToChildren {
            return "有毒 毒性 风险 toxic pet risk cat dog child 猫 狗 儿童"
        }
        return "宠物安全 低风险 pet safe cat safe dog safe child safe 猫 狗 儿童"
    }

    private static func lightSearchText(for entry: PlantCatalogEntry) -> String {
        switch entry.lightRequirement {
        case .low:
            "弱光 低光 low light shade"
        case .medium:
            entry.defaultWateringDays >= 12
                ? "中等光 耐弱光 低光 low light medium light"
                : "中等光 medium light"
        case .brightIndirect:
            "明亮散射光 bright indirect filtered light"
        case .direct:
            "直射光 全日照 direct sun bright light"
        }
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}

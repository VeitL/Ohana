//
//  PetAvatarAssetCatalog.swift
//  Ohana
//
//  Deterministic mapping from pet appearance selections to bundled avatar PNGs.
//

import Foundation

enum PetAvatarAssetCatalog {
    struct Appearance: Hashable {
        let coatName: String
        let coatSlug: String
        let coatHex: String
        let coatAliases: Set<String>
        let eyeName: String = "黑色"

        init(coatName: String, coatSlug: String, coatHex: String, coatAliases: [String] = []) {
            self.coatName = coatName
            self.coatSlug = coatSlug
            self.coatHex = coatHex
            self.coatAliases = Set(coatAliases)
        }

        func matches(coatColor: String) -> Bool {
            coatName == coatColor || coatAliases.contains(coatColor)
        }
    }

    static let assetDirectory = "PetAvatarAssets"

    private static let devonRexBreedNames: Set<String> = [
        "德文卷毛猫",
        "德文卷毛",
        "Devon Rex",
        "devon rex"
    ]

    private static let exoticShorthairBreedNames: Set<String> = [
        "异国短毛猫",
        "异国短毛",
        "异短",
        "加菲猫",
        "Exotic Shorthair",
        "exotic shorthair",
        "Exotic",
        "exotic"
    ]

    private static let munchkinBreedNames: Set<String> = [
        "曼基康猫",
        "曼基康",
        "短腿猫",
        "Munchkin",
        "munchkin",
        "Munchkin Cat",
        "munchkin cat"
    ]

    private static let birmanBreedNames: Set<String> = [
        "伯曼猫",
        "伯曼",
        "Birman",
        "birman",
        "Birman Cat",
        "birman cat"
    ]

    private static let siberianCatBreedNames: Set<String> = [
        "西伯利亚猫",
        "西伯利亚",
        "Siberian",
        "siberian",
        "Siberian Cat",
        "siberian cat"
    ]

    private static let britishShorthairBreedNames: Set<String> = [
        "英国短毛猫",
        "英国短毛",
        "英短",
        "British Shorthair",
        "british shorthair"
    ]

    private static let americanShorthairBreedNames: Set<String> = [
        "美国短毛猫",
        "美国短毛",
        "美短",
        "American Shorthair",
        "american shorthair"
    ]

    private static let ragdollBreedNames: Set<String> = [
        "布偶猫",
        "布偶",
        "Ragdoll",
        "ragdoll"
    ]

    private static let siameseBreedNames: Set<String> = [
        "暹罗猫",
        "暹罗",
        "Siamese",
        "siamese"
    ]

    private static let abyssinianBreedNames: Set<String> = [
        "阿比西尼亚猫",
        "阿比西尼亚",
        "Abyssinian",
        "abyssinian"
    ]

    private static let maineCoonBreedNames: Set<String> = [
        "缅因库恩猫",
        "缅因猫",
        "缅因",
        "Maine Coon",
        "maine coon"
    ]

    private static let persianBreedNames: Set<String> = [
        "波斯猫",
        "波斯",
        "Persian",
        "persian"
    ]

    private static let scottishFoldBreedNames: Set<String> = [
        "苏格兰折耳猫",
        "苏格兰折耳",
        "折耳猫",
        "Scottish Fold",
        "scottish fold"
    ]

    private static let norwegianForestBreedNames: Set<String> = [
        "挪威森林猫",
        "挪威森林",
        "Norwegian Forest Cat",
        "norwegian forest cat",
        "Norwegian Forest",
        "norwegian forest"
    ]

    private static let burmeseBreedNames: Set<String> = [
        "缅甸猫",
        "Burmese",
        "burmese",
        "Burmese Cat",
        "burmese cat"
    ]

    private static let liHuaBreedNames: Set<String> = [
        "狸花猫",
        "狸花",
        "中华狸花猫",
        "Chinese Li Hua",
        "chinese li hua",
        "Dragon Li",
        "dragon li",
        "Li Hua",
        "li hua"
    ]

    private static let russianBlueBreedNames: Set<String> = [
        "俄罗斯蓝猫",
        "Russian Blue",
        "russian blue"
    ]

    private static let silverShadedBreedNames: Set<String> = [
        "银渐层",
        "Silver Shaded",
        "silver shaded"
    ]

    private static let goldenShadedBreedNames: Set<String> = [
        "金渐层",
        "Golden Shaded",
        "golden shaded"
    ]

    private static let bengalBreedNames: Set<String> = [
        "孟加拉猫",
        "Bengal",
        "bengal",
        "Bengal Cat",
        "bengal cat"
    ]

    private static let somaliBreedNames: Set<String> = [
        "索马里猫",
        "Somali",
        "somali",
        "Somali Cat",
        "somali cat"
    ]

    private static let sphynxBreedNames: Set<String> = [
        "斯芬克斯无毛猫",
        "斯芬克斯猫",
        "斯芬克斯",
        "无毛猫",
        "Sphynx",
        "sphynx",
        "Sphynx Cat",
        "sphynx cat"
    ]

    private static let turkishAngoraBreedNames: Set<String> = [
        "土耳其安哥拉猫",
        "土耳其安哥拉",
        "安哥拉猫",
        "Turkish Angora",
        "turkish angora",
        "Turkish Angora Cat",
        "turkish angora cat"
    ]

    private static let domesticShorthairBreedNames: Set<String> = [
        "中华田园猫",
        "中华田园",
        "田园猫",
        "家猫",
        "中国家猫",
        "Domestic Shorthair",
        "domestic shorthair",
        "Domestic Short Hair",
        "domestic short hair",
        "Chinese Domestic Cat",
        "chinese domestic cat"
    ]

    private static let shibaInuBreedNames: Set<String> = [
        "柴犬",
        "Shiba Inu",
        "shiba inu"
    ]

    private static let pugBreedNames: Set<String> = [
        "巴哥犬",
        "八哥犬",
        "巴哥",
        "八哥",
        "Pug",
        "pug"
    ]

    private static let bostonTerrierBreedNames: Set<String> = [
        "波士顿梗",
        "波士顿",
        "Boston Terrier",
        "boston terrier"
    ]

    private static let chihuahuaBreedNames: Set<String> = [
        "吉娃娃",
        "奇瓦瓦",
        "Chihuahua",
        "chihuahua"
    ]

    private static let akitaBreedNames: Set<String> = [
        "秋田犬",
        "秋田",
        "Akita",
        "akita",
        "Akita Inu",
        "akita inu"
    ]

    private static let jackRussellTerrierBreedNames: Set<String> = [
        "杰克罗素梗",
        "杰克罗素",
        "Jack Russell Terrier",
        "jack russell terrier",
        "Jack Russell",
        "jack russell"
    ]

    private static let rottweilerBreedNames: Set<String> = [
        "罗威纳犬",
        "罗威纳",
        "Rottweiler",
        "rottweiler"
    ]

    private static let sharPeiBreedNames: Set<String> = [
        "沙皮犬",
        "沙皮",
        "Shar Pei",
        "shar pei",
        "Chinese Shar Pei",
        "chinese shar pei"
    ]

    private static let chowChowBreedNames: Set<String> = [
        "松狮犬",
        "松狮",
        "Chow Chow",
        "chow chow"
    ]

    private static let shetlandSheepdogBreedNames: Set<String> = [
        "喜乐蒂牧羊犬",
        "喜乐蒂",
        "Shetland Sheepdog",
        "shetland sheepdog",
        "Sheltie",
        "sheltie"
    ]

    private static let englishBulldogBreedNames: Set<String> = [
        "英国斗牛犬",
        "英斗",
        "English Bulldog",
        "english bulldog",
        "Bulldog",
        "bulldog"
    ]

    private static let goldenRetrieverBreedNames: Set<String> = [
        "金毛",
        "金毛寻回犬",
        "黄金猎犬",
        "Golden Retriever",
        "golden retriever"
    ]

    private static let frenchBulldogBreedNames: Set<String> = [
        "法国斗牛犬",
        "法斗",
        "French Bulldog",
        "french bulldog"
    ]

    private static let labradorRetrieverBreedNames: Set<String> = [
        "拉布拉多犬",
        "拉布拉多寻回犬",
        "拉布拉多",
        "Labrador Retriever",
        "labrador retriever",
        "Labrador",
        "labrador"
    ]

    private static let corgiBreedNames: Set<String> = [
        "柯基犬",
        "柯基",
        "Corgi",
        "corgi",
        "Pembroke Welsh Corgi",
        "pembroke welsh corgi"
    ]

    private static let beagleBreedNames: Set<String> = [
        "比格犬",
        "比格",
        "Beagle",
        "beagle"
    ]

    private static let bichonFriseBreedNames: Set<String> = [
        "比熊犬",
        "比熊",
        "Bichon Frise",
        "bichon frise"
    ]

    private static let dalmatianBreedNames: Set<String> = [
        "大麦町犬",
        "斑点狗",
        "Dalmatian",
        "dalmatian"
    ]

    private static let dobermanBreedNames: Set<String> = [
        "杜宾犬",
        "杜宾",
        "Doberman",
        "doberman",
        "Doberman Pinscher",
        "doberman pinscher"
    ]

    private static let malteseBreedNames: Set<String> = [
        "马尔济斯犬",
        "马尔济斯",
        "Maltese",
        "maltese"
    ]

    private static let afghanHoundBreedNames: Set<String> = [
        "阿富汗猎犬",
        "Afghan Hound",
        "afghan hound"
    ]

    private static let yorkshireTerrierBreedNames: Set<String> = [
        "约克夏梗",
        "约克夏",
        "Yorkshire Terrier",
        "yorkshire terrier",
        "Yorkie",
        "yorkie"
    ]

    private static let samoyedBreedNames: Set<String> = [
        "萨摩耶犬",
        "萨摩耶",
        "Samoyed",
        "samoyed"
    ]

    private static let poodleBreedNames: Set<String> = [
        "泰迪/贵宾犬",
        "泰迪",
        "贵宾犬",
        "贵宾",
        "Toy Poodle",
        "toy poodle",
        "Poodle",
        "poodle"
    ]

    private static let shihTzuBreedNames: Set<String> = [
        "西施犬",
        "西施",
        "Shih Tzu",
        "shih tzu"
    ]

    private static let chineseRuralDogBreedNames: Set<String> = [
        "中华田园犬",
        "中华田园",
        "田园犬",
        "土狗",
        "Chinese Rural Dog",
        "chinese rural dog",
        "Chinese Native Dog",
        "chinese native dog"
    ]

    private static let miniatureSchnauzerBreedNames: Set<String> = [
        "迷你雪纳瑞",
        "雪纳瑞",
        "Miniature Schnauzer",
        "miniature schnauzer"
    ]

    private static let alaskanMalamuteBreedNames: Set<String> = [
        "阿拉斯加雪橇犬",
        "阿拉斯加",
        "Alaskan Malamute",
        "alaskan malamute"
    ]

    private static let australianShepherdBreedNames: Set<String> = [
        "澳大利亚牧羊犬",
        "澳牧",
        "Australian Shepherd",
        "australian shepherd",
        "Aussie",
        "aussie"
    ]

    private static let borderCollieBreedNames: Set<String> = [
        "边境牧羊犬",
        "边牧",
        "Border Collie",
        "border collie"
    ]

    private static let pomeranianBreedNames: Set<String> = [
        "博美犬",
        "博美",
        "Pomeranian",
        "pomeranian"
    ]

    private static let cavalierKingCharlesSpanielBreedNames: Set<String> = [
        "查理王骑士犬",
        "查理王",
        "Cavalier King Charles Spaniel",
        "cavalier king charles spaniel",
        "Cavalier",
        "cavalier"
    ]

    private static let cockerSpanielBreedNames: Set<String> = [
        "可卡犬",
        "可卡",
        "Cocker Spaniel",
        "cocker spaniel",
        "Cocker",
        "cocker"
    ]

    private static let siberianHuskyBreedNames: Set<String> = [
        "西伯利亚哈士奇",
        "哈士奇",
        "Siberian Husky",
        "siberian husky",
        "Husky",
        "husky"
    ]

    private static let germanShepherdBreedNames: Set<String> = [
        "德国牧羊犬",
        "德牧",
        "German Shepherd",
        "german shepherd"
    ]

    private static let dachshundBreedNames: Set<String> = [
        "腊肠犬",
        "腊肠",
        "Dachshund",
        "dachshund"
    ]

    private static let westHighlandWhiteTerrierBreedNames: Set<String> = [
        "西高地白梗",
        "西高地",
        "West Highland White Terrier",
        "west highland white terrier",
        "Westie",
        "westie"
    ]

    private static let speciesStandardSlugs: Set<String> = [
        "cat",
        "dog",
        "fish",
        "bird",
        "rabbit",
        "reptile",
        "hamster",
        "other"
    ]

    static let devonRexAppearances: [Appearance] = [
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF", coatAliases: ["蓝色（灰蓝）"]),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A", coatAliases: ["虎斑色"]),
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2C2C2C"),
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10", coatAliases: ["重点色"]),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A", coatAliases: ["巧克力色"]),
        .init(coatName: "火焰重点色", coatSlug: "flame_point", coatHex: "E36A2E", coatAliases: ["红色"])
    ]

    static let exoticShorthairAppearances: [Appearance] = [
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF", coatAliases: ["蓝色"]),
        .init(coatName: "橘白", coatSlug: "orange_white", coatHex: "C8622A", coatAliases: ["橘白色", "红白"])
    ]

    static let munchkinAppearances: [Appearance] = [
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "橘虎斑", coatSlug: "orange_tabby", coatHex: "C8622A", coatAliases: ["红虎斑"]),
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2C2C2C", coatAliases: ["奶牛色"])
    ]

    static let birmanAppearances: [Appearance] = [
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10"),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A")
    ]

    static let siberianCatAppearances: [Appearance] = [
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A"),
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "重点色", coatSlug: "colorpoint", coatHex: "4A2A10", coatAliases: ["海豹重点色"])
    ]

    static let britishShorthairAppearances: [Appearance] = [
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF", coatAliases: ["蓝灰色"]),
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0", coatAliases: ["银渐层"]),
        .init(coatName: "金渐层", coatSlug: "golden_shaded", coatHex: "D4A017"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "重点色", coatSlug: "colorpoint", coatHex: "4A2A10")
    ]

    static let americanShorthairAppearances: [Appearance] = [
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0"),
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "橘虎斑", coatSlug: "orange_tabby", coatHex: "C8622A", coatAliases: ["红虎斑"]),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF")
    ]

    static let ragdollAppearances: [Appearance] = [
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10"),
        .init(coatName: "海豹双色", coatSlug: "seal_bicolor", coatHex: "4A2A10", coatAliases: ["海豹重点配白"]),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "蓝双色", coatSlug: "blue_bicolor", coatHex: "7A9AAF", coatAliases: ["蓝重点配白"]),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A", coatAliases: ["巧克力配白"]),
        .init(coatName: "丁香重点色", coatSlug: "lilac_point", coatHex: "B0A0B0", coatAliases: ["丁香配白"]),
        .init(coatName: "火焰重点色", coatSlug: "flame_point", coatHex: "E36A2E")
    ]

    static let siameseAppearances: [Appearance] = [
        .init(coatName: "海豹重点色", coatSlug: "seal_point", coatHex: "4A2A10"),
        .init(coatName: "蓝重点色", coatSlug: "blue_point", coatHex: "7A9AAF"),
        .init(coatName: "巧克力重点色", coatSlug: "chocolate_point", coatHex: "4A2C1A"),
        .init(coatName: "丁香重点色", coatSlug: "lilac_point", coatHex: "B0A0B0")
    ]

    static let abyssinianAppearances: [Appearance] = [
        .init(coatName: "黄褐色", coatSlug: "ruddy", coatHex: "C8822A"),
        .init(coatName: "肉桂红", coatSlug: "sorrel", coatHex: "B5451B", coatAliases: ["红色"]),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF"),
        .init(coatName: "浅黄褐色", coatSlug: "fawn", coatHex: "C9A66B", coatAliases: ["栗色"])
    ]

    static let maineCoonAppearances: [Appearance] = [
        .init(coatName: "棕虎斑", coatSlug: "brown_tabby", coatHex: "7A5C3A"),
        .init(coatName: "银虎斑", coatSlug: "silver_tabby", coatHex: "C0C0C0", coatAliases: ["银色"]),
        .init(coatName: "红虎斑", coatSlug: "red_tabby", coatHex: "B5451B", coatAliases: ["红色"]),
        .init(coatName: "黑烟色", coatSlug: "black_smoke", coatHex: "4B4B4B"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF", coatAliases: ["蓝色"]),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "三花", coatSlug: "calico", coatHex: "D4B896")
    ]

    static let persianAppearances: [Appearance] = [
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF")
    ]

    static let scottishFoldAppearances: [Appearance] = [
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "金色", coatSlug: "golden", coatHex: "D4A017"),
        .init(coatName: "银色", coatSlug: "silver", coatHex: "C0C0C0"),
        .init(coatName: "虎斑", coatSlug: "tabby", coatHex: "7A5C3A"),
        .init(coatName: "玳瑁", coatSlug: "tortoiseshell", coatHex: "6E2C00")
    ]

    static let norwegianForestAppearances: [Appearance] = [
        .init(coatName: "棕虎斑白", coatSlug: "brown_tabby_white", coatHex: "7A5C3A", coatAliases: ["棕虎斑配白"]),
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2A2A2A"),
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "B5451B"),
        .init(coatName: "蓝白", coatSlug: "blue_white", coatHex: "7A9AAF"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8")
    ]

    static let burmeseAppearances: [Appearance] = [
        .init(coatName: "貂褐色", coatSlug: "sable", coatHex: "4A2A10", coatAliases: ["貂色", "海豹褐色"]),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF"),
        .init(coatName: "巧克力色", coatSlug: "chocolate", coatHex: "4A2C1A"),
        .init(coatName: "丁香色", coatSlug: "lilac", coatHex: "C0B0C0"),
        .init(coatName: "红色", coatSlug: "red", coatHex: "B5451B"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8")
    ]

    static let liHuaAppearances: [Appearance] = [
        .init(coatName: "棕狸花", coatSlug: "brown_mackerel_tabby", coatHex: "7A5C3A"),
        .init(coatName: "银灰狸花", coatSlug: "silver_mackerel_tabby", coatHex: "9A9A92")
    ]

    static let russianBlueAppearances: [Appearance] = [
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF")
    ]

    static let silverShadedAppearances: [Appearance] = [
        .init(coatName: "银底渐层", coatSlug: "silver_base_shaded", coatHex: "C0C0C0"),
        .init(coatName: "浅银色", coatSlug: "light_silver", coatHex: "E0E0E0")
    ]

    static let goldenShadedAppearances: [Appearance] = [
        .init(coatName: "金底渐层", coatSlug: "golden_base_shaded", coatHex: "D4A017"),
        .init(coatName: "深金色", coatSlug: "dark_golden", coatHex: "B8860B")
    ]

    static let bengalAppearances: [Appearance] = [
        .init(coatName: "棕豹纹", coatSlug: "brown_rosetted", coatHex: "7A5C3A"),
        .init(coatName: "银豹纹", coatSlug: "silver_rosetted", coatHex: "C0C0C0"),
        .init(coatName: "雪色豹纹", coatSlug: "snow_rosetted", coatHex: "F5E6C8"),
        .init(coatName: "蓝豹纹", coatSlug: "blue_rosetted", coatHex: "7A9AAF")
    ]

    static let somaliAppearances: [Appearance] = [
        .init(coatName: "黄褐色", coatSlug: "ruddy", coatHex: "C8822A"),
        .init(coatName: "红色", coatSlug: "sorrel", coatHex: "B5451B"),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF"),
        .init(coatName: "栗色", coatSlug: "fawn", coatHex: "7B4F2E")
    ]

    static let sphynxAppearances: [Appearance] = [
        .init(coatName: "桃色肤色", coatSlug: "pink_skin", coatHex: "F0C8A0", coatAliases: ["桃色", "粉色肤色"]),
        .init(coatName: "黑色肤色", coatSlug: "black_skin", coatHex: "3A2A1A"),
        .init(coatName: "蓝色肤色", coatSlug: "blue_skin", coatHex: "7A9AAF"),
        .init(coatName: "虎纹肤色", coatSlug: "tabby_skin", coatHex: "7A5C3A", coatAliases: ["虎斑肤色"])
    ]

    static let turkishAngoraAppearances: [Appearance] = [
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "蓝色", coatSlug: "blue", coatHex: "7A9AAF"),
        .init(coatName: "红色", coatSlug: "red", coatHex: "B5451B")
    ]

    static let domesticShorthairAppearances: [Appearance] = [
        .init(coatName: "橘猫", coatSlug: "orange_tabby", coatHex: "C8622A", coatAliases: ["橘虎斑", "橘色"]),
        .init(coatName: "黑猫", coatSlug: "black", coatHex: "1A1A1A", coatAliases: ["黑色"]),
        .init(coatName: "白猫", coatSlug: "white", coatHex: "F5F5F0", coatAliases: ["白色"]),
        .init(coatName: "三花（黑白橘）", coatSlug: "calico", coatHex: "D4B896", coatAliases: ["三花", "三花猫"]),
        .init(coatName: "狸花（虎斑）", coatSlug: "brown_tabby", coatHex: "7A5C3A", coatAliases: ["狸花", "虎斑", "棕虎斑"]),
        .init(coatName: "玳瑁", coatSlug: "tortoiseshell", coatHex: "6E2C00"),
        .init(coatName: "奶牛（黑白）", coatSlug: "black_white", coatHex: "F5F5F0", coatAliases: ["奶牛猫", "黑白"])
    ]

    static let shibaInuAppearances: [Appearance] = [
        .init(coatName: "赤色", coatSlug: "red", coatHex: "C8622A", coatAliases: ["红柴"]),
        .init(coatName: "黑褐色", coatSlug: "black_tan", coatHex: "2A1A12", coatAliases: ["黑芝麻", "黑棕三色"]),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8", coatAliases: ["奶油（裏白）"]),
        .init(coatName: "胡麻色", coatSlug: "sesame", coatHex: "7A6A4A")
    ]

    static let pugAppearances: [Appearance] = [
        .init(coatName: "黄褐色", coatSlug: "fawn", coatHex: "C8A060", coatAliases: ["米色", "浅黄褐色", "fawn"]),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A", coatAliases: ["black"]),
        .init(coatName: "杏色", coatSlug: "apricot_fawn", coatHex: "E8C49A", coatAliases: ["杏黄", "杏黄褐色", "apricot", "apricot fawn"]),
        .init(coatName: "银米色", coatSlug: "silver_fawn", coatHex: "C8B8A0", coatAliases: ["银色黄褐", "银黄褐色", "silver fawn"])
    ]

    static let bostonTerrierAppearances: [Appearance] = [
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2A2A2A"),
        .init(coatName: "虎斑白", coatSlug: "brindle_white", coatHex: "4A3A1A", coatAliases: ["虎斑配白"]),
        .init(coatName: "海豹色白", coatSlug: "seal_white", coatHex: "3A2418", coatAliases: ["海豹白", "海豹色配白"])
    ]

    static let chihuahuaAppearances: [Appearance] = [
        .init(coatName: "黄褐色", coatSlug: "fawn", coatHex: "C8A060", coatAliases: ["浅黄褐色", "米色"]),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "黑棕色", coatSlug: "black_tan", coatHex: "2A1A0A", coatAliases: ["黑棕"]),
        .init(coatName: "巧克力色", coatSlug: "chocolate", coatHex: "4A2C1A")
    ]

    static let akitaAppearances: [Appearance] = [
        .init(coatName: "赤色", coatSlug: "red", coatHex: "C8622A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "虎斑", coatSlug: "brindle", coatHex: "4A3A1A"),
        .init(coatName: "芝麻色", coatSlug: "sesame", coatHex: "7A5C3A")
    ]

    static let jackRussellTerrierAppearances: [Appearance] = [
        .init(coatName: "白棕", coatSlug: "brown_white", coatHex: "C8622A", coatAliases: ["白棕色", "棕白"]),
        .init(coatName: "白黑", coatSlug: "black_white", coatHex: "2A2A2A", coatAliases: ["黑白"]),
        .init(coatName: "三色", coatSlug: "tricolor", coatHex: "4A2A10")
    ]

    static let rottweilerAppearances: [Appearance] = [
        .init(coatName: "standard", coatSlug: "standard", coatHex: "2A1A0A", coatAliases: ["标准", "黑棕", "黑棕色"])
    ]

    static let sharPeiAppearances: [Appearance] = [
        .init(coatName: "黄褐色", coatSlug: "fawn", coatHex: "C8A060", coatAliases: ["黄褐", "浅黄褐色"]),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A")
    ]

    static let chowChowAppearances: [Appearance] = [
        .init(coatName: "红色", coatSlug: "red", coatHex: "B5451B"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8")
    ]

    static let shetlandSheepdogAppearances: [Appearance] = [
        .init(coatName: "貂色白", coatSlug: "sable_white", coatHex: "A05A1A", coatAliases: ["貂白", "貂色配白"]),
        .init(coatName: "三色", coatSlug: "tricolor", coatHex: "4A2A10"),
        .init(coatName: "蓝陨色", coatSlug: "blue_merle", coatHex: "7A9AAF", coatAliases: ["蓝陨", "蓝色陨石"])
    ]

    static let englishBulldogAppearances: [Appearance] = [
        .init(coatName: "黄褐白", coatSlug: "fawn_white", coatHex: "C8A060", coatAliases: ["黄褐色白", "黄褐配白"]),
        .init(coatName: "虎斑白", coatSlug: "brindle_white", coatHex: "4A3A1A", coatAliases: ["虎斑配白"]),
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "B5451B", coatAliases: ["红色白", "红色配白"])
    ]

    static let goldenRetrieverAppearances: [Appearance] = [
        .init(coatName: "浅金色", coatSlug: "light_golden", coatHex: "F2D38A", coatAliases: ["浅奶油金", "金色", "金黄色", "深金色"])
    ]

    static let frenchBulldogAppearances: [Appearance] = [
        .init(coatName: "虎斑", coatSlug: "brindle", coatHex: "4A3A1A"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "花斑", coatSlug: "pied", coatHex: "C8B4A0"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF"),
        .init(coatName: "巧克力色", coatSlug: "chocolate", coatHex: "4A2C1A")
    ]

    static let labradorRetrieverAppearances: [Appearance] = [
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "黄色", coatSlug: "yellow", coatHex: "D4A017"),
        .init(coatName: "巧克力色", coatSlug: "chocolate", coatHex: "4A2C1A")
    ]

    static let corgiAppearances: [Appearance] = [
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "C85A1A"),
        .init(coatName: "貂色白", coatSlug: "sable_white", coatHex: "A05A1A"),
        .init(coatName: "黑白三色", coatSlug: "black_white_tricolor", coatHex: "1A1A0A")
    ]

    static let beagleAppearances: [Appearance] = [
        .init(coatName: "黑棕白三色", coatSlug: "black_brown_white_tricolor", coatHex: "4A2A10"),
        .init(coatName: "棕白", coatSlug: "brown_white", coatHex: "C8622A"),
        .init(coatName: "柠檬白", coatSlug: "lemon_white", coatHex: "E8C49A")
    ]

    static let bichonFriseAppearances: [Appearance] = [
        .init(coatName: "纯白", coatSlug: "pure_white", coatHex: "F5F5F0"),
        .init(coatName: "奶白", coatSlug: "cream_white", coatHex: "F5E6C8")
    ]

    static let dalmatianAppearances: [Appearance] = [
        .init(coatName: "白底黑斑", coatSlug: "black_spotted", coatHex: "F5F5F0"),
        .init(coatName: "白底肝斑", coatSlug: "liver_spotted", coatHex: "6B3A2A")
    ]

    static let dobermanAppearances: [Appearance] = [
        .init(coatName: "黑棕色", coatSlug: "black_tan", coatHex: "1A1A0A"),
        .init(coatName: "蓝棕色", coatSlug: "blue_tan", coatHex: "3A4A5A"),
        .init(coatName: "红棕色", coatSlug: "red_tan", coatHex: "8B3A1A")
    ]

    static let malteseAppearances: [Appearance] = [
        .init(coatName: "纯白", coatSlug: "pure_white", coatHex: "F5F5F0"),
        .init(coatName: "乳白", coatSlug: "ivory", coatHex: "F8F4EC")
    ]

    static let afghanHoundAppearances: [Appearance] = [
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "红棕色", coatSlug: "red_brown", coatHex: "8B3A1A")
    ]

    static let yorkshireTerrierAppearances: [Appearance] = [
        .init(coatName: "钢蓝背棕腿", coatSlug: "steel_blue_tan", coatHex: "4A5A7A"),
        .init(coatName: "金棕色", coatSlug: "golden_tan", coatHex: "C8A800")
    ]

    static let samoyedAppearances: [Appearance] = [
        .init(coatName: "纯白", coatSlug: "pure_white", coatHex: "F5F5F0"),
        .init(coatName: "奶白色", coatSlug: "cream_white", coatHex: "F5E6C8")
    ]

    static let poodleAppearances: [Appearance] = [
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "杏色", coatSlug: "apricot", coatHex: "E8C49A"),
        .init(coatName: "红色", coatSlug: "red", coatHex: "B5451B"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "棕色", coatSlug: "brown", coatHex: "7B4F2E"),
        .init(coatName: "银色", coatSlug: "silver", coatHex: "C0C0C0"),
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF")
    ]

    static let shihTzuAppearances: [Appearance] = [
        .init(coatName: "金白色", coatSlug: "golden_white", coatHex: "D4A017", coatAliases: ["金白"]),
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2A2A2A"),
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "B5451B")
    ]

    static let chineseRuralDogAppearances: [Appearance] = [
        .init(coatName: "黄色", coatSlug: "yellow", coatHex: "D4A017", coatAliases: ["黄犬", "黄狗"]),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "花斑", coatSlug: "pied", coatHex: "C8B4A0", coatAliases: ["花色", "花狗"])
    ]

    static let miniatureSchnauzerAppearances: [Appearance] = [
        .init(coatName: "椒盐色", coatSlug: "salt_pepper", coatHex: "9E9E9E"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "黑银色", coatSlug: "black_silver", coatHex: "2A2A2A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0")
    ]

    static let alaskanMalamuteAppearances: [Appearance] = [
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2A2A2A"),
        .init(coatName: "灰白", coatSlug: "gray_white", coatHex: "9E9E9E"),
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "8B3A1A"),
        .init(coatName: "纯白", coatSlug: "pure_white", coatHex: "F5F5F0")
    ]

    static let australianShepherdAppearances: [Appearance] = [
        .init(coatName: "蓝灰色", coatSlug: "blue_gray", coatHex: "7A9AAF", coatAliases: ["蓝陨石", "蓝陨色"]),
        .init(coatName: "红色", coatSlug: "red", coatHex: "B5451B"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "花斑色", coatSlug: "dapple", coatHex: "C8B4A0", coatAliases: ["花斑", "陨石色"])
    ]

    static let borderCollieAppearances: [Appearance] = [
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2A2A2A"),
        .init(coatName: "蓝白", coatSlug: "blue_white", coatHex: "7A9AAF"),
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "8B3A1A"),
        .init(coatName: "三色", coatSlug: "tricolor", coatHex: "4A2A10")
    ]

    static let pomeranianAppearances: [Appearance] = [
        .init(coatName: "橙色", coatSlug: "orange", coatHex: "C8622A"),
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "棕色", coatSlug: "brown", coatHex: "7B4F2E")
    ]

    static let cavalierKingCharlesSpanielAppearances: [Appearance] = [
        .init(coatName: "红宝石色", coatSlug: "ruby", coatHex: "8B1A1A"),
        .init(coatName: "黑棕色", coatSlug: "black_tan", coatHex: "2A1A0A"),
        .init(coatName: "三色", coatSlug: "tricolor", coatHex: "4A2A10"),
        .init(coatName: "布伦海姆色", coatSlug: "blenheim", coatHex: "C8622A")
    ]

    static let cockerSpanielAppearances: [Appearance] = [
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A"),
        .init(coatName: "金色", coatSlug: "golden", coatHex: "D4A017"),
        .init(coatName: "巧克力色", coatSlug: "chocolate", coatHex: "4A2C1A"),
        .init(coatName: "花斑", coatSlug: "parti", coatHex: "C8B4A0")
    ]

    static let siberianHuskyAppearances: [Appearance] = [
        .init(coatName: "黑白", coatSlug: "black_white", coatHex: "2A2A2A"),
        .init(coatName: "灰白", coatSlug: "gray_white", coatHex: "9E9E9E"),
        .init(coatName: "红白", coatSlug: "red_white", coatHex: "8B3A1A"),
        .init(coatName: "纯白", coatSlug: "solid_white", coatHex: "F5F5F0"),
        .init(coatName: "银白", coatSlug: "silver_white", coatHex: "E0E0E0")
    ]

    static let germanShepherdAppearances: [Appearance] = [
        .init(coatName: "黑棕（鞍形）", coatSlug: "black_tan_saddle", coatHex: "1A1A0A"),
        .init(coatName: "黑红色", coatSlug: "black_red", coatHex: "2A1A0A"),
        .init(coatName: "纯黑", coatSlug: "solid_black", coatHex: "1A1A1A"),
        .init(coatName: "纯白", coatSlug: "solid_white", coatHex: "F5F5F0")
    ]

    static let dachshundAppearances: [Appearance] = [
        .init(coatName: "红色", coatSlug: "red", coatHex: "B5451B"),
        .init(coatName: "巧克力棕", coatSlug: "chocolate_brown", coatHex: "4A2C1A"),
        .init(coatName: "黑棕", coatSlug: "black_tan", coatHex: "1A1A0A"),
        .init(coatName: "奶油色", coatSlug: "cream", coatHex: "F5E6C8"),
        .init(coatName: "花斑", coatSlug: "dapple", coatHex: "C8B4A0")
    ]

    static let westHighlandWhiteTerrierAppearances: [Appearance] = [
        .init(coatName: "白色", coatSlug: "white", coatHex: "F5F5F0"),
        .init(coatName: "黑色", coatSlug: "black", coatHex: "1A1A1A")
    ]

    private static var catBreedAppearances: [String: [Appearance]] {
        [
            "devon_rex": devonRexAppearances,
            "exotic_shorthair": exoticShorthairAppearances,
            "munchkin": munchkinAppearances,
            "birman": birmanAppearances,
            "siberian": siberianCatAppearances,
            "british_shorthair": britishShorthairAppearances,
            "american_shorthair": americanShorthairAppearances,
            "ragdoll": ragdollAppearances,
            "siamese": siameseAppearances,
            "abyssinian": abyssinianAppearances,
            "maine_coon": maineCoonAppearances,
            "persian": persianAppearances,
            "scottish_fold": scottishFoldAppearances,
            "norwegian_forest": norwegianForestAppearances,
            "burmese": burmeseAppearances,
            "li_hua": liHuaAppearances,
            "russian_blue": russianBlueAppearances,
            "silver_shaded": silverShadedAppearances,
            "golden_shaded": goldenShadedAppearances,
            "bengal": bengalAppearances,
            "somali": somaliAppearances,
            "sphynx": sphynxAppearances,
            "turkish_angora": turkishAngoraAppearances,
            "domestic_shorthair": domesticShorthairAppearances
        ]
    }

    private static var dogBreedAppearances: [String: [Appearance]] {
        [
            "shiba_inu": shibaInuAppearances,
            "pug": pugAppearances,
            "boston_terrier": bostonTerrierAppearances,
            "chihuahua": chihuahuaAppearances,
            "akita": akitaAppearances,
            "jack_russell_terrier": jackRussellTerrierAppearances,
            "rottweiler": rottweilerAppearances,
            "shar_pei": sharPeiAppearances,
            "chow_chow": chowChowAppearances,
            "shetland_sheepdog": shetlandSheepdogAppearances,
            "english_bulldog": englishBulldogAppearances,
            "golden_retriever": goldenRetrieverAppearances,
            "french_bulldog": frenchBulldogAppearances,
            "labrador_retriever": labradorRetrieverAppearances,
            "corgi": corgiAppearances,
            "beagle": beagleAppearances,
            "bichon_frise": bichonFriseAppearances,
            "dalmatian": dalmatianAppearances,
            "doberman": dobermanAppearances,
            "maltese": malteseAppearances,
            "afghan_hound": afghanHoundAppearances,
            "yorkshire_terrier": yorkshireTerrierAppearances,
            "samoyed": samoyedAppearances,
            "poodle": poodleAppearances,
            "shih_tzu": shihTzuAppearances,
            "chinese_rural_dog": chineseRuralDogAppearances,
            "miniature_schnauzer": miniatureSchnauzerAppearances,
            "alaskan_malamute": alaskanMalamuteAppearances,
            "australian_shepherd": australianShepherdAppearances,
            "border_collie": borderCollieAppearances,
            "pomeranian": pomeranianAppearances,
            "cavalier_king_charles_spaniel": cavalierKingCharlesSpanielAppearances,
            "cocker_spaniel": cockerSpanielAppearances,
            "siberian_husky": siberianHuskyAppearances,
            "german_shepherd": germanShepherdAppearances,
            "dachshund": dachshundAppearances,
            "west_highland_white_terrier": westHighlandWhiteTerrierAppearances
        ]
    }

    static func supports(species: String, breed: String) -> Bool {
        breedAppearances(speciesSlug: normalizedSpecies(species), breedSlug: normalizedBreed(breed)) != nil
    }

    static func coatColors(species: String, breed: String) -> [CoatColor]? {
        guard let appearances = breedAppearances(
            speciesSlug: normalizedSpecies(species),
            breedSlug: normalizedBreed(breed)
        ) else { return nil }
        var seen: Set<String> = []
        return appearances.compactMap { appearance in
            guard !seen.contains(appearance.coatName) else { return nil }
            seen.insert(appearance.coatName)
            return CoatColor(name: appearance.coatName, hex: appearance.coatHex)
        }
    }

    static func eyeColors(species: String, breed: String, coatColor: String) -> [EyeColor]? {
        guard let appearances = breedAppearances(
            speciesSlug: normalizedSpecies(species),
            breedSlug: normalizedBreed(breed)
        ),
            coatColor == "自定义" || appearances.contains(where: { $0.matches(coatColor: coatColor) }) else { return nil }
        return [EyeColor(name: "黑色", hex: "111111")]
    }

    static func defaultAppearance(species: String, breed: String) -> Appearance? {
        breedAppearances(speciesSlug: normalizedSpecies(species), breedSlug: normalizedBreed(breed))?.first
    }

    static func avatarFilename(species: String, breed: String, gender: String, coatColor: String, eyeColor _: String) -> String? {
        let speciesSlug = normalizedSpecies(species)
        let genderSlug = normalizedGender(gender)

        guard speciesStandardSlugs.contains(speciesSlug) else { return nil }
        let breedSlug = normalizedBreed(breed)
        guard let appearances = breedAppearances(speciesSlug: speciesSlug, breedSlug: breedSlug) else {
            return "\(speciesSlug)_\(genderSlug)_standard.png"
        }

        guard coatColor != "自定义",
              let appearance = appearances.first(where: { $0.matches(coatColor: coatColor) }) else {
            return "\(speciesSlug)_\(genderSlug)_standard.png"
        }

        return "\(speciesSlug)_\(breedSlug)_\(genderSlug)_\(appearance.coatSlug).png"
    }

    private static func breedAppearances(speciesSlug: String, breedSlug: String) -> [Appearance]? {
        switch speciesSlug {
        case "cat": catBreedAppearances[breedSlug]
        case "dog": dogBreedAppearances[breedSlug]
        default: nil
        }
    }

    static func avatarData(species: String, breed: String, gender: String, coatColor: String, eyeColor: String) -> Data? {
        guard let filename = avatarFilename(species: species, breed: breed, gender: gender, coatColor: coatColor, eyeColor: eyeColor) else {
            return nil
        }
        return avatarData(filename: filename)
    }

    static func avatarURL(species: String, breed: String, gender: String, coatColor: String, eyeColor: String, bundle: Bundle = .main) -> URL? {
        guard let filename = avatarFilename(species: species, breed: breed, gender: gender, coatColor: coatColor, eyeColor: eyeColor) else {
            return nil
        }
        return avatarURL(filename: filename, bundle: bundle)
    }

    static func avatarURL(filename: String, bundle: Bundle = .main) -> URL? {
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        return bundle.url(forResource: name, withExtension: ext, subdirectory: assetDirectory)
    }

    static func avatarData(filename: String, bundle: Bundle = .main) -> Data? {
        guard let url = avatarURL(filename: filename, bundle: bundle) else { return nil }
        return try? Data(contentsOf: url) // smoothness: allow legacy prepared-avatar decode path; media service migration tracked after P1 baseline
    }

    private static func normalizedSpecies(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "猫", "cat", "cats": "cat"
        case "狗", "dog", "dogs": "dog"
        case "鱼", "fish", "fishes": "fish"
        case "鸟", "bird", "birds": "bird"
        case "兔", "兔子", "rabbit", "rabbits", "bunny", "bunnies": "rabbit"
        case "爬宠", "爬虫", "爬行动物", "reptile", "reptiles", "lizard", "gecko": "reptile"
        case "仓鼠", "hamster", "hamsters": "hamster"
        case "其他", "other", "others": "other"
        default: "pet"
        }
    }

    private static func normalizedBreed(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if devonRexBreedNames.contains(trimmed) {
            return "devon_rex"
        }
        if exoticShorthairBreedNames.contains(trimmed) {
            return "exotic_shorthair"
        }
        if munchkinBreedNames.contains(trimmed) {
            return "munchkin"
        }
        if birmanBreedNames.contains(trimmed) {
            return "birman"
        }
        if siberianCatBreedNames.contains(trimmed) {
            return "siberian"
        }
        if britishShorthairBreedNames.contains(trimmed) {
            return "british_shorthair"
        }
        if americanShorthairBreedNames.contains(trimmed) {
            return "american_shorthair"
        }
        if ragdollBreedNames.contains(trimmed) {
            return "ragdoll"
        }
        if siameseBreedNames.contains(trimmed) {
            return "siamese"
        }
        if abyssinianBreedNames.contains(trimmed) {
            return "abyssinian"
        }
        if maineCoonBreedNames.contains(trimmed) {
            return "maine_coon"
        }
        if persianBreedNames.contains(trimmed) {
            return "persian"
        }
        if scottishFoldBreedNames.contains(trimmed) {
            return "scottish_fold"
        }
        if norwegianForestBreedNames.contains(trimmed) {
            return "norwegian_forest"
        }
        if burmeseBreedNames.contains(trimmed) {
            return "burmese"
        }
        if liHuaBreedNames.contains(trimmed) {
            return "li_hua"
        }
        if russianBlueBreedNames.contains(trimmed) {
            return "russian_blue"
        }
        if silverShadedBreedNames.contains(trimmed) {
            return "silver_shaded"
        }
        if goldenShadedBreedNames.contains(trimmed) {
            return "golden_shaded"
        }
        if bengalBreedNames.contains(trimmed) {
            return "bengal"
        }
        if somaliBreedNames.contains(trimmed) {
            return "somali"
        }
        if sphynxBreedNames.contains(trimmed) {
            return "sphynx"
        }
        if turkishAngoraBreedNames.contains(trimmed) {
            return "turkish_angora"
        }
        if domesticShorthairBreedNames.contains(trimmed) {
            return "domestic_shorthair"
        }
        if shibaInuBreedNames.contains(trimmed) {
            return "shiba_inu"
        }
        if pugBreedNames.contains(trimmed) {
            return "pug"
        }
        if bostonTerrierBreedNames.contains(trimmed) {
            return "boston_terrier"
        }
        if chihuahuaBreedNames.contains(trimmed) {
            return "chihuahua"
        }
        if akitaBreedNames.contains(trimmed) {
            return "akita"
        }
        if jackRussellTerrierBreedNames.contains(trimmed) {
            return "jack_russell_terrier"
        }
        if rottweilerBreedNames.contains(trimmed) {
            return "rottweiler"
        }
        if sharPeiBreedNames.contains(trimmed) {
            return "shar_pei"
        }
        if chowChowBreedNames.contains(trimmed) {
            return "chow_chow"
        }
        if shetlandSheepdogBreedNames.contains(trimmed) {
            return "shetland_sheepdog"
        }
        if englishBulldogBreedNames.contains(trimmed) {
            return "english_bulldog"
        }
        if goldenRetrieverBreedNames.contains(trimmed) {
            return "golden_retriever"
        }
        if frenchBulldogBreedNames.contains(trimmed) {
            return "french_bulldog"
        }
        if labradorRetrieverBreedNames.contains(trimmed) {
            return "labrador_retriever"
        }
        if corgiBreedNames.contains(trimmed) {
            return "corgi"
        }
        if beagleBreedNames.contains(trimmed) {
            return "beagle"
        }
        if bichonFriseBreedNames.contains(trimmed) {
            return "bichon_frise"
        }
        if dalmatianBreedNames.contains(trimmed) {
            return "dalmatian"
        }
        if dobermanBreedNames.contains(trimmed) {
            return "doberman"
        }
        if malteseBreedNames.contains(trimmed) {
            return "maltese"
        }
        if afghanHoundBreedNames.contains(trimmed) {
            return "afghan_hound"
        }
        if yorkshireTerrierBreedNames.contains(trimmed) {
            return "yorkshire_terrier"
        }
        if samoyedBreedNames.contains(trimmed) {
            return "samoyed"
        }
        if poodleBreedNames.contains(trimmed) {
            return "poodle"
        }
        if shihTzuBreedNames.contains(trimmed) {
            return "shih_tzu"
        }
        if chineseRuralDogBreedNames.contains(trimmed) {
            return "chinese_rural_dog"
        }
        if miniatureSchnauzerBreedNames.contains(trimmed) {
            return "miniature_schnauzer"
        }
        if alaskanMalamuteBreedNames.contains(trimmed) {
            return "alaskan_malamute"
        }
        if australianShepherdBreedNames.contains(trimmed) {
            return "australian_shepherd"
        }
        if borderCollieBreedNames.contains(trimmed) {
            return "border_collie"
        }
        if pomeranianBreedNames.contains(trimmed) {
            return "pomeranian"
        }
        if cavalierKingCharlesSpanielBreedNames.contains(trimmed) {
            return "cavalier_king_charles_spaniel"
        }
        if cockerSpanielBreedNames.contains(trimmed) {
            return "cocker_spaniel"
        }
        if siberianHuskyBreedNames.contains(trimmed) {
            return "siberian_husky"
        }
        if germanShepherdBreedNames.contains(trimmed) {
            return "german_shepherd"
        }
        if dachshundBreedNames.contains(trimmed) {
            return "dachshund"
        }
        if westHighlandWhiteTerrierBreedNames.contains(trimmed) {
            return "west_highland_white_terrier"
        }
        return trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func normalizedGender(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "female", "girl", "女", "女孩", "母": "girl"
        default: "boy"
        }
    }
}

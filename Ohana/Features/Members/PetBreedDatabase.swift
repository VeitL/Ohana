//
//  PetBreedDatabase.swift
//  Ohana
//
//  品种数据库：涵盖市场常见品种，含毛色/瞳色/推荐主题色
//

import SwiftUI

// MARK: - Coat Color
nonisolated struct CoatColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

// MARK: - Eye Color
nonisolated struct EyeColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

// MARK: - Breed Info
nonisolated struct BreedInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coatColors: [CoatColor]
    let eyeColors: [EyeColor]
    let suggestedThemeHex: String

    static func == (lhs: BreedInfo, rhs: BreedInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

private nonisolated struct BreedCareTipSet {
    let zh: [String]
    let en: [String]
    let de: [String]

    func resolve(l: L10n) -> [String] {
        if l.isChinese { return zh }
        if l.isDe { return de }
        return en
    }
}

// MARK: - Pet Breed Database
nonisolated enum PetBreedDatabase {

    // MARK: - Common Colors
    static let genericCoatColors: [CoatColor] = [
        CoatColor(name: "黑色", hex: "1A1A1A"),
        CoatColor(name: "白色", hex: "F5F5F0"),
        CoatColor(name: "灰色", hex: "9E9E9E"),
        CoatColor(name: "深灰色", hex: "5C5C5C"),
        CoatColor(name: "浅灰色", hex: "CFCFCF"),
        CoatColor(name: "棕色", hex: "7B4F2E"),
        CoatColor(name: "深棕色", hex: "4A2A10"),
        CoatColor(name: "红棕色", hex: "8B3A1A"),
        CoatColor(name: "金黄色", hex: "D4A017"),
        CoatColor(name: "奶油色", hex: "F5E6C8"),
        CoatColor(name: "红色", hex: "B5451B"),
        CoatColor(name: "橙色", hex: "C8622A"),
        CoatColor(name: "黄色", hex: "E8D44D"),
        CoatColor(name: "橙黄色", hex: "FFB300"),
        CoatColor(name: "杏色", hex: "E8C49A"),
        CoatColor(name: "蓝色", hex: "3B6FB8"),
        CoatColor(name: "绿色", hex: "3D8C4A"),
        CoatColor(name: "蓝灰色", hex: "7A9AAF"),
        CoatColor(name: "银色", hex: "C0C0C0"),
        CoatColor(name: "巧克力色", hex: "4A2C1A"),
        CoatColor(name: "虎斑色", hex: "7A5C3A"),
        CoatColor(name: "花斑色", hex: "C8B4A0"),
        // 兔/鸟/仓鼠等「coats([...])」引用名，须在此表内才有正确色块（否则退化为灰色占位）
        CoatColor(name: "黑白", hex: "2C2C2C"),
        CoatColor(name: "蓝白", hex: "8FA8BE"),
        CoatColor(name: "棕白", hex: "9A846E"),
        CoatColor(name: "灰白", hex: "C5C5C5"),
        CoatColor(name: "花斑", hex: "C8B4A0"),
        CoatColor(name: "多色", hex: "C4A882"),
        CoatColor(name: "灰棕色", hex: "8D7B68"),
        CoatColor(name: "珍珠色", hex: "E8DDD4"),
        CoatColor(name: "蓝宝石色", hex: "6B8CBC"),
        CoatColor(name: "白色（冬季）", hex: "F0F0EE"),
        CoatColor(name: "沙棕色", hex: "C4A574"),
        CoatColor(name: "肉桂色", hex: "C9A66B"),
        CoatColor(name: "米色", hex: "E5D9C8"),
        CoatColor(name: "盐椒色", hex: "8B8B82"),
        CoatColor(name: "白腹深刺", hex: "3A3632"),
        CoatColor(name: "黄化", hex: "FFE566"),
        CoatColor(name: "白面", hex: "ECEAE4"),
        CoatColor(name: "橙色脸颊灰色", hex: "9E9E9E"),
        CoatColor(name: "其他", hex: "BDBDBD")
    ]

    // 奶牛色专用（黑白双色，底色白，重点黑）
    static let cowPatternCoatColors: [CoatColor] = [
        CoatColor(name: "奶牛白底", hex: "F5F5F0"),
        CoatColor(name: "奶牛黑斑", hex: "1A1A1A")
    ]

    static let genericEyeColors: [EyeColor] = [
        EyeColor(name: "棕色", hex: "6B3A2A"),
        EyeColor(name: "深棕色", hex: "3D1F0D"),
        EyeColor(name: "琥珀色", hex: "C68B1A"),
        EyeColor(name: "金色", hex: "D4A017"),
        EyeColor(name: "黄色", hex: "C8A800"),
        EyeColor(name: "绿色", hex: "3D7A30"),
        EyeColor(name: "翠绿色", hex: "1A8C3A"),
        EyeColor(name: "蓝绿色", hex: "2A7A6A"),
        EyeColor(name: "蓝色", hex: "2A5C9A"),
        EyeColor(name: "浅蓝色", hex: "5A9ACA"),
        EyeColor(name: "冰蓝色", hex: "9EC8E8"),
        EyeColor(name: "铜色", hex: "A05A1A"),
        EyeColor(name: "橙色", hex: "C06010"),
        EyeColor(name: "榛色", hex: "7A5A2A"),
        EyeColor(name: "黑色", hex: "1C1C1C"),
        EyeColor(name: "异瞳", hex: "7A3A7A"),
        EyeColor(name: "红色", hex: "CC2200"),
        EyeColor(name: "粉色（白化）", hex: "E8A8C8"),
        EyeColor(name: "红色（白化）", hex: "FF5533"),
        EyeColor(name: "铜绿色", hex: "6B8C3A"),
        EyeColor(name: "其他", hex: "BDBDBD")
    ]

    /// 在品种允许的瞳色集合内，按当前已选毛色做常见表型上的二次收敛（重点色猫多为蓝眼表型、白化/红眼与白毛、部分白兔等）；无法收窄时退回品种全集。
    /// 参考：CFA/FCI 公开品种描述、家猫「重点色」温度敏感白化（cs/cb）与常见伴侣动物毛色-眼色表型归纳。
    static func refinedEyeColors(breed: BreedInfo?, coatColor: String) -> [EyeColor] {
        let base = breed?.eyeColors ?? genericEyeColors
        let coat = coatColor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !coat.isEmpty, coat != "自定义" else { return base }

        if coat.contains("白化") || coat.contains("红眼") {
            let narrowed = base.filter { $0.name.contains("红") || $0.name.contains("粉色") }
            return narrowed.isEmpty ? base : narrowed
        }

        if coat.contains("重点"), let n = breed?.name, n == "暹罗猫" || n == "布偶猫" {
            let narrowed = base.filter { $0.name.contains("蓝") }
            return narrowed.isEmpty ? base : narrowed
        }

        if breed?.name == "新西兰兔", coat == "白色" {
            let narrowed = base.filter { $0.name.contains("粉色") || $0.name.contains("红") }
            return narrowed.isEmpty ? base : narrowed
        }

        return base
    }

    // MARK: - Dog Breeds (A-Z)
    static let dogBreeds: [BreedInfo] = [
        BreedInfo(name: "阿富汗猎犬",
                  coatColors: [CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "红棕色", hex: "8B3A1A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "阿拉斯加雪橇犬",
                  coatColors: [CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "灰白", hex: "9E9E9E"), CoatColor(name: "红白", hex: "8B3A1A"), CoatColor(name: "纯白", hex: "F5F5F0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "澳大利亚牧羊犬",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "花斑色", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "42A5F5"),
        BreedInfo(name: "巴哥犬",
                  coatColors: [CoatColor(name: "黄褐色", hex: "C8A060"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "杏色", hex: "E8C49A"), CoatColor(name: "银米色", hex: "C8B8A0")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "C8A060"),
        BreedInfo(name: "比格犬",
                  coatColors: [CoatColor(name: "黑棕白三色", hex: "4A2A10"), CoatColor(name: "棕白", hex: "C8622A"), CoatColor(name: "柠檬白", hex: "E8C49A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "榛色", hex: "7A5A2A")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "比熊犬",
                  coatColors: [CoatColor(name: "纯白", hex: "F5F5F0"), CoatColor(name: "奶白", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "边境牧羊犬",
                  coatColors: [CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "蓝白", hex: "7A9AAF"), CoatColor(name: "红白", hex: "8B3A1A"), CoatColor(name: "三色", hex: "4A2A10")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "455A64"),
        BreedInfo(name: "博美犬",
                  coatColors: [CoatColor(name: "橙色", hex: "C8622A"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "棕色", hex: "7B4F2E")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FF7043"),
        BreedInfo(name: "波士顿梗",
                  coatColors: [CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "虎斑白", hex: "4A3A1A"), CoatColor(name: "海豹色白", hex: "3A2418")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "455A64"),
        BreedInfo(name: "查理王骑士犬",
                  coatColors: [CoatColor(name: "红宝石色", hex: "8B1A1A"), CoatColor(name: "黑棕色", hex: "2A1A0A"), CoatColor(name: "三色", hex: "4A2A10"), CoatColor(name: "布伦海姆色", hex: "C8622A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "C0392B"),
        BreedInfo(name: "柴犬",
                  coatColors: [CoatColor(name: "红柴", hex: "C85A1A"), CoatColor(name: "黑芝麻", hex: "2A2A1A"), CoatColor(name: "黑棕三色", hex: "1A1A0A"), CoatColor(name: "奶油（裏白）", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FF7043"),
        BreedInfo(name: "大麦町犬",
                  coatColors: [CoatColor(name: "白底黑斑", hex: "F5F5F0"), CoatColor(name: "白底肝斑", hex: "6B3A2A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "455A64"),
        BreedInfo(name: "德国牧羊犬",
                  coatColors: [CoatColor(name: "黑棕（鞍形）", hex: "1A1A0A"), CoatColor(name: "黑红色", hex: "2A1A0A"), CoatColor(name: "纯黑", hex: "1A1A1A"), CoatColor(name: "纯白", hex: "F5F5F0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "杜宾犬",
                  coatColors: [CoatColor(name: "黑棕色", hex: "1A1A0A"), CoatColor(name: "蓝棕色", hex: "3A4A5A"), CoatColor(name: "红棕色", hex: "8B3A1A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "212121"),
        BreedInfo(name: "法国斗牛犬",
                  coatColors: [CoatColor(name: "虎斑", hex: "4A3A1A"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "花斑", hex: "C8B4A0"), CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "巧克力色", hex: "4A2C1A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "吉娃娃",
                  coatColors: [CoatColor(name: "黄褐色", hex: "C8A060"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "黑棕色", hex: "2A1A0A"), CoatColor(name: "巧克力色", hex: "4A2C1A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "D7A65B"),
        BreedInfo(name: "腊肠犬",
                  coatColors: [CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "巧克力棕", hex: "4A2C1A"), CoatColor(name: "黑棕", hex: "1A1A0A"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "花斑", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "拉布拉多犬",
                  coatColors: [CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "黄色", hex: "D4A017"), CoatColor(name: "巧克力色", hex: "4A2C1A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "榛色", hex: "7A5A2A")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "金毛寻回犬",
                  coatColors: [CoatColor(name: "浅奶油金", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "杰克罗素梗",
                  coatColors: [CoatColor(name: "白棕", hex: "C8622A"), CoatColor(name: "白黑", hex: "2A2A2A"), CoatColor(name: "三色", hex: "4A2A10")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "F5E6C8"),
        BreedInfo(name: "柯基犬",
                  coatColors: [CoatColor(name: "红白", hex: "C85A1A"), CoatColor(name: "貂色白", hex: "A05A1A"), CoatColor(name: "黑白三色", hex: "1A1A0A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "可卡犬",
                  coatColors: [CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "金色", hex: "D4A017"), CoatColor(name: "巧克力色", hex: "4A2C1A"), CoatColor(name: "花斑", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "榛色", hex: "7A5A2A")], suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "秋田犬",
                  coatColors: [CoatColor(name: "赤色", hex: "C8622A"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "虎斑", hex: "4A3A1A"), CoatColor(name: "芝麻色", hex: "7A5C3A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "C8622A"),
        BreedInfo(name: "罗威纳犬",
                  coatColors: [CoatColor(name: "standard", hex: "1A1A0A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "212121"),
        BreedInfo(name: "马尔济斯犬",
                  coatColors: [CoatColor(name: "纯白", hex: "F5F5F0"), CoatColor(name: "乳白", hex: "F8F4EC")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "迷你雪纳瑞",
                  coatColors: [CoatColor(name: "椒盐色", hex: "9E9E9E"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "黑银色", hex: "2A2A2A"), CoatColor(name: "白色", hex: "F5F5F0")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "萨摩耶犬",
                  coatColors: [CoatColor(name: "纯白", hex: "F5F5F0"), CoatColor(name: "奶白色", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "沙皮犬",
                  coatColors: [CoatColor(name: "黄褐色", hex: "C8A060"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "黑色", hex: "1A1A1A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "C8A060"),
        BreedInfo(name: "松狮犬",
                  coatColors: [CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "奶油色", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "B5451B"),
        BreedInfo(name: "泰迪/贵宾犬",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "杏色", hex: "E8C49A"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "棕色", hex: "7B4F2E"), CoatColor(name: "银色", hex: "C0C0C0"), CoatColor(name: "蓝灰色", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "琥珀色", hex: "C68B1A")], suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "西伯利亚哈士奇",
                  coatColors: [CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "灰白", hex: "9E9E9E"), CoatColor(name: "红白", hex: "8B3A1A"), CoatColor(name: "纯白", hex: "F5F5F0"), CoatColor(name: "银白", hex: "E0E0E0")],
                  eyeColors: [EyeColor(name: "冰蓝色", hex: "9EC8E8"), EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "西高地白梗",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "喜乐蒂牧羊犬",
                  coatColors: [CoatColor(name: "貂色白", hex: "A05A1A"), CoatColor(name: "三色", hex: "4A2A10"), CoatColor(name: "蓝陨色", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "A05A1A"),
        BreedInfo(name: "西施犬",
                  coatColors: [CoatColor(name: "金白色", hex: "D4A017"), CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "红白", hex: "B5451B")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "英国斗牛犬",
                  coatColors: [CoatColor(name: "黄褐白", hex: "C8A060"), CoatColor(name: "虎斑白", hex: "4A3A1A"), CoatColor(name: "红白", hex: "B5451B")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "约克夏梗",
                  coatColors: [CoatColor(name: "钢蓝背棕腿", hex: "4A5A7A"), CoatColor(name: "金棕色", hex: "C8A800")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "中华田园犬",
                  coatColors: [CoatColor(name: "黄色", hex: "D4A017"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "花斑", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "黄色", hex: "C8A800")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E")
    ]

    // MARK: - Cat Breeds (A-Z)
    static let catBreeds: [BreedInfo] = [
        BreedInfo(name: "阿比西尼亚猫",
                  coatColors: [CoatColor(name: "黄褐色", hex: "C8822A"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "蓝色", hex: "7A9AAF"), CoatColor(name: "栗色", hex: "7B4F2E")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "琥珀色", hex: "C68B1A")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "暹罗猫",
                  coatColors: [CoatColor(name: "海豹重点色", hex: "4A2A10"), CoatColor(name: "蓝重点色", hex: "7A9AAF"), CoatColor(name: "巧克力重点色", hex: "4A2C1A"), CoatColor(name: "丁香重点色", hex: "B0A0B0")],
                  eyeColors: [EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "布偶猫",
                  coatColors: [CoatColor(name: "海豹重点配白", hex: "4A2A10"), CoatColor(name: "蓝重点配白", hex: "7A9AAF"), CoatColor(name: "巧克力配白", hex: "6B3A2A"), CoatColor(name: "丁香配白", hex: "C0B0C0")],
                  eyeColors: [EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "B8A9C9"),
        BreedInfo(name: "波斯猫",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "蓝色", hex: "7A9AAF"), CoatColor(name: "金色", hex: "D4A017"), CoatColor(name: "银色", hex: "C0C0C0"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "玳瑁色", hex: "6E2C00")],
                  eyeColors: [EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "异国短毛猫",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "橘白", hex: "C8622A")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "曼基康猫",
                  coatColors: [CoatColor(name: "银虎斑", hex: "C0C0C0"), CoatColor(name: "橘虎斑", hex: "C8622A"), CoatColor(name: "黑白", hex: "2C2C2C")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "C0C0C0"),
        BreedInfo(name: "伯曼猫",
                  coatColors: [CoatColor(name: "海豹重点色", hex: "4A2A10"), CoatColor(name: "蓝重点色", hex: "7A9AAF"), CoatColor(name: "巧克力重点色", hex: "4A2C1A")],
                  eyeColors: [EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "B8A9C9"),
        BreedInfo(name: "西伯利亚猫",
                  coatColors: [CoatColor(name: "棕虎斑", hex: "7A5C3A"), CoatColor(name: "银虎斑", hex: "C0C0C0"), CoatColor(name: "重点色", hex: "4A2A10")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "苏格兰折耳猫",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "金色", hex: "D4A017"), CoatColor(name: "银色", hex: "C0C0C0"), CoatColor(name: "虎斑", hex: "7A5C3A"), CoatColor(name: "玳瑁", hex: "6E2C00")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "英国短毛猫",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "蓝白", hex: "A8B8CA"), CoatColor(name: "金渐层", hex: "D4A017"), CoatColor(name: "银渐层", hex: "C0C0C0"), CoatColor(name: "虎斑", hex: "7A5C3A"), CoatColor(name: "重点色", hex: "4A2A10")],
                  eyeColors: [EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "橙色", hex: "C06010"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "美国短毛猫",
                  coatColors: [CoatColor(name: "银虎斑", hex: "C0C0C0"), CoatColor(name: "棕虎斑", hex: "7A5C3A"), CoatColor(name: "红虎斑", hex: "B5451B"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "挪威森林猫",
                  coatColors: [CoatColor(name: "棕虎斑白", hex: "7A5C3A"), CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "红白", hex: "B5451B"), CoatColor(name: "蓝白", hex: "7A9AAF"), CoatColor(name: "奶油色", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "铜色", hex: "A05A1A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "缅因库恩猫",
                  coatColors: [CoatColor(name: "棕虎斑", hex: "7A5C3A"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "银色", hex: "C0C0C0"), CoatColor(name: "蓝色", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "缅甸猫",
                  coatColors: [CoatColor(name: "貂褐色", hex: "4A2A10"), CoatColor(name: "蓝色", hex: "7A9AAF"), CoatColor(name: "巧克力色", hex: "4A2C1A"), CoatColor(name: "丁香色", hex: "C0B0C0"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "奶油色", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "黄色", hex: "C8A800"), EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "琥珀色", hex: "C68B1A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "孟加拉猫",
                  coatColors: [CoatColor(name: "棕豹纹", hex: "7A5C3A"), CoatColor(name: "银豹纹", hex: "C0C0C0"), CoatColor(name: "雪色豹纹", hex: "F5E6C8"), CoatColor(name: "蓝豹纹", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "德文卷毛猫",
                  coatColors: [
                      CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "白色", hex: "F5F5F0"),
                      CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "奶油色", hex: "F5E6C8"),
                      CoatColor(name: "棕虎斑", hex: "7A5C3A"), CoatColor(name: "黑白", hex: "2C2C2C"),
                      CoatColor(name: "海豹重点色", hex: "4A2A10"), CoatColor(name: "蓝重点色", hex: "7A9AAF"),
                      CoatColor(name: "巧克力重点色", hex: "4A2C1A"), CoatColor(name: "火焰重点色", hex: "E36A2E")
                  ],
                  eyeColors: [
                      EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "翠绿色", hex: "1A8C3A"),
                      EyeColor(name: "琥珀色", hex: "C68B1A"), EyeColor(name: "铜色", hex: "A05A1A"),
                      EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "蓝色", hex: "2A5C9A"),
                      EyeColor(name: "异瞳", hex: "7A3A7A")
                  ], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "俄罗斯蓝猫",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "翠绿色", hex: "1A8C3A"), EyeColor(name: "绿色", hex: "3D7A30")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "斯芬克斯无毛猫",
                  coatColors: [CoatColor(name: "桃色肤色", hex: "F0C8A0"), CoatColor(name: "黑色肤色", hex: "3A2A1A"), CoatColor(name: "蓝色肤色", hex: "7A9AAF"), CoatColor(name: "虎纹肤色", hex: "7A5C3A")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "土耳其安哥拉猫",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "蓝色", hex: "7A9AAF"), CoatColor(name: "红色", hex: "B5451B")],
                  eyeColors: [EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "琥珀色", hex: "C68B1A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "中华田园猫",
                  coatColors: [CoatColor(name: "橘猫", hex: "C8622A"), CoatColor(name: "黑猫", hex: "1A1A1A"), CoatColor(name: "白猫", hex: "F5F5F0"), CoatColor(name: "三花（黑白橘）", hex: "D4B896"), CoatColor(name: "狸花（虎斑）", hex: "7A5C3A"), CoatColor(name: "玳瑁", hex: "6E2C00"), CoatColor(name: "奶牛（黑白）", hex: "F5F5F0")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "黄色", hex: "C8A800"), EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "银渐层",
                  coatColors: [CoatColor(name: "银底渐层", hex: "C0C0C0"), CoatColor(name: "浅银色", hex: "E0E0E0")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝绿色", hex: "2A7A6A")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "金渐层",
                  coatColors: [CoatColor(name: "金底渐层", hex: "D4A017"), CoatColor(name: "深金色", hex: "B8860B")],
                  eyeColors: [EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "铜绿色", hex: "6B8C3A")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "索马里猫",
                  coatColors: [CoatColor(name: "黄褐色", hex: "C8822A"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "蓝色", hex: "7A9AAF"), CoatColor(name: "栗色", hex: "7B4F2E")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "琥珀色", hex: "C68B1A")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E")
    ]

    // MARK: - Rabbit Breeds (A-Z)
    static let rabbitBreeds: [BreedInfo] = [
        BreedInfo(name: "安哥拉兔", coatColors: coats(["白色", "黑色", "蓝色", "奶油色"]), eyeColors: eyes(["棕色", "蓝色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "垂耳兔", coatColors: coats(["白色", "黑色", "灰色", "棕色", "花斑"]), eyeColors: eyes(["棕色", "蓝色", "粉色（白化）"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "荷兰兔", coatColors: coats(["黑白", "蓝白", "棕白", "灰白"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "狮子兔", coatColors: coats(["白色", "黑色", "棕色", "灰色", "多色"]), eyeColors: eyes(["棕色", "蓝色"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "新西兰兔", coatColors: coats(["白色", "黑色", "红色"]), eyeColors: eyes(["粉色（白化）", "棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "中华田园兔", coatColors: coats(["灰色", "白色", "棕色"]), eyeColors: eyes(["棕色", "红色（白化）"]), suggestedThemeHex: "BDBDBD"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E")
    ]

    // MARK: - Hamster Breeds
    static let hamsterBreeds: [BreedInfo] = [
        BreedInfo(name: "叙利亚仓鼠（金熊）", coatColors: coats(["金黄色", "奶油色", "白色", "黑色", "花斑"]), eyeColors: eyes(["黑色", "红色（白化）"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "侏儒坎贝尔仓鼠", coatColors: coats(["灰棕色", "白色", "珍珠色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "侏儒冬白仓鼠", coatColors: coats(["灰色", "白色（冬季）", "珍珠色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "加卡利亚仓鼠", coatColors: coats(["灰棕色", "蓝宝石色", "珍珠色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "罗伯罗夫斯基仓鼠", coatColors: coats(["沙棕色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E")
    ]

    // MARK: - Bird Breeds
    static let birdBreeds: [BreedInfo] = [
        BreedInfo(name: "虎皮鹦鹉", coatColors: coats(["绿色", "蓝色", "黄色", "白色", "灰色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "玄凤鹦鹉", coatColors: coats(["灰色", "黄化", "白面", "白色"]), eyeColors: eyes(["黑色", "红色（白化）"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "牡丹鹦鹉", coatColors: coats(["绿色", "蓝色", "黄色", "白色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "和尚鹦鹉", coatColors: coats(["绿色", "蓝色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "太阳锥尾鹦鹉", coatColors: coats(["橙黄色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "金刚鹦鹉", coatColors: coats(["红色", "蓝色", "绿色", "黄色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "文鸟", coatColors: coats(["白色", "灰色", "奶油色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "珍珠鸟", coatColors: coats(["橙色脸颊灰色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E")
    ]

    // MARK: - Other Pets
    static let otherBreeds: [BreedInfo] = [
        BreedInfo(name: "荷兰猪", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "龙猫", coatColors: coats(["灰色", "白色", "米色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "刺猬", coatColors: coats(["白腹深刺", "盐椒色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "雪貂", coatColors: coats(["奶油色", "黑色", "白色", "肉桂色"]), eyeColors: eyes(["黑色", "红色（白化）"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "乌龟", coatColors: coats(["绿色", "棕色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "金鱼", coatColors: coats(["红色", "橙色", "白色", "黑色", "花斑"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "锦鲤", coatColors: coats(["红白", "黄色", "黑色", "花斑"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E")
    ]

    // MARK: - Lookup
    static func breeds(for species: String) -> [BreedInfo] {
        let raw: [BreedInfo] = switch Pet.canonicalSpeciesKey(species) {
        case "dog": dogBreeds
        case "cat": catBreeds
        case "rabbit": rabbitBreeds
        case "hamster": hamsterBreeds
        case "bird": birdBreeds
        default: otherBreeds
        }
        // 「其他」固定排在最后
        let others = raw.filter { $0.name == "其他" }
        let sorted = raw.filter { $0.name != "其他" }.sorted { $0.name < $1.name }
        return sorted + others
    }

    // MARK: - Private helpers
    private static func coats(_ names: [String]) -> [CoatColor] {
        names.map { n in
            genericCoatColors.first { $0.name == n } ?? CoatColor(name: n, hex: "BDBDBD")
        }
    }

    private static func eyes(_ names: [String]) -> [EyeColor] {
        names.map { n in
            genericEyeColors.first { $0.name == n } ?? EyeColor(name: n, hex: "BDBDBD")
        }
    }

    // MARK: - Country/City Data
    static let countries: [String] = [
        "中国", "美国", "英国", "法国", "德国", "日本", "韩国", "澳大利亚", "加拿大",
        "意大利", "西班牙", "荷兰", "比利时", "爱尔兰", "俄罗斯", "瑞典", "挪威", "丹麦",
        "芬兰", "冰岛", "瑞士", "奥地利", "葡萄牙", "希腊", "土耳其", "波兰", "捷克",
        "匈牙利", "罗马尼亚", "保加利亚", "克罗地亚", "塞尔维亚", "乌克兰", "以色列",
        "阿联酋", "沙特阿拉伯", "印度", "泰国", "新加坡", "马来西亚", "印度尼西亚",
        "越南", "菲律宾", "新西兰", "巴西", "阿根廷", "智利", "哥伦比亚", "秘鲁",
        "墨西哥", "南非", "埃及", "摩洛哥", "肯尼亚",
        "其他"
    ]

    static let citiesByCountry: [String: [String]] = [
        "中国": ["北京", "上海", "广州", "深圳", "成都", "杭州", "武汉", "南京", "重庆", "西安", "苏州", "长沙", "天津", "青岛", "宁波", "郑州", "厦门", "济南", "合肥", "福州", "昆明", "大连", "哈尔滨", "沈阳", "贵阳", "南昌", "长春", "石家庄", "太原", "兰州", "乌鲁木齐", "海口", "三亚", "香港", "澳门", "台北", "其他"],
        "美国": ["纽约", "洛杉矶", "芝加哥", "旧金山", "西雅图", "波士顿", "华盛顿", "迈阿密", "奥兰多", "休斯敦", "达拉斯", "奥斯汀", "亚特兰大", "费城", "凤凰城", "圣迭戈", "拉斯维加斯", "波特兰", "丹佛", "圣何塞", "其他"],
        "英国": ["伦敦", "曼彻斯特", "伯明翰", "利物浦", "爱丁堡", "格拉斯哥", "布里斯托", "利兹", "谢菲尔德", "纽卡斯尔", "牛津", "剑桥", "卡迪夫", "贝尔法斯特", "其他"],
        "法国": ["巴黎", "里昂", "马赛", "波尔多", "尼斯", "图卢兹", "里尔", "南特", "斯特拉斯堡", "蒙彼利埃", "雷恩", "戛纳", "其他"],
        "德国": ["柏林", "慕尼黑", "汉堡", "法兰克福", "科隆", "杜塞尔多夫", "斯图加特", "莱比锡", "德累斯顿", "不来梅", "汉诺威", "纽伦堡", "波恩", "其他"],
        "日本": ["东京", "大阪", "京都", "名古屋", "横滨", "福冈", "札幌", "神户", "广岛", "仙台", "奈良", "冲绳", "千叶", "埼玉", "其他"],
        "韩国": ["首尔", "釜山", "仁川", "大邱", "大田", "光州", "水原", "蔚山", "济州", "城南", "高阳", "其他"],
        "澳大利亚": ["悉尼", "墨尔本", "布里斯班", "珀斯", "阿德莱德", "堪培拉", "黄金海岸", "霍巴特", "达尔文", "纽卡斯尔", "卧龙岗", "其他"],
        "加拿大": ["多伦多", "温哥华", "蒙特利尔", "卡尔加里", "渥太华", "埃德蒙顿", "魁北克城", "温尼伯", "哈利法克斯", "维多利亚", "滑铁卢", "其他"],
        "意大利": ["罗马", "米兰", "佛罗伦萨", "威尼斯", "都灵", "那不勒斯", "博洛尼亚", "热那亚", "巴勒莫", "维罗纳", "比萨", "其他"],
        "西班牙": ["马德里", "巴塞罗那", "瓦伦西亚", "塞维利亚", "毕尔巴鄂", "马拉加", "格拉纳达", "萨拉戈萨", "阿利坎特", "其他"],
        "荷兰": ["阿姆斯特丹", "鹿特丹", "海牙", "乌得勒支", "埃因霍温", "格罗宁根", "马斯特里赫特", "莱顿", "代尔夫特", "其他"],
        "比利时": ["布鲁塞尔", "安特卫普", "根特", "布鲁日", "鲁汶", "列日", "那慕尔", "沙勒罗瓦", "其他"],
        "爱尔兰": ["都柏林", "科克", "高威", "利默里克", "沃特福德", "基尔肯尼", "其他"],
        "俄罗斯": ["莫斯科", "圣彼得堡", "新西伯利亚", "叶卡捷琳堡", "喀山", "索契", "海参崴", "下诺夫哥罗德", "其他"],
        "瑞典": ["斯德哥尔摩", "哥德堡", "马尔默", "乌普萨拉", "隆德", "林雪平", "于默奥", "其他"],
        "挪威": ["奥斯陆", "卑尔根", "特隆赫姆", "斯塔万格", "特罗姆瑟", "克里斯蒂安桑", "其他"],
        "丹麦": ["哥本哈根", "奥胡斯", "欧登塞", "奥尔堡", "埃斯比约", "罗斯基勒", "其他"],
        "芬兰": ["赫尔辛基", "坦佩雷", "图尔库", "奥卢", "埃斯波", "万塔", "拉赫蒂", "其他"],
        "冰岛": ["雷克雅未克", "科帕沃于尔", "哈夫纳夫约杜尔", "阿克雷里", "凯夫拉维克", "其他"],
        "瑞士": ["苏黎世", "日内瓦", "巴塞尔", "伯尔尼", "洛桑", "卢塞恩", "卢加诺", "圣加仑", "其他"],
        "奥地利": ["维也纳", "萨尔茨堡", "因斯布鲁克", "格拉茨", "林茨", "克拉根福", "其他"],
        "葡萄牙": ["里斯本", "波尔图", "科英布拉", "法鲁", "布拉加", "卡斯凯什", "马德拉", "其他"],
        "希腊": ["雅典", "塞萨洛尼基", "帕特雷", "伊拉克利翁", "罗德", "哈尼亚", "其他"],
        "土耳其": ["伊斯坦布尔", "安卡拉", "伊兹密尔", "安塔利亚", "布尔萨", "科尼亚", "卡帕多奇亚", "其他"],
        "波兰": ["华沙", "克拉科夫", "格但斯克", "弗罗茨瓦夫", "波兹南", "罗兹", "卢布林", "其他"],
        "捷克": ["布拉格", "布尔诺", "俄斯特拉发", "比尔森", "奥洛穆茨", "卡罗维发利", "其他"],
        "匈牙利": ["布达佩斯", "德布勒森", "塞格德", "佩奇", "杰尔", "米什科尔茨", "其他"],
        "罗马尼亚": ["布加勒斯特", "克卢日-纳波卡", "蒂米什瓦拉", "雅西", "布拉索夫", "康斯坦察", "其他"],
        "保加利亚": ["索非亚", "普罗夫迪夫", "瓦尔纳", "布尔加斯", "鲁塞", "其他"],
        "克罗地亚": ["萨格勒布", "斯普利特", "杜布罗夫尼克", "里耶卡", "扎达尔", "其他"],
        "塞尔维亚": ["贝尔格莱德", "诺维萨德", "尼什", "苏博蒂察", "克拉古耶瓦茨", "其他"],
        "乌克兰": ["基辅", "利沃夫", "敖德萨", "哈尔科夫", "第聂伯罗", "切尔诺夫策", "其他"],
        "以色列": ["特拉维夫", "耶路撒冷", "海法", "贝尔谢巴", "埃拉特", "内坦亚", "其他"],
        "阿联酋": ["迪拜", "阿布扎比", "沙迦", "阿治曼", "拉斯海玛", "富查伊拉", "其他"],
        "沙特阿拉伯": ["利雅得", "吉达", "达曼", "麦加", "麦地那", "胡拜尔", "其他"],
        "印度": ["新德里", "孟买", "班加罗尔", "海得拉巴", "钦奈", "加尔各答", "浦那", "斋浦尔", "艾哈迈达巴德", "果阿", "其他"],
        "泰国": ["曼谷", "清迈", "普吉", "芭提雅", "清莱", "孔敬", "苏梅岛", "华欣", "其他"],
        "新加坡": ["中区", "乌节", "滨海湾", "裕廊", "淡滨尼", "兀兰", "榜鹅", "其他"],
        "马来西亚": ["吉隆坡", "槟城", "新山", "马六甲", "怡保", "哥打基纳巴卢", "古晋", "其他"],
        "印度尼西亚": ["雅加达", "巴厘岛", "泗水", "万隆", "日惹", "棉兰", "望加锡", "其他"],
        "越南": ["河内", "胡志明市", "岘港", "会安", "芽庄", "顺化", "大叻", "其他"],
        "菲律宾": ["马尼拉", "宿务", "达沃", "奎松市", "碧瑶", "长滩岛", "伊洛伊洛", "其他"],
        "新西兰": ["奥克兰", "惠灵顿", "基督城", "皇后镇", "汉密尔顿", "但尼丁", "陶朗加", "其他"],
        "巴西": ["圣保罗", "里约热内卢", "巴西利亚", "萨尔瓦多", "福塔莱萨", "库里蒂巴", "贝洛奥里藏特", "其他"],
        "阿根廷": ["布宜诺斯艾利斯", "科尔多瓦", "罗萨里奥", "门多萨", "拉普拉塔", "巴里洛切", "其他"],
        "智利": ["圣地亚哥", "瓦尔帕莱索", "康塞普西翁", "拉塞雷纳", "安托法加斯塔", "蓬塔阿雷纳斯", "其他"],
        "哥伦比亚": ["波哥大", "麦德林", "卡利", "卡塔赫纳", "巴兰基亚", "圣玛尔塔", "其他"],
        "秘鲁": ["利马", "库斯科", "阿雷基帕", "特鲁希略", "皮乌拉", "普诺", "其他"],
        "墨西哥": ["墨西哥城", "瓜达拉哈拉", "蒙特雷", "坎昆", "普埃布拉", "蒂华纳", "梅里达", "其他"],
        "南非": ["约翰内斯堡", "开普敦", "德班", "比勒陀利亚", "伊丽莎白港", "斯泰伦博斯", "其他"],
        "埃及": ["开罗", "亚历山大", "吉萨", "卢克索", "阿斯旺", "沙姆沙伊赫", "赫尔格达", "其他"],
        "摩洛哥": ["卡萨布兰卡", "马拉喀什", "拉巴特", "非斯", "丹吉尔", "阿加迪尔", "其他"],
        "肯尼亚": ["内罗毕", "蒙巴萨", "基苏木", "纳库鲁", "埃尔多雷特", "马林迪", "其他"]
    ]

    static func cities(for country: String) -> [String] {
        citiesByCountry[country] ?? ["其他"]
    }

    // MARK: - P1: 品种护理小贴士

    /// 品种护理建议 [breed名称: 本地化贴士条目]。UI 只能通过 `careTips(for:l:)` 取值，避免非中文语言直接展示中文数据源。
    private static let breedCareTips: [String: BreedCareTipSet] = [
        // 狗
        "边境牧羊犬": .init(
            zh: ["每日需>=2小时高强度运动，智力游戏不可少", "每周梳毛3次，换毛期每天梳", "高能量犬种，适合有经验的主人"],
            en: ["Plan 2+ hours of intense exercise and brain games daily.", "Brush 3 times a week, and daily during shedding season.", "A high-energy breed best for experienced handlers."],
            de: ["Plane täglich mindestens 2 Stunden Bewegung und Denkspiele ein.", "3-mal pro Woche bürsten, im Fellwechsel täglich.", "Eine energiegeladene Rasse für erfahrene Halter."]
        ),
        "澳大利亚牧羊犬": .init(
            zh: ["每日需要充足运动和互动训练", "中长毛每周梳理2-3次，换毛期增加频率", "聪明敏感，适合嗅闻、敏捷和服从游戏"],
            en: ["Needs generous daily exercise plus interactive training.", "Brush the medium coat 2-3 times weekly, more during shedding.", "Smart and sensitive; scent, agility, and obedience games fit well."],
            de: ["Braucht täglich viel Bewegung und interaktives Training.", "Mittellanges Fell 2-3-mal pro Woche bürsten, im Fellwechsel öfter.", "Klug und sensibel; Nasenarbeit, Agility und Gehorsam passen gut."]
        ),
        "金毛寻回犬": .init(
            zh: ["每周梳毛2-3次，洗澡约4-6周一次", "每日散步>=1小时，喜欢游泳", "关注关节健康，体重控制很重要"],
            en: ["Brush 2-3 times weekly; bathe about every 4-6 weeks.", "Aim for at least 1 hour of walking daily; many love swimming.", "Watch joints and keep weight under control."],
            de: ["2-3-mal pro Woche bürsten; etwa alle 4-6 Wochen baden.", "Täglich mindestens 1 Stunde spazieren; viele schwimmen gern.", "Gelenke beobachten und Gewicht konsequent kontrollieren."]
        ),
        "拉布拉多寻回犬": .init(
            zh: ["食欲旺盛，注意控制饮食防止肥胖", "每日运动1-2小时，喜欢游泳", "每周梳毛2次，换毛期每天梳"],
            en: ["Strong appetite; portion control helps prevent obesity.", "Needs 1-2 hours of activity daily and often loves swimming.", "Brush twice weekly, and daily during shedding season."],
            de: ["Großer Appetit; Portionen kontrollieren, um Übergewicht zu vermeiden.", "Braucht täglich 1-2 Stunden Aktivität und schwimmt oft gern.", "2-mal pro Woche bürsten, im Fellwechsel täglich."]
        ),
        "柴犬": .init(
            zh: ["独立性强，需耐心社会化训练", "每周梳毛1-2次，换毛期每天梳", "每日散步30-60分钟即可"],
            en: ["Independent; patient socialization matters.", "Brush 1-2 times weekly, and daily during shedding season.", "30-60 minutes of walking each day is usually enough."],
            de: ["Eigenständig; geduldige Sozialisierung ist wichtig.", "1-2-mal pro Woche bürsten, im Fellwechsel täglich.", "30-60 Minuten Spaziergang pro Tag reichen meist."]
        ),
        "泰迪/贵宾犬": .init(
            zh: ["毛发持续生长，每6-8周专业美容一次", "聪明易训练，适合做各类 trick", "日常刷牙很重要，牙齿疾病高发"],
            en: ["Coat keeps growing; professional grooming every 6-8 weeks helps.", "Highly trainable and great for trick practice.", "Daily tooth brushing matters because dental disease is common."],
            de: ["Das Fell wächst weiter; alle 6-8 Wochen professionell pflegen lassen.", "Sehr lernfreudig und gut für Tricks geeignet.", "Tägliches Zähneputzen ist wichtig, da Zahnprobleme häufig sind."]
        ),
        "比熊犬": .init(
            zh: ["毛发需每日梳理防打结，每4-6周美容", "每日中等运动，适合公寓居住", "泪痕明显，需定期清洁眼周"],
            en: ["Brush daily to prevent mats; groom every 4-6 weeks.", "Moderate daily activity works well for apartment life.", "Tear stains are common; clean around the eyes regularly."],
            de: ["Täglich bürsten, um Verfilzungen zu vermeiden; alle 4-6 Wochen pflegen.", "Mäßige tägliche Bewegung passt gut zur Wohnung.", "Tränenflecken sind häufig; Augenbereich regelmäßig reinigen."]
        ),
        "英国短毛猫": .init(
            zh: ["每周梳毛1-2次即可，偶尔掉毛", "体型偏胖，注意饮食控制", "性格温和，适合室内生活"],
            en: ["Brush 1-2 times weekly; shedding is usually moderate.", "Prone to weight gain, so keep portions steady.", "Calm temperament and well suited to indoor life."],
            de: ["1-2-mal pro Woche bürsten; Haaren meist mäßig.", "Neigt zu Gewichtszunahme, daher Portionen im Blick behalten.", "Ruhiges Wesen und gut für Wohnungshaltung geeignet."]
        ),
        "布偶猫": .init(
            zh: ["毛发柔软，每周梳理2-3次防结块", "性格温顺，不适合独处太久", "体型大，成猫体重可达8-10kg"],
            en: ["Soft coat; brush 2-3 times weekly to prevent tangles.", "Gentle and social, so long lonely stretches are not ideal.", "Large breed; adults can reach 8-10 kg."],
            de: ["Weiches Fell; 2-3-mal pro Woche bürsten gegen Knoten.", "Sanft und sozial, daher lange Alleinzeiten vermeiden.", "Große Rasse; erwachsene Tiere können 8-10 kg erreichen."]
        ),
        "缅因猫": .init(
            zh: ["半长毛，每周梳理2次", "体型最大的家猫之一，需要空间活动", "喜水，部分个体可以学习玩水"],
            en: ["Semi-long coat; brush about twice weekly.", "One of the largest house cats and needs room to move.", "Often curious about water; some can learn water play."],
            de: ["Halblanges Fell; etwa 2-mal pro Woche bürsten.", "Eine der größten Hauskatzen und braucht Bewegungsraum.", "Oft wasserneugierig; manche lernen Wasserspiele."]
        ),
        "美国短毛猫": .init(
            zh: ["短毛易打理，每周梳理1次", "性格活泼，适应力强", "注意体重控制，容易发胖"],
            en: ["Short coat is easy; weekly brushing is enough.", "Playful and adaptable temperament.", "Watch weight, as this breed can gain easily."],
            de: ["Kurzhaar ist pflegeleicht; wöchentliches Bürsten reicht.", "Verspielt und anpassungsfähig.", "Gewicht im Blick behalten, da sie leicht zunimmt."]
        ),
        "哈士奇": .init(
            zh: ["换毛期大量掉毛，每天梳毛必不可少", "需要大量运动，每日>=2小时", "聪明但独立，逃跑能力强，需防护"],
            en: ["Heavy seasonal shedding; daily brushing is essential then.", "Needs lots of activity, often 2+ hours daily.", "Smart but independent; secure fences and leads matter."],
            de: ["Starker Fellwechsel; dann täglich bürsten.", "Braucht viel Aktivität, oft 2+ Stunden täglich.", "Klug, aber eigenständig; sichere Leinen und Zäune sind wichtig."]
        ),
        "阿拉斯加雪橇犬": .init(
            zh: ["毛量惊人，换毛期需每日梳毛", "体型大，需充足运动空间", "不耐热，夏季注意防暑"],
            en: ["Very dense coat; brush daily during shedding season.", "Large body and needs plenty of movement space.", "Heat-sensitive; plan summer cooling carefully."],
            de: ["Sehr dichtes Fell; im Fellwechsel täglich bürsten.", "Großer Körper und viel Bewegungsraum nötig.", "Hitzeempfindlich; im Sommer gut kühlen."]
        ),
        "萨摩耶": .init(
            zh: ["白色毛发需定期清洁，每周梳毛2-3次", "活泼友善，需要陪伴和运动", "微笑天使，但掉毛量惊人"],
            en: ["White coat needs regular cleaning and 2-3 brushes weekly.", "Friendly and lively; needs company and exercise.", "Lovely smile, serious shedding."],
            de: ["Weißes Fell regelmäßig reinigen und 2-3-mal pro Woche bürsten.", "Freundlich und lebhaft; braucht Nähe und Bewegung.", "Charmantes Lächeln, aber viel Fellverlust."]
        ),
        "西高地白梗": .init(
            zh: ["白色被毛需定期清洁，避免泪痕和口周染色", "活泼自信，每日散步和嗅闻游戏不可少", "注意皮肤敏感和耳朵清洁"],
            en: ["Clean the white coat regularly to reduce tear and mouth staining.", "Confident and lively; daily walks and sniff games help.", "Watch sensitive skin and keep ears clean."],
            de: ["Weißes Fell regelmäßig reinigen, um Augen- und Maulflecken zu reduzieren.", "Selbstbewusst und lebhaft; tägliche Spaziergänge und Schnüffelspiele helfen.", "Empfindliche Haut beobachten und Ohren sauber halten."]
        ),
        "博美": .init(
            zh: ["双层毛发，每周梳毛2-3次", "体型小但活力十足", "膝盖骨脱臼高发，注意关节保护"],
            en: ["Double coat; brush 2-3 times weekly.", "Small body, big energy.", "Patellar issues are common, so protect the joints."],
            de: ["Doppelfell; 2-3-mal pro Woche bürsten.", "Kleiner Körper, viel Energie.", "Kniescheibenprobleme sind häufig, daher Gelenke schützen."]
        ),
        "巴哥犬": .init(
            zh: ["短鼻犬种，不耐热，夏季避免剧烈运动", "注意控制体重，肥胖会加重呼吸负担", "每日清洁面部褶皱和眼周"],
            en: ["Flat-faced breed; avoid intense summer exercise.", "Weight control reduces breathing strain.", "Clean facial folds and eye area daily."],
            de: ["Kurznasige Rasse; im Sommer intensive Bewegung vermeiden.", "Gewichtskontrolle entlastet die Atmung.", "Gesichtsfalten und Augenbereich täglich reinigen."]
        ),
        "波士顿梗": .init(
            zh: ["短鼻犬种，炎热天气减少户外强度", "短毛易打理，每周梳理1次即可", "活泼聪明，适合短时间多频率训练"],
            en: ["Flat-faced breed; lower outdoor intensity in hot weather.", "Short coat is easy; weekly brushing is enough.", "Bright and lively; short frequent training works well."],
            de: ["Kurznasige Rasse; bei Hitze draußen ruhiger machen.", "Kurzhaar ist pflegeleicht; wöchentliches Bürsten reicht.", "Klug und lebhaft; kurze häufige Trainings passen gut."]
        ),
        "法国斗牛犬": .init(
            zh: ["短鼻犬种，注意呼吸道护理", "清洁皮肤褶皱，防止细菌滋生", "不耐热，夏季避免剧烈运动"],
            en: ["Flat-faced breed; monitor breathing comfort.", "Clean skin folds to reduce bacterial buildup.", "Heat-sensitive; avoid intense summer exercise."],
            de: ["Kurznasige Rasse; Atmung aufmerksam beobachten.", "Hautfalten reinigen, um Bakterien zu reduzieren.", "Hitzeempfindlich; im Sommer starke Belastung vermeiden."]
        ),
        "英国斗牛犬": .init(
            zh: ["清洁面部皱褶非常重要，每天擦拭", "短鼻犬种，高温下谨慎运动", "体重管理严格，关节负担大"],
            en: ["Wipe facial wrinkles daily; it is essential care.", "Flat-faced breed; be cautious with heat.", "Strict weight control protects overloaded joints."],
            de: ["Gesichtsfalten täglich abwischen; das ist zentrale Pflege.", "Kurznasige Rasse; bei Hitze vorsichtig bewegen.", "Strenge Gewichtskontrolle schützt belastete Gelenke."]
        ),
        "吉娃娃": .init(
            zh: ["注意保暖，冬季需穿衣", "牙齿较小，每日刷牙防牙石", "骨骼细小，避免从高处跳下"],
            en: ["Keep warm; winter clothing may be needed.", "Small teeth need daily brushing to reduce tartar.", "Fragile frame; prevent jumps from height."],
            de: ["Warm halten; im Winter kann Kleidung nötig sein.", "Kleine Zähne täglich putzen, um Zahnstein zu reduzieren.", "Zarter Körper; Sprünge aus Höhe vermeiden."]
        ),
        "杰克罗素梗": .init(
            zh: ["精力旺盛，每天需要充足运动和嗅闻游戏", "聪明但主见强，训练要稳定一致", "短毛护理简单，每周梳理1次"],
            en: ["High energy; needs daily exercise and sniff games.", "Smart but strong-willed, so keep training consistent.", "Short coat is simple; brush weekly."],
            de: ["Sehr aktiv; braucht täglich Bewegung und Schnüffelspiele.", "Klug, aber willensstark; Training konsequent halten.", "Kurzhaar ist einfach; wöchentlich bürsten."]
        ),
        "秋田犬": .init(
            zh: ["独立且护主，幼犬期社会化非常重要", "双层毛换毛明显，换毛期需每日梳理", "体型较大，注意关节和体重管理"],
            en: ["Independent and protective; puppy socialization is crucial.", "Double coat sheds heavily; brush daily during shedding.", "Large body; watch joints and weight."],
            de: ["Eigenständig und beschützend; frühe Sozialisierung ist sehr wichtig.", "Doppelfell mit starkem Wechsel; dann täglich bürsten.", "Großer Körper; Gelenke und Gewicht beachten."]
        ),
        "罗威纳犬": .init(
            zh: ["力量大，需要稳定牵引和服从训练", "注意关节健康和体重控制", "短毛护理简单，每周梳理1次"],
            en: ["Powerful breed; steady leash and obedience work matter.", "Watch joint health and weight control.", "Short coat is simple; brush weekly."],
            de: ["Kräftige Rasse; stabile Leinenführung und Gehorsam sind wichtig.", "Gelenkgesundheit und Gewicht kontrollieren.", "Kurzhaar ist einfach; wöchentlich bürsten."]
        ),
        "沙皮犬": .init(
            zh: ["皮肤褶皱需保持干爽，注意皮肤炎症", "耳道较窄，定期检查清洁耳朵", "运动中等，避免高温环境"],
            en: ["Keep skin folds dry and watch for inflammation.", "Narrow ear canals need regular checks and cleaning.", "Moderate activity; avoid hot environments."],
            de: ["Hautfalten trocken halten und Entzündungen beobachten.", "Enge Gehörgänge regelmäßig prüfen und reinigen.", "Mäßige Bewegung; Hitze vermeiden."]
        ),
        "松狮犬": .init(
            zh: ["厚毛怕热，夏季注意降温", "每周梳毛2-3次，换毛期增加频率", "性格独立，训练需耐心且一致"],
            en: ["Thick coat traps heat; prioritize cooling in summer.", "Brush 2-3 times weekly, more during shedding.", "Independent nature; training needs patience and consistency."],
            de: ["Dickes Fell speichert Hitze; im Sommer gut kühlen.", "2-3-mal pro Woche bürsten, im Fellwechsel öfter.", "Eigenständiges Wesen; Training braucht Geduld und Konstanz."]
        ),
        "喜乐蒂牧羊犬": .init(
            zh: ["中长毛每周梳理2-3次，换毛期更频繁", "聪明敏感，适合服从和嗅闻训练", "运动需求中高，需要稳定陪伴"],
            en: ["Brush the medium coat 2-3 times weekly, more while shedding.", "Smart and sensitive; obedience and scent work fit well.", "Medium-high exercise needs and steady companionship."],
            de: ["Mittellanges Fell 2-3-mal pro Woche bürsten, im Fellwechsel öfter.", "Klug und sensibel; Gehorsam und Nasenarbeit passen gut.", "Mittelhoher bis hoher Bewegungsbedarf und verlässliche Nähe."]
        ),
        "腊肠犬": .init(
            zh: ["脊椎问题高发，减少跳跃上下楼梯", "注意体重控制", "每周梳毛1次（短毛型）"],
            en: ["Back issues are common; reduce jumping and stairs.", "Keep weight controlled.", "Brush weekly for short-coated types."],
            de: ["Rückenprobleme sind häufig; Sprünge und Treppen reduzieren.", "Gewicht im Blick behalten.", "Kurzhaarige Varianten wöchentlich bürsten."]
        ),
        "雪纳瑞": .init(
            zh: ["胡须需定期清洁，避免食物残留", "每8-12周专业美容一次", "容易形成结石，多喝水"],
            en: ["Clean the beard regularly to remove food residue.", "Professional grooming every 8-12 weeks helps.", "Can be prone to stones; encourage water intake."],
            de: ["Bart regelmäßig reinigen, damit keine Futterreste bleiben.", "Professionelle Pflege alle 8-12 Wochen hilft.", "Kann zu Steinen neigen; Wasseraufnahme fördern."]
        ),
        "马尔济斯": .init(
            zh: ["丝状长毛需每日梳理或定期剪短", "泪痕问题，每日清洁眼周", "体型娇小，注意低血糖风险"],
            en: ["Silky long coat needs daily brushing or regular trimming.", "Tear staining is common; clean around the eyes daily.", "Tiny body; watch low blood sugar risk."],
            de: ["Seidiges Langhaar täglich bürsten oder regelmäßig kürzen.", "Tränenflecken sind häufig; Augenbereich täglich reinigen.", "Sehr klein; Risiko für Unterzuckerung beachten."]
        ),
        "中华田园犬": .init(
            zh: ["适应性强，日常护理简单", "每周梳毛1次，注意耳朵清洁", "性格忠诚，需充足运动和社会化"],
            en: ["Adaptable and usually simple to care for.", "Brush weekly and keep ears clean.", "Loyal temperament; needs enough activity and socialization."],
            de: ["Anpassungsfähig und meist unkompliziert in der Pflege.", "Wöchentlich bürsten und Ohren sauber halten.", "Treues Wesen; braucht genug Bewegung und Sozialisierung."]
        )
    ]

    /// 查找品种护理贴士（模糊匹配）
    static func careTips(for breed: String) -> [String]? {
        careTips(for: breed, l: L10n())
    }

    /// 查找本地化品种护理贴士（模糊匹配）
    static func careTips(for breed: String, l: L10n) -> [String]? {
        let normalized = breed.trimmingCharacters(in: .whitespaces)
        // 精确匹配
        if let tips = breedCareTips[normalized] { return tips.resolve(l: l) }
        // 模糊匹配（包含关系）
        for (key, tips) in breedCareTips {
            if normalized.contains(key) || key.contains(normalized) {
                return tips.resolve(l: l)
            }
        }
        return nil
    }
}

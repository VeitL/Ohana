//
//  PetBreedDatabase.swift
//  Ohana
//
//  品种数据库：涵盖市场常见品种，含毛色/瞳色/推荐主题色
//

import SwiftUI

// MARK: - Coat Color
struct CoatColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

// MARK: - Eye Color
struct EyeColor: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let hex: String
    var color: Color { Color(hex: hex) }
}

// MARK: - Breed Info
struct BreedInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let coatColors: [CoatColor]
    let eyeColors: [EyeColor]
    let suggestedThemeHex: String
    
    static func == (lhs: BreedInfo, rhs: BreedInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Pet Breed Database
enum PetBreedDatabase {
    
    // MARK: - Common Colors
    static let genericCoatColors: [CoatColor] = [
        CoatColor(name: "黑色",     hex: "1A1A1A"),
        CoatColor(name: "白色",     hex: "F5F5F0"),
        CoatColor(name: "灰色",     hex: "9E9E9E"),
        CoatColor(name: "深灰色",   hex: "5C5C5C"),
        CoatColor(name: "浅灰色",   hex: "CFCFCF"),
        CoatColor(name: "棕色",     hex: "7B4F2E"),
        CoatColor(name: "深棕色",   hex: "4A2A10"),
        CoatColor(name: "红棕色",   hex: "8B3A1A"),
        CoatColor(name: "金黄色",   hex: "D4A017"),
        CoatColor(name: "奶油色",   hex: "F5E6C8"),
        CoatColor(name: "红色",     hex: "B5451B"),
        CoatColor(name: "橙色",     hex: "C8622A"),
        CoatColor(name: "杏色",     hex: "E8C49A"),
        CoatColor(name: "蓝灰色",   hex: "7A9AAF"),
        CoatColor(name: "银色",     hex: "C0C0C0"),
        CoatColor(name: "巧克力色", hex: "4A2C1A"),
        CoatColor(name: "虎斑色",   hex: "7A5C3A"),
        CoatColor(name: "花斑色",   hex: "C8B4A0"),
        CoatColor(name: "其他",     hex: "BDBDBD"),
    ]

    // 奶牛色专用（黑白双色，底色白，重点黑）
    static let cowPatternCoatColors: [CoatColor] = [
        CoatColor(name: "奶牛白底", hex: "F5F5F0"),
        CoatColor(name: "奶牛黑斑", hex: "1A1A1A"),
    ]

    static let genericEyeColors: [EyeColor] = [
        EyeColor(name: "棕色",   hex: "6B3A2A"),
        EyeColor(name: "深棕色", hex: "3D1F0D"),
        EyeColor(name: "琥珀色", hex: "C68B1A"),
        EyeColor(name: "金色",   hex: "D4A017"),
        EyeColor(name: "黄色",   hex: "C8A800"),
        EyeColor(name: "绿色",   hex: "3D7A30"),
        EyeColor(name: "翠绿色", hex: "1A8C3A"),
        EyeColor(name: "蓝绿色", hex: "2A7A6A"),
        EyeColor(name: "蓝色",   hex: "2A5C9A"),
        EyeColor(name: "浅蓝色", hex: "5A9ACA"),
        EyeColor(name: "冰蓝色", hex: "9EC8E8"),
        EyeColor(name: "铜色",   hex: "A05A1A"),
        EyeColor(name: "橙色",   hex: "C06010"),
        EyeColor(name: "榛色",   hex: "7A5A2A"),
        EyeColor(name: "黑色",   hex: "1C1C1C"),
        EyeColor(name: "异瞳",   hex: "7A3A7A"),
        EyeColor(name: "红色",   hex: "CC2200"),
        EyeColor(name: "其他",   hex: "BDBDBD"),
    ]
    
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
        BreedInfo(name: "腊肠犬",
                  coatColors: [CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "巧克力棕", hex: "4A2C1A"), CoatColor(name: "黑棕", hex: "1A1A0A"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "花斑", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "795548"),
        BreedInfo(name: "拉布拉多犬",
                  coatColors: [CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "黄色", hex: "D4A017"), CoatColor(name: "巧克力色", hex: "4A2C1A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "榛色", hex: "7A5A2A")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "金毛寻回犬",
                  coatColors: [CoatColor(name: "浅奶油金", hex: "F5E6C8"), CoatColor(name: "金黄色", hex: "D4A017"), CoatColor(name: "深金色", hex: "B8860B"), CoatColor(name: "红金色", hex: "C8622A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "柯基犬",
                  coatColors: [CoatColor(name: "红白", hex: "C85A1A"), CoatColor(name: "貂色白", hex: "A05A1A"), CoatColor(name: "黑白三色", hex: "1A1A0A")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "可卡犬",
                  coatColors: [CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "金色", hex: "D4A017"), CoatColor(name: "巧克力色", hex: "4A2C1A"), CoatColor(name: "花斑", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "榛色", hex: "7A5A2A")], suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "马尔济斯犬",
                  coatColors: [CoatColor(name: "纯白", hex: "F5F5F0")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "迷你雪纳瑞",
                  coatColors: [CoatColor(name: "椒盐色", hex: "9E9E9E"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "黑银色", hex: "2A2A2A"), CoatColor(name: "白色", hex: "F5F5F0")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "萨摩耶犬",
                  coatColors: [CoatColor(name: "纯白", hex: "F5F5F0"), CoatColor(name: "奶白色", hex: "F5E6C8")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "泰迪/贵宾犬",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "杏色", hex: "E8C49A"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "棕色", hex: "7B4F2E"), CoatColor(name: "银色", hex: "C0C0C0"), CoatColor(name: "蓝灰色", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "琥珀色", hex: "C68B1A")], suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "西伯利亚哈士奇",
                  coatColors: [CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "灰白", hex: "9E9E9E"), CoatColor(name: "红白", hex: "8B3A1A"), CoatColor(name: "纯白", hex: "F5F5F0"), CoatColor(name: "银白", hex: "E0E0E0")],
                  eyeColors: [EyeColor(name: "冰蓝色", hex: "9EC8E8"), EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "西施犬",
                  coatColors: [CoatColor(name: "金白色", hex: "D4A017"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑白", hex: "2A2A2A"), CoatColor(name: "红白", hex: "B5451B"), CoatColor(name: "多色", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D")], suggestedThemeHex: "FFC107"),
        BreedInfo(name: "约克夏梗",
                  coatColors: [CoatColor(name: "钢蓝背棕腿", hex: "4A5A7A"), CoatColor(name: "金棕色", hex: "C8A800")],
                  eyeColors: [EyeColor(name: "深棕色", hex: "3D1F0D"), EyeColor(name: "黑色", hex: "1C1C1C")], suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "中华田园犬",
                  coatColors: [CoatColor(name: "黄色", hex: "D4A017"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "花斑", hex: "C8B4A0")],
                  eyeColors: [EyeColor(name: "棕色", hex: "6B3A2A"), EyeColor(name: "黄色", hex: "C8A800")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
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
        BreedInfo(name: "苏格兰折耳猫",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "金色", hex: "D4A017"), CoatColor(name: "银色", hex: "C0C0C0"), CoatColor(name: "虎斑", hex: "7A5C3A"), CoatColor(name: "玳瑁", hex: "6E2C00")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "英国短毛猫",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF"), CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "金渐层", hex: "D4A017"), CoatColor(name: "银渐层", hex: "C0C0C0"), CoatColor(name: "虎斑", hex: "7A5C3A"), CoatColor(name: "重点色", hex: "4A2A10")],
                  eyeColors: [EyeColor(name: "铜色", hex: "A05A1A"), EyeColor(name: "橙色", hex: "C06010"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "90A4AE"),
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
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "黄色", hex: "C8A800")], suggestedThemeHex: "795548"),
        BreedInfo(name: "孟加拉猫",
                  coatColors: [CoatColor(name: "棕豹纹", hex: "7A5C3A"), CoatColor(name: "银豹纹", hex: "C0C0C0"), CoatColor(name: "雪色豹纹", hex: "F5E6C8"), CoatColor(name: "蓝豹纹", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A")], suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "德文卷毛猫",
                  coatColors: [CoatColor(name: "白色", hex: "F5F5F0"), CoatColor(name: "黑色", hex: "1A1A1A"), CoatColor(name: "蓝色", hex: "7A9AAF"), CoatColor(name: "奶油色", hex: "F5E6C8"), CoatColor(name: "红色", hex: "B5451B"), CoatColor(name: "银渐层", hex: "C0C0C0"), CoatColor(name: "玳瑁", hex: "6E2C00")],
                  eyeColors: [EyeColor(name: "金色", hex: "D4A017"), EyeColor(name: "绿色", hex: "3D7A30"), EyeColor(name: "蓝色", hex: "2A5C9A"), EyeColor(name: "异瞳", hex: "7A3A7A")], suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "俄罗斯蓝猫",
                  coatColors: [CoatColor(name: "蓝灰色", hex: "7A9AAF")],
                  eyeColors: [EyeColor(name: "翠绿色", hex: "1A8C3A")], suggestedThemeHex: "90A4AE"),
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
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
    ]
    
    // MARK: - Rabbit Breeds (A-Z)
    static let rabbitBreeds: [BreedInfo] = [
        BreedInfo(name: "安哥拉兔", coatColors: coats(["白色","黑色","蓝色","奶油色"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "垂耳兔", coatColors: coats(["白色","黑色","灰色","棕色","花斑"]), eyeColors: eyes(["棕色","蓝色","粉色（白化）"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "荷兰兔", coatColors: coats(["黑白","蓝白","棕白","灰白"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "狮子兔", coatColors: coats(["白色","黑色","棕色","灰色","多色"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "新西兰兔", coatColors: coats(["白色","黑色","红色"]), eyeColors: eyes(["粉色（白化）","棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "中华田园兔", coatColors: coats(["灰色","白色","棕色"]), eyeColors: eyes(["棕色","红色（白化）"]), suggestedThemeHex: "BDBDBD"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
    ]
    
    // MARK: - Hamster Breeds
    static let hamsterBreeds: [BreedInfo] = [
        BreedInfo(name: "叙利亚仓鼠（金熊）", coatColors: coats(["金黄色","奶油色","白色","黑色","花斑"]), eyeColors: eyes(["黑色","红色（白化）"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "侏儒坎贝尔仓鼠", coatColors: coats(["灰棕色","白色","珍珠色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "侏儒冬白仓鼠", coatColors: coats(["灰色","白色（冬季）","珍珠色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "加卡利亚仓鼠", coatColors: coats(["灰棕色","蓝宝石色","珍珠色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "罗伯罗夫斯基仓鼠", coatColors: coats(["沙棕色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
    ]
    
    // MARK: - Bird Breeds
    static let birdBreeds: [BreedInfo] = [
        BreedInfo(name: "虎皮鹦鹉", coatColors: coats(["绿色","蓝色","黄色","白色","灰色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "玄凤鹦鹉", coatColors: coats(["灰色","黄化","白面","白色"]), eyeColors: eyes(["黑色","红色（白化）"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "牡丹鹦鹉", coatColors: coats(["绿色","蓝色","黄色","白色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "和尚鹦鹉", coatColors: coats(["绿色","蓝色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "太阳锥尾鹦鹉", coatColors: coats(["橙黄色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "金刚鹦鹉", coatColors: coats(["红色","蓝色","绿色","黄色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "文鸟", coatColors: coats(["白色","灰色","奶油色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "珍珠鸟", coatColors: coats(["橙色脸颊灰色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
    ]
    
    // MARK: - Other Pets
    static let otherBreeds: [BreedInfo] = [
        BreedInfo(name: "荷兰猪", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "龙猫", coatColors: coats(["灰色","白色","米色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "刺猬", coatColors: coats(["白腹深刺","盐椒色"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "雪貂", coatColors: coats(["奶油色","黑色","白色","肉桂色"]), eyeColors: eyes(["黑色","红色（白化）"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "乌龟", coatColors: coats(["绿色","棕色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "66BB6A"),
        BreedInfo(name: "金鱼", coatColors: coats(["红色","橙色","白色","黑色","花斑"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "锦鲤", coatColors: coats(["红白","黄色","黑色","花斑"]), eyeColors: eyes(["黑色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
    ]
    
    // MARK: - Lookup
    static func breeds(for species: String) -> [BreedInfo] {
        let raw: [BreedInfo]
        switch species {
        case "狗": raw = dogBreeds
        case "猫": raw = catBreeds
        case "兔子": raw = rabbitBreeds
        case "仓鼠": raw = hamsterBreeds
        case "鸟": raw = birdBreeds
        default: raw = otherBreeds
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
        "意大利", "西班牙", "荷兰", "比利时", "俄罗斯", "瑞典", "挪威", "丹麦",
        "芬兰", "瑞士", "奥地利", "葡萄牙", "希腊", "土耳其", "波兰", "捷克",
        "匈牙利", "罗马尼亚", "印度", "泰国", "新加坡", "马来西亚", "印度尼西亚",
        "越南", "菲律宾", "新西兰", "巴西", "阿根廷", "墨西哥", "南非", "埃及",
        "其他"
    ]
    
    static let citiesByCountry: [String: [String]] = [
        "中国": ["北京", "上海", "广州", "深圳", "成都", "杭州", "武汉", "南京", "重庆",
                  "西安", "苏州", "长沙", "天津", "青岛", "宁波", "郑州", "厦门", "济南",
                  "合肥", "福州", "昆明", "大连", "哈尔滨", "沈阳", "贵阳", "南昌", "其他"],
        "美国": ["纽约", "洛杉矶", "芝加哥", "旧金山", "西雅图", "波士顿", "迈阿密", "其他"],
        "英国": ["伦敦", "曼彻斯特", "伯明翰", "利物浦", "爱丁堡", "格拉斯哥", "其他"],
        "法国": ["巴黎", "里昂", "马赛", "波尔多", "尼斯", "其他"],
        "德国": ["柏林", "慕尼黑", "汉堡", "法兰克福", "科隆", "其他"],
        "日本": ["东京", "大阪", "京都", "名古屋", "横滨", "福冈", "札幌", "其他"],
        "韩国": ["首尔", "釜山", "仁川", "大邱", "其他"],
        "澳大利亚": ["悉尼", "墨尔本", "布里斯班", "珀斯", "阿德莱德", "其他"],
        "加拿大": ["多伦多", "温哥华", "蒙特利尔", "卡尔加里", "渥太华", "其他"],
    ]
    
    static func cities(for country: String) -> [String] {
        citiesByCountry[country] ?? ["其他"]
    }

    // MARK: - P1: 品种护理小贴士

    /// 品种护理建议 [breed名称: [贴士条目]]
    static let breedCareTips: [String: [String]] = [
        // 狗
        "边境牧羊犬": ["每日需≥2小时高强度运动，智力游戏不可少", "每周梳毛3次，换毛期每天梳", "高能量犬种，适合有经验的主人"],
        "金毛寻回犬": ["每周梳毛2-3次，洗澡约4-6周一次", "每日散步≥1小时，喜欢游泳", "关注关节健康，体重控制很重要"],
        "拉布拉多寻回犬": ["食欲旺盛，注意控制饮食防止肥胖", "每日运动1-2小时，喜欢游泳", "每周梳毛2次，换毛期每天梳"],
        "柴犬": ["独立性强，需耐心社会化训练", "每周梳毛1-2次，换毛期每天梳", "每日散步30-60分钟即可"],
        "泰迪/贵宾犬": ["毛发持续生长，每6-8周专业美容一次", "聪明易训练，适合做各类trick", "日常刷牙很重要，牙齿疾病高发"],
        "比熊犬": ["毛发需每日梳理防打结，每4-6周美容", "每日中等运动，适合公寓居住", "泪痕明显，需定期清洁眼周"],
        "英国短毛猫": ["每周梳毛1-2次即可，偶尔掉毛", "体型偏胖，注意饮食控制", "性格温和，适合室内生活"],
        "布偶猫": ["毛发柔软，每周梳理2-3次防结块", "性格温顺，不适合独处太久", "体型大，成猫体重可达8-10kg"],
        "缅因猫": ["半长毛，每周梳理2次", "体型最大的家猫之一，需要空间活动", "喜水，部分个体可以学习玩水"],
        "美国短毛猫": ["短毛易打理，每周梳理1次", "性格活泼，适应力强", "注意体重控制，容易发胖"],
        "哈士奇": ["换毛期大量掉毛，每天梳毛必不可少", "需要大量运动，每日≥2小时", "聪明但独立，逃跑能力强，需防护"],
        "阿拉斯加雪橇犬": ["毛量惊人，换毛期需每日梳毛", "体型大，需充足运动空间", "不耐热，夏季注意防暑"],
        "萨摩耶": ["白色毛发需定期清洁，每周梳毛2-3次", "活泼友善，需要陪伴和运动", "微笑天使，但掉毛量惊人"],
        "博美": ["双层毛发，每周梳毛2-3次", "体型小但活力十足", "膝盖骨脱臼高发，注意关节保护"],
        "法国斗牛犬": ["短鼻犬种，注意呼吸道护理", "清洁皮肤褶皱，防止细菌滋生", "不耐热，夏季避免剧烈运动"],
        "英国斗牛犬": ["清洁面部皱褶非常重要，每天擦拭", "短鼻犬种，高温下谨慎运动", "体重管理严格，关节负担大"],
        "吉娃娃": ["注意保暖，冬季需穿衣", "牙齿较小，每日刷牙防牙石", "骨骼细小，避免从高处跳下"],
        "腊肠犬": ["脊椎问题高发，减少跳跃上下楼梯", "注意体重控制", "每周梳毛1次（短毛型）"],
        "雪纳瑞": ["胡须需定期清洁，避免食物残留", "每8-12周专业美容一次", "容易形成结石，多喝水"],
        "马尔济斯": ["丝状长毛需每日梳理或定期剪短", "泪痕问题，每日清洁眼周", "体型娇小，注意低血糖风险"],
        "中华田园犬": ["适应性强，日常护理简单", "每周梳毛1次，注意耳朵清洁", "性格忠诚，需充足运动和社会化"],
    ]

    /// 查找品种护理贴士（模糊匹配）
    static func careTips(for breed: String) -> [String]? {
        let normalized = breed.trimmingCharacters(in: .whitespaces)
        // 精确匹配
        if let tips = breedCareTips[normalized] { return tips }
        // 模糊匹配（包含关系）
        for (key, tips) in breedCareTips {
            if normalized.contains(key) || key.contains(normalized) {
                return tips
            }
        }
        return nil
    }
}

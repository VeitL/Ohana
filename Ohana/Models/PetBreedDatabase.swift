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
        CoatColor(name: "黑色", hex: "1a1a1a"),
        CoatColor(name: "白色", hex: "FAFAFA"),
        CoatColor(name: "棕色", hex: "795548"),
        CoatColor(name: "金黄色", hex: "FFC107"),
        CoatColor(name: "奶油色", hex: "FFF8E1"),
        CoatColor(name: "灰色", hex: "9E9E9E"),
        CoatColor(name: "蓝灰色", hex: "90A4AE"),
        CoatColor(name: "橙红色", hex: "FF7043"),
        CoatColor(name: "杏色", hex: "FFCCBC"),
        CoatColor(name: "巧克力色", hex: "5D4037"),
        CoatColor(name: "重点色", hex: "B8B0A8"),
        CoatColor(name: "花斑色", hex: "D7CCC8"),
        CoatColor(name: "虎斑色", hex: "8D6E63"),
        CoatColor(name: "三花色", hex: "E8D5B7"),
        CoatColor(name: "其他", hex: "BDBDBD"),
    ]
    
    static let genericEyeColors: [EyeColor] = [
        EyeColor(name: "琥珀色", hex: "FFC107"),
        EyeColor(name: "棕色", hex: "795548"),
        EyeColor(name: "蓝色", hex: "42A5F5"),
        EyeColor(name: "绿色", hex: "66BB6A"),
        EyeColor(name: "黄色", hex: "FFEE58"),
        EyeColor(name: "铜色", hex: "FF8F00"),
        EyeColor(name: "橙色", hex: "FF7043"),
        EyeColor(name: "浅蓝色", hex: "81D4FA"),
        EyeColor(name: "异瞳", hex: "9C27B0"),
        EyeColor(name: "其他", hex: "BDBDBD"),
    ]
    
    // MARK: - Dog Breeds (A-Z)
    static let dogBreeds: [BreedInfo] = [
        BreedInfo(name: "阿富汗猎犬", coatColors: coats(["奶油色","黑色","红棕色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "阿拉斯加雪橇犬", coatColors: coats(["黑白","灰白","红白","全白"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "澳大利亚牧羊犬", coatColors: coats(["蓝灰色","红色","黑色","花斑色"]), eyeColors: eyes(["蓝色","棕色","异瞳"]), suggestedThemeHex: "42A5F5"),
        BreedInfo(name: "巴吉度猎犬", coatColors: coats(["三色","棕白","柠檬白"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "比格犬", coatColors: coats(["三色","棕白","柠檬白"]), eyeColors: eyes(["棕色","榛色"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "比熊犬", coatColors: coats(["白色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "边境牧羊犬", coatColors: coats(["黑白","蓝白","红白","三色"]), eyeColors: eyes(["棕色","蓝色","异瞳"]), suggestedThemeHex: "455A64"),
        BreedInfo(name: "博美犬", coatColors: coats(["橙色","白色","黑色","奶油色","棕色","蓝灰色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "布列塔尼猎犬", coatColors: coats(["橙白","肝白"]), eyeColors: eyes(["棕色","琥珀色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "查理王骑士犬", coatColors: coats(["红宝石色","黑棕色","三色","布伦海姆色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "C0392B"),
        BreedInfo(name: "柴犬", coatColors: coats(["红色","黑棕色","芝麻色","奶油色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "大麦町犬", coatColors: coats(["白底黑斑","白底肝斑"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "455A64"),
        BreedInfo(name: "德国牧羊犬", coatColors: coats(["黑棕色","黑红色","纯黑","纯白"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "杜宾犬", coatColors: coats(["黑棕色","蓝棕色","红棕色","白色(罕)"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "212121"),
        BreedInfo(name: "法国斗牛犬", coatColors: coats(["虎斑","奶油色","白色","花斑色","蓝灰色","巧克力色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "腊肠犬", coatColors: coats(["红色","巧克力棕","黑棕","奶油色","花斑色"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "拉布拉多犬", coatColors: coats(["黑色","黄色","巧克力色"]), eyeColors: eyes(["棕色","黄色"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "老英国牧羊犬", coatColors: coats(["灰白","蓝灰白"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "猎狐梗", coatColors: coats(["白底棕斑","白底黑斑"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "BDBDBD"),
        BreedInfo(name: "金毛寻回犬", coatColors: coats(["金色","奶油色","浅金","深金"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "卷毛比雄犬", coatColors: coats(["白色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "柯基犬", coatColors: coats(["红色","白色","三色","蓝灰色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "可卡犬", coatColors: coats(["黑色","金色","巧克力色","花斑色"]), eyeColors: eyes(["棕色","榛色"]), suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "马尔济斯犬", coatColors: coats(["白色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "美国可卡犬", coatColors: coats(["黑色","金色","棕色","花斑色","杂色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "迷你杜宾犬", coatColors: coats(["黑棕色","巧克力棕","红色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "212121"),
        BreedInfo(name: "迷你雪纳瑞", coatColors: coats(["椒盐色","黑色","黑银色","白色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "牧羊犬", coatColors: coats(["棕白","三色","蓝灰"]), eyeColors: eyes(["棕色","蓝色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "纽芬兰犬", coatColors: coats(["黑色","棕色","黑白"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "212121"),
        BreedInfo(name: "帕皮庸", coatColors: coats(["白底黑斑","白底棕斑","白底红斑"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "萨摩耶犬", coatColors: coats(["白色","奶白色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "沙皮犬", coatColors: coats(["奶油色","棕色","红色","黑色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "史宾格犬", coatColors: coats(["肝白","黑白","棕白"]), eyeColors: eyes(["棕色","榛色"]), suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "松狮犬", coatColors: coats(["红色","黑色","蓝色","奶油色","肉桂色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FF7043"),
        BreedInfo(name: "泰迪/贵宾犬", coatColors: coats(["白色","杏色","红色","黑色","棕色","银色","蓝灰色"]), eyeColors: eyes(["棕色","琥珀色"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "西伯利亚哈士奇", coatColors: coats(["黑白","灰白","红白","纯白","银白"]), eyeColors: eyes(["蓝色","棕色","异瞳"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "西高地白梗", coatColors: coats(["白色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "西施犬", coatColors: coats(["金色","白色","黑色","红色","多色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "FFC107"),
        BreedInfo(name: "约克夏梗", coatColors: coats(["蓝棕色","金棕色"]), eyeColors: eyes(["棕色"]), suggestedThemeHex: "8D6E63"),
        BreedInfo(name: "中华田园犬", coatColors: coats(["黑色","黄色","白色","花斑色"]), eyeColors: eyes(["棕色","黄色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "其他", coatColors: genericCoatColors, eyeColors: genericEyeColors, suggestedThemeHex: "9E9E9E"),
    ]
    
    // MARK: - Cat Breeds (A-Z)
    static let catBreeds: [BreedInfo] = [
        BreedInfo(name: "阿比西尼亚猫", coatColors: coats(["兔毛色","红色","蓝色","栗色"]), eyeColors: eyes(["金色","绿色","铜色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "暹罗猫", coatColors: coats(["重点色（海豹/蓝/巧克力/丁香）"]), eyeColors: eyes(["蓝色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "布偶猫", coatColors: coats(["重点色","双色重点色","手套色"]), eyeColors: eyes(["蓝色"]), suggestedThemeHex: "B8A9C9"),
        BreedInfo(name: "波斯猫", coatColors: coats(["白色","黑色","蓝色","金色","银色","虎斑色","重点色"]), eyeColors: eyes(["铜色","蓝色","绿色","异瞳"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "苏格兰折耳猫", coatColors: coats(["白色","黑色","蓝灰色","金色","银色","虎斑色","重点色"]), eyeColors: eyes(["琥珀色","绿色","蓝色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "英国短毛猫", coatColors: coats(["蓝灰色","白色","黑色","金色","银色","虎斑色","重点色"]), eyeColors: eyes(["铜色","橙色","绿色","蓝色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "美国短毛猫", coatColors: coats(["银虎斑","棕虎斑","红色","白色","黑色"]), eyeColors: eyes(["绿色","金色","蓝色"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "挪威森林猫", coatColors: coats(["棕虎斑白","黑白","红白","蓝白","多种"]), eyeColors: eyes(["绿色","金色","铜色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "缅因库恩猫", coatColors: coats(["棕虎斑","黑色","白色","红色","银色","多种"]), eyeColors: eyes(["绿色","金色","铜色","蓝色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "缅甸猫", coatColors: coats(["貂色","蓝色","巧克力色","丁香色"]), eyeColors: eyes(["金色","黄色"]), suggestedThemeHex: "795548"),
        BreedInfo(name: "孟加拉猫", coatColors: coats(["棕色点斑","银色点斑","雪色点斑"]), eyeColors: eyes(["绿色","金色","棕色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "德文卷毛猫", coatColors: coats(["灰色","琥珀色","重点色","黑色","白色","蓝色"]), eyeColors: eyes(["琥珀色","绿色","蓝色","异瞳"]), suggestedThemeHex: "9E9E9E"),
        BreedInfo(name: "科尼什卷毛猫", coatColors: coats(["白色","黑色","蓝色","红色","奶油色","多种"]), eyeColors: eyes(["绿色","金色","蓝色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "拉邦猫", coatColors: coats(["多种"]), eyeColors: eyes(["多种"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "俄罗斯蓝猫", coatColors: coats(["蓝灰色"]), eyeColors: eyes(["绿色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "斯芬克斯无毛猫", coatColors: coats(["肤色","黑色","蓝色","红色（皮肤底色）"]), eyeColors: eyes(["绿色","金色","蓝色","异瞳"]), suggestedThemeHex: "FFCCBC"),
        BreedInfo(name: "土耳其安哥拉猫", coatColors: coats(["白色","黑色","蓝色","红色"]), eyeColors: eyes(["蓝色","绿色","琥珀色","异瞳"]), suggestedThemeHex: "FAFAFA"),
        BreedInfo(name: "索马里猫", coatColors: coats(["兔毛色","红色","蓝色","栗色"]), eyeColors: eyes(["金色","绿色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "中华田园猫", coatColors: coats(["橘猫","黑猫","白猫","三花","狸花","玳瑁"]), eyeColors: eyes(["绿色","黄色","棕色","蓝色"]), suggestedThemeHex: "FF8F00"),
        BreedInfo(name: "银渐层", coatColors: coats(["银色底渐层"]), eyeColors: eyes(["绿色","蓝绿色"]), suggestedThemeHex: "90A4AE"),
        BreedInfo(name: "金渐层", coatColors: coats(["金色底渐层"]), eyeColors: eyes(["绿色","铜绿色"]), suggestedThemeHex: "FFC107"),
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
}

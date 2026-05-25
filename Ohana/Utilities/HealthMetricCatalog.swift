//
//  HealthMetricCatalog.swift
//  Ohana
//
//  ArkSchemaV56：人类体检指标静态目录
//
//  设计意图：
//  - 体检指标（TSH/HbA1c/血压…）不存数据库，目录是 App 内置常量。
//  - 每个指标可有多个 unit（mIU/L、ng/mL 等），每个 unit 各自带「正常范围」。
//  - 国家偏好仅决定默认 unit 与默认显示范围（参考各国主流报告习惯），用户仍可自由切换。
//
//  覆盖范围：
//  - 实验室指标：甲状腺/血糖/血脂/肝功/肾功/血常规/炎症与维生素/电解质（约 25 项）
//  - 生命体征：收缩压、舒张压、心率、体温、SpO₂、呼吸率（6 项）
//

import SwiftUI
import Foundation

// MARK: - 分类

enum HealthMetricCategory: String, CaseIterable, Identifiable {
    case thyroid = "thyroid"
    case glucose = "glucose"
    case lipid = "lipid"
    case liver = "liver"
    case kidney = "kidney"
    case bloodCount = "blood_count"
    case inflammationVitamin = "inflammation_vitamin"
    case electrolyte = "electrolyte"
    case vitals = "vitals"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .thyroid: return "waveform.path.ecg"
        case .glucose: return "drop.fill"
        case .lipid: return "chart.pie.fill"
        case .liver: return "cross.vial.fill"
        case .kidney: return "testtube.2"
        case .bloodCount: return "allergens.fill"
        case .inflammationVitamin: return "pills.fill"
        case .electrolyte: return "bolt.heart.fill"
        case .vitals: return "heart.text.square.fill"
        }
    }

    func displayName(_ l: L10n) -> String {
        switch self {
        case .thyroid: return l.tr(zh: "甲状腺", en: "Thyroid", de: "Schilddrüse")
        case .glucose: return l.tr(zh: "血糖", en: "Glucose", de: "Blutzucker")
        case .lipid: return l.tr(zh: "血脂", en: "Lipids", de: "Blutfette")
        case .liver: return l.tr(zh: "肝功能", en: "Liver", de: "Leber")
        case .kidney: return l.tr(zh: "肾功能", en: "Kidney", de: "Niere")
        case .bloodCount: return l.tr(zh: "血常规", en: "Blood Count", de: "Blutbild")
        case .inflammationVitamin: return l.tr(zh: "炎症与维生素", en: "Inflammation & Vitamins", de: "Entzündung & Vitamine")
        case .electrolyte: return l.tr(zh: "电解质", en: "Electrolytes", de: "Elektrolyte")
        case .vitals: return l.tr(zh: "生命体征", en: "Vitals", de: "Vitalwerte")
        }
    }

    var color: Color {
        switch self {
        case .thyroid: return Color.goPurple
        case .glucose: return Color.goOrange
        case .lipid: return Color.goYellow
        case .liver: return Color.goRed
        case .kidney: return Color(hex: "64748B")
        case .bloodCount: return Color(hex: "E11D48")
        case .inflammationVitamin: return Color.goTeal
        case .electrolyte: return Color.goMint
        case .vitals: return Color(hex: "F43F5E")
        }
    }
}

// MARK: - Unit & Range

struct HealthMetricUnit: Identifiable, Hashable {
    /// 稳定 code，存储在 HumanHealthMetricLog.unitCode
    let code: String
    /// 显示标签（mIU/L 等，统一英文符号，免本地化）
    let label: String
    /// 该 unit 下的正常范围（左右开闭由调用方按"内含"处理；nil=无标准）
    let normalLow: Double?
    let normalHigh: Double?

    var id: String { code }

    func formatted(_ value: Double) -> String {
        // 根据数量级决定小数位
        let absV = abs(value)
        let digits: Int
        if absV >= 1000 { digits = 0 }
        else if absV >= 100 { digits = 1 }
        else if absV >= 1 { digits = 2 }
        else { digits = 3 }
        return String(format: "%.\(digits)f", value)
    }

    func formattedValue(_ value: Double, includeUnit: Bool = true) -> String {
        includeUnit ? "\(formatted(value)) \(label)" : formatted(value)
    }

    func normalRangeLabel(includeUnit: Bool = true) -> String {
        let suffix = includeUnit ? " \(label)" : ""
        switch (normalLow, normalHigh) {
        case let (.some(low), .some(high)) where low <= 0:
            return "≤ \(formatted(high))\(suffix)"
        case let (.some(low), .some(high)):
            return "\(formatted(low))–\(formatted(high))\(suffix)"
        case let (.some(low), .none):
            return "≥ \(formatted(low))\(suffix)"
        case let (.none, .some(high)):
            return "≤ \(formatted(high))\(suffix)"
        default:
            return "—"
        }
    }

    /// 根据正常范围给出状态色：低/正常/高/未知
    func status(for value: Double) -> HealthMetricStatus {
        guard let lo = normalLow, let hi = normalHigh else { return .unknown }
        if value < lo { return .low }
        if value > hi { return .high }
        return .normal
    }
}

enum HealthMetricStatus {
    case low, normal, high, unknown

    var color: Color {
        switch self {
        case .low: return Color(hex: "06B6D4")
        case .normal: return Color.goTeal
        case .high: return Color.goOrange
        case .unknown: return Color.ohanaSecondaryText
        }
    }

    func label(_ l: L10n) -> String {
        switch self {
        case .low: return l.tr(zh: "偏低", en: "Low", de: "Niedrig")
        case .normal: return l.tr(zh: "正常", en: "Normal", de: "Normal")
        case .high: return l.tr(zh: "偏高", en: "High", de: "Hoch")
        case .unknown: return l.tr(zh: "—", en: "—", de: "—")
        }
    }
}

// MARK: - 指标定义

struct HealthMetric: Identifiable, Hashable {
    /// 稳定 key，写入 HumanHealthMetricLog.metricKey
    let key: String
    let category: HealthMetricCategory
    let nameZh: String
    let nameEn: String
    let nameDe: String
    /// 缩写/别名（TSH / HbA1c 等），用于搜索
    let shortNames: [String]
    /// 可用 unit，第一个为通用默认；按国家覆盖见 `defaultUnitCode(country:)`
    let units: [HealthMetricUnit]
    /// 各国常用 unit code（覆盖 units[0]）
    let countryDefaultUnit: [String: String]
    /// 简短描述（hint）
    let hintZh: String
    let hintEn: String
    let hintDe: String

    var id: String { key }

    func displayName(_ l: L10n) -> String {
        l.tr(zh: nameZh, en: nameEn, de: nameDe)
    }

    func hint(_ l: L10n) -> String {
        l.tr(zh: hintZh, en: hintEn, de: hintDe)
    }

    /// 给定国家代码，给出推荐默认 unit
    func defaultUnit(for countryCode: String) -> HealthMetricUnit {
        if let code = countryDefaultUnit[countryCode.uppercased()],
           let match = units.first(where: { $0.code == code }) {
            return match
        }
        return units[0]
    }

    func unit(for code: String) -> HealthMetricUnit? {
        units.first { $0.code == code }
    }
}

// MARK: - Catalog

enum HealthMetricCatalog {
    /// 全部指标（按 category + 内部声明顺序）
    static let all: [HealthMetric] = makeAll()

    static func metric(forKey key: String) -> HealthMetric? {
        all.first { $0.key == key }
    }

    static func metrics(in category: HealthMetricCategory) -> [HealthMetric] {
        all.filter { $0.category == category }
    }

    /// 给定国家是否在我们的偏好覆盖列表里（仅做默认 unit 决定，目录所有指标对所有国家均可见）
    static func countriesWithDefaults() -> [String] {
        ["CN", "US", "DE", "GB", "JP", "HK", "TW"]
    }

    // MARK: - Builder

    private static func makeAll() -> [HealthMetric] {
        var list: [HealthMetric] = []
        list.append(contentsOf: thyroid)
        list.append(contentsOf: glucose)
        list.append(contentsOf: lipid)
        list.append(contentsOf: liver)
        list.append(contentsOf: kidney)
        list.append(contentsOf: bloodCount)
        list.append(contentsOf: inflammationVitamin)
        list.append(contentsOf: electrolyte)
        list.append(contentsOf: vitals)
        return list
    }

    // MARK: - 甲状腺

    private static let thyroid: [HealthMetric] = [
        HealthMetric(
            key: "tsh",
            category: .thyroid,
            nameZh: "促甲状腺激素", nameEn: "TSH", nameDe: "TSH",
            shortNames: ["TSH"],
            units: [
                HealthMetricUnit(code: "mIU_L", label: "mIU/L", normalLow: 0.4, normalHigh: 4.0),
                HealthMetricUnit(code: "uIU_mL", label: "µIU/mL", normalLow: 0.4, normalHigh: 4.0)
            ],
            countryDefaultUnit: ["US": "uIU_mL"],
            hintZh: "评估甲状腺功能的首要指标。", hintEn: "Primary thyroid function screen.", hintDe: "Wichtigster Schilddrüsen-Screening-Wert."
        ),
        HealthMetric(
            key: "ft4",
            category: .thyroid,
            nameZh: "游离 T4", nameEn: "Free T4", nameDe: "Freies T4",
            shortNames: ["FT4"],
            units: [
                HealthMetricUnit(code: "pmol_L", label: "pmol/L", normalLow: 12, normalHigh: 22),
                HealthMetricUnit(code: "ng_dL", label: "ng/dL", normalLow: 0.8, normalHigh: 1.8)
            ],
            countryDefaultUnit: ["US": "ng_dL"],
            hintZh: "甲状腺合成的活性激素。", hintEn: "Free thyroxine.", hintDe: "Freies Thyroxin."
        ),
        HealthMetric(
            key: "ft3",
            category: .thyroid,
            nameZh: "游离 T3", nameEn: "Free T3", nameDe: "Freies T3",
            shortNames: ["FT3"],
            units: [
                HealthMetricUnit(code: "pmol_L", label: "pmol/L", normalLow: 3.1, normalHigh: 6.8),
                HealthMetricUnit(code: "pg_mL", label: "pg/mL", normalLow: 2.0, normalHigh: 4.4)
            ],
            countryDefaultUnit: ["US": "pg_mL"],
            hintZh: "活性更强的甲状腺激素。", hintEn: "Free triiodothyronine.", hintDe: "Freies Triiodthyronin."
        ),
        HealthMetric(
            key: "tpo_ab",
            category: .thyroid,
            nameZh: "TPO 抗体", nameEn: "TPO Antibody", nameDe: "TPO-Antikörper",
            shortNames: ["TPO"],
            units: [HealthMetricUnit(code: "IU_mL", label: "IU/mL", normalLow: 0, normalHigh: 34)],
            countryDefaultUnit: [:],
            hintZh: "桥本/Graves 等自免甲状腺疾病的标志。", hintEn: "Autoimmune thyroid marker.", hintDe: "Marker für autoimmune Schilddrüse."
        )
    ]

    // MARK: - 血糖

    private static let glucose: [HealthMetric] = [
        HealthMetric(
            key: "fbg",
            category: .glucose,
            nameZh: "空腹血糖", nameEn: "Fasting Glucose", nameDe: "Nüchternblutzucker",
            shortNames: ["FBG", "FPG"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 3.9, normalHigh: 6.1),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 70, normalHigh: 110)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "禁食 8 小时后采血。", hintEn: "After 8h fasting.", hintDe: "Nach 8 h Fasten."
        ),
        HealthMetric(
            key: "ppg2h",
            category: .glucose,
            nameZh: "餐后 2h 血糖", nameEn: "Postprandial 2h Glucose", nameDe: "2h-Blutzucker postprandial",
            shortNames: ["PPG"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 3.9, normalHigh: 7.8),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 70, normalHigh: 140)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "进餐后 2 小时血糖。", hintEn: "2 hours after a meal.", hintDe: "2 Std. nach Mahlzeit."
        ),
        HealthMetric(
            key: "hba1c",
            category: .glucose,
            nameZh: "糖化血红蛋白", nameEn: "HbA1c", nameDe: "HbA1c",
            shortNames: ["HbA1c", "A1C"],
            units: [
                HealthMetricUnit(code: "percent", label: "%", normalLow: 4.0, normalHigh: 5.6),
                HealthMetricUnit(code: "mmol_mol", label: "mmol/mol", normalLow: 20, normalHigh: 38)
            ],
            countryDefaultUnit: ["DE": "mmol_mol", "GB": "mmol_mol"],
            hintZh: "近 2-3 个月平均血糖。", hintEn: "Avg glucose last 2–3 months.", hintDe: "Mittlerer Blutzucker 2–3 Monate."
        ),
        HealthMetric(
            key: "fasting_insulin",
            category: .glucose,
            nameZh: "空腹胰岛素", nameEn: "Fasting Insulin", nameDe: "Nüchterninsulin",
            shortNames: ["INS"],
            units: [HealthMetricUnit(code: "mIU_L", label: "mIU/L", normalLow: 2.6, normalHigh: 24.9)],
            countryDefaultUnit: [:],
            hintZh: "评估胰岛素抵抗。", hintEn: "Insulin resistance screen.", hintDe: "Hinweis auf Insulinresistenz."
        )
    ]

    // MARK: - 血脂

    private static let lipid: [HealthMetric] = [
        HealthMetric(
            key: "tc",
            category: .lipid,
            nameZh: "总胆固醇", nameEn: "Total Cholesterol", nameDe: "Gesamtcholesterin",
            shortNames: ["TC"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 0, normalHigh: 5.2),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 0, normalHigh: 200)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "<5.2 mmol/L 为理想。", hintEn: "Desirable <200 mg/dL.", hintDe: "Wünschenswert <200 mg/dL."
        ),
        HealthMetric(
            key: "tg",
            category: .lipid,
            nameZh: "甘油三酯", nameEn: "Triglycerides", nameDe: "Triglyceride",
            shortNames: ["TG"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 0, normalHigh: 1.7),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 0, normalHigh: 150)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "<1.7 mmol/L 为理想。", hintEn: "Desirable <150 mg/dL.", hintDe: "Wünschenswert <150 mg/dL."
        ),
        HealthMetric(
            key: "hdl",
            category: .lipid,
            nameZh: "高密度脂蛋白 HDL-C", nameEn: "HDL-C", nameDe: "HDL-C",
            shortNames: ["HDL", "HDL-C"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 1.04, normalHigh: 2.0),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 40, normalHigh: 80)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "「好」胆固醇，越高越好。", hintEn: "“Good” cholesterol, higher is better.", hintDe: "„Gutes“ Cholesterin, höher ist besser."
        ),
        HealthMetric(
            key: "ldl",
            category: .lipid,
            nameZh: "低密度脂蛋白 LDL-C", nameEn: "LDL-C", nameDe: "LDL-C",
            shortNames: ["LDL", "LDL-C"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 0, normalHigh: 3.4),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 0, normalHigh: 130)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "「坏」胆固醇，越低越好。", hintEn: "“Bad” cholesterol, lower is better.", hintDe: "„Schlechtes“ Cholesterin, niedriger ist besser."
        )
    ]

    // MARK: - 肝功能

    private static let liver: [HealthMetric] = [
        HealthMetric(
            key: "alt",
            category: .liver,
            nameZh: "谷丙转氨酶 ALT", nameEn: "ALT", nameDe: "ALT (GPT)",
            shortNames: ["ALT", "GPT", "SGPT"],
            units: [HealthMetricUnit(code: "U_L", label: "U/L", normalLow: 7, normalHigh: 40)],
            countryDefaultUnit: [:],
            hintZh: "肝细胞损伤敏感指标。", hintEn: "Sensitive liver injury marker.", hintDe: "Empfindlicher Leberzell-Marker."
        ),
        HealthMetric(
            key: "ast",
            category: .liver,
            nameZh: "谷草转氨酶 AST", nameEn: "AST", nameDe: "AST (GOT)",
            shortNames: ["AST", "GOT", "SGOT"],
            units: [HealthMetricUnit(code: "U_L", label: "U/L", normalLow: 13, normalHigh: 35)],
            countryDefaultUnit: [:],
            hintZh: "肝/心肌损伤指标。", hintEn: "Liver and cardiac muscle marker.", hintDe: "Leber- und Herzmuskel-Marker."
        ),
        HealthMetric(
            key: "ggt",
            category: .liver,
            nameZh: "谷氨酰转肽酶 GGT", nameEn: "GGT", nameDe: "GGT",
            shortNames: ["GGT", "γ-GT"],
            units: [HealthMetricUnit(code: "U_L", label: "U/L", normalLow: 7, normalHigh: 45)],
            countryDefaultUnit: [:],
            hintZh: "胆道与酒精相关肝损伤敏感。", hintEn: "Sensitive to biliary/alcohol injury.", hintDe: "Sensibel für Galle/Alkohol."
        ),
        HealthMetric(
            key: "tbil",
            category: .liver,
            nameZh: "总胆红素", nameEn: "Total Bilirubin", nameDe: "Gesamtbilirubin",
            shortNames: ["TBIL"],
            units: [
                HealthMetricUnit(code: "umol_L", label: "µmol/L", normalLow: 3.4, normalHigh: 20.5),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 0.2, normalHigh: 1.2)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "黄疸/溶血/胆道。", hintEn: "Jaundice / hemolysis / biliary.", hintDe: "Gelbsucht / Hämolyse / Galle."
        ),
        HealthMetric(
            key: "alb",
            category: .liver,
            nameZh: "白蛋白", nameEn: "Albumin", nameDe: "Albumin",
            shortNames: ["ALB"],
            units: [
                HealthMetricUnit(code: "g_L", label: "g/L", normalLow: 35, normalHigh: 55),
                HealthMetricUnit(code: "g_dL", label: "g/dL", normalLow: 3.5, normalHigh: 5.5)
            ],
            countryDefaultUnit: ["US": "g_dL"],
            hintZh: "肝合成功能 / 营养状态。", hintEn: "Liver synthesis / nutrition.", hintDe: "Lebersynthese / Ernährung."
        )
    ]

    // MARK: - 肾功能

    private static let kidney: [HealthMetric] = [
        HealthMetric(
            key: "creatinine",
            category: .kidney,
            nameZh: "肌酐", nameEn: "Creatinine", nameDe: "Kreatinin",
            shortNames: ["Cr", "Crea"],
            units: [
                HealthMetricUnit(code: "umol_L", label: "µmol/L", normalLow: 53, normalHigh: 106),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 0.6, normalHigh: 1.2)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "评估肾小球滤过的常规指标。", hintEn: "Routine renal filtration marker.", hintDe: "Routine-Nierenmarker."
        ),
        HealthMetric(
            key: "bun",
            category: .kidney,
            nameZh: "尿素氮", nameEn: "BUN", nameDe: "Harnstoff (BUN)",
            shortNames: ["BUN"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 2.9, normalHigh: 8.2),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 8, normalHigh: 23)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "肾脏排泄能力 / 蛋白代谢。", hintEn: "Renal excretion / protein metabolism.", hintDe: "Nierenfunktion / Proteinabbau."
        ),
        HealthMetric(
            key: "egfr",
            category: .kidney,
            nameZh: "eGFR", nameEn: "eGFR", nameDe: "eGFR",
            shortNames: ["eGFR", "GFR"],
            units: [HealthMetricUnit(code: "ml_min_173", label: "mL/min/1.73m²", normalLow: 90, normalHigh: 130)],
            countryDefaultUnit: [:],
            hintZh: "估算肾小球滤过率。", hintEn: "Estimated GFR.", hintDe: "Geschätzte GFR."
        ),
        HealthMetric(
            key: "uric_acid",
            category: .kidney,
            nameZh: "尿酸", nameEn: "Uric Acid", nameDe: "Harnsäure",
            shortNames: ["UA"],
            units: [
                HealthMetricUnit(code: "umol_L", label: "µmol/L", normalLow: 155, normalHigh: 420),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 2.6, normalHigh: 7.0)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "痛风风险监测。", hintEn: "Gout risk monitoring.", hintDe: "Gicht-Risiko."
        )
    ]

    // MARK: - 血常规

    private static let bloodCount: [HealthMetric] = [
        HealthMetric(
            key: "hgb",
            category: .bloodCount,
            nameZh: "血红蛋白", nameEn: "Hemoglobin", nameDe: "Hämoglobin",
            shortNames: ["HGB", "Hb"],
            units: [
                HealthMetricUnit(code: "g_L", label: "g/L", normalLow: 115, normalHigh: 175),
                HealthMetricUnit(code: "g_dL", label: "g/dL", normalLow: 11.5, normalHigh: 17.5)
            ],
            countryDefaultUnit: ["US": "g_dL"],
            hintZh: "贫血筛查最常用指标。", hintEn: "Most common anemia marker.", hintDe: "Wichtigster Anämie-Wert."
        ),
        HealthMetric(
            key: "wbc",
            category: .bloodCount,
            nameZh: "白细胞", nameEn: "WBC", nameDe: "Leukozyten",
            shortNames: ["WBC"],
            units: [HealthMetricUnit(code: "x10_9_L", label: "×10⁹/L", normalLow: 3.5, normalHigh: 9.5)],
            countryDefaultUnit: [:],
            hintZh: "感染 / 炎症 / 血液疾病提示。", hintEn: "Infection / inflammation / hematology.", hintDe: "Infektion / Entzündung / Hämatologie."
        ),
        HealthMetric(
            key: "rbc",
            category: .bloodCount,
            nameZh: "红细胞", nameEn: "RBC", nameDe: "Erythrozyten",
            shortNames: ["RBC"],
            units: [HealthMetricUnit(code: "x10_12_L", label: "×10¹²/L", normalLow: 3.8, normalHigh: 5.8)],
            countryDefaultUnit: [:],
            hintZh: "红细胞计数。", hintEn: "Red cell count.", hintDe: "Erythrozytenzahl."
        ),
        HealthMetric(
            key: "plt",
            category: .bloodCount,
            nameZh: "血小板", nameEn: "Platelets", nameDe: "Thrombozyten",
            shortNames: ["PLT"],
            units: [HealthMetricUnit(code: "x10_9_L", label: "×10⁹/L", normalLow: 125, normalHigh: 350)],
            countryDefaultUnit: [:],
            hintZh: "凝血与出血风险评估。", hintEn: "Coagulation / bleeding risk.", hintDe: "Gerinnung / Blutungsrisiko."
        )
    ]

    // MARK: - 炎症与维生素

    private static let inflammationVitamin: [HealthMetric] = [
        HealthMetric(
            key: "hscrp",
            category: .inflammationVitamin,
            nameZh: "高敏 C 反应蛋白", nameEn: "hs-CRP", nameDe: "hs-CRP",
            shortNames: ["hsCRP", "CRP"],
            units: [HealthMetricUnit(code: "mg_L", label: "mg/L", normalLow: 0, normalHigh: 3.0)],
            countryDefaultUnit: [:],
            hintZh: "<1 低风险，1-3 中等，>3 高心血管风险。", hintEn: "<1 low, 1–3 moderate, >3 high cardio risk.", hintDe: "<1 niedrig, 1–3 mittel, >3 hohes Risiko."
        ),
        HealthMetric(
            key: "esr",
            category: .inflammationVitamin,
            nameZh: "血沉", nameEn: "ESR", nameDe: "BSG",
            shortNames: ["ESR", "BSG"],
            units: [HealthMetricUnit(code: "mm_h", label: "mm/h", normalLow: 0, normalHigh: 20)],
            countryDefaultUnit: [:],
            hintZh: "非特异性炎症指标。", hintEn: "Non-specific inflammation marker.", hintDe: "Unspezifischer Entzündungswert."
        ),
        HealthMetric(
            key: "vitamin_d",
            category: .inflammationVitamin,
            nameZh: "25-羟维生素 D", nameEn: "Vitamin D (25-OH)", nameDe: "Vitamin D (25-OH)",
            shortNames: ["VitD", "25(OH)D"],
            units: [
                HealthMetricUnit(code: "nmol_L", label: "nmol/L", normalLow: 75, normalHigh: 250),
                HealthMetricUnit(code: "ng_mL", label: "ng/mL", normalLow: 30, normalHigh: 100)
            ],
            countryDefaultUnit: ["US": "ng_mL"],
            hintZh: "充足 ≥30 ng/mL（75 nmol/L）。", hintEn: "Sufficient ≥30 ng/mL (75 nmol/L).", hintDe: "Ausreichend ≥30 ng/mL."
        ),
        HealthMetric(
            key: "vitamin_b12",
            category: .inflammationVitamin,
            nameZh: "维生素 B12", nameEn: "Vitamin B12", nameDe: "Vitamin B12",
            shortNames: ["B12"],
            units: [
                HealthMetricUnit(code: "pmol_L", label: "pmol/L", normalLow: 148, normalHigh: 740),
                HealthMetricUnit(code: "pg_mL", label: "pg/mL", normalLow: 200, normalHigh: 1000)
            ],
            countryDefaultUnit: ["US": "pg_mL"],
            hintZh: "缺乏可致巨幼贫血/神经症状。", hintEn: "Deficiency → anemia / neuro symptoms.", hintDe: "Mangel → Anämie / neurol. Symptome."
        ),
        HealthMetric(
            key: "ferritin",
            category: .inflammationVitamin,
            nameZh: "铁蛋白", nameEn: "Ferritin", nameDe: "Ferritin",
            shortNames: ["Ferritin"],
            units: [
                HealthMetricUnit(code: "ng_mL", label: "ng/mL", normalLow: 30, normalHigh: 400),
                HealthMetricUnit(code: "ug_L", label: "µg/L", normalLow: 30, normalHigh: 400)
            ],
            countryDefaultUnit: [:],
            hintZh: "评估体内铁储备。", hintEn: "Iron stores marker.", hintDe: "Eisenspeicher-Marker."
        )
    ]

    // MARK: - 电解质

    private static let electrolyte: [HealthMetric] = [
        HealthMetric(
            key: "na",
            category: .electrolyte,
            nameZh: "钠", nameEn: "Sodium", nameDe: "Natrium",
            shortNames: ["Na"],
            units: [HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 135, normalHigh: 145)],
            countryDefaultUnit: [:],
            hintZh: "水盐平衡核心电解质。", hintEn: "Core electrolyte for fluid balance.", hintDe: "Zentraler Wasser-Salz-Elektrolyt."
        ),
        HealthMetric(
            key: "k",
            category: .electrolyte,
            nameZh: "钾", nameEn: "Potassium", nameDe: "Kalium",
            shortNames: ["K"],
            units: [HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 3.5, normalHigh: 5.3)],
            countryDefaultUnit: [:],
            hintZh: "影响心律。", hintEn: "Affects cardiac rhythm.", hintDe: "Beeinflusst Herzrhythmus."
        ),
        HealthMetric(
            key: "ca",
            category: .electrolyte,
            nameZh: "钙", nameEn: "Calcium", nameDe: "Kalzium",
            shortNames: ["Ca"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 2.1, normalHigh: 2.6),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 8.5, normalHigh: 10.5)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "骨骼/神经/凝血。", hintEn: "Bone / neuro / coagulation.", hintDe: "Knochen / Nerven / Gerinnung."
        ),
        HealthMetric(
            key: "mg",
            category: .electrolyte,
            nameZh: "镁", nameEn: "Magnesium", nameDe: "Magnesium",
            shortNames: ["Mg"],
            units: [
                HealthMetricUnit(code: "mmol_L", label: "mmol/L", normalLow: 0.75, normalHigh: 1.0),
                HealthMetricUnit(code: "mg_dL", label: "mg/dL", normalLow: 1.8, normalHigh: 2.4)
            ],
            countryDefaultUnit: ["US": "mg_dL"],
            hintZh: "肌肉/神经稳定性。", hintEn: "Muscle / nerve stability.", hintDe: "Muskel- und Nervenstabilität."
        )
    ]

    // MARK: - 生命体征

    private static let vitals: [HealthMetric] = [
        HealthMetric(
            key: "sbp",
            category: .vitals,
            nameZh: "收缩压", nameEn: "Systolic BP", nameDe: "Systolischer Blutdruck",
            shortNames: ["SBP"],
            units: [HealthMetricUnit(code: "mmHg", label: "mmHg", normalLow: 90, normalHigh: 130)],
            countryDefaultUnit: [:],
            hintZh: "心脏收缩时血压。", hintEn: "Pressure during heart contraction.", hintDe: "Druck bei Herzkontraktion."
        ),
        HealthMetric(
            key: "dbp",
            category: .vitals,
            nameZh: "舒张压", nameEn: "Diastolic BP", nameDe: "Diastolischer Blutdruck",
            shortNames: ["DBP"],
            units: [HealthMetricUnit(code: "mmHg", label: "mmHg", normalLow: 60, normalHigh: 85)],
            countryDefaultUnit: [:],
            hintZh: "心脏舒张时血压。", hintEn: "Pressure during heart relaxation.", hintDe: "Druck bei Herzentspannung."
        ),
        HealthMetric(
            key: "hr",
            category: .vitals,
            nameZh: "心率", nameEn: "Heart Rate", nameDe: "Herzfrequenz",
            shortNames: ["HR"],
            units: [HealthMetricUnit(code: "bpm", label: "bpm", normalLow: 60, normalHigh: 100)],
            countryDefaultUnit: [:],
            hintZh: "静息心率。", hintEn: "Resting heart rate.", hintDe: "Ruhepuls."
        ),
        HealthMetric(
            key: "temp",
            category: .vitals,
            nameZh: "体温", nameEn: "Body Temperature", nameDe: "Körpertemperatur",
            shortNames: ["T"],
            units: [
                HealthMetricUnit(code: "celsius", label: "°C", normalLow: 36.1, normalHigh: 37.2),
                HealthMetricUnit(code: "fahrenheit", label: "°F", normalLow: 97.0, normalHigh: 99.0)
            ],
            countryDefaultUnit: ["US": "fahrenheit"],
            hintZh: "口腔/腋下/耳温因部位略有差异。", hintEn: "Varies by site (oral/axillary/ear).", hintDe: "Variiert je nach Messort."
        ),
        HealthMetric(
            key: "spo2",
            category: .vitals,
            nameZh: "血氧饱和度", nameEn: "SpO₂", nameDe: "SpO₂",
            shortNames: ["SpO2"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 95, normalHigh: 100)],
            countryDefaultUnit: [:],
            hintZh: "<95% 提示需关注。", hintEn: "<95% warrants attention.", hintDe: "<95% beachten."
        ),
        HealthMetric(
            key: "rr",
            category: .vitals,
            nameZh: "呼吸率", nameEn: "Respiratory Rate", nameDe: "Atemfrequenz",
            shortNames: ["RR"],
            units: [HealthMetricUnit(code: "per_min", label: "/min", normalLow: 12, normalHigh: 20)],
            countryDefaultUnit: [:],
            hintZh: "成人静息每分钟呼吸次数。", hintEn: "Adult resting breaths per minute.", hintDe: "Atemzüge pro Minute (Ruhe)."
        )
    ]
}

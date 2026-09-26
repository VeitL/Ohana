//
//  HealthMetricCatalog+Immune.swift
//  Ohana
//
//  Immune-cell metrics kept as one catalog category group.
//

import Foundation

enum HealthMetricCatalogImmuneGroup {
    static let metrics: [HealthMetric] = [
        HealthMetric(
            key: "b_cells_abs", category: .inflammationVitamin,
            nameZh: "B 细胞绝对值", nameEn: "B Cells Absolute", nameDe: "B-Lymphozyten absolut",
            shortNames: ["CD19+ abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: 70, normalHigh: 800)],
            countryDefaultUnit: [:],
            hintZh: "CD19+ B 细胞绝对计数。", hintEn: "Absolute CD19+ B-cell count.", hintDe: "Absolute Zahl der CD19+ B-Lymphozyten."
        ),
        HealthMetric(
            key: "b_cells_pct", category: .inflammationVitamin,
            nameZh: "B 细胞比例", nameEn: "B Cells %", nameDe: "B-Lymphozyten relativ",
            shortNames: ["CD19+ %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 7, normalHigh: 23)],
            countryDefaultUnit: [:],
            hintZh: "CD19+ B 细胞比例。", hintEn: "Relative CD19+ B-cell proportion.", hintDe: "Relativer Anteil der CD19+ B-Lymphozyten."
        ),
        HealthMetric(
            key: "t_cells_abs", category: .inflammationVitamin,
            nameZh: "T 细胞绝对值", nameEn: "T Cells Absolute", nameDe: "T-Lymphozyten absolut",
            shortNames: ["CD3+ abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: 800, normalHigh: 2900)],
            countryDefaultUnit: [:],
            hintZh: "CD3+ T 细胞绝对计数。", hintEn: "Absolute CD3+ T-cell count.", hintDe: "Absolute Zahl der CD3+ T-Lymphozyten."
        ),
        HealthMetric(
            key: "t_cells_pct", category: .inflammationVitamin,
            nameZh: "T 细胞比例", nameEn: "T Cells %", nameDe: "T-Lymphozyten relativ",
            shortNames: ["CD3+ %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 55, normalHigh: 85)],
            countryDefaultUnit: [:],
            hintZh: "CD3+ T 细胞比例。", hintEn: "Relative CD3+ T-cell proportion.", hintDe: "Relativer Anteil der CD3+ T-Lymphozyten."
        ),
        HealthMetric(
            key: "cd4_abs", category: .inflammationVitamin,
            nameZh: "CD4 T 细胞绝对值", nameEn: "CD4 T Cells Absolute", nameDe: "CD4-Helferzellen absolut",
            shortNames: ["CD4+ abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: 500, normalHigh: 1900)],
            countryDefaultUnit: [:],
            hintZh: "CD4+ T 辅助细胞绝对计数。", hintEn: "Absolute CD4+ helper T-cell count.", hintDe: "Absolute Zahl der CD4+ T-Helferzellen."
        ),
        HealthMetric(
            key: "cd4_pct", category: .inflammationVitamin,
            nameZh: "CD4 T 细胞比例", nameEn: "CD4 T Cells %", nameDe: "CD4-Helferzellen relativ",
            shortNames: ["CD4+ %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 32, normalHigh: 55)],
            countryDefaultUnit: [:],
            hintZh: "CD4+ T 辅助细胞比例。", hintEn: "Relative CD4+ helper T-cell proportion.", hintDe: "Relativer Anteil der CD4+ T-Helferzellen."
        ),
        HealthMetric(
            key: "cd8_abs", category: .inflammationVitamin,
            nameZh: "CD8 T 细胞绝对值", nameEn: "CD8 T Cells Absolute", nameDe: "CD8-Suppressorzellen absolut",
            shortNames: ["CD8+ abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: 220, normalHigh: 1100)],
            countryDefaultUnit: [:],
            hintZh: "CD8+ T 细胞绝对计数。", hintEn: "Absolute CD8+ T-cell count.", hintDe: "Absolute Zahl der CD8+ T-Zellen."
        ),
        HealthMetric(
            key: "cd8_pct", category: .inflammationVitamin,
            nameZh: "CD8 T 细胞比例", nameEn: "CD8 T Cells %", nameDe: "CD8-Suppressorzellen relativ",
            shortNames: ["CD8+ %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 20, normalHigh: 39)],
            countryDefaultUnit: [:],
            hintZh: "CD8+ T 细胞比例。", hintEn: "Relative CD8+ T-cell proportion.", hintDe: "Relativer Anteil der CD8+ T-Zellen."
        ),
        HealthMetric(
            key: "nk_cells_abs", category: .inflammationVitamin,
            nameZh: "NK 细胞绝对值", nameEn: "NK Cells Absolute", nameDe: "NK-Zellen absolut",
            shortNames: ["CD16/56+ abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: 35, normalHigh: 850)],
            countryDefaultUnit: [:],
            hintZh: "自然杀伤细胞绝对计数。", hintEn: "Absolute natural-killer-cell count.", hintDe: "Absolute Zahl der natürlichen Killerzellen."
        ),
        HealthMetric(
            key: "nk_cells_pct", category: .inflammationVitamin,
            nameZh: "NK 细胞比例", nameEn: "NK Cells %", nameDe: "NK-Zellen relativ",
            shortNames: ["CD16/56+ %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 5, normalHigh: 25)],
            countryDefaultUnit: [:],
            hintZh: "自然杀伤细胞比例。", hintEn: "Relative natural-killer-cell proportion.", hintDe: "Relativer Anteil der natürlichen Killerzellen."
        ),
        HealthMetric(
            key: "cytotoxic_t_cells_abs", category: .inflammationVitamin,
            nameZh: "细胞毒性 T 细胞绝对值", nameEn: "Cytotoxic T Cells Absolute", nameDe: "Zytotoxische T-Zellen absolut",
            shortNames: ["cytotox T abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: 20, normalHigh: 220)],
            countryDefaultUnit: [:],
            hintZh: "细胞毒性 T 细胞绝对计数。", hintEn: "Absolute cytotoxic T-cell count.", hintDe: "Absolute Zahl zytotoxischer T-Zellen."
        ),
        HealthMetric(
            key: "cytotoxic_t_cells_pct", category: .inflammationVitamin,
            nameZh: "细胞毒性 T 细胞比例", nameEn: "Cytotoxic T Cells %", nameDe: "Zytotoxische T-Zellen relativ",
            shortNames: ["cytotox T %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 2, normalHigh: 6)],
            countryDefaultUnit: [:],
            hintZh: "细胞毒性 T 细胞比例。", hintEn: "Relative cytotoxic T-cell proportion.", hintDe: "Relativer Anteil zytotoxischer T-Zellen."
        ),
        HealthMetric(
            key: "activated_t_cells_abs", category: .inflammationVitamin,
            nameZh: "活化 T 细胞绝对值", nameEn: "Activated T Cells Absolute", nameDe: "Aktivierte T-Zellen absolut",
            shortNames: ["HLA-DR+ abs"],
            units: [HealthMetricUnit(code: "per_uL", label: "/µL", normalLow: nil, normalHigh: nil)],
            countryDefaultUnit: [:],
            hintZh: "活化 T 细胞绝对计数，参考范围依检测方法。", hintEn: "Absolute activated T-cell count; ranges depend on the assay.", hintDe: "Absolute Zahl aktivierter T-Zellen; Referenzbereiche sind methodenabhängig."
        ),
        HealthMetric(
            key: "activated_t_cells_pct", category: .inflammationVitamin,
            nameZh: "活化 T 细胞比例", nameEn: "Activated T Cells %", nameDe: "Aktivierte T-Zellen relativ",
            shortNames: ["HLA-DR+ %"],
            units: [HealthMetricUnit(code: "percent", label: "%", normalLow: 0, normalHigh: 15)],
            countryDefaultUnit: [:],
            hintZh: "活化 T 细胞比例。", hintEn: "Relative activated T-cell proportion.", hintDe: "Relativer Anteil aktivierter T-Zellen."
        ),
        HealthMetric(
            key: "cd4_cd8_ratio", category: .inflammationVitamin,
            nameZh: "CD4/CD8 比值", nameEn: "CD4/CD8 Ratio", nameDe: "CD4/CD8-Ratio",
            shortNames: ["CD4/CD8"],
            units: [HealthMetricUnit(code: "ratio", label: "ratio", normalLow: 1, normalHigh: 2.3)],
            countryDefaultUnit: [:],
            hintZh: "CD4 与 CD8 T 细胞的比值。", hintEn: "Ratio of CD4 to CD8 T cells.", hintDe: "Verhältnis von CD4- zu CD8-T-Zellen."
        ),
        HealthMetric(
            key: "hiv_rna", category: .inflammationVitamin,
            nameZh: "HIV RNA", nameEn: "HIV RNA", nameDe: "HIV-RNA",
            shortNames: ["HIV RNA"],
            units: [HealthMetricUnit(code: "copies_mL", label: "copies/mL", normalLow: 0, normalHigh: 20)],
            countryDefaultUnit: [:],
            hintZh: "仅记录报告给出的数值结果，不代替医学解释。", hintEn: "Records only the reported numeric result; it does not provide medical interpretation.", hintDe: "Erfasst nur den angegebenen Zahlenwert und ersetzt keine medizinische Einordnung."
        )
    ]
}

//
//  HumanLabResultParserSupport.swift
//  Ohana
//
//  Supporting vocabulary, normalization, and value types for lab result parsing.
//

import Foundation

nonisolated extension HumanLabResultParser {
    @MainActor
    static func makeUnitVocabulary(from metrics: [HealthMetric]) -> [UnitDescriptor] {
        var seen = Set<String>()
        var units: [UnitDescriptor] = []
        for metric in metrics {
            for unit in metric.units {
                let descriptor = UnitDescriptor(unit)
                guard seen.insert(descriptor.normalizedLabel).inserted else { continue }
                units.append(descriptor)
            }
        }
        return units
    }

    func normalizedWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    func normalizedSearchText(_ text: String) -> String {
        let folded = text
            .precomposedStringWithCompatibilityMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(folded.unicodeScalars.count)
        var lastWasSeparator = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                scalars.append(" ")
                lastWasSeparator = true
            }
        }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespaces)
    }

    func normalizedUnitText(_ text: String) -> String {
        Self.normalizeUnit(text)
    }

    static func normalizeUnit(_ text: String) -> String {
        var normalized = text
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "µ", with: "u")
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "mg/di", with: "mg/dl")
            .replacingOccurrences(of: "ng/di", with: "ng/dl")
            .replacingOccurrences(of: "g/di", with: "g/dl")
            .replacingOccurrences(of: "mmo//l", with: "mmol/l")
            .replacingOccurrences(of: "mmo/l", with: "mmol/l")
            .replacingOccurrences(of: "mmol/]", with: "mmol/l")
            .replacingOccurrences(of: "mmol/)", with: "mmol/l")
            .replacingOccurrences(of: "u/]", with: "u/l")
            .replacingOccurrences(of: "u/)", with: "u/l")
            .replacingOccurrences(of: "u/i", with: "u/l")
            .replacingOccurrences(of: "ulu/ml", with: "uiu/ml")
            .replacingOccurrences(of: "u/u/ml", with: "uiu/ml")
            .replacingOccurrences(of: "(ul)", with: "/ul")
            .replacingOccurrences(of: "[ul]", with: "/ul")
        for character in [" ", "\u{00A0}", "×", "*", "·", "^", "(", ")"] {
            normalized = normalized.replacingOccurrences(of: character, with: "")
        }
        normalized = normalized.replacingOccurrences(of: "x10", with: "10")
        return normalized
    }

    func average(_ values: [Float]) -> Float {
        let finiteValues = values.filter(\.isFinite)
        guard !finiteValues.isEmpty else { return 0 }
        return finiteValues.reduce(0, +) / Float(finiteValues.count)
    }
}

nonisolated extension HumanLabResultParser {
    struct SourceRow: Sendable {
        let pageIndex: Int
        let cells: [String]
        let text: String
        let confidence: Float
        let isTable: Bool
        let preferredValueText: String?
        let preferredReferenceText: String?
        let observedAt: Date?
    }

    struct SourceRowBatch: Sendable {
        let rows: [SourceRow]
        let wasTruncated: Bool
    }

    struct SourceRowCoverage: Hashable, Sendable {
        let label: String
        let observedAt: Date?
    }

    struct AliasDescriptor: Sendable {
        let normalized: String
        let requiresReview: Bool
    }

    struct UnitDescriptor: Sendable {
        let code: String
        let label: String
        let normalizedLabel: String

        init(_ unit: HealthMetricUnit) {
            code = unit.code
            label = unit.label
            normalizedLabel = HumanLabResultParser.normalizeUnit(unit.label)
        }
    }

    struct ResolvedUnit: Sendable {
        let descriptor: UnitDescriptor
        let sourceLabel: String
        let multiplier: Double
        let requiresReview: Bool
    }

    struct SourceUnitMapping: Sendable {
        let labels: [String]
        let targetCode: String
        let multiplier: Double
    }

    struct GeometryDateColumn: Sendable {
        let columnIndex: Int
        let centerX: Double
        let date: Date
    }

    struct GeometryColumnAnchor: Sendable {
        let index: Int
        let centerX: Double
    }

    enum LineColumnRole: Equatable, Sendable {
        case parameter
        case reference
        case result(Int)
    }

    struct LineColumnAnchor: Sendable {
        let role: LineColumnRole
        let centerX: Double
    }

    struct LineDateColumn: Sendable {
        let centerX: Double
        let headerY: Double
        let date: Date
    }

    struct LineMetricLabel: Sendable {
        let line: HumanLabOCRTextLine
        let text: String
        let metric: MetricDescriptor?
    }

    struct MetricDescriptor: Sendable {
        let key: String
        let aliases: [AliasDescriptor]
        let units: [UnitDescriptor]

        @MainActor
        init(_ metric: HealthMetric) {
            key = metric.key
            units = metric.units.map(UnitDescriptor.init)

            let commonAliases = HumanLabResultParser.commonAliases[metric.key] ?? []
            let strongValues = [metric.key, metric.nameZh, metric.nameEn, metric.nameDe]
                + metric.shortNames
            var aliasReviewByNormalizedValue: [String: Bool] = [:]
            for value in strongValues {
                let normalized = HumanLabResultParser.normalizeAlias(value)
                guard !normalized.isEmpty else { continue }
                aliasReviewByNormalizedValue[normalized] = false
            }
            for alias in commonAliases {
                let normalized = HumanLabResultParser.normalizeAlias(alias.value)
                guard !normalized.isEmpty else { continue }
                let current = aliasReviewByNormalizedValue[normalized] ?? true
                aliasReviewByNormalizedValue[normalized] = current && alias.requiresReview
            }
            aliases = aliasReviewByNormalizedValue
                .map { AliasDescriptor(normalized: $0.key, requiresReview: $0.value) }
                .sorted { $0.normalized.count > $1.normalized.count }
        }
    }

    struct MetricMatch: Sendable {
        let metric: MetricDescriptor
        let cellIndex: Int
        let score: Int
        var requiresReview: Bool
    }

    struct ExtractedFields {
        var value: Double?
        var qualifier: HumanLabValueQualifier = .exact
        var valueRange: NSRange?
        var valueRequiresReview = false
        var referenceLow: Double?
        var referenceHigh: Double?
        var referenceText: String?
        var textAfterValue = ""
    }

    struct ParsedNumber {
        let value: Double
        let requiresReview: Bool
    }

    struct PatternBundle {
        let number: NSRegularExpression
        let doubleRange: NSRegularExpression
        let comparatorRange: NSRegularExpression
        let dateHeader: NSRegularExpression
        let highFlag: NSRegularExpression
        let lowFlag: NSRegularExpression
        let normalFlag: NSRegularExpression

        init() throws {
            let numberCore = #"[-+]?(?:\d+(?:[.,]\d+)?|[.,]\d+)"#
            number = try NSRegularExpression(
                pattern: #"(?<![\p{L}\d])([<>≤≥]?\s*"# + numberCore
                    + #")(?![\p{L}\d]|\s*[-–—]?\s*\(?OH)"#,
                options: [.caseInsensitive]
            )
            doubleRange = try NSRegularExpression(
                pattern: "(" + numberCore + #")\s*(?:-|–|—|~|～|至|到)\s*("#
                    + numberCore + ")",
                options: []
            )
            comparatorRange = try NSRegularExpression(
                pattern: #"([<>≤≥])\s*("# + numberCore + ")",
                options: []
            )
            dateHeader = try NSRegularExpression(
                pattern: #"(?<!\d)(\d{1,2})[./-](\d{1,2})[./-](\d{4})(?!\d)"#,
                options: []
            )
            highFlag = try NSRegularExpression(
                pattern: #"(?:\[\s*\+\s*\]|［\s*\+\s*］|\(\s*\+\s*\)|(?:^|\s)[\[［(]?\s*\+\s*[\]］)]?(?=\s*\d))|(?:^|[\s\t*])(?:H|HIGH|HOCH)(?=$|[\s\t*])|[↑⬆]|(?:偏高|升高)"#,
                options: [.caseInsensitive]
            )
            lowFlag = try NSRegularExpression(
                pattern: #"(?:\[\s*-\s*\]|［\s*-\s*］|\(\s*-\s*\)|(?:^|\s)[\[［(]?\s*-\s*[\]］)]?(?=\s*\d)|(?:^|\s)L\s*-\s*[\]］](?=\s*\d))|(?:^|[\s\t*])(?:L|LOW|NIEDRIG)(?=$|[\s\t*])|[↓⬇]|(?:偏低|降低)"#,
                options: [.caseInsensitive]
            )
            normalFlag = try NSRegularExpression(
                pattern: #"(?:^|[\s\t*])(?:N|NORMAL)(?=$|[\s\t*])|正常"#,
                options: [.caseInsensitive]
            )
        }
    }

    struct CommonAlias: Sendable {
        let value: String
        let requiresReview: Bool
    }

    static let commonAliases: [String: [CommonAlias]] = [
        "tpo_ab": aliases("TPOAb", "Anti-TPO", "TPO-AK", "Thyreoperoxidase-Antikörper"),
        "glucose": aliases("Glucose", "Glukose", "Glucose i. Serum", "Serum glucose"),
        "fbg": aliases("GLU", "Glucose fasting", "Fasting plasma glucose", "Nüchternglukose", "空腹葡萄糖", review: true),
        "ppg2h": aliases("2h-PG", "2 hour glucose", "餐后两小时血糖", review: true),
        "hba1c": aliases("Glycated hemoglobin", "Glycohemoglobin", "糖化血色素"),
        "fasting_insulin": aliases("Fasting insulin", "Nüchterninsulin", "空腹胰岛素"),
        "tc": aliases("CHOL", "Total cholesterol", "Cholesterin gesamt", "总胆固醇"),
        "tg": aliases("TRIG", "Triglyceride", "Triglyzeride"),
        "hdl": aliases("HDL cholesterol", "HDL-Cholesterin"),
        "ldl": aliases("LDL cholesterol", "LDL-Cholesterin"),
        "alt": aliases("Alanine aminotransferase", "Alanin-Aminotransferase"),
        "ast": aliases("Aspartate aminotransferase", "Aspartat-Aminotransferase"),
        "ggt": aliases("Gamma-GT", "Gamma glutamyltransferase", "Gamma-Glutamyltransferase"),
        "tbil": aliases("Bilirubin total", "Bilirubin gesamt"),
        "ldh": aliases("LDH", "Lactatdehydrogenase", "Laktatdehydrogenase"),
        "alp": aliases("Alkalische Phosphatase", "Alkaline phosphatase", "AP", review: true),
        "amylase": aliases("Amylase", "Amylase i. Serum", "Serum amylase"),
        "total_protein": aliases("Gesamtprotein", "Gesamteiweiß", "Total protein", "TP", review: true),
        "creatinine": aliases("CRE", "CREA", "Serum creatinine", "KRE", "Kreatinin"),
        "bun": aliases("Urea nitrogen", "Harnstoff-N"),
        "urea": aliases("Urea", "Harnstoff", "Hamstoff", "尿素"),
        "uric_acid": aliases("Uric acid", "Harnsäure"),
        "quick": aliases("Quick", "Quick-Wert", "Thromboplastinzeit Quick", "Prothrombinaktivität"),
        "inr": aliases("INR", "International Normalized Ratio"),
        "aptt": aliases("aPTT", "PTT", "part Thromboplastinzeit", "partielle Thromboplastinzeit"),
        "hct": aliases("HCT", "Hämatokrit", "Hamatokrit", "Hematocrit"),
        "mcv": aliases("MCV", "mittleres Erythrozytenvolumen"),
        "mch": aliases("MCH", "mittleres korpuskuläres Hämoglobin"),
        "mchc": aliases("MCHC", "mittlere korpuskuläre Hämoglobinkonzentration"),
        "rdw_cv": aliases("RDW", "RDW-CV", "Erythrozytenverteilungsbreite %"),
        "rdw_sd": aliases("RDW-SD", "Erythrozytenverteilungsbreite SD"),
        "mpv": aliases("MPV", "mittleres Thrombozytenvolumen"),
        "hgb": aliases("Hemoglobin", "Hämoglobin"),
        "wbc": aliases("Leukocytes", "Leukozyten"),
        "rbc": aliases("Erythrocytes", "Erythrozyten"),
        "plt": aliases("Platelet count", "Thrombocytes", "Thrombozyten"),
        "neut_pct": aliases("neutrophile Granulozyten %", "Neutrophils %"),
        "neut_abs": aliases("neutrophile Granulozyten absolut", "Absolute neutrophils"),
        "lymph_pct": aliases("Lymphozyten %", "Lymphocytes %"),
        "lymph_abs": aliases("Lymphozyten absolut", "Absolute lymphocytes"),
        "mono_pct": aliases("Monozyten %", "Monocytes %"),
        "mono_abs": aliases("Monozyten absolut", "Absolute monocytes"),
        "eos_pct": aliases("Eosinophile %", "Eosinophils %"),
        "eos_abs": aliases("Eosinophile absolut", "Absolute eosinophils"),
        "baso_pct": aliases("Basophile %", "Basophils %"),
        "baso_abs": aliases("Basophile absolut", "Absolute basophils"),
        "b_cells_abs": aliases("B-Lymphozyten abs CD19", "B cells absolute CD19"),
        "b_cells_pct": aliases("B-Lymphozyten rel CD19", "B cells relative CD19"),
        "t_cells_abs": aliases("T-Lymphozyten abs", "T-Lymphozyten abs CD3", "T cells absolute CD3"),
        "t_cells_pct": aliases("T-Lymphozyten rel", "T-Lymphozyten rel CD3", "T cells relative CD3"),
        "cd4_abs": aliases("Helferzellen abs", "Helferzellen abs CD3 CD4", "CD4 helper cells absolute"),
        "cd4_pct": aliases("Helferzellen rel", "Helferzellen rel CD3 CD4", "CD4 helper cells relative"),
        "cd8_abs": aliases("Suppressorzellen abs", "Suppressorzellen abs CD3 CD8", "CD8 suppressor cells absolute"),
        "cd8_pct": aliases("Suppressorzellen rel", "Suppressorzellen rel CD3 CD8", "CD8 suppressor cells relative"),
        "nk_cells_abs": aliases("NK-Zellen abs CD3 CD16 56", "NK cells absolute"),
        "nk_cells_pct": aliases("NK-Zellen rel CD3 CD16 56", "NK cells relative"),
        "cytotoxic_t_cells_abs": aliases("cytotox T-Zellen abs", "cytotoxic T cells absolute"),
        "cytotoxic_t_cells_pct": aliases("cytotox T-Zellen rel", "cytotoxic T cells relative"),
        "activated_t_cells_abs": aliases("akt T-Zellen abs", "activated T cells absolute"),
        "activated_t_cells_pct": aliases("akt T-Zellen rel", "activated T cells relative"),
        "cd4_cd8_ratio": aliases("CD4 CD8 Ratio", "CD4/CD8 ratio"),
        "hiv_rna": aliases("HIV-RNA", "HIV RNA"),
        "hscrp": aliases("hs-CRP", "C-reactive protein", "C-reaktives Protein"),
        "vitamin_d": aliases("25-OH Vitamin D", "25 Hydroxyvitamin D", "25-OH-Vitamin D"),
        "vitamin_b12": aliases("Cobalamin", "Cobalamin B12"),
        "na": aliases("Sodium", "Natrium"),
        "k": aliases("Potassium", "Kalium"),
        "ca": aliases("Calcium", "Kalzium"),
        "mg": aliases("Magnesium")
    ]

    static let sourceUnitMappings: [String: [SourceUnitMapping]] = {
        let countPerMicroliter = SourceUnitMapping(
            labels: ["/µL", "/μL", "/uL", "/pL", "/p.l", "jµL", "juL", "cells/µL"],
            targetCode: "x10_9_L",
            multiplier: 0.001
        )
        let absoluteCountKeys = [
            "wbc", "plt", "neut_abs", "lymph_abs", "mono_abs", "eos_abs", "baso_abs"
        ]
        var mappings = Dictionary(
            uniqueKeysWithValues: absoluteCountKeys.map { ($0, [countPerMicroliter]) }
        )
        mappings["rbc"] = [SourceUnitMapping(
            labels: ["×10⁶/µL", "10^6/µL", "10⁶/µL", "x10^6/uL", "10^6/p.l", "10^6/pL"],
            targetCode: "x10_12_L",
            multiplier: 1
        )]
        mappings["urea"] = [SourceUnitMapping(
            labels: ["mg/dL"],
            targetCode: "mmol_L",
            multiplier: 0.1665
        )]
        mappings["total_protein"] = [SourceUnitMapping(
            labels: ["g/dL"],
            targetCode: "g_L",
            multiplier: 10
        )]
        mappings["inr"] = [SourceUnitMapping(
            labels: ["Index"],
            targetCode: "ratio",
            multiplier: 1
        )]
        mappings["aptt"] = [SourceUnitMapping(
            labels: ["sec", "sec.", "seconds"],
            targetCode: "seconds",
            multiplier: 1
        )]
        mappings["egfr"] = [SourceUnitMapping(
            labels: ["mL/min/1.73m2", "mL/min/1,73m2", "mL/min/1"],
            targetCode: "ml_min_173",
            multiplier: 1
        )]
        mappings["hiv_rna"] = [SourceUnitMapping(
            labels: ["cp/mL", "cpm/mL", "copies/mL"],
            targetCode: "copies_mL",
            multiplier: 1
        )]
        return mappings
    }()

    static func aliases(
        _ values: String...,
        review: Bool = false
    ) -> [CommonAlias] {
        values.map { CommonAlias(value: $0, requiresReview: review) }
    }

    static func normalizeAlias(_ value: String) -> String {
        let folded = value
            .precomposedStringWithCompatibilityMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var scalars: [Unicode.Scalar] = []
        var lastWasSeparator = true
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                scalars.append(" ")
                lastWasSeparator = true
            }
        }
        return String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespaces)
    }
}

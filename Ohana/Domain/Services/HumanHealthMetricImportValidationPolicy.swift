//
//  HumanHealthMetricImportValidationPolicy.swift
//  Ohana
//
//  Shared invariant for reviewed lab imports and compatible restore payloads.
//

import Foundation

@MainActor
enum HumanHealthMetricImportValidationPolicy {
    private struct MetricUnitKey: Hashable {
        let metricKey: String
        let unitCode: String

        init(_ metricKey: String, _ unitCode: String) {
            self.metricKey = metricKey
            self.unitCode = unitCode
        }
    }

    static let maximumSourceLabelLength = 256
    static let maximumReferenceRangeLength = 256

    private static let metricUnitPlausibleRanges: [MetricUnitKey: ClosedRange<Double>] = [
        MetricUnitKey("wbc", "x10_9_L"): 0 ... 500,
        MetricUnitKey("rbc", "x10_12_L"): 0.1 ... 20,
        MetricUnitKey("plt", "x10_9_L"): 0 ... 5000,
        MetricUnitKey("neut_abs", "x10_9_L"): 0 ... 500,
        MetricUnitKey("lymph_abs", "x10_9_L"): 0 ... 500,
        MetricUnitKey("mono_abs", "x10_9_L"): 0 ... 500,
        MetricUnitKey("eos_abs", "x10_9_L"): 0 ... 500,
        MetricUnitKey("baso_abs", "x10_9_L"): 0 ... 500,
        MetricUnitKey("na", "mmol_L"): 80 ... 200,
        MetricUnitKey("k", "mmol_L"): 0.5 ... 20,
        MetricUnitKey("ca", "mmol_L"): 0.2 ... 10,
        MetricUnitKey("creatinine", "mg_dL"): 0 ... 30,
        MetricUnitKey("creatinine", "umol_L"): 0 ... 3000,
        MetricUnitKey("egfr", "ml_min_173"): 0 ... 300,
        MetricUnitKey("uric_acid", "mg_dL"): 0 ... 50,
        MetricUnitKey("uric_acid", "umol_L"): 0 ... 3000,
        MetricUnitKey("tc", "mg_dL"): 0 ... 3000,
        MetricUnitKey("tg", "mg_dL"): 0 ... 3000,
        MetricUnitKey("tc", "mmol_L"): 0 ... 40,
        MetricUnitKey("tg", "mmol_L"): 0 ... 40,
        MetricUnitKey("quick", "percent"): 0 ... 250,
        MetricUnitKey("inr", "ratio"): 0 ... 20,
        MetricUnitKey("aptt", "seconds"): 0 ... 300,
        MetricUnitKey("hiv_rna", "copies_mL"): 0 ... 1_000_000_000
    ]

    private static let metricPlausibleRanges: [String: ClosedRange<Double>] = [
        "tsh": 0 ... 500,
        "ft3": 0 ... 500,
        "ft4": 0 ... 500
    ]

    private static let unitPlausibleRanges: [String: ClosedRange<Double>] = [
        "percent": 0 ... 100,
        "ratio": 0 ... 100,
        "per_uL": 0 ... 100_000,
        "U_L": 0 ... 100_000,
        "fL": 0 ... 500,
        "pg": 0 ... 200,
        "g_dL": 0 ... 100,
        "g_L": 0 ... 1000,
        "mg_dL": 0 ... 100_000,
        "mmol_L": 0 ... 1000
    ]

    static func isValid(
        metricKey: String,
        unitCode: String,
        value: Double,
        referenceLow: Double?,
        referenceHigh: Double?,
        sourceLabel: String,
        referenceRangeText: String
    ) -> Bool {
        guard value >= 0,
              value.isFinite,
              referenceLow?.isFinite != false,
              referenceHigh?.isFinite != false,
              sourceLabel.count <= maximumSourceLabelLength,
              referenceRangeText.count <= maximumReferenceRangeLength,
              let metric = HealthMetricCatalog.metric(forKey: metricKey),
              metric.unit(for: unitCode) != nil else {
            return false
        }
        if let referenceLow, let referenceHigh, referenceLow > referenceHigh {
            return false
        }
        if let plausibleRange = plausibleRange(metricKey: metricKey, unitCode: unitCode),
           !plausibleRange.contains(value) {
            return false
        }
        return true
    }

    /// Broad OCR/entry guardrails, not diagnostic or reference ranges. The
    /// report-provided reference values remain the authoritative display data.
    private static func plausibleRange(
        metricKey: String,
        unitCode: String
    ) -> ClosedRange<Double>? {
        metricUnitPlausibleRanges[MetricUnitKey(metricKey, unitCode)]
            ?? metricPlausibleRanges[metricKey]
            ?? unitPlausibleRanges[unitCode]
    }
}

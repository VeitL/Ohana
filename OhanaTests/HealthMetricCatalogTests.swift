import Testing
@testable import Ohana

struct HealthMetricCatalogTests {
    @Test func catalogHasCommonMetricsAndUsDefaults() throws {
        #expect(HealthMetricCatalog.all.count >= 30)

        let fastingGlucose = try #require(HealthMetricCatalog.metric(forKey: "fbg"))
        #expect(fastingGlucose.defaultUnit(for: "US").code == "mg_dL")
        #expect(fastingGlucose.defaultUnit(for: "CN").code == "mmol_L")

        let temperature = try #require(HealthMetricCatalog.metric(forKey: "temp"))
        #expect(temperature.defaultUnit(for: "US").code == "fahrenheit")
        #expect(temperature.defaultUnit(for: "DE").code == "celsius")
    }

    @Test func catalogLocalizesCategoriesAndMetricNames() throws {
        let lZh = L10n("zh")
        let lEn = L10n("en")
        let lDe = L10n("de")
        let hba1c = try #require(HealthMetricCatalog.metric(forKey: "hba1c"))

        #expect(HealthMetricCategory.glucose.displayName(lZh) == "血糖")
        #expect(HealthMetricCategory.glucose.displayName(lEn) == "Glucose")
        #expect(HealthMetricCategory.glucose.displayName(lDe) == "Blutzucker")
        #expect(hba1c.displayName(lZh) == "糖化血红蛋白")
        #expect(hba1c.displayName(lEn) == "HbA1c")
        #expect(hba1c.displayName(lDe) == "HbA1c")
    }

    @Test func everyMetricHasUniqueValidUnitsAndAnOptionalReferenceRange() {
        let keys = HealthMetricCatalog.all.map(\.key)
        #expect(Set(keys).count == keys.count)

        for metric in HealthMetricCatalog.all {
            #expect(!metric.key.isEmpty)
            #expect(!metric.units.isEmpty)
            #expect(Set(metric.units.map(\.code)).count == metric.units.count)
            for unit in metric.units {
                #expect(!unit.code.isEmpty)
                #expect(!unit.label.isEmpty)
                #expect(unit.normalLow?.isFinite != false)
                #expect(unit.normalHigh?.isFinite != false)
                if let low = unit.normalLow, let high = unit.normalHigh {
                    #expect(low <= high)
                }
                if unit.normalLow == nil, unit.normalHigh == nil {
                    #expect(unit.normalRangeLabel() == "—")
                } else {
                    #expect(unit.normalRangeLabel().contains(unit.label))
                }
            }
        }
    }

    @Test func expandedLabMetricsKeepStableKeysAndCanonicalUnits() throws {
        let expectedCanonicalUnits = [
            "glucose": "mmol_L",
            "ldh": "U_L",
            "alp": "U_L",
            "amylase": "U_L",
            "total_protein": "g_L",
            "urea": "mmol_L",
            "quick": "percent",
            "inr": "ratio",
            "aptt": "seconds",
            "hct": "percent",
            "mcv": "fL",
            "mch": "pg",
            "mchc": "g_dL",
            "rdw_cv": "percent",
            "rdw_sd": "fL",
            "mpv": "fL",
            "neut_pct": "percent",
            "neut_abs": "x10_9_L",
            "lymph_pct": "percent",
            "lymph_abs": "x10_9_L",
            "mono_pct": "percent",
            "mono_abs": "x10_9_L",
            "eos_pct": "percent",
            "eos_abs": "x10_9_L",
            "baso_pct": "percent",
            "baso_abs": "x10_9_L",
            "b_cells_abs": "per_uL",
            "b_cells_pct": "percent",
            "t_cells_abs": "per_uL",
            "t_cells_pct": "percent",
            "cd4_abs": "per_uL",
            "cd4_pct": "percent",
            "cd8_abs": "per_uL",
            "cd8_pct": "percent",
            "nk_cells_abs": "per_uL",
            "nk_cells_pct": "percent",
            "cytotoxic_t_cells_abs": "per_uL",
            "cytotoxic_t_cells_pct": "percent",
            "activated_t_cells_abs": "per_uL",
            "activated_t_cells_pct": "percent",
            "cd4_cd8_ratio": "ratio",
            "hiv_rna": "copies_mL"
        ]

        for (metricKey, canonicalUnitCode) in expectedCanonicalUnits {
            let metric = try #require(HealthMetricCatalog.metric(forKey: metricKey))
            #expect(metric.units.first?.code == canonicalUnitCode)
            #expect(metric.unit(for: canonicalUnitCode) != nil)
        }
    }

    @Test func ureaAndBUNRemainSemanticallyAndNumericallyDistinct() throws {
        let urea = try #require(HealthMetricCatalog.metric(forKey: "urea"))
        let bun = try #require(HealthMetricCatalog.metric(forKey: "bun"))
        let ureaMgDL = try #require(urea.unit(for: "mg_dL"))
        let bunMgDL = try #require(bun.unit(for: "mg_dL"))

        #expect(urea.nameDe == "Harnstoff")
        #expect(urea.shortNames.contains("UREA"))
        #expect(!urea.shortNames.contains("BUN"))
        #expect(bun.nameDe == "Harnstoff-Stickstoff")
        #expect(bun.shortNames.contains("BUN"))
        #expect(bun.shortNames.contains("Harnstoff-N"))
        #expect(!bun.shortNames.contains("UREA"))
        #expect(ureaMgDL.normalLow == 17)
        #expect(ureaMgDL.normalHigh == 43)
        #expect(bunMgDL.normalLow == 8)
        #expect(bunMgDL.normalHigh == 23)
    }
}

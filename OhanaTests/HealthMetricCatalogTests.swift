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

    @Test func everyMetricHasAUnitAndReferenceRange() {
        for metric in HealthMetricCatalog.all {
            #expect(!metric.key.isEmpty)
            #expect(!metric.units.isEmpty)
            for unit in metric.units {
                #expect(!unit.code.isEmpty)
                #expect(!unit.label.isEmpty)
                #expect(unit.normalRangeLabel().contains(unit.label))
            }
        }
    }
}

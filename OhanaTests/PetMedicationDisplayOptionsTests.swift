import Testing
@testable import Ohana

struct PetMedicationDisplayOptionsTests {
    @Test func doseUnitsUseStableKeysAndLocalizeLegacyValues() {
        let zh = L10n("zh")
        let en = L10n("en")

        #expect(PetMedicationDoseUnitOption.canonicalKey("片") == "tablet")
        #expect(PetMedicationDoseUnitOption.canonicalKey("tablet") == "tablet")
        #expect(PetMedicationDoseUnitOption.canonicalKey("粒") == "capsule")
        #expect(PetMedicationDoseUnitOption.canonicalKey("ml") == "ml")
        #expect(PetMedicationDoseUnitOption.displayTitle(for: "tablet", l: zh) == "片")
        #expect(PetMedicationDoseUnitOption.displayTitle(for: "片", l: en) == "tablet")
        #expect(PetMedicationDoseUnitOption.formatDosage("1 片", l: en) == "1 tablet")
        #expect(PetMedicationDoseUnitOption.formatDosage("2 capsule", l: zh) == "2 粒")
    }

    @Test func administrationMetadataReadsLegacyButWritesStableKeys() {
        let en = L10n("en")

        let legacy = PetMedicationAdministrationMetadata.split(from: "【喂法:拌饭】\nwith dinner")
        #expect(legacy.key == "mixedWithFood")
        #expect(legacy.note == "with dinner")
        #expect(PetMedicationAdministrationOption.displayTitle(for: legacy.key ?? "", l: en) == "Mixed with food")

        let canonical = PetMedicationAdministrationMetadata.merged(key: "direct", note: "after meal")
        #expect(canonical == "【admin:direct】\nafter meal")

        let parsedCanonical = PetMedicationAdministrationMetadata.split(from: canonical)
        #expect(parsedCanonical.key == "direct")
        #expect(parsedCanonical.note == "after meal")
    }
}

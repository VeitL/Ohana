//
//  AddPlantView+CareDetailsStep.swift
//  Ohana
//
//  Step 3: recommended care details with editable controls.
//

import SwiftUI

extension AddPlantView {
    var plantCareDetailsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            PlantCreationInfoRow(
                icon: "drop.fill",
                title: l.tr(zh: "Water", en: "Water", de: "Wasser"),
                subtitle: selectedCatalog?.localizedWateringPreference ?? l.tr(zh: "按表土干湿调整。", en: "Adjust by soil dryness.", de: "Nach Erdfeuchte anpassen.")
            ) {
                Stepper(
                    l.tr(zh: "每 \(wateringInterval) 天", en: "Every \(wateringInterval) days", de: "Alle \(wateringInterval) Tage"),
                    value: $wateringInterval,
                    in: 1 ... 90
                )
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            }

            PlantCreationInfoRow(
                icon: "sun.max.fill",
                title: l.tr(zh: "Light", en: "Light", de: "Licht"),
                subtitle: selectedCatalog.map { l.tr(zh: "推荐：\($0.lightRequirement.displayName)", en: "Recommended: \($0.lightRequirement.displayName)", de: "Empfohlen: \($0.lightRequirement.displayName)") }
                    ?? l.tr(zh: "记录光照强度和窗户朝向。", en: "Record intensity and window direction.", de: "Lichtstärke und Fenster erfassen.")
            ) {
                VStack(spacing: 10) {
                    Picker(l.tr(zh: "光照强度", en: "Light level", de: "Lichtstärke"), selection: $lightLevel) {
                        ForEach(PlantLightLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    Picker(l.tr(zh: "窗户朝向", en: "Window direction", de: "Fensterausrichtung"), selection: $windowDirection) {
                        ForEach(PlantWindowDirection.allCases) { direction in
                            Text(direction.displayName).tag(direction)
                        }
                    }
                    Stepper(
                        lightMeasurementLux > 0
                            ? l.tr(zh: "实测 \(lightMeasurementLux) lux", en: "\(lightMeasurementLux) lux reading", de: "\(lightMeasurementLux) lux")
                            : l.tr(zh: "实测 未记录", en: "Reading not recorded", de: "Messung nicht erfasst"),
                        value: $lightMeasurementLux,
                        in: 0 ... 20000,
                        step: 250
                    )
                }
                .pickerStyle(.menu)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            }

            PlantCreationInfoRow(
                icon: "humidity.fill",
                title: l.tr(zh: "Humidity", en: "Humidity", de: "Luftfeuchte"),
                subtitle: selectedCatalog?.localizedHumidity ?? l.tr(zh: "根据房间湿度和空调暖气微调。", en: "Tune by room humidity and AC/heater exposure.", de: "Nach Raumfeuchte und Klimaquelle anpassen.")
            ) {
                VStack(spacing: 10) {
                    Picker(l.tr(zh: "湿度偏好", en: "Humidity preference", de: "Luftfeuchte"), selection: $humidityPreference) {
                        ForEach(PlantHumidityPreference.allCases) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    Picker(l.tr(zh: "温度偏好", en: "Temperature preference", de: "Temperatur"), selection: $temperaturePreference) {
                        ForEach(PlantTemperaturePreference.allCases) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    Toggle(l.tr(zh: "靠近空调/暖气", en: "Near AC/heater", de: "Nahe an Klimaanlage/Heizung"), isOn: $isNearClimateSource)
                        .tint(Color.goPrimary)
                }
                .pickerStyle(.menu)
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            }

            PlantCreationInfoRow(
                icon: "leaf.fill",
                title: l.tr(zh: "Fertilizing", en: "Fertilizing", de: "Düngen"),
                subtitle: selectedCatalog?.localizedFertilizing ?? l.tr(zh: "生长期薄肥，状态紧张时暂停。", en: "Use light fertilizer in growing season; pause when stressed.", de: "In der Wachstumszeit leicht düngen, bei Stress pausieren.")
            ) {
                Stepper(
                    l.tr(zh: "每 \(fertilizingInterval) 天", en: "Every \(fertilizingInterval) days", de: "Alle \(fertilizingInterval) Tage"),
                    value: $fertilizingInterval,
                    in: 1 ... 365
                )
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            }

            PlantCreationInfoRow(
                icon: "shippingbox.fill",
                title: l.tr(zh: "Repotting", en: "Repotting", de: "Umtopfen"),
                subtitle: selectedCatalog?.localizedSoil ?? l.tr(zh: "盆径、介质和排水会影响换盆复查。", en: "Pot size, soil, and drainage affect repot checks.", de: "Topfgröße, Erde und Drainage beeinflussen Umtopfchecks.")
            ) {
                VStack(spacing: 10) {
                    Stepper(l.tr(zh: "盆径 \(Int(potDiameterCm)) cm", en: "Pot \(Int(potDiameterCm)) cm", de: "Topf \(Int(potDiameterCm)) cm"), value: $potDiameterCm, in: 0 ... 80, step: 1)
                    Toggle(l.tr(zh: "花盆有排水孔", en: "Pot has drainage hole", de: "Topf hat Abzugsloch"), isOn: $potHasDrainage)
                        .tint(Color.goPrimary)
                    OhanaChoiceChipRow(
                        title: l.tr(zh: "常见土壤", en: "Common soil", de: "Häufige Erde"),
                        options: commonSoilOptions,
                        selection: $soilType,
                        identifierPrefix: "add-plant-soil-choice"
                    )
                    inlineFormField(
                        l.tr(zh: "土壤类型", en: "Soil type", de: "Erdtyp"),
                        text: $soilType,
                        placeholder: l.tr(zh: "疏松排水型通用土", en: "Loose well-draining mix", de: "Lockere gut drainierende Erde"),
                        identifier: "add-plant-soil-input",
                        focusField: .soil,
                        submitLabel: .done
                    )
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            }

            PlantCreationInfoRow(
                icon: "hands.sparkles.fill",
                title: l.tr(zh: "Clean", en: "Clean", de: "Reinigen"),
                subtitle: l.tr(zh: "靠近空调/暖气会让叶片清洁提醒更频繁。", en: "AC/heater exposure makes leaf-cleaning checks more frequent.", de: "Klimaquellen machen Blattreinigung häufiger.")
            ) {
                Toggle(l.tr(zh: "需要更频繁清洁叶片", en: "Needs more frequent leaf cleaning", de: "Häufigere Blattreinigung"), isOn: $isNearClimateSource)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .tint(Color.goPrimary)
            }

            PlantCreationInfoRow(
                icon: "exclamationmark.triangle.fill",
                title: l.tr(zh: "Toxicity", en: "Toxicity", de: "Giftigkeit"),
                subtitle: selectedCatalog?.localizedToxicity ?? l.tr(zh: "可按家中宠物和儿童情况调整。", en: "Adjust for pets and children at home.", de: "Für Haustiere und Kinder anpassen.")
            ) {
                VStack(spacing: 8) {
                    Toggle(l.tr(zh: "对猫有误食风险", en: "Risk for cats", de: "Risiko für Katzen"), isOn: $isToxicToCats)
                    Toggle(l.tr(zh: "对狗有误食风险", en: "Risk for dogs", de: "Risiko für Hunde"), isOn: $isToxicToDogs)
                    Toggle(l.tr(zh: "对儿童有误食风险", en: "Risk for children", de: "Risiko für Kinder"), isOn: $isToxicToChildren)
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            }

            PlantCreationInfoRow(
                icon: "ruler.fill",
                title: l.tr(zh: "Dimension", en: "Dimension", de: "Größe"),
                subtitle: l.tr(zh: "株高、冠幅和类型会影响换盆与护理判断。", en: "Height, spread, and type affect repot and care logic.", de: "Höhe, Breite und Typ beeinflussen Umtopf- und Pflegechecks.")
            ) {
                VStack(spacing: 10) {
                    Stepper(l.tr(zh: "当前高度 \(Int(currentHeightCm)) cm", en: "Height \(Int(currentHeightCm)) cm", de: "Höhe \(Int(currentHeightCm)) cm"), value: $currentHeightCm, in: 0 ... 300, step: 1)
                    Stepper(l.tr(zh: "冠幅 \(Int(currentSpreadCm)) cm", en: "Spread \(Int(currentSpreadCm)) cm", de: "Breite \(Int(currentSpreadCm)) cm"), value: $currentSpreadCm, in: 0 ... 300, step: 1)
                    Toggle(l.tr(zh: "水培", en: "Hydroponic", de: "Hydrokultur"), isOn: $isHydroponic)
                        .tint(Color.goPrimary)
                    Toggle(l.tr(zh: "多肉/仙人掌类", en: "Succulent/cactus", de: "Sukkulente/Kaktus"), isOn: $isSucculent)
                        .tint(Color.goPrimary)
                }
                .font(OhanaFont.callout(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            }
        }
        .overlay(alignment: .topLeading) {
            PlantCreationAccessibilityMarker(identifier: "add-plant-step-care-details")
        }
    }
}

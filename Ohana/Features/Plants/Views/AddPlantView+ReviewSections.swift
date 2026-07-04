//
//  AddPlantView+ReviewSections.swift
//  Ohana
//
//  Optional review sections kept out of the primary Add Plant flow.
//

import SwiftUI
import UIKit

extension AddPlantView {
    @ViewBuilder
    var duplicateWarningSection: some View {
        if !duplicateCandidates.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative warning glyph; adjacent title and rows explain duplicate risk.
                        .foregroundStyle(Color.goYellow)
                        .accessibilityHidden(true)
                    Text(l.tr(zh: "可能重复", en: "Possible duplicate", de: "Möglicherweise doppelt"))
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    if duplicateAcknowledgementKey == currentDuplicateAcknowledgementKey {
                        Text(l.tr(zh: "已确认", en: "Confirmed", de: "Bestätigt"))
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
                ForEach(duplicateCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.title)
                            .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text("\(candidate.reason) · \(candidate.detail)")
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    duplicateAcknowledgementKey = currentDuplicateAcknowledgementKey
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(l.tr(zh: "仍然添加为新植物", en: "Still add as a new plant", de: "Trotzdem als neue Pflanze hinzufügen"), systemImage: "plus.circle")
                        .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(ScaleButtonStyle())
                .foregroundStyle(Color.goPrimary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.goYellow.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(Color.goYellow.opacity(0.22), lineWidth: 1)
            }
        }
    }

    var environmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(l.tr(zh: "室内植物", en: "Indoor plant", de: "Zimmerpflanze"), isOn: $isIndoor)
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
            Picker(l.tr(zh: "窗户朝向", en: "Window direction", de: "Fensterausrichtung"), selection: $windowDirection) {
                ForEach(PlantWindowDirection.allCases) { direction in
                    Text(direction.displayName).tag(direction)
                }
            }
            Picker(l.tr(zh: "光照强度", en: "Light level", de: "Lichtstärke"), selection: $lightLevel) {
                ForEach(PlantLightLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            Stepper(
                lightMeasurementLux > 0
                    ? l.tr(zh: "光照实测 \(lightMeasurementLux) lux", en: "Light reading \(lightMeasurementLux) lux", de: "Lichtmessung \(lightMeasurementLux) lux")
                    : l.tr(zh: "光照实测 未记录", en: "Light reading not recorded", de: "Lichtmessung nicht erfasst"),
                value: $lightMeasurementLux,
                in: 0 ... 20000,
                step: 250
            )
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
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
                .font(OhanaFont.adaptive(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .tint(Color.goPrimary)
        }
        .pickerStyle(.menu)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }

    var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(l.tr(zh: "当前状态", en: "Current status", de: "Aktueller Zustand"), selection: $healthStatus) {
                ForEach(PlantHealthStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            if let catalog = selectedCatalog,
               catalog.isToxicToCats || catalog.isToxicToDogs || catalog.isToxicToChildren {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill") // a11y: allow decorative warning glyph; adjacent text carries the warning.
                        .foregroundStyle(Color.goYellow)
                        .accessibilityHidden(true)
                    Text(l.tr(
                        zh: "已标记宠物/儿童误食风险，详情页和提醒会优先提示。",
                        en: "Marked as an ingestion risk for pets/children. Details and reminders will prioritize safety.",
                        de: "Als Verschluckrisiko für Haustiere/Kinder markiert. Details und Erinnerungen betonen Sicherheit."
                    ))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
            }
        }
        .pickerStyle(.menu)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .goTranslucentCard(cornerRadius: OhanaRadius.controlLarge)
    }
}

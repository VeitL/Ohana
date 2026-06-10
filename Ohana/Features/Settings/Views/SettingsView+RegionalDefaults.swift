//
//  SettingsView+RegionalDefaults.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension SettingsView {
    func menuValueLabel(_ text: String) -> some View {
        HStack(spacing: 5) {
            Text(text)
                .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Image(systemName: "chevron.down") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 9, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
        }
        .foregroundStyle(primaryText)
        .frame(minHeight: 34)
        .padding(.horizontal, 10)
        .background(Color.ohanaControlFill, in: Capsule())
    }

    func applyCountryDefaults(_ country: AppCountry.Option) {
        AppCountry.applyDefaults(for: country.code)
        appCountry = country.code
        appLanguage = AppLanguage.normalize(country.defaultLanguageCode)
        appMeasurementSystem = AppMeasurementSystem.normalize(country.defaultMeasurementSystemCode)
        appCurrency = AppCurrency.normalize(country.defaultCurrencyCode)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func syncStoredRegionalDefaultsIfNeeded() {
        AppCountry.ensureInitialized()
        if appCountry != AppCountry.code {
            appCountry = AppCountry.code
        }
        if appMeasurementSystem != AppMeasurementSystem.code {
            appMeasurementSystem = AppMeasurementSystem.code
        }
        if appCurrency != AppCurrency.code {
            appCurrency = AppCurrency.code
        }
        if appLanguage != AppLanguage.code {
            appLanguage = AppLanguage.code
        }
    }

    func scheduleDataSectionsMount() {
        guard !areDataSectionsMounted else { return }
        dataSectionsMountTask?.cancel()
        dataSectionsMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 260) {
            withAnimation(GoMotion.quick) {
                areDataSectionsMounted = true
            }
            dataSectionsMountTask = nil
        }
    }
}

//
//  SettingsView+RegionalDefaults.swift
//  Ohana
//

import SwiftData
import SwiftUI
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
        appCountry = country.code
        appMeasurementSystem = AppMeasurementSystem.normalize(country.defaultMeasurementSystemCode)
        appCurrency = AppCurrency.normalize(country.defaultCurrencyCode)
        languageSelectionCode = AppLanguage.normalize(country.defaultLanguageCode)
        scheduleLanguageCommit(languageSelectionCode)
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
            commitLanguageChange(AppLanguage.code, emitFeedback: false)
        }
    }

    func syncLanguageSelectionFromStorage() {
        let normalized = AppLanguage.normalize(appLanguage)
        guard languageSelectionCode != normalized else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            languageSelectionCode = normalized
        }
    }

    func scheduleLanguageCommit(_ rawLanguageCode: String) {
        let normalized = AppLanguage.normalize(rawLanguageCode)
        guard normalized != AppLanguage.normalize(appLanguage) else {
            languageCommitTask?.cancel()
            languageCommitTask = nil
            return
        }

        languageCommitTask?.cancel()
        languageCommitTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 96) {
            commitLanguageChange(normalized)
        }
    }

    func commitLanguageChange(_ languageCode: String, emitFeedback: Bool = true) {
        let normalized = AppLanguage.normalize(languageCode)
        guard AppLanguage.normalize(appLanguage) != normalized else {
            languageCommitTask = nil
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            appLanguage = normalized
        }
        languageCommitTask = nil

        if emitFeedback {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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

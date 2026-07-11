import Foundation
import Testing
@testable import Ohana

struct LocalizationTests {
    @Test func localizedTextResolvesSupportedLanguages() {
        let text = AppLocalizedText(
            translations: [
                "zh": "保存",
                "en": "Save",
                "de": "Speichern",
                "es": "Guardar",
                "pt": "Salvar",
                "fr": "Enregistrer",
                "ja": "保存",
                "ko": "저장",
                "it": "Salva"
            ]
        )

        #expect(text.resolve("zh") == "保存")
        #expect(text.resolve("en") == "Save")
        #expect(text.resolve("de") == "Speichern")
        #expect(text.resolve("es") == "Guardar")
        #expect(text.resolve("pt") == "Salvar")
        #expect(text.resolve("fr") == "Enregistrer")
        #expect(text.resolve("ja") == "保存")
        #expect(text.resolve("ko") == "저장")
        #expect(text.resolve("it") == "Salva")
        #expect(text.missingSupportedLanguageCodes.isEmpty)
    }

    @Test func localizedTextReportsMissingRegisteredTranslations() {
        let text = AppLocalizedText(zh: "货币", en: "Currency")

        #expect(text.resolve("de") == "Currency")
        #expect(text.resolve("es") == "Currency")
        #expect(text.resolve("pt") == "Currency")
        #expect(text.resolve("fr") == "Currency")
        #expect(text.resolve("ja") == "Currency")
        #expect(text.resolve("ko") == "Currency")
        #expect(text.resolve("it") == "Currency")
        #expect(text.missingSupportedLanguageCodes == ["de", "es", "pt", "fr", "ja", "ko", "it"])
    }

    @Test func languageRegistryProvidesFutureReadyFallbackChains() {
        #expect(AppLanguage.supported.map(\.code) == ["zh", "en", "de", "es", "pt", "fr", "ja", "ko", "it"])
        #expect(AppLanguage.supportedLprojNames == Set(["zh-Hans", "en", "de", "es", "pt", "fr", "ja", "ko", "it"]))
        #expect(AppLanguage.fallbackChain(for: "de") == ["de", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "es") == ["es", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "pt") == ["pt", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "fr") == ["fr", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "ja") == ["ja", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "ko") == ["ko", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "it") == ["it", "en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "en") == ["en", "zh"])
        #expect(AppLanguage.fallbackChain(for: "nl") == ["zh", "en"])
        #expect(AppLanguage.lprojName(for: "de") == "de")
        #expect(AppLanguage.lprojName(for: "es") == "es")
        #expect(AppLanguage.lprojName(for: "pt") == "pt")
        #expect(AppLanguage.lprojName(for: "fr") == "fr")
        #expect(AppLanguage.lprojName(for: "ja") == "ja")
        #expect(AppLanguage.lprojName(for: "ko") == "ko")
        #expect(AppLanguage.lprojName(for: "it") == "it")
    }

    @Test func highTrafficCopyResolvesSupportedLanguages() {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")
        let es = L10n("es")
        let pt = L10n("pt")
        let fr = L10n("fr")
        let ja = L10n("ja")
        let ko = L10n("ko")
        let it = L10n("it")

        #expect(zh.potty == "噗噗")
        #expect(en.potty == "Poop")
        #expect(de.potty == "Häufchen")
        #expect(es.potty == "Popó")
        #expect(pt.potty == "Cocô")
        #expect(fr.potty == "Caca")
        #expect(ja.potty == "ぷっぷ")
        #expect(ko.potty == "뿌뿌")
        #expect(it.potty == "Popò")
        #expect(zh.edit == "编辑")
        #expect(en.edit == "Edit")
        #expect(de.edit == "Bearbeiten")
        #expect(es.edit == "Editar")
        #expect(pt.edit == "Editar")
        #expect(fr.edit == "Modifier")
        #expect(ja.edit == "編集")
        #expect(ko.edit == "편집")
        #expect(it.edit == "Modifica")
        #expect(zh.addEntityHeadline == "谁要上岛？")
        #expect(en.addEntityHeadline == "Who's joining the fun?")
        #expect(de.addEntityHeadline == "Wer kommt dazu?")
        #expect(es.addEntityHeadline == "¿Quién sube a la isla?")
        #expect(pt.addEntityHeadline == "Quem chega à ilha?")
        #expect(fr.addEntityHeadline == "Qui monte sur l'île ?")
        #expect(ja.addEntityHeadline == "だれが島にくる？")
        #expect(ko.addEntityHeadline == "누가 섬에 올까요?")
        #expect(it.addEntityHeadline == "Chi sale sull'isola?")
        #expect(de.petCardWalkPoopLabel == "Häufchen-Stopps")
        #expect(es.petCardWalkPoopLabel == "Paradas popó")
        #expect(pt.petCardWalkPoopLabel == "Paradas cocô")
        #expect(fr.petCardWalkPoopLabel == "Arrêts caca")
        #expect(ja.petCardWalkPoopLabel == "ぷっぷ電台")
        #expect(ko.petCardWalkPoopLabel == "뿌뿌 방송국")
        #expect(it.petCardWalkPoopLabel == "Radio popò")
        #expect(es.daysLeft(3) == "Quedan 3 días")
        #expect(pt.homeToastPotty("Mochi", points: 2) == "Mochi cocô registrado +2 🥥")
        #expect(fr.petCardVaccineCountdown(daysUntilDue: 5) == "dans 5 j")
        #expect(ja.daysLeft(3) == "あと 3 日")
        #expect(ko.homeToastPotty("Mochi", points: 2) == "Mochi 뿌뿌 기록 +2 🥥")
        #expect(it.petCardVaccineCountdown(daysUntilDue: 5) == "tra 5 g")
    }

    @Test func functionMenuCopyResolvesPlantEntrypoints() {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")

        #expect(FeatureGroup.plants.title(l: zh) == "植物")
        #expect(FeatureGroup.plants.title(l: en) == "Plants")
        #expect(FeatureGroup.plants.title(l: de) == "Pflanzen")
        #expect(FeatureGroup.householdHub.title(l: en) == "Household")
        #expect(PetFeature.food.title(l: en) == "Food")
        #expect(PetFeature.potty.title(l: de) == "Häufchen-Radio")
    }

    @Test func localizedHelpersDoNotCollapseGermanToEnglish() {
        let de = L10n("de")
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 1))!

        #expect(Human.westernZodiacDisplay(for: date, l: de) == "Steinbock")
        #expect(PetPersonalityTag.displayTitle(for: "curious", l: de) == "Neugierig")
        #expect(PetAgeConverter.humanAge(birthday: date, species: "狗", l: de).contains("Menschenalter"))
    }

    @Test func petTagGreetingDoesNotFallbackToChineseForEnglishOrGerman() {
        let pet = Pet(name: "Momo", species: "狗")
        pet.personalityTagsRaw = "curious"

        let zh = PetTagGreeting.homeSubtitleHint(pet: pet, hour: 8, l: L10n("zh"))
        let en = PetTagGreeting.homeSubtitleHint(pet: pet, hour: 8, l: L10n("en"))
        let de = PetTagGreeting.homeSubtitleHint(pet: pet, hour: 8, l: L10n("de"))

        #expect(!zh.isEmpty)
        #expect(!containsCJK(en))
        #expect(!containsCJK(de))
    }

    @Test func petBreedCareTipsDoNotFallbackToChineseForEnglishOrGerman() throws {
        let zh = try #require(PetBreedDatabase.careTips(for: "西伯利亚哈士奇", l: L10n("zh")))
        let en = try #require(PetBreedDatabase.careTips(for: "西伯利亚哈士奇", l: L10n("en")))
        let de = try #require(PetBreedDatabase.careTips(for: "西伯利亚哈士奇", l: L10n("de")))

        #expect(!zh.isEmpty)
        #expect(!en.isEmpty)
        #expect(!de.isEmpty)
        #expect(containsCJK(zh.joined(separator: " ")))
        #expect(!containsCJK(en.joined(separator: " ")))
        #expect(!containsCJK(de.joined(separator: " ")))
    }

    @Test func day0PromiseCopyResolvesChineseAndEnglish() {
        let zh = Day0PromiseCopy(L10n("zh"))
        let en = Day0PromiseCopy(L10n("en"))

        #expect(zh.navigationTitle(petEmoji: "🐶") == "🐶 首日承诺")
        #expect(en.navigationTitle(petEmoji: "🐶") == "🐶 Day 0 Promise")
        #expect(zh.welcomeTitle(petName: "Momo") == "欢迎 Momo 🎉")
        #expect(en.welcomeTitle(petName: "Momo") == "Welcome, Momo 🎉")
        #expect(zh.sendPromisesTitle(count: 2) == "把 2 条承诺发给家人")
        #expect(en.sendPromisesTitle(count: 1) == "Send 1 promise to family")
        #expect(en.sendPromisesTitle(count: 2) == "Send 2 promises to family")
        #expect(zh.taskDescription(petName: "Momo") == "首日承诺 · 让家人一起帮 Momo 开启第一天")
        #expect(en.taskDescription(petName: "Momo") == "Day 0 Promise · Let your family help Momo start day one")
    }

    @Test func day0PromisePromisesLocalizeSpeciesSpecificActions() {
        let zh = Day0PromiseCopy(L10n("zh"))
        let en = Day0PromiseCopy(L10n("en"))

        let zhDogTitles = zh.promises(petName: "Momo", species: "狗").map(\.title)
        let enDogTitles = en.promises(petName: "Momo", species: "dog").map(\.title)
        let enCatTitles = en.promises(petName: "Luna", species: "cat").map(\.title)

        #expect(zhDogTitles.contains("明天带 Momo 出去走 15 分钟"))
        #expect(enDogTitles.contains("Take Momo for a 15-minute walk tomorrow"))
        #expect(enCatTitles.contains("Brush Luna tonight for a little wind-down"))
    }

    @Test func day0PromiseCopyFallsBackToEnglishForOtherRegisteredLanguages() {
        let de = Day0PromiseCopy(L10n("de"))

        #expect(de.skipTitle == "Skip")
        #expect(de.skipForNowTitle == "Skip for now")
        #expect(de.sendPromisesTitle(count: 2) == "Send 2 promises to family")
    }

    @Test func countryDefaultsMapToLanguageUnitsAndCurrency() {
        let us = AppCountry.option(for: "US")
        let germany = AppCountry.option(for: "DE")
        let china = AppCountry.option(for: "CN")

        #expect(us.defaultLanguageCode == "en")
        #expect(us.defaultCurrencyCode == "USD")
        #expect(us.defaultMeasurementSystemCode == "imperial")
        #expect(germany.defaultLanguageCode == "de")
        #expect(germany.defaultCurrencyCode == "EUR")
        #expect(germany.defaultMeasurementSystemCode == "metric")
        #expect(china.defaultLanguageCode == "zh")
        #expect(china.defaultCurrencyCode == "CNY")
        #expect(china.defaultMeasurementSystemCode == "metric")
    }

    @Test func countrySelectionAppliesEditablePreferenceDefaults() {
        let defaults = UserDefaults.standard
        let previousCountry = defaults.string(forKey: AppCountry.storageKey)
        let previousLanguage = defaults.string(forKey: "appLanguage")
        let previousCurrency = defaults.string(forKey: AppCurrency.storageKey)
        let previousMeasurement = defaults.string(forKey: AppMeasurementSystem.storageKey)
        defer {
            restore(previousCountry, forKey: AppCountry.storageKey)
            restore(previousLanguage, forKey: "appLanguage")
            restore(previousCurrency, forKey: AppCurrency.storageKey)
            restore(previousMeasurement, forKey: AppMeasurementSystem.storageKey)
        }

        AppCountry.applyDefaults(for: "GB")

        #expect(defaults.string(forKey: AppCountry.storageKey) == "GB")
        #expect(defaults.string(forKey: "appLanguage") == "en")
        #expect(defaults.string(forKey: AppCurrency.storageKey) == "GBP")
        #expect(defaults.string(forKey: AppMeasurementSystem.storageKey) == "imperial")
    }

    @Test func domainBackupErrorsResolveLocalizedCopy() {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")

        #expect(BackupError.missingPassword.localizedMessage(l: zh) == "请输入备份密码后重试。")
        #expect(BackupError.missingPassword.localizedMessage(l: en) == "Enter a backup password and try again.")
        #expect(BackupError.weakPassword(minimum: 8).localizedMessage(l: en) == "Backup password must be at least 8 characters.")
        #expect(BackupError.passwordMismatch.localizedMessage(l: de) == "Die beiden Backup-Passwörter stimmen nicht überein.")
        #expect(BackupError.unsupportedVersion(72).localizedMessage(l: en).contains("v72"))
        #expect(BackupError.invalidEncryptedBackup.localizedMessage(l: en).contains("encrypted backup"))
        #expect(BackupError.invalidRestoreData(.identity).localizedMessage(l: zh).contains("未对现有数据进行任何更改"))
        #expect(BackupError.invalidRestoreData(.relationship).localizedMessage(l: en).contains("broken required relationship"))
        #expect(BackupError.invalidRestoreData(.pendingChanges).localizedMessage(l: de).contains("Änderungen stehen noch aus"))
    }

    @Test func automaticBackupErrorsResolveLocalizedCopy() {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")

        #expect(AutomaticBackupFileStoreError.iCloudUnavailable.localizedMessage(l: zh).contains("iCloud Drive 暂时不可用"))
        #expect(AutomaticBackupFileStoreError.iCloudUnavailable.localizedMessage(l: en).contains("iCloud Drive is temporarily unavailable"))
        #expect(AutomaticBackupFileStoreError.writeFailed("disk full").localizedMessage(l: en) == "Automatic backup failed to write: disk full")
        #expect(AutomaticBackupFileStoreError.cleanupFailed("locked").localizedMessage(l: de) == "Automatische Backup-Bereinigung fehlgeschlagen: locked")
    }

    @Test func domainCareRewardCopyResolvesLocalizedTitles() {
        let pet = Pet(name: "Momo", species: "猫")
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")

        #expect(DomainCareRewardAction.feed.title(pet: pet, l: zh) == "Momo 喂食奖励")
        #expect(DomainCareRewardAction.feed.title(pet: pet, l: en) == "Momo feeding reward")
        #expect(DomainCareRewardAction.walk(distanceMeters: 1200).title(pet: pet, l: de) == "Momo Spaziergang-Bonus")
        #expect(DomainCareRewardAction.care(type: .bath).title(pet: pet, l: en) == "Momo bath reward")
        #expect(DomainCareRewardAction.expense.title(pet: nil, l: en) == "Expense reward")
        #expect(DomainCareRewardAction.dailyFocusCompletion.title(pet: nil, l: de) == "Today Focus abgeschlossen")
        #expect(DomainCareRewardQuality.precise.badgeLabel(l: en) == "🎯 Precise XP+10%")
        #expect(DomainCareRewardQuality.preciseNotePhoto.badgeLabel(l: de) == "✨ Vollständiger Eintrag XP+30%")
    }

    @Test func carePlanOverdueCopyResolvesLocalizedStatus() {
        let status = CarePlanOverdueStatus(
            title: "喂食", // localization-audit: allow test fixture source title
            actionType: "feed",
            scheduledAt: Date(timeIntervalSince1970: 1000),
            daysOverdue: 2,
            reminderId: nil,
            eventId: nil
        )
        let waterStatus = WaterCareCycleStatus(elapsedDays: 5, intervalDays: 3)
        let dueToday = WaterCareCycleStatus(elapsedDays: 3, intervalDays: 3)
        let upcoming = CareCycleStatus(elapsedDays: 1, intervalDays: 3)

        #expect(status.localizedTitle(l: L10n("en")) == "Feeding")
        #expect(status.compactText(l: L10n("en")) == "2d overdue")
        #expect(status.localizedOverdueText(l: L10n("de")) == "Fütterung 2 T. überfällig")
        #expect(waterStatus.compactDueText(l: L10n("zh")) == "逾期2天")
        #expect(waterStatus.compactDueText(l: L10n("en")) == "2d overdue")
        #expect(dueToday.compactDueText(l: L10n("de")) == "Heute")
        #expect(dueToday.duePhase == .dueToday)
        #expect(upcoming.duePhase == .upcoming)
        #expect(upcoming.compactLastRecordedText(l: L10n("en")) == "1d ago")
        #expect(WaterCareCycleWarningKind.waterChange.localizedTitle(l: L10n("en")) == "Water change")
        #expect(WaterCareCycleWarningKind.filterClean.localizedTitle(l: L10n("de")) == "Filter")
        #expect(WaterCareCycleWarningKind.filterReplace.localizedTitle(l: L10n("en")) == "Replacement")
    }

    @Test func plantCareTypeDisplayNameCanUseExplicitLanguage() {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")

        #expect(PlantCareType.watering.displayName(l: zh) == "浇水")
        #expect(PlantCareType.watering.displayName(l: en) == "Watering")
        #expect(PlantCareType.watering.displayName(l: de) == "Gießen")
        #expect(PlantCareType.pestCheck.displayName(l: en) == "Pest check")
        #expect(PlantCareType.pestCheck.displayName(l: de) == "Schädlingscheck")
        #expect(PlantCareType.customNote.displayName(l: zh) == "备注")
    }

    @Test @MainActor func domainGeneratedStatusAndRewardCopyResolvesLocalizedTitles() throws {
        let zh = L10n("zh")
        let en = L10n("en")
        let de = L10n("de")

        #expect(CareEventService.sharedCareRewardTitle(.feeding, targetCount: 2, l: zh) == "共同喂食 · 2只")
        #expect(CareEventService.sharedCareRewardTitle(.feeding, targetCount: 2, l: en) == "Shared feeding · 2 pets")
        #expect(CareEventService.sharedCareRewardTitle(.walk, targetCount: 1, l: de) == "Gemeinsamer Spaziergang · 1 Haustier")
        #expect(CareEventService.sharedCareRewardTitle(.expense, targetCount: 2, category: .medical, l: en) == "Shared expense · Medical")
        #expect(EntityKind.human.displayName(l: en) == "Human")
        #expect(EntityKind.plant.displayName(l: de) == "Pflanze")

        #expect(CalendarTaskCompletionSyncService.calendarRewardTitle(for: .play, petName: "Momo", l: en) == "Momo play reward")
        #expect(CalendarTaskCompletionSyncService.calendarRewardTitle(for: .filterClean, petName: "Bubbles", l: de) == "Bubbles Filterreinigungs-Bonus")
        if case let .general(_, _, _, title) = CalendarTaskCompletionSyncService.rewardAction(for: .waterChange, petName: "Bubbles", l: en) {
            #expect(title == "Bubbles water-change reward")
        } else {
            Issue.record("Expected water-change calendar reward to use a general reward action")
        }

        let pet = Pet(name: "Momo", species: "猫")
        let event = CareLedgerEvent(
            occurredAt: Date(timeIntervalSince1970: 1000),
            actorKind: .human,
            actorId: nil,
            subjectKind: .pet,
            subjectId: pet.id.uuidString,
            eventKind: .medication,
            actionType: "medication",
            coconutDelta: 3
        )
        let entry = try #require(CareLedgerStatsService().reportEntries(
            events: [event],
            pets: [pet],
            humans: [],
            interval: DateInterval(
                start: Date(timeIntervalSince1970: 900),
                end: Date(timeIntervalSince1970: 1100)
            ),
            l: en
        ).first)
        #expect(entry.title == "Medication")
        #expect(entry.actorName == "Unassigned")

        let recent = AntiRepeatCareManager.checkRecentCareLedger(
            for: pet,
            type: .feeding,
            ledgerEvents: [
                CareLedgerEvent(
                    occurredAt: Date(timeIntervalSince1970: 1000),
                    actorKind: .human,
                    actorId: pet.id.uuidString,
                    subjectKind: .pet,
                    subjectId: pet.id.uuidString,
                    eventKind: .care,
                    actionType: CareType.feeding.rawValue
                )
            ],
            currentUserId: pet.id.uuidString,
            in: [],
            now: Date(timeIntervalSince1970: 1060),
            l: de
        )
        #expect(recent?.executorName == "Du")
    }

    @Test func measurementSystemNormalizesUnknownValues() {
        #expect(AppMeasurementSystem.normalize("metric") == "metric")
        #expect(AppMeasurementSystem.normalize("imperial") == "imperial")
        #expect(AppMeasurementSystem.normalize("unknown") == AppMeasurementSystem.fallbackCode)
    }

    private func restore(_ value: String?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
        }
    }
}

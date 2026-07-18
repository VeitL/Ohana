//
//  SettingsView+MainSections.swift
//  Ohana
//

import SwiftUI

extension SettingsView {
    @ViewBuilder
    var settingsBodySections: some View {
        if SettingsDebugTools.isRunningUITests {
            settingsUITestShortcutSection
        }
        settingsDataSections
        settingsDeferredHeavySections
        settingsExperienceSection
        settingsPersonalSection
        settingsCategorySection
    }

    var settingsCategorySection: some View {
        Section {
            ForEach(SettingsDestination.allCases, id: \.self) { destination in
                NavigationLink(value: destination) {
                    SettingsNavigationLabel(
                        icon: destination.icon,
                        title: destination.title(l),
                        subtitle: destination.subtitle(l)
                    )
                }
                .accessibilityIdentifier(destination.accessibilityIdentifier)
            }
        } header: {
            Text(l.tr(zh: "设置分类", en: "Settings", de: "Einstellungen"))
        }
    }

    var settingsExperienceSection: some View {
        settingsSection(title: l.tr(
            zh: "使用模式",
            en: "Experience",
            de: "Nutzungsmodus",
            es: "Modo de uso",
            pt: "Modo de uso",
            fr: "Mode d’utilisation",
            ja: "利用モード",
            ko: "사용 모드",
            it: "Modalità d’uso"
        )) {
            HStack(spacing: 12) {
                settingsIcon(
                    experienceMode == .zen ? "leaf.fill" : "square.grid.2x2.fill",
                    color: experienceMode == .zen ? Color.goPrimary : Color.goBlue
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(
                        zh: "App 模式",
                        en: "App mode",
                        de: "App-Modus",
                        es: "Modo de la app",
                        pt: "Modo do app",
                        fr: "Mode de l’app",
                        ja: "Appモード",
                        ko: "앱 모드",
                        it: "Modalità app"
                    ))
                        .font(OhanaFont.body(.semibold))
                    Text(experienceMode.subtitle(l))
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Picker(
                    l.tr(
                        zh: "App 模式",
                        en: "App mode",
                        de: "App-Modus",
                        es: "Modo de la app",
                        pt: "Modo do app",
                        fr: "Mode de l’app",
                        ja: "Appモード",
                        ko: "앱 모드",
                        it: "Modalità app"
                    ),
                    selection: Binding(
                        get: { experienceMode },
                        set: { onRequestExperienceModeChange?($0) }
                    )
                ) {
                    ForEach(AppExperienceMode.allCases) { mode in
                        Text(mode.title(l)).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings-experience-mode-picker")
            }
            .foregroundStyle(primaryText)
            .frame(minHeight: 54)

            if experienceMode == .zen, !livingSettingsHumans.isEmpty {
                HStack(spacing: 12) {
                    settingsIcon("person.crop.circle.badge.checkmark", color: Color.goTeal)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.tr(
                            zh: "本人",
                            en: "Me",
                            de: "Ich",
                            es: "Yo",
                            pt: "Eu",
                            fr: "Moi",
                            ja: "本人",
                            ko: "본인",
                            it: "Io"
                        ))
                        .font(OhanaFont.body(.semibold))
                        Text(l.tr(
                            zh: "打开 App 时自动为此人打卡",
                            en: "Checked in automatically when Ohana opens",
                            de: "Wird beim Öffnen von Ohana automatisch eingecheckt",
                            es: "Se registra automáticamente al abrir Ohana",
                            pt: "Check-in automático ao abrir o Ohana",
                            fr: "Pointage automatique à l’ouverture d’Ohana",
                            ja: "Ohanaを開くと自動でチェックイン",
                            ko: "Ohana를 열면 자동으로 체크인",
                            it: "Check-in automatico all’apertura di Ohana"
                        ))
                        .font(OhanaFont.caption2(.semibold))
                        .foregroundStyle(tertiaryText)
                    }
                    Spacer(minLength: 8)
                    Picker(
                        l.tr(
                            zh: "选择本人",
                            en: "Choose me",
                            de: "Eigene Person wählen",
                            es: "Elegirme",
                            pt: "Escolher-me",
                            fr: "Me choisir",
                            ja: "本人を選択",
                            ko: "본인 선택",
                            it: "Scegli me"
                        ),
                        selection: zenOwnerSelectionBinding
                    ) {
                        ForEach(livingSettingsHumans) { human in
                            Text(human.displayName(fallback: l.tr(
                                zh: "未命名成员",
                                en: "Unnamed person",
                                de: "Unbenannte Person",
                                es: "Persona sin nombre",
                                pt: "Pessoa sem nome",
                                fr: "Personne sans nom",
                                ja: "名前のない家族",
                                ko: "이름 없는 가족",
                                it: "Persona senza nome"
                            )))
                            .tag(human.id.uuidString)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("settings-zen-owner-picker")
                }
                .foregroundStyle(primaryText)
                .frame(minHeight: 54)
            }
        }
    }

    private var livingSettingsHumans: [SettingsHumanSnapshot] {
        (homeHumans ?? []).filter { !$0.hasPassedAway }
    }

    private var zenOwnerSelectionBinding: Binding<String> {
        Binding(
            get: { zenOwnerHumanID },
            set: { rawID in
                guard let id = UUID(uuidString: rawID) else { return }
                onRequestZenOwnerChange?(id)
            }
        )
    }

    var settingsPersonalSection: some View {
        settingsSection(title: "Ohana Personal") {
            settingsRow(
                icon: appServices.commerce.hasPersonalEntitlement ? "checkmark.seal.fill" : "sparkles",
                title: "Ohana Personal",
                subtitle: personalSettingsSubtitle,
                iconColor: appServices.commerce.hasPersonalEntitlement ? Color.goPrimary : Color.goOrange
            ) {
                showingPersonalPlan = true
            }
            .accessibilityIdentifier("settings-personal-plan-action")
        }
    }

    private var personalSettingsSubtitle: String {
        let commerce = appServices.commerce
        if commerce.hasPersonalEntitlement {
            if commerce.hasLegacySupporterPackEntitlement || commerce.activePersonalPurchaseChoices.contains(.lifetime) {
                return l.tr(
                    zh: "Personal Lifetime · 已启用",
                    en: "Personal Lifetime · Active",
                    de: "Personal Lifetime · Aktiv"
                )
            }
            if commerce.activePersonalPurchaseChoices.contains(.yearly) {
                return l.tr(
                    zh: "Personal 年度方案 · 已启用",
                    en: "Personal Yearly · Active",
                    de: "Personal jährlich · Aktiv"
                )
            }
            if commerce.activePersonalPurchaseChoices.contains(.monthly) {
                return l.tr(
                    zh: "Personal 月度方案 · 已启用",
                    en: "Personal Monthly · Active",
                    de: "Personal monatlich · Aktiv"
                )
            }
            return l.tr(zh: "已启用", en: "Active", de: "Aktiv")
        }

        if let yearlyPrice = commerce.displayPrice(for: .yearly) {
            guard commerce.isEligibleForIntroOffer(for: .yearly) else {
                return l.tr(
                    zh: "Personal 年度方案 · \(yearlyPrice)／年",
                    en: "Personal Yearly · \(yearlyPrice)/year",
                    de: "Personal jährlich · \(yearlyPrice)/Jahr",
                    es: "Personal anual · \(yearlyPrice)/año",
                    pt: "Personal anual · \(yearlyPrice)/ano",
                    fr: "Personal annuel · \(yearlyPrice)/an",
                    ja: "Personal 年額 · \(yearlyPrice)/年",
                    ko: "Personal 연간 · \(yearlyPrice)/년",
                    it: "Personal annuale · \(yearlyPrice)/anno"
                )
            }
            return l.tr(
                zh: "符合条件可试用 14 天 · \(yearlyPrice)／年",
                en: "Eligible: 14-day trial · \(yearlyPrice)/year",
                de: "Für Berechtigte: 14 Tage testen · \(yearlyPrice)/Jahr",
                es: "Si cumples los requisitos: 14 días gratis · \(yearlyPrice)/año",
                pt: "Se elegível: 14 dias grátis · \(yearlyPrice)/ano",
                fr: "Si éligible : 14 jours gratuits · \(yearlyPrice)/an",
                ja: "対象者は14日間無料 · \(yearlyPrice)/年",
                ko: "대상자는 14일 무료 체험 · \(yearlyPrice)/년",
                it: "Se idoneo: 14 giorni gratis · \(yearlyPrice)/anno"
            )
        }
        if let lifetimePrice = commerce.displayPrice(for: .lifetime) {
            return l.tr(
                zh: "月度、年度或 \(lifetimePrice) Lifetime",
                en: "Monthly, yearly, or \(lifetimePrice) Lifetime",
                de: "Monatlich, jährlich oder \(lifetimePrice) Lifetime",
                es: "Mensual, anual o Lifetime por \(lifetimePrice)",
                pt: "Mensal, anual ou Lifetime por \(lifetimePrice)",
                fr: "Mensuel, annuel ou Lifetime à \(lifetimePrice)",
                ja: "月額、年額、またはLifetime（\(lifetimePrice)）",
                ko: "월간, 연간 또는 Lifetime \(lifetimePrice)",
                it: "Mensile, annuale o Lifetime a \(lifetimePrice)"
            )
        }
        return l.tr(
            zh: "月度、年度或 Lifetime",
            en: "Monthly, yearly, or Lifetime",
            de: "Monatlich, jährlich oder Lifetime"
        )
    }

    @ViewBuilder
    var settingsDeferredHeavySections: some View {
        if SettingsDebugTools.isVisible {
            settingsDebugSection
        }
        if OnlineFeatureGate.allows(.onlineCollaboration) {
            householdSyncSection
        }
    }
}

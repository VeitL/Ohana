//
//  SettingsView+MainSections.swift
//  Ohana
//

import SwiftUI

extension SettingsView {
    @ViewBuilder
    var settingsBodySections: some View {
        settingsExperienceSection
        if SettingsDebugTools.isRunningUITests {
            settingsUITestShortcutSection
        }
        settingsDataSections
        settingsDeferredHeavySections
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
            SettingsExperienceModeSelector(
                selection: experienceMode,
                l: l,
                onSelect: { mode in
                    guard mode != experienceMode else { return }
                    onRequestExperienceModeChange?(mode)
                }
            )

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

private struct SettingsExperienceModeSelector: View {
    let selection: AppExperienceMode
    let l: L10n
    let onSelect: (AppExperienceMode) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(l.tr(
                zh: "选择 Ohana 的使用方式；资料、椰子与 Oasis 都会原样保留。",
                en: "Choose how Ohana feels. Your records, coconuts, and Oasis stay unchanged.",
                de: "Wähle, wie sich Ohana anfühlt. Daten, Kokosnüsse und Oasis bleiben unverändert.",
                es: "Elige cómo usar Ohana. Tus datos, cocos y Oasis no cambian.",
                pt: "Escolha como usar o Ohana. Seus dados, cocos e Oasis não mudam.",
                fr: "Choisissez votre façon d’utiliser Ohana. Vos données, cocos et Oasis restent intacts.",
                ja: "Ohanaの使い方を選べます。記録、ココナッツ、Oasisはそのままです。",
                ko: "Ohana 사용 방식을 선택하세요. 기록, 코코넛과 Oasis는 그대로 유지됩니다.",
                it: "Scegli come usare Ohana. Dati, cocco e Oasis restano invariati."
            ))
            .font(OhanaFont.footnote(.semibold))
            .foregroundStyle(Color.ohanaSecondaryText)
            .fixedSize(horizontal: false, vertical: true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) { modeButtons }
                } else {
                    HStack(alignment: .top, spacing: 10) { modeButtons }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var modeButtons: some View {
        ForEach(AppExperienceMode.allCases) { mode in
            modeButton(mode)
        }
    }

    private func modeButton(_ mode: AppExperienceMode) -> some View {
        let isSelected = selection == mode
        let icon = mode == .zen ? "leaf.fill" : "square.grid.2x2.fill"

        return Button {
            onSelect(mode)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.goPrimary)
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Color.goPrimary : Color.goPrimary.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    Spacer(minLength: 6)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(OhanaFont.adaptive(size: 18, weight: .bold))
                        .foregroundStyle(isSelected ? Color.goPrimary : Color.ohanaTertiaryText)
                        .accessibilityHidden(true)
                }

                Text(mode.title(l))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)

                Text(mode.subtitle(l))
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
            .padding(14)
            .background(
                isSelected ? Color.goPrimary.opacity(0.10) : Color.ohanaControlFill.opacity(0.72),
                in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                    .strokeBorder(isSelected ? Color.goPrimary : Color.ohanaDivider, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(mode.title(l))
        .accessibilityValue(isSelected
            ? l.tr(zh: "已选择", en: "Selected", de: "Ausgewählt", es: "Seleccionado", pt: "Selecionado", fr: "Sélectionné", ja: "選択中", ko: "선택됨", it: "Selezionato")
            : l.tr(zh: "未选择", en: "Not selected", de: "Nicht ausgewählt", es: "No seleccionado", pt: "Não selecionado", fr: "Non sélectionné", ja: "未選択", ko: "선택 안 됨", it: "Non selezionato"))
        .accessibilityHint(mode.subtitle(l))
        .accessibilityIdentifier("settings-experience-mode-\(mode.rawValue)")
    }
}

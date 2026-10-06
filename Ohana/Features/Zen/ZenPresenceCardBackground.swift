//
//  ZenPresenceCardBackground.swift
//  Ohana
//
//  Fixed status palettes and the finite pending-glass dissolve used by Zen cards.
//

import SwiftUI

nonisolated enum ZenPresenceScorePalette {
    static func hex(for score: Int) -> String {
        switch min(max(score, 1), 10) {
        case 1: "B9565D"
        case 2: "C96858"
        case 3: "D47B4D"
        case 4: "D8944A"
        case 5: "C0A452"
        case 6: "91A95F"
        case 7: "68A674"
        case 8: "43A079"
        case 9: "238F71"
        default: "087C68"
        }
    }
}

extension ZenPresencePresentation.CardBackgroundState {
    nonisolated var themeColorHex: String {
        switch self {
        case .pending: "64748B"
        case .checked: "64748B"
        case let .score(value): ZenPresenceScorePalette.hex(for: value)
        }
    }

    @MainActor
    var accentColor: Color {
        Color(hex: themeColorHex)
    }
}

extension ZenPresenceScoreBand {
    @MainActor
    var zenColor: Color {
        let representativeScore = (scoreRange.lowerBound + scoreRange.upperBound) / 2
        return Color(hex: ZenPresenceScorePalette.hex(for: representativeScore))
    }
}

enum ZenPresenceCardTransition {
    static let cleanupDelayMilliseconds: UInt64 = 840
}

extension ZenPresenceSubjectDTO {
    var zenFallbackEmoji: String {
        let savedEmoji = avatarEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard savedEmoji.isEmpty else { return savedEmoji }
        return switch kind {
        case .human: "👤"
        case .pet: "🐾"
        case .plant: "🌱"
        }
    }

    var zenStatusBadgeTone: FocusCardStatusBadgeTone {
        guard checkedToday else { return .urgent }
        return (status?.score ?? 10) <= 4 ? .due : .ok
    }

    func zenCompactStatusText(_ localization: L10n) -> String {
        guard checkedToday else {
            if isOwner {
                return localization.tr(
                    zh: "待确认", en: "CONFIRM", de: "BESTÄTIGEN", es: "CONFIRMAR",
                    pt: "CONFIRMAR", fr: "CONFIRMER", ja: "未確認", ko: "확인 필요", it: "CONFERMA"
                )
            }
            return kind == .human
                ? localization.tr(
                    zh: "待联系", en: "CONTACT", de: "KONTAKT", es: "CONTACTAR",
                    pt: "CONTATO", fr: "CONTACT", ja: "未連絡", ko: "연락 필요", it: "CONTATTO"
                )
                : localization.tr(
                    zh: "待观察", en: "OBSERVE", de: "BEOBACHTEN", es: "OBSERVAR",
                    pt: "OBSERVAR", fr: "OBSERVER", ja: "未観察", ko: "관찰 필요", it: "OSSERVA"
                )
        }
        guard let persistedStatus = status else {
            if isOwner {
                return localization.tr(
                    zh: "已确认", en: "SAFE", de: "BESTÄTIGT", es: "CONFIRMADO",
                    pt: "CONFIRMADO", fr: "CONFIRMÉ", ja: "確認済み", ko: "확인됨", it: "CONFERMATO"
                )
            }
            return kind == .human
                ? localization.tr(
                    zh: "已联系", en: "CONTACTED", de: "KONTAKT", es: "CONTACTADO",
                    pt: "CONTATO", fr: "CONTACTÉ", ja: "連絡済み", ko: "연락함", it: "CONTATTATO"
                )
                : localization.tr(
                    zh: "已观察", en: "OBSERVED", de: "BEOBACHTET", es: "OBSERVADO",
                    pt: "OBSERVADO", fr: "OBSERVÉ", ja: "観察済み", ko: "관찰함", it: "OSSERVATO"
                )
        }
        return "\(persistedStatus.score)/10"
    }

    func zenStatusText(_ localization: L10n) -> String {
        if let persistedStatus = status {
            if kind == .pet || kind == .plant {
                return localization.tr(
                    zh: "今日观察：\(persistedStatus.title(localization))",
                    en: "Observed today: \(persistedStatus.title(localization))",
                    de: "Heute beobachtet: \(persistedStatus.title(localization))",
                    es: "Observado hoy: \(persistedStatus.title(localization))",
                    pt: "Observado hoje: \(persistedStatus.title(localization))",
                    fr: "Observé aujourd’hui : \(persistedStatus.title(localization))",
                    ja: "今日の観察：\(persistedStatus.title(localization))",
                    ko: "오늘 관찰: \(persistedStatus.title(localization))",
                    it: "Osservato oggi: \(persistedStatus.title(localization))"
                )
            }
            return localization.tr(
                zh: "今日状态：\(persistedStatus.title(localization))",
                en: "Today: \(persistedStatus.title(localization))",
                de: "Heute: \(persistedStatus.title(localization))",
                es: "Hoy: \(persistedStatus.title(localization))",
                pt: "Hoje: \(persistedStatus.title(localization))",
                fr: "Aujourd’hui : \(persistedStatus.title(localization))",
                ja: "今日：\(persistedStatus.title(localization))",
                ko: "오늘: \(persistedStatus.title(localization))",
                it: "Oggi: \(persistedStatus.title(localization))"
            )
        }
        if checkedToday {
            if isOwner {
                return localization.tr(
                    zh: "今天已平安确认 · 可添加状态",
                    en: "Safety confirmed today · Add a status",
                    de: "Heute bestätigt · Status hinzufügen",
                    es: "Confirmación de hoy hecha · Añadir estado",
                    pt: "Confirmação de hoje feita · Adicionar estado",
                    fr: "Confirmation du jour effectuée · Ajouter un état",
                    ja: "今日の無事を確認済み · 状態を追加",
                    ko: "오늘 무사 확인 완료 · 상태 추가",
                    it: "Conferma di oggi completata · Aggiungi uno stato"
                )
            }
            return kind == .human
                ? localization.tr(
                    zh: "今天已记录联系 · 可添加状态",
                    en: "Contact recorded today · Add a status",
                    de: "Kontakt heute erfasst · Status hinzufügen",
                    es: "Contacto registrado hoy · Añadir estado",
                    pt: "Contato registrado hoje · Adicionar status",
                    fr: "Contact du jour enregistré · Ajouter un état",
                    ja: "今日の連絡を記録済み · 状態を追加",
                    ko: "오늘 연락 기록 완료 · 상태 추가",
                    it: "Contatto di oggi registrato · Aggiungi uno stato"
                )
                : localization.tr(
                    zh: "今天已观察 · 可添加状态",
                    en: "Observed today · Add a status",
                    de: "Heute beobachtet · Status hinzufügen",
                    es: "Observado hoy · Añadir estado",
                    pt: "Observado hoje · Adicionar status",
                    fr: "Observé aujourd’hui · Ajouter un état",
                    ja: "今日の観察を記録済み · 状態を追加",
                    ko: "오늘 관찰 기록 완료 · 상태 추가",
                    it: "Osservazione di oggi registrata · Aggiungi uno stato"
                )
        }
        if isOwner {
            return localization.tr(
                zh: "轻点卡片确认今天平安",
                en: "Tap the card to confirm you're safe today",
                de: "Tippe auf die Karte, um dich heute zu bestätigen",
                es: "Toca la tarjeta para confirmar que estás bien hoy",
                pt: "Toque no cartão para confirmar que está bem hoje",
                fr: "Touchez la carte pour confirmer que tout va bien aujourd’hui",
                ja: "カードをタップして今日の無事を確認",
                ko: "카드를 탭해 오늘의 무사를 확인하세요",
                it: "Tocca la scheda per confermare che oggi stai bene"
            )
        }
        return kind == .human
            ? localization.tr(
                zh: "轻点记录今天已联系",
                en: "Tap to record contact today",
                de: "Tippen, um heutigen Kontakt zu erfassen",
                es: "Toca para registrar el contacto de hoy",
                pt: "Toque para registrar o contato de hoje",
                fr: "Touchez pour noter le contact du jour",
                ja: "タップして今日の連絡を記録",
                ko: "탭하여 오늘의 연락을 기록하세요",
                it: "Tocca per registrare il contatto di oggi"
            )
            : localization.tr(
                zh: "轻点记录今天的观察",
                en: "Tap to record today's observation",
                de: "Tippen, um die heutige Beobachtung zu erfassen",
                es: "Toca para registrar la observación de hoy",
                pt: "Toque para registrar a observação de hoje",
                fr: "Touchez pour noter l’observation du jour",
                ja: "タップして今日の観察を記録",
                ko: "탭하여 오늘의 관찰을 기록하세요",
                it: "Tocca per registrare l’osservazione di oggi"
            )
    }

    func zenAccessibilityLabel(_ localization: L10n) -> String {
        "\(name), \(kind.title(localization)), \(zenStatusText(localization))"
    }

    func zenBackgroundAccessibilityValue(_ localization: L10n) -> String {
        switch ZenPresencePresentation.cardBackgroundState(for: self) {
        case .pending:
            return localization.tr(
                zh: "磨砂玻璃覆盖，\(zenCompactStatusText(localization))",
                en: "Frosted glass cover, \(zenCompactStatusText(localization))",
                de: "Mattglas-Abdeckung, \(zenCompactStatusText(localization))",
                es: "Cubierta de vidrio esmerilado, \(zenCompactStatusText(localization))",
                pt: "Cobertura de vidro fosco, \(zenCompactStatusText(localization))",
                fr: "Voile en verre dépoli, \(zenCompactStatusText(localization))",
                ja: "すりガラス、\(zenCompactStatusText(localization))",
                ko: "반투명 유리, \(zenCompactStatusText(localization))",
                it: "Vetro satinato, \(zenCompactStatusText(localization))"
            )
        case .checked:
            return localization.tr(
                zh: "中性状态背景，\(zenStatusText(localization))",
                en: "Neutral status background, \(zenStatusText(localization))",
                de: "Neutraler Statushintergrund, \(zenStatusText(localization))",
                es: "Fondo de estado neutro, \(zenStatusText(localization))",
                pt: "Fundo de status neutro, \(zenStatusText(localization))",
                fr: "Fond d’état neutre, \(zenStatusText(localization))",
                ja: "ニュートラルな状態背景、\(zenStatusText(localization))",
                ko: "중립 상태 배경, \(zenStatusText(localization))",
                it: "Sfondo di stato neutro, \(zenStatusText(localization))"
            )
        case .score:
            let statusName = status?.title(localization) ?? zenCompactStatusText(localization)
            return localization.tr(
                zh: "状态背景：\(statusName)，\(zenStatusText(localization))",
                en: "Status background: \(statusName), \(zenStatusText(localization))",
                de: "Statushintergrund: \(statusName), \(zenStatusText(localization))",
                es: "Fondo de estado: \(statusName), \(zenStatusText(localization))",
                pt: "Fundo de status: \(statusName), \(zenStatusText(localization))",
                fr: "Fond d’état : \(statusName), \(zenStatusText(localization))",
                ja: "状態背景：\(statusName)、\(zenStatusText(localization))",
                ko: "상태 배경: \(statusName), \(zenStatusText(localization))",
                it: "Sfondo di stato: \(statusName), \(zenStatusText(localization))"
            )
        }
    }
}

struct ZenPresencePendingGlassOverlay: View {
    let opacity: CGFloat
    let cornerRadius: CGFloat
    let usesMaterial: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if usesMaterial {
                shape
                    .fill(.clear)
                    .glassEffect(
                        .clear
                            .tint(Color.goCardWhite.opacity(colorScheme == .dark ? 0.045 : 0.025))
                            .interactive(false),
                        in: shape
                    )
            } else {
                shape
                    .fill(solidHaze.opacity(colorScheme == .dark ? 0.48 : 0.42))
            }

            LinearGradient(
                stops: [
                    .init(color: Color.goCardWhite.opacity(colorScheme == .dark ? 0.09 : 0.13), location: 0.00),
                    .init(color: Color.goCardWhite.opacity(0.015), location: 0.42),
                    .init(color: Color.arkInk.opacity(colorScheme == .dark ? 0.045 : 0.025), location: 1.00)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.goCardWhite.opacity(colorScheme == .dark ? 0.12 : 0.20),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .blendMode(.screen)
        }
        .clipShape(shape)
        .opacity(Double(min(max(opacity, 0), 1)))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var solidHaze: Color {
        colorScheme == .dark ? Color(hex: "27322F") : Color(hex: "E4ECE9")
    }
}

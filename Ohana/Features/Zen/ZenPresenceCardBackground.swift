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
            return localization.tr(
                zh: "待打卡",
                en: "PENDING",
                de: "OFFEN",
                es: "PENDIENTE",
                pt: "PENDENTE",
                fr: "À FAIRE",
                ja: "未完了",
                ko: "미완료",
                it: "DA FARE"
            )
        }
        guard let persistedStatus = status else {
            return localization.tr(
                zh: "已打卡",
                en: "CHECKED",
                de: "ERLEDIGT",
                es: "HECHO",
                pt: "FEITO",
                fr: "FAIT",
                ja: "完了",
                ko: "완료",
                it: "FATTO"
            )
        }
        return "\(persistedStatus.score)/10"
    }

    func zenStatusText(_ localization: L10n) -> String {
        if let persistedStatus = status {
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
            return localization.tr(
                zh: "今天已打卡 · 可添加状态",
                en: "Checked in · Add a status",
                de: "Eingecheckt · Status hinzufügen",
                es: "Check-in hecho · Añadir estado",
                pt: "Check-in feito · Adicionar status",
                fr: "Check-in effectué · Ajouter un état",
                ja: "チェックイン済み · 状態を追加",
                ko: "체크인 완료 · 상태 추가",
                it: "Check-in fatto · Aggiungi uno stato"
            )
        }
        return localization.tr(
            zh: "点击卡片打卡",
            en: "Tap to check in",
            de: "Zum Einchecken tippen",
            es: "Toca para hacer check-in",
            pt: "Toque para fazer check-in",
            fr: "Touchez pour enregistrer",
            ja: "タップしてチェックイン",
            ko: "탭하여 체크인",
            it: "Tocca per il check-in"
        )
    }

    func zenAccessibilityLabel(_ localization: L10n) -> String {
        "\(name), \(kind.title(localization)), \(zenStatusText(localization))"
    }

    func zenBackgroundAccessibilityValue(_ localization: L10n) -> String {
        switch ZenPresencePresentation.cardBackgroundState(for: self) {
        case .pending:
            return localization.tr(
                zh: "磨砂玻璃覆盖，今天未打卡",
                en: "Frosted glass cover, not checked in today",
                de: "Mattglas-Abdeckung, heute nicht eingecheckt",
                es: "Cubierta de vidrio esmerilado, sin check-in hoy",
                pt: "Cobertura de vidro fosco, sem check-in hoje",
                fr: "Voile en verre dépoli, aucun check-in aujourd’hui",
                ja: "すりガラスで覆われています。今日は未チェックイン",
                ko: "반투명 유리로 덮임, 오늘 체크인하지 않음",
                it: "Copertura in vetro satinato, nessun check-in oggi"
            )
        case .checked:
            return localization.tr(
                zh: "中性状态背景，今天已打卡，未选择状态",
                en: "Neutral status background, checked in today, no status selected",
                de: "Neutraler Statushintergrund, heute eingecheckt, kein Status gewählt",
                es: "Fondo de estado neutro, check-in hecho hoy, sin estado elegido",
                pt: "Fundo de status neutro, check-in feito hoje, sem status selecionado",
                fr: "Fond d’état neutre, check-in effectué aujourd’hui, aucun état choisi",
                ja: "ニュートラルな状態背景、今日のチェックイン済み、状態未選択",
                ko: "중립 상태 배경, 오늘 체크인 완료, 상태 미선택",
                it: "Sfondo di stato neutro, check-in effettuato oggi, nessuno stato scelto"
            )
        case .score:
            let statusName = status?.title(localization) ?? zenCompactStatusText(localization)
            return localization.tr(
                zh: "状态背景：\(statusName)，今天已打卡",
                en: "Status background: \(statusName), checked in today",
                de: "Statushintergrund: \(statusName), heute eingecheckt",
                es: "Fondo de estado: \(statusName), check-in hecho hoy",
                pt: "Fundo de status: \(statusName), check-in feito hoje",
                fr: "Fond d’état : \(statusName), check-in effectué aujourd’hui",
                ja: "状態背景：\(statusName)、今日のチェックイン済み",
                ko: "상태 배경: \(statusName), 오늘 체크인 완료",
                it: "Sfondo di stato: \(statusName), check-in effettuato oggi"
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

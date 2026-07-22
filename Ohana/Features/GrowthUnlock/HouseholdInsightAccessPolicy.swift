//
//  HouseholdInsightAccessPolicy.swift
//  Ohana
//
//  One small policy composes tree progression with Personal/Family access for
//  Household Insights only. Other growth gates deliberately stay untouched.
//

import Foundation

nonisolated enum HouseholdInsightTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case weight
    case expense
    case weeklyReport
    case careAnalysis
    case reminderHealth
    case longTermReview

    var id: String { rawValue }

    var requiredStageID: GrowthUnlockStageID {
        switch self {
        case .weight, .expense:
            .dailyCare
        case .weeklyReport:
            .rewards
        case .careAnalysis, .reminderHealth:
            .advancedInsights
        case .longTermReview:
            .memoryReview
        }
    }

    var destination: FMDest {
        switch self {
        case .weight:
            .featureAggregate(.weight)
        case .expense:
            .featureAggregate(.expense)
        case .weeklyReport:
            .familyWeeklyReport
        case .careAnalysis:
            .careLedgerAnalysis
        case .reminderHealth:
            .reminderObservability
        case .longTermReview:
            .familyLongTermReview
        }
    }

    func title(language: String) -> String {
        let copy: AppLocalizedText = switch self {
        case .weight:
            AppLocalizedText(
                zh: "体重", en: "Weight", de: "Gewicht", es: "Peso",
                pt: "Peso", fr: "Poids", ja: "体重", ko: "체중", it: "Peso"
            )
        case .expense:
            AppLocalizedText(
                zh: "花费", en: "Expenses", de: "Ausgaben", es: "Gastos",
                pt: "Despesas", fr: "Dépenses", ja: "支出", ko: "지출", it: "Spese"
            )
        case .weeklyReport:
            AppLocalizedText(
                zh: "周报", en: "Weekly", de: "Woche", es: "Semanal",
                pt: "Semanal", fr: "Semaine", ja: "週間", ko: "주간", it: "Settimanale"
            )
        case .careAnalysis:
            AppLocalizedText(
                zh: "照护分析", en: "Care Analysis", de: "Pflegeanalyse", es: "Análisis de cuidados",
                pt: "Análise de cuidados", fr: "Analyse des soins", ja: "ケア分析", ko: "돌봄 분석", it: "Analisi delle cure"
            )
        case .reminderHealth:
            AppLocalizedText(
                zh: "提醒健康", en: "Reminder Health", de: "Erinnerungsstatus", es: "Estado de recordatorios",
                pt: "Estado dos lembretes", fr: "État des rappels", ja: "リマインダー状態", ko: "알림 상태", it: "Stato promemoria"
            )
        case .longTermReview:
            AppLocalizedText(
                zh: "长期回顾", en: "Long-term", de: "Langzeit", es: "Largo plazo",
                pt: "Longo prazo", fr: "Long terme", ja: "長期レビュー", ko: "장기 돌아보기", it: "Lungo termine"
            )
        }
        return copy.resolve(language)
    }

    func fullTitle(language: String) -> String {
        switch self {
        case .weeklyReport:
            return AppLocalizedText(
                zh: "家庭周报", en: "Weekly Report", de: "Wochenbericht", es: "Informe semanal",
                pt: "Relatório semanal", fr: "Rapport hebdomadaire", ja: "週間レポート", ko: "주간 보고서", it: "Rapporto settimanale"
            ).resolve(language)
        default:
            return title(language: language)
        }
    }

    static func tab(for destination: FMDest) -> HouseholdInsightTab? {
        switch destination {
        case .featureAggregate(.weight):
            .weight
        case .featureAggregate(.expense):
            .expense
        case .familyWeeklyReport:
            .weeklyReport
        case .careLedgerAnalysis:
            .careAnalysis
        case .reminderObservability:
            .reminderHealth
        case .familyLongTermReview:
            .longTermReview
        default:
            nil
        }
    }
}

nonisolated enum HouseholdInsightAccess: Equatable, Sendable {
    case available
    case availableThroughPersonal
    case locked(requiredLevel: Int)

    var isAvailable: Bool {
        switch self {
        case .available, .availableThroughPersonal:
            true
        case .locked:
            false
        }
    }

    var requiredLevel: Int? {
        if case let .locked(requiredLevel) = self { return requiredLevel }
        return nil
    }
}

@MainActor
enum HouseholdInsightAccessPolicy {
    static func includesUngatedSafetySummary(for tab: HouseholdInsightTab) -> Bool {
        tab == .reminderHealth
    }

    static func containerAccess(
        currentLevel: Int,
        plan: OhanaPlanLevel
    ) -> HouseholdInsightAccess {
        access(requiredStageID: .dailyCare, currentLevel: currentLevel, plan: plan)
    }

    static func access(
        for tab: HouseholdInsightTab,
        currentLevel: Int,
        plan: OhanaPlanLevel
    ) -> HouseholdInsightAccess {
        access(requiredStageID: tab.requiredStageID, currentLevel: currentLevel, plan: plan)
    }

    static func access(
        for destination: FMDest,
        currentLevel: Int,
        plan: OhanaPlanLevel
    ) -> HouseholdInsightAccess? {
        guard let tab = HouseholdInsightTab.tab(for: destination) else { return nil }
        return access(for: tab, currentLevel: currentLevel, plan: plan)
    }

    private static func access(
        requiredStageID: GrowthUnlockStageID,
        currentLevel: Int,
        plan: OhanaPlanLevel
    ) -> HouseholdInsightAccess {
        let requiredLevel = GrowthUnlockPolicy
            .status(for: requiredStageID, currentLevel: currentLevel)
            .step.requiredLevel
        if currentLevel >= requiredLevel {
            return .available
        }
        if plan.hasPersonal {
            return .availableThroughPersonal
        }
        return .locked(requiredLevel: requiredLevel)
    }
}

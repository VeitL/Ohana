import SwiftUI

struct HouseholdInsightLockedCard: View {
    let tab: HouseholdInsightTab
    let currentLevel: Int
    let appLanguage: String
    let onShowPersonal: () -> Void

    private var l: L10n { L10n(appLanguage) }

    private var requiredLevel: Int {
        GrowthUnlockPolicy
            .status(for: tab.requiredStageID, currentLevel: currentLevel)
            .step.requiredLevel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tab.icon)
                    .font(OhanaFont.adaptive(size: 20, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.goPrimary.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(tab.title(l: l))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "椰子树 Lv.\(requiredLevel) 解锁",
                        en: "Unlocks at Coconut Tree Lv.\(requiredLevel)",
                        de: "Wird bei Kokosbaum Lv.\(requiredLevel) freigeschaltet"
                    ))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer(minLength: 0)
            }

            Text(tab.lockedExplanation(l: l))
                .font(OhanaFont.body(.medium))
                .foregroundStyle(Color.ohanaSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { actions }
                VStack(spacing: 10) { actions }
            }
        }
        .padding(18)
        .goTranslucentCard(cornerRadius: OhanaRadius.cardSoft)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("household-insight-locked-\(tab.rawValue)")
    }

    @ViewBuilder
    private var actions: some View {
        Label(
            l.tr(zh: "当前 Lv.\(currentLevel)", en: "Current Lv.\(currentLevel)", de: "Aktuell Lv.\(currentLevel)"),
            systemImage: "tree.fill"
        )
        .font(OhanaFont.callout(.black))
        .foregroundStyle(Color.ohanaSecondaryText)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.ohanaControlFill, in: Capsule())

        Button(action: onShowPersonal) {
            Label(
                l.tr(zh: "用 Personal 立即解锁", en: "Unlock with Personal", de: "Mit Personal freischalten"),
                systemImage: "sparkles"
            )
            .font(OhanaFont.callout(.black))
            .foregroundStyle(Color.arkInk)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.goPrimary, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

private extension HouseholdInsightTab {
    func title(l: L10n) -> String {
        fullTitle(language: l.languageCode)
    }

    var icon: String {
        switch self {
        case .weight: "scalemass.fill"
        case .expense: "creditcard.fill"
        case .weeklyReport: "chart.bar.doc.horizontal"
        case .careAnalysis: "list.bullet.rectangle.portrait.fill"
        case .reminderHealth: "bell.badge.fill"
        case .longTermReview: "book.closed.fill"
        }
    }

    func lockedExplanation(l: L10n) -> String {
        switch self {
        case .weeklyReport:
            l.tr(
                zh: "继续记录照护，Lv.6 会自动整理标准家庭周报。Personal 可提前查看。",
                en: "Keep logging care. Lv.6 automatically organizes the standard household weekly report. Personal opens it earlier.",
                de: "Pflege weiter erfassen. Ab Lv.6 entsteht der Standard-Wochenbericht automatisch; Personal öffnet ihn früher."
            )
        case .careAnalysis:
            l.tr(
                zh: "Lv.8 开放跨事件的深度照护分析。Personal 可提前查看。",
                en: "Lv.8 opens deeper analysis across care events. Personal opens it earlier.",
                de: "Ab Lv.8 werden tiefe Analysen über Pflegeereignisse hinweg geöffnet; Personal öffnet sie früher."
            )
        case .reminderHealth:
            l.tr(
                zh: "权限、失败和逾期等安全状态始终显示；完整调度诊断在 Lv.8 或 Personal 开放。",
                en: "Permission, failed, and overdue safety states always remain visible. Full scheduling diagnostics open at Lv.8 or with Personal.",
                de: "Berechtigungs-, Fehler- und Überfälligkeitsstatus bleiben sichtbar. Die vollständige Diagnose öffnet ab Lv.8 oder mit Personal."
            )
        case .longTermReview:
            l.tr(
                zh: "Lv.9 按月份整理长期照护与回忆。Personal 可提前使用长周期统计和导出。",
                en: "Lv.9 organizes long-term care and memories by month. Personal opens long-range statistics and export earlier.",
                de: "Ab Lv.9 werden langfristige Pflege und Erinnerungen monatlich geordnet; Personal öffnet Langzeitstatistiken und Export früher."
            )
        case .weight, .expense:
            l.tr(
                zh: "体重和花费在 Lv.1 开放。原始记录不会因等级或套餐被隐藏。",
                en: "Weight and Expenses open at Lv.1. Raw records are never hidden by level or plan.",
                de: "Gewicht und Ausgaben öffnen ab Lv.1. Rohdaten werden nie durch Stufe oder Tarif verborgen."
            )
        }
    }
}

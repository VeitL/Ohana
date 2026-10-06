import SwiftUI

struct HumanNoteTimelineFilters: View {
    @Binding var timeRange: HumanNoteTimeRange
    @Binding var attachmentsOnly: Bool
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(selection: $timeRange) {
                ForEach(HumanNoteTimeRange.allCases) { range in
                    Text(title(range)).tag(range)
                }
            } label: {
                Text(l.tr(
                    zh: "时间范围", en: "Time range", de: "Zeitraum",
                    es: "Periodo", pt: "Período", fr: "Période",
                    ja: "期間", ko: "기간", it: "Periodo"
                ))
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("human-note-time-range")

            Toggle(isOn: $attachmentsOnly) {
                Text(l.tr(
                    zh: "仅显示带附件的备注", en: "Only notes with attachments", de: "Nur Notizen mit Anhängen",
                    es: "Solo notas con archivos adjuntos", pt: "Apenas notas com anexos", fr: "Notes avec pièces jointes uniquement",
                    ja: "添付があるメモのみ", ko: "첨부 파일이 있는 메모만", it: "Solo note con allegati"
                ))
                .font(OhanaFont.callout(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            }
            .tint(Color.goPrimary)
            .frame(minHeight: 44)
            .accessibilityIdentifier("human-note-attachments-filter")
        }
        .foregroundStyle(Color.ohanaPrimaryText)
    }

    private func title(_ range: HumanNoteTimeRange) -> String {
        switch range {
        case .all:
            l.tr(
                zh: "全部时间", en: "All time", de: "Gesamter Zeitraum",
                es: "Todo el historial", pt: "Todo o histórico", fr: "Toute la période",
                ja: "すべての期間", ko: "전체 기간", it: "Tutto lo storico"
            )
        case .last7Days:
            l.tr(
                zh: "近 7 天", en: "Last 7 days", de: "Letzte 7 Tage",
                es: "Últimos 7 días", pt: "Últimos 7 dias", fr: "7 derniers jours",
                ja: "過去7日間", ko: "최근 7일", it: "Ultimi 7 giorni"
            )
        case .last30Days:
            l.tr(
                zh: "近 30 天", en: "Last 30 days", de: "Letzte 30 Tage",
                es: "Últimos 30 días", pt: "Últimos 30 dias", fr: "30 derniers jours",
                ja: "過去30日間", ko: "최근 30일", it: "Ultimi 30 giorni"
            )
        }
    }
}

struct HumanNoteTimelineNoResults: View {
    let resetFilters: () -> Void
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        ContentUnavailableView {
            Label(l.tr(
                zh: "没有符合条件的备注", en: "No matching notes", de: "Keine passenden Notizen",
                es: "No hay notas coincidentes", pt: "Nenhuma nota encontrada", fr: "Aucune note correspondante",
                ja: "一致するメモがありません", ko: "일치하는 메모 없음", it: "Nessuna nota corrispondente"
            ), systemImage: "magnifyingglass")
        } description: {
            Text(l.tr(
                zh: "试试其他关键词，或放宽筛选条件。", en: "Try another keyword or broaden the filters.",
                de: "Versuche ein anderes Suchwort oder weniger Filter.", es: "Prueba otra palabra o amplía los filtros.",
                pt: "Tente outra palavra ou amplie os filtros.", fr: "Essayez un autre mot ou élargissez les filtres.",
                ja: "別のキーワードを試すか、絞り込み条件を緩めてください。", ko: "다른 검색어를 입력하거나 필터 조건을 넓혀 주세요.",
                it: "Prova un’altra parola o amplia i filtri."
            ))
        } actions: {
            Button(action: resetFilters) {
                Text(l.tr(
                    zh: "重置筛选", en: "Reset filters", de: "Filter zurücksetzen",
                    es: "Restablecer filtros", pt: "Redefinir filtros", fr: "Réinitialiser les filtres",
                    ja: "絞り込みをリセット", ko: "필터 초기화", it: "Reimposta filtri"
                ))
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("human-note-reset-filters")
        }
    }
}

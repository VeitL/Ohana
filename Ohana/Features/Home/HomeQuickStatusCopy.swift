import Foundation

/// Localized, compact presentation only; quick-action completion still comes from its ledger projection.
nonisolated struct HomeQuickStatusCopy {
    let l: L10n

    init(_ localization: L10n) { l = localization }

    var needsSetup: String {
        l.tr(
            zh: "待设置", en: "Set up", de: "Einrichten",
            es: "Configurar", pt: "Configurar", fr: "À configurer",
            ja: "未設定", ko: "설정 필요", it: "Da configurare"
        )
    }

    var countOnly: String {
        l.tr(
            zh: "只记录次数", en: "Count only", de: "Nur Anzahl",
            es: "Solo recuento", pt: "Só contagem", fr: "Nombre uniquement",
            ja: "回数のみ", ko: "횟수만 기록", it: "Solo conteggio"
        )
    }

    var noWalkToday: String { PetCareExperienceCopy(l: l).noRecordToday }

    var noPlayToday: String { PetCareExperienceCopy(l: l).noRecordToday }

    var recentConcern: String {
        l.tr(
            zh: "最近异常", en: "Recent concern", de: "Zuletzt auffällig",
            es: "Incidencia reciente", pt: "Alteração recente", fr: "Anomalie récente",
            ja: "最近の異常", ko: "최근 이상 기록", it: "Anomalia recente"
        )
    }

    var doneToday: String {
        l.tr(
            zh: "今日已完成", en: "Done today", de: "Heute erledigt",
            es: "Hecho hoy", pt: "Feito hoje", fr: "Fait aujourd’hui",
            ja: "今日は完了", ko: "오늘 완료", it: "Fatto oggi"
        )
    }

    var playPlanned: String {
        l.tr(
            zh: "计划待陪", en: "Play planned", de: "Spielzeit geplant",
            es: "Juego pendiente", pt: "Brincadeira planejada", fr: "Jeu prévu",
            ja: "遊びの予定あり", ko: "놀이 예정", it: "Gioco previsto"
        )
    }

    var holdToManage: String {
        l.tr(
            zh: "长按管理", en: "Hold to manage", de: "Zum Verwalten halten",
            es: "Mantén para gestionar", pt: "Segure para gerenciar", fr: "Maintenir pour gérer",
            ja: "長押しで管理", ko: "길게 눌러 관리", it: "Tieni premuto per gestire"
        )
    }

    func manualMeals(_ count: Int) -> String {
        l.tr(
            zh: "手动 \(count)餐", en: "Manual · \(count)", de: "Manuell · \(count)",
            es: "Manual · \(count)", pt: "Manual · \(count)", fr: "Manuel · \(count)",
            ja: "手動 \(count)回", ko: "수동 \(count)회", it: "Manuale · \(count)"
        )
    }

    func missedMeals(_ count: Int) -> String {
        l.tr(
            zh: "未打卡 \(count)餐", en: "Not logged · \(count)", de: "Nicht erfasst · \(count)",
            es: "Sin registrar · \(count)", pt: "Não registrado · \(count)", fr: "Non noté · \(count)",
            ja: "未記録 \(count)回", ko: "미기록 \(count)회", it: "Non registrato · \(count)"
        )
    }

    func automaticCount(_ count: Int) -> String {
        l.tr(
            zh: "自动 \(count)次", en: "Automatic · \(count)", de: "Automatisch · \(count)",
            es: "Automático · \(count)", pt: "Automático · \(count)", fr: "Automatique · \(count)",
            ja: "自動 \(count)回", ko: "자동 \(count)회", it: "Automatico · \(count)"
        )
    }

    func pendingCount(_ count: Int) -> String {
        l.tr(
            zh: "待补 \(count)次", en: "Pending · \(count)", de: "Offen · \(count)",
            es: "Pendiente · \(count)", pt: "Pendente · \(count)", fr: "En attente · \(count)",
            ja: "未完了 \(count)回", ko: "남은 횟수 \(count)회", it: "Da fare · \(count)"
        )
    }

    func todayCount(_ count: Int) -> String {
        l.tr(
            zh: "今日 \(count)次", en: "Today · \(count)", de: "Heute · \(count)",
            es: "Hoy · \(count)", pt: "Hoje · \(count)", fr: "Aujourd’hui · \(count)",
            ja: "今日 \(count)回", ko: "오늘 \(count)회", it: "Oggi · \(count)"
        )
    }

    func playCount(_ count: Int) -> String {
        l.tr(
            zh: "今日陪玩 \(count)次", en: "Play today · \(count)", de: "Spielzeit heute · \(count)",
            es: "Juego hoy · \(count)", pt: "Brincadeira hoje · \(count)", fr: "Jeu aujourd’hui · \(count)",
            ja: "今日の遊び \(count)回", ko: "오늘 놀이 \(count)회", it: "Gioco oggi · \(count)"
        )
    }

    func plan(_ progress: String) -> String {
        l.tr(
            zh: "计划 \(progress)", en: "Plan \(progress)", de: "Plan \(progress)",
            es: "Plan \(progress)", pt: "Plano \(progress)", fr: "Programme \(progress)",
            ja: "予定 \(progress)", ko: "계획 \(progress)", it: "Piano \(progress)"
        )
    }

    func todayProgress(_ progress: String) -> String {
        l.tr(
            zh: "今日 \(progress)", en: "Today \(progress)", de: "Heute \(progress)",
            es: "Hoy \(progress)", pt: "Hoje \(progress)", fr: "Aujourd’hui \(progress)",
            ja: "今日 \(progress)", ko: "오늘 \(progress)", it: "Oggi \(progress)"
        )
    }

    func medicationCount(_ count: Int) -> String {
        l.tr(
            zh: "\(count)种药", en: "Medications · \(count)", de: "Medikamente · \(count)",
            es: "Medicamentos · \(count)", pt: "Medicamentos · \(count)", fr: "Médicaments · \(count)",
            ja: "薬 \(count)種類", ko: "약 \(count)종", it: "Farmaci · \(count)"
        )
    }

    func thisMonth(_ amount: String) -> String {
        l.tr(
            zh: "本月 \(amount)", en: "This month \(amount)", de: "Diesen Monat \(amount)",
            es: "Este mes \(amount)", pt: "Este mês \(amount)", fr: "Ce mois-ci \(amount)",
            ja: "今月 \(amount)", ko: "이번 달 \(amount)", it: "Questo mese \(amount)"
        )
    }

    func daysAgo(_ days: Int) -> String {
        l.tr(
            zh: "\(days)天前", en: "\(days)d ago", de: "Vor \(days) T.",
            es: "Hace \(days) d", pt: "Há \(days) d", fr: "Il y a \(days) j",
            ja: "\(days)日前", ko: "\(days)일 전", it: "\(days) g fa"
        )
    }

    func filterCare(daysAgo days: Int) -> String {
        let age = days == 0 ? doneToday : daysAgo(days)
        return l.tr(zh: "滤芯 · \(age)", en: "Filter · \(age)", de: "Filter · \(age)", es: "Filtro · \(age)", pt: "Filtro · \(age)", fr: "Filtre · \(age)", ja: "フィルター · \(age)", ko: "필터 · \(age)", it: "Filtro · \(age)")
    }

    func waterCare(daysAgo days: Int) -> String {
        let age = days == 0 ? doneToday : daysAgo(days)
        return l.tr(zh: "换水 · \(age)", en: "Water change · \(age)", de: "Wasserwechsel · \(age)", es: "Cambio de agua · \(age)", pt: "Troca de água · \(age)", fr: "Changement d’eau · \(age)", ja: "水換え · \(age)", ko: "물 교체 · \(age)", it: "Cambio acqua · \(age)")
    }
}

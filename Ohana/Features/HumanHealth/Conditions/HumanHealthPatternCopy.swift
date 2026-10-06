import Foundation

enum HumanHealthPatternCopy {
    case title, introduction, interval, sameDay, medication, chooseMedication, noMedication
    case noObservations, recordToday, hairShedding, allergySymptoms, quickStart, severityGuide
    case timeline, comparison, insufficient, incomplete, boundary, method, methodDetail, history, date, severity
    case taken, skipped, mixed, unknown

    static func recordSymptoms(_ l: L10n) -> String {
            l.tr(zh: "脱发／过敏", en: "Hair / allergy", de: "Haare / Allergie", es: "Cabello / alergia", pt: "Cabelo / alergia", fr: "Cheveux / allergie", ja: "抜け毛・アレルギー", ko: "탈모 / 알레르기", it: "Capelli / allergia")
    }

    static func symptomDetail(_ l: L10n) -> String {
            l.tr(zh: "记录脱发、过敏等每日程度，再查看用药后的变化。", en: "Log daily hair shedding, allergies or other symptoms, then compare changes after medication.", de: "Haarausfall, Allergien oder andere Symptome täglich erfassen und Veränderungen nach Medikamenten vergleichen.", es: "Registra a diario la caída del cabello, alergias u otros síntomas y compara cambios tras la medicación.", pt: "Registre diariamente queda de cabelo, alergias ou outros sintomas e compare mudanças após a medicação.", fr: "Notez chaque jour la chute de cheveux, les allergies ou d’autres symptômes, puis comparez les évolutions après les prises.", ja: "抜け毛やアレルギーなどの日々の程度を記録し、服薬後の変化を確認します。", ko: "탈모, 알레르기 등 매일의 증상 정도를 기록하고 복약 이후 변화를 비교하세요.", it: "Registra ogni giorno caduta dei capelli, allergie o altri sintomi e confronta le variazioni dopo i farmaci.")
    }

    func text(_ l: L10n) -> String {
        switch self {
        case .title:
            l.tr(zh: "用药与变化", en: "Medication & changes", de: "Medikamente & Veränderungen", es: "Medicación y cambios", pt: "Medicação e mudanças", fr: "Médicaments et évolutions", ja: "服薬と変化", ko: "복약과 변화", it: "Farmaci e variazioni")
        case .introduction:
            l.tr(zh: "把用药记录与之后的状态放在一起看。", en: "See medication records alongside later symptoms.", de: "Medikamenteneinträge mit späteren Symptomen vergleichen.", es: "Compara la medicación registrada con síntomas posteriores.", pt: "Veja os registros de medicação junto aos sintomas posteriores.", fr: "Comparez les prises enregistrées aux symptômes ultérieurs.", ja: "服薬記録と、その後の症状を並べて確認します。", ko: "복약 기록과 이후 증상을 함께 살펴보세요.", it: "Confronta le assunzioni registrate con i sintomi successivi.")
        case .interval:
            l.tr(zh: "观察间隔", en: "Time between records", de: "Abstand zwischen Einträgen", es: "Intervalo entre registros", pt: "Intervalo entre registros", fr: "Intervalle entre les entrées", ja: "記録間の間隔", ko: "기록 간 간격", it: "Intervallo tra registrazioni")
        case .sameDay:
            l.tr(zh: "当天", en: "Same day", de: "Am selben Tag", es: "Mismo día", pt: "Mesmo dia", fr: "Le même jour", ja: "同じ日", ko: "같은 날", it: "Stesso giorno")
        case .medication:
            l.tr(zh: "查看哪种药物", en: "Medication to compare", de: "Medikament zum Vergleichen", es: "Medicación a comparar", pt: "Medicação a comparar", fr: "Médicament à comparer", ja: "比較する薬", ko: "비교할 약", it: "Farmaco da confrontare")
        case .chooseMedication:
            l.tr(zh: "选择药物", en: "Choose medication", de: "Medikament auswählen", es: "Elegir medicación", pt: "Escolher medicação", fr: "Choisir un médicament", ja: "薬を選択", ko: "약 선택", it: "Scegli farmaco")
        case .noMedication:
            l.tr(zh: "先在今日用药中添加药物，并如实记录服用情况。", en: "Add a medication in Medication today and record doses as they happen.", de: "Füge unter Medikamente heute ein Medikament hinzu und erfasse die Einnahmen.", es: "Añade una medicación en Medicación de hoy y registra las tomas.", pt: "Adicione uma medicação em Medicação de hoje e registre as doses.", fr: "Ajoutez un médicament dans Médicaments du jour et consignez les prises.", ja: "今日の服薬で薬を追加し、実際の服薬状況を記録してください。", ko: "오늘 복약에서 약을 추가하고 실제 복약 상태를 기록하세요.", it: "Aggiungi un farmaco in Farmaci di oggi e registra le assunzioni.")
        case .noObservations:
            l.tr(zh: "先记录今天的程度，之后再回来查看变化。", en: "Record today's severity, then return to see changes over time.", de: "Erfasse die heutige Stärke und sieh später den Verlauf an.", es: "Registra la intensidad de hoy y vuelve para ver los cambios.", pt: "Registre a intensidade de hoje e volte para ver as mudanças.", fr: "Notez l’intensité d’aujourd’hui, puis revenez voir son évolution.", ja: "まず今日の程度を記録すると、後から変化を確認できます。", ko: "오늘의 정도를 기록하고 나중에 변화를 확인하세요.", it: "Registra l’intensità di oggi e torna per vedere le variazioni.")
        case .recordToday:
            l.tr(zh: "记录今天", en: "Record today", de: "Heute erfassen", es: "Registrar hoy", pt: "Registrar hoje", fr: "Noter aujourd’hui", ja: "今日を記録", ko: "오늘 기록", it: "Registra oggi")
        case .hairShedding:
            l.tr(zh: "脱发情况", en: "Hair shedding", de: "Haarausfall", es: "Caída del cabello", pt: "Queda de cabelo", fr: "Chute de cheveux", ja: "抜け毛", ko: "탈모 상태", it: "Caduta dei capelli")
        case .allergySymptoms:
            l.tr(zh: "过敏症状", en: "Allergy symptoms", de: "Allergiesymptome", es: "Síntomas de alergia", pt: "Sintomas de alergia", fr: "Symptômes allergiques", ja: "アレルギー症状", ko: "알레르기 증상", it: "Sintomi allergici")
        case .quickStart:
            l.tr(zh: "快速开始", en: "Quick start", de: "Schnellstart", es: "Inicio rápido", pt: "Início rápido", fr: "Démarrage rapide", ja: "かんたん設定", ko: "빠른 시작", it: "Inizio rapido")
        case .severityGuide:
            l.tr(zh: "按你自己的同一标准记录：0 表示没有，10 表示程度最高。不必数头发。", en: "Use the same personal scale: 0 means none, 10 means the most. No need to count hairs.", de: "Nutze immer deine eigene Skala: 0 bedeutet kein, 10 stärkster Ausfall. Haare zählen ist nicht nötig.", es: "Usa siempre tu misma escala: 0 es nada, 10 es el máximo. No hace falta contar cabellos.", pt: "Use sempre a mesma escala pessoal: 0 é nada, 10 é o máximo. Não precisa contar fios.", fr: "Gardez la même échelle personnelle : 0 signifie aucune chute, 10 le maximum. Inutile de compter les cheveux.", ja: "同じ自分の基準で、なしを0、最も多い状態を10として記録します。本数を数える必要はありません。", ko: "같은 개인 기준으로 기록하세요. 없음은 0, 가장 많음은 10입니다. 머리카락 수를 셀 필요는 없습니다.", it: "Usa sempre la stessa scala personale: 0 significa nessuna, 10 il massimo. Non serve contare i capelli.")
        case .timeline:
            l.tr(zh: "近 90 天的程度", en: "Severity over 90 days", de: "Stärke in 90 Tagen", es: "Intensidad en 90 días", pt: "Intensidade em 90 dias", fr: "Intensité sur 90 jours", ja: "90日間の程度", ko: "90일간의 정도", it: "Intensità in 90 giorni")
        case .date:
            l.tr(zh: "日期", en: "Date", de: "Datum", es: "Fecha", pt: "Data", fr: "Date", ja: "日付", ko: "날짜", it: "Data")
        case .severity:
            l.tr(zh: "自评程度", en: "Self-rated severity", de: "Selbst eingeschätzte Stärke", es: "Intensidad autoevaluada", pt: "Intensidade autoavaliada", fr: "Intensité autoévaluée", ja: "自己評価の程度", ko: "자가 평가 정도", it: "Intensità autovalutata")
        case .comparison:
            l.tr(zh: "记录日均值对照", en: "Recorded-day averages", de: "Mittelwerte erfasster Tage", es: "Promedios de días registrados", pt: "Médias dos dias registrados", fr: "Moyennes des jours renseignés", ja: "記録日の平均比較", ko: "기록일 평균 비교", it: "Medie dei giorni registrati")
        case .insufficient:
            l.tr(zh: "目前只展示记录。两类各有至少 5 个配对记录日后，才显示均值对照。无需为了比较改变用药。", en: "Showing records only. Averages need at least 5 paired days in each group. Do not change medication to create a comparison.", de: "Nur Einträge sichtbar. Mittelwerte benötigen je 5 zugeordnete Tage. Ändere Medikamente nicht für einen Vergleich.", es: "Solo se muestran registros. Las medias requieren 5 días emparejados por grupo. No cambies la medicación para comparar.", pt: "Apenas registros são exibidos. As médias precisam de 5 dias pareados por grupo. Não altere a medicação para comparar.", fr: "Seules les entrées sont affichées. Il faut 5 jours appariés par groupe pour les moyennes. Ne modifiez pas vos prises pour comparer.", ja: "現在は記録のみ表示します。平均には各群5日以上の対応する記録が必要です。比較のために服薬を変えないでください。", ko: "현재는 기록만 표시합니다. 평균 비교에는 각 그룹에 연결된 기록일 5일 이상이 필요합니다. 비교를 위해 복약을 바꾸지 마세요.", it: "Sono mostrati solo i dati. Servono 5 giorni abbinati per gruppo per le medie. Non modificare i farmaci per confrontarli.")
        case .incomplete:
            l.tr(zh: "记录未完整载入，暂不显示均值对照。原始历史仍保留。", en: "Records are incomplete here; averages are hidden. Original history is retained.", de: "Einträge sind unvollständig; Mittelwerte bleiben verborgen. Der Verlauf bleibt erhalten.", es: "Los registros están incompletos; se ocultan los promedios. El historial se conserva.", pt: "Os registros estão incompletos; as médias estão ocultas. O histórico permanece.", fr: "Les entrées sont incomplètes ; les moyennes sont masquées. L’historique est conservé.", ja: "記録の読み込みが不完全なため平均は表示しません。元の履歴は保持されています。", ko: "기록이 완전히 로드되지 않아 평균을 숨겼습니다. 원래 기록은 유지됩니다.", it: "I dati sono incompleti; le medie sono nascoste. La cronologia è conservata.")
        case .boundary:
            l.tr(zh: "时间上的对应不代表药物造成或改善了症状。", en: "Timing alone cannot show that a medication caused or improved symptoms.", de: "Zeitliche Nähe beweist nicht, dass ein Medikament Symptome verursacht oder verbessert.", es: "La coincidencia temporal no demuestra que un medicamento causó o mejoró los síntomas.", pt: "A relação temporal não prova que um medicamento causou ou melhorou os sintomas.", fr: "La concordance temporelle ne prouve pas qu’un médicament cause ou améliore les symptômes.", ja: "時期の一致だけでは、薬が症状の原因や改善につながったとは判断できません。", ko: "시점이 일치한다고 약이 증상을 유발하거나 개선했다고 판단할 수는 없습니다.", it: "La coincidenza temporale non dimostra che un farmaco abbia causato o migliorato i sintomi.")
        case .method:
            l.tr(zh: "如何看这张图", en: "How to read this", de: "So liest du die Ansicht", es: "Cómo leer esto", pt: "Como ler", fr: "Comment lire ces données", ja: "見方", ko: "읽는 방법", it: "Come leggere i dati")
        case .methodDetail:
            l.tr(zh: "每点是一天自评的平均值；空白不是 0。用药按记录对应的计划日期对齐，补录时间不会移动日期。已服、跳过都有记录的日子单独标示；漏记或待处理为未知。当天对照不判断先后顺序，跳过记录不证明当天完全没有服药。间隔由你选择，不代表医学上的起效时间；压力、疾病、其他药物等也可能影响结果。", en: "Each point averages one day's ratings; gaps are not zero. Doses use their scheduled dates, not the time of back-entry. Mixed taken/skipped days are separate; missing or pending logs are unknown. Same-day views do not establish sequence, and a skip does not prove no medication was taken that day. The interval is your viewing choice, not a medical onset time. Stress, illness and other medications may also matter.", de: "Jeder Punkt mittelt einen Tag; Lücken sind keine Null. Es zählt das geplante Dosendatum, nicht der Nachtrag. Gemischte Tage stehen separat; fehlende oder offene Einträge sind unbekannt. Gleicher Tag beweist keine Reihenfolge; Überspringen beweist keinen einnahmefreien Tag. Der Abstand ist eine Ansichtsoption, keine medizinische Wirkzeit. Stress, Krankheit und andere Medikamente können mitwirken.", es: "Cada punto promedia un día; los huecos no son cero. Se usa la fecha prevista de la dosis, no la del registro tardío. Los días mixtos van separados; faltantes o pendientes son desconocidos. Mismo día no establece orden; omitir no prueba un día sin medicación. El intervalo es visual, no un tiempo médico de efecto. Estrés, enfermedad y otros fármacos pueden influir.", pt: "Cada ponto é a média do dia; lacunas não são zero. Vale a data prevista da dose, não a do registro tardio. Dias mistos ficam separados; registros ausentes ou pendentes são desconhecidos. Mesmo dia não define ordem; pular não prova um dia sem medicação. O intervalo é visual, não um prazo médico de efeito. Estresse, doenças e outros remédios podem influir.", fr: "Chaque point est la moyenne d’un jour ; un vide n’est pas un zéro. La date prévue de prise est utilisée, pas celle de la saisie tardive. Les jours mixtes sont séparés ; les entrées absentes ou en attente sont inconnues. Un même jour n’établit pas l’ordre ; une prise sautée ne prouve pas une journée sans médicament. L’intervalle est un choix de lecture, pas un délai médical. Stress, maladies et autres médicaments peuvent intervenir.", ja: "各点は1日の評価平均で、空白は0ではありません。後日入力した時刻ではなく予定された服薬日で対応させます。服用とスキップの混在日は別表示、未記録や保留は不明です。同日比較は前後関係を示さず、スキップだけでその日まったく服薬しなかったとは判断できません。間隔は表示の選択で、医学的な作用時間ではありません。ストレス、病気、他の薬も影響し得ます。", ko: "각 점은 하루 평가의 평균이며 빈칸은 0이 아닙니다. 나중에 입력한 시각이 아닌 예정된 복약 날짜로 연결합니다. 복용과 건너뜀이 섞인 날은 별도 표시하고 누락이나 대기는 알 수 없음입니다. 같은 날 비교는 선후 관계를 뜻하지 않으며 건너뜀만으로 하루 종일 미복용했다고 볼 수 없습니다. 간격은 보기 설정이지 의학적 작용 시간이 아닙니다. 스트레스, 질병, 다른 약도 영향을 줄 수 있습니다.", it: "Ogni punto è la media giornaliera; i vuoti non sono zero. Si usa la data prevista della dose, non quella di inserimento tardivo. I giorni misti sono separati; dati mancanti o in attesa sono ignoti. Lo stesso giorno non stabilisce l’ordine; una dose saltata non prova un giorno senza farmaci. L’intervallo è una scelta visiva, non un tempo medico d’azione. Stress, malattie e altri farmaci possono influire.")
        case .history:
            l.tr(zh: "逐日查看", en: "Review each day", de: "Tage einzeln ansehen", es: "Ver cada día", pt: "Ver cada dia", fr: "Voir chaque jour", ja: "日ごとに確認", ko: "날짜별 보기", it: "Esamina ogni giorno")
        case .taken, .skipped, .mixed, .unknown:
            doseStateText(l)
        }
    }

    private func doseStateText(_ l: L10n) -> String {
        switch self {
        case .taken:
            l.tr(zh: "标记已服", en: "Marked taken", de: "Als genommen markiert", es: "Marcada tomada", pt: "Marcada como tomada", fr: "Noté pris", ja: "服用と記録", ko: "복용으로 기록", it: "Segnata assunta")
        case .skipped:
            l.tr(zh: "标记跳过", en: "Marked skipped", de: "Als übersprungen markiert", es: "Marcada omitida", pt: "Marcada como pulada", fr: "Noté sauté", ja: "スキップと記録", ko: "건너뜀으로 기록", it: "Segnata saltata")
        case .mixed:
            l.tr(zh: "已服和跳过", en: "Taken and skipped", de: "Genommen und übersprungen", es: "Tomada y omitida", pt: "Tomada e pulada", fr: "Pris et sauté", ja: "服用とスキップ", ko: "복용 및 건너뜀", it: "Assunta e saltata")
        case .unknown:
            l.tr(zh: "用药未知", en: "Medication unknown", de: "Einnahme unbekannt", es: "Medicación desconocida", pt: "Medicação desconhecida", fr: "Prise inconnue", ja: "服薬不明", ko: "복약 여부 불명", it: "Assunzione ignota")
        default: ""
        }
    }

    static func daysLater(_ days: Int, l: L10n) -> String {
        days == 0 ? HumanHealthPatternCopy.sameDay.text(l) : l.tr(zh: "\(days) 天后", en: "\(days) days later", de: "\(days) Tage später", es: "\(days) días después", pt: "\(days) dias depois", fr: "\(days) jours après", ja: "\(days)日後", ko: "\(days)일 후", it: "\(days) giorni dopo")
    }

    static func coverage(_ paired: Int, total: Int, l: L10n) -> String {
        l.tr(zh: "\(total) 个状态记录日 · \(paired) 天可配对", en: "\(total) symptom days · \(paired) paired days", de: "\(total) Symptomtage · \(paired) zugeordnet", es: "\(total) días de síntomas · \(paired) emparejados", pt: "\(total) dias de sintomas · \(paired) pareados", fr: "\(total) jours de symptômes · \(paired) appariés", ja: "症状記録\(total)日・対応\(paired)日", ko: "증상 기록 \(total)일 · 연결 \(paired)일", it: "\(total) giorni di sintomi · \(paired) abbinati")
    }

    static func mean(_ value: Double, days: Int, l: L10n) -> String {
        let number = value.formatted(.number.precision(.fractionLength(1)).locale(AppLanguage.effectiveLocale))
        return l.tr(zh: "\(number)/10 · \(days) 天", en: "\(number)/10 · \(days) days", de: "\(number)/10 · \(days) Tage", es: "\(number)/10 · \(days) días", pt: "\(number)/10 · \(days) dias", fr: "\(number)/10 · \(days) jours", ja: "\(number)/10・\(days)日", ko: "\(number)/10 · \(days)일", it: "\(number)/10 · \(days) giorni")
    }
}

extension HumanHealthMedicationDayState {
    func title(_ l: L10n) -> String {
        switch self {
        case .taken: HumanHealthPatternCopy.taken.text(l)
        case .skipped: HumanHealthPatternCopy.skipped.text(l)
        case .mixed: HumanHealthPatternCopy.mixed.text(l)
        case .unknown: HumanHealthPatternCopy.unknown.text(l)
        }
    }
}

//
//  PersonalUpgradePrompt.swift
//  Ohana
//
//  Presentation value passed from quota-enforcing domain commands to the
//  Personal comparison screen. It contains no persistence or entitlement
//  decisions of its own.
//

import Foundation

nonisolated enum PersonalUpgradeReason: Equatable, Hashable, Sendable {
    case quota(PersonalLimitedResource)
    case feature(PersonalFeature)
}

nonisolated struct PersonalUpgradePrompt: Identifiable, Equatable, Sendable {
    let reason: PersonalUpgradeReason
    let currentCount: Int?
    let attemptedCount: Int?
    let limit: Int?
    let preservesGrandfatheredData: Bool

    var id: PersonalUpgradeReason { reason }

    init(denial: PersonalFreeLimitDenial) {
        reason = .quota(denial.resource)
        currentCount = denial.currentCount
        attemptedCount = denial.attemptedCount
        limit = denial.limit
        preservesGrandfatheredData = denial.preservesGrandfatheredData
    }

    /// Use for a proactive premium affordance when there is no denied command
    /// to supply exact usage counts.
    init(resource: PersonalLimitedResource) {
        reason = .quota(resource)
        currentCount = nil
        attemptedCount = nil
        limit = PersonalFreeLimits.current.limit(for: resource)
        preservesGrandfatheredData = false
    }

    init(feature: PersonalFeature) {
        reason = .feature(feature)
        currentCount = nil
        attemptedCount = nil
        limit = nil
        preservesGrandfatheredData = false
    }

    func title(_ l: L10n) -> String {
        switch reason {
        case let .quota(resource):
            quotaTitle(resource, l: l)
        case let .feature(feature):
            featureTitle(feature, l: l)
        }
    }

    private func quotaTitle(_ resource: PersonalLimitedResource, l: L10n) -> String {
        switch resource {
        case .activePet:
            l.tr(
                zh: "添加另一只宠物",
                en: "Add another pet",
                de: "Weiteres Tier hinzufügen",
                es: "Añadir otra mascota",
                pt: "Adicionar outro animal",
                fr: "Ajouter un autre animal",
                ja: "別のペットを追加",
                ko: "다른 반려동물 추가",
                it: "Aggiungi un altro animale"
            )
        case .activeHuman:
            l.tr(
                zh: "添加更多 Human",
                en: "Add more Humans",
                de: "Weitere Menschen hinzufügen",
                es: "Añadir más Human",
                pt: "Adicionar mais Human",
                fr: "Ajouter d’autres Human",
                ja: "Humanをさらに追加",
                ko: "Human 더 추가",
                it: "Aggiungi altri Human"
            )
        case .activePlant:
            l.tr(
                zh: "添加更多活跃植物",
                en: "Add more active plants",
                de: "Weitere aktive Pflanzen hinzufügen",
                es: "Añadir más plantas activas",
                pt: "Adicionar mais plantas ativas",
                fr: "Ajouter d’autres plantes actives",
                ja: "アクティブな植物をさらに追加",
                ko: "활성 식물 더 추가",
                it: "Aggiungi altre piante attive"
            )
        case .ordinaryActivePlan:
            l.tr(
                zh: "创建更多普通计划",
                en: "Create more everyday plans",
                de: "Weitere Alltagspläne erstellen",
                es: "Crear más planes cotidianos",
                pt: "Criar mais planos do dia a dia",
                fr: "Créer plus de plans courants",
                ja: "通常プランをさらに作成",
                ko: "일반 플랜 더 만들기",
                it: "Crea altri piani quotidiani"
            )
        }
    }

    private func featureTitle(_ feature: PersonalFeature, l: L10n) -> String {
        switch feature {
        case .extendedTrends:
            l.tr(
                zh: "查看更长期趋势",
                en: "See longer-term trends",
                de: "Längerfristige Trends ansehen",
                es: "Ver tendencias a más largo plazo",
                pt: "Ver tendências de prazo mais longo",
                fr: "Voir les tendances à plus long terme",
                ja: "より長期の傾向を見る",
                ko: "더 장기적인 추세 보기",
                it: "Visualizza tendenze a più lungo termine"
            )
        case .vetSummaryPDF:
            l.tr(
                zh: "生成兽医 PDF 摘要",
                en: "Create a vet PDF summary",
                de: "Tierarzt-PDF erstellen",
                es: "Crear un resumen veterinario en PDF",
                pt: "Criar um resumo veterinário em PDF",
                fr: "Créer un résumé vétérinaire en PDF",
                ja: "獣医向けPDF要約を作成",
                ko: "수의사용 PDF 요약 만들기",
                it: "Crea un riepilogo veterinario in PDF"
            )
        case .supporterAppearance:
            l.tr(
                zh: "使用 Personal 外观",
                en: "Use Personal appearances",
                de: "Personal-Designs verwenden",
                es: "Usar estilos de Ohana Personal",
                pt: "Usar visuais do Ohana Personal",
                fr: "Utiliser les styles Ohana Personal",
                ja: "Ohana Personalの外観を使用",
                ko: "Ohana Personal 디자인 사용",
                it: "Usa gli stili di Ohana Personal"
            )
        case .presenceLongRangeAnalytics,
             .presenceCrossSubjectComparison,
             .presenceDataExport:
            l.tr(
                zh: "解锁佛系趋势与分析",
                en: "Unlock Zen trends and insights",
                de: "Zen-Trends und Analysen freischalten",
                es: "Desbloquea tendencias y análisis zen",
                pt: "Desbloqueie tendências e análises zen",
                fr: "Débloquez les tendances et analyses Zen",
                ja: "佛系トレンドと分析を解放",
                ko: "마음 편한 트렌드와 분석 잠금 해제",
                it: "Sblocca tendenze e analisi Zen"
            )
        case .presenceAdvancedReminders:
            l.tr(
                zh: "解锁高级打卡提醒",
                en: "Unlock advanced check-in reminders",
                de: "Erweiterte Check-in-Erinnerungen",
                es: "Desbloquea recordatorios de check-in avanzados",
                pt: "Desbloqueie lembretes avançados de check-in",
                fr: "Débloquez les rappels de check-in avancés",
                ja: "高度なチェックイン通知を解放",
                ko: "고급 체크인 알림 잠금 해제",
                it: "Sblocca i promemoria di check-in avanzati"
            )
        case .presenceEditableMessageTemplate:
            l.tr(
                zh: "自定义联系文案",
                en: "Customize the contact message",
                de: "Kontaktnachricht anpassen",
                es: "Personaliza el mensaje de contacto",
                pt: "Personalize a mensagem de contato",
                fr: "Personnalisez le message de contact",
                ja: "連絡メッセージをカスタマイズ",
                ko: "연락 메시지 사용자 지정",
                it: "Personalizza il messaggio di contatto"
            )
        case .documentScanning:
            l.tr(
                zh: "扫描并整理文档",
                en: "Scan and organize documents",
                de: "Dokumente scannen und ordnen",
                es: "Escanea y organiza documentos",
                pt: "Digitalize e organize documentos",
                fr: "Numérisez et organisez des documents",
                ja: "書類をスキャンして整理",
                ko: "문서를 스캔하고 정리",
                it: "Scansiona e organizza documenti"
            )
        case .systemWidgets:
            l.tr(
                zh: "在桌面查看今日照护",
                en: "See today’s care on your Home Screen",
                de: "Heutige Pflege auf dem Home-Bildschirm",
                es: "Consulta el cuidado de hoy en la pantalla de inicio",
                pt: "Veja os cuidados de hoje na tela de Início",
                fr: "Consultez les soins du jour sur l’écran d’accueil",
                ja: "ホーム画面で今日のケアを確認",
                ko: "홈 화면에서 오늘의 돌봄 확인",
                it: "Consulta le cure di oggi nella schermata Home"
            )
        }
    }

    func detail(_ l: L10n) -> String {
        if case let .feature(feature) = reason {
            return featureDescription(feature, l: l)
        }

        return freeLimitDescription(l)
    }

    private func freeLimitDescription(_ l: L10n) -> String {
        guard case let .quota(resource) = reason, let limit else { return "" }
        return switch resource {
        case .activePet:
            l.tr(
                zh: "Free 可保留 \(limit) 只活跃宠物；Ohana Personal 不限数量。",
                en: "Free includes \(limit) active pet; Ohana Personal removes the limit.",
                de: "Free umfasst \(limit) aktives Tier; Ohana Personal hebt das Limit auf.",
                es: "Free incluye \(limit) mascota activa; Ohana Personal elimina el límite.",
                pt: "Free inclui \(limit) animal ativo; Ohana Personal remove o limite.",
                fr: "Free inclut \(limit) animal actif ; Ohana Personal supprime la limite.",
                ja: "Freeではアクティブなペットは\(limit)匹まで。Ohana Personalでは無制限です。",
                ko: "Free에서는 활성 반려동물을 \(limit)마리까지 이용할 수 있으며, Ohana Personal은 제한이 없습니다.",
                it: "Free include \(limit) animale attivo; Ohana Personal elimina il limite."
            )
        case .activeHuman:
            l.tr(
                zh: "Free 可保留 \(limit) 位活跃 Human；Ohana Personal 不限数量。",
                en: "Free includes \(limit) active Humans; Ohana Personal removes the limit.",
                de: "Free umfasst \(limit) aktive Menschen; Ohana Personal hebt das Limit auf.",
                es: "Free incluye \(limit) Human activos; Ohana Personal elimina el límite.",
                pt: "Free inclui \(limit) Human ativos; Ohana Personal remove o limite.",
                fr: "Free inclut \(limit) Human actifs ; Ohana Personal supprime la limite.",
                ja: "FreeではアクティブなHumanは\(limit)人まで。Ohana Personalでは無制限です。",
                ko: "Free에서는 활성 Human을 \(limit)명까지 이용할 수 있으며, Ohana Personal은 제한이 없습니다.",
                it: "Free include \(limit) Human attivi; Ohana Personal elimina il limite."
            )
        case .activePlant:
            l.tr(
                zh: "Free 可保留 \(limit) 株活跃植物；Ohana Personal 不限数量。",
                en: "Free includes \(limit) active plants; Ohana Personal removes the limit.",
                de: "Free umfasst \(limit) aktive Pflanzen; Ohana Personal hebt das Limit auf.",
                es: "Free incluye \(limit) plantas activas; Ohana Personal elimina el límite.",
                pt: "Free inclui \(limit) plantas ativas; Ohana Personal remove o limite.",
                fr: "Free inclut \(limit) plantes actives ; Ohana Personal supprime la limite.",
                ja: "Freeではアクティブな植物は\(limit)株まで。Ohana Personalでは無制限です。",
                ko: "Free에서는 활성 식물을 \(limit)개까지 이용할 수 있으며, Ohana Personal은 제한이 없습니다.",
                it: "Free include \(limit) piante attive; Ohana Personal elimina il limite."
            )
        case .ordinaryActivePlan:
            l.tr(
                zh: "Free 可保留 \(limit) 个普通活跃计划；健康关键提醒不计入限制。",
                en: "Free includes \(limit) active everyday plans; health-critical reminders never count toward the limit.",
                de: "Free umfasst \(limit) aktive Alltagspläne; gesundheitlich wichtige Erinnerungen zählen nie zum Limit.",
                es: "Free incluye \(limit) planes cotidianos activos; los recordatorios críticos de salud no cuentan para el límite.",
                pt: "Free inclui \(limit) planos ativos do dia a dia; lembretes críticos de saúde não contam para o limite.",
                fr: "Free inclut \(limit) plans courants actifs ; les rappels de santé essentiels ne comptent pas dans la limite.",
                ja: "Freeでは通常のアクティブなプランは\(limit)件まで。健康上重要なリマインダーは上限に含まれません。",
                ko: "Free에서는 일반 활성 플랜을 \(limit)개까지 이용할 수 있으며, 건강상 중요한 미리 알림은 제한에 포함되지 않습니다.",
                it: "Free include \(limit) piani quotidiani attivi; i promemoria sanitari essenziali non contano ai fini del limite."
            )
        }
    }

    private func featureDescription(_ feature: PersonalFeature, l: L10n) -> String {
        switch feature {
        case .extendedTrends:
            l.tr(
                zh: "Free 提供最近 30 天的基础趋势；Ohana Personal 解锁 90 天与全部时间分析。现有记录始终可用。",
                en: "Free includes basic trends for the last 30 days. Ohana Personal unlocks 90-day and all-time analysis. Existing records always remain available.",
                de: "Free enthält Basistrends der letzten 30 Tage. Ohana Personal schaltet 90-Tage- und Gesamtanalysen frei. Vorhandene Einträge bleiben immer verfügbar.",
                es: "Free incluye tendencias básicas de los últimos 30 días. Ohana Personal desbloquea análisis de 90 días y de todo el historial. Los registros existentes siguen siempre disponibles.",
                pt: "Free inclui tendências básicas dos últimos 30 dias. Ohana Personal libera análises de 90 dias e de todo o histórico. Os registros existentes continuam sempre disponíveis.",
                fr: "Free inclut les tendances de base des 30 derniers jours. Ohana Personal débloque les analyses sur 90 jours et sur tout l’historique. Les données existantes restent toujours disponibles.",
                ja: "Freeでは直近30日間の基本的な傾向を確認できます。Ohana Personalでは90日間と全期間の分析を利用できます。既存の記録は常に利用できます。",
                ko: "Free에서는 최근 30일의 기본 추세를 볼 수 있습니다. Ohana Personal에서는 90일 및 전체 기간 분석을 이용할 수 있습니다. 기존 기록은 항상 이용할 수 있습니다.",
                it: "Free include le tendenze di base degli ultimi 30 giorni. Ohana Personal sblocca analisi a 90 giorni e dell’intero storico. I dati esistenti restano sempre disponibili."
            )
        case .vetSummaryPDF:
            l.tr(
                zh: "Ohana Personal 可从本地记录生成兽医 PDF 摘要；原始记录与手动导出始终可用。",
                en: "Ohana Personal creates vet PDF summaries from local records. Raw records and manual export always remain available.",
                de: "Ohana Personal erstellt Tierarzt-PDFs aus lokalen Einträgen. Rohdaten und manueller Export bleiben immer verfügbar.",
                es: "Ohana Personal crea resúmenes veterinarios en PDF a partir de registros locales. Los registros originales y la exportación manual siguen siempre disponibles.",
                pt: "Ohana Personal cria resumos veterinários em PDF a partir de registros locais. Os registros originais e a exportação manual continuam sempre disponíveis.",
                fr: "Ohana Personal crée des résumés vétérinaires en PDF à partir des données locales. Les données brutes et l’export manuel restent toujours disponibles.",
                ja: "Ohana Personalではローカルの記録から獣医向けPDF要約を作成できます。元の記録と手動エクスポートは常に利用できます。",
                ko: "Ohana Personal은 로컬 기록으로 수의사용 PDF 요약을 만들 수 있습니다. 원본 기록과 수동 내보내기는 항상 이용할 수 있습니다.",
                it: "Ohana Personal crea riepiloghi veterinari in PDF dai dati locali. I dati originali e l’esportazione manuale restano sempre disponibili."
            )
        case .supporterAppearance:
            l.tr(
                zh: "Ohana Personal 解锁全部 Founding Supporter 外观权益。",
                en: "Ohana Personal unlocks every Founding Supporter appearance extra.",
                de: "Ohana Personal schaltet alle Founding-Supporter-Designextras frei.",
                es: "Ohana Personal desbloquea todos los extras visuales de Founding Supporter.",
                pt: "Ohana Personal libera todos os extras visuais de Founding Supporter.",
                fr: "Ohana Personal débloque tous les extras visuels Founding Supporter.",
                ja: "Ohana PersonalではFounding Supporterのすべての外観特典を利用できます。",
                ko: "Ohana Personal은 Founding Supporter의 모든 디자인 혜택을 잠금 해제합니다.",
                it: "Ohana Personal sblocca tutti gli extra estetici Founding Supporter."
            )
        case .presenceLongRangeAnalytics, .presenceCrossSubjectComparison, .presenceDataExport:
            l.tr(
                zh: "Free 永久保留全部原始打卡月历；Ohana Personal 增加 90 天、1 年与全部时间趋势、跨对象比较和导出。",
                en: "Free keeps every raw check-in month. Ohana Personal adds 90-day, one-year and all-time trends, comparison, and export.",
                de: "Free behält alle Check-in-Monate. Personal ergänzt 90 Tage, ein Jahr, Gesamttrends, Vergleich und Export.",
                es: "Free conserva todos los meses de check-in. Ohana Personal añade tendencias de 90 días, un año y todo el historial, comparaciones y exportación.",
                pt: "O Free mantém todos os meses de check-in. O Ohana Personal adiciona tendências de 90 dias, um ano e todo o histórico, comparações e exportação.",
                fr: "Free conserve tous les mois de check-in. Ohana Personal ajoute les tendances sur 90 jours, un an et toute la période, les comparaisons et l’export.",
                ja: "Freeではすべての月のチェックイン記録を保持します。Ohana Personalでは90日、1年、全期間のトレンド、比較、書き出しを利用できます。",
                ko: "Free는 모든 월별 체크인 기록을 보관합니다. Ohana Personal은 90일, 1년, 전체 기간 추세와 비교 및 내보내기를 제공합니다.",
                it: "Free conserva tutti i mesi di check-in. Ohana Personal aggiunge tendenze a 90 giorni, un anno e per tutto il periodo, confronti ed esportazione."
            )
        case .presenceAdvancedReminders:
            l.tr(
                zh: "Free 提供一个每日提醒；Personal 增加按星期设置、15–180 分钟宽限和第二次本机提醒。",
                en: "Free includes one daily reminder. Personal adds weekday schedules, a 15–180 minute grace period, and a second local reminder.",
                de: "Free enthält eine tägliche Erinnerung. Personal ergänzt Wochentage, 15–180 Minuten Kulanz und eine zweite lokale Erinnerung.",
                es: "Free incluye un recordatorio diario. Personal añade horarios por día de la semana, un margen de 15–180 minutos y un segundo recordatorio local.",
                pt: "O Free inclui um lembrete diário. O Personal adiciona horários por dia da semana, tolerância de 15–180 minutos e um segundo lembrete local.",
                fr: "Free inclut un rappel quotidien. Personal ajoute les jours de la semaine, un délai de 15 à 180 minutes et un second rappel local.",
                ja: "Freeでは毎日1回の通知を利用できます。Personalでは曜日設定、15〜180分の猶予、2回目の端末内通知を追加できます。",
                ko: "Free는 매일 알림 1회를 제공합니다. Personal은 요일 설정, 15~180분 유예 시간과 두 번째 기기 내 알림을 추가합니다.",
                it: "Free include un promemoria giornaliero. Personal aggiunge giorni della settimana, una tolleranza di 15–180 minuti e un secondo promemoria locale."
            )
        case .presenceEditableMessageTemplate:
            l.tr(
                zh: "Free 使用固定的克制文案；Personal 可在本机编辑文案并保存最多三位联系人。短信仍必须由你确认发送。",
                en: "Free uses a fixed, careful message. Personal lets you edit it locally and keep up to three contacts. You still confirm every text.",
                de: "Free nutzt einen festen Text. Personal erlaubt lokale Anpassung und bis zu drei Kontakte. Jede SMS bleibt bestätigungspflichtig.",
                es: "Free usa un mensaje fijo y prudente. Personal permite editarlo en el dispositivo y guardar hasta tres contactos. Tú sigues confirmando cada SMS.",
                pt: "O Free usa uma mensagem fixa e cuidadosa. O Personal permite editá-la no dispositivo e manter até três contatos. Você ainda confirma cada SMS.",
                fr: "Free utilise un message fixe et prudent. Personal permet de le modifier sur l’appareil et de conserver jusqu’à trois contacts. Vous confirmez toujours chaque SMS.",
                ja: "Freeでは固定の控えめな文面を使用します。Personalでは端末上で編集し、連絡先を3人まで保存できます。SMSの送信は毎回あなたが確認します。",
                ko: "Free는 신중한 고정 문구를 사용합니다. Personal은 기기에서 문구를 편집하고 연락처를 최대 3명까지 저장할 수 있습니다. 문자 전송은 매번 직접 확인합니다.",
                it: "Free usa un messaggio fisso e prudente. Personal permette di modificarlo sul dispositivo e conservare fino a tre contatti. Confermi comunque ogni SMS."
            )
        case .documentScanning:
            l.tr(
                zh: "Ohana Personal 可在本机扫描文档、逐项复核并保存结构化记录；原始图片和完整识别文本不会长期保存。",
                en: "Ohana Personal scans documents on device for item-by-item review and structured records. Source images and full recognized text are not retained long term.",
                de: "Ohana Personal scannt Dokumente auf dem Gerät zur Einzelprüfung und für strukturierte Einträge. Quellbilder und der vollständig erkannte Text werden nicht dauerhaft gespeichert.",
                es: "Ohana Personal escanea documentos en el dispositivo para revisarlos elemento por elemento y guardar registros estructurados. Las imágenes originales y el texto reconocido completo no se conservan a largo plazo.",
                pt: "O Ohana Personal digitaliza documentos no dispositivo para revisão item a item e registros estruturados. As imagens de origem e o texto reconhecido completo não são mantidos a longo prazo.",
                fr: "Ohana Personal numérise les documents sur l’appareil pour une vérification élément par élément et des données structurées. Les images sources et le texte reconnu intégral ne sont pas conservés à long terme.",
                ja: "Ohana Personalは端末上で書類をスキャンし、項目ごとに確認して構造化された記録として保存します。元画像と認識した全文は長期保存されません。",
                ko: "Ohana Personal은 기기에서 문서를 스캔하고 항목별로 검토해 구조화된 기록으로 저장합니다. 원본 이미지와 전체 인식 텍스트는 장기간 보관하지 않습니다.",
                it: "Ohana Personal scansiona i documenti sul dispositivo per la revisione voce per voce e il salvataggio di dati strutturati. Le immagini originali e il testo riconosciuto completo non vengono conservati a lungo termine."
            )
        case .systemWidgets:
            l.tr(
                zh: "Ohana Personal 可在主屏幕与锁屏显示精简的今日照护进度；原始记录仍只保存在你的设备上。",
                en: "Ohana Personal shows a compact daily-care summary on the Home and Lock Screens. Your original records stay on your device.",
                de: "Ohana Personal zeigt eine kompakte Pflegeübersicht auf Home- und Sperrbildschirm. Deine Originaleinträge bleiben auf deinem Gerät.",
                es: "Ohana Personal muestra un resumen compacto del cuidado diario en las pantallas de inicio y bloqueo. Tus registros originales permanecen en tu dispositivo.",
                pt: "O Ohana Personal mostra um resumo compacto dos cuidados diários nas telas de Início e Bloqueio. Seus registros originais permanecem no dispositivo.",
                fr: "Ohana Personal affiche un résumé compact des soins quotidiens sur les écrans d’accueil et verrouillé. Vos données d’origine restent sur votre appareil.",
                ja: "Ohana Personalでは、ホーム画面とロック画面に今日のケア概要を表示できます。元の記録は端末内に保存されたままです。",
                ko: "Ohana Personal은 홈 및 잠금 화면에 간결한 오늘의 돌봄 요약을 표시합니다. 원본 기록은 기기에 그대로 보관됩니다.",
                it: "Ohana Personal mostra un riepilogo compatto delle cure quotidiane nelle schermate Home e di blocco. I dati originali restano sul dispositivo."
            )
        }
    }
}

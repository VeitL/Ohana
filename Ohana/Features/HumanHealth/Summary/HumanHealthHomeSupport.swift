import SwiftUI

nonisolated enum HumanHealthQuickRecord: String, Identifiable, Sendable {
    case weight, metrics, observation, workout, report, note
    var id: String { rawValue }
}

enum HumanHealthHomeText {
    case today, quickRecords, moreRecords, recordWeight, recordMetric, recordState
    case more, profile, changes, additionalInfo, noTasks, incomplete, saved, viewRecord
    case chooseMetric, recentMetrics, searchMetrics, chooseCondition, addCondition, customize
    case loadFailed, saveFailed, previousRecord, needsCondition

    func title(_ l: L10n) -> String {
        switch self {
        case .loadFailed:
            l.tr(zh: "记录未能载入，请重试", en: "Records could not be loaded. Please retry.", de: "Einträge konnten nicht geladen werden. Bitte erneut versuchen.", es: "No se cargaron los registros. Inténtalo de nuevo.", pt: "Não foi possível carregar os registros. Tente novamente.", fr: "Les entrées n’ont pas pu être chargées. Réessayez.", ja: "記録を読み込めませんでした。再試行してください。", ko: "기록을 불러오지 못했습니다. 다시 시도하세요.", it: "Impossibile caricare le registrazioni. Riprova.")
        case .saveFailed:
            l.tr(zh: "未能保存，输入已保留。请重试。", en: "Could not save. Your input is preserved; please retry.", de: "Speichern fehlgeschlagen. Deine Eingabe bleibt erhalten; bitte erneut versuchen.", es: "No se pudo guardar. Tus datos siguen aquí; inténtalo de nuevo.", pt: "Não foi possível salvar. Seus dados continuam aqui; tente novamente.", fr: "Échec de l’enregistrement. Votre saisie est conservée ; réessayez.", ja: "保存できませんでした。入力内容は保持されています。再試行してください。", ko: "저장하지 못했습니다. 입력 내용은 유지됩니다. 다시 시도하세요.", it: "Salvataggio non riuscito. I dati inseriti sono conservati; riprova.")
        case .previousRecord:
            l.tr(zh: "上次记录", en: "Previous record", de: "Letzter Eintrag", es: "Registro anterior", pt: "Registro anterior", fr: "Entrée précédente", ja: "前回の記録", ko: "이전 기록", it: "Registrazione precedente")
        case .needsCondition:
            l.tr(zh: "先添加你想关注的健康状况，再记录自评状态。", en: "Add a condition you want to track before logging your state.", de: "Füge zuerst einen Zustand hinzu, den du beobachten möchtest.", es: "Añade una condición que quieras seguir antes de registrar tu estado.", pt: "Adicione uma condição que deseja acompanhar antes de registrar seu estado.", fr: "Ajoutez un état de santé à suivre avant de noter votre ressenti.", ja: "記録する前に、経過を見たい健康状態を追加してください。", ko: "상태를 기록하기 전에 추적할 건강 상태를 추가하세요.", it: "Aggiungi una condizione da seguire prima di registrare come stai.")
        case .today:
            l.tr(zh: "今天与接下来", en: "Today & next", de: "Heute & demnächst", es: "Hoy y después", pt: "Hoje e a seguir", fr: "Aujourd’hui et à venir", ja: "今日とこれから", ko: "오늘과 다음 일정", it: "Oggi e prossimamente")
        case .quickRecords:
            l.tr(zh: "快捷记录", en: "Quick records", de: "Schnell erfassen", es: "Registro rápido", pt: "Registro rápido", fr: "Saisie rapide", ja: "かんたん記録", ko: "빠른 기록", it: "Registrazione rapida")
        case .moreRecords:
            l.tr(zh: "更多记录", en: "More records", de: "Weitere Einträge", es: "Más registros", pt: "Mais registros", fr: "Autres saisies", ja: "その他の記録", ko: "다른 기록", it: "Altre registrazioni")
        case .recordWeight:
            l.tr(zh: "记体重", en: "Log weight", de: "Gewicht erfassen", es: "Registrar peso", pt: "Registrar peso", fr: "Noter le poids", ja: "体重を記録", ko: "체중 기록", it: "Registra peso")
        case .recordMetric:
            l.tr(zh: "记指标", en: "Log a metric", de: "Wert erfassen", es: "Registrar medición", pt: "Registrar medição", fr: "Noter une mesure", ja: "測定値を記録", ko: "측정값 기록", it: "Registra misura")
        case .recordState:
            HumanHealthPatternCopy.recordSymptoms(l)
        case .more:
            l.tr(zh: "更多", en: "More", de: "Mehr", es: "Más", pt: "Mais", fr: "Plus", ja: "その他", ko: "더 보기", it: "Altro")
        case .profile:
            l.tr(zh: "资料", en: "Profile", de: "Profil", es: "Perfil", pt: "Perfil", fr: "Profil", ja: "プロフィール", ko: "프로필", it: "Profilo")
        case .changes:
            l.tr(zh: "近期变化", en: "Recent changes", de: "Letzte Veränderungen", es: "Cambios recientes", pt: "Mudanças recentes", fr: "Évolutions récentes", ja: "最近の変化", ko: "최근 변화", it: "Variazioni recenti")
        case .additionalInfo:
            l.tr(zh: "补充信息", en: "Additional information", de: "Weitere Angaben", es: "Información adicional", pt: "Informações adicionais", fr: "Informations complémentaires", ja: "追加情報", ko: "추가 정보", it: "Altre informazioni")
        case .noTasks:
            l.tr(zh: "今天没有已设置的健康待办", en: "No health tasks scheduled today", de: "Heute keine Gesundheitsaufgaben geplant", es: "No hay tareas de salud programadas hoy", pt: "Nenhuma tarefa de saúde programada hoje", fr: "Aucune tâche de santé prévue aujourd’hui", ja: "今日設定されている健康の予定はありません", ko: "오늘 설정된 건강 일정이 없습니다", it: "Nessuna attività di salute prevista oggi")
        case .incomplete:
            l.tr(zh: "部分安排尚未载入，请打开详情查看", en: "Some schedules could not be loaded. Open details to check.", de: "Einige Pläne fehlen. Details öffnen.", es: "Algunos planes no se cargaron. Abre los detalles.", pt: "Alguns planos não foram carregados. Abra os detalhes.", fr: "Certains programmes ne sont pas chargés. Ouvrez les détails.", ja: "一部の予定を読み込めませんでした。詳細をご確認ください。", ko: "일부 일정을 불러오지 못했습니다. 상세 정보를 확인하세요.", it: "Alcuni programmi non sono caricati. Apri i dettagli.")
        case .saved:
            l.tr(zh: "已记录", en: "Recorded", de: "Erfasst", es: "Registrado", pt: "Registrado", fr: "Enregistré", ja: "記録しました", ko: "기록됨", it: "Registrato")
        case .viewRecord:
            l.tr(zh: "查看记录", en: "View record", de: "Eintrag ansehen", es: "Ver registro", pt: "Ver registro", fr: "Voir l’entrée", ja: "記録を見る", ko: "기록 보기", it: "Vedi registrazione")
        case .chooseMetric:
            l.tr(zh: "选择指标", en: "Choose a metric", de: "Wert auswählen", es: "Elegir medición", pt: "Escolher medição", fr: "Choisir une mesure", ja: "項目を選択", ko: "측정 항목 선택", it: "Scegli misura")
        case .recentMetrics:
            l.tr(zh: "最近记录", en: "Recently recorded", de: "Zuletzt erfasst", es: "Registros recientes", pt: "Registros recentes", fr: "Saisies récentes", ja: "最近の記録", ko: "최근 기록", it: "Registrazioni recenti")
        case .searchMetrics:
            l.tr(zh: "搜索名称或缩写", en: "Search name or abbreviation", de: "Name oder Kürzel suchen", es: "Buscar nombre o abreviatura", pt: "Buscar nome ou abreviação", fr: "Rechercher un nom ou une abréviation", ja: "名称や略称で検索", ko: "이름 또는 약어 검색", it: "Cerca nome o abbreviazione")
        case .chooseCondition:
            l.tr(zh: "选择健康状况", en: "Choose a condition", de: "Zustand auswählen", es: "Elegir condición", pt: "Escolher condição", fr: "Choisir un état", ja: "健康状態を選択", ko: "건강 상태 선택", it: "Scegli condizione")
        case .addCondition:
            l.tr(zh: "添加健康状况", en: "Add a condition", de: "Zustand hinzufügen", es: "Añadir condición", pt: "Adicionar condição", fr: "Ajouter un état", ja: "健康状態を追加", ko: "건강 상태 추가", it: "Aggiungi condizione")
        case .customize:
            l.tr(zh: "继续完善（可选）", en: "Customize (optional)", de: "Ergänzen (optional)", es: "Personalizar (opcional)", pt: "Personalizar (opcional)", fr: "Personnaliser (facultatif)", ja: "詳しく設定（任意）", ko: "추가 설정 (선택)", it: "Personalizza (facoltativo)")
        }
    }
}

// UI contract: existing summary rows with native controls; the parent emits domain commands.
struct HumanHealthTodaySection: View {
    let human: Human
    let snapshot: HumanHealthSummarySnapshot
    let isPending: (String) -> Bool
    let onDose: (HumanHealthSummaryDose, HumanMedicationStatus) -> Void
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(HumanHealthHomeText.today.title(l))
                .font(OhanaFont.title3(.semibold))
            if snapshot.medicationScheduleIsIncomplete || snapshot.recordCounts.reports.isTruncated {
                Text(HumanHealthHomeText.incomplete.title(l))
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .accessibilityIdentifier("human-health-summary-today-incomplete")
            }
            ForEach(snapshot.todayItems) { item in
                switch item {
                case let .dose(dose):
                    if Calendar.current.isDateInToday(dose.scheduledTime) {
                        doseRow(dose, id: item.id)
                    } else {
                        NavigationLink { HumanMedicationView(human: human, showsDoneButton: false) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dose.name).font(OhanaFont.callout(.semibold))
                                Text(dose.scheduledTime, format: .dateTime.year().month().day().hour().minute())
                                    .font(OhanaFont.caption())
                                if !dose.dosage.isEmpty { Text(dose.dosage).font(OhanaFont.caption()) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                case let .followUp(report):
                    NavigationLink { HumanHealthReportView(human: human) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l.tr(zh: "复查安排", en: "Follow-up", de: "Kontrolle"))
                                Text(report.date, format: .dateTime.year().month().day())
                                    .font(OhanaFont.caption())
                                    .foregroundStyle(Color.ohanaSecondaryText)
                            }
                        } icon: { Image(systemName: "calendar.badge.clock").accessibilityHidden(true) }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .accessibilityIdentifier("human-health-summary-today-follow-up")
                }
            }
            if snapshot.todayItems.isEmpty,
               !snapshot.medicationScheduleIsIncomplete, !snapshot.recordCounts.reports.isTruncated {
                Text(snapshot.medicationIsVisible && snapshot.bodyIsVisible
                     ? HumanHealthHomeText.noTasks.title(l)
                     : l.tr(zh: "部分健康记录仅本人可见", en: "Some health records are private", de: "Einige Gesundheitsdaten sind privat"))
                    .font(OhanaFont.callout())
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            HStack {
                NavigationLink { HumanMedicationView(human: human, showsDoneButton: false) } label: {
                    Text(l.tr(zh: "今日用药", en: "Medication today", de: "Medikamente heute"))
                }
                .accessibilityIdentifier("human-health-summary-today-medication")
                Spacer()
                NavigationLink { HumanHealthReportView(human: human) } label: {
                    Text(l.tr(zh: "报告与复查", en: "Reports & follow-ups", de: "Berichte & Kontrollen"))
                }
                .accessibilityIdentifier("human-health-summary-today-reports")
            }
            .font(OhanaFont.caption())
            .frame(minHeight: 44)
        }
        .padding(16)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        .accessibilityIdentifier("human-health-summary-today-section")
    }

    private func doseRow(_ dose: HumanHealthSummaryDose, id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dose.name).font(OhanaFont.callout(.semibold))
            HStack {
                Text(dose.scheduledTime, format: .dateTime.hour().minute())
                if !dose.dosage.isEmpty { Text(dose.dosage) }
            }
            .font(OhanaFont.caption())
            .foregroundStyle(Color.ohanaSecondaryText)
            HStack(spacing: 12) {
                if isPending(id) {
                    ProgressView().accessibilityLabel(l.tr(zh: "正在保存", en: "Saving", de: "Wird gespeichert"))
                }
                Button(l.tr(zh: "已服", en: "Taken", de: "Genommen")) { onDose(dose, .taken) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("\(dose.name) · \(dose.scheduledTime.formatted(date: .omitted, time: .shortened)) · \(l.tr(zh: "已服", en: "Taken", de: "Genommen"))")
                    .accessibilityIdentifier("human-health-home-dose-taken-\(dose.medicationID.uuidString)-\(Int(dose.scheduledTime.timeIntervalSince1970 / 60))")
                Button(l.tr(zh: "跳过", en: "Skip", de: "Überspringen")) { onDose(dose, .skipped) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("human-health-home-dose-skipped-\(dose.medicationID.uuidString)-\(Int(dose.scheduledTime.timeIntervalSince1970 / 60))")
            }
            .frame(minHeight: 44)
            .disabled(isPending(id))
        }
        .padding(.vertical, 6)
    }
}

struct HumanHealthMoreView: View {
    let human: Human
    @Binding var quickRecord: HumanHealthQuickRecord?
    @Binding var savedRecordRoute: HumanHealthSummaryRoute?
    var onOpenAchievements: (() -> Void)?
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)?
    var onOpenTasks: (() -> Void)?
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        List {
            if let savedRecordRoute {
                Section {
                    NavigationLink { destinationView(savedRecordRoute) } label: {
                        HStack {
                            Text(HumanHealthHomeText.saved.title(l))
                            Spacer()
                            Text(HumanHealthHomeText.viewRecord.title(l))
                        }
                    }
                    .accessibilityIdentifier("human-health-more-record-saved")
                }
            }
            Section(l.tr(zh: "健康记录", en: "Health records", de: "Gesundheitseinträge")) {
                ForEach(HumanHealthSummaryDestination.allCases) { destination in
                    NavigationLink { destinationView(HumanHealthSummaryRoute.feature(destination)) } label: {
                        Label(destination.title(l), systemImage: destination.systemImage)
                    }
                    .accessibilityIdentifier("human-all-feature-\(destination.rawValue)")
                }
            }
            Section(HumanHealthHomeText.moreRecords.title(l)) {
                recordButton(.workout, title: l.tr(zh: "记录运动", en: "Log workout", de: "Training erfassen"), icon: "figure.run")
                recordButton(.report, title: l.tr(zh: "手动添加报告", en: "Add report manually", de: "Bericht manuell hinzufügen"), icon: "doc.badge.plus")
                recordButton(.note, title: l.tr(zh: "添加随记", en: "Add note", de: "Notiz hinzufügen"), icon: "square.and.pencil")
            }
            Section {
                NavigationLink { destinationView(HumanHealthSummaryRoute.profile) } label: { Label(HumanHealthHomeText.profile.title(l), systemImage: "person.crop.circle") }
                NavigationLink { destinationView(HumanHealthSummaryRoute.notes) } label: { Label(l.tr(zh: "随记历史", en: "Note history", de: "Notizverlauf"), systemImage: "note.text") }
                NavigationLink { destinationView(HumanHealthSummaryRoute.expenses) } label: { Label(l.tr(zh: "宠物花费份额", en: "Pet expense share", de: "Anteil an Tierausgaben"), systemImage: "creditcard") }
                NavigationLink { destinationView(HumanHealthSummaryRoute.wishlist) } label: { Label(l.tr(zh: "愿望单", en: "Wishlist", de: "Wunschliste"), systemImage: "gift") }
                NavigationLink { destinationView(HumanHealthSummaryRoute.assets) } label: { Label(l.tr(zh: "椰子资产", en: "Coconut assets", de: "Kokosnussvermögen"), systemImage: "circle.hexagongrid") }
                if let onOpenAchievements {
                    Button(action: onOpenAchievements) { Label(l.tr(zh: "成就", en: "Achievements", de: "Erfolge"), systemImage: "medal") }
                } else {
                    NavigationLink { destinationView(HumanHealthSummaryRoute.achievements) } label: { Label(l.tr(zh: "成就", en: "Achievements", de: "Erfolge"), systemImage: "medal") }
                }
            }
        }
        .navigationTitle(HumanHealthHomeText.more.title(l))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("human-health-home-more-screen")
    }

    private func destinationView(_ route: HumanHealthSummaryRoute) -> some View {
        HumanHealthSummaryDestinationView(
            human: human, route: route, quickRecord: $quickRecord, savedRecordRoute: $savedRecordRoute,
            onOpenAchievements: onOpenAchievements, onPresentCoconutLog: onPresentCoconutLog, onOpenTasks: onOpenTasks
        )
    }

    private func recordButton(_ record: HumanHealthQuickRecord, title: String, icon: String) -> some View {
        Button { quickRecord = record } label: { Label(title, systemImage: icon) }
            .disabled(human.hasPassedAway)
            .accessibilityIdentifier("human-health-home-record-\(record.id)")
    }
}

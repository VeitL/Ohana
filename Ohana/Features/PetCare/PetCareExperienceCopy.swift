import Foundation

/// Copy shared by pet creation, quick records, and their history handoff.
nonisolated struct PetCareExperienceCopy {
    let l: L10n

    var optionalLater: String {
        l.tr(zh: "可选，之后随时补充", en: "Optional · add later", de: "Optional · später ergänzen", es: "Opcional · añadir después", pt: "Opcional · adicionar depois", fr: "Facultatif · à compléter plus tard", ja: "任意・あとから追加できます", ko: "선택 사항 · 나중에 추가", it: "Facoltativo · aggiungi dopo")
    }
    var skipPersonality: String {
        l.tr(zh: "暂不填写，下一步", en: "Skip for now · next", de: "Vorerst überspringen · weiter", es: "Omitir por ahora · siguiente", pt: "Pular por enquanto · próximo", fr: "Passer pour le moment · suivant", ja: "今は入力せず次へ", ko: "나중에 입력 · 다음", it: "Salta per ora · avanti")
    }
    var finishWithDefaultAvatar: String {
        l.tr(zh: "使用默认头像，完成", en: "Finish with default avatar", de: "Mit Standardavatar abschließen", es: "Terminar con avatar predeterminado", pt: "Concluir com avatar padrão", fr: "Terminer avec l’avatar par défaut", ja: "標準アイコンで完了", ko: "기본 아바타로 완료", it: "Completa con avatar predefinito")
    }
    var requiredName: String {
        l.tr(zh: "请填写名字", en: "Enter a name", de: "Namen eingeben", es: "Introduce un nombre", pt: "Digite um nome", fr: "Saisissez un nom", ja: "名前を入力してください", ko: "이름을 입력해 주세요", it: "Inserisci un nome")
    }
    var requiredSpeciesBreed: String {
        l.tr(zh: "请选择物种与品种", en: "Choose species and breed", de: "Art und Rasse auswählen", es: "Elige especie y raza", pt: "Escolha espécie e raça", fr: "Choisissez l’espèce et la race", ja: "動物の種類と品種を選んでください", ko: "종과 품종을 선택해 주세요", it: "Scegli specie e razza")
    }
    var requiredSex: String {
        l.tr(zh: "请选择性别", en: "Choose a sex", de: "Geschlecht auswählen", es: "Elige el sexo", pt: "Escolha o sexo", fr: "Choisissez le sexe", ja: "性別を選んでください", ko: "성별을 선택해 주세요", it: "Scegli il sesso")
    }
    var recordOnce: String {
        l.tr(zh: "记录一次", en: "Log once", de: "Einmal erfassen", es: "Registrar una vez", pt: "Registrar uma vez", fr: "Noter une fois", ja: "1回記録", ko: "한 번 기록", it: "Registra una volta")
    }
    var fillRecord: String {
        l.tr(zh: "填写记录", en: "Add a record", de: "Eintrag ausfüllen", es: "Añadir registro", pt: "Adicionar registro", fr: "Ajouter une entrée", ja: "記録を入力", ko: "기록 입력", it: "Aggiungi un record")
    }
    var startWalk: String {
        l.tr(zh: "开始遛宠", en: "Start walk", de: "Spaziergang starten", es: "Iniciar paseo", pt: "Iniciar passeio", fr: "Démarrer la promenade", ja: "散歩を開始", ko: "산책 시작", it: "Inizia passeggiata")
    }
    var viewRecord: String {
        l.tr(zh: "查看记录", en: "View record", de: "Eintrag ansehen", es: "Ver registro", pt: "Ver registro", fr: "Voir l’entrée", ja: "記録を見る", ko: "기록 보기", it: "Vedi record")
    }
    var viewHistory: String {
        l.tr(zh: "查看记录", en: "View history", de: "Verlauf ansehen", es: "Ver historial", pt: "Ver histórico", fr: "Voir l’historique", ja: "履歴を見る", ko: "기록 보기", it: "Vedi cronologia")
    }
    var recorded: String {
        l.tr(zh: "已记录", en: "Recorded", de: "Erfasst", es: "Registrado", pt: "Registrado", fr: "Noté", ja: "記録しました", ko: "기록됨", it: "Registrato")
    }
    var recordTime: String {
        l.tr(zh: "记录时间", en: "Record time", de: "Zeit des Eintrags", es: "Hora del registro", pt: "Hora do registro", fr: "Date et heure", ja: "記録日時", ko: "기록 시간", it: "Data e ora")
    }
    var note: String {
        l.tr(zh: "备注（选填）", en: "Note (optional)", de: "Notiz (optional)", es: "Nota (opcional)", pt: "Nota (opcional)", fr: "Note (facultative)", ja: "メモ（任意）", ko: "메모 (선택)", it: "Nota (facoltativa)")
    }
    var notificationsOff: String {
        l.tr(zh: "通知未开启，仍可正常记录；提醒可在待办中心查看。", en: "Notifications are off. You can still record and find reminders in Tasks.", de: "Mitteilungen sind aus. Einträge und Erinnerungen unter Aufgaben funktionieren weiterhin.", es: "Las notificaciones están desactivadas. Puedes registrar y ver recordatorios en Tareas.", pt: "Notificações desativadas. Você pode registrar e ver lembretes em Tarefas.", fr: "Les notifications sont désactivées. Vous pouvez noter et consulter les rappels dans Tâches.", ja: "通知はオフです。記録は可能で、リマインダーはタスクで確認できます。", ko: "알림이 꺼져 있습니다. 기록과 할 일의 알림 확인은 가능합니다.", it: "Le notifiche sono disattivate. Puoi registrare e vedere i promemoria in Attività.")
    }
    var saving: String {
        l.tr(zh: "正在保存", en: "Saving", de: "Wird gespeichert", es: "Guardando", pt: "Salvando", fr: "Enregistrement", ja: "保存中", ko: "저장 중", it: "Salvataggio")
    }
    var moreOptions: String {
        l.tr(zh: "时间与更多选项", en: "Time and more options", de: "Zeit und weitere Optionen", es: "Hora y más opciones", pt: "Horário e mais opções", fr: "Heure et autres options", ja: "日時とその他の設定", ko: "시간 및 추가 옵션", it: "Ora e altre opzioni")
    }
    var sharedCare: String {
        l.tr(zh: "共同照护", en: "Shared care", de: "Gemeinsame Pflege", es: "Cuidado compartido", pt: "Cuidado compartilhado", fr: "Soins partagés", ja: "一緒にお世話", ko: "함께 돌보기", it: "Cura condivisa")
    }
    var setReminder: String {
        l.tr(zh: "设置提醒", en: "Set reminder", de: "Erinnerung einrichten", es: "Crear recordatorio", pt: "Criar lembrete", fr: "Créer un rappel", ja: "リマインダーを設定", ko: "알림 설정", it: "Imposta promemoria")
    }
    var editReminder: String {
        l.tr(zh: "编辑提醒", en: "Edit reminder", de: "Erinnerung bearbeiten", es: "Editar recordatorio", pt: "Editar lembrete", fr: "Modifier le rappel", ja: "リマインダーを編集", ko: "알림 편집", it: "Modifica promemoria")
    }
    var reminderOptional: String {
        l.tr(zh: "按需要设置，不影响记录", en: "Optional · recording works without it", de: "Optional · Einträge funktionieren auch ohne", es: "Opcional · puedes registrar sin él", pt: "Opcional · você pode registrar sem ele", fr: "Facultatif · vous pouvez noter sans rappel", ja: "任意・設定しなくても記録できます", ko: "선택 사항 · 알림 없이 기록 가능", it: "Facoltativo · puoi registrare senza")
    }
    var latestMemory: String {
        l.tr(zh: "最近的回忆", en: "Latest memory", de: "Neueste Erinnerung", es: "Último recuerdo", pt: "Última memória", fr: "Dernier souvenir", ja: "最近の思い出", ko: "최근 추억", it: "Ultimo ricordo")
    }
    var addMemory: String {
        l.tr(zh: "留下一段回忆", en: "Save a memory", de: "Erinnerung festhalten", es: "Guardar un recuerdo", pt: "Guardar uma memória", fr: "Garder un souvenir", ja: "思い出を残す", ko: "추억 남기기", it: "Conserva un ricordo")
    }
    var saveFailed: String {
        l.tr(zh: "保存失败，请重试。输入已保留。", en: "Couldn’t save. Your draft is kept; try again.", de: "Speichern fehlgeschlagen. Dein Entwurf bleibt erhalten; versuche es erneut.", es: "No se pudo guardar. Tu borrador se conserva; inténtalo de nuevo.", pt: "Não foi possível salvar. O rascunho foi mantido; tente novamente.", fr: "Échec de l’enregistrement. Votre brouillon est conservé ; réessayez.", ja: "保存できませんでした。入力は保持されています。再試行してください。", ko: "저장하지 못했습니다. 입력이 유지됩니다. 다시 시도하세요.", it: "Salvataggio non riuscito. La bozza è conservata; riprova.")
    }
    var retry: String {
        l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen", es: "Reintentar", pt: "Tentar novamente", fr: "Réessayer", ja: "再試行", ko: "다시 시도", it: "Riprova")
    }
    var noRecord: String {
        l.tr(zh: "还没有记录", en: "No records yet", de: "Noch keine Einträge", es: "Aún no hay registros", pt: "Ainda sem registros", fr: "Pas encore d’entrées", ja: "まだ記録がありません", ko: "아직 기록이 없습니다", it: "Ancora nessun record")
    }
    var noRecordToday: String {
        l.tr(zh: "今天还没有记录", en: "No records today", de: "Heute noch keine Einträge", es: "Sin registros hoy", pt: "Sem registros hoje", fr: "Aucune entrée aujourd’hui", ja: "今日はまだ記録がありません", ko: "오늘 기록이 없습니다", it: "Nessun record oggi")
    }
    var recordUnavailable: String {
        l.tr(zh: "这条记录已不可用", en: "This record is no longer available", de: "Dieser Eintrag ist nicht mehr verfügbar", es: "Este registro ya no está disponible", pt: "Este registro não está mais disponível", fr: "Cette entrée n’est plus disponible", ja: "この記録は表示できません", ko: "이 기록을 더 이상 볼 수 없습니다", it: "Questo record non è più disponibile")
    }

    func recordedToday(_ count: Int) -> String {
        l.tr(zh: "今天已记录 \(count) 次", en: "\(count) logged today", de: "Heute \(count) erfasst", es: "\(count) registros hoy", pt: "\(count) registros hoje", fr: "\(count) entrées aujourd’hui", ja: "今日は\(count)回記録", ko: "오늘 \(count)회 기록", it: "\(count) registrazioni oggi")
    }
    func lastRecord(_ time: String) -> String {
        l.tr(zh: "上次 \(time)", en: "Last: \(time)", de: "Zuletzt: \(time)", es: "Último: \(time)", pt: "Último: \(time)", fr: "Dernière fois : \(time)", ja: "前回 \(time)", ko: "최근 \(time)", it: "Ultimo: \(time)")
    }
}

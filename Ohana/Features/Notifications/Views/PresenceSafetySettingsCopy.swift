//
//  PresenceSafetySettingsCopy.swift
//  Ohana
//

import Foundation

nonisolated struct PresenceSafetySettingsCopy {
    let l: L10n

    init(languageCode: String) {
        l = L10n(languageCode)
    }

    func text(
        zh: String,
        en: String,
        de: String,
        es: String,
        pt: String,
        fr: String,
        ja: String,
        ko: String,
        it: String
    ) -> String {
        l.tr(zh: zh, en: en, de: de, es: es, pt: pt, fr: fr, ja: ja, ko: ko, it: it)
    }

    var title: String {
        text(
            zh: "佛系守护",
            en: "Zen check-in safety",
            de: "Zen-Check-in-Schutz",
            es: "Seguridad del registro zen",
            pt: "Segurança do check-in zen",
            fr: "Sécurité du pointage zen",
            ja: "佛系チェックインの見守り",
            ko: "마음 편한 체크인 보호",
            it: "Sicurezza check-in zen"
        )
    }

    var reminderSection: String {
        text(
            zh: "本机提醒",
            en: "On-device reminder",
            de: "Lokale Erinnerung",
            es: "Recordatorio del dispositivo",
            pt: "Lembrete no dispositivo",
            fr: "Rappel sur l’appareil",
            ja: "デバイス内リマインダー",
            ko: "기기 내 알림",
            it: "Promemoria sul dispositivo"
        )
    }

    var enableReminder: String {
        text(
            zh: "启用每日打卡提醒",
            en: "Enable daily check-in reminder",
            de: "Tägliche Check-in-Erinnerung aktivieren",
            es: "Activar recordatorio diario",
            pt: "Ativar lembrete diário",
            fr: "Activer le rappel quotidien",
            ja: "毎日のチェックイン通知を有効にする",
            ko: "매일 체크인 알림 켜기",
            it: "Attiva il promemoria giornaliero"
        )
    }

    var reminderTime: String {
        text(
            zh: "提醒时间",
            en: "Reminder time",
            de: "Erinnerungszeit",
            es: "Hora del recordatorio",
            pt: "Horário do lembrete",
            fr: "Heure du rappel",
            ja: "通知時刻",
            ko: "알림 시간",
            it: "Orario del promemoria"
        )
    }

    var byWeekday: String {
        text(
            zh: "按星期设置",
            en: "Set by weekday",
            de: "Nach Wochentag einstellen",
            es: "Configurar por día",
            pt: "Configurar por dia",
            fr: "Régler par jour",
            ja: "曜日ごとに設定",
            ko: "요일별 설정",
            it: "Imposta per giorno"
        )
    }

    var secondReminder: String {
        text(
            zh: "宽限后再次提醒",
            en: "Remind again after grace period",
            de: "Nach Karenzzeit erneut erinnern",
            es: "Recordar tras el período de gracia",
            pt: "Lembrar após o período de tolerância",
            fr: "Rappeler après le délai de grâce",
            ja: "猶予時間後にもう一度通知",
            ko: "유예 시간 후 다시 알림",
            it: "Ricorda dopo il periodo di tolleranza"
        )
    }

    func gracePeriod(minutes: Int) -> String {
        text(
            zh: "宽限期：\(minutes) 分钟",
            en: "Grace period: \(minutes) minutes",
            de: "Karenzzeit: \(minutes) Minuten",
            es: "Período de gracia: \(minutes) min",
            pt: "Período de tolerância: \(minutes) min",
            fr: "Délai de grâce : \(minutes) min",
            ja: "猶予時間：\(minutes)分",
            ko: "유예 시간: \(minutes)분",
            it: "Periodo di tolleranza: \(minutes) min"
        )
    }

    var personalReminderHint: String {
        text(
            zh: "Personal 可按星期设置，并在 15–180 分钟宽限后安排第二次本机提醒。",
            en: "Personal can schedule by weekday and add a second on-device reminder after a 15–180 minute grace period.",
            de: "Personal kann nach Wochentag planen und nach 15–180 Minuten eine zweite lokale Erinnerung senden.",
            es: "Personal permite programar por día y añadir otro recordatorio tras 15–180 minutos.",
            pt: "O Personal permite agendar por dia e adicionar outro lembrete após 15–180 minutos.",
            fr: "Personal permet un réglage par jour et un second rappel après 15 à 180 minutes.",
            ja: "Personalでは曜日別設定と、15〜180分後の2回目のデバイス内通知を利用できます。",
            ko: "Personal에서는 요일별 설정과 15~180분 뒤 두 번째 기기 내 알림을 사용할 수 있습니다.",
            it: "Personal consente la pianificazione per giorno e un secondo promemoria dopo 15–180 minuti."
        )
    }

    var downgradePreservedHint: String {
        text(
            zh: "此前的 Personal 提醒设置已保留并可继续运行。Free 期间不能增加或修改高级设置，但可以关闭或重新开启。",
            en: "Your previous Personal reminder remains saved and can keep running. On Free, advanced fields cannot be added or changed, but the reminder can be turned off or back on.",
            de: "Die frühere Personal-Erinnerung bleibt gespeichert und kann weiterlaufen. In Free können erweiterte Felder nicht ergänzt oder geändert, aber ein- oder ausgeschaltet werden.",
            es: "El recordatorio de Personal sigue guardado y puede continuar. En Free no se pueden añadir ni cambiar opciones avanzadas, pero sí activarlo o desactivarlo.",
            pt: "O lembrete do Personal continua salvo e pode funcionar. No Free, opções avançadas não podem ser adicionadas nem alteradas, mas o lembrete pode ser ligado ou desligado.",
            fr: "L’ancien rappel Personal reste enregistré et peut continuer. Avec Free, les réglages avancés ne peuvent pas être ajoutés ni modifiés, mais le rappel peut être activé ou désactivé.",
            ja: "以前のPersonal通知設定は保持され、引き続き動作できます。Freeでは高度な項目の追加・変更はできませんが、通知のオン・オフは可能です。",
            ko: "이전 Personal 알림 설정은 보존되어 계속 작동할 수 있습니다. Free에서는 고급 설정을 추가하거나 변경할 수 없지만 알림을 끄거나 다시 켤 수 있습니다.",
            it: "Il precedente promemoria Personal resta salvato e può continuare. Con Free le opzioni avanzate non si possono aggiungere o modificare, ma il promemoria può essere attivato o disattivato."
        )
    }

    var messageSection: String {
        text(
            zh: "短信文案",
            en: "Text message",
            de: "SMS-Text",
            es: "Mensaje de texto",
            pt: "Mensagem de texto",
            fr: "Message SMS",
            ja: "SMS文面",
            ko: "문자 문구",
            it: "Messaggio SMS"
        )
    }

    var fixedMessageTemplate: String {
        text(
            zh: "未收到今天的打卡，请主动确认。",
            en: "We haven't received today's check-in. Please check in with them directly.",
            de: "Der heutige Check-in ist noch nicht eingegangen. Bitte frage direkt nach.",
            es: "No hemos recibido el registro de hoy. Confirma la situación directamente.",
            pt: "Ainda não recebemos o check-in de hoje. Confirme diretamente com a pessoa.",
            fr: "Nous n’avons pas reçu le pointage d’aujourd’hui. Merci de vérifier directement.",
            ja: "今日のチェックインがまだ届いていません。本人に直接確認してください。",
            ko: "오늘 체크인이 아직 확인되지 않았습니다. 직접 안부를 확인해 주세요.",
            it: "Non abbiamo ricevuto il check-in di oggi. Verifica direttamente con la persona."
        )
    }

    var messageExplanation: String {
        text(
            zh: "短信只会在你点击联系人并在系统编辑器中确认后发送。Ohana 不会自动向外部联系人发消息。",
            en: "A text is sent only after you tap a contact and confirm in the system composer. Ohana never messages external contacts automatically.",
            de: "Eine SMS wird nur gesendet, wenn du einen Kontakt auswählst und im Systemeditor bestätigst. Ohana schreibt externe Kontakte nie automatisch an.",
            es: "El SMS solo se envía tras tocar un contacto y confirmar en el editor del sistema. Ohana nunca escribe automáticamente a contactos externos.",
            pt: "O SMS só é enviado após tocar em um contato e confirmar no editor do sistema. O Ohana nunca envia mensagens externas automaticamente.",
            fr: "Le SMS n’est envoyé qu’après avoir choisi un contact et confirmé dans l’éditeur système. Ohana n’écrit jamais automatiquement aux contacts externes.",
            ja: "SMSは連絡先をタップし、システムの作成画面で確認した場合のみ送信されます。Ohanaが外部連絡先へ自動送信することはありません。",
            ko: "문자는 연락처를 누르고 시스템 작성 화면에서 확인한 경우에만 전송됩니다. Ohana는 외부 연락처에 자동으로 메시지를 보내지 않습니다.",
            it: "L’SMS parte solo dopo aver scelto un contatto e confermato nell’editor di sistema. Ohana non scrive mai automaticamente ai contatti esterni."
        )
    }

    var contactsSection: String {
        text(
            zh: "本机联系人",
            en: "Local contacts",
            de: "Lokale Kontakte",
            es: "Contactos locales",
            pt: "Contatos locais",
            fr: "Contacts locaux",
            ja: "ローカル連絡先",
            ko: "기기 내 연락처",
            it: "Contatti locali"
        )
    }

    var addContact: String {
        text(
            zh: "添加联系人",
            en: "Add contact",
            de: "Kontakt hinzufügen",
            es: "Añadir contacto",
            pt: "Adicionar contato",
            fr: "Ajouter un contact",
            ja: "連絡先を追加",
            ko: "연락처 추가",
            it: "Aggiungi contatto"
        )
    }

    var editContact: String {
        text(
            zh: "编辑联系人",
            en: "Edit contact",
            de: "Kontakt bearbeiten",
            es: "Editar contacto",
            pt: "Editar contato",
            fr: "Modifier le contact",
            ja: "連絡先を編集",
            ko: "연락처 편집",
            it: "Modifica contatto"
        )
    }

    var contactName: String {
        text(
            zh: "姓名",
            en: "Name",
            de: "Name",
            es: "Nombre",
            pt: "Nome",
            fr: "Nom",
            ja: "名前",
            ko: "이름",
            it: "Nome"
        )
    }

    var phoneNumber: String {
        text(
            zh: "电话号码",
            en: "Phone number",
            de: "Telefonnummer",
            es: "Número de teléfono",
            pt: "Número de telefone",
            fr: "Numéro de téléphone",
            ja: "電話番号",
            ko: "전화번호",
            it: "Numero di telefono"
        )
    }

    var contactEnabled: String {
        text(
            zh: "启用此联系人",
            en: "Enable this contact",
            de: "Diesen Kontakt aktivieren",
            es: "Activar este contacto",
            pt: "Ativar este contato",
            fr: "Activer ce contact",
            ja: "この連絡先を有効にする",
            ko: "이 연락처 사용",
            it: "Attiva questo contatto"
        )
    }

    var composeMessage: String {
        text(
            zh: "填写短信",
            en: "Compose text",
            de: "SMS verfassen",
            es: "Redactar SMS",
            pt: "Escrever SMS",
            fr: "Rédiger un SMS",
            ja: "SMSを作成",
            ko: "문자 작성",
            it: "Scrivi SMS"
        )
    }

    var localOnlyContactsHint: String {
        text(
            zh: "姓名和号码只保存在本机，不进入备份或同步。Free 可保存 1 位；Personal 可保存最多 3 位。",
            en: "Names and numbers stay on this device and are excluded from backup and sync. Free stores 1; Personal stores up to 3.",
            de: "Namen und Nummern bleiben auf diesem Gerät und werden weder gesichert noch synchronisiert. Free speichert 1, Personal bis zu 3.",
            es: "Los nombres y números se guardan solo en este dispositivo y no se incluyen en copias ni sincronización. Free permite 1 y Personal hasta 3.",
            pt: "Nomes e números ficam apenas neste dispositivo e não entram em backup nem sincronização. Free permite 1 e Personal até 3.",
            fr: "Les noms et numéros restent sur cet appareil, hors sauvegarde et synchronisation. Free en conserve 1 et Personal jusqu’à 3.",
            ja: "名前と番号はこのデバイスだけに保存され、バックアップや同期には含まれません。Freeは1件、Personalは最大3件です。",
            ko: "이름과 번호는 이 기기에만 저장되며 백업이나 동기화에 포함되지 않습니다. Free는 1명, Personal은 최대 3명입니다.",
            it: "Nomi e numeri restano su questo dispositivo e sono esclusi da backup e sincronizzazione. Free ne salva 1, Personal fino a 3."
        )
    }

    func contactLimit(limit: Int) -> String {
        text(
            zh: "当前方案最多可保存 \(limit) 位联系人。已有联系人会保留；请先删除一位再添加。",
            en: "Your current plan stores up to \(limit) contact(s). Existing contacts stay saved; remove one before adding another.",
            de: "Dein aktueller Tarif speichert bis zu \(limit) Kontakt(e). Bestehende Kontakte bleiben; entferne zuerst einen.",
            es: "Tu plan permite hasta \(limit) contacto(s). Los existentes se conservan; elimina uno antes de añadir otro.",
            pt: "Seu plano permite até \(limit) contato(s). Os existentes são mantidos; remova um antes de adicionar outro.",
            fr: "Votre offre conserve jusqu’à \(limit) contact(s). Les contacts existants restent; supprimez-en un avant d’en ajouter.",
            ja: "現在のプランでは最大\(limit)件です。既存の連絡先は保持されます。追加する前に1件削除してください。",
            ko: "현재 요금제에서는 최대 \(limit)명까지 저장됩니다. 기존 연락처는 유지되며 추가하려면 먼저 한 명을 삭제하세요.",
            it: "Il piano attuale salva fino a \(limit) contatto/i. Quelli esistenti restano; rimuovine uno prima di aggiungerne un altro."
        )
    }

    var save: String {
        text(
            zh: "保存",
            en: "Save",
            de: "Sichern",
            es: "Guardar",
            pt: "Salvar",
            fr: "Enregistrer",
            ja: "保存",
            ko: "저장",
            it: "Salva"
        )
    }

    var delete: String {
        text(
            zh: "删除联系人",
            en: "Delete contact",
            de: "Kontakt löschen",
            es: "Eliminar contacto",
            pt: "Excluir contato",
            fr: "Supprimer le contact",
            ja: "連絡先を削除",
            ko: "연락처 삭제",
            it: "Elimina contatto"
        )
    }

    var cancel: String {
        text(
            zh: "取消",
            en: "Cancel",
            de: "Abbrechen",
            es: "Cancelar",
            pt: "Cancelar",
            fr: "Annuler",
            ja: "キャンセル",
            ko: "취소",
            it: "Annulla"
        )
    }

    var saved: String {
        text(
            zh: "提醒设置已保存",
            en: "Reminder settings saved",
            de: "Erinnerung gespeichert",
            es: "Recordatorio guardado",
            pt: "Lembrete salvo",
            fr: "Rappel enregistré",
            ja: "通知設定を保存しました",
            ko: "알림 설정을 저장했습니다",
            it: "Promemoria salvato"
        )
    }

    var reminderDisabled: String {
        text(
            zh: "本机提醒已关闭",
            en: "On-device reminder turned off",
            de: "Lokale Erinnerung deaktiviert",
            es: "Recordatorio desactivado",
            pt: "Lembrete desativado",
            fr: "Rappel désactivé",
            ja: "デバイス内通知をオフにしました",
            ko: "기기 내 알림을 껐습니다",
            it: "Promemoria disattivato"
        )
    }

    var permissionNeeded: String {
        text(
            zh: "未获得通知权限。请在系统设置中允许通知后再试。",
            en: "Notification permission was not granted. Allow notifications in system settings and try again.",
            de: "Die Mitteilungsberechtigung wurde nicht erteilt. Erlaube Mitteilungen in den Systemeinstellungen und versuche es erneut.",
            es: "No se concedió permiso para notificaciones. Actívalo en Ajustes e inténtalo de nuevo.",
            pt: "A permissão de notificações não foi concedida. Ative-a nos Ajustes e tente novamente.",
            fr: "L’autorisation de notification n’a pas été accordée. Activez-la dans Réglages puis réessayez.",
            ja: "通知が許可されていません。システム設定で通知を許可してから再試行してください。",
            ko: "알림 권한이 허용되지 않았습니다. 시스템 설정에서 알림을 허용한 뒤 다시 시도하세요.",
            it: "Il permesso per le notifiche non è stato concesso. Abilitalo nelle impostazioni di sistema e riprova."
        )
    }

    var messageSent: String {
        text(
            zh: "系统已确认短信发送",
            en: "The system confirmed the text was sent",
            de: "Das System hat den SMS-Versand bestätigt",
            es: "El sistema confirmó el envío del SMS",
            pt: "O sistema confirmou o envio do SMS",
            fr: "Le système a confirmé l’envoi du SMS",
            ja: "システムがSMSの送信を確認しました",
            ko: "시스템에서 문자 전송을 확인했습니다",
            it: "Il sistema ha confermato l’invio dell’SMS"
        )
    }

    var genericError: String {
        text(
            zh: "无法保存，请稍后重试。",
            en: "Could not save. Try again later.",
            de: "Speichern nicht möglich. Versuche es später erneut.",
            es: "No se pudo guardar. Inténtalo más tarde.",
            pt: "Não foi possível salvar. Tente novamente mais tarde.",
            fr: "Enregistrement impossible. Réessayez plus tard.",
            ja: "保存できませんでした。後でもう一度お試しください。",
            ko: "저장할 수 없습니다. 나중에 다시 시도하세요.",
            it: "Impossibile salvare. Riprova più tardi."
        )
    }

    var messageFailed: String {
        text(
            zh: "系统未确认短信发送。请重试或复制号码和文案。",
            en: "The system did not confirm that the text was sent. Try again or copy the number and message.",
            de: "Das System hat den Versand nicht bestätigt. Versuche es erneut oder kopiere Nummer und Text.",
            es: "El sistema no confirmó el envío. Inténtalo de nuevo o copia el número y el mensaje.",
            pt: "O sistema não confirmou o envio. Tente novamente ou copie o número e a mensagem.",
            fr: "Le système n’a pas confirmé l’envoi. Réessayez ou copiez le numéro et le message.",
            ja: "システムがSMS送信を確認しませんでした。再試行するか、番号と文面をコピーしてください。",
            ko: "시스템에서 문자 전송을 확인하지 못했습니다. 다시 시도하거나 번호와 문구를 복사하세요.",
            it: "Il sistema non ha confermato l’invio. Riprova o copia numero e messaggio."
        )
    }

    var atLeastOneSchedule: String {
        text(
            zh: "请至少选择一个提醒日。",
            en: "Select at least one reminder day.",
            de: "Wähle mindestens einen Erinnerungstag.",
            es: "Selecciona al menos un día.",
            pt: "Selecione pelo menos um dia.",
            fr: "Sélectionnez au moins un jour.",
            ja: "通知する曜日を1つ以上選んでください。",
            ko: "알림 요일을 하나 이상 선택하세요.",
            it: "Seleziona almeno un giorno."
        )
    }

    var invalidName: String {
        text(
            zh: "请输入联系人姓名。",
            en: "Enter a contact name.",
            de: "Gib einen Kontaktnamen ein.",
            es: "Introduce el nombre del contacto.",
            pt: "Digite o nome do contato.",
            fr: "Saisissez le nom du contact.",
            ja: "連絡先の名前を入力してください。",
            ko: "연락처 이름을 입력하세요.",
            it: "Inserisci il nome del contatto."
        )
    }

    var invalidPhone: String {
        text(
            zh: "请输入电话号码。",
            en: "Enter a phone number.",
            de: "Gib eine Telefonnummer ein.",
            es: "Introduce un número de teléfono.",
            pt: "Digite um número de telefone.",
            fr: "Saisissez un numéro de téléphone.",
            ja: "電話番号を入力してください。",
            ko: "전화번호를 입력하세요.",
            it: "Inserisci un numero di telefono."
        )
    }

    func weekday(_ weekday: PresenceReminderWeekday) -> String {
        switch weekday {
        case .monday:
            text(zh: "星期一", en: "Monday", de: "Montag", es: "Lunes", pt: "Segunda-feira", fr: "Lundi", ja: "月曜日", ko: "월요일", it: "Lunedì")
        case .tuesday:
            text(zh: "星期二", en: "Tuesday", de: "Dienstag", es: "Martes", pt: "Terça-feira", fr: "Mardi", ja: "火曜日", ko: "화요일", it: "Martedì")
        case .wednesday:
            text(zh: "星期三", en: "Wednesday", de: "Mittwoch", es: "Miércoles", pt: "Quarta-feira", fr: "Mercredi", ja: "水曜日", ko: "수요일", it: "Mercoledì")
        case .thursday:
            text(zh: "星期四", en: "Thursday", de: "Donnerstag", es: "Jueves", pt: "Quinta-feira", fr: "Jeudi", ja: "木曜日", ko: "목요일", it: "Giovedì")
        case .friday:
            text(zh: "星期五", en: "Friday", de: "Freitag", es: "Viernes", pt: "Sexta-feira", fr: "Vendredi", ja: "金曜日", ko: "금요일", it: "Venerdì")
        case .saturday:
            text(zh: "星期六", en: "Saturday", de: "Samstag", es: "Sábado", pt: "Sábado", fr: "Samedi", ja: "土曜日", ko: "토요일", it: "Sabato")
        case .sunday:
            text(zh: "星期日", en: "Sunday", de: "Sonntag", es: "Domingo", pt: "Domingo", fr: "Dimanche", ja: "日曜日", ko: "일요일", it: "Domenica")
        }
    }
}

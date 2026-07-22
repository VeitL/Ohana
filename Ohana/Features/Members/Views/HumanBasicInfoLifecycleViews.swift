import SwiftUI

struct HumanLifecycleDangerZone: View {
    let human: Human
    let onMarkPassedAway: (Date) -> Void
    let onUndoPassedAway: () -> Void
    let onDelete: (@escaping (HumanDeletionPresentationOutcome) -> Void) -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var passedDate = Date()
    @State private var showingPassedAlert = false
    @State private var showingUndoPassedAlert = false
    @State private var showingDeleteSheet = false
    @State private var isExpanded = false
    @State private var isDeleteInProgress = false
    @State private var deleteErrorMessage: String?
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if human.hasPassedAway {
                    passedAwaySummary
                    lifecycleButton(
                        title: l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Verstorben-Markierung zurücknehmen"),
                        icon: "arrow.uturn.backward",
                        color: Color.goYellow,
                        identifier: "human-memorial-undo-action"
                    ) {
                        showingUndoPassedAlert = true
                    }
                } else {
                    DatePicker(l.tr(zh: "离世日期", en: "Date of Passing", de: "Sterbedatum"), selection: $passedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(Color.goPrimary)
                    lifecycleButton(
                        title: l.tr(
                            zh: "标记 \(human.name) 已离世", en: "Mark \(human.name) as passed away", de: "\(human.name) als verstorben markieren",
                            es: "Marcar a \(human.name) como fallecido", pt: "Marcar \(human.name) como falecido", fr: "Indiquer le décès de \(human.name)",
                            ja: "\(human.name)を逝去として記録", ko: "\(human.name)님을 별세로 표시", it: "Segna \(human.name) come deceduto"
                        ),
                        icon: "rainbow",
                        color: Color.goPurple,
                        identifier: "human-memorial-mark-action"
                    ) {
                        showingPassedAlert = true
                    }
                }

                lifecycleButton(
                    title: l.tr(
                        zh: "彻底删除 \(human.name)", en: "Permanently delete \(human.name)", de: "\(human.name) endgültig löschen",
                        es: "Eliminar permanentemente a \(human.name)", pt: "Excluir \(human.name) permanentemente", fr: "Supprimer définitivement \(human.name)",
                        ja: "\(human.name)を完全に削除", ko: "\(human.name)님 영구 삭제", it: "Elimina definitivamente \(human.name)"
                    ),
                    icon: "trash.fill",
                    color: Color.goRed,
                    identifier: "human-danger-delete-action"
                ) {
                    showingDeleteSheet = true
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "archivebox.fill") // a11y: allow decorative icon; the disclosure label supplies the full meaning
                    .foregroundStyle(Color.goRed.opacity(0.72))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(
                        zh: "生命与数据管理", en: "Life & data management", de: "Lebens- und Datenverwaltung",
                        es: "Vida y gestión de datos", pt: "Vida e gestão de dados", fr: "Vie et gestion des données",
                        ja: "ライフイベントとデータ管理", ko: "생애 및 데이터 관리", it: "Vita e gestione dei dati"
                    ))
                    .font(OhanaFont.callout(.bold))
                    Text(l.tr(
                        zh: "离世状态与永久删除", en: "Memorial status and permanent deletion", de: "Gedenkstatus und endgültiges Löschen",
                        es: "Estado conmemorativo y eliminación permanente", pt: "Estado memorial e exclusão permanente", fr: "Statut commémoratif et suppression définitive",
                        ja: "メモリアル状態と完全削除", ko: "추모 상태 및 영구 삭제", it: "Stato commemorativo ed eliminazione definitiva"
                    ))
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(14)
        .goTranslucentCard(cornerRadius: OhanaRadius.control)
        .tint(Color.goRed)
        .accessibilityIdentifier("human-lifecycle-management-disclosure")
        .onAppear {
            passedDate = human.passedAwayDate ?? Date()
        }
        .onChange(of: human.passedAwayDate) { _, date in
            passedDate = date ?? Date()
        }
        .alert(l.tr(zh: "确认标记离世", en: "Confirm Passing Mark", de: "Verstorben-Markierung bestätigen"), isPresented: $showingPassedAlert) {
            Button(l.tr(zh: "确认", en: "Confirm", de: "Bestätigen"), role: .destructive) {
                onMarkPassedAway(passedDate)
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "将标记 \(human.name) 为离世，并让未来安排退出活跃提醒。原有数据会保留，此操作可撤销。",
                en: "\(human.name) will be marked as passed away, and future schedules will leave active reminders. Existing data is kept, and this can be undone.",
                de: "\(human.name) wird als verstorben markiert, und zukünftige Termine verlassen aktive Erinnerungen. Bestehende Daten bleiben erhalten und dies kann rückgängig gemacht werden.",
                es: "\(human.name) se marcará como fallecido y las futuras citas saldrán de los recordatorios activos. Los datos existentes se conservarán y podrás deshacerlo.",
                pt: "\(human.name) será marcado como falecido e os agendamentos futuros sairão dos lembretes ativos. Os dados existentes serão mantidos e isso poderá ser desfeito.",
                fr: "Le décès de \(human.name) sera enregistré et les échéances futures quitteront les rappels actifs. Les données existantes seront conservées et cette action pourra être annulée.",
                ja: "\(human.name)を逝去として記録し、今後の予定を有効なリマインダーから外します。既存のデータは保持され、元に戻せます。",
                ko: "\(human.name)님을 별세로 표시하고 이후 일정은 활성 알림에서 제외합니다. 기존 데이터는 유지되며 되돌릴 수 있습니다.",
                it: "\(human.name) verrà segnato come deceduto e gli appuntamenti futuri usciranno dai promemoria attivi. I dati esistenti saranno conservati e l’azione potrà essere annullata."
            ))
        }
        .alert(l.tr(zh: "撤销离世标记", en: "Undo Passing Mark", de: "Verstorben-Markierung zurücknehmen"), isPresented: $showingUndoPassedAlert) {
            Button(l.tr(zh: "撤销", en: "Undo", de: "Zurücknehmen"), role: .destructive) {
                onUndoPassedAway()
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(l.tr(
                zh: "将清除 \(human.name) 的离世记录，恢复为在世状态。",
                en: "\(human.name)'s passing record will be cleared and restored to active status.",
                de: "Der Verstorben-Eintrag von \(human.name) wird gelöscht und der aktive Status wiederhergestellt.",
                es: "Se borrará el registro de fallecimiento de \(human.name) y se restaurará su estado activo.",
                pt: "O registro de falecimento de \(human.name) será removido e o status ativo será restaurado.",
                fr: "L’enregistrement du décès de \(human.name) sera effacé et son statut actif sera rétabli.",
                ja: "\(human.name)の逝去記録を消去し、アクティブな状態に戻します。",
                ko: "\(human.name)님의 별세 기록을 지우고 활성 상태로 복원합니다.",
                it: "La registrazione del decesso di \(human.name) verrà rimossa e lo stato attivo ripristinato."
            ))
        }
        .sheet(isPresented: $showingDeleteSheet) {
            HumanDeleteConfirmationSheet(
                humanName: human.name,
                isDeleting: isDeleteInProgress,
                onCancel: { showingDeleteSheet = false },
                onDelete: beginDeletion
            )
            .ohanaCompactSheetPresentation(detents: [.medium, .large])
        }
        .alert(
            l.tr(
                zh: "无法删除成员", en: "Could not delete member", de: "Mitglied konnte nicht gelöscht werden",
                es: "No se pudo eliminar al miembro", pt: "Não foi possível excluir o membro", fr: "Impossible de supprimer le membre",
                ja: "メンバーを削除できませんでした", ko: "구성원을 삭제할 수 없음", it: "Impossibile eliminare il membro"
            ),
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button(l.confirm, role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func beginDeletion() {
        guard !isDeleteInProgress else { return }
        isDeleteInProgress = true
        onDelete { outcome in
            isDeleteInProgress = false
            switch outcome {
            case .deleted:
                showingDeleteSheet = false
            case let .failed(message):
                deleteErrorMessage = message
            }
        }
    }

    private var passedAwaySummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = human.passedAwayDate {
                Text(l.tr(
                    zh: "离世日期：\(date.formatted(.dateTime.year().month().day()))",
                    en: "Date of passing: \(date.formatted(.dateTime.year().month().day()))",
                    de: "Sterbedatum: \(date.formatted(.dateTime.year().month().day()))",
                    es: "Fecha de fallecimiento: \(date.formatted(.dateTime.year().month().day()))",
                    pt: "Data de falecimento: \(date.formatted(.dateTime.year().month().day()))",
                    fr: "Date du décès : \(date.formatted(.dateTime.year().month().day()))",
                    ja: "逝去日：\(date.formatted(.dateTime.year().month().day()))",
                    ko: "별세일: \(date.formatted(.dateTime.year().month().day()))",
                    it: "Data del decesso: \(date.formatted(.dateTime.year().month().day()))"
                ))
                    .font(OhanaFont.adaptive(size: 13, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
            }
            Text(l.tr(
                zh: "相伴 \(human.daysTogetherAtPassing) 天 · \(human.ageAtPassingText)",
                en: "Together for \(human.daysTogetherAtPassing) days · \(localizedAgeAtPassing)",
                de: "\(human.daysTogetherAtPassing) Tage zusammen · \(localizedAgeAtPassing)",
                es: "\(human.daysTogetherAtPassing) días juntos · \(localizedAgeAtPassing)",
                pt: "\(human.daysTogetherAtPassing) dias juntos · \(localizedAgeAtPassing)",
                fr: "\(human.daysTogetherAtPassing) jours ensemble · \(localizedAgeAtPassing)",
                ja: "一緒に過ごした\(human.daysTogetherAtPassing)日 · \(localizedAgeAtPassing)",
                ko: "함께한 \(human.daysTogetherAtPassing)일 · \(localizedAgeAtPassing)",
                it: "\(human.daysTogetherAtPassing) giorni insieme · \(localizedAgeAtPassing)"
            ))
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.goPurple.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
            .strokeBorder(Color.goPurple.opacity(0.22), lineWidth: 1))
        .accessibilityIdentifier("human-memorial-passed-date")
    }

    private func lifecycleButton(
        title: String,
        icon: String,
        color: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon) // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 14, weight: .bold))
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                .strokeBorder(color.opacity(0.26), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private var localizedAgeAtPassing: String {
        guard let birthday = human.birthday,
              let passed = human.passedAwayDate else {
            return l.tr(zh: "未知年龄", en: "Unknown age", de: "Unbekanntes Alter")
        }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: passed).year ?? 0
        return years > 0
            ? localizedHumanAgeYears(years, l: l)
            : l.tr(zh: "未满1岁", en: "Under 1", de: "Unter 1")
    }
}

private struct HumanDeleteConfirmationSheet: View {
    let humanName: String
    let isDeleting: Bool
    let onCancel: () -> Void
    let onDelete: () -> Void

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var confirmName = ""
    @FocusState private var confirmNameFocused: Bool
    private var l: L10n { L10n(appLanguage) }

    private var canDelete: Bool {
        !isDeleting && ConfirmationNameMatcher.matches(confirmName, expectedName: humanName)
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.adaptive(size: 16, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed)
                        .frame(width: 36, height: 36) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .background(Color.goRed.opacity(0.12), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l.tr(
                            zh: "删除成员 \(humanName)", en: "Delete member \(humanName)", de: "Mitglied \(humanName) löschen",
                            es: "Eliminar a \(humanName)", pt: "Excluir \(humanName)", fr: "Supprimer \(humanName)",
                            ja: "\(humanName)を削除", ko: "\(humanName)님 삭제", it: "Elimina \(humanName)"
                        ))
                            .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(zh: "输入名字后才能继续", en: "Enter the name to continue", de: "Namen eingeben, um fortzufahren"))
                            .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Button(action: cancelAfterResigningKeyboard) {
                        Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                            .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isDeleting)
                    .accessibilityIdentifier("human-delete-confirm-close")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(l.tr(
                        zh: "这会永久删除成员资料及所有关联的本地数据，包括健康、用药、任务、椰子账本、活动记录与备注附件。无法撤销。",
                        en: "This permanently deletes the member profile and all related local data, including health, medication, tasks, coconut ledgers, activity history, and note attachments. It cannot be undone.",
                        de: "Dies löscht das Mitgliederprofil und alle zugehörigen lokalen Daten dauerhaft, einschließlich Gesundheit, Medikamente, Aufgaben, Kokosnuss-Konten, Aktivitäten und Notizanhänge. Dies kann nicht rückgängig gemacht werden.",
                        es: "Esto elimina permanentemente el perfil y todos los datos locales relacionados, incluidos salud, medicación, tareas, registros de cocos, actividad y archivos adjuntos. No se puede deshacer.",
                        pt: "Isso exclui permanentemente o perfil e todos os dados locais relacionados, incluindo saúde, medicação, tarefas, registros de cocos, atividades e anexos. Não é possível desfazer.",
                        fr: "Cette action supprime définitivement le profil et toutes les données locales associées, notamment santé, médicaments, tâches, registres de noix de coco, activités et pièces jointes. Elle est irréversible.",
                        ja: "メンバーのプロフィールと、健康・服薬・タスク・ココナッツ台帳・活動履歴・メモの添付ファイルを含む関連ローカルデータを完全に削除します。元に戻せません。",
                        ko: "구성원 프로필과 건강, 복약, 작업, 코코넛 원장, 활동 기록, 메모 첨부 파일을 포함한 모든 관련 로컬 데이터를 영구 삭제합니다. 되돌릴 수 없습니다.",
                        it: "Questa azione elimina definitivamente il profilo e tutti i dati locali correlati, inclusi salute, farmaci, attività, registri delle noci di cocco, cronologia e allegati delle note. Non può essere annullata."
                    ))
                        .font(OhanaFont.adaptive(size: 13, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.68))
                    Text(l.tr(
                        zh: "请输入：\(humanName)", en: "Enter: \(humanName)", de: "Eingeben: \(humanName)",
                        es: "Escribe: \(humanName)", pt: "Digite: \(humanName)", fr: "Saisissez : \(humanName)",
                        ja: "入力：\(humanName)", ko: "입력: \(humanName)", it: "Inserisci: \(humanName)"
                    ))
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goRed.opacity(0.8))
                }

                TextField(l.tr(zh: "成员名字", en: "Member name", de: "Mitgliedsname"), text: $confirmName) // ui-v4: allow existing form input; P1 baseline keeps layout stable while feature forms migrate to OhanaTextField
                    .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($confirmNameFocused)
                    .disabled(isDeleting)
                    .onSubmit { attemptDelete() }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous)
                        .strokeBorder(canDelete ? Color.goRed.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1))
                    .accessibilityIdentifier("human-delete-confirm-name-input")

                HStack(spacing: 10) {
                    Button(action: cancelAfterResigningKeyboard) {
                        Text(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"))
                            .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.72))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(isDeleting)
                    .accessibilityIdentifier("human-delete-confirm-cancel")

                    Button(action: attemptDelete) {
                        Group {
                            if isDeleting {
                                ProgressView()
                                    .tint(Color.white) // ui-v4: allow high-contrast progress indicator on destructive red fill
                            } else {
                                Text(l.tr(zh: "删除", en: "Delete", de: "Löschen"))
                                    .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            }
                        }
                        .foregroundStyle(canDelete || isDeleting ? Color.white : Color.ohanaTertiaryText) // ui-v4: allow destructive red button needs white contrast
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(canDelete || isDeleting ? Color.goRed : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!canDelete)
                    .accessibilityIdentifier("human-delete-confirm-delete")
                }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .interactiveDismissDisabled(isDeleting)
    }

    private func cancelAfterResigningKeyboard() {
        confirmNameFocused = false
        onCancel()
    }

    private func attemptDelete() {
        guard canDelete else { return }
        confirmNameFocused = false
        onDelete()
    }
}

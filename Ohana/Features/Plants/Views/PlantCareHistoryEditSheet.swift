//
//  PlantCareHistoryEditSheet.swift
//  Ohana
//
//  Native, retryable editor for one plant-care history record.
//

import PhotosUI
import SwiftData
import SwiftUI

nonisolated enum PlantCareHistoryRouteAction: String, Hashable, Sendable {
    case edit
    case delete
}

nonisolated struct PlantCareHistoryRoute: Identifiable, Hashable, Sendable {
    let recordID: PlantCareHistoryRecordID
    let action: PlantCareHistoryRouteAction

    var id: String {
        "\(recordID.plantID.uuidString)|\(recordID.logID.uuidString)|\(action.rawValue)"
    }
}

struct PlantCareHistoryEditSheet: View {
    private enum FailedAction {
        case edit
        case delete
    }

    let route: PlantCareHistoryRoute
    let onCommitted: (PlantCareHistoryCommandResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @AppStorage("currentActiveHumanId") private var activeHumanID = ""

    @State private var snapshot: PlantCareHistoryRecordSnapshot?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var date = Date()
    @State private var careType = PlantCareType.watering
    @State private var note = ""
    @State private var healthStatus: PlantHealthStatus?
    @State private var photoMutation = PlantCareHistoryPhotoMutation.keep
    @State private var replacementPhotoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isSaving = false
    @State private var failureMessage: String?
    @State private var failedAction: FailedAction?
    @State private var showsDeleteConfirmation = false
    @State private var didOfferInitialDelete = false
    @State private var editOperationID = UUID()
    @State private var deleteOperationID = UUID()

    private var l: L10n { L10n(appLanguage) }
    private var editor: PlantCareCommandExecutor {
        PlantCareCommandExecutor(context: modelContext, services: appServices)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView(l.tr(zh: "正在读取记录", en: "Loading record", de: "Eintrag wird geladen"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loadError || snapshot == nil {
                    loadFailureView
                } else {
                    editorForm
                }
            }
            .navigationTitle(l.tr(zh: "编辑护理记录", en: "Edit care log", de: "Pflegeeintrag bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "保存", en: "Save", de: "Speichern")) {
                        save()
                    }
                    .disabled(snapshot == nil || isSaving || isLoadingPhoto)
                    .accessibilityIdentifier("plant-care-history-save")
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task(id: route.recordID) {
            loadSnapshot()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            loadPhoto(from: item)
        }
        .alert(
            l.tr(zh: "删除这条记录？", en: "Delete this log?", de: "Diesen Eintrag löschen?"),
            isPresented: $showsDeleteConfirmation
        ) {
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                if route.action == .delete { dismiss() }
            }
            Button(l.tr(zh: "删除", en: "Delete", de: "Löschen"), role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text(deleteExplanation)
        }
        .accessibilityIdentifier("plant-care-history-editor")
    }

    private var editorForm: some View {
        Form {
            if let failureMessage {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(failureMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.goRed)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) {
                            retryFailedAction()
                        }
                        .frame(minHeight: 44)
                        .disabled(isSaving)
                        .accessibilityIdentifier("plant-care-history-retry")
                    }
                }
            }

            Section(l.tr(zh: "护理事实", en: "Care fact", de: "Pflegeangabe")) {
                Picker(l.tr(zh: "类型", en: "Type", de: "Typ"), selection: $careType) {
                    ForEach(PlantCareType.allCases) { type in
                        Label(type.displayName(l: l), systemImage: careSymbol(for: type))
                            .tag(type)
                    }
                }
                .disabled(snapshot?.sourceFieldsAreLocked == true)

                DatePicker(
                    l.tr(zh: "时间", en: "Date", de: "Datum"),
                    selection: $date,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(snapshot?.sourceFieldsAreLocked == true)

                if snapshot?.sourceFieldsAreLocked == true {
                    Label(
                        l.tr(
                            zh: "这条记录来自计划完成。类型和时间由原计划锁定；删除会把对应计划重新打开。",
                            en: "This log came from a completed plan. Its type and date stay tied to that plan; deleting it reopens the plan occurrence.",
                            de: "Dieser Eintrag stammt aus einem abgeschlossenen Plan. Typ und Datum bleiben daran gebunden; Löschen öffnet den Termin wieder."
                        ),
                        systemImage: "lock.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
            }

            Section(l.tr(zh: "观察", en: "Observation", de: "Beobachtung")) {
                TextField(
                    l.tr(zh: "备注", en: "Note", de: "Notiz"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(3 ... 8)
                .accessibilityIdentifier("plant-care-history-note")

                Picker(l.tr(zh: "当时状态", en: "Status at the time", de: "Status zu diesem Zeitpunkt"), selection: $healthStatus) {
                    Text(l.tr(zh: "未记录", en: "Not recorded", de: "Nicht erfasst"))
                        .tag(nil as PlantHealthStatus?)
                    ForEach(PlantHealthStatus.allCases) { status in
                        Text(healthStatusTitle(status))
                            .tag(status as PlantHealthStatus?)
                    }
                }
            }

            Section(l.tr(zh: "照片", en: "Photo", de: "Foto")) {
                photoEditor
            }

            if let snapshot {
                Section(l.tr(zh: "记录来源", en: "Record source", de: "Eintragsquelle")) {
                    LabeledContent(
                        l.tr(zh: "来源", en: "Source", de: "Quelle"),
                        value: sourceTitle(snapshot.source)
                    )
                    LabeledContent(
                        l.tr(zh: "执行者", en: "Executor", de: "Ausgeführt von"),
                        value: snapshot.executorID?.isEmpty == false
                            ? snapshot.executorID!
                            : l.tr(zh: "未记录", en: "Not recorded", de: "Nicht erfasst")
                    )
                    Text(l.tr(
                        zh: "执行者和事务标识属于审计信息，编辑时保持不变。当前健康档案也不会由历史改动自动覆盖。",
                        en: "Executor and transaction identity are immutable audit fields. Editing history also does not overwrite the plant's current health profile.",
                        de: "Ausführende Person und Transaktions-ID bleiben als Prüfdaten unverändert. Der aktuelle Gesundheitsstatus der Pflanze wird ebenfalls nicht überschrieben."
                    ))
                    .font(.footnote)
                    .foregroundStyle(Color.ohanaSecondaryText)
                }
            }

            Section {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label(l.tr(zh: "删除记录", en: "Delete log", de: "Eintrag löschen"), systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .disabled(isSaving)
                .accessibilityIdentifier("plant-care-history-delete")
            } footer: {
                Text(l.tr(
                    zh: "删除历史不会收回已经结算的椰子或预算；相关护理账本会留下明确校正。",
                    en: "Deleting history does not claw back settled coconuts or budget usage; the care ledger keeps an explicit correction.",
                    de: "Beim Löschen werden verbuchte Kokosnüsse oder Budgetnutzung nicht zurückgenommen; das Pflegebuch hält die Korrektur fest."
                ))
            }
        }
    }

    @ViewBuilder
    private var photoEditor: some View {
        if let replacementPhotoData {
            AsyncDecodedImageView(data: replacementPhotoData) { image in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            } placeholder: {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 150)
            }
            .accessibilityLabel(l.tr(zh: "替换照片预览", en: "Replacement photo preview", de: "Vorschau des Ersatzfotos"))
        } else if photoMutation == .remove {
            Label(l.tr(zh: "保存后移除照片", en: "Photo will be removed", de: "Foto wird entfernt"), systemImage: "photo.badge.minus")
                .foregroundStyle(Color.ohanaSecondaryText)
        } else if snapshot?.hasPhoto == true {
            Label(l.tr(zh: "保留当前照片", en: "Current photo will be kept", de: "Aktuelles Foto bleibt erhalten"), systemImage: "photo.fill")
                .foregroundStyle(Color.ohanaSecondaryText)
        } else {
            Label(l.tr(zh: "没有照片", en: "No photo", de: "Kein Foto"), systemImage: "photo")
                .foregroundStyle(Color.ohanaSecondaryText)
        }

        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            Label(
                isLoadingPhoto
                    ? l.tr(zh: "正在读取照片", en: "Loading photo", de: "Foto wird geladen")
                    : l.tr(zh: "选择照片", en: "Choose photo", de: "Foto auswählen"),
                systemImage: "photo.badge.plus"
            )
            .frame(minHeight: 44)
        }
        .disabled(isLoadingPhoto || isSaving)
        .accessibilityIdentifier("plant-care-history-photo-picker")

        if snapshot?.hasPhoto == true || replacementPhotoData != nil {
            Button(role: .destructive) {
                selectedPhotoItem = nil
                replacementPhotoData = nil
                photoMutation = .remove
            } label: {
                Label(l.tr(zh: "移除照片", en: "Remove photo", de: "Foto entfernen"), systemImage: "xmark.circle")
                    .frame(minHeight: 44)
            }
            .disabled(isSaving)
        }
    }

    private var loadFailureView: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").accessibilityHidden(true)
                .font(.title)
                .foregroundStyle(Color.goRed)
            Text(l.tr(zh: "无法读取这条记录", en: "This log could not be loaded", de: "Dieser Eintrag konnte nicht geladen werden"))
                .font(OhanaFont.title3(.black))
            Text(l.tr(
                zh: "它可能已在别处删除，或暂时无法访问。你可以重试。",
                en: "It may have been deleted elsewhere or is temporarily unavailable. You can retry.",
                de: "Er wurde möglicherweise anderswo gelöscht oder ist vorübergehend nicht verfügbar. Du kannst es erneut versuchen."
            ))
            .foregroundStyle(Color.ohanaSecondaryText)
            .multilineTextAlignment(.center)
            Button(l.tr(zh: "重试", en: "Retry", de: "Erneut versuchen")) {
                loadSnapshot()
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
            .accessibilityIdentifier("plant-care-history-load-retry")
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var deleteExplanation: String {
        if snapshot?.sourceFieldsAreLocked == true {
            return l.tr(
                zh: "这会删除护理事实，并把对应的计划事项或提醒重新设为待处理。已结算奖励和预算不会逆转。",
                en: "This removes the care fact and reopens its plan occurrence or reminder. Settled rewards and budget usage are not reversed.",
                de: "Der Pflegeeintrag wird entfernt und der zugehörige Termin oder die Erinnerung wieder geöffnet. Verbuchte Belohnungen und Budgetnutzung werden nicht zurückgenommen."
            )
        }
        return l.tr(
            zh: "这会永久删除这条护理记录。已结算奖励和预算不会逆转。",
            en: "This permanently deletes the care log. Settled rewards and budget usage are not reversed.",
            de: "Dieser Pflegeeintrag wird dauerhaft gelöscht. Verbuchte Belohnungen und Budgetnutzung werden nicht zurückgenommen."
        )
    }

    private func loadSnapshot() {
        isLoading = true
        loadError = false
        failureMessage = nil
        do {
            let loaded = try PlantCareHistorySnapshotReader.load(recordID: route.recordID, context: modelContext)
            snapshot = loaded
            date = loaded.date
            careType = loaded.careType
            note = loaded.note
            healthStatus = loaded.healthStatus
            photoMutation = .keep
            replacementPhotoData = nil
            selectedPhotoItem = nil
            isLoading = false
            if route.action == .delete, !didOfferInitialDelete {
                didOfferInitialDelete = true
                showsDeleteConfirmation = true
            }
        } catch {
            snapshot = nil
            isLoading = false
            loadError = true
        }
    }

    private func save() {
        guard let snapshot, !isSaving else { return }
        isSaving = true
        failureMessage = nil
        failedAction = nil
        let result = editor.editHistory(
            PlantCareHistoryEditIntent(
                recordID: snapshot.recordID,
                operationID: editOperationID,
                expectedCareTransactionID: snapshot.careTransactionID,
                date: date,
                careType: careType,
                note: note,
                healthStatus: healthStatus,
                photoMutation: photoMutation,
                editedByHumanID: normalizedActiveHumanID
            ),
            note: "plant.history.edit"
        )
        isSaving = false
        guard result.didPersist else {
            failedAction = .edit
            failureMessage = errorMessage(for: result)
            return
        }
        onCommitted(result)
        dismiss()
    }

    private func deleteRecord() {
        guard let snapshot, !isSaving else { return }
        isSaving = true
        failureMessage = nil
        failedAction = nil
        let result = editor.deleteHistory(
            PlantCareHistoryDeleteIntent(
                recordID: snapshot.recordID,
                operationID: deleteOperationID,
                expectedCareTransactionID: snapshot.careTransactionID,
                deletedByHumanID: normalizedActiveHumanID
            ),
            note: "plant.history.delete"
        )
        isSaving = false
        guard result.didPersist else {
            failedAction = .delete
            failureMessage = errorMessage(for: result)
            return
        }
        onCommitted(result)
        dismiss()
    }

    private func retryFailedAction() {
        switch failedAction {
        case .edit:
            save()
        case .delete:
            deleteRecord()
        case nil:
            loadSnapshot()
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                isLoadingPhoto = false
                guard let data else {
                    failureMessage = l.tr(
                        zh: "无法读取所选照片，请重新选择。",
                        en: "The selected photo could not be read. Choose it again.",
                        de: "Das ausgewählte Foto konnte nicht gelesen werden. Bitte erneut auswählen."
                    )
                    failedAction = nil
                    return
                }
                replacementPhotoData = data
                photoMutation = .replace(data)
            }
        }
    }

    private var normalizedActiveHumanID: String? {
        let value = activeHumanID.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func errorMessage(for result: PlantCareHistoryCommandResult) -> String {
        switch result.failure {
        case .missingRecord:
            l.tr(zh: "这条记录已不存在。", en: "This log no longer exists.", de: "Dieser Eintrag existiert nicht mehr.")
        case .wrongPlant, .scheduleSourceMismatch, .missingScheduleSource:
            l.tr(zh: "无法确认记录与原植物或计划的关联，未做更改。", en: "The link to the original plant or plan could not be verified. Nothing changed.", de: "Die Verbindung zur ursprünglichen Pflanze oder zum Plan konnte nicht bestätigt werden. Es wurde nichts geändert.")
        case .staleRecord:
            l.tr(zh: "记录已在别处改变。关闭后重新打开，再试一次。", en: "This log changed elsewhere. Close, reopen, and try again.", de: "Dieser Eintrag wurde anderswo geändert. Bitte schließen, erneut öffnen und wiederholen.")
        case .internalFeedback:
            l.tr(zh: "内部计划反馈不能在历史中编辑。", en: "Internal plan feedback cannot be edited as history.", de: "Interne Planrückmeldungen können nicht als Verlauf bearbeitet werden.")
        case .futureDate:
            l.tr(zh: "护理时间不能晚于现在。", en: "The care date cannot be in the future.", de: "Das Pflegedatum darf nicht in der Zukunft liegen.")
        case .sourceFieldsLocked:
            l.tr(zh: "计划记录的类型和时间不能修改。", en: "A plan log's type and date cannot be changed.", de: "Typ und Datum eines Planeintrags können nicht geändert werden.")
        case .reservedFeedbackNote:
            l.tr(zh: "备注不能以 defer: 或 skip: 开头，请修改后重试。", en: "Notes cannot start with defer: or skip:. Edit the note and try again.", de: "Notizen dürfen nicht mit defer: oder skip: beginnen. Bitte ändere die Notiz und versuche es erneut.")
        case .pendingRewardSettlement:
            l.tr(zh: "这条记录的奖励仍在结算。请稍后再编辑。", en: "This log's reward is still settling. Try editing it again later.", de: "Die Belohnung dieses Eintrags wird noch verarbeitet. Bitte später erneut bearbeiten.")
        case .rewardedScheduleUnsupported:
            l.tr(zh: "这条计划记录带有无法安全逆转的奖励，暂未删除。", en: "This plan log carries a reward that cannot be safely reversed, so it was not deleted.", de: "Dieser Planeintrag enthält eine Belohnung, die nicht sicher rückgängig gemacht werden kann, und wurde daher nicht gelöscht.")
        case .authorizationDenied:
            l.tr(zh: "当前成员无权修改这条计划记录。", en: "The current member cannot change this plan log.", de: "Das aktuelle Mitglied darf diesen Planeintrag nicht ändern.")
        case .scheduleReopenFailed:
            l.tr(zh: "原计划无法完整重新打开，因此没有删除记录。", en: "The original plan could not be fully reopened, so the log was kept.", de: "Der ursprüngliche Plan konnte nicht vollständig wieder geöffnet werden; der Eintrag blieb erhalten.")
        case .persistenceFailed, .none:
            result.persistenceErrorDescription ?? l.tr(
                zh: "更改未保存，请重试。",
                en: "The change was not saved. Try again.",
                de: "Die Änderung wurde nicht gespeichert. Bitte erneut versuchen."
            )
        }
    }

    private func sourceTitle(_ source: PlantCareHistorySource) -> String {
        switch source {
        case .manual:
            l.tr(zh: "手动记录", en: "Manual log", de: "Manueller Eintrag")
        case .legacy:
            l.tr(zh: "旧版记录", en: "Legacy log", de: "Älterer Eintrag")
        case .calendar:
            l.tr(zh: "日历计划", en: "Calendar plan", de: "Kalenderplan")
        case .reminder:
            l.tr(zh: "系统提醒", en: "Reminder", de: "Erinnerung")
        case .internalFeedback:
            l.tr(zh: "内部反馈", en: "Internal feedback", de: "Interne Rückmeldung")
        }
    }

    private func healthStatusTitle(_ status: PlantHealthStatus) -> String {
        switch status {
        case .thriving:
            l.tr(zh: "状态很好", en: "Thriving", de: "Sehr guter Zustand")
        case .stable:
            l.tr(zh: "稳定", en: "Stable", de: "Stabil")
        case .watching:
            l.tr(zh: "需要观察", en: "Needs watching", de: "Beobachten")
        case .stressed:
            l.tr(zh: "状态紧张", en: "Stressed", de: "Gestresst")
        }
    }

    private func careSymbol(for type: PlantCareType) -> String {
        switch type {
        case .watering: "drop.fill"
        case .fertilizing: "leaf.fill"
        case .repotting: "arrow.triangle.2.circlepath"
        case .pruning: "scissors"
        case .misting: "cloud.drizzle.fill"
        case .rotating: "rotate.3d"
        case .leafCleaning: "sparkles"
        case .pestCheck: "ladybug.fill"
        case .photo: "camera.fill"
        case .newLeaf: "leaf.circle.fill"
        case .yellowLeaf: "exclamationmark.triangle.fill"
        case .pestFound: "ant.fill"
        case .customNote: "note.text"
        }
    }
}

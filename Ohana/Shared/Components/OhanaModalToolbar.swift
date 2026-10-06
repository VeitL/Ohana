import SwiftUI

/// Standalone sheets own a stack; pushed destinations keep their parent's stack.
struct OhanaNavigationContainer<Content: View>: View {
    let ownsNavigationStack: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if ownsNavigationStack {
            NavigationStack { content() }
        } else {
            content()
        }
    }
}

/// The modal host owns navigation chrome. Content views emit intents only.
struct OhanaModalToolbar: ToolbarContent {
    let onClose: () -> Void
    var onSave: (() -> Void)?
    var isEditor = false
    var canSave = true
    var isSaving = false
    var saveTitle: String?
    var closeIdentifier = "ohana-sheet-close-action"
    var saveIdentifier = "ohana-sheet-save-action"

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some ToolbarContent {
        ToolbarItem(placement: onSave == nil && !isEditor ? .topBarTrailing : .cancellationAction) {
            Button(role: onSave == nil && !isEditor ? .close : .cancel, action: onClose) {
                if onSave == nil && !isEditor {
                    Label(l.tr(zh: "关闭", en: "Close", de: "Schließen", es: "Cerrar", pt: "Fechar", fr: "Fermer", ja: "閉じる", ko: "닫기", it: "Chiudi"), systemImage: "xmark")
                } else {
                    Text(l.cancel)
                }
            }
            .disabled(isSaving)
            .accessibilityIdentifier(closeIdentifier)
        }
        if let onSave {
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle ?? l.tr(zh: "保存", en: "Save", de: "Speichern", es: "Guardar", pt: "Salvar", fr: "Enregistrer", ja: "保存", ko: "저장", it: "Salva"), action: onSave)
                    .disabled(!canSave || isSaving)
                    .accessibilityIdentifier(saveIdentifier)
            }
        }
    }
}

nonisolated enum OhanaEditorDismissalDecision: Equatable {
    case dismiss, confirmDiscard, keepSaving

    static func resolve(hasChanges: Bool, isSaving: Bool) -> Self {
        if isSaving { return .keepSaving }
        return hasChanges ? .confirmDiscard : .dismiss
    }
}

private struct OhanaEditorChrome: ViewModifier {
    let hasChanges: Bool
    let isSaving: Bool
    let isComplete: Bool
    let canSave: Bool
    let saveTitle: String?
    let closeIdentifier: String
    let saveIdentifier: String
    let onCancel: () -> Void
    let onSave: (() -> Void)?

    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var showsDiscardConfirmation = false
    private var l: L10n { L10n(appLanguage) }

    func body(content: Content) -> some View {
        content
            .disabled(isSaving)
            .toolbar {
                OhanaModalToolbar(
                    onClose: requestCancel,
                    onSave: isComplete ? nil : onSave,
                    isEditor: !isComplete,
                    canSave: canSave,
                    isSaving: isSaving,
                    saveTitle: saveTitle,
                    closeIdentifier: closeIdentifier,
                    saveIdentifier: saveIdentifier
                )
            }
            .interactiveDismissDisabled((hasChanges && !isComplete) || isSaving)
            .confirmationDialog(
                l.tr(zh: "放弃未保存的修改？", en: "Discard unsaved changes?", de: "Ungespeicherte Änderungen verwerfen?", es: "¿Descartar los cambios sin guardar?", pt: "Descartar alterações não salvas?", fr: "Abandonner les modifications non enregistrées ?", ja: "未保存の変更を破棄しますか？", ko: "저장하지 않은 변경 사항을 버릴까요?", it: "Scartare le modifiche non salvate?"),
                isPresented: $showsDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(l.tr(zh: "放弃修改", en: "Discard changes", de: "Änderungen verwerfen", es: "Descartar cambios", pt: "Descartar alterações", fr: "Abandonner les modifications", ja: "変更を破棄", ko: "변경 사항 버리기", it: "Scarta modifiche"), role: .destructive) {
                    guard !isSaving else { return }
                    onCancel()
                }
                .accessibilityIdentifier("ohana-discard-changes-action")
                Button(l.tr(zh: "继续编辑", en: "Keep editing", de: "Weiter bearbeiten", es: "Seguir editando", pt: "Continuar editando", fr: "Continuer la modification", ja: "編集を続ける", ko: "계속 편집", it: "Continua a modificare"), role: .cancel) {}
                    .accessibilityIdentifier("ohana-keep-editing-action")
            }
    }

    private func requestCancel() {
        switch OhanaEditorDismissalDecision.resolve(hasChanges: hasChanges && !isComplete, isSaving: isSaving) {
        case .dismiss: onCancel()
        case .confirmDiscard: showsDiscardConfirmation = true
        case .keepSaving: break
        }
    }
}

extension View {
    func ohanaEditorChrome(
        hasChanges: Bool,
        isSaving: Bool = false,
        isComplete: Bool = false,
        canSave: Bool = true,
        saveTitle: String? = nil,
        closeIdentifier: String = "ohana-sheet-cancel-action",
        saveIdentifier: String = "ohana-sheet-save-action",
        onCancel: @escaping () -> Void,
        onSave: (() -> Void)?
    ) -> some View {
        modifier(OhanaEditorChrome(
            hasChanges: hasChanges, isSaving: isSaving, isComplete: isComplete, canSave: canSave,
            saveTitle: saveTitle, closeIdentifier: closeIdentifier, saveIdentifier: saveIdentifier,
            onCancel: onCancel, onSave: onSave
        ))
    }
}

struct OhanaEditorSheet<Content: View>: View {
    let title: String
    let hasChanges: Bool
    var isSaving = false
    var canSave = true
    var saveIdentifier = "ohana-sheet-save-action"
    let onCancel: () -> Void
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                content()
                    .padding(.horizontal, OhanaSpacing.pageMargin)
                    .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .ohanaEditorChrome(
                hasChanges: hasChanges, isSaving: isSaving, canSave: canSave,
                saveIdentifier: saveIdentifier,
                onCancel: onCancel, onSave: onSave
            )
        }
        .ohanaSheetPagePresentation()
    }
}

/// Destructive plan changes are confirmed by a system dialog in the current editor.
struct OhanaDeletePlanButton: View {
    let title: String
    let action: () -> Void
    @State private var showsConfirmation = false
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Button(title, role: .destructive) { showsConfirmation = true }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .confirmationDialog(
                l.tr(zh: "删除当前计划？", en: "Delete this plan?", de: "Diesen Plan löschen?", es: "¿Eliminar este plan?", pt: "Excluir este plano?", fr: "Supprimer ce programme ?", ja: "このプランを削除しますか？", ko: "이 계획을 삭제할까요?", it: "Eliminare questo piano?"),
                isPresented: $showsConfirmation, titleVisibility: .visible
            ) {
                Button(title, role: .destructive, action: action)
                    .accessibilityIdentifier("ohana-confirm-delete-plan-action")
                Button(l.cancel, role: .cancel) {}
            }
    }
}

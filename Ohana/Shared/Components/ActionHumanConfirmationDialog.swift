//
//  ActionHumanConfirmationDialog.swift
//  Ohana
//
//  One-tap confirmation for actions that do not already have a form.
//

import SwiftUI

@MainActor
struct ActionHumanConfirmationDraft: Identifiable {
    let id = UUID()
    let actionTitle: String
    let humans: [ActionHumanOption]
    let preferredHumanID: UUID?
    let perform: (String?) -> Void
}

private struct ActionHumanConfirmationDialogModifier: ViewModifier {
    @Binding var draft: ActionHumanConfirmationDraft?
    @Environment(\.ohanaAppLanguageCode) private var appLanguage

    private var l: L10n { L10n(appLanguage) }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            dialogTitle,
            isPresented: Binding(
                get: { draft != nil },
                set: { if !$0 { draft = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let draft {
                ForEach(orderedHumans(draft)) { human in
                    Button(buttonTitle(human, draft: draft)) {
                        let perform = draft.perform
                        self.draft = nil
                        perform(human.id.uuidString)
                    }
                }
            }
            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {
                draft = nil
            }
        } message: {
            if let draft,
               let preferred = draft.humans.first(where: { $0.id == draft.preferredHumanID }) {
                Text(l.tr(
                    zh: "默认记为 \(displayName(preferred)) 完成，也可以临时选择其他成员。",
                    en: "Defaults to \(displayName(preferred)). You can choose someone else for this action.",
                    de: "Standardmäßig \(displayName(preferred)). Für diese Aktion kann jemand anderes gewählt werden."
                ))
            }
        }
    }

    private var dialogTitle: String {
        guard let draft else { return "" }
        return l.tr(
            zh: "确认\(draft.actionTitle)",
            en: "Confirm \(draft.actionTitle)",
            de: "\(draft.actionTitle) bestätigen"
        )
    }

    private func orderedHumans(_ draft: ActionHumanConfirmationDraft) -> [ActionHumanOption] {
        draft.humans.sorted { lhs, rhs in
            if lhs.id == draft.preferredHumanID { return true }
            if rhs.id == draft.preferredHumanID { return false }
            return displayName(lhs).localizedStandardCompare(displayName(rhs)) == .orderedAscending
        }
    }

    private func buttonTitle(_ human: ActionHumanOption, draft: ActionHumanConfirmationDraft) -> String {
        let name = displayName(human)
        guard draft.preferredHumanID != nil else { return name }
        return human.id == draft.preferredHumanID
            ? l.tr(zh: "确认 · \(name)", en: "Confirm · \(name)", de: "Bestätigen · \(name)")
            : l.tr(zh: "改为 \(name)", en: "Use \(name)", de: "\(name) wählen")
    }

    private func displayName(_ human: ActionHumanOption) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty
            ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied")
            : name
    }
}

extension View {
    func actionHumanConfirmationDialog(draft: Binding<ActionHumanConfirmationDraft?>) -> some View {
        modifier(ActionHumanConfirmationDialogModifier(draft: draft))
    }
}

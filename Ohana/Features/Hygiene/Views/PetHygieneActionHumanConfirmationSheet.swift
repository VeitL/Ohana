//
//  PetHygieneActionHumanConfirmationSheet.swift
//  Ohana
//
//  Lightweight confirmation for sheetless hygiene check-ins in multi-Human homes.
//

import SwiftUI

struct PetHygieneActionHumanDraft: Identifiable {
    let type: HygieneType
    let initialExecutorID: UUID?

    var id: String { type.rawValue }
}

struct PetHygieneActionHumanConfirmationSheet: View {
    let draft: PetHygieneActionHumanDraft
    let humans: [ActionHumanOption]
    let tint: Color
    let onConfirm: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedExecutorID: UUID?

    init(
        draft: PetHygieneActionHumanDraft,
        humans: [ActionHumanOption],
        tint: Color,
        onConfirm: @escaping (UUID?) -> Void
    ) {
        self.draft = draft
        self.humans = humans
        self.tint = tint
        self.onConfirm = onConfirm
        _selectedExecutorID = State(initialValue: draft.initialExecutorID)
    }

    private var l: L10n { L10n(appLanguage) }
    private var resolvedExecutorID: UUID? {
        ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: selectedExecutorID,
            currentLocalHumanID: nil,
            humans: humans
        )
    }
    private var requiresExecutorSelection: Bool {
        ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans).count > 1 &&
            resolvedExecutorID == nil
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "确认护理", en: "Confirm care", de: "Pflege bestätigen"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: draft.type.systemIconName)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(tint, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.type.localizedLabel(l))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(l.tr(
                            zh: "确认本次已经完成",
                            en: "Confirm this care is complete",
                            de: "Diese Pflege als erledigt bestätigen"
                        ))
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer(minLength: 0)
                }

                ActionHumanPicker(
                    humans: humans,
                    currentLocalHumanID: draft.initialExecutorID,
                    selectedHumanID: $selectedExecutorID,
                    role: .executor,
                    tint: tint
                )

                Button {
                    guard !requiresExecutorSelection else { return }
                    onConfirm(resolvedExecutorID)
                    dismiss()
                } label: {
                    Label(
                        l.tr(zh: "确认已完成", en: "Confirm completed", de: "Als erledigt bestätigen"),
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(tint, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(requiresExecutorSelection)
                .opacity(requiresExecutorSelection ? 0.5 : 1)
                .accessibilityIdentifier("pet-hygiene-confirm-action")
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("pet-hygiene-actor-confirmation-sheet")
    }
}

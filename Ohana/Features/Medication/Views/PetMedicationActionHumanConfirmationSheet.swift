//
//  PetMedicationActionHumanConfirmationSheet.swift
//  Ohana
//
//  Lightweight, draft-scoped attribution for sheetless pet medication actions.
//

import SwiftData
import SwiftUI

nonisolated struct PetMedicationDoseActorDraft: Identifiable, Hashable, Sendable {
    let petID: UUID
    let medicationID: UUID
    let actionTitle: String
    let initialExecutorID: UUID?

    var id: String { "\(petID.uuidString)-\(medicationID.uuidString)" }
}

nonisolated struct PetMedicationDoseActorSelectionContext: Equatable, Sendable {
    let eligibleHumanCount: Int
    let defaultExecutorID: UUID?

    var needsConfirmation: Bool { eligibleHumanCount > 1 }
}

@MainActor
enum PetMedicationDoseActorSelectionResolver {
    static func resolve(
        context: ModelContext,
        currentLocalHumanIDRaw: String?
    ) -> PetMedicationDoseActorSelectionContext {
        let descriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\Human.createdAt)])
        let options = ((try? context.fetch(descriptor)) ?? []).map(option)
        let eligible = ActionHumanDefaultSelectionPolicy.eligibleHumans(from: options)
        let selectedID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: currentLocalHumanIDRaw.flatMap(UUID.init(uuidString:)),
            humans: options
        )
        return PetMedicationDoseActorSelectionContext(
            eligibleHumanCount: eligible.count,
            defaultExecutorID: selectedID
        )
    }

    static func resolvedExecutorID(draftHumanID: UUID?, humans: [ActionHumanOption]) -> UUID? {
        ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: draftHumanID,
            currentLocalHumanID: nil,
            humans: humans
        )
    }

    static func requiresSelection(draftHumanID: UUID?, humans: [ActionHumanOption]) -> Bool {
        ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans).count > 1 &&
            ActionHumanDefaultSelectionPolicy.selection(
                draftHumanID: draftHumanID,
                currentLocalHumanID: nil,
                humans: humans
            ) == nil
    }

    private static func option(_ human: Human) -> ActionHumanOption {
        ActionHumanOption(
            id: human.id,
            name: human.name,
            avatarEmoji: human.avatarEmoji,
            isDeceased: human.hasPassedAway
        )
    }
}

struct PetMedicationActionHumanConfirmationSheet: View {
    let draft: PetMedicationDoseActorDraft
    let actionHumans: [ActionHumanOption]
    let onConfirm: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedExecutorID: UUID?

    init(
        draft: PetMedicationDoseActorDraft,
        actionHumans: [ActionHumanOption],
        onConfirm: @escaping (UUID?) -> Void
    ) {
        self.draft = draft
        self.actionHumans = actionHumans
        self.onConfirm = onConfirm
        _selectedExecutorID = State(initialValue: draft.initialExecutorID)
    }

    private var l: L10n { L10n(appLanguage) }
    private var resolvedExecutorID: UUID? {
        PetMedicationDoseActorSelectionResolver.resolvedExecutorID(
            draftHumanID: selectedExecutorID,
            humans: actionHumans
        )
    }
    private var requiresExecutorSelection: Bool {
        PetMedicationDoseActorSelectionResolver.requiresSelection(
            draftHumanID: selectedExecutorID,
            humans: actionHumans
        )
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "确认喂药", en: "Confirm medication", de: "Medikamentengabe bestätigen"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text(draft.actionTitle)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "pills.fill").accessibilityHidden(true)
                        .font(OhanaFont.adaptive(size: 17, weight: .black))
                        .foregroundStyle(Color.goBlue)
                }

                ActionHumanPicker(
                    humans: actionHumans,
                    currentLocalHumanID: draft.initialExecutorID,
                    selectedHumanID: $selectedExecutorID,
                    role: .executor,
                    tint: Color.goBlue
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
                    .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(requiresExecutorSelection)
                .opacity(requiresExecutorSelection ? 0.5 : 1)
                .accessibilityIdentifier("pet-medication-dose-confirm-action")
            }
        }
        .presentationDetents([.medium])
        .presentationContentInteraction(.scrolls)
    }
}

extension View {
    func petMedicationDoseActorConfirmation(
        draft: Binding<PetMedicationDoseActorDraft?>,
        onConfirm: @escaping (PetMedicationDoseActorDraft, UUID?) -> Void
    ) -> some View {
        sheet(item: draft) { presentedDraft in
            PetMedicationActionHumanConfirmationSheetDataContainer(draft: presentedDraft) { executorID in
                onConfirm(presentedDraft, executorID)
            }
        }
    }
}

//
//  PlantQuickCareActorConfirmationSheet.swift
//  Ohana
//
//  Lightweight confirmation for sheetless plant-care actions in multi-Human homes.
//

import SwiftData
import SwiftUI

nonisolated struct PlantActionHumanSelectionContext: Equatable, Sendable {
    let eligibleHumanCount: Int
    let defaultHumanID: UUID?

    var needsConfirmation: Bool { eligibleHumanCount > 1 }
}

@MainActor
enum PlantActionHumanSelectionResolver {
    static func resolve(
        context: ModelContext,
        currentLocalHumanIDRaw: String
    ) -> PlantActionHumanSelectionContext {
        let descriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\Human.createdAt)])
        let options = ((try? context.fetch(descriptor)) ?? []).map { human in
            ActionHumanOption(
                id: human.id,
                name: human.name,
                avatarEmoji: human.avatarEmoji,
                isDeceased: human.hasPassedAway
            )
        }
        let eligibleHumans = ActionHumanDefaultSelectionPolicy.eligibleHumans(from: options)
        let defaultHumanID = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: nil,
            currentLocalHumanID: UUID(uuidString: currentLocalHumanIDRaw),
            humans: options
        )
        return PlantActionHumanSelectionContext(
            eligibleHumanCount: eligibleHumans.count,
            defaultHumanID: defaultHumanID
        )
    }
}

@MainActor
enum PlantActionHumanDraftValidator {
    static func resolvedHumanID(draftHumanID: UUID?, humans: [Human]) -> UUID? {
        ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: draftHumanID,
            currentLocalHumanID: nil,
            humans: options(from: humans)
        )
    }

    static func requiresSelection(draftHumanID: UUID?, humans: [Human]) -> Bool {
        let options = options(from: humans)
        return ActionHumanDefaultSelectionPolicy.eligibleHumans(from: options).count > 1 &&
            ActionHumanDefaultSelectionPolicy.selection(
                draftHumanID: draftHumanID,
                currentLocalHumanID: nil,
                humans: options
            ) == nil
    }

    private static func options(from humans: [Human]) -> [ActionHumanOption] {
        humans.map { human in
            ActionHumanOption(
                id: human.id,
                name: human.name,
                avatarEmoji: human.avatarEmoji,
                isDeceased: human.hasPassedAway
            )
        }
    }
}

nonisolated struct PlantQuickCareActorDraft: Identifiable, Hashable, Sendable {
    let plantID: UUID
    let plantName: String
    let careType: PlantCareType
    let initialExecutorID: UUID?

    var id: String { "\(plantID.uuidString)-\(careType.rawValue)" }
}

struct PlantQuickCareActorConfirmationSheet: View {
    let draft: PlantQuickCareActorDraft
    let onConfirm: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var selectedExecutorID: UUID?
    @State private var requiresExecutorSelection = false

    init(
        draft: PlantQuickCareActorDraft,
        onConfirm: @escaping (UUID?) -> Void
    ) {
        self.draft = draft
        self.onConfirm = onConfirm
        _selectedExecutorID = State(initialValue: draft.initialExecutorID)
    }

    private var l: L10n { L10n(appLanguage) }
    private var tint: Color {
        switch draft.careType {
        case .watering, .misting:
            Color.goTeal
        case .fertilizing, .newLeaf:
            Color.goPrimary
        case .yellowLeaf, .pestFound:
            Color.goRed
        case .repotting, .pruning, .rotating, .leafCleaning, .pestCheck, .photo, .customNote:
            Color.goYellow
        }
    }

    var body: some View {
        OhanaSheetWrapper(
            title: l.tr(zh: "确认护理", en: "Confirm care", de: "Pflege bestätigen"),
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: careSymbol)
                        .font(OhanaFont.adaptive(size: 18, weight: .black))
                        .foregroundStyle(Color.arkInk)
                        .frame(width: 44, height: 44)
                        .background(tint, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(draft.careType.displayName(l: l))
                            .font(OhanaFont.callout(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(draft.plantName)
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }

                QuickCareActionHumanPickerContainer(
                    selectedHumanID: $selectedExecutorID,
                    requiresSelection: $requiresExecutorSelection,
                    role: .executor,
                    tint: tint
                )

                Button {
                    guard !requiresExecutorSelection else { return }
                    onConfirm(selectedExecutorID)
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
                .accessibilityIdentifier("plant-quick-care-confirm-action")
            }
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("plant-quick-care-actor-confirmation-sheet")
    }

    private var careSymbol: String {
        switch draft.careType {
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

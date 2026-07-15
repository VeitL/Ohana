//
//  ActionHumanPicker.swift
//  Ohana
//
//  Lightweight, draft-scoped Human attribution for care and record actions.
//

import Foundation
import SwiftData
import SwiftUI

nonisolated struct ActionHumanOption: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let avatarEmoji: String
    let isDeceased: Bool

    init(
        id: UUID,
        name: String,
        avatarEmoji: String = "👤",
        isDeceased: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.isDeceased = isDeceased
    }
}

nonisolated enum ActionHumanRole: Hashable, Sendable {
    case executor
    case recorder
    case payer
    case participants
}

nonisolated enum ActionHumanDefaultSelectionPolicy {
    static func eligibleHumans(from humans: [ActionHumanOption]) -> [ActionHumanOption] {
        humans.filter { !$0.isDeceased }
    }

    /// Resolves a safe draft selection without mutating the device's current Human.
    ///
    /// An existing valid draft always wins. When an existing draft becomes invalid and
    /// multiple Humans remain, returning `nil` forces an explicit choice instead of
    /// silently attributing the action to somebody else.
    static func selection(
        draftHumanID: UUID?,
        currentLocalHumanID: UUID?,
        humans: [ActionHumanOption]
    ) -> UUID? {
        let eligible = eligibleHumans(from: humans)
        let eligibleIDs = Set(eligible.map(\.id))

        if let draftHumanID {
            if eligibleIDs.contains(draftHumanID) {
                return draftHumanID
            }
            return eligible.count == 1 ? eligible[0].id : nil
        }

        if let currentLocalHumanID, eligibleIDs.contains(currentLocalHumanID) {
            return currentLocalHumanID
        }

        return eligible.count == 1 ? eligible[0].id : nil
    }
}

@MainActor
enum ActionHumanOptionLoader {
    static func load(context: ModelContext) -> [ActionHumanOption] {
        var descriptor = FetchDescriptor<Human>(sortBy: [SortDescriptor(\Human.createdAt)])
        descriptor.fetchLimit = 64
        do {
            return try context.fetch(descriptor).map { human in
                ActionHumanOption(
                    id: human.id,
                    name: human.name,
                    avatarEmoji: human.avatarEmoji,
                    isDeceased: human.hasPassedAway
                )
            }
        } catch {
            OhanaLog.warning(
                "Action Human options failed to load: \(error.localizedDescription)",
                category: "Care"
            )
            return []
        }
    }
}

struct ActionHumanPicker: View {
    let humans: [ActionHumanOption]
    let currentLocalHumanID: UUID?
    let role: ActionHumanRole
    var tint: Color = .goPrimary
    var compact = true

    @Binding private var selectedHumanID: UUID?
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var isChoosingHuman = false

    init(
        humans: [ActionHumanOption],
        currentLocalHumanID: UUID?,
        selectedHumanID: Binding<UUID?>,
        role: ActionHumanRole = .executor,
        tint: Color = .goPrimary,
        compact: Bool = true
    ) {
        self.humans = humans
        self.currentLocalHumanID = currentLocalHumanID
        self.role = role
        self.tint = tint
        self.compact = compact
        _selectedHumanID = selectedHumanID
    }

    private var eligibleHumans: [ActionHumanOption] {
        ActionHumanDefaultSelectionPolicy.eligibleHumans(from: humans)
    }

    private var selectedHuman: ActionHumanOption? {
        eligibleHumans.first { $0.id == selectedHumanID }
    }

    private var selectionContext: SelectionContext {
        SelectionContext(
            eligibleHumanIDs: eligibleHumans.map(\.id),
            currentLocalHumanID: currentLocalHumanID,
            draftHumanID: selectedHumanID
        )
    }

    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        Group {
            if eligibleHumans.count > 1 {
                pickerButton
            }
        }
        .onAppear(perform: reconcileDraftSelection)
        .onChange(of: selectionContext) { _, _ in
            reconcileDraftSelection()
        }
    }

    private var pickerButton: some View {
        Button {
            isChoosingHuman = true
        } label: {
            HStack(spacing: 8) {
                Text(selectedHuman?.avatarEmoji ?? "👤")
                    .font(.body)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(roleTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Text(selectedHuman.map(displayName) ?? choosePrompt)
                        .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, compact ? 6 : 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.ohanaCardSurface)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(selectedHuman == nil ? 0.7 : 0.32), lineWidth: 1)
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("\(roleTitle)：\(selectedHuman.map(displayName) ?? choosePrompt)")
        .accessibilityHint(changeHint)
        .confirmationDialog(
            dialogTitle,
            isPresented: $isChoosingHuman,
            titleVisibility: .visible
        ) {
            ForEach(eligibleHumans) { human in
                Button {
                    selectedHumanID = human.id
                } label: {
                    Label(
                        displayName(human),
                        systemImage: human.id == selectedHumanID ? "checkmark.circle.fill" : "circle"
                    )
                }
            }

            Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen"), role: .cancel) {}
        }
    }

    private func reconcileDraftSelection() {
        let resolved = ActionHumanDefaultSelectionPolicy.selection(
            draftHumanID: selectedHumanID,
            currentLocalHumanID: currentLocalHumanID,
            humans: humans
        )
        guard resolved != selectedHumanID else { return }
        selectedHumanID = resolved
    }

    private func displayName(_ human: ActionHumanOption) -> String {
        let trimmedName = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty
            ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied")
            : trimmedName
    }

    private var roleTitle: String {
        switch role {
        case .executor:
            l.tr(zh: "这次由谁完成", en: "Who did this", de: "Wer hat das erledigt")
        case .recorder:
            l.tr(zh: "这次由谁记录", en: "Who recorded this", de: "Wer hat das erfasst")
        case .payer:
            l.tr(zh: "这次由谁支付", en: "Who paid this", de: "Wer hat das bezahlt")
        case .participants:
            l.tr(zh: "这次谁参与", en: "Who joined", de: "Wer war dabei")
        }
    }

    private var choosePrompt: String {
        switch role {
        case .executor:
            l.tr(zh: "选择完成这件事的人", en: "Choose who did it", de: "Person auswählen")
        case .recorder:
            l.tr(zh: "选择记录这件事的人", en: "Choose who recorded it", de: "Erfassende Person wählen")
        case .payer:
            l.tr(zh: "选择支付这笔花费的人", en: "Choose who paid", de: "Zahlende Person wählen")
        case .participants:
            l.tr(zh: "选择参与的人", en: "Choose a participant", de: "Teilnehmende Person wählen")
        }
    }

    private var dialogTitle: String {
        switch role {
        case .executor:
            l.tr(zh: "谁完成了这件事？", en: "Who completed this?", de: "Wer hat das erledigt?")
        case .recorder:
            l.tr(zh: "谁记录了这件事？", en: "Who recorded this?", de: "Wer hat das erfasst?")
        case .payer:
            l.tr(zh: "谁支付了这笔花费？", en: "Who paid this expense?", de: "Wer hat diese Ausgabe bezahlt?")
        case .participants:
            l.tr(zh: "谁参与了这件事？", en: "Who participated?", de: "Wer war beteiligt?")
        }
    }

    private var changeHint: String {
        l.tr(
            zh: "轻点可为这次操作选择其他家庭成员",
            en: "Choose a different household member for this action",
            de: "Ein anderes Haushaltsmitglied für diese Aktion auswählen"
        )
    }
}

private nonisolated struct SelectionContext: Hashable {
    let eligibleHumanIDs: [UUID]
    let currentLocalHumanID: UUID?
    let draftHumanID: UUID?
}

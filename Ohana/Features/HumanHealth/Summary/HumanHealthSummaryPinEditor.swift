//
//  HumanHealthSummaryPinEditor.swift
//  Ohana
//

import SwiftUI

struct HumanHealthSummaryPinEditor: View {
    let onSave: ([HumanHealthSummaryDestination]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var items: [HumanHealthSummaryDestination]

    init(
        initialItems: [HumanHealthSummaryDestination],
        onSave: @escaping ([HumanHealthSummaryDestination]) -> Void
    ) {
        self.onSave = onSave
        _items = State(initialValue: HumanHealthSummaryPinPreference.normalized(initialItems))
    }

    private var l: L10n { L10n(appLanguage) }
    private var availableItems: [HumanHealthSummaryDestination] {
        HumanHealthSummaryPinPreference.availableItems.filter { !items.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if items.isEmpty {
                        Text(l.tr(
                            zh: "还没有重点项目。可从下方添加。",
                            en: "No pinned items yet. Add one below.",
                            de: "Noch nichts fixiert. Unten hinzufügen."
                        ))
                        .foregroundStyle(Color.ohanaSecondaryText)
                    } else {
                        ForEach(items) { item in
                            Label(item.title(l), systemImage: item.systemImage)
                                .foregroundStyle(Color.ohanaPrimaryText)
                                .accessibilityIdentifier("human-health-pin-editor-item-\(item.rawValue)")
                        }
                        .onMove { offsets, destination in
                            items.move(fromOffsets: offsets, toOffset: destination)
                        }
                        .onDelete { offsets in
                            items.remove(atOffsets: offsets)
                        }
                    }
                } header: {
                    Text(l.tr(zh: "已固定 · 可拖动排序", en: "Pinned · drag to reorder", de: "Fixiert · zum Sortieren ziehen"))
                }

                if !availableItems.isEmpty {
                    Section(l.tr(zh: "可添加", en: "Available", de: "Verfügbar")) {
                        ForEach(availableItems) { item in
                            Button {
                                items.append(item)
                            } label: {
                                HStack {
                                    Label(item.title(l), systemImage: item.systemImage)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill") // a11y: allow decorative action affordance; button text supplies the label
                                        .foregroundStyle(Color.goPrimary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .accessibilityIdentifier("human-health-pin-editor-add-\(item.rawValue)")
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(l.tr(zh: "编辑重点项目", en: "Edit Pinned Items", de: "Fixierte Bereiche bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        onSave(items)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .accessibilityIdentifier("human-health-pin-editor")
    }
}

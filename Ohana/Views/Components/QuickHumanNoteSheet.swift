//
//  QuickHumanNoteSheet.swift
//  Ohana
//

import SwiftUI
import SwiftData

struct QuickHumanNoteSheet: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var noteText = ""
    @State private var date = Date()

    var body: some View {
        ZStack {
            ArkBackgroundView().ignoresSafeArea()
            VStack(spacing: 20) {
                // 标题栏
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(OhanaFont.title2())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("快速备注")
                        .font(OhanaFont.headline(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("保存") { save() }
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(
                            noteText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.primary.opacity(0.3) : Color.goLime
                        )
                        .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 输入区
                UltimateGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .foregroundStyle(Color.goPrimary)
                            Text(human.name)
                                .font(OhanaFont.subheadline(.bold))
                                .foregroundStyle(.primary.opacity(0.8))
                        }
                        TextEditor(text: $noteText)
                            .font(OhanaFont.body())
                            .foregroundStyle(.primary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 16)

                // 日期行
                UltimateGlassCard {
                    HStack {
                        Label("日期", systemImage: "calendar")
                            .font(OhanaFont.callout(.semibold))
                            .foregroundStyle(.primary.opacity(0.7))
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .tint(Color.goPrimary)
                    }
                    .padding(16)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    private func save() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let entry = "[\(fmt.string(from: date))] \(noteText.trimmingCharacters(in: .whitespaces))"
        human.notes = human.notes.isEmpty ? entry : human.notes + "\n\n" + entry
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

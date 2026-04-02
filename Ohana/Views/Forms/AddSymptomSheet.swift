//
//  AddSymptomSheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct AddSymptomSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var category: SymptomCategory = .digestive
    @State private var symptomName: String = ""
    @State private var severity: SymptomSeverity = .mild
    @State private var note: String = ""

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("类别").font(.system(size: 15, weight: .bold))
                        Spacer()
                        Picker("", selection: $category) {
                            ForEach(SymptomCategory.allCases, id: \.self) { cat in
                                Text("\(cat.emoji) \(cat.rawValue)").tag(cat)
                            }
                        }
                        .tint(themeColor)
                    }
                    
                    TextField("具体症状 (如: 频繁呕吐黄水)", text: $symptomName)
                        .font(.system(size: 15, weight: .medium))
                    
                    DatePicker("发生时间", selection: $selectedDate)
                        .font(.system(size: 15, weight: .bold))
                } header: {
                    Text("症状描述").font(.system(size: 12, weight: .medium, design: .rounded))
                }

                Section {
                    Picker("严重程度", selection: $severity) {
                        ForEach(SymptomSeverity.allCases, id: \.self) { level in
                            HStack {
                                Image(systemName: level.icon)
                                Text(level.label)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(severityColor(severity))
                } header: {
                    Text("严重程度").font(.system(size: 12, weight: .medium, design: .rounded))
                } footer: {
                    Text("严重或紧急的情况将触发首页警告并建议就医。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("添加补充说明 (如有无用药、精神状态)...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color(uiColor: .placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $note)
                            .frame(minHeight: 100)
                            .padding(.horizontal, -4)
                    }
                } header: {
                    Text("详细记录").font(.system(size: 12, weight: .medium, design: .rounded))
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text("保存记录")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(themeColor)
                    .disabled(symptomName.isEmpty)
                }
            }
            .navigationTitle("记录异常症状")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func severityColor(_ severity: SymptomSeverity) -> Color {
        switch severity {
        case .mild: return Color.green
        case .moderate: return Color.orange
        case .severe: return Color.red
        case .critical: return Color(hex: "8B0000") // Dark Red
        }
    }

    private func save() {
        let log = SymptomLog(
            date: selectedDate,
            category: category,
            symptomName: symptomName.trimmingCharacters(in: .whitespacesAndNewlines),
            severity: severity,
            note: note,
            pet: pet
        )
        modelContext.insert(log)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

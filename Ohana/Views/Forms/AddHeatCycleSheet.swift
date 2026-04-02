//
//  AddHeatCycleSheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct AddHeatCycleSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 7)
    @State private var hasEndDate = false
    @State private var status: HeatCycleStatus = .proestrus
    @State private var isMated = false
    @State private var expectedDeliveryDate = Date().addingTimeInterval(86400 * 63)
    @State private var note: String = ""

    private var themeColor: Color { Color(hex: pet.themeColorHex) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("当前阶段", selection: $status) {
                        ForEach(HeatCycleStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .tint(themeColor)
                    
                    DatePicker("开始时间", selection: $startDate, displayedComponents: .date)
                    
                    Toggle("已知结束时间", isOn: $hasEndDate).tint(themeColor)
                    if hasEndDate {
                        DatePicker("结束时间", selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    Text("生理期状态").font(.system(size: 12, weight: .medium, design: .rounded))
                }

                if status == .estrus || status == .pregnant {
                    Section {
                        Toggle("已发生交配", isOn: $isMated).tint(themeColor)
                        if isMated || status == .pregnant {
                            DatePicker("预计产期", selection: $expectedDeliveryDate, displayedComponents: .date)
                                .tint(.pink)
                        }
                    } header: {
                        Text("繁育记录").font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                }

                Section {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                } header: {
                    Text("备注说明 (可选)").font(.system(size: 12, weight: .medium, design: .rounded))
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
                }
            }
            .navigationTitle("记录生理期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if status == .pregnant { isMated = true }
            }
        }
    }

    private func save() {
        let log = HeatCycleLog(
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            status: status,
            note: note,
            isMated: isMated,
            expectedDeliveryDate: (isMated || status == .pregnant) ? expectedDeliveryDate : nil,
            pet: pet
        )
        modelContext.insert(log)
        modelContext.safeSave()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

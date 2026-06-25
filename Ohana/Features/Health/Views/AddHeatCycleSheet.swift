//
//  AddHeatCycleSheet.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftData
import SwiftUI

struct AddHeatCycleSheet: View {
    let pet: Pet
    var onSaved: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(86400 * 7)
    @State private var hasEndDate = false
    @State private var status: HeatCycleStatus = .proestrus
    @State private var isMated = false
    @State private var expectedDeliveryDate = Date().addingTimeInterval(86400 * 63)
    @State private var note: String = ""
    @State private var isSaving = false

    private var themeColor: Color { Color(hex: pet.themeColorHex) }
    private var l: L10n { L10n(appLanguage) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(l.tr(zh: "当前阶段", en: "Current stage", de: "Aktuelle Phase"), selection: $status) {
                        ForEach(HeatCycleStatus.allCases, id: \.self) { s in
                            Text(statusTitle(s)).tag(s)
                        }
                    }
                    .tint(themeColor)

                    DatePicker(l.tr(zh: "开始时间", en: "Start date", de: "Startdatum"), selection: $startDate, displayedComponents: .date)

                    Toggle(l.tr(zh: "已知结束时间", en: "Known end date", de: "Enddatum bekannt"), isOn: $hasEndDate).tint(themeColor)
                    if hasEndDate {
                        DatePicker(l.tr(zh: "结束时间", en: "End date", de: "Enddatum"), selection: $endDate, displayedComponents: .date)
                    }
                } header: {
                    Text(l.tr(zh: "生理期状态", en: "Heat Cycle Status", de: "Läufigkeitsstatus"))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                }

                if status == .estrus || status == .pregnant {
                    Section {
                        Toggle(l.tr(zh: "已发生交配", en: "Mating occurred", de: "Deckakt erfolgt"), isOn: $isMated).tint(themeColor)
                        if isMated || status == .pregnant {
                            DatePicker(l.tr(zh: "预计产期", en: "Expected delivery", de: "Voraussichtlicher Wurftermin"), selection: $expectedDeliveryDate, displayedComponents: .date)
                                .tint(.pink)
                        }
                    } header: {
                        Text(l.tr(zh: "繁育记录", en: "Breeding Record", de: "Zuchtprotokoll"))
                            .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    }
                }

                Section {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                } header: {
                    Text(l.tr(zh: "备注说明（可选）", en: "Notes (optional)", de: "Notizen (optional)"))
                        .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text(isSaving
                            ? l.tr(zh: "保存中...", en: "Saving...", de: "Speichert...")
                            : l.tr(zh: "保存记录", en: "Save Record", de: "Eintrag speichern"))
                            .font(OhanaFont.adaptive(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(themeColor)
                    .disabled(isSaving || !pet.canWriteHealthFacts)
                }
            }
            .navigationTitle(l.tr(zh: "记录生理期", en: "Log Heat Cycle", de: "Läufigkeit erfassen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l.tr(zh: "取消", en: "Cancel", de: "Abbrechen")) { dismiss() }
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .onAppear {
                if status == .pregnant { isMated = true }
            }
            .onDisappear {
                commandQueue.cancelAll()
            }
        }
    }

    private func save() {
        guard !isSaving, pet.canWriteHealthFacts else { return }
        let input = PetHeatCycleCommandInput(
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            status: status,
            note: note,
            isMated: isMated,
            expectedDeliveryDate: (isMated || status == .pregnant) ? expectedDeliveryDate : nil
        )
        let command = DomainCommand.petHealthRecord(petID: pet.id, type: "heat")

        isSaving = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        commandQueue.enqueue(command) {
            guard PetHealthCommandExecutor(context: modelContext, services: appServices).recordHeatCycle(
                pet: pet,
                input: input,
                note: "pet.heat.record"
            ) != nil else {
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSaved?()
            dismiss()
        }
    }

    private func statusTitle(_ status: HeatCycleStatus) -> String {
        switch status {
        case .proestrus:
            l.tr(zh: "发情前期", en: "Proestrus", de: "Proöstrus")
        case .estrus:
            l.tr(zh: "发情期", en: "Estrus", de: "Östrus")
        case .diestrus:
            l.tr(zh: "发情后期", en: "Diestrus", de: "Diöstrus")
        case .anestrus:
            l.tr(zh: "休情期", en: "Anestrus", de: "Anöstrus")
        case .pregnant:
            l.tr(zh: "孕期", en: "Pregnancy", de: "Trächtigkeit")
        case .nursing:
            l.tr(zh: "哺乳期", en: "Nursing", de: "Säugezeit")
        }
    }
}

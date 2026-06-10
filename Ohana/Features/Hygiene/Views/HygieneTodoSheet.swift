//
//  HygieneTodoSheet.swift
//  Ohana
//
//  Lightweight hygiene plan sheet backed by PetHygieneCommandExecutor.
//

import SwiftData
import SwiftUI

struct HygieneTodoSheet: View {
    let pet: Pet
    let type: HygieneType
    let accent: Color
    let onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices

    @State private var startDate: Date
    @State private var startTime: Date
    @State private var isAllDay: Bool
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var repeatDays: Int
    @State private var customNote: String

    init(
        pet: Pet,
        type: HygieneType,
        accent: Color,
        onSaved: @escaping () -> Void
    ) {
        let now = Date()
        let defaultRepeatDays = type.effectiveCycleDays(for: pet.id)
        self.pet = pet
        self.type = type
        self.accent = accent
        self.onSaved = onSaved
        _startDate = State(initialValue: now)
        _startTime = State(initialValue: now)
        _isAllDay = State(initialValue: true)
        _hasEndDate = State(initialValue: false)
        _endDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        _repeatDays = State(initialValue: max(defaultRepeatDays, 1))
        _customNote = State(initialValue: "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    scheduleSection
                    recurrenceSection
                    noteSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(OhanaAppBackground().ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(accent)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: type.systemIconName)
                .font(OhanaFont.adaptive(size: 18, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(type.rawValue)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text("为 \(pet.name) 添加护理计划")
                    .font(OhanaFont.adaptive(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("时间")

            Toggle("全天", isOn: $isAllDay)
                .tint(accent)

            DatePicker("开始日期", selection: $startDate, displayedComponents: .date)

            if !isAllDay {
                DatePicker("提醒时间", selection: $startTime, displayedComponents: .hourAndMinute)
            }

            Toggle("结束日期", isOn: $hasEndDate)
                .tint(accent)

            if hasEndDate {
                DatePicker("结束", selection: $endDate, displayedComponents: .date)
            }
        }
        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("重复")

            Stepper(value: $repeatDays, in: 0...365) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(recurrenceLabel)
                        .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("0 表示只提醒一次")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("备注")

            TextField("可选", text: $customNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .font(OhanaFont.adaptive(size: 14, weight: .semibold, design: .rounded))
                .padding(12)
                .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(Color.ohanaSecondaryText)
    }

    private var recurrenceLabel: String {
        switch repeatDays {
        case 0: return "不重复"
        case 1: return "每天"
        case 7: return "每周"
        case 14: return "每两周"
        case 30: return "每月"
        default: return "每 \(repeatDays) 天"
        }
    }

    private func save() {
        let input = PetHygienePlanCommandInput(
            startDate: startDate,
            isAllDay: isAllDay,
            startTime: startTime,
            hasEndDate: hasEndDate,
            endDate: endDate,
            repeatDays: repeatDays,
            customNote: customNote
        )
        PetHygieneCommandExecutor(context: modelContext, services: appServices).createPlan(
            pet: pet,
            type: type,
            input: input,
            note: "PetHygieneDetailView.HygieneTodoSheet"
        )
        onSaved()
        dismiss()
    }
}

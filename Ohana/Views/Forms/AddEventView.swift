//
//  AddEventView.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    
    @State private var title = ""
    @State private var eventType: EventType = .daily
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isAllDay = false
    @State private var hasEndDate = false
    @State private var relatedEntityType = ""
    @State private var relatedEntityId = ""
    @State private var recurrenceDays = 1
    @State private var hasRecurrence = false
    @State private var recurrenceEndDate = Date()
    @State private var hasRecurrenceEnd = false
    @State private var reminderAdvanceDays = 0
    @State private var hasReminder = true
    
    var body: some View {
        OhanaSheetWrapper(title: "添加事件", onDismiss: { dismiss() }) {
            VStack(spacing: 20) {
                // 标题
                VStack(alignment: .leading, spacing: 4) {
                    Text("事件标题")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("输入标题", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 事件类型
                VStack(alignment: .leading, spacing: 8) {
                    Text("事件类型")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EventType.allCases) { type in
                                Button {
                                    eventType = type
                                    if title.isEmpty {
                                        title = type.rawValue
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(type.emoji)
                                        Text(type.rawValue)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(eventType == type ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        eventType == type ? Color.arkCoral : Color.gray.opacity(0.15),
                                        in: Capsule()
                                    )
                                }
                            }
                        }
                    }
                }
                
                // 时间
                VStack(spacing: 12) {
                    Toggle("全天事件", isOn: $isAllDay)
                        .tint(.arkCoral)
                    
                    DatePicker("开始时间", selection: $startDate,
                               displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    
                    Toggle("设置结束时间", isOn: $hasEndDate)
                        .tint(.arkCoral)
                    
                    if hasEndDate {
                        DatePicker("结束时间", selection: $endDate,
                                   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    }
                }
                
                // 关联实体
                VStack(alignment: .leading, spacing: 8) {
                    Text("关联对象")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                relatedEntityType = ""
                                relatedEntityId = ""
                            } label: {
                                Text("无")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(relatedEntityType.isEmpty ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        relatedEntityType.isEmpty ? Color.arkCoral : Color.gray.opacity(0.15),
                                        in: Capsule()
                                    )
                            }
                            
                            ForEach(pets) { pet in
                                Button {
                                    relatedEntityType = "Pet"
                                    relatedEntityId = pet.id.uuidString
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(pet.avatarEmoji)
                                        Text(pet.name)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(relatedEntityId == pet.id.uuidString ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        relatedEntityId == pet.id.uuidString ? Color.arkCoral : Color.gray.opacity(0.15),
                                        in: Capsule()
                                    )
                                }
                            }
                            
                            ForEach(humans) { human in
                                Button {
                                    relatedEntityType = "Human"
                                    relatedEntityId = human.id.uuidString
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(human.avatarEmoji)
                                        Text(human.name)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(relatedEntityId == human.id.uuidString ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        relatedEntityId == human.id.uuidString ? Color.arkCoral : Color.gray.opacity(0.15),
                                        in: Capsule()
                                    )
                                }
                            }
                        }
                    }
                }
                
                // 循环
                VStack(spacing: 12) {
                    Toggle("循环事件", isOn: $hasRecurrence)
                        .tint(.arkCoral)
                    
                    if hasRecurrence {
                        Stepper("每 \(recurrenceDays) 天", value: $recurrenceDays, in: 1...365)
                        
                        Toggle("设置循环结束日期", isOn: $hasRecurrenceEnd)
                            .tint(.arkCoral)
                        
                        if hasRecurrenceEnd {
                            DatePicker("结束日期", selection: $recurrenceEndDate, displayedComponents: .date)
                        }
                    }
                }
                
                // 提醒
                Toggle("创建提醒", isOn: $hasReminder)
                    .tint(.arkCoral)
                
                if hasReminder {
                    Stepper("提前 \(reminderAdvanceDays) 天提醒", value: $reminderAdvanceDays, in: 0...30)
                }
                
                // 保存
                Button {
                    saveEvent()
                } label: {
                    Text("添加事件")
                        .capsuleButton()
                }
                .disabled(title.isEmpty)
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
    }
    
    private func saveEvent() {
        let event = Event(
            title: title,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            isAllDay: isAllDay,
            eventType: eventType.rawValue,
            relatedEntityType: relatedEntityType,
            relatedEntityId: relatedEntityId
        )
        event.recurrenceDays = hasRecurrence ? recurrenceDays : 0
        event.recurrenceEndDate = hasRecurrenceEnd ? recurrenceEndDate : nil
        modelContext.insert(event)

        if hasReminder {
            let cal = Calendar.current
            // 任务1修复：严格要求 recurrenceDays >= 1，防止步长为0死循环
            if hasRecurrence && recurrenceDays >= 1 {
                // hardCap = 用户设定的结束日期，否则最多 startDate+365 天
                // 绝对不允许超出 hardCap
                let hardCap: Date = hasRecurrenceEnd
                    ? recurrenceEndDate
                    : (cal.date(byAdding: .day, value: 365, to: startDate) ?? startDate)
                var cursor = startDate
                var safetyCount = 0
                let maxOccurrences = 500   // 绝对上限，防御性保护
                while cursor <= hardCap && safetyCount < maxOccurrences {
                    let scheduled = cal.date(byAdding: .day, value: -reminderAdvanceDays, to: cursor) ?? cursor
                    let r = Reminder(event: event, scheduledAt: scheduled)
                    modelContext.insert(r)
                    guard let next = cal.date(byAdding: .day, value: recurrenceDays, to: cursor),
                          next > cursor else { break }   // 步进必须向前，否则中止
                    cursor = next
                    safetyCount += 1
                }
            } else {
                // 单次事件
                let scheduled = cal.date(byAdding: .day, value: -reminderAdvanceDays, to: startDate) ?? startDate
                let r = Reminder(event: event, scheduledAt: scheduled)
                modelContext.insert(r)
            }
        }

        modelContext.safeSave()
        dismiss()
    }
}

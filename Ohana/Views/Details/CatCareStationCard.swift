//
//  CatCareStationCard.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

enum CatCareAction: String, CaseIterable {
    case litter = "铲猫砂"
    case feed = "喂食"
    case water = "喂水"
    
    var emoji: String {
        switch self {
        case .litter: return "🧹"
        case .feed: return "🥩"
        case .water: return "💧"
        }
    }
}

struct CatCareStationCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate, order: .reverse) private var allEvents: [Event]
    
    @State private var recentAction: CatCareAction?
    @State private var undoTimer: Timer?
    @State private var undoEvent: Event?
    @State private var undoHygieneLog: PetHygieneLog?
    @State private var showHistory = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            Button { showHistory = true } label: {
                HStack {
                    Text("🐱")
                        .font(.system(size: 18))
                    Text("猫咪护理站")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            
            // 操作按钮
            HStack(spacing: 12) {
                ForEach(CatCareAction.allCases, id: \.rawValue) { action in
                    careButton(action: action)
                }
            }
            
            // 撤回提示
            if let recentAction {
                HStack {
                    Text("\(recentAction.emoji) 已打卡")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                    Spacer()
                    Button {
                        undoAction()
                    } label: {
                        Text("撤回")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 今日统计
            todayStats
        }
        .padding(16)
        .ohanaGlassStyle(cornerRadius: 20)
        .sheet(isPresented: $showHistory) {
            CatCareHistorySheet(pet: pet)
        }
    }
    
    // MARK: - Care Button
    private func careButton(action: CatCareAction) -> some View {
        Button {
            performAction(action)
        } label: {
            VStack(spacing: 6) {
                Text(action.emoji)
                    .font(.system(size: 24))
                Text(action.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            }
        }
    }
    
    // MARK: - Today Stats
    private var todayStats: some View {
        HStack(spacing: 16) {
            ForEach(CatCareAction.allCases, id: \.rawValue) { action in
                let count = todayCount(for: action)
                HStack(spacing: 4) {
                    Text(action.emoji)
                        .font(.system(size: 12))
                    Text("×\(count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(count > 0 ? .primary : .secondary)
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Actions
    private func performAction(_ action: CatCareAction) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        let event = Event(
            title: "\(action.emoji) \(action.rawValue)",
            startDate: Date(),
            isAllDay: false,
            eventType: EventType.litterBox.rawValue,
            relatedEntityType: "Pet",
            relatedEntityId: pet.id.uuidString
        )
        modelContext.insert(event)
        undoEvent = event
        
        if action == .litter {
            let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                .flatMap { $0.isEmpty ? nil : $0 }
            let hygieneLog = PetHygieneLog(date: Date(), type: .bath, pet: pet, executorId: executorId)
            modelContext.insert(hygieneLog)
            undoHygieneLog = hygieneLog
        }
        
        modelContext.safeSave()
        
        withAnimation(.spring(response: 0.3)) {
            recentAction = action
        }
        
        // 4秒后自动隐藏撤回
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            withAnimation {
                recentAction = nil
                undoEvent = nil
                undoHygieneLog = nil
            }
        }
    }
    
    private func undoAction() {
        if let event = undoEvent {
            modelContext.delete(event)
        }
        if let log = undoHygieneLog {
            modelContext.delete(log)
        }
        modelContext.safeSave()
        
        withAnimation {
            recentAction = nil
            undoEvent = nil
            undoHygieneLog = nil
        }
        undoTimer?.invalidate()
    }
    
    private func todayCount(for action: CatCareAction) -> Int {
        allEvents.filter {
            $0.relatedEntityId == pet.id.uuidString &&
            $0.eventType == EventType.litterBox.rawValue &&
            Calendar.current.isDateInToday($0.startDate) &&
            $0.title.contains(action.rawValue)
        }.count
    }
}

// MARK: - Cat Care History Sheet
struct CatCareHistorySheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Event.startDate, order: .reverse) private var allEvents: [Event]
    
    private var catCareEvents: [Event] {
        allEvents.filter {
            $0.relatedEntityId == pet.id.uuidString &&
            $0.eventType == EventType.litterBox.rawValue
        }
    }
    
    var body: some View {
        OhanaSheetWrapper(title: "护理记录", onDismiss: { dismiss() }) {
            if catCareEvents.isEmpty {
                VStack(spacing: 12) {
                    Text("🐱")
                        .font(.system(size: 48))
                    Text("暂无护理记录")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            } else {
                let grouped = Dictionary(grouping: catCareEvents) {
                    Calendar.current.startOfDay(for: $0.startDate)
                }.sorted { $0.key > $1.key }
                
                ForEach(grouped, id: \.key) { date, events in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(date, style: .date)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                        
                        ForEach(events) { event in
                            HStack {
                                Text(event.title)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text(event.startDate, style: .time)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .ohanaGlassStyle(cornerRadius: 12)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

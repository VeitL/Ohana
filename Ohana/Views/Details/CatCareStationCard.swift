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

private struct CatCareUndoState: Equatable {
    let action: CatCareAction
    let eventID: UUID
    let hygieneLogID: UUID?
}

struct CatCareStationCard: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Query private var allEvents: [Event]
    
    @State private var recentAction: CatCareAction?
    @State private var undoTask: Task<Void, Never>?
    @State private var undoState: CatCareUndoState?
    @State private var showHistory = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    init(pet: Pet) {
        self.pet = pet
        let petID = pet.id.uuidString
        let eventType = EventType.litterBox.rawValue
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petID && event.eventType == eventType
            },
            sort: \Event.startDate,
            order: .reverse
        )
    }
    
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
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
            .foregroundStyle(Color.ohanaPrimaryText)
            
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
        .onDisappear {
            undoTask?.cancel()
            commandQueue.cancelAll()
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
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.ohanaCardSurface.opacity(0.3), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        undoTask?.cancel()
        undoState = nil
        withAnimation(GoMotion.feedback) {
            recentAction = action
        }

        let command = DomainCommand.catCareRecord(petID: pet.id, action: action.rawValue)
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
            .flatMap { $0.isEmpty ? nil : $0 }
        let input = CatCareCommandInput(
            actionRaw: action.rawValue,
            emoji: action.emoji,
            recordsHygiene: action == .litter,
            executorId: executorId
        )
        commandQueue.enqueue(command) {
            let result = PetCareCommandExecutor(context: modelContext).recordCatCare(pet: pet, input: input)
            undoState = CatCareUndoState(
                action: action,
                eventID: result.eventID,
                hygieneLogID: result.hygieneLogID
            )
            scheduleUndoClear()
        }
    }

    private func scheduleUndoClear() {
        undoTask?.cancel()
        undoTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation {
                recentAction = nil
                undoState = nil
            }
            undoTask = nil
        }
    }
    
    private func undoAction() {
        let state = undoState
        undoTask?.cancel()
        withAnimation {
            recentAction = nil
            undoState = nil
        }
        guard let state else { return }

        let command = DomainCommand.catCareUndo(petID: pet.id, eventID: state.eventID)
        commandQueue.enqueue(command) {
            _ = PetCareCommandExecutor(context: modelContext).undoCatCare(
                pet: pet,
                eventID: state.eventID,
                hygieneLogID: state.hygieneLogID
            )
        }
    }
    
    private func todayCount(for action: CatCareAction) -> Int {
        allEvents.filter {
            Calendar.current.isDateInToday($0.startDate) &&
            $0.title.contains(action.rawValue)
        }.count
    }
}

// MARK: - Cat Care History Sheet
struct CatCareHistorySheet: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @Query private var allEvents: [Event]

    init(pet: Pet) {
        self.pet = pet
        let petID = pet.id.uuidString
        let eventType = EventType.litterBox.rawValue
        _allEvents = Query(
            filter: #Predicate<Event> { event in
                event.relatedEntityId == petID && event.eventType == eventType
            },
            sort: \Event.startDate,
            order: .reverse
        )
    }
    
    private var catCareEvents: [Event] {
        allEvents
    }
    
    var body: some View {
        OhanaSheetWrapper(title: "护理记录", onDismiss: { dismiss() }) {
            if catCareEvents.isEmpty {
                VStack(spacing: 12) {
                    Text("🐱")
                        .font(.system(size: 48))
                    Text("暂无护理记录")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.ohanaSecondaryText)
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
                            .foregroundStyle(Color.ohanaSecondaryText)
                        
                        ForEach(events) { event in
                            HStack {
                                Text(event.title)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text(event.startDate, style: .time)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.ohanaSecondaryText)
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

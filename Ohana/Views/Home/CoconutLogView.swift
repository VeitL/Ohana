//
//  CoconutLogView.swift
//  Ohana
//
//  B7: 椰子获取记录页（从 OasisRewardView 椰子按钮进入）
//

import SwiftUI
import SwiftData

enum CoconutLogSubject: Identifiable, Equatable {
    case pet(UUID)
    case human(UUID)

    var id: String {
        switch self {
        case .pet(let id): "pet-\(id.uuidString)"
        case .human(let id): "human-\(id.uuidString)"
        }
    }

    var actorId: String {
        switch self {
        case .pet(let id), .human(let id):
            id.uuidString
        }
    }
}

struct CoconutLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var manager = QuestManager.shared
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""
    @AppStorage("appLanguage") private var appLanguage = "zh"

    // N10: member filter
    @State private var selectedActorId: String? = nil
    @State private var showingWealthDashboard = false
    private let subject: CoconutLogSubject?

    init(subject: CoconutLogSubject? = nil) {
        self.subject = subject
        _selectedActorId = State(initialValue: subject?.actorId)
    }

    private var l: L10n { L10n(appLanguage) }

    private var activeHumanId: UUID? {
        UUID(uuidString: activeHumanIdStr)
    }

    private var activeHumanActorId: String? {
        activeHumanIdStr.isEmpty ? nil : activeHumanIdStr
    }

    private var visibleHumans: [Human] {
        PrivacyService.unlockedHumans(for: .wishlist, from: humans, viewedBy: activeHumanId)
    }

    private var hiddenHumanIds: Set<String> {
        Set(humans.compactMap {
            PrivacyService.isLocked(.wishlist, for: $0, viewedBy: activeHumanId) ? $0.id.uuidString : nil
        })
    }

    private var visibleLogs: [CoconutLogEntry] {
        manager.coconutLogs.filter { !hiddenHumanIds.contains($0.actorId ?? "") }
    }

    private var visibleCoconutTotal: Int {
        if let subject {
            return balance(for: subject.actorId)
        }
        if let selectedActorId {
            return balance(for: selectedActorId)
        }
        return pets.reduce(0) { $0 + $1.coconutBalance } + visibleHumans.reduce(0) { $0 + $1.coconutBalance }
    }

    private func balance(for actorId: String) -> Int {
        if let pet = pets.first(where: { $0.id.uuidString == actorId }) {
            return pet.coconutBalance
        }
        guard !hiddenHumanIds.contains(actorId) else { return 0 }
        return visibleHumans.first(where: { $0.id.uuidString == actorId })?.coconutBalance ?? 0
    }

    private var filteredLogs: [CoconutLogEntry] {
        guard let id = subject?.actorId ?? selectedActorId else { return visibleLogs }
        return visibleLogs.filter { $0.actorId == id }
    }

    private var subjectName: String? {
        guard let subject else { return nil }
        switch subject {
        case .pet(let id):
            return pets.first(where: { $0.id == id })?.name
        case .human(let id):
            return visibleHumans.first(where: { $0.id == id })?.name
        }
    }

    private var knownActors: [(id: String, name: String, emoji: String)] {
        var seen = Set<String>()
        var result: [(String, String, String)] = []
        for human in visibleHumans {
            seen.insert(human.id.uuidString)
            result.append((human.id.uuidString, human.name, human.avatarEmoji.isEmpty ? "😊" : human.avatarEmoji))
        }
        for pet in pets {
            seen.insert(pet.id.uuidString)
            result.append((pet.id.uuidString, pet.name, "🐾"))
        }
        for log in visibleLogs {
            guard let id = log.actorId, let name = log.actorName, !seen.contains(id) else { continue }
            seen.insert(id)
            let emoji: String
            if visibleHumans.contains(where: { $0.id.uuidString == id }) {
                emoji = visibleHumans.first(where: { $0.id.uuidString == id })?.avatarEmoji ?? "😊"
            } else {
                emoji = "🐾"
            }
            result.append((id, name, emoji))
        }
        return result
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                // 余额大字
                HStack(spacing: 10) {
                    Text("🥥").font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(visibleCoconutTotal)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                            .contentTransition(.numericText())
                            .animation(GoMotion.feedback, value: visibleCoconutTotal)
                        Text(l.tr(zh: "当前椰子余额", en: "Current coconut balance", de: "Aktueller Kokosnussstand"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                GoDashedDivider().padding(.horizontal, 20)

                // N10: 成员筛选胶囊
                if subject == nil && !knownActors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(id: nil, emoji: "🌴", name: l.tr(zh: "全部", en: "All", de: "Alle"))
                            ForEach(knownActors, id: \.id) { actor in
                                filterChip(id: actor.id, emoji: actor.emoji, name: actor.name)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                }

                // 记录列表
                if filteredLogs.isEmpty {
                    VStack(spacing: 12) {
                        Text("🥥").font(.system(size: 48))
                        Text((subject == nil && selectedActorId == nil)
                             ? l.tr(zh: "还没有椰子记录", en: "No coconut history yet", de: "Noch keine Kokosnuss-Historie")
                             : l.tr(zh: "该成员暂无椰子记录", en: "No history for this member", de: "Keine Historie für dieses Mitglied"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
                        Text(l.tr(zh: "完成打卡后，椰子收支会出现在这里", en: "Coconut changes appear here after check-ins", de: "Kokosnuss-Bewegungen erscheinen hier nach Check-ins"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { idx, log in
                                logRow(log: log)
                                if idx < filteredLogs.count - 1 {
                                    Divider()
                                        .background(Color.ohanaCardStroke)
                                        .padding(.leading, 78)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingWealthDashboard) {
            IslandWealthDashboardView()
        }
        .onAppear {
            seedDefaultActorFilterIfNeeded()
        }
        .onChange(of: activeHumanIdStr) { oldValue, newValue in
            guard subject == nil else { return }
            let next = newValue.isEmpty ? nil : newValue
            if selectedActorId == nil || selectedActorId == oldValue || selectedActorId?.isEmpty == true {
                withAnimation(GoMotion.selection) {
                    selectedActorId = next
                }
            }
        }
    }

    private func seedDefaultActorFilterIfNeeded() {
        guard subject == nil, selectedActorId == nil, let activeHumanActorId else { return }
        selectedActorId = activeHumanActorId
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(Color.goPrimary)
                    Text(l.tr(zh: "椰子历史", en: "Coconut History", de: "Kokosnuss-Historie"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.ohanaPrimaryText)
                }
                Text(subjectName ?? l.tr(zh: "每一笔收支", en: "Every coconut change", de: "Jede Bewegung"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button {
                showingWealthDashboard = true
            } label: {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "打开财富分析", en: "Open wealth analysis", de: "Vermögensanalyse öffnen"))

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
        }
    }

    @ViewBuilder
    private func filterChip(id: String?, emoji: String, name: String) -> some View {
        let isSelected = selectedActorId == id
        Button {
            withAnimation(GoMotion.selection) { selectedActorId = id }
        } label: {
            HStack(spacing: 5) {
                Text(emoji).font(.system(size: 14))
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.ohanaPrimaryActionText : Color.ohanaSecondaryText)
            }
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(isSelected ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(GoMotion.selection, value: selectedActorId)
    }

    @ViewBuilder
    private func logRow(log: CoconutLogEntry) -> some View {
        let isEarning = log.amount > 0
        // 判断 actorId 对应的是宜物还是人类
        let isPet = log.actorId.map { id in pets.contains { $0.id.uuidString == id } } ?? false
        let isHuman = log.actorId.map { id in visibleHumans.contains { $0.id.uuidString == id } } ?? false
        let isSystem = log.actorId == nil || (!isPet && !isHuman)

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((isEarning ? Color.goPrimary : Color.goRed).opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(log.emoji).font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(log.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                HStack(spacing: 6) {
                    if isSystem {
                        // 全局系统奖励
                        Text("🏕️ 岛屿奖励")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.ohanaControlFill, in: Capsule())
                    } else if isPet {
                        // 宜物标签：展示宜物名
                        HStack(spacing: 3) {
                            Text("🐾")
                                .font(.system(size: 9))
                            Text(log.actorName ?? "")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.goTeal)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.goTeal.opacity(0.12), in: Capsule())
                    } else if isHuman {
                        // 人类标签
                        Text(log.actorName ?? "")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.goPrimary.opacity(0.9))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.goPrimary.opacity(0.1), in: Capsule())
                    }
                    Text(log.timeAgoString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                }
            }
            Spacer()
            HStack(spacing: 3) {
                Text(isEarning ? "+\(log.amount)" : "\(log.amount)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(isEarning ? Color.goPrimary : Color.goRed)
                Text("🥥").font(.system(size: 14))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }
}

#Preview {
    CoconutLogView()
}

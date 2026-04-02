//
//  CoconutLogView.swift
//  Ohana
//
//  B7: 椰子获取记录页（从 OasisRewardView 椰子按钮进入）
//

import SwiftUI
import SwiftData

struct CoconutLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var manager = QuestManager.shared
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Pet.createdAt)   private var pets:   [Pet]

    // N10: member filter
    @State private var selectedActorId: String? = nil

    private var filteredLogs: [CoconutLogEntry] {
        guard let id = selectedActorId else { return manager.coconutLogs }
        return manager.coconutLogs.filter { $0.actorId == id }
    }

    private var knownActors: [(id: String, name: String, emoji: String)] {
        var seen = Set<String>()
        var result: [(String, String, String)] = []
        for log in manager.coconutLogs {
            guard let id = log.actorId, let name = log.actorName, !seen.contains(id) else { continue }
            seen.insert(id)
            let emoji: String
            if humans.contains(where: { $0.id.uuidString == id }) {
                emoji = humans.first(where: { $0.id.uuidString == id })?.avatarEmoji ?? "😊"
            } else {
                emoji = "🐾"
            }
            result.append((id, name, emoji))
        }
        return result
    }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("椰子记录")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("每次照顾家人都能获得椰子 🥥")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 16)

                // 余额大字
                HStack(spacing: 10) {
                    Text("🥥").font(.system(size: 44))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(manager.coconutCount)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(Color.goPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4), value: manager.coconutCount)
                        Text("当前椰子余额")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                GoDashedDivider().padding(.horizontal, 20)

                // N10: 成员筛选胶囊
                if !knownActors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(id: nil, emoji: "🌴", name: "全部")
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
                        Text(selectedActorId == nil ? "还没有椰子记录" : "该成员暂无椰子记录")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.4))
                        Text("完成打卡、照顾家人后椰子会出现在这里")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary.opacity(0.25))
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
                                        .background(.white.opacity(0.06))
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
    }

    @ViewBuilder
    private func filterChip(id: String?, emoji: String, name: String) -> some View {
        let isSelected = selectedActorId == id
        Button {
            withAnimation(.spring(response: 0.3)) { selectedActorId = id }
        } label: {
            HStack(spacing: 5) {
                Text(emoji).font(.system(size: 14))
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.65))
            }
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(isSelected ? Color.goPrimary : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: selectedActorId)
    }

    @ViewBuilder
    private func logRow(log: CoconutLogEntry) -> some View {
        let isEarning = log.amount > 0
        // 判断 actorId 对应的是宜物还是人类
        let isPet = log.actorId.map { id in pets.contains { $0.id.uuidString == id } } ?? false
        let isHuman = log.actorId.map { id in humans.contains { $0.id.uuidString == id } } ?? false
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
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if isSystem {
                        // 全局系统奖励
                        Text("🏕️ 岛屿奖励")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.white.opacity(0.07), in: Capsule())
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
                        .foregroundStyle(.primary.opacity(0.35))
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

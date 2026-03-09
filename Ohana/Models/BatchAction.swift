//
//  BatchAction.swift
//  Ohana
//
//  一键全家批量打卡动作定义 — 支持自定义、序列化、物种过滤
//

import SwiftUI
import SwiftData

// MARK: - BatchActionType

enum BatchActionType: String, CaseIterable, Codable {
    case feed    = "feed"
    case water   = "water"
    case potty   = "potty"
    case litter  = "litter"
    case play    = "play"

    var label: String {
        switch self {
        case .feed:   return "喂食"
        case .water:  return "喂水"
        case .potty:  return "便便"
        case .litter: return "铲砂"
        case .play:   return "陪玩"
        }
    }

    var emoji: String {
        switch self {
        case .feed:   return "🍗"
        case .water:  return "💧"
        case .potty:  return "💩"
        case .litter: return "🧹"
        case .play:   return "🎾"
        }
    }

    var colorHex: String {
        switch self {
        case .feed:   return "FF8C00"
        case .water:  return "00D4AA"
        case .potty:  return "FFF44F"
        case .litter: return "C8FF00"
        case .play:   return "FF6B6B"
        }
    }
}

// MARK: - BatchAction

struct BatchAction: Identifiable, Codable {
    var id: String { type.rawValue }
    let type: BatchActionType

    var label:        String { type.emoji + " " + type.label }
    var toastMessage: String { type.label + "完成 " + type.emoji }
    var color:        Color  { Color(hex: type.colorHex) }

    /// 根据动作类型过滤目标宠物
    func targetPets(from all: [Pet]) -> [Pet] {
        let catLike = ["猫", "兔子", "仓鼠", "龙猫", "豚鼠"]
        switch type {
        case .feed, .water, .play:
            return all
        case .potty:
            return all.filter { !catLike.contains($0.species) }
        case .litter:
            return all.filter { catLike.contains($0.species) }
        }
    }

    /// 执行批量打卡
    @MainActor
    func perform(pets: [Pet], context: ModelContext) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let qm = QuestManager.shared
        switch type {
        case .feed:
            qm.batchAward(type: .feed, pets: pets, context: context)
        case .water:
            qm.batchAward(type: .water, pets: pets, context: context)
        case .potty:
            qm.batchAward(type: .potty(isLitter: false), pets: pets, context: context)
        case .litter:
            qm.batchAward(
                type: .general(humanReward: 5, petReward: 8, emoji: "🧹", title: "铲砂打卡"),
                pets: pets, context: context
            )
        case .play:
            qm.batchAward(
                type: .general(humanReward: 10, petReward: 12, emoji: "🎾", title: "陪玩打卡"),
                pets: pets, context: context
            )
        }
    }

    /// 默认动作列表
    static var defaults: [BatchAction] {
        [.init(type: .feed), .init(type: .water), .init(type: .potty), .init(type: .litter)]
    }
}

// MARK: - BatchActionEditSheet

struct BatchActionEditSheet: View {
    @Binding var selected: [BatchAction]
    @Environment(\.dismiss) private var dismiss

    private let allTypes = BatchActionType.allCases

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("选择一键全家操作")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(2)
                        .padding(.top, 8)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        ForEach(allTypes, id: \.rawValue) { t in
                            let isOn = selected.contains(where: { $0.type == t })
                            Button {
                                if isOn {
                                    selected.removeAll { $0.type == t }
                                } else {
                                    selected.append(.init(type: t))
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    Text(t.emoji).font(.system(size: 26))
                                    Text(t.label)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(isOn ? Color(hex: t.colorHex) : .white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    isOn
                                        ? Color(hex: t.colorHex).opacity(0.15)
                                        : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isOn ? Color(hex: t.colorHex).opacity(0.6) : Color.white.opacity(0.1),
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Text("完成")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.goLime, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

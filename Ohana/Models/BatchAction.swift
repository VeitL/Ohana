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

    /// SF Symbol icon — 与快捷操作卡片 icon 保持一致
    var sfIcon: String {
        switch self {
        case .feed:   return "fork.knife"
        case .water:  return "drop.fill"
        case .potty:  return "allergens"
        case .litter: return "trash.fill"
        case .play:   return "tennisball.fill"
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
        VStack(spacing: 0) {
            // 拖拽把手
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("一键全家")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("选择批量打卡的操作")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(allTypes, id: \.rawValue) { t in
                    let isOn = selected.contains(where: { $0.type == t })
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if isOn {
                            selected.removeAll { $0.type == t }
                        } else {
                            selected.append(.init(type: t))
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(hex: t.colorHex).opacity(isOn ? 0.22 : 0.08))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                isOn ? Color(hex: t.colorHex).opacity(0.7) : Color(hex: t.colorHex).opacity(0.2),
                                                lineWidth: isOn ? 2 : 1
                                            )
                                    )
                                Text(t.emoji).font(.system(size: 26))
                            }
                            Text(t.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(isOn ? Color(hex: t.colorHex) : .primary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isOn ? Color(hex: t.colorHex).opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .scaleEffect(isOn ? 1.04 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 24)

            Button { dismiss() } label: {
                Text("完成")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goLime, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .presentationBackground(.ultraThinMaterial)
    }
}

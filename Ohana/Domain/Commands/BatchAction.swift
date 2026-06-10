//
//  BatchAction.swift
//  Ohana
//
//  一键全家批量打卡动作定义 — 支持自定义、序列化、物种过滤
//

import SwiftData
import SwiftUI

// MARK: - BatchActionType

enum BatchActionType: String, CaseIterable, Codable {
    case feed
    case water
    case potty
    case litter
    case play

    var label: String {
        switch self {
        case .feed: "喂食"
        case .water: "喂水"
        case .potty: "便便"
        case .litter: "铲砂"
        case .play: "陪玩"
        }
    }

    var emoji: String {
        switch self {
        case .feed: "🍗"
        case .water: "💧"
        case .potty: "💩"
        case .litter: "🧹"
        case .play: "🎾"
        }
    }

    var colorHex: String {
        switch self {
        case .feed: "FF8C00"
        case .water: "00D4AA"
        case .potty: "FFF44F"
        case .litter: "F59E0B"
        case .play: "FF6B6B"
        }
    }

    /// SF Symbol icon — 与快捷操作卡片 icon 保持一致
    var sfIcon: String {
        switch self {
        case .feed: "fork.knife"
        case .water: "drop.fill"
        case .potty: "allergens"
        case .litter: "trash.fill"
        case .play: "tennisball.fill"
        }
    }
}

// MARK: - BatchAction

struct BatchAction: Identifiable, Codable {
    var id: String { type.rawValue }
    let type: BatchActionType

    var label: String { type.emoji + " " + type.label }
    var toastMessage: String { type.label + "完成 " + type.emoji }
    var color: Color { Color(hex: type.colorHex) }

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
        let qm = QuestManager()
        switch type {
        case .feed:
            qm.batchAward(type: .feed, pets: pets, context: context)
        case .water:
            qm.batchAward(type: .water, pets: pets, context: context)
        case .potty:
            qm.batchAward(type: .potty(isLitter: false), pets: pets, context: context)
        case .litter:
            qm.batchAward(
                type: .general(humanReward: 4, petReward: 1, emoji: "🧹", title: "铲砂打卡"),
                pets: pets, context: context
            )
        case .play:
            qm.batchAward(
                type: .general(humanReward: 3, petReward: 2, emoji: "🎾", title: "陪玩打卡"),
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
                .frame(width: 36, height: 4) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                .padding(.top, 10)
                .padding(.bottom, 20)

            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("一键全家")
                        .font(.system(size: 22, weight: .black, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                    Text("选择批量打卡的操作")
                        .font(.system(size: 14, weight: .medium)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                        .font(.system(size: 14, weight: .bold)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .frame(width: 30, height: 30) // a11y: allow visual glyph frame; interactive hit target is provided by the surrounding control or container
                        .background(Color.ohanaControlFill, in: Circle())
                }
                .buttonStyle(ScaleButtonStyle())
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
                                RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                    .fill(Color(hex: t.colorHex).opacity(isOn ? 0.22 : 0.08))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
                                            .strokeBorder(
                                                isOn ? Color(hex: t.colorHex).opacity(0.7) : Color(hex: t.colorHex).opacity(0.2),
                                                lineWidth: isOn ? 2 : 1
                                            )
                                    )
                                Text(t.emoji).font(.system(size: 26)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                            }
                            Text(t.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                                .foregroundStyle(isOn ? Color(hex: t.colorHex) : .primary.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isOn ? Color(hex: t.colorHex).opacity(0.06) : Color.clear,
                            in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
                        )
                        .scaleEffect(isOn ? 1.04 : 1.0)
                        .animation(GoMotion.feedback, value: isOn)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 24)

            Button { dismiss() } label: {
                Text("完成")
                    .font(.system(size: 15, weight: .black, design: .rounded)) // a11y: allow fixed display glyph/legacy hero typography; Dynamic Type migration tracked by P1 baseline
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.row))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .presentationBackground(.clear)
    }
}

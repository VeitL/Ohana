//
//  OverviewQuickActionQuickAddAndDrag.swift
//  Ohana
//
//  Quick-add popover and edit-mode drag helpers.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 喂水已打卡：水滴内下半部水浪（浪线仅画在 drop 下半区，再按水滴形 mask）
private struct QuickActionWaterDropWithWaves: View {
    let accent: Color
    var isPressed: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppPerformanceMode.powerSavingKey) private var powerSavingMode = false
    @StateObject private var workloadPolicy = AppWorkloadPolicy.shared

    private var dropSize: CGFloat { 30 }
    private var shouldReduceWork: Bool {
        reduceMotion || workloadPolicy.ambientMotionBudget(isVisible: true) == .static
    }

    var body: some View {
        let frame = dropSize * 1.2
        ZStack {
            Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(.system(size: dropSize, weight: .semibold))
                .foregroundStyle(accent)

            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: shouldReduceWork)) { timeline in // smoothness: allow visible water icon wave is workload-policy gated and reduced to 20fps
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let w = size.width
                    let h = size.height
                    let yMin = h * 0.48
                    let bandH = max(4, h - yMin)
                    for i in 0..<5 {
                        var path = Path()
                        let row = CGFloat(i)
                        let yBase = yMin + bandH * (0.12 + row * 0.17)
                        path.move(to: CGPoint(x: -1, y: yBase))
                        let steps = max(12, Int(w / 2))
                        for s in 0...steps {
                            let px = CGFloat(s) / CGFloat(steps) * (w + 2)
                            let phase = CGFloat(t * 1.75) + row * 0.55
                            let wave = sin((px / 6.8 + phase) * .pi / 2.2) * 2.4
                            path.addLine(to: CGPoint(x: px, y: yBase + wave))
                        }
                        context.stroke(
                            path,
                            with: .color(Color.ohanaPrimaryText.opacity(0.22 + 0.06 * (1 - Double(i) / 5))),
                            lineWidth: i < 2 ? 1.15 : 0.95
                        )
                    }
                }
                .frame(width: frame, height: frame)
                .mask {
                    Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                        .font(.system(size: dropSize, weight: .semibold))
                        .frame(width: frame, height: frame)
                }
            }

            Image(systemName: "drop.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(.system(size: dropSize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .frame(width: 44, height: 44)
        .scaleEffect(isPressed ? 0.90 : 1.0)
        .accessibilityLabel("喂水，今日已打卡")
    }
}

// MARK: - QA Quick Add Popover（与 GoQuickActionCard 同款 SF Symbol + 前景色，圆环色圈 + 横滑）
struct QAQuickAddPopoverContent: View {
    let pet: Pet
    let existingItems: [QuickActionItem]
    let onAdd: (QuickActionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var qaColorScheme
    @State private var showLimitAlert = false

    private var petItemCount: Int {
        QuickActionLimit.count(for: pet, in: existingItems)
    }

    private var isAtLimit: Bool {
        petItemCount >= QuickActionLimit.maxItemsPerEntity
    }

    private var options: [QuickActionPickerCatalog.Option] {
        let existing = Set(existingItems.filter { $0.petId == pet.id }.map(\.actionType))
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existing)
    }

    /// 与 `GoQuickActionCard.quickActionIconForeground` 一致（添加面板无「今日已打卡」态）
    private func pickerIconForeground(actionType: String) -> Color {
        if qaColorScheme == .dark { return .white.opacity(actionType == "feed" ? 0.72 : 0.92) }
        if actionType == "feed" { return Color.secondary }
        return Color.primary.opacity(0.75)
    }

    var body: some View {
        Group {
            if isAtLimit {
                VStack(spacing: 8) {
                    Text("8/8").font(OhanaFont.adaptive(size: 24, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("快捷操作已满")
                        .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("更多功能请去「全部功能」查看")
                        .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if options.isEmpty {
                VStack(spacing: 8) {
                    Text("✅").font(OhanaFont.adaptive(size: 26)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text("已全部添加")
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(options) { opt in
                            let accent = Color(hex: opt.colorHex)
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                guard !isAtLimit else {
                                    showLimitAlert = true
                                    return
                                }
                                onAdd(QuickActionItem(
                                    label: opt.label,
                                    icon: opt.icon,
                                    colorHex: opt.colorHex,
                                    petId: pet.id,
                                    actionType: opt.id
                                ))
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(accent.opacity(0.18))
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Circle().strokeBorder(accent.opacity(0.4), lineWidth: 1)
                                            )
                                        OhanaQuickActionIcon(
                                            actionType: opt.id,
                                            fallbackSystemName: opt.icon,
                                            size: 34,
                                            color: pickerIconForeground(actionType: opt.id)
                                        )
                                    }
                                    Text(opt.label)
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(qaColorScheme == .dark ? .white.opacity(0.9) : .primary)
                                }
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .presentationCompactAdaptation(.popover)
        .alert(QuickActionLimit.title, isPresented: $showLimitAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(QuickActionLimit.message)
        }
    }
}

/// 编辑模式拖拽排序：系统预览仅显示图标+文字，无卡片矩形底
struct QuickActionReorderDragPreview: View {
    let item: QuickActionItem
    var themeHex: String?

    var body: some View {
        VStack(spacing: 6) {
            OhanaQuickActionIcon(
                actionType: item.actionType,
                fallbackSystemName: item.icon,
                size: 34,
                color: Color.ohanaFunctionalIcon
            )
            .frame(width: 44, height: 44)
            Text(item.label)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(Color.ohanaPrimaryText)
        }
        .fixedSize()
    }
}

/// 编辑模式拖拽层：自定义预览仅图标+标题（无整张卡片矩形）。
struct QAEditModeDragLayer: View {
    let item: QuickActionItem
    let themeHex: String?
    @Binding var draggingItemId: String?

    var body: some View {
        Color.clear
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .onDrag {
                OhanaFeedback.light()
                withAnimation(GoMotion.selection) {
                    draggingItemId = item.id
                }
                return NSItemProvider(object: item.id as NSString)
            } preview: {
                QuickActionReorderDragPreview(item: item, themeHex: themeHex)
            }
    }
}

struct QADropDelegate: DropDelegate {
    let targetItem: QuickActionItem
    @Binding var items: [QuickActionItem]
    @Binding var draggingItemId: String?
    @Binding var lastDropTargetId: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingItemId = nil
        lastDropTargetId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard lastDropTargetId != targetItem.id else { return }

        if let draggingItemId {
            moveItem(fromId: draggingItemId)
            return
        }

        let types: [UTType] = [.plainText, .utf8PlainText]
        guard let provider = info.itemProviders(for: types).first else { return }
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let ns = obj as? NSString else { return }
            let fromId = ns as String
            DispatchQueue.main.async {
                moveItem(fromId: fromId)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if lastDropTargetId == targetItem.id {
            lastDropTargetId = nil
        }
    }

    private func moveItem(fromId: String) {
        guard fromId != targetItem.id,
              let fromIdx = items.firstIndex(where: { $0.id == fromId }),
              let toIdx = items.firstIndex(where: { $0.id == targetItem.id })
        else { return }

        lastDropTargetId = targetItem.id
        OhanaFeedback.light()
        withAnimation(GoMotion.selection) {
            items.move(
                fromOffsets: IndexSet(integer: fromIdx),
                toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx
            )
        }
    }
}

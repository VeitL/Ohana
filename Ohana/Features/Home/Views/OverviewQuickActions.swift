//
//  OverviewQuickActions.swift
//  Ohana
//
//  首页快速动作组件
//

import SwiftUI
import SwiftData

// MARK: - Go Quick Action Card (毛玻璃正方形)
struct GoQuickActionCard: View {
    let item: QuickActionItem
    let isPressed: Bool
    let petAvatar: UIImage?
    var petThemeColorHex: String? = nil
    /// 覆盖 `item.icon`（如喂水卡按「换水」模式显示不同 SF Symbol）
    var displayIcon: String? = nil
    /// 覆盖主标题（如首页喂水快捷项在「换水」模式下显示「换水」）
    var titleLabelOverride: String? = nil
    var pendingReminder: Reminder? = nil
    var showsAttentionDot: Bool = false
    var countText: String? = nil
    var privacyBadgeText: String? = nil
    var privacyIconName: String? = nil
    var privacyIconTint: Color = Color.goYellow
    var isPrivacyLocked: Bool = false
    var isCompletedToday: Bool = false
    var prefersLightForeground: Bool = false
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    /// 护理卡：点击后由外部执行打卡（传入 HygieneType raw string）
    var onGroomCheckIn: ((String) -> Void)? = nil
    /// 便便卡：点击后弹出类型选择（传入 PottyType raw string）
    var onPottySelect: ((String) -> Void)? = nil
    /// 健康卡：点击后弹出健康快速记录选项（传入 HealthQuickAction raw string）
    var onHealthSelect: ((String) -> Void)? = nil
    /// 长按→添加待办 sheet 回调
    var onAddReminder: (() -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var showGroomMenu = false
    @State private var showPottyMenu = false
    @State private var showHealthMenu = false
    @StateObject private var commandQueue = DeferredDomainCommandQueue()
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices

    private var isGroom: Bool { item.actionType == "groom" }
    private var isPotty: Bool { item.actionType == "potty" }
    private var isHealth: Bool { item.actionType == "health" }

    /// 根据 actionType 获取干净的显示名（不含宠物名）
    private var cleanLabel: String {
        let map: [String: String] = [
            "walk": "遛狗", "feed": "喂食", "water": "喂水",
            "potty": "便便", "litter": "铲屎", "groom": "护理",
            "health": "健康", "expense": "花费", "weight": "体重",
            "play": "陪玩", "moment": "记录", "waterChange": "换水",
            "filterClean": "清滤材", "cageCleaning": "清鸟笼",
            "freeFlight": "放飞", "misting": "喷水", "substrateChange": "换垫材"
        ]
        return map[item.actionType] ?? item.label
    }
    
    // 高级极简的规则圆角，取代不规则圆角
    private let premiumShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    private var cardBgColor: Color {
        if isCompletedToday { return Color.goPrimary.opacity(0.18) }
        if isWarningState {
            return Color.goRed.mix(with: Color.ohanaCardSurface, by: colorScheme == .dark ? 0.52 : 0.72)
        }
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.16) : Color.ohanaCardSurface
    }
    private var cardBorderColor: Color {
        if isCompletedToday { return Color.goPrimary.opacity(0.68) }
        if isWarningState { return Color.goRed.opacity(0.72) }
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.54) : Color.ohanaGlassStroke.opacity(0.42)
    }

    private var isWarningState: Bool {
        showsAttentionDot
    }

    /// 今日已打卡时图标/水浪用色：优先宠物主题色，否则快捷项自带色
    private var checkInAccentColor: Color {
        Color.ohanaFunctionalIcon
    }

    private var isWaterAction: Bool { item.actionType == "water" }
    private var isFeedAction: Bool { item.actionType == "feed" }

    /// V4: 功能 icon 统一为 goPrimary 单色 glyph，状态由卡片/数字/徽标表达。
    private var quickActionIconForeground: Color {
        Color.ohanaFunctionalIcon.opacity(isCompletedToday ? 1 : 0.9)
    }

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }
    private var usesLightForeground: Bool { prefersLightForeground || isDarkMode }
    private var titleForeground: Color {
        if isCompletedToday { return Color.goPrimary }
        return Color.ohanaPrimaryText.opacity(usesLightForeground ? 0.9 : 0.75)
    }
    private var subtitleForeground: Color {
        Color.ohanaSecondaryText.opacity(usesLightForeground ? 1.0 : 0.72)
    }
    
    @State private var animateGlow = false
    @State private var pendingSingleTapWorkItem: DispatchWorkItem? = nil
    @State private var lastTapDate: Date? = nil
    /// 长按成功后，手指抬起仍会触发 `DragGesture.onEnded`，需忽略紧随其后的那次「伪点击」（否则花费等会先开详情再弹出记账）
    @State private var ignoreNextDragEndTap: Bool = false
    private let tapMovementThreshold: CGFloat = 10
    private let doubleTapInterval: TimeInterval = 0.28

    private var resolvedIcon: String { displayIcon ?? item.icon }
    private var iconTileColor: Color {
        Color.ohanaFunctionalIcon.opacity(isCompletedToday ? 0.18 : 0.12)
    }

    /// 无菜单项时不挂 contextMenu，避免与长按打开详情 sheet 冲突（系统菜单盖住 sheet）
    private var hasContextMenuContent: Bool {
        // 护理 / 健康：长按只进详情，不弹系统二级菜单；点击弹出 popover
        if isGroom || isHealth { return false }
        return pendingReminder != nil
            || (isPotty && onAddReminder != nil)
            || onDelete != nil
    }

    var body: some View {
        // Avoid wrapping the card in Button/ExclusiveGesture here, because that
        // competes with the parent vertical ScrollView and makes the quick-action
        // area feel "stuck" when the user starts a vertical drag on a card.
        let core = cardContent
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .onLongPressGesture(minimumDuration: 0.45) {
                guard let lp = onLongPress else { return }
                cancelPendingSingleTap()
                lastTapDate = nil
                ignoreNextDragEndTap = true
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                lp()
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        if ignoreNextDragEndTap {
                            ignoreNextDragEndTap = false
                            return
                        }
                        let movedFarEnough =
                            abs(value.translation.width) > tapMovementThreshold ||
                            abs(value.translation.height) > tapMovementThreshold
                        guard !movedFarEnough else {
                            cancelPendingSingleTap()
                            lastTapDate = nil
                            return
                        }
                        handleTapCandidate()
                    }
            )

        Group {
            if hasContextMenuContent {
                core.contextMenu {
                    if let reminder = pendingReminder {
                        Button {
                            let activeHumanId = appServices.activeHumanSelection.currentHumanId
                            commandQueue.enqueue(.reminderCompletion(reminderID: reminder.id)) {
                                ReminderCommandExecutor(context: modelContext, services: appServices).complete(
                                    reminder,
                                    by: activeHumanId,
                                    note: "overview.quick.action.reminder.complete"
                                )
                            }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Label("完成待办", systemImage: "checkmark.circle.fill")
                        }
                    }
                    if isGroom, let onAdd = onAddReminder {
                        Button { onAdd() } label: {
                            Label("添加护理待办", systemImage: "bell.badge.plus")
                        }
                    }
                    if onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("移除快捷入口", systemImage: "trash")
                        }
                    }
                }
            } else {
                core
            }
        }
        .confirmationDialog("移除「\(item.label)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("移除", role: .destructive) { onDelete?() }
            Button("取消", role: .cancel) {}
        }
    }

    private var cardContent: some View {
        VStack(spacing: 6) {
            // Icon — keep the function glyph visible; completion is an additive badge/state.
            ZStack {
                OhanaQuickActionIcon(
                    actionType: item.actionType,
                    fallbackSystemName: resolvedIcon,
                    size: 34,
                    color: quickActionIconForeground,
                    isCompleted: isCompletedToday,
                    showsCompletionBadge: isCompletedToday
                )
                .scaleEffect(isPressed ? 0.90 : 1.0)
                .ohanaSymbolPulse(trigger: isCompletedToday)

                if pendingReminder != nil || showsAttentionDot {
                    Circle()
                        .fill(Color.goRed)
                        .frame(width: 7, height: 7) // a11y: allow decorative non-interactive frame; hit area handled by parent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 2, y: -2)
                }

                if let privacyIconName {
                    Image(systemName: privacyIconName)
                        .font(OhanaFont.adaptive(size: 10, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(privacyIconTint)
                        .shadow(color: Color.arkInk.opacity(0.35), radius: 2, x: 0, y: 1) // ui-v4: allow tiny privacy badge legibility lift
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 3, y: -4)
                }
            }
            .frame(width: 44, height: 44)
            .popover(isPresented: $showGroomMenu, arrowEdge: .top) {
                GroomPopoverContent(onSelect: { raw in
                    onGroomCheckIn?(raw)
                }, themeColor: petThemeColorHex.map { Color(hex: $0) } ?? Color.goPrimary)
                .presentationCompactAdaptation(.popover)
            }
            .popover(isPresented: $showPottyMenu, arrowEdge: .top) {
                PottyPopoverContent(onSelect: { raw in
                    onPottySelect?(raw)
                })
                .presentationCompactAdaptation(.popover)
            }
            .popover(isPresented: $showHealthMenu, arrowEdge: .top) {
                HealthPopoverContent(onSelect: { raw in
                    onHealthSelect?(raw)
                }, petThemeColorHex: petThemeColorHex)
                .presentationCompactAdaptation(.popover)
            }

            // 文字
            VStack(spacing: 1) {
                Text(titleLabelOverride ?? cleanLabel)
                    .font(OhanaFont.caption2(.semibold))
                    .foregroundStyle(titleForeground)
                    .lineLimit(1)

                if let badge = privacyBadgeText {
                    Label(badge, systemImage: isPrivacyLocked ? "lock.fill" : "globe.asia.australia.fill")
                        .font(OhanaFont.adaptive(size: 8, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(isPrivacyLocked ? Color.goYellow : subtitleForeground)
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                } else if let subtitle = countText ?? pendingReminder?.event?.title {
                    Text(subtitle)
                        .font(OhanaFont.caption2(.medium))
                        .foregroundStyle(subtitleForeground)
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(OhanaFont.adaptive(size: 9)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                }
            }
        }
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .frame(maxWidth: .infinity, minHeight: 82)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(cardBgColor, in: premiumShape)
        .overlay {
            premiumShape
                .strokeBorder(cardBorderColor, lineWidth: isWarningState ? 1.2 : 1)
        }
        .animation(GoMotion.feedback, value: isPressed)
        .animation(GoMotion.feedback, value: isCompletedToday)
        .animation(GoMotion.feedback, value: isWarningState)
        .ohanaSelectionMotion(isSelected: isCompletedToday, scale: 1.015)
        .ohanaStateMotion(pendingReminder?.id)
    }

    private func handleTapCandidate() {
        guard onDoubleTap != nil else {
            handlePrimaryTap()
            return
        }

        let now = Date()
        if let lastTapDate, now.timeIntervalSince(lastTapDate) <= doubleTapInterval {
            cancelPendingSingleTap()
            self.lastTapDate = nil
            onDoubleTap?()
            return
        }

        self.lastTapDate = now
        let workItem = DispatchWorkItem {
            handlePrimaryTap()
            self.lastTapDate = nil
            self.pendingSingleTapWorkItem = nil
        }
        pendingSingleTapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapInterval, execute: workItem)
    }

    private func cancelPendingSingleTap() {
        pendingSingleTapWorkItem?.cancel()
        pendingSingleTapWorkItem = nil
    }

    private func handlePrimaryTap() {
        if isGroom && onGroomCheckIn != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showGroomMenu = true
        } else if isPotty && onPottySelect != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showPottyMenu = true
        } else if isHealth && onHealthSelect != nil {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showHealthMenu = true
        } else {
            onTap()
        }
    }
}

//
//  OverviewQuickActions.swift
//  Ohana
//
//  Phase 59: 从 OverviewView.swift 提取的快速动作组件
//

import SwiftUI
import SwiftData

// MARK: - 快捷操作候选（与 QACardType.available 物种规则一致，供添加面板共用）
enum QuickActionPickerCatalog {
    struct Option: Identifiable, Hashable {
        let id: String
        let label: String
        let icon: String
        let colorHex: String
    }

    private static let all: [Option] = [
        Option(id: "walk", label: "遛狗", icon: "figure.walk", colorHex: "C8FF00"),
        Option(id: "feed", label: "喂食", icon: "fork.knife", colorHex: "FFDD44"),
        Option(id: "water", label: "喂水", icon: "drop.fill", colorHex: "00D4AA"),
        Option(id: "potty", label: "便便", icon: "allergens", colorHex: "FF8C42"),
        Option(id: "litter", label: "铲屎", icon: "trash.fill", colorHex: "5B6AFF"),
        Option(id: "groom", label: "护理", icon: "scissors", colorHex: "FF8C42"),
        Option(id: "health", label: "健康", icon: "heart.fill", colorHex: "FF4757"),
        Option(id: "expense", label: "花费", icon: "yensign.circle", colorHex: "A78BFA"),
        Option(id: "weight", label: "体重", icon: "scalemass.fill", colorHex: "80FFEA"),
        Option(id: "play", label: "逗玩", icon: "tennisball.fill", colorHex: "FF6B6B"),
        Option(id: "moment", label: "记录", icon: "camera.circle.fill", colorHex: "FF6B9D"),
        Option(id: "waterChange", label: "换水", icon: "drop.circle.fill", colorHex: "4ECDC4"),
        Option(id: "filterClean", label: "清滤材", icon: "wrench.and.screwdriver.fill", colorHex: "A78BFA"),
        Option(id: "cageCleaning", label: "清鸟笼", icon: "basket.fill", colorHex: "FFD166"),
        Option(id: "freeFlight", label: "放飞", icon: "bird.fill", colorHex: "06D6A0"),
        Option(id: "misting", label: "喷水", icon: "cloud.drizzle.fill", colorHex: "118AB2"),
        Option(id: "substrateChange", label: "换垫材", icon: "leaf.fill", colorHex: "07DB8B"),
    ]

    /// 当前物种可出现的 actionType 集合（与 ArkCrewIDCardView.QACardType.available 一致）
    static func allowedActionTypeIds(forSpecies species: String) -> Set<String> {
        var allowed = Set(QACardType.available(for: species).map(\.rawValue))
        if allowed.contains("care") { allowed.insert("groom") }
        allowed.insert("water")
        allowed.insert("waterChange")
        allowed.insert("moment")
        return allowed
    }

    static func available(for pet: Pet, existingActionTypes: Set<String>) -> [Option] {
        let allowed = allowedActionTypeIds(forSpecies: pet.species)
        return all.filter { allowed.contains($0.id) && !existingActionTypes.contains($0.id) }
    }
}

// MARK: - QuickActionItem Data Model
struct QuickActionItem: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var icon: String
    var colorHex: String
    var petId: UUID?
    var entityId: UUID?
    var entityKindRaw: String?
    var actionType: String   // "walk","health","groom","potty","feed","calendar","add","waterPlant","fertilizePlant"

    var entityKind: EntityKind? {
        get { entityKindRaw.flatMap { EntityKind(rawValue: $0) } }
        set { entityKindRaw = newValue?.rawValue }
    }

    var resolvedEntityId: UUID? { entityId ?? petId }

    init(id: String = UUID().uuidString, label: String, icon: String,
         colorHex: String, petId: UUID? = nil, actionType: String,
         entityId: UUID? = nil, entityKind: EntityKind? = nil) {
        self.id = id; self.label = label; self.icon = icon
        self.colorHex = colorHex; self.petId = petId; self.actionType = actionType
        self.entityId = entityId; self.entityKindRaw = entityKind?.rawValue
    }
}

enum QuickActionLimit {
    static let maxItemsPerEntity = 8
    static let title = "快捷操作已达上限"
    static let message = "快捷操作区最多只能添加 8 个。更多功能可以在「全部功能」里查看和使用。"

    static func count(for pet: Pet, in items: [QuickActionItem]) -> Int {
        items.filter { $0.petId == pet.id && $0.entityKind != .human }.count
    }
}

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
    var countText: String? = nil
    var privacyBadgeText: String? = nil
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
    @Environment(\.modelContext) private var modelContext

    private var isGroom: Bool { item.actionType == "groom" }
    private var isPotty: Bool { item.actionType == "potty" }
    private var isHealth: Bool { item.actionType == "health" }

    /// 根据 actionType 获取干净的显示名（不含宠物名）
    private var cleanLabel: String {
        let map: [String: String] = [
            "walk": "遛狗", "feed": "喂食", "water": "喂水",
            "potty": "便便", "litter": "铲屎", "groom": "护理",
            "health": "健康", "expense": "花费", "weight": "体重",
            "play": "逗玩", "moment": "记录", "waterChange": "换水",
            "filterClean": "清滤材", "cageCleaning": "清鸟笼",
            "freeFlight": "放飞", "misting": "喷水", "substrateChange": "换垫材"
        ]
        return map[item.actionType] ?? item.label
    }
    
    // 高级极简的规则圆角，取代不规则圆角
    private let premiumShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    private var cardBgColor: Color {
        if isCompletedToday { return Color.goLime.opacity(0.18) }
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.22) : base.opacity(0.14)
    }
    private var cardBorderColor: Color {
        if isCompletedToday { return Color.goLime.opacity(0.68) }
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.7) : base.opacity(0.3)
    }

    /// 今日已打卡时图标/水浪用色：优先宠物主题色，否则快捷项自带色
    private var checkInAccentColor: Color {
        if isCompletedToday { return Color.goLime }
        if let hex = petThemeColorHex { return Color(hex: hex) }
        return Color(hex: item.colorHex)
    }

    private var isWaterAction: Bool { item.actionType == "water" }
    private var isFeedAction: Bool { item.actionType == "feed" }

    /// 深色背景上优先保证可读性；浅色模式保留原来的完成态主题色反馈。
    private var quickActionIconForeground: Color {
        if isCompletedToday { return Color.goLime }
        if usesLightForeground { return .white.opacity(isFeedAction && !isCompletedToday ? 0.72 : 0.92) }
        if isFeedAction { return Color.secondary }
        return Color.primary.opacity(0.75)
    }

    @Environment(\.colorScheme) private var colorScheme
    private var isDarkMode: Bool { colorScheme == .dark }
    private var usesLightForeground: Bool { prefersLightForeground || isDarkMode }
    private var titleForeground: Color {
        if isCompletedToday { return Color.goLime }
        return usesLightForeground ? Color.white.opacity(0.9) : Color.primary.opacity(0.75)
    }
    private var subtitleForeground: Color {
        usesLightForeground ? Color.white.opacity(0.62) : Color.primary.opacity(0.35)
    }
    
    @State private var animateGlow = false
    @State private var pendingSingleTapWorkItem: DispatchWorkItem? = nil
    @State private var lastTapDate: Date? = nil
    /// 长按成功后，手指抬起仍会触发 `DragGesture.onEnded`，需忽略紧随其后的那次「伪点击」（否则花费等会先开详情再弹出记账）
    @State private var ignoreNextDragEndTap: Bool = false
    private let tapMovementThreshold: CGFloat = 10
    private let doubleTapInterval: TimeInterval = 0.28

    private var resolvedIcon: String { displayIcon ?? item.icon }

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
                            let activeHumanId = UserDefaults.standard.string(forKey: "currentActiveHumanId")
                            ReminderCompletionService.complete(reminder, by: activeHumanId, context: modelContext)
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
            // Icon — 喂水已打卡：水浪仅在水滴形下半部；喂食与其它项共用 SF Symbol（无动画）
            ZStack {
                if isWaterAction && isCompletedToday {
                    QuickActionWaterDropWithWaves(
                        accent: checkInAccentColor,
                        isPressed: isPressed
                    )
                } else {
                    Image(systemName: resolvedIcon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(quickActionIconForeground)
                        .scaleEffect(isPressed ? 0.90 : 1.0)
                }

                if pendingReminder != nil {
                    Circle()
                        .fill(Color.goRed)
                        .frame(width: 7, height: 7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .offset(x: 2, y: -2)
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
                        .font(.system(size: 8, weight: .black, design: .rounded))
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
                        .font(.system(size: 9))
                }
            }
        }
        .scaleEffect(isPressed ? 0.88 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
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
        if isGroom {
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

// MARK: - Groom Popover (紧凑气泡弹出)
private struct GroomPopoverContent: View {
    let onSelect: (String) -> Void
    var themeColor: Color = Color.goPrimary
    @Environment(\.dismiss) private var dismiss

    private struct GroomOption: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private let options: [GroomOption] = [
        GroomOption(id: "bath",     icon: "drop.fill",   label: "洗澡"),
        GroomOption(id: "teeth",    icon: "mouth.fill",  label: "刷牙"),
        GroomOption(id: "nails",    icon: "scissors",    label: "剪甲"),
        GroomOption(id: "brushing", icon: "comb.fill",   label: "梳毛"),
        GroomOption(id: "ears",     icon: "ear.fill",    label: "清耳"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(themeColor)
                            .frame(width: 48, height: 48)
                        Text(opt.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Potty Popover (便便类型选择气泡)
private struct PottyPopoverContent: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct PottyOption: Identifiable {
        let id: String
        let icon: String
        let label: String
        let colorHex: String
    }

    private let options: [PottyOption] = [
        PottyOption(id: PottyType.perfectPoop.rawValue, icon: "seal.fill",                    label: "完美", colorHex: "8B6914"),
        PottyOption(id: PottyType.softPoop.rawValue,    icon: "circle.dashed",                label: "软便", colorHex: "F59E0B"),
        PottyOption(id: PottyType.liquidPoop.rawValue,  icon: "exclamationmark.triangle.fill", label: "水便", colorHex: "EF4444"),
        PottyOption(id: PottyType.pee.rawValue,         icon: "drop.fill",                    label: "尿尿", colorHex: "3B82F6"),
    ]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(hex: opt.colorHex))
                            .frame(width: 48, height: 48)
                        Text(opt.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Health Popover (健康快速记录选项气泡)
private struct HealthPopoverContent: View {
    let onSelect: (String) -> Void
    var petThemeColorHex: String? = nil
    @Environment(\.dismiss) private var dismiss

    private struct HealthOption: Identifiable {
        let id: String
        let icon: String
        let label: String
        let colorHex: String
    }

    private let options: [HealthOption] = [
        HealthOption(id: "symptom",    icon: "exclamationmark.triangle.fill", label: "症状",   colorHex: "EF4444"),
        HealthOption(id: "vaccine",    icon: "syringe.fill",                  label: "疫苗",   colorHex: "10B981"),
        HealthOption(id: "deworming",  icon: "pills.fill",                    label: "驱虫",   colorHex: "8B5CF6"),
        HealthOption(id: "visit",      icon: "stethoscope",                   label: "就诊",   colorHex: "F59E0B"),
        HealthOption(id: "heatCycle",  icon: "heart.circle.fill",            label: "生理期", colorHex: "EC4899"),
    ]

    private var themeColor: Color {
        petThemeColorHex.map { Color(hex: $0) } ?? Color.goPrimary
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options) { opt in
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSelect(opt.id)
                    dismiss()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: opt.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(hex: opt.colorHex))
                            .frame(width: 48, height: 48)
                        Text(opt.label)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - QA Manage Sheet
struct QAManageSheet: View {
    let pets: [Pet]
    let defaultPetId: UUID?
    @Binding var savedItems: [QuickActionItem]
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(savedItems, id: \.id) { item in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: item.colorHex).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: item.icon)
                                .foregroundStyle(Color(hex: item.colorHex))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            if let pid = item.petId, let pet = pets.first(where: { $0.id == pid }) {
                                Text(pet.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("通用")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indices in
                    savedItems.remove(atOffsets: indices)
                }
                .onMove { indices, newOffset in
                    savedItems.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .navigationTitle("编辑快捷操作")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showingAddSheet = true } label: {
                            Image(systemName: "plus")
                        }
                        Button("完成") { dismiss() }
                            .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddQuickActionSheet(
                    pets: pets,
                    defaultPetId: defaultPetId,
                    existingItems: savedItems
                ) { newItem in
                    if let petId = newItem.petId,
                       let pet = pets.first(where: { $0.id == petId }),
                       QuickActionLimit.count(for: pet, in: savedItems) >= QuickActionLimit.maxItemsPerEntity {
                        return
                    }
                    savedItems.append(newItem)
                }
            }
        }
    }
}

// MARK: - Add Quick Action Sheet
struct AddQuickActionSheet: View {
    let pets: [Pet]
    let defaultPetId: UUID?
    let existingItems: [QuickActionItem]
    let onAdd: (QuickActionItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("quickActionItems_v2") private var quickActionItemsJSON: String = ""
    @State private var step: Int = 1
    @State private var selectedPet: Pet? = nil
    @State private var showLimitAlert = false

    /// F3: 实时读取 AppStorage 中的 item 数量（而非快照）
    private var liveItems: [QuickActionItem] {
        (try? JSONDecoder().decode([QuickActionItem].self, from: Data(quickActionItemsJSON.utf8))) ?? []
    }
    private var selectedPetItemCount: Int {
        guard let pet = selectedPet else { return 0 }
        return QuickActionLimit.count(for: pet, in: liveItems)
    }

    private func availableActions(for pet: Pet) -> [QuickActionPickerCatalog.Option] {
        let existingTypes = Set(liveItems.filter { $0.petId == pet.id }.map { $0.actionType })
        return QuickActionPickerCatalog.available(for: pet, existingActionTypes: existingTypes)
    }

    @State private var pressedActionId: String? = nil

    var body: some View {
        ZStack(alignment: .top) {
            // 拖拽把手
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .zIndex(1)

            VStack(spacing: 0) {
                Color.clear.frame(height: 22)
                if step == 1 {
                    petStep
                } else {
                    actionStep
                }
                Spacer(minLength: 32)
            }
        }
        .presentationBackground(.ultraThinMaterial)
        .presentationDetents([.height(380), .medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            if let pid = defaultPetId, let pet = pets.first(where: { $0.id == pid }) {
                selectedPet = pet
                step = 2
            }
        }
        .alert(QuickActionLimit.title, isPresented: $showLimitAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(QuickActionLimit.message)
        }
    }

    private var petStep: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择宠物")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("为哪只宠物添加快速入口")
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
            .padding(.top, 12)

            // 宠物列表
            VStack(spacing: 10) {
                ForEach(pets) { pet in
                    Button {
                        selectedPet = pet
                        withAnimation(.spring(response: 0.3)) { step = 2 }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: pet.themeColorHex).opacity(0.22))
                                    .frame(width: 48, height: 48)
                                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                                    Image(uiImage: img)
                                        .resizable().scaledToFill()
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                } else {
                                    Text(pet.avatarEmoji).font(.system(size: 26))
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pet.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("\(pet.species) · \(pet.breed)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(hex: pet.themeColorHex))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var actionStep: some View {
        VStack(spacing: 20) {
            // 头部：返回按鈕 + 宠物头像与名字融为一体
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3)) { step = 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                if let pet = selectedPet {
                    ZStack {
                        Circle().fill(Color(hex: pet.themeColorHex).opacity(0.2))
                            .frame(width: 36, height: 36)
                        if let data = pet.avatarImageData, let img = UIImage(data: data) {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 36, height: 36).clipShape(Circle())
                        } else {
                            Text(pet.avatarEmoji).font(.system(size: 20))
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pet.name)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                        Text("选择快捷功能")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // iOS 控制中心风格图标网格
            if let pet = selectedPet {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        let available = availableActions(for: pet)
                        if selectedPetItemCount >= QuickActionLimit.maxItemsPerEntity {
                            VStack(spacing: 8) {
                                Text("最多 8 个快捷操作")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("更多功能可以去「全部功能」里查看。")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if available.isEmpty {
                            Text("所有快捷入口已添加")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        }
                        ForEach(available) { action in
                            let accentColor = Color(hex: action.colorHex)
                            let isPressed = pressedActionId == action.id
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                guard selectedPetItemCount < QuickActionLimit.maxItemsPerEntity else {
                                    showLimitAlert = true
                                    return
                                }
                                onAdd(QuickActionItem(
                                    label: action.label,
                                    icon: action.icon, colorHex: action.colorHex,
                                    petId: pet.id, actionType: action.id
                                ))
                                dismiss()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: action.icon)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(accentColor)
                                        .frame(width: 44, height: 44)
                                    Text(action.label)
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    isPressed ? accentColor.opacity(0.1) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .scaleEffect(isPressed ? 0.90 : 1.0)
                                .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isPressed)
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedPetItemCount >= QuickActionLimit.maxItemsPerEntity)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in pressedActionId = action.id }
                                    .onEnded   { _ in pressedActionId = nil }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Quick Feed Sheet
struct QuickFeedSheet: View {
    let pet: Pet
    let actionType: String
    let onRemove: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var setAsDefault = false

    private var isWater: Bool { actionType == "water" }
    private var unit: String { isWater ? "ml" : "g" }
    private var defaultAmount: Double { isWater ? 200 : pet.dailyPortionGrams }
    private var isCasual: Bool { !isWater && pet.foodTrackingMode == .casual }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                VStack(spacing: 24) {
                    petHeader
                    HStack {
                        ExecutorPickerBar(tint: Color.goPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    if isCasual {
                        casualBody
                    } else {
                        preciseBody
                    }
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var petHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goPrimary.opacity(0.15))
                    .frame(width: 52, height: 52)
                if let data = pet.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 52, height: 52).clipShape(Circle())
                } else {
                    Text(pet.avatarEmoji)
                        .font(.system(size: 26))
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(pet.name)
                    .font(OhanaFont.body(.black))
                    .foregroundStyle(.primary)
                Text(isWater ? "喂水打卡" : (isCasual ? "佛系喂食 🐾" : "精准喂食 📊"))
                    .font(OhanaFont.caption(.medium))
                    .foregroundStyle(.primary.opacity(0.45))
            }
            Spacer()
            Text(isWater ? "💧" : "🍗").font(.system(size: 30))
        }
        .padding(.horizontal, 20)
    }

    private var casualBody: some View {
        VStack(spacing: 20) {
            UltimateGlassCard {
                VStack(spacing: 12) {
                    Text(casualCopyText)
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text("打卡后获得 +1🥥 椰子奖励")
                        .font(OhanaFont.footnote(.medium))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .padding(24)
            }
            .padding(.horizontal, 20)

            Button { commitFeed(amount: 0) } label: {
                HStack(spacing: 8) {
                    Text("✅")
                    Text("确认喂食  +1🥥")
                        .font(OhanaFont.headline(.black))
                        .foregroundStyle(Color.arkInk)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            removeButton
        }
    }

    private var preciseBody: some View {
        VStack(spacing: 16) {
            UltimateGlassCard {
                VStack(spacing: 12) {
                    Text("输入\(isWater ? "饮水量" : "喂食量")")
                        .font(OhanaFont.footnote(.semibold))
                        .foregroundStyle(.primary.opacity(0.6))
                    HStack(spacing: 8) {
                        TextField("默认 \(Int(defaultAmount))", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(OhanaFont.metric(size: 32))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        Text(unit)
                            .font(OhanaFont.title3(.bold))
                            .foregroundStyle(.primary.opacity(0.5))
                            .frame(width: 36)
                    }
                    Toggle(isOn: $setAsDefault) {
                        Text("设为默认\(isWater ? "饮水量" : "每日份量")")
                            .font(OhanaFont.footnote(.medium))
                            .foregroundStyle(.primary.opacity(0.7))
                    }
                    .tint(Color.goPrimary)
                }
                .padding(20)
            }
            .padding(.horizontal, 20)

            Button {
                let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? defaultAmount
                commitFeed(amount: amount)
            } label: {
                Text("打卡 +1🥥")
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goPrimary, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            removeButton
        }
    }

    private var removeButton: some View {
        Button(role: .destructive) {
            onRemove(); dismiss()
        } label: {
            Text("移除此快捷入口")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.goRed)
        }
        .buttonStyle(.plain)
    }

    private var casualCopyText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:  return "早餐时间到了！\n主子今天胃口好吗？🌅"
        case 10..<14: return "午饭打卡！\n记得让 \(pet.name) 多喝水哦 💦"
        case 14..<18: return "下午喂食 ☀️\n\(pet.name) 今天乖吗？"
        case 18..<22: return "晚餐时间！\n今天辛苦啦，\(pet.name) 也一样 🌙"
        default:       return "\(pet.name) 的宵夜时间？\n记录一下也没关系 😄"
        }
    }

    private func commitFeed(amount: Double) {
        let executorId = UserDefaults.standard.string(forKey: "currentActiveHumanId").flatMap {
            $0.isEmpty ? nil : $0
        }
        if isWater {
            let waterAmount = amount > 0 ? amount : defaultAmount
            CareEventService.recordCare(pet: pet, type: .watering, amountMl: waterAmount, context: modelContext, executorId: executorId, reward: .water)
        } else {
            if !isCasual && setAsDefault && amount > 0 { pet.dailyPortionGrams = amount }
            CareEventService.recordManualFeed(pet: pet, amountGrams: amount, context: modelContext, executorId: executorId)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - 喂水已打卡：水滴内下半部水浪（浪线仅画在 drop 下半区，再按水滴形 mask）
private struct QuickActionWaterDropWithWaves: View {
    let accent: Color
    var isPressed: Bool = false

    private var dropSize: CGFloat { 30 }

    var body: some View {
        let frame = dropSize * 1.2
        ZStack {
            Image(systemName: "drop.fill")
                .font(.system(size: dropSize, weight: .semibold))
                .foregroundStyle(accent)

            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
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
                            with: .color(Color.white.opacity(0.22 + 0.06 * (1 - Double(i) / 5))),
                            lineWidth: i < 2 ? 1.15 : 0.95
                        )
                    }
                }
                .frame(width: frame, height: frame)
                .mask {
                    Image(systemName: "drop.fill")
                        .font(.system(size: dropSize, weight: .semibold))
                        .frame(width: frame, height: frame)
                }
            }

            Image(systemName: "drop.fill")
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
                    Text("8/8").font(.system(size: 24, weight: .black, design: .rounded))
                    Text("快捷操作已满")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("更多功能请去「全部功能」查看")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else if options.isEmpty {
                VStack(spacing: 8) {
                    Text("✅").font(.system(size: 26))
                    Text("已全部添加")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
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
                                        Image(systemName: opt.icon)
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundStyle(pickerIconForeground(actionType: opt.id))
                                    }
                                    Text(opt.label)
                                        .font(OhanaFont.caption2(.bold))
                                        .foregroundStyle(qaColorScheme == .dark ? .white.opacity(0.9) : .primary)
                                }
                            }
                            .buttonStyle(.plain)
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

    private var accent: Color {
        if let h = themeHex { return Color(hex: h) }
        return Color(hex: item.colorHex)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
            Text(item.label)
                .font(OhanaFont.caption2(.semibold))
                .foregroundStyle(.primary)
        }
        .fixedSize()
    }
}


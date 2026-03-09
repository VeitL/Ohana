//
//  OverviewQuickActions.swift
//  Ohana
//
//  Phase 59: 从 OverviewView.swift 提取的快速动作组件
//

import SwiftUI
import SwiftData

// MARK: - QuickActionItem Data Model
struct QuickActionItem: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var icon: String
    var colorHex: String
    var petId: UUID?
    var actionType: String   // "walk","health","groom","potty","feed","calendar","add"

    init(id: String = UUID().uuidString, label: String, icon: String,
         colorHex: String, petId: UUID? = nil, actionType: String) {
        self.id = id; self.label = label; self.icon = icon
        self.colorHex = colorHex; self.petId = petId; self.actionType = actionType
    }
}

// MARK: - Go Quick Action Card (毛玻璃正方形)
struct GoQuickActionCard: View {
    let item: QuickActionItem
    let isPressed: Bool
    let petAvatar: UIImage?
    var petThemeColorHex: String? = nil
    var pendingReminder: Reminder? = nil
    var countText: String? = nil
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    /// 护理卡：点击后由外部执行打卡（传入 HygieneType raw string）
    var onGroomCheckIn: ((String) -> Void)? = nil
    /// 长按→添加待办 sheet 回调
    var onAddReminder: (() -> Void)? = nil

    @State private var showDeleteConfirm = false
    @State private var showGroomMenu = false
    @Environment(\.modelContext) private var modelContext

    private var isGroom: Bool { item.actionType == "groom" }

    private var cardBgColor: Color {
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.22) : base.opacity(0.14)
    }
    private var cardBorderColor: Color {
        let base = petThemeColorHex.map { Color(hex: $0) } ?? Color(hex: item.colorHex)
        return pendingReminder != nil ? base.opacity(0.7) : base.opacity(0.3)
    }

    var body: some View {
        Button(action: {
            if isGroom {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showGroomMenu = true
            } else if onDoubleTap == nil {
                onTap()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(cardBorderColor, lineWidth: pendingReminder != nil ? 1.5 : 1)
                    )

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        Image(systemName: item.icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(hex: item.colorHex))
                            .padding(.top, 12)
                            .padding(.leading, 10)
                        Spacer()
                        if let img = petAvatar {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        } else {
                            Circle()
                                .fill(Color(hex: item.colorHex).opacity(0.3))
                                .frame(width: 10, height: 10)
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        if let reminder = pendingReminder {
                            Text(reminder.event?.title ?? item.label)
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: item.colorHex))
                                .lineLimit(1)
                            Text("待办")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        } else {
                            Text(item.label)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                            if let ct = countText {
                                Text(ct)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: item.colorHex).opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
                }

                if pendingReminder != nil {
                    Circle()
                        .fill(Color.goRed)
                        .frame(width: 8, height: 8)
                        .padding(.top, 7)
                        .padding(.trailing, 7)
                }
            }
            .frame(height: 84)
            .scaleEffect(isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .if(onDoubleTap != nil) { v in
            v.simultaneousGesture(
                ExclusiveGesture(
                    TapGesture(count: 2).onEnded { onDoubleTap?() },
                    TapGesture(count: 1).onEnded { onTap() }
                )
            )
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                if let lp = onLongPress {
                    lp()
                } else {
                    showDeleteConfirm = true
                }
            }
        )
        .contextMenu {
            if let reminder = pendingReminder {
                Button {
                    reminder.statusEnum = .completed
                    reminder.completedAt = Date()
                    modelContext.safeSave()
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
        // 护理卡：毛玻璃 LazyVGrid Sheet
        .sheet(isPresented: $showGroomMenu) {
            GroomMenuSheet(onSelect: { raw in
                onGroomCheckIn?(raw)
            })
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .confirmationDialog("移除「\(item.label)」？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("移除", role: .destructive) { onDelete?() }
            Button("取消", role: .cancel) {}
        }
    }
}

// MARK: - Groom Menu Sheet (毛玻璃控制中心风格)
struct GroomMenuSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct GroomOption: Identifiable {
        let id: String
        let emoji: String
        let label: String
        let colorHex: String
    }

    private let options: [GroomOption] = [
        GroomOption(id: "bath",     emoji: "🛁", label: "洗澡",  colorHex: "4ECDC4"),
        GroomOption(id: "teeth",    emoji: "🦷", label: "刷牙",  colorHex: "80FFEA"),
        GroomOption(id: "nails",    emoji: "✂️", label: "剪甲",  colorHex: "C8FF00"),
        GroomOption(id: "brushing", emoji: "🪮", label: "梳毛",  colorHex: "A78BFA"),
        GroomOption(id: "ears",     emoji: "👂", label: "清耳",  colorHex: "FF8C42"),
    ]

    @State private var pressed: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("护理打卡")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("选择护理项目")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                spacing: 14
            ) {
                ForEach(options) { opt in
                    let accent = Color(hex: opt.colorHex)
                    let isPressed = pressed == opt.id
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onSelect(opt.id)
                        dismiss()
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(accent.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(accent.opacity(0.4), lineWidth: 1)
                                    )
                                Text(opt.emoji)
                                    .font(.system(size: 28))
                            }
                            Text(opt.label)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .scaleEffect(isPressed ? 0.90 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isPressed)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in pressed = opt.id }
                            .onEnded   { _ in pressed = nil }
                    )
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)
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
    @State private var step: Int = 1
    @State private var selectedPet: Pet? = nil

    private struct ActionOption: Identifiable {
        let id: String
        let label: String
        let icon: String
        let colorHex: String
        let speciesFilter: String?
    }

    private let allActions: [ActionOption] = [
        ActionOption(id: "walk",    label: "遛狗",  icon: "figure.walk",    colorHex: "C8FF00", speciesFilter: "狗"),
        ActionOption(id: "feed",    label: "喂食",  icon: "fork.knife",     colorHex: "FFDD44", speciesFilter: nil),
        ActionOption(id: "water",   label: "喂水",  icon: "drop.fill",      colorHex: "00D4AA", speciesFilter: nil),
        ActionOption(id: "potty",   label: "便便",  icon: "allergens",      colorHex: "FF8C42", speciesFilter: "狗"),
        ActionOption(id: "litter",  label: "铲屎",  icon: "trash.fill",     colorHex: "5B6AFF", speciesFilter: "猫"),
        ActionOption(id: "groom",   label: "护理",  icon: "scissors",       colorHex: "FF8C42", speciesFilter: nil),
        ActionOption(id: "health",  label: "健康",  icon: "heart.fill",     colorHex: "FF4757", speciesFilter: nil),
        ActionOption(id: "expense", label: "花费",  icon: "yensign.circle", colorHex: "A78BFA", speciesFilter: nil),
        ActionOption(id: "weight",  label: "体重",  icon: "scalemass.fill", colorHex: "80FFEA", speciesFilter: nil),
    ]

    private func availableActions(for pet: Pet) -> [ActionOption] {
        let petActions = allActions.filter { $0.speciesFilter == nil || $0.speciesFilter == pet.species }
        let existingTypes = Set(existingItems.filter { $0.petId == pet.id }.map { $0.actionType })
        return petActions.filter { !existingTypes.contains($0.id) }
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
        .presentationBackground(.regularMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            if let pid = defaultPetId, let pet = pets.first(where: { $0.id == pid }) {
                selectedPet = pet
                step = 2
            }
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
            VStack(spacing: 8) {
                ForEach(pets) { pet in
                    Button {
                        selectedPet = pet
                        withAnimation(.spring(response: 0.3)) { step = 2 }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: pet.themeColorHex).opacity(0.18))
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pet.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text("\(pet.species) · \(pet.breed)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                    spacing: 14
                ) {
                    let available = availableActions(for: pet)
                    if available.isEmpty {
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
                            onAdd(QuickActionItem(
                                label: "\(pet.name)\(action.label)",
                                icon: action.icon, colorHex: action.colorHex,
                                petId: pet.id, actionType: action.id
                            ))
                            dismiss()
                        } label: {
                            VStack(spacing: 10) {
                                // 大图标区域（果冻圆角矩形背景）
                                ZStack {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(accentColor.opacity(0.15))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: action.icon)
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(accentColor)
                                }
                                // 底部小字
                                Text(action.label)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .scaleEffect(isPressed ? 0.90 : 1.0)
                            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: isPressed)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in pressedActionId = action.id }
                                .onEnded   { _ in pressedActionId = nil }
                        )
                    }
                }
                .padding(.horizontal, 20)
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
                    .fill(Color.goLime.opacity(0.15))
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
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(isWater ? "喂水打卡" : (isCasual ? "佛系喂食 🐾" : "精准喂食 📊"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Text(isWater ? "💧" : "🍗").font(.system(size: 30))
        }
        .padding(.horizontal, 20)
    }

    private var casualBody: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(casualCopyText)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("打卡后获得 +1🥥 椰子奖励")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)

            Button { commitFeed(amount: 0) } label: {
                HStack(spacing: 8) {
                    Text("✅")
                    Text("确认喂食  +1🥥")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.goLime, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            removeButton
        }
    }

    private var preciseBody: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("输入\(isWater ? "饮水量" : "喂食量")")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 8) {
                    TextField("默认 \(Int(defaultAmount))", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    Text(unit)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 36)
                }
                Toggle(isOn: $setAsDefault) {
                    Text("设为默认\(isWater ? "饮水量" : "每日份量")")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .tint(Color.goLime)
            }
            .padding(.horizontal, 20)

            Button {
                let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? defaultAmount
                commitFeed(amount: amount)
            } label: {
                Text("打卡 +1🥥")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color.goLime, in: RoundedRectangle(cornerRadius: 14))
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
            let log = PetCareLog(date: Date(), type: .watering, amountGrams: 0, pet: pet, executorId: executorId)
            modelContext.insert(log)
        } else {
            let log = PetCareLog(date: Date(), type: .feeding, amountGrams: amount, pet: pet, executorId: executorId)
            if !isCasual && setAsDefault && amount > 0 { pet.dailyPortionGrams = amount }
            modelContext.insert(log)
        }
        modelContext.safeSave()
        QuestManager.shared.awardAction(type: isWater ? .water : .feed, pet: pet, context: modelContext)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

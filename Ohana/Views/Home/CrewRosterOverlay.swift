//
//  CrewRosterOverlay.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

// MARK: - 欧哈纳图鉴主视图

struct CrewRosterOverlay: View {
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    @State private var searchText = ""
    @State private var showingAddEntity = false
    @State private var showingCoconutLog = false

    private var filteredPets: [Pet] {
        searchText.isEmpty ? Array(pets) : pets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredHumans: [Human] {
        searchText.isEmpty ? Array(humans) : humans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredPlants: [Plant] {
        searchText.isEmpty ? Array(plants) : plants.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var isEmpty: Bool { filteredPets.isEmpty && filteredHumans.isEmpty && filteredPlants.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                ArkBackgroundView()
                IslandMoodWeatherView(mood: .breezy)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // 顶部搜索栏
                    dexSearchBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 10)

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            if isEmpty {
                                emptyState
                            } else {
                                bentoDex
                            }
                            Spacer(minLength: 60)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("欧哈纳图鉴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        // 1. 添加实体按钮（独立，自带图标背景）
                        Button { showingAddEntity = true } label: {
                            Image(systemName: "plus.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(Color.goLime)
                                .font(.system(size: 20))
                        }

                        // 2. 椰子余额（完全独立的视觉个体）
                        CoconutBalanceCapsule { showingCoconutLog = true }
                    }
                }
            }
            .sheet(isPresented: $showingAddEntity) { AddEntityView() }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
        }
    }

    // MARK: - 搜索栏
    private var dexSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.4))
            TextField("搜索岛民...", text: $searchText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .tint(Color.goLime)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.primary.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Bento Dex 主体
    private var bentoDex: some View {
        VStack(spacing: 16) {
            // ── 宠物区（正方形卡片 2列 Bento）
            if !filteredPets.isEmpty {
                dexSectionLabel("PETS", count: filteredPets.count, emoji: "🐾")
                BentoPetGrid(pets: filteredPets, onSelect: { pet in
                    onSelectPet(pet)
                })
                .padding(.horizontal, 16)
            }

            // ── 人类区（横向宽卡片）
            if !filteredHumans.isEmpty {
                dexSectionLabel("HUMANS", count: filteredHumans.count, emoji: "👥")
                VStack(spacing: 10) {
                    ForEach(filteredHumans) { human in
                        HumanWideCard(human: human) {
                            onSelectHuman(human)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // ── 植物区（竖向卡片横排）
            if !filteredPlants.isEmpty {
                dexSectionLabel("PLANTS", count: filteredPlants.count, emoji: "🌿")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredPlants) { plant in
                            PlantTallCard(plant: plant)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // ── 迎接新生命 Add 按钮
            addNewLifeButton
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Section 标签
    private func dexSectionLabel(_ title: String, count: Int, emoji: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 12))
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
                .tracking(2)
            Text("· \(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.goLime.opacity(0.7))
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 添加按钮
    private var addNewLifeButton: some View {
        Button { showingAddEntity = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.goLime.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color.goLime)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("迎接新生命")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    Text("宠物 · 家人 · 植物")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.goLime.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .foregroundStyle(Color.goLime.opacity(0.35))
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("🔍").font(.system(size: 48))
            Text("没有找到岛民")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
            Text("试试其他关键词")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.3))
        }
        .padding(.top, 80)
    }
}

// MARK: - 宠物 Bento 网格（不对称混排）

private struct BentoPetGrid: View {
    let pets: [Pet]
    let onSelect: (Pet) -> Void

    var body: some View {
        // 每行 2 个正方形，奇数最后一个占满整行
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(pets.enumerated()), id: \.element.id) { idx, pet in
                PetSquareCard(pet: pet, isWide: pets.count % 2 == 1 && idx == pets.count - 1) {
                    onSelect(pet)
                }
                // 奇数末尾卡片占满剩余列
                .gridCellColumns(pets.count % 2 == 1 && idx == pets.count - 1 ? 2 : 1)
            }
        }
    }
}

// MARK: - 宠物正方形卡片（P10：与首页 ArkCrewIDCardView 正面完全一致）

private struct PetSquareCard: View {
    let pet: Pet
    var isWide: Bool = false
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isPressed = false
    @State private var showDeleteAlert = false
    @State private var deleteConfirmName = ""
    @State private var showNameMismatch = false

    private var themeColor: Color { Color(hex: pet.themeColorHex.isEmpty ? "4338FF" : pet.themeColorHex) }
    private var cardHeight: CGFloat { isWide ? 140 : 160 }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let avatarImage: UIImage? = pet.avatarImageData.flatMap { UIImage(data: $0) }
                let isTransparent: Bool = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false

                ZStack {
                    if isTransparent, let img = avatarImage {
                        petCutoutCard(geo: geo, img: img, w: w, h: h)
                    } else if let img = avatarImage {
                        petBlurCard(geo: geo, img: img, w: w, h: h)
                    } else {
                        petEmojiCard(geo: geo, w: w, h: h)
                    }
                }
            }
            .frame(height: cardHeight)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.7).onEnded { _ in
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                deleteConfirmName = ""
                showNameMismatch = false
                showDeleteAlert = true
            }
        )
        .alert("删除 \(pet.name)？", isPresented: $showDeleteAlert) {
            TextField("输入宠物名字确认", text: $deleteConfirmName)
            Button("取消", role: .cancel) { deleteConfirmName = "" }
            Button("删除", role: .destructive) {
                if deleteConfirmName == pet.name {
                    let petIdStr = pet.id.uuidString
                    if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
                        for event in allEvents where event.relatedEntityId == petIdStr {
                            modelContext.delete(event)
                        }
                    }
                    modelContext.delete(pet)
                    modelContext.safeSave()
                } else {
                    showNameMismatch = true
                }
            }
        } message: {
            Text(showNameMismatch ? "❌ 输入名称不匹配，请重新输入 \"\(pet.name)\"" : "请输入 \"\(pet.name)\" 确认删除。此操作不可撤销。")
        }
    }

    // ── 方案1：透明抠图 破框悬浮
    private func petCutoutCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(themeColor.mix(with: .black, by: 0.30))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [themeColor.opacity(0.85),
                             themeColor.mix(with: Color(hex: "000000"), by: 0.45).opacity(0.95)],
                    startPoint: .topTrailing, endPoint: .bottomLeading))
            // 右侧名字
            HStack(alignment: .bottom, spacing: 0) {
                Spacer().frame(width: w * 0.48)
                miniInfoColumn(w: w, h: h)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        // 破框层
        .overlay(alignment: .bottomLeading) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(RadialGradient(colors: [themeColor.opacity(0.55), .clear],
                                        center: .center, startRadius: 0, endRadius: 50))
                    .frame(width: 100, height: 28).blur(radius: 8).offset(y: 6)
                ZStack {
                    Image(uiImage: img).resizable().scaledToFit()
                        .scaleEffect(1.06).colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                    Image(uiImage: img).resizable().scaledToFit()
                }
                .frame(width: w * 0.50, height: h * 1.12)
                .offset(y: -12)
            }
            .frame(width: w * 0.50, alignment: .bottom)
            .allowsHitTesting(false)
        }
        .shadow(color: themeColor.opacity(0.45), radius: 10, x: 0, y: 4)
    }

    // ── 方案2：普通照片 高斯模糊背景
    private func petBlurCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: w, height: h).blur(radius: 30)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(0.25), Color.black.opacity(0.52)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.30))
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: w * 0.60, height: h).clipped()
                .mask(LinearGradient(
                    stops: [.init(color: .black, location: 0),
                            .init(color: .black, location: 0.45),
                            .init(color: .clear, location: 1.0)],
                    startPoint: .leading, endPoint: .trailing))
                .allowsHitTesting(false)
            HStack(alignment: .bottom, spacing: 0) {
                Spacer().frame(width: w * 0.44)
                miniInfoColumn(w: w, h: h, textColor: .white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: themeColor.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    // ── 方案3：纯色渐变 + Emoji
    private func petEmojiCard(geo: GeometryProxy, w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [themeColor, themeColor.mix(with: .black, by: 0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                .font(.system(size: 56)).minimumScaleFactor(0.5)
                .frame(width: w * 0.50, height: h * 0.90, alignment: .center)
                .allowsHitTesting(false)
            HStack(alignment: .bottom, spacing: 0) {
                Spacer().frame(width: w * 0.50)
                miniInfoColumn(w: w, h: h)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: themeColor.opacity(0.35), radius: 10, x: 0, y: 4)
    }

    // ── 右侧信息列（名字 + 相伴天数）
    private func miniInfoColumn(w: CGFloat, h: CGFloat, textColor: Color? = nil) -> some View {
        let bright = ["C8FF00","E8FFB0","B8FFD0","FFF44F","FFEB3B","FFFFFF"]
        let tc: Color = textColor ?? (bright.contains(pet.themeColorHex.uppercased()) ? Color.arkInk : .white)
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)
            if pet.daysTogether > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(pet.daysTogether)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(tc)
                    Text("天")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(tc.opacity(0.6))
                }
                .padding(.bottom, 3)
            }
            Text(pet.name)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(tc)
                .lineLimit(1).minimumScaleFactor(0.45)
                .padding(.bottom, 4)
            if !pet.ageText.isEmpty {
                Text(pet.ageText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(tc.opacity(0.65))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(tc.opacity(0.15), in: Capsule())
                    .padding(.bottom, 10)
            }
        }
        .padding(.trailing, 10)
        .frame(width: w * 0.50, alignment: .trailing)
    }

    @ViewBuilder
    private var petStatusBadge: some View {
        let statusInfo = petStatus(for: pet)
        if let (emoji, label, color) = statusInfo {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 11))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
        }
    }

    private func petStatus(for pet: Pet) -> (String, String, Color)? {
        // 正在遛狗
        let mgr = PetWalkingManager.shared
        if case .running = mgr.phase, mgr.currentPet?.id == pet.id {
            return ("🐕", "遛狗中", Color.goLime)
        }
        if case .paused = mgr.phase, mgr.currentPet?.id == pet.id {
            return ("⏸️", "暂停中", Color.goYellow)
        }
        // 余粮告急
        if pet.dailyPortionGrams > 0 && pet.remainingFoodDays <= 3 && pet.remainingFoodDays >= 0 {
            return ("🍖", "粮食告急", Color.goOrange)
        }
        // 今日已遛狗
        let todayWalked = pet.walkLogs.contains { Calendar.current.isDateInToday($0.startDate) }
        if todayWalked { return ("✨", "今日已溜", Color.goTeal) }
        return nil
    }
}

// MARK: - 人类横向宽卡片

private struct HumanWideCard: View {
    let human: Human
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: 14) {
                // 头像
                ZStack {
                    Circle()
                        .fill(Color(hex: "667eea").opacity(0.25))
                        .frame(width: 56, height: 56)
                    if let data = human.avatarImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 2))
                    } else {
                        Text(human.avatarEmoji)
                            .font(.system(size: 28))
                    }
                }

                // 名字 + 角色
                VStack(alignment: .leading, spacing: 5) {
                    Text(human.name)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        Text(human.roleText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.arkInk)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Color.goLime, in: Capsule())
                        if human.birthday != nil {
                            Text(human.ageText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.45))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.25))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .goTranslucentCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - 植物竖向长卡片

private struct PlantTallCard: View {
    let plant: Plant
    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景渐变
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: "1A2F1A").opacity(0.6), Color(hex: "00D4AA").opacity(0.15)],
                    startPoint: .bottom, endPoint: .top
                ))

            VStack(spacing: 0) {
                Spacer()
                // 植物向上生长的 emoji
                Text(plant.avatarEmoji)
                    .font(.system(size: 42))
                    .shadow(color: Color.goTeal.opacity(0.4), radius: 10)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // 底部信息
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if plant.needsWatering {
                    Label("需要浇水", systemImage: "drop.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.goCardCyan)
                } else {
                    Text(plant.species.isEmpty ? "植物" : plant.species)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.45))
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
        }
        .frame(width: 110, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

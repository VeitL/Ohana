//
//  CrewRosterOverlay.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

// MARK: - Ohana 图鉴主视图

struct CrewRosterOverlay: View {
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var hideToolbar: Bool = false
    var searchTrigger: Bool = false
    var addMemberTrigger: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \Plant.createdAt) private var plants: [Plant]

    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var showingAddEntity = false
    @State private var showingCoconutLog = false
    @AppStorage("appUIStyle") private var appUIStyle: String = "go"
    @Environment(\.colorScheme) private var colorScheme

    private var isMaterial: Bool { false }
    private var matBg:      Color { colorScheme == .light ? Color(hex: "F5F5F7") : Color(hex: "0A0A0C") }
    private var matSurface: Color { colorScheme == .light ? .white : Color(hex: "1C1C1E") }
    private var matAccent:  Color { Color(hex: "FF5A00") }

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
                OhanaAppBackground()
                IslandMoodWeatherView(mood: .breezy)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // R6: 全局 header 占位
                    Spacer().frame(height: 70)

                    if !hideToolbar {
                        // 顶部搜索栏 + 添加按钮（独立使用时显示）
                        HStack(spacing: 10) {
                            dexSearchBar
                            Button { showingAddEntity = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(Color.goPrimary)
                                    .font(.system(size: 24))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 10)
                    } else if isSearchActive {
                        // 嵌入 tab 时，仅当搜索激活时显示搜索栏
                        HStack(spacing: 10) {
                            dexSearchBar
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    isSearchActive = false
                                    searchText = ""
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.primary.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

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
                        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: searchText)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddEntity) { AddEntityView() }
            .sheet(isPresented: $showingCoconutLog) { CoconutLogView() }
            .onChange(of: searchTrigger) { _, _ in
                withAnimation(.spring(response: 0.25)) { isSearchActive.toggle() }
                if !isSearchActive { searchText = "" }
            }
            .onChange(of: addMemberTrigger) { _, _ in showingAddEntity = true }
        }
    }

    // MARK: - 搜索栏
    private var dexSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isMaterial ? Color(hex: "8E8E93") : .primary.opacity(0.4))
            TextField("搜索成员...", text: $searchText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .tint(isMaterial ? matAccent : Color.goPrimary)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.primary.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            isMaterial ? matSurface : .white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isMaterial ? Color.clear : .white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: isMaterial ? .black.opacity(0.04) : .clear, radius: 8, x: 0, y: 2)
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

            // ── 人类区（正方形卡片 2列 Bento）
            if !filteredHumans.isEmpty {
                dexSectionLabel("HUMANS", count: filteredHumans.count, emoji: "👥")
                BentoHumanGrid(humans: filteredHumans, onSelect: { human in
                    onSelectHuman(human)
                })
                .padding(.horizontal, 16)
            }

            // ── 植物区（竖向卡片横排）
            if !filteredPlants.isEmpty {
                dexSectionLabel("PLANTS", count: filteredPlants.count, emoji: "🌿")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(filteredPlants.enumerated()), id: \.element.id) { index, plant in
                            PlantTallCard(plant: plant)
                                .ohanaSmoothAppear(index: index)
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
        HStack(spacing: 8) {
            if isMaterial {
                HStack(spacing: 5) {
                    Text(emoji).font(.system(size: 12))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.6))
                    Text("· \(count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(matAccent)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(matSurface, in: Capsule())
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
                Spacer()
            } else {
                Text(emoji).font(.system(size: 12))
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                    .tracking(2)
                Text("· \(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary.opacity(0.7))
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 添加按钮
    private var addNewLifeButton: some View {
        let accent = isMaterial ? matAccent : Color.goPrimary
        return Button { showingAddEntity = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(isMaterial ? 0.1 : 0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isMaterial ? "Add Member" : "迎接新生命")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                    Text("宠物 · 家人 · 植物")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isMaterial
                ? AnyShapeStyle(matSurface)
                : AnyShapeStyle(Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        style: isMaterial
                            ? StrokeStyle(lineWidth: 1.5)
                            : StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .foregroundStyle(accent.opacity(0.35))
            )
            .shadow(color: isMaterial ? .black.opacity(0.04) : .clear, radius: 8, x: 0, y: 2)
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

// MARK: - 宠物两列网格

private struct BentoPetGrid: View {
    let pets: [Pet]
    let onSelect: (Pet) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(pets.enumerated()), id: \.element.id) { index, pet in
                PetSquareCard(pet: pet) {
                    onSelect(pet)
                }
                .ohanaSmoothAppear(index: index)
            }
        }
    }
}

// MARK: - 宠物小卡片（两列网格用，单击进详情）

private struct PetSquareCard: View {
    let pet: Pet
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @State private var isDeletePressing = false
    @State private var deletePressCandidate = false
    @State private var deletePressToken = UUID()
    @State private var suppressTapUntil = Date.distantPast
    @State private var showDeleteAlert = false
    @State private var showHomeStackFullAlert = false
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""

    private var themeColor: Color { Color(hex: pet.themeColorHex.isEmpty ? "4338FF" : pet.themeColorHex) }
    private var isShownOnHome: Bool { HomeCardVisibility.isPetVisible(pet, raw: hiddenHomePetIDsRaw) }

    private var posterHeadline: String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "OHANA" }
        return String(trimmed.prefix(6)).uppercased()
    }

    var body: some View {
        VStack(spacing: 8) {
            cardFace
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                guard Date() >= suppressTapUntil else { return }
                onTap()
            }
            .scaleEffect(isDeletePressing ? 0.97 : 1.0)
            .rotationEffect(.degrees(isDeletePressing ? -1.35 : 0))
            .animation(isDeletePressing ? .easeInOut(duration: 0.09).repeatForever(autoreverses: true) : .spring(response: 0.22, dampingFraction: 0.82), value: isDeletePressing)
            .overlay(alignment: .topTrailing) {
                if isDeletePressing {
                    deletePreviewBadge
                        .padding(7)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
            .onLongPressGesture(
                minimumDuration: 0.7,
                maximumDistance: 12,
                pressing: updateDeletePressFeedback,
                perform: triggerDeleteAlert
            )
            homeVisibilityToggle
        }
        .alert("删除 \(pet.name)？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                let petIdStr = pet.id.uuidString
                if let allEvents = try? modelContext.fetch(FetchDescriptor<Event>()) {
                    for event in allEvents where event.relatedEntityId == petIdStr {
                        modelContext.delete(event)
                    }
                }
                modelContext.delete(pet)
                modelContext.safeSave()
            }
        } message: {
            Text("确定要删除 \(pet.name) 吗？此操作不可撤销。")
        }
    }

    private var cardFace: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let (cardTop, cardBottom) = WalletPetCardTheme.gradientPair(for: pet.themeColorHex)
            let avatarImage: UIImage? = pet.avatarImageData.flatMap { UIImage(data: $0) }
            let isTransparent: Bool = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            let isPopout = isTransparent && avatarImage != nil

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cardTop, cardBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.22)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Text(posterHeadline)
                    .font(.system(size: w * 0.28, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "FF5A3D").opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(y: -h * 0.22)
                    .allowsHitTesting(false)

                miniSubjectLayer(avatarImage: avatarImage, isPopout: isPopout, w: w, h: h)
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .allowsHitTesting(false)

                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: themeColor.opacity(0.32), radius: 12, x: 0, y: 4)
    }

    private var readableTextColor: Color {
        let bright = ["C8FF00","E8FFB0","B8FFD0","FFF44F","FFEB3B","FFFFFF","FFEAA7","FDCB6E"]
        return bright.contains(pet.themeColorHex.uppercased()) ? Color.arkInk : .white
    }

    private func compactBadge(_ text: String, textColor: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(textColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(textColor.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(textColor.opacity(0.12), lineWidth: 0.5))
    }

    private var homeVisibilityBinding: Binding<Bool> {
        Binding(
            get: { isShownOnHome },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if newValue,
                   !HomeCardVisibility.canShowPet(pet, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
                    showHomeStackFullAlert = true
                    return
                }
                hiddenHomePetIDsRaw = HomeCardVisibility.rawBySettingPet(pet, visible: newValue, raw: hiddenHomePetIDsRaw)
            }
        )
    }

    private var homeVisibilityToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: isShownOnHome ? "house.fill" : "house.slash.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(isShownOnHome ? Color.goLime : Color.white.opacity(0.45))
                .frame(width: 16)
            Text(isShownOnHome ? "首页显示" : "不在首页")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(isShownOnHome ? 0.86 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Toggle("", isOn: homeVisibilityBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.goLime)
                .scaleEffect(0.62)
                .frame(width: 34, height: 22)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("首页显示")
        .accessibilityValue(isShownOnHome ? "开启" : "关闭")
        .alert("首页卡片堆已满", isPresented: $showHomeStackFullAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先隐藏一张成员卡片，再显示 \(pet.name)。")
        }
    }

    private var deletePreviewBadge: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color.goRed, in: Circle())
            .shadow(color: Color.goRed.opacity(0.45), radius: 8, y: 3)
    }

    private func updateDeletePressFeedback(_ pressing: Bool) {
        if pressing {
            let token = UUID()
            deletePressToken = token
            deletePressCandidate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                guard deletePressCandidate, deletePressToken == token else { return }
                suppressTapUntil = Date().addingTimeInterval(1.1)
                withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
                    isDeletePressing = true
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            deletePressCandidate = false
            deletePressToken = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                guard !showDeleteAlert else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.84)) {
                    isDeletePressing = false
                }
            }
        }
    }

    private func triggerDeleteAlert() {
        suppressTapUntil = Date().addingTimeInterval(1.1)
        deletePressCandidate = false
        deletePressToken = UUID()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
            isDeletePressing = false
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showDeleteAlert = true
    }

    @ViewBuilder
    private func miniSubjectLayer(avatarImage: UIImage?, isPopout: Bool, w: CGFloat, h: CGFloat) -> some View {
        if let avatarImage {
            if isPopout {
                // 透明抠图：居左贴边
                ZStack(alignment: .bottom) {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(0.88)
                        .colorMultiply(.white)
                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFit()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)
            } else {
                // 普通照片：填满左半区域，右侧羽化
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w * 0.52, height: h)
                    .clipped()
                    .saturation(1.02)
                    .contrast(1.03)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0.0),
                                .init(color: .black, location: 0.65),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.08),
                                .clear,
                                themeColor.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.screen)
                    }
            }
        } else {
            // 无头像：剪影
            let silhouetteSpecies: String = {
                let value = pet.species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if value == "dog" || pet.species == "狗" { return "狗" }
                if value == "cat" || pet.species == "猫" { return "猫" }
                return pet.species
            }()
            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.16))
                    .frame(width: w * 0.28, height: 12)
                    .blur(radius: 6)
                    .offset(y: h * 0.14)
                PetSilhouetteView(
                    species: silhouetteSpecies,
                    coatColor: pet.coatColor.isEmpty ? Color(hex: "E8C49A") : Color(hex: pet.coatColor),
                    eyeColor: pet.eyeColor.isEmpty ? Color(hex: "6B3A2A") : Color(hex: pet.eyeColor)
                )
                .scaleEffect(0.42)
                .frame(width: w * 0.38, height: h * 0.68)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ── 方案1：透明抠图 破框悬浮
    private func petCutoutCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
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
        }
    }

    // ── 方案2：普通照片 高斯模糊背景
    private func petBlurCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
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
        }
    }

    // ── 方案3：纯色渐变 + Emoji
    private func petEmojiCard(geo: GeometryProxy, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
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
        }
    }

    // ── 右侧信息列（姓名 + 陪伴天数）
    private func miniInfoColumn(w: CGFloat, h: CGFloat, textColor: Color? = nil) -> some View {
        let tc: Color = textColor ?? readableTextColor
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)
            if pet.daysTogether > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(pet.daysTogether)")
                        .font(OhanaFont.metric(size: 20))
                        .foregroundStyle(tc)
                    Text("天")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(tc.opacity(0.6))
                }
                .padding(.bottom, 3)
            } else {
                Text("新成员")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tc.opacity(0.68))
                    .padding(.bottom, 3)
            }

            HStack(spacing: 4) {
                compactBadge(pet.species.isEmpty ? "宠物" : pet.species, textColor: tc)
                compactBadge(pet.ageText.isEmpty ? "年龄未知" : pet.ageText, textColor: tc)
            }
            .padding(.bottom, 10)
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
            return ("🐕", "遛狗中", Color.goPrimary)
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

// MARK: - 人类两列网格

private struct BentoHumanGrid: View {
    let humans: [Human]
    let onSelect: (Human) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(humans.enumerated()), id: \.element.id) { index, human in
                HumanSquareCard(human: human) {
                    onSelect(human)
                }
                .ohanaSmoothAppear(index: index)
            }
        }
    }
}

// MARK: - 人类小卡片（两列网格用，单击进详情）

private struct HumanSquareCard: View {
    let human: Human
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.createdAt) private var allPets: [Pet]
    @Query(sort: \Human.createdAt) private var allHumans: [Human]
    @State private var isDeletePressing = false
    @State private var deletePressCandidate = false
    @State private var deletePressToken = UUID()
    @State private var suppressTapUntil = Date.distantPast
    @State private var showDeleteAlert = false
    @State private var showHomeStackFullAlert = false
    @AppStorage(HomeCardVisibility.hiddenPetIDsKey) private var hiddenHomePetIDsRaw = ""

    private var themeColor: Color { Color(hex: human.themeColor) }
    private var companionshipDays: Int {
        max(0, Calendar.current.dateComponents([.day], from: human.createdAt, to: Date()).day ?? 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            cardFace
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                guard Date() >= suppressTapUntil else { return }
                onTap()
            }
            .scaleEffect(isDeletePressing ? 0.97 : 1.0)
            .rotationEffect(.degrees(isDeletePressing ? -1.35 : 0))
            .animation(isDeletePressing ? .easeInOut(duration: 0.09).repeatForever(autoreverses: true) : .spring(response: 0.22, dampingFraction: 0.82), value: isDeletePressing)
            .overlay(alignment: .topTrailing) {
                if isDeletePressing {
                    deletePreviewBadge
                        .padding(7)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
            .onLongPressGesture(
                minimumDuration: 0.7,
                maximumDistance: 12,
                pressing: updateDeletePressFeedback,
                perform: triggerDeleteAlert
            )
            homeVisibilityToggle
        }
        .alert("删除 \(human.name)？", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                modelContext.delete(human)
                modelContext.safeSave()
            }
        } message: {
            Text("确定要删除 \(human.name) 吗？此操作不可撤销。")
        }
    }

    private var cardFace: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let avatarImage: UIImage? = human.avatarImageData.flatMap { UIImage(data: $0) }
            let usesFullBleed = avatarImage != nil

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        MeshGradient(
                            width: 3, height: 3,
                            points: [
                                SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                                SIMD2(0.0, 0.5), SIMD2(0.52, 0.38), SIMD2(1.0, 0.5),
                                SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0)
                            ],
                            colors: WalletPetCardTheme.meshColors(for: human.themeColor)
                        )
                    )
                LinearGradient(
                    colors: [.clear, .black.opacity(usesFullBleed ? 0.12 : 0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: max(w, h), height: h)
                        .clipped()
                        .frame(width: w, height: h, alignment: .leading)
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white, location: 0.46),
                                    .init(color: .white.opacity(0.72), location: 0.60),
                                    .init(color: .white.opacity(0.18), location: 0.76),
                                    .init(color: .clear, location: 0.92)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .allowsHitTesting(false)
                }

                Text(human.name.uppercased())
                    .font(.system(size: WalletPetCardTheme.headlinePointSize(cardWidth: w, headlineCount: human.name.count), weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "FF5A3D").opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.22)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 8)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .opacity(0.78)
                    .allowsHitTesting(false)

                if !usesFullBleed {
                    humanAvatarContent
                        .frame(width: w * 0.52, height: h)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                }

                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
                .allowsHitTesting(false)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: themeColor.opacity(0.28), radius: 12, x: 0, y: 4)
    }

    private var readableTextColor: Color {
        let bright = ["C8FF00","E8FFB0","B8FFD0","FFF44F","FFEB3B","FFFFFF","FFEAA7","FDCB6E"]
        return bright.contains(human.themeColor.uppercased()) ? Color.arkInk : .white
    }

    private func compactBadge(_ text: String, textColor: Color) -> some View {
        Text(text)
            .font(OhanaFont.caption2(.black))
            .foregroundStyle(textColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(textColor.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(textColor.opacity(0.12), lineWidth: 0.5))
    }

    private var homeVisibilityBinding: Binding<Bool> {
        Binding(
            get: { human.shouldShowOnHome },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                if newValue,
                   !HomeCardVisibility.canShowHuman(human, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
                    showHomeStackFullAlert = true
                    return
                }
                human.shouldShowOnHome = newValue
                modelContext.safeSave()
            }
        )
    }

    private var homeVisibilityToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: human.shouldShowOnHome ? "house.fill" : "house.slash.fill")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(human.shouldShowOnHome ? Color.goLime : Color.white.opacity(0.45))
                .frame(width: 16)
            Text(human.shouldShowOnHome ? "首页显示" : "不在首页")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(human.shouldShowOnHome ? 0.86 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Toggle("", isOn: homeVisibilityBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.goLime)
                .scaleEffect(0.62)
                .frame(width: 34, height: 22)
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.07), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("首页显示")
        .accessibilityValue(human.shouldShowOnHome ? "开启" : "关闭")
        .alert("首页卡片堆已满", isPresented: $showHomeStackFullAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("首页最多显示 \(HomeCardVisibility.maxVisibleCards) 张卡片。请先隐藏一张成员卡片，再显示 \(human.name)。")
        }
    }

    private var deletePreviewBadge: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(Color.goRed, in: Circle())
            .shadow(color: Color.goRed.opacity(0.45), radius: 8, y: 3)
    }

    private func updateDeletePressFeedback(_ pressing: Bool) {
        if pressing {
            let token = UUID()
            deletePressToken = token
            deletePressCandidate = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                guard deletePressCandidate, deletePressToken == token else { return }
                suppressTapUntil = Date().addingTimeInterval(1.1)
                withAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true)) {
                    isDeletePressing = true
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else {
            deletePressCandidate = false
            deletePressToken = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                guard !showDeleteAlert else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.84)) {
                    isDeletePressing = false
                }
            }
        }
    }

    private func triggerDeleteAlert() {
        suppressTapUntil = Date().addingTimeInterval(1.1)
        deletePressCandidate = false
        deletePressToken = UUID()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.82)) {
            isDeletePressing = false
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        showDeleteAlert = true
    }

    @ViewBuilder
    private var humanAvatarContent: some View {
        if let data = human.avatarImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if !human.avatarEmoji.isEmpty {
            Text(human.avatarEmoji)
                .font(.system(size: 44))
        } else {
            Text(String(human.name.prefix(1)))
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // ── 方案1：透明抠图 破框悬浮
    private func humanCutoutCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor.opacity(0.85),
                                 themeColor.mix(with: Color(hex: "000000"), by: 0.45).opacity(0.95)],
                        startPoint: .topTrailing, endPoint: .bottomLeading))
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.48)
                    miniInfoColumn(w: w, h: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                            .clipShape(Circle()) // Apply circular clipping for humans if preferring normal avatar look
                    }
                    .frame(width: w * 0.50, height: h * 1.12)
                    .offset(y: -12)
                }
                .frame(width: w * 0.50, alignment: .bottom)
                .allowsHitTesting(false)
            }
        }
    }

    // ── 方案2：普通照片 高斯模糊背景
    private func humanBlurCard(geo: GeometryProxy, img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
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
        }
    }

    // ── 方案3：纯色渐变 + Emoji
    private func humanEmojiCard(geo: GeometryProxy, w: CGFloat, h: CGFloat) -> some View {
        UltimateGlassCard {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor, themeColor.mix(with: .black, by: 0.45)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(human.avatarEmoji.isEmpty ? String(human.name.prefix(1)) : human.avatarEmoji)
                    .font(.system(size: 56)).minimumScaleFactor(0.5)
                    .frame(width: w * 0.50, height: h * 0.90, alignment: .center)
                    .allowsHitTesting(false)
                HStack(alignment: .bottom, spacing: 0) {
                    Spacer().frame(width: w * 0.50)
                    miniInfoColumn(w: w, h: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // ── 右侧信息列（姓名 + 陪伴天数 + 角色）
    private func miniInfoColumn(w: CGFloat, h: CGFloat, textColor: Color? = nil) -> some View {
        let tc: Color = textColor ?? readableTextColor
        return VStack(alignment: .trailing, spacing: 0) {
            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(companionshipDays)")
                    .font(OhanaFont.metric(size: 20))
                    .foregroundStyle(tc)
                Text("天")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(tc.opacity(0.6))
            }
            .padding(.bottom, 3)

            HStack(spacing: 4) {
                compactBadge("人类", textColor: tc)
                compactBadge(human.birthday == nil ? "年龄未知" : human.ageText, textColor: tc)
            }
            .padding(.bottom, 10)
        }
        .padding(.trailing, 10)
        .frame(width: w * 0.50, alignment: .trailing)
    }
}

// MARK: - 植物竖向长卡片

private struct PlantTallCard: View {
    let plant: Plant

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
    }
}

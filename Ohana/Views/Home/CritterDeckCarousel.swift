//
//  CritterDeckCarousel.swift
//  Ohana
//
//  Created by Guanchenulous on 01.03.26.
//

import SwiftUI
import SwiftData

// MARK: - Card Deck Item
enum DeckItem: Identifiable {
    case pet(Pet)
    case human(Human)

    var id: String {
        switch self {
        case .pet(let p): return "pet-\(p.id)"
        case .human(let h): return "human-\(h.id)"
        }
    }
}

// MARK: - Wallet Layout Constants
private enum WalletLayout {
    /// 每张后牌向下偏移露出顶边的高度（Apple Wallet 感）
    static let peekOffset: CGFloat = 32
    /// 后牌轻微缩放（营造景深）
    static func scale(_ depth: Int) -> CGFloat { max(0.88, 1.0 - CGFloat(depth) * 0.04) }
    /// 后牌亮度衰减
    static func brightness(_ depth: Int) -> Double { -Double(depth) * 0.08 }
    /// 首页最多展示的卡片数（超出则折叠到 AllCardsSheet）
    static let maxVisible = 3
    /// 信用卡标准比例 85.6×53.98mm ≈ 1.586:1（宽/高）
    static func cardHeight(for width: CGFloat) -> CGFloat {
        return (width - 48) / 1.586
    }
}

struct CritterDeckCarousel: View {
    let pets: [Pet]
    let humans: [Human]
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    var onAddNew: (() -> Void)? = nil
    var onTopCardChanged: ((DeckItem) -> Void)? = nil
    var initialTopId: UUID? = nil
    var resetFlip: Bool = false

    // MARK: - State
    @State private var cards: [DeckItem] = []
    @State private var isTopFlipped: Bool = false
    @State private var isBusy: Bool = false
    /// 当前居中显示的卡片索引
    @State private var activeIndex: Int = 0
    /// 居中牌跟随手指的 Y 偏移
    @State private var dragOffsetY: CGFloat = 0
    /// 是否正在拖拽
    @State private var isDragging: Bool = false
    @State private var showAllCardsSheet = false
    // C3: 宠物背面健康格 modal sheet
    @State private var quickHealthPet: Pet? = nil
    
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""

    private var allItems: [DeckItem] {
        let petItems  = pets.map   { DeckItem.pet($0) }
        let humanItems = humans.filter { $0.shouldShowOnHome }.map { DeckItem.human($0) }
        return petItems + humanItems
    }

    // MARK: - Computed dimensions
    private var cardH: CGFloat { WalletLayout.cardHeight(for: ScreenCompat.width) }
    private var visibleCount: Int { min(cards.count, WalletLayout.maxVisible) }
    /// 滚轮卡片间距：背后卡片只露出一点点边缘作为滑动提示
    private var wheelSpacing: CGFloat { 45 }
    /// 整个滚轮展示区高度（中心牌 + 上下各露出一点边缘）
    private var wheelFrameHeight: CGFloat { cardH + wheelSpacing * 2.2 }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 14) {
            TabView(selection: $activeIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                    cardContent(for: item, isTop: index == activeIndex)
                        .scaleEffect(index == activeIndex ? 1.0 : 0.985)
                        .opacity(index == activeIndex ? 1.0 : 0.92)
                        .padding(.horizontal, 6)
                        .tag(index)
                }
            }
            .frame(height: cardH + 16)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.42, dampingFraction: 0.82), value: activeIndex)

            HStack(spacing: 0) {
                Spacer()
                if cards.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<min(cards.count, 5), id: \.self) { idx in
                            Capsule()
                                .fill(idx == activeIndex ? Color.goPrimary : Color.white.opacity(0.35))
                                .frame(width: idx == activeIndex ? 24 : 7, height: 7)
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeIndex)
                }
                Spacer()
                if cards.count > WalletLayout.maxVisible {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAllCardsSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("全部 \(cards.count) 张")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 24)
        }
        .padding(.horizontal, 16)
        .onAppear {
            setupCards()
            if cards.indices.contains(activeIndex) {
                onTopCardChanged?(cards[activeIndex])
            }
        }
        .onChange(of: allItems.map(\.id)) { _, _ in
            cards = allItems
            activeIndex = min(activeIndex, max(cards.count - 1, 0))
            isTopFlipped = false
            isBusy = false
            dragOffsetY = 0
            if cards.indices.contains(activeIndex) {
                onTopCardChanged?(cards[activeIndex])
            }
        }
        .onChange(of: resetFlip) { _, _ in
            isTopFlipped = false
        }
        .onChange(of: activeIndex) { oldValue, newValue in
            guard cards.indices.contains(newValue) else { return }
            isTopFlipped = false
            if oldValue != newValue {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            onTopCardChanged?(cards[newValue])
        }
        .sheet(isPresented: $showAllCardsSheet) {
            AllCardsSheet(
                cards: cards,
                onSelectPet: { pet in showAllCardsSheet = false; onSelectPet(pet) },
                onSelectHuman: { human in showAllCardsSheet = false; onSelectHuman(human) },
                onPromote: { index in
                    showAllCardsSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if index > 0 { promoteCard(at: index) }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // C3: 宠物背面健康格 → modal sheet（避免 NavigationStack push 死锁）
        .sheet(item: $quickHealthPet) { pet in
            NavigationStack { PetHealthDetailView(pet: pet, isModal: true) }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Wheel Math Helpers

    /// index 到 activeIndex 的距离（最短路径，考虑循环）
    private func wheelDiff(index: Int) -> Int {
        guard cards.count > 1 else { return 0 }
        let raw = index - activeIndex
        let half = cards.count / 2
        if raw > half  { return raw - cards.count }
        if raw < -half { return raw + cards.count }
        return raw
    }

    private func wheelScale(diff: CGFloat) -> CGFloat {
        max(0.80, 1.0 - abs(diff) * 0.12)
    }

    private func wheelOpacity(diff: CGFloat) -> Double {
        max(0.0, 1.0 - Double(abs(diff)) * 0.50)
    }

    private func wheelBrightness(diff: CGFloat) -> Double {
        -Double(abs(diff)) * 0.22
    }

    // MARK: - Swipe Actions

    /// 上滑：activeIndex 向后移动一张（下一张来到中心）
    private func advanceToNext() {
        guard cards.count > 1, !isBusy else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { dragOffsetY = 0 }
            return
        }
        isBusy = true
        isTopFlipped = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            dragOffsetY = 0
            activeIndex = (activeIndex + 1) % cards.count
        }
        onTopCardChanged?(cards[activeIndex])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { isBusy = false }
    }

    /// 下滑：activeIndex 向前移动一张（上一张来到中心）
    private func retreatToPrev() {
        guard cards.count > 1, !isBusy else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { dragOffsetY = 0 }
            return
        }
        isBusy = true
        isTopFlipped = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            dragOffsetY = 0
            activeIndex = (activeIndex - 1 + cards.count) % cards.count
        }
        onTopCardChanged?(cards[activeIndex])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { isBusy = false }
    }

    /// 点击旁边的卡片：跳到该卡片
    private func jumpToCard(at index: Int) {
        guard !isBusy, index != activeIndex else { return }
        isBusy = true
        isTopFlipped = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            dragOffsetY = 0
            activeIndex = index
        }
        onTopCardChanged?(cards[activeIndex])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { isBusy = false }
    }

    // MARK: - Promote card to front (from AllCardsSheet)
    private func promoteCard(at index: Int) {
        guard !isBusy, index != activeIndex, index < cards.count else { return }
        isBusy = true
        isTopFlipped = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
            dragOffsetY = 0
            activeIndex = index
        }
        onTopCardChanged?(cards[activeIndex])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { isBusy = false }
    }

    // MARK: - Setup
    private func setupCards() {
        let base = allItems
        var startIndex = 0
        if let target = initialTopId,
           let idx = base.firstIndex(where: {
               if case .pet(let p) = $0 { return p.id == target }
               return false
           }) {
            startIndex = idx
        }
        cards = base
        activeIndex = startIndex
    }

    // MARK: - Card Content Builder
    @ViewBuilder
    private func cardContent(for item: DeckItem, isTop: Bool) -> some View {
        switch item {
        // C3 sheet 挂在 cardContent 外的 body ZStack 上
        case .pet(let pet):
            ArkCrewIDCardView(
                pet: pet,
                onDetail: { onSelectPet(pet) },
                isFlipped: isTop ? $isTopFlipped : nil,
                onShowHealth: { quickHealthPet = pet }
            )
        case .human(let human):
            HumanIDCardView(
                human: human,
                onDetail: { onSelectHuman(human) },
                isFlipped: isTop ? $isTopFlipped : nil
            )
        }
    }
}

// MARK: - All Cards Sheet（LazyVGrid 双列缩略卡）
private struct AllCardsSheet: View {
    let cards: [DeckItem]
    let onSelectPet: (Pet) -> Void
    let onSelectHuman: (Human) -> Void
    let onPromote: (Int) -> Void

    // 每列宽度 = (屏幕宽 - 水平padding*2 - 列间距) / 2
    private let hPad: CGFloat = 16
    private let gap: CGFloat = 12
    private var cardWidth: CGFloat {
        (ScreenCompat.width - hPad * 2 - gap) / 2
    }
    private var cardHeight: CGFloat { cardWidth / 1.586 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "060E24").ignoresSafeArea()

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: gap), GridItem(.flexible(), spacing: gap)],
                        spacing: gap
                    ) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, item in
                            miniCard(item: item, index: index)
                        }
                    }
                    .padding(.horizontal, hPad)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("全部成员")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func miniCard(item: DeckItem, index: Int) -> some View {
        MiniFlipCard(
            item: item,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            isFirst: index == 0,
            onDetail: {
                switch item {
                case .pet(let p): onSelectPet(p)
                case .human(let h): onSelectHuman(h)
                }
            },
            onPromote: index > 0 ? { onPromote(index) } : nil
        )
    }
}

// MARK: - 可翻转缩略卡
private struct MiniFlipCard: View {
    let item: DeckItem
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let isFirst: Bool
    let onDetail: () -> Void
    var onPromote: (() -> Void)? = nil

    @State private var isFlipped = false
    @State private var showFront = true
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""

    var body: some View {
        ZStack {
            miniCardFront
                .opacity(showFront ? 1 : 0)
            miniCardBack
                .scaleEffect(x: -1, y: 1)
                .opacity(showFront ? 0 : 1)
        }
        .frame(width: cardWidth, height: cardHeight)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isFlipped)
        .onChange(of: isFlipped) { _, newFlipped in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { showFront = !newFlipped }
            }
        }
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isFlipped.toggle()
        }
        .overlay(alignment: .topLeading) {
            if isFirst {
                Text("当前")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.goPrimary, in: Capsule())
                    .padding(8)
            }
        }
    }

    // ── 卡片正面（缩略展示）
    @ViewBuilder
    private var miniCardFront: some View {
        switch item {
        case .pet(let pet):
            let themeColor = Color(hex: pet.themeColorHex.isEmpty ? "4338FF" : pet.themeColorHex)
            let isTransparent = pet.avatarImageData.map { ImageCutoutService.isTransparentPNG($0) } ?? false
            ZStack(alignment: .bottomLeading) {
                // ── 卡片底层（包含非透明图和文字，整体 clipShape）
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(
                            colors: [themeColor, themeColor.opacity(0.6), Color.goDarkBlue],
                            startPoint: .topLeading, endPoint: .bottomTrailing))

                    // 普通图：React 风格融合效果 - 左下角径向渐变遮罩 + 颜色混合
                    if let data = pet.avatarImageData, let img = UIImage(data: data), !isTransparent {
                        // 图片容器：定位在左下角，占 80% 宽度
                        ZStack {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: cardWidth * 0.8, height: cardHeight)
                                .clipped()
                                // 核心 1：径向渐变遮罩，中心点在左下角 (20% 100%)
                                .mask(
                                    RadialGradient(
                                        gradient: Gradient(stops: [
                                            .init(color: .black, location: 0.35),      // 中心完全显示
                                            .init(color: .black, location: 0.5),       // 过渡区
                                            .init(color: .clear, location: 0.9)        // 边缘完全隐藏
                                        ]),
                                        center: UnitPoint(x: 0.2, y: 1.0),         // 左下角
                                        startRadius: 10,
                                        endRadius: 180
                                    )
                                )
                                // 核心 2：颜色混合叠加层 - mix-blend-color 效果
                                .overlay(
                                    Color(hex: "C8FF00")                        // 亮绿色背景色
                                        .opacity(0.2)                           // 20% 透明度
                                        .blendMode(.color),                      // mix-blend-color
                                    alignment: .topLeading
                                )
                                .allowsHitTesting(false)
                        }
                        .frame(width: cardWidth * 0.8, height: cardHeight, alignment: .bottomLeading)
                        .clipped()
                    } else if pet.avatarImageData == nil {
                        Text(pet.avatarEmoji.isEmpty ? String(pet.name.prefix(1)) : pet.avatarEmoji)
                            .font(.system(size: 48))
                            .frame(width: cardWidth * 0.5, height: cardHeight, alignment: .center)
                    }

                    // 右侧信息（只保留大字名字）
                    VStack(alignment: .trailing, spacing: 2) {
                        Spacer()
                        Text(pet.name)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .padding(.trailing, 10).padding(.bottom, 12)
                    .frame(width: cardWidth * 0.5, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    // 翻转提示
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // ── 透明 PNG 破框层（在 clipShape 外叠加，底部对齐，向上溢出）
                if let data = pet.avatarImageData, let img = UIImage(data: data), isTransparent {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                        .frame(width: cardWidth * 0.65, height: cardHeight * 1.25)
                        .allowsHitTesting(false)
                        .frame(width: cardWidth * 0.65, height: cardHeight, alignment: .bottom)
                }
            }
            .shadow(color: themeColor.opacity(0.4), radius: 8, x: 0, y: 4)

        case .human(let human):
            let themeHex: String = human.themeColor
            let themeColor = Color(hex: themeHex)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeColor, themeColor.opacity(0.6), Color.goDarkBlue],
                        startPoint: .topLeading, endPoint: .bottomTrailing))

                // FIX 3+8：透明 PNG 不裁切，普通图底部渐变融入
                if let data = human.avatarImageData, let img = UIImage(data: data) {
                    if ImageCutoutService.isTransparentPNG(data) {
                        Image(uiImage: img)
                            .resizable().scaledToFit()
                            .frame(width: cardWidth * 0.55, height: cardHeight)
                            .allowsHitTesting(false)
                    } else {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: cardWidth * 0.55, height: cardHeight)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .clear, Color.goDarkBlue.opacity(0.5), Color.goDarkBlue.opacity(0.85)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                    }
                } else {
                    Text(human.avatarEmoji.isEmpty ? String(human.name.prefix(1)) : human.avatarEmoji)
                        .font(.system(size: 48))
                        .frame(width: cardWidth * 0.5, height: cardHeight, alignment: .center)
                }

                VStack(alignment: .trailing, spacing: 2) {
                    Spacer()
                    let isMe = (human.id.uuidString == activeHumanId)
                    let titleDisplay: String = {
                        guard isMe else { return "" }
                        switch equippedTitle {
                        case "title_guardian": return "🛡️"
                        case "title_pioneer": return "🚀"
                        case "title_chef": return "👨‍🍳"
                        default: return ""
                        }
                    }()
                    Text(titleDisplay + human.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                .padding(.trailing, 10).padding(.bottom, 12)
                .frame(width: cardWidth * 0.5, alignment: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: themeColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }

    // ── 卡片背面（操作按钮 + 今日快速统计）
    private var miniCardBack: some View {
        let name: String = {
            switch item {
            case .pet(let p): return p.name
            case .human(let h): return h.name
            }
        }()
        let accentColor: Color = {
            switch item {
            case .pet(let p): return Color(hex: p.themeColorHex.isEmpty ? "4338FF" : p.themeColorHex)
            case .human(let h): return Color(hex: h.themeColor)
            }
        }()

        return ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.goDarkBlue, Color.goDeepNavy],
                    startPoint: .top, endPoint: .bottom))

            VStack(spacing: 8) {
                // 名字 + 主题色点
                HStack(spacing: 5) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                    Text(name)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                // 小统计（宠物显示今日动态）
                if case .pet(let p) = item {
                    let walkToday = p.walkLogs.filter { Calendar.current.isDateInToday($0.startDate) }.count
                    let feedToday = p.careLogs.filter { $0.type == CareType.feeding.rawValue && Calendar.current.isDateInToday($0.date) }.count
                    HStack(spacing: 8) {
                        Label("\(walkToday)", systemImage: "figure.walk")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.goPrimary.opacity(walkToday > 0 ? 1 : 0.35))
                        Label("\(feedToday)", systemImage: "fork.knife")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.goOrange.opacity(feedToday > 0 ? 1 : 0.35))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.white.opacity(0.06), in: Capsule())
                }

                // 详情按钮
                Button(action: onDetail) {
                    Text("进入详情")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(accentColor, in: Capsule())
                }
                .buttonStyle(.plain)

                // 置顶按钮
                if let promote = onPromote {
                    Button(action: promote) {
                        Text("置顶显示")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity).padding(.vertical, 5)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}


// ==========================================================
// ⚠️ 下方的 HumanIDCardView 保持原样，与之前提供的一致
// 包含在这里是为了确保你可以无脑直接覆盖整个文件运行
// ==========================================================

struct HumanIDCardView: View {
    let human: Human
    let onDetail: () -> Void
    var isFlipped: Binding<Bool>? = nil
    
    @State private var _isFlipped = false
    @State private var showFront = true
    @AppStorage("shop_equipped_title") private var equippedTitle: String = ""
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    
    private var flipped: Bool {
        isFlipped?.wrappedValue ?? _isFlipped
    }
    
    private func toggleFlip() {
        if let binding = isFlipped {
            binding.wrappedValue.toggle()
        } else {
            _isFlipped.toggle()
        }
    }
    
    var body: some View {
        ZStack {
            humanFrontView
                .opacity(showFront ? 1 : 0)
            humanBackView
                .scaleEffect(x: -1, y: 1)
                .opacity(showFront ? 0 : 1)
        }
        .frame(width: ScreenCompat.width - 48, height: (ScreenCompat.width - 48) / 1.586)
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .animation(.spring(response: 0.6, dampingFraction: 0.78), value: flipped)
        .onChange(of: flipped) { _, newFlipped in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { showFront = !newFlipped }
            }
        }
        .onAppear { showFront = !flipped }
        .onTapGesture { toggleFlip() }
    }
    
    // MARK: - 人类主题色（V15 起直接读 themeColorHex 字段）
    private var humanThemeColor: Color { Color(hex: human.themeColor) }

    private var humanFrontView: some View {
        GeometryReader { geo in
            ZStack {
                // ── 层1：渐变背景
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [humanThemeColor, humanThemeColor.opacity(0.6), Color.goDarkBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // ── 层2：大号水印背景字
                Text(human.name.uppercased())
                    .font(.system(size: 110, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.045))
                    .rotationEffect(.degrees(-12))
                    .offset(x: geo.size.width * 0.05, y: -geo.size.height * 0.05)
                    .allowsHitTesting(false)

                // ── 层3：左图 + 右侧信息（与 PetCardFrontView 完全相同结构）
                HStack(alignment: .bottom, spacing: 0) {

                    // ── 左侧：头像大图（底部对齐，占52%宽）
                    ZStack(alignment: .bottom) {
                        // 底部地面光晕
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [humanThemeColor.opacity(0.5), .clear],
                                    center: .center, startRadius: 0, endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 36)
                            .blur(radius: 10)
                            .offset(y: 12)

                        // 头像（支持照片贴纸描边 / emoji fallback）
                        Group {
                            if let imageData = human.avatarImageData,
                               let uiImage = UIImage(data: imageData) {
                                ZStack {
                                    // 贴纸白边
                                    Image(uiImage: uiImage)
                                        .resizable().scaledToFit()
                                        .scaleEffect(1.06)
                                        .colorMultiply(.white)
                                        .shadow(color: .white, radius: 0, x: 2, y: 0)
                                        .shadow(color: .white, radius: 0, x: -2, y: 0)
                                        .shadow(color: .white, radius: 0, x: 0, y: 2)
                                        .shadow(color: .white, radius: 0, x: 0, y: -2)
                                        .shadow(color: .white, radius: 1, x: 2, y: 2)
                                        .shadow(color: .white, radius: 1, x: -2, y: -2)
                                    Image(uiImage: uiImage)
                                        .resizable().scaledToFit()
                                }
                            } else {
                                Text(human.avatarEmoji.isEmpty ? String(human.name.prefix(1)) : human.avatarEmoji)
                                    .font(.system(size: 160))
                                    .minimumScaleFactor(0.4)
                            }
                        }
                        .frame(width: geo.size.width * 0.52, height: geo.size.height * 0.90)
                        .shadow(color: .black.opacity(0.4), radius: 18, x: 12, y: 14)
                    }
                    .frame(width: geo.size.width * 0.52, alignment: .bottom)
                    .clipped()

                    // ── 右侧：信息排版（完全复刻 PetCardFrontView）
                    VStack(alignment: .trailing, spacing: 0) {
                        Spacer(minLength: 0)

                        // 相伴天数
                        let daysKnown = human.birthday.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? 0
                        if daysKnown > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("✨ 相识")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                                Text("\(daysKnown)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1).minimumScaleFactor(0.5)
                                Text("天")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .padding(.bottom, 6)
                        } else {
                            HStack(spacing: 3) {
                                Text("👤")
                                    .font(.system(size: 11))
                                Text(human.roleText)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .padding(.bottom, 10)
                        }

                        // 大名字
                        let isMe = (human.id.uuidString == activeHumanId)
                        let titleDisplay: String = {
                            guard isMe else { return "" }
                            switch equippedTitle {
                            case "title_guardian": return "🛡️ "
                            case "title_pioneer": return "🚀 "
                            case "title_chef": return "👨‍🍳 "
                            default: return ""
                            }
                        }()
                        Text(titleDisplay + human.name)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1).minimumScaleFactor(0.45)
                            .padding(.bottom, 6)

                        // 胶囊信息
                        VStack(alignment: .trailing, spacing: 4) {
                            // 角色 + 性别胶囊（从 notes 解析性别）
                            let genderText: String = {
                                if let r = human.notes.range(of: "性别:") {
                                    return String(human.notes[r.upperBound...].prefix(while: { $0 != "｜" && $0 != "\n" }))
                                }
                                return ""
                            }()
                            humanFrontPill("\(human.roleText)\(genderText.isEmpty ? "" : " · \(genderText)")")
                            // 年龄称号
                            if !human.ageText.isEmpty {
                                humanFrontPillScalable(human.ageText)
                            }
                            // 血型
                            if !human.bloodType.isEmpty {
                                humanFrontPill("血型 \(human.bloodType)")
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 28)
                    .frame(width: geo.size.width * 0.48, alignment: .trailing)
                }

                // ── 悬浮：右上角详情按钮
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onDetail) {
                            HStack(spacing: 4) {
                                Text("详情")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .padding(.top, 20).padding(.trailing, 18)
                    }
                    Spacer()
                }

                // ── 翻转图标（左下角）
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.leading, 18).padding(.bottom, 14)
                            .allowsHitTesting(false)
                        Spacer()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: humanThemeColor.opacity(0.5), radius: 24, x: 0, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
    }

    private func humanFrontPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }

    private func humanFrontPillScalable(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1).minimumScaleFactor(0.5)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
    }
    
    private var humanBackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.goDarkBlue, Color.goDeepNavy],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 0) {
                // ── 顶部：标题 + 详情按钮
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("QUICK ACCESS")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.45))
                        Text(human.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button(action: onDetail) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.goPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

                GoDashedDivider()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                // ── 人类专属 Quick Access 网格
                HumanQuickAccessGrid(human: human)
                    .padding(.horizontal, 16)

                Spacer(minLength: 0)

                // ── 底部基础信息行（一行紧凑显示）
                HStack(spacing: 12) {
                    if human.birthday != nil {
                        humanBackChip(icon: "🎂", text: human.ageText, accent: Color.goYellow)
                    }
                    if !human.bloodType.isEmpty {
                        humanBackChip(icon: "🩸", text: human.bloodType, accent: Color.goRed)
                    }
                    humanBackChip(icon: "👤", text: human.roleText, accent: Color.goTeal)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func humanBackChip(icon: String, text: String, accent: Color) -> some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(accent.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(0.25), lineWidth: 0.5))
    }
    
    private func goInfoRow(label: String, value: String, accent: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
    }
}

// MARK: - 人类专属 Quick Access 网格
struct HumanQuickAccessGrid: View {
    let human: Human
    @Environment(\.modelContext) private var modelContext
    @State private var showWeightSheet = false
    @State private var showWishSheet = false
    @State private var waterCheckedIn = false

    private struct HumanQAAction: Identifiable {
        let id: String
        let emoji: String
        let label: String
        let sublabel: String
        let accentHex: String
    }

    private let actions: [HumanQAAction] = [
        HumanQAAction(id: "weight",  emoji: "⚖️", label: "记录体重", sublabel: "健康管理", accentHex: "00D4AA"),
        HumanQAAction(id: "water",   emoji: "💧", label: "喝水打卡", sublabel: "今日饮水", accentHex: "4338FF"),
        HumanQAAction(id: "expense", emoji: "💸", label: "记一笔账", sublabel: "生活花费", accentHex: "FFB800"),
        HumanQAAction(id: "wish",    emoji: "📝", label: "待办心愿", sublabel: "愿望清单", accentHex: "C8FF00"),
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(actions) { action in
                humanQACell(action)
            }
        }
        .sheet(isPresented: $showWeightSheet) {
            GenericWeightEntrySheet(target: .human(human))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWishSheet) {
            HumanWishlistView(human: human)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func humanQACell(_ action: HumanQAAction) -> some View {
        let accent = Color(hex: action.accentHex)
        let isWaterDone = action.id == "water" && waterCheckedIn
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            handleHumanAction(action.id)
        } label: {
            VStack(spacing: 2) {
                Text(action.emoji).font(.system(size: 20))
                Text(action.label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(isWaterDone ? Color.goPrimary : .white.opacity(0.85))
                    .lineLimit(1)
                Text(isWaterDone ? "已打卡" : action.sublabel)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(isWaterDone ? Color.goPrimary.opacity(0.7) : .white.opacity(0.4))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(accent.opacity(isWaterDone ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isWaterDone ? Color.goPrimary.opacity(0.5) : accent.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func handleHumanAction(_ id: String) {
        switch id {
        case "weight":
            showWeightSheet = true
        case "water":
            let log = WaterLog(date: Date(), amountMl: 250)
            modelContext.insert(log)
            modelContext.safeSave()
            QuestManager.shared.awardAction(
                type: .general(humanReward: 3, petReward: 0, emoji: "💧", title: "\(human.name) 喝水打卡"),
                pet: nil, context: modelContext
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.3)) { waterCheckedIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { waterCheckedIn = false }
            }
        case "expense":
            // 花费跳转到 HumanDetailView（通过 onDetail 回调）
            // 此处因为 HumanIDCardView 已有 onDetail，仅做视觉反馈
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "wish":
            showWishSheet = true
        default:
            break
        }
    }
}
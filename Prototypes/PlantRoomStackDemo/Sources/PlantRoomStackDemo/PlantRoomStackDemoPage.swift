import SwiftUI

public struct PlantRoomStackDemoPage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var cardSpace
    @State private var selectedRoomID: String?
    @State private var selectedPlantID: String?

    private let rooms = DemoRoom.samples

    public init(initialRoomID: String? = nil) {
        _selectedRoomID = State(initialValue: initialRoomID)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                DemoBackground()

                if let selectedRoom {
                    expandedRoom(selectedRoom, viewport: proxy.size)
                        .transition(.opacity)
                } else {
                    roomOverview
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("plant-room-stack-demo")
    }

    private var selectedRoom: DemoRoom? {
        rooms.first { $0.id == selectedRoomID }
    }

    private var roomOverview: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 22) {
                overviewHeader

                ForEach(rooms) { room in
                    RoomStackPreview(
                        room: room,
                        namespace: cardSpace,
                        onOpen: { open(room) }
                    )
                }

                Text("假数据原型 · 不会写入植物或房间资料")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.demoLime)
                    .frame(width: 8, height: 8)

                Text("MOTION PROTOTYPE")
                    .font(.caption2.weight(.black))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
            }

            Text("植物房间")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text("每个房间是一叠会呼吸的植物卡片。\n轻点任意卡片堆，把它展开。")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }

    private func expandedRoom(_ room: DemoRoom, viewport: CGSize) -> some View {
        VStack(spacing: 0) {
            expandedHeader(room)

            ScrollView(showsIndicators: false) {
                VStack(spacing: -30) {
                    ForEach(Array(room.plants.indices), id: \.self) { index in
                        let plant = room.plants[index]
                        Button {
                            focus(plant)
                        } label: {
                            DemoPlantCard(
                                room: room,
                                plant: plant,
                                presentation: .expanded,
                                isFocused: selectedPlantID == plant.id
                            )
                        }
                        .buttonStyle(.plain)
                        .matchedGeometryEffect(
                            id: cardID(room: room, plant: plant),
                            in: cardSpace
                        )
                        .rotationEffect(expandedRotation(for: index))
                        .offset(x: expandedHorizontalOffset(for: index))
                        .zIndex(Double(room.plants.count - index))
                        .animation(
                            motion.delay(reduceMotion ? 0 : Double(index) * 0.035),
                            value: selectedRoomID
                        )
                        .accessibilityLabel(
                            "\(plant.name)，\(plant.status.label)，\(plant.careNote)"
                        )
                        .accessibilityHint("轻点突出这张植物卡片")
                        .accessibilityIdentifier("demo-plant-card-\(plant.id)")
                    }
                }
                .frame(maxWidth: min(viewport.width - 34, 390))
                .padding(.top, 18)
                .padding(.bottom, 118)
                .frame(maxWidth: .infinity)
            }
            .scrollClipDisabled()
        }
        .safeAreaInset(edge: .bottom) {
            expandedHint(room)
        }
        .accessibilityIdentifier("demo-room-expanded-\(room.id)")
    }

    private func expandedHeader(_ room: DemoRoom) -> some View {
        HStack(spacing: 14) {
            Button(action: closeRoom) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 44, height: 44)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(DemoPressButtonStyle())
            .accessibilityLabel("收起房间")
            .accessibilityIdentifier("demo-room-close")

            VStack(alignment: .leading, spacing: 2) {
                Label(room.name, systemImage: room.symbol)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.primary)

                Text("\(room.plants.count) 株植物 · \(room.dueCount) 株待照护")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("已展开")
                .font(.caption2.weight(.black))
                .foregroundStyle(Color.demoInk)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(room.tint.opacity(0.55), in: Capsule())
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func expandedHint(_ room: DemoRoom) -> some View {
        HStack(spacing: 10) {
            Image(systemName: selectedPlantID == nil ? "hand.tap.fill" : "sparkles")
                .foregroundStyle(room.tint)

            Text(selectedPlantID == nil ? "轻点植物卡片，查看层次反馈" : "卡片会保留真实内容与原生交互")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var motion: Animation {
        reduceMotion
            ? .easeOut(duration: 0.18)
            : .spring(duration: 0.68, bounce: 0.22)
    }

    private func open(_ room: DemoRoom) {
        selectedPlantID = nil
        withAnimation(motion) {
            selectedRoomID = room.id
        }
    }

    private func closeRoom() {
        selectedPlantID = nil
        withAnimation(motion) {
            selectedRoomID = nil
        }
    }

    private func focus(_ plant: DemoPlant) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.42, bounce: 0.28)) {
            selectedPlantID = selectedPlantID == plant.id ? nil : plant.id
        }
    }

    private func cardID(room: DemoRoom, plant: DemoPlant) -> String {
        "\(room.id)-\(plant.id)"
    }

    private func expandedRotation(for index: Int) -> Angle {
        guard !reduceMotion else { return .zero }
        let values = [-1.8, 1.2, -0.7, 1.6, -1.1]
        return .degrees(values[index % values.count])
    }

    private func expandedHorizontalOffset(for index: Int) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let values: [CGFloat] = [-5, 7, -3, 6, -6]
        return values[index % values.count]
    }
}

private struct RoomStackPreview: View {
    let room: DemoRoom
    let namespace: Namespace.ID
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onOpen) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(room.plants.indices.prefix(3)).reversed(), id: \.self) { index in
                    let plant = room.plants[index]
                    DemoPlantCard(
                        room: room,
                        plant: plant,
                        presentation: .collapsed,
                        isFocused: false
                    )
                    .matchedGeometryEffect(
                        id: "\(room.id)-\(plant.id)",
                        in: namespace
                    )
                    .scaleEffect(1 - CGFloat(index) * 0.035, anchor: .top)
                    .rotationEffect(compactRotation(for: index))
                    .offset(
                        x: CGFloat(index) * 4,
                        y: CGFloat(index) * 12
                    )
                    .zIndex(Double(3 - index))
                }

                HStack(spacing: 7) {
                    Text("点击展开")
                        .font(.caption2.weight(.black))
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2.weight(.black))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .offset(x: 16, y: 146)
                .zIndex(10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 185, alignment: .top)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .buttonStyle(DemoPressButtonStyle())
        .accessibilityLabel("\(room.name)，\(room.plants.count) 株植物，\(room.dueCount) 株待照护")
        .accessibilityHint("轻点展开这个房间的植物卡片")
        .accessibilityIdentifier("demo-room-stack-\(room.id)")
    }

    private func compactRotation(for index: Int) -> Angle {
        guard !reduceMotion else { return .zero }
        let values = [0.0, -1.6, 2.2]
        return .degrees(values[index % values.count])
    }
}

private struct DemoPlantCard: View {
    let room: DemoRoom
    let plant: DemoPlant
    let presentation: Presentation
    let isFocused: Bool

    @Environment(\.colorScheme) private var colorScheme

    enum Presentation {
        case collapsed
        case expanded

        var height: CGFloat {
            switch self {
            case .collapsed: 154
            case .expanded: 176
            }
        }
    }

    var body: some View {
        ZStack {
            cardBackground

            Circle()
                .fill(room.tint.opacity(colorScheme == .dark ? 0.22 : 0.32))
                .frame(width: 170, height: 170)
                .blur(radius: 2)
                .offset(x: 128, y: -68)

            Circle()
                .fill(.white.opacity(colorScheme == .dark ? 0.06 : 0.34))
                .frame(width: 105, height: 105)
                .offset(x: 88, y: 58)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Label(room.name, systemImage: room.symbol)
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.primary.opacity(0.72))

                    Spacer(minLength: 8)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(plant.status.color)
                            .frame(width: 7, height: 7)
                        Text(plant.status.label)
                    }
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.white.opacity(colorScheme == .dark ? 0.08 : 0.52), in: Capsule())
                }

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plant.name)
                            .font(.system(size: presentation == .expanded ? 25 : 22, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(plant.variety)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.primary.opacity(0.58))
                            .lineLimit(1)

                        if presentation == .expanded {
                            Label(plant.careNote, systemImage: "drop.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.primary.opacity(0.72))
                                .padding(.top, 7)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(plant.emoji)
                        .font(.system(size: presentation == .expanded ? 61 : 53))
                        .shadow(color: room.tint.opacity(0.28), radius: 16, y: 8)
                        .accessibilityHidden(true)
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: presentation.height)
        .background(baseColor)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(
                    isFocused ? room.tint : .white.opacity(colorScheme == .dark ? 0.10 : 0.62),
                    lineWidth: isFocused ? 3 : 1
                )
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10),
            radius: isFocused ? 24 : 16,
            y: isFocused ? 14 : 9
        )
        .scaleEffect(isFocused ? 1.025 : 1)
        .offset(y: isFocused ? -7 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                baseColor,
                room.tint.opacity(colorScheme == .dark ? 0.22 : 0.30)
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    private var baseColor: Color {
        colorScheme == .dark
            ? Color(red: 0.095, green: 0.105, blue: 0.11)
            : Color(red: 0.985, green: 0.982, blue: 0.955)
    }
}

private struct DemoBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.045, green: 0.055, blue: 0.06), Color(red: 0.075, green: 0.075, blue: 0.065)]
                    : [Color(red: 0.965, green: 0.95, blue: 0.87), Color(red: 0.93, green: 0.965, blue: 0.91)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.demoLime.opacity(colorScheme == .dark ? 0.08 : 0.22))
                .frame(width: 310, height: 310)
                .blur(radius: 70)
                .offset(x: 150, y: -300)

            Circle()
                .fill(Color.demoCoral.opacity(colorScheme == .dark ? 0.07 : 0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -165, y: 340)
        }
        .ignoresSafeArea()
    }
}

private struct DemoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

private struct DemoRoom: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let tint: Color
    let plants: [DemoPlant]

    var dueCount: Int {
        plants.count { $0.status == .needsCare }
    }

    static let samples: [DemoRoom] = [
        DemoRoom(
            id: "living-room",
            name: "客厅",
            symbol: "sofa.fill",
            tint: .demoLime,
            plants: [
                DemoPlant(id: "momo", name: "Momo", variety: "龟背竹", emoji: "🌿", status: .needsCare, careNote: "今天需要浇水"),
                DemoPlant(id: "piko", name: "Piko", variety: "黄金葛", emoji: "🪴", status: .happy, careNote: "状态很好"),
                DemoPlant(id: "ruby", name: "Ruby", variety: "橡皮树", emoji: "🌱", status: .happy, careNote: "3 天后检查"),
                DemoPlant(id: "fig", name: "Fig", variety: "琴叶榕", emoji: "🌳", status: .watch, careNote: "观察日照")
            ]
        ),
        DemoRoom(
            id: "bedroom",
            name: "卧室",
            symbol: "bed.double.fill",
            tint: .demoLilac,
            plants: [
                DemoPlant(id: "luna", name: "Luna", variety: "白鹤芋", emoji: "🌷", status: .happy, careNote: "状态很好"),
                DemoPlant(id: "cloud", name: "Cloud", variety: "竹芋", emoji: "🍃", status: .watch, careNote: "需要提高湿度"),
                DemoPlant(id: "snake", name: "Sumi", variety: "虎尾兰", emoji: "🌵", status: .happy, careNote: "5 天后检查")
            ]
        ),
        DemoRoom(
            id: "balcony",
            name: "阳台",
            symbol: "sun.max.fill",
            tint: .demoCoral,
            plants: [
                DemoPlant(id: "olive", name: "Oli", variety: "橄榄树", emoji: "🌳", status: .needsCare, careNote: "今天需要浇水"),
                DemoPlant(id: "basil", name: "Basil", variety: "罗勒", emoji: "🌿", status: .needsCare, careNote: "需要采摘"),
                DemoPlant(id: "lavender", name: "Vera", variety: "薰衣草", emoji: "🪻", status: .happy, careNote: "状态很好"),
                DemoPlant(id: "cactus", name: "Spike", variety: "仙人掌", emoji: "🌵", status: .happy, careNote: "7 天后检查")
            ]
        )
    ]
}

private struct DemoPlant: Identifiable {
    let id: String
    let name: String
    let variety: String
    let emoji: String
    let status: DemoPlantStatus
    let careNote: String
}

private enum DemoPlantStatus: Equatable {
    case happy
    case watch
    case needsCare

    var label: String {
        switch self {
        case .happy: "舒适"
        case .watch: "留意"
        case .needsCare: "待照护"
        }
    }

    var color: Color {
        switch self {
        case .happy: .demoGreen
        case .watch: .demoOrange
        case .needsCare: .demoCoral
        }
    }
}

private extension Color {
    static let demoInk = Color(red: 0.105, green: 0.125, blue: 0.12)
    static let demoLime = Color(red: 0.70, green: 0.89, blue: 0.39)
    static let demoLilac = Color(red: 0.74, green: 0.68, blue: 0.96)
    static let demoCoral = Color(red: 0.98, green: 0.54, blue: 0.42)
    static let demoGreen = Color(red: 0.24, green: 0.67, blue: 0.47)
    static let demoOrange = Color(red: 0.96, green: 0.65, blue: 0.28)
}

#Preview("房间卡片堆") {
    PlantRoomStackDemoPage()
}

#Preview("客厅已展开") {
    PlantRoomStackDemoPage(initialRoomID: "living-room")
}

#Preview("深色模式") {
    PlantRoomStackDemoPage()
        .preferredColorScheme(.dark)
}

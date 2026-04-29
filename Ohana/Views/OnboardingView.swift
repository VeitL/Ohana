//
//  OnboardingView.swift
//  Ohana
//
//  首次启动引导 — GO UI 主题重设计
//  设计规范：深蓝渐变背景 + 浮动色球 + 荧光绿主色 + 玻璃卡片
//

import SwiftUI
import SwiftData

// MARK: - Ohana App Icon Shape (matches SVG in design system)

private struct OhanaIconView: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.219, style: .continuous)
                .fill(Color(hex: "0C1640"))
                .frame(width: size, height: size)

            HeartbeatPath()
                .stroke(Color.goLime, style: StrokeStyle(lineWidth: size * 0.063,
                                                          lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.531, height: size * 0.25)

            Circle()
                .fill(Color.goLime)
                .frame(width: size * 0.094, height: size * 0.094)
        }
    }

    private struct HeartbeatPath: Shape {
        func path(in rect: CGRect) -> Path {
            // SVG path scaled to rect: M 60 140 C 60 96 108 96 128 128 C 148 160 196 160 196 116 C 196 88 168 80 148 108
            // Normalised to 0-1 within the 136×80 bounding box of the curve
            let w = rect.width, h = rect.height
            var p = Path()
            p.move(to: CGPoint(x: 0, y: h * 0.75))
            p.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.5),
                control1: CGPoint(x: 0, y: h * 0.2),
                control2: CGPoint(x: w * 0.353, y: h * 0.2)
            )
            p.addCurve(
                to: CGPoint(x: w, y: h * 0.225),
                control1: CGPoint(x: w * 0.647, y: h * 0.8),
                control2: CGPoint(x: w, y: h * 0.8)
            )
            p.addCurve(
                to: CGPoint(x: w * 0.647, y: h * 0.7),
                control1: CGPoint(x: w, y: h * 0),
                control2: CGPoint(x: w * 0.794, y: h * 0)
            )
            return p
        }
    }
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""
    @AppStorage("ohana_show_first_success_card") private var showFirstSuccessCard: Bool = false
    @AppStorage("ohana_first_quick_checkin_completed") private var firstQuickCheckInCompleted: Bool = false
    @AppStorage("appLanguage") private var appLanguage: String = AppLanguage.fallbackCode
    var isReplay: Bool = false
    var onReplayFinished: (() -> Void)?

    private enum FlowStep: Int, Equatable {
        case intro = 0
        case profile = 1
        case firstPet = 2
    }

    private struct IntroCard: Identifiable {
        let id: String
        let label: String
        let title: String
        let subtitle: String
        let icon: String
        let color: Color
        let labelForeground: Color
        let iconForeground: Color
        let bullets: [String]
        let mockRows: [String]
    }

    @State private var step: FlowStep = .intro
    @State private var introPage: Int = 0
    /// 每次进入「添加人类」步骤刷新，避免从欢迎页返回后残留半填状态
    @State private var humanWizardSessionId = UUID()
    @State private var petWizardSessionId = UUID()

    @State private var blobPulse = false
    @State private var iconPulse = false

    private var isEnglish: Bool { AppLanguage.normalize(appLanguage) == "en" }

    private var introCards: [IntroCard] {
        [
        IntroCard(
            id: "home",
            label: isEnglish ? "HOME" : "首页",
            title: isEnglish ? "One home for every family member" : "把宠物和家人的状态放在一个首页",
            subtitle: isEnglish ? "Wallet-style cards show who needs attention, what changed, and where to jump next." : "像钱包一样的卡片堆，直接看到谁需要照顾、今天发生了什么、下一步去哪。",
            icon: "rectangle.stack.fill",
            color: Color(hex: "5B6AFF"),
            labelForeground: .white,
            iconForeground: .white,
            bullets: isEnglish ? ["Pet, human, and plant cards", "Tap to expand full details", "No spreadsheet-style chaos"] : ["宠物、家人、植物统一管理", "点击卡片展开完整信息", "不用在多个表格里找记录"],
            mockRows: isEnglish ? ["Mochi · walk due", "Lilo · water changed", "Family · 2 helpers"] : ["Mochi · 今天待遛", "Lilo · 换水已完成", "家人 · 2 位协作者"]
        ),
        IntroCard(
            id: "quick",
            label: isEnglish ? "QUICK LOGS" : "快速记录",
            title: isEnglish ? "Log care in seconds" : "喂食、喂水、铲屎、逗玩几秒完成",
            subtitle: isEnglish ? "Daily actions stay lightweight, with the current device owner automatically recorded as the executor." : "日常照顾不需要填长表单，执行者会自动绑定为当前手机使用者。",
            icon: "bolt.heart.fill",
            color: Color.goLime,
            labelForeground: Color.arkInk,
            iconForeground: Color.arkInk,
            bullets: isEnglish ? ["Feed, water, litter, play", "Weight and health records", "Executor saved automatically"] : ["喂食/喂水/换水/铲屎/便便/逗玩", "体重、护理、健康也能快速记录", "自动记录是谁做的"],
            mockRows: isEnglish ? ["Feed +1", "Water changed", "Weight 5.2 kg"] : ["喂食 +1", "换水完成", "体重 5.2 kg"]
        ),
        IntroCard(
            id: "calendar",
            label: isEnglish ? "CALENDAR" : "日历提醒",
            title: isEnglish ? "Never lose the next important date" : "疫苗、用药、生日和护理计划不再靠脑子记",
            subtitle: isEnglish ? "Pet-specific calendars keep reminders and history tied to the right companion." : "日程会和对应宠物绑定，打开宠物日历只看它相关的安排。",
            icon: "calendar.badge.clock",
            color: Color.goTeal,
            labelForeground: .white,
            iconForeground: .white,
            bullets: isEnglish ? ["Vaccines and medication", "Food stock and care plans", "Filter by pet"] : ["疫苗、用药、生日提醒", "粮仓和护理计划", "按宠物查看相关日程"],
            mockRows: isEnglish ? ["Vaccine · Apr 30", "Medication · tonight", "Food stock · 6 days"] : ["疫苗 · 4月30日", "用药 · 今晚", "粮仓 · 还能吃 6 天"]
        ),
        IntroCard(
            id: "family",
            label: isEnglish ? "FAMILY" : "家庭协作",
            title: isEnglish ? "Know who paid and who helped" : "谁照顾了、谁花了钱，都有记录",
            subtitle: isEnglish ? "Shared care logs, payer tracking, and collaboration modules make multi-person households clearer." : "多人家庭里，照顾记录和花费支付者都会保留下来，减少重复沟通。",
            icon: "person.2.fill",
            color: Color(hex: "FF6B9D"),
            labelForeground: .white,
            iconForeground: .white,
            bullets: isEnglish ? ["Payer saved for expenses", "Human collaboration when needed", "Clear family history"] : ["花费可记录支付者", "多人时显示家庭协作", "家庭记录更清楚"],
            mockRows: isEnglish ? ["Paid by Alex · 32", "Litter by Jamie", "Care streak · 8 days"] : ["Alex 支付 · 32", "Jamie 铲屎", "连续照顾 · 8 天"]
        ),
        IntroCard(
            id: "oasis",
            label: isEnglish ? "REWARDS" : "绿洲奖励",
            title: isEnglish ? "Make consistency visible" : "把坚持照顾变成可见的成长",
            subtitle: isEnglish ? "Care actions earn coconuts, streaks, and Oasis progress without turning chores into noise." : "完成照顾会获得椰子、连续打卡和绿洲成长，让家务变得更有反馈。",
            icon: "sparkles",
            color: Color(hex: "FFB020"),
            labelForeground: Color.arkInk,
            iconForeground: Color.arkInk,
            bullets: isEnglish ? ["Coconut rewards", "Streak feedback", "Oasis growth"] : ["椰子奖励", "连续打卡反馈", "绿洲成长"],
            mockRows: isEnglish ? ["Coconuts +12", "Streak 8", "Oasis level 3"] : ["椰子 +12", "连续 8 天", "绿洲等级 3"]
        )
        ]
    }

    private var isLastIntroPage: Bool {
        introPage >= introCards.count - 1
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background: navy gradient + animated blobs
            LinearGradient(
                colors: [Color(hex: "2D4ECC"), Color(hex: "1A2E8A"), Color(hex: "0C1640")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.goLime)
                        .frame(width: 260, height: 260)
                        .blur(radius: 80).opacity(0.18)
                        .offset(x: blobPulse ? -50 : -70, y: blobPulse ? -60 : -80)
                    Circle()
                        .fill(Color(hex: "5B6AFF"))
                        .frame(width: 300, height: 300)
                        .blur(radius: 90).opacity(0.35)
                        .offset(x: blobPulse ? geo.size.width - 80 : geo.size.width - 100,
                                y: blobPulse ? 180 : 220)
                    Circle()
                        .fill(Color(hex: "A855F7"))
                        .frame(width: 240, height: 240)
                        .blur(radius: 90).opacity(0.25)
                        .offset(x: blobPulse ? -40 : -60,
                                y: blobPulse ? geo.size.height * 0.6 : geo.size.height * 0.55)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // ── Content
            content
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { blobPulse = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true }
            if !isReplay && !currentActiveHumanId.isEmpty && !hasOnboarded {
                step = .firstPet
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .intro:
            introFlow
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .profile:
            humanOnboardingWizard
                .transition(.opacity)
        case .firstPet:
            petChoiceFlow
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step.rawValue ? Color.goLime : Color.white.opacity(0.15))
                    .frame(width: i == step.rawValue ? 28 : nil, height: 4)
                    .animation(.spring(response: 0.4), value: step)
            }
        }
    }

    /// 与「添加家人 → 家庭成员」相同的完整人类向导，完成后绑定为当前设备主人
    private var humanOnboardingWizard: some View {
        NavigationStack {
            ZStack {
                GoIslandWizardBackdrop()
                AddHumanWizardView(
                    onComplete: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                            step = .firstPet
                        }
                    },
                    onHumanSaved: { human in
                        currentActiveHumanId = human.id.uuidString
                    }
                )
                .id(humanWizardSessionId)
            }
            .navigationTitle(isEnglish ? "Family Member" : "家庭成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { step = .intro }
                    } label: {
                        Text(isEnglish ? "Back" : "返回")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }
                }
            }
        }
    }

    // MARK: - Intro flow

    private var introFlow: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 28)
                .padding(.top, 54)
                .padding(.bottom, 14)

            VStack(spacing: 7) {
                OhanaIconView(size: 46)
                    .scaleEffect(iconPulse ? 1.04 : 1.0)
                    .shadow(color: Color.goLime.opacity(iconPulse ? 0.34 : 0.18), radius: 24)

                Text(isEnglish ? "Welcome to Ohana" : "欢迎来到 Ohana")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(isEnglish ? "Swipe through the essentials, then set up your family." : "先看完核心功能，再开始建立你的家庭。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 24)

            TabView(selection: $introPage) {
                ForEach(Array(introCards.enumerated()), id: \.element.id) { index, card in
                    introFeatureCard(card)
                        .tag(index)
                        .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: 470)
            .padding(.top, 14)

            introPageIndicator
                .padding(.top, 4)

            Spacer(minLength: 12)

            ctaArea
                .padding(.horizontal, 24)
                .padding(.bottom, 42)
        }
    }

    private func introFeatureCard(_ card: IntroCard) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(card.label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(card.labelForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(card.color, in: Capsule())
                Spacer()
                Image(systemName: card.icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(card.iconForeground)
                    .frame(width: 42, height: 42)
                    .background(card.color, in: Circle())
                    .shadow(color: card.color.opacity(0.35), radius: 14, y: 7)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(card.title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(card.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            introMockScreenshot(card)

            VStack(spacing: 8) {
                ForEach(card.bullets, id: \.self) { bullet in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(card.color)
                        Text(bullet)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 24, y: 14)
    }

    private func introMockScreenshot(_ card: IntroCard) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [card.color.opacity(0.92), card.color.mix(with: .black, by: 0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 82, height: 116)
                    .overlay(alignment: .topLeading) {
                        Image(systemName: card.icon)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(card.iconForeground)
                            .padding(13)
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 5) {
                            Capsule().fill(.white.opacity(0.86)).frame(width: 44, height: 6)
                            Capsule().fill(.white.opacity(0.42)).frame(width: 58, height: 5)
                        }
                        .padding(13)
                    }

                VStack(spacing: 7) {
                    ForEach(Array(card.mockRows.enumerated()), id: \.offset) { index, row in
                        HStack(spacing: 8) {
                            Image(systemName: index == 0 ? "checkmark.circle.fill" : index == 1 ? "clock.fill" : "sparkles")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(index == 0 ? card.color : .white.opacity(0.65))
                                .frame(width: 18)
                            Text(row)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(.white.opacity(index == 0 ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(hex: "07112F").opacity(0.72), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private var introPageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(introCards.indices, id: \.self) { index in
                Capsule()
                    .fill(index == introPage ? Color.goLime : Color.white.opacity(0.22))
                    .frame(width: index == introPage ? 24 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: introPage)
            }
        }
    }

    // MARK: - CTA area

    private var ctaArea: some View {
        VStack(spacing: 12) {
            Button(action: advanceFromWelcome) {
                HStack(spacing: 8) {
                    Text(isLastIntroPage ? (isEnglish ? "Continue" : "继续") : (isEnglish ? "Next" : "下一张"))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color(hex: "1A1A2E"))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color(hex: "1A1A2E"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.goLime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !isLastIntroPage {
                Button(isEnglish ? "Skip intro" : "跳过介绍") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    startProfileSetup()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
            } else {
                Text(isEnglish ? "Local-first · No account · Data stays on your device" : "完全本地存储 · 无账号 · 数据只在你的设备上")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.28))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Optional first pet

    private var petChoiceFlow: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 28)
                .padding(.top, 60)
                .padding(.bottom, 34)

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.goLime.opacity(iconPulse ? 0.22 : 0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 42)
                Text("🐾")
                    .font(.system(size: 92))
                    .scaleEffect(iconPulse ? 1.08 : 0.96)
                Text(isEnglish ? "First Companion" : "第一个伙伴")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(Color.arkInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.goLime, in: Capsule())
                    .offset(x: 66, y: 80)
            }
            .padding(.bottom, 22)

            VStack(spacing: 12) {
                Text(isEnglish ? "Bring your first pet onto the island?" : "要把第一个宠物接上岛吗？")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(isEnglish ? "This step is optional. Ohana prepares quick record entries, while feeding and water-change plans appear only after you set them up." : "这一步不是强制的。添加后，Ohana 会准备快捷记录入口；喂食、换水等计划只会在你主动设置后出现。")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 34)

            VStack(spacing: 10) {
                onboardingMiniTip(icon: "bolt.fill", text: isEnglish ? "Species-aware quick actions" : "生成物种专属快捷操作")
                onboardingMiniTip(icon: "calendar", text: isEnglish ? "Add birthdays, vaccines, and care reminders later" : "生日、疫苗和护理提醒可继续完善")
                onboardingMiniTip(icon: "sparkles", text: isEnglish ? "Complete a first light log on Home to see coconut rewards" : "进入首页后完成第一次轻量打卡，马上看到椰子奖励")
            }
            .padding(18)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 24)
            .padding(.top, 26)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                Button {
                    petWizardSessionId = UUID()
                    step = .firstPet
                    showPetWizard = true
                } label: {
                    Label(isEnglish ? "Add First Pet" : "添加第一个宠物", systemImage: "pawprint.fill")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(Color.arkInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.goLime, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button(isEnglish ? "Enter Home First" : "先进入首页") {
                    finishOnboarding()
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 42)
        }
        .sheet(isPresented: $showPetWizard) {
            NavigationStack {
                ZStack {
                    GoIslandWizardBackdrop()
                    AddPetWizardView {
                        showPetWizard = false
                        finishOnboarding()
                    }
                    .id(petWizardSessionId)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(isEnglish ? "Later" : "稍后") {
                            showPetWizard = false
                        }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.goLime)
                    }
                }
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled(false)
        }
    }

    @State private var showPetWizard = false

    private func onboardingMiniTip(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.goLime)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
    }

    private func advanceFromWelcome() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isLastIntroPage {
            startProfileSetup()
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                introPage = min(introPage + 1, introCards.count - 1)
            }
        }
    }

    private func startProfileSetup() {
        humanWizardSessionId = UUID()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { step = .profile }
    }

    private func finishOnboarding() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if isReplay {
            onReplayFinished?()
            return
        }
        firstQuickCheckInCompleted = false
        showFirstSuccessCard = true
        withAnimation(.easeInOut(duration: 0.28)) {
            hasOnboarded = true
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}

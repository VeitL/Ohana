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

    @State private var step: Int = 0
    /// 每次进入「添加人类」步骤刷新，避免从欢迎页返回后残留半填状态
    @State private var humanWizardSessionId = UUID()

    @State private var blobPulse = false
    @State private var iconPulse = false

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
            VStack(spacing: 0) {
                if step == 0 {
                    progressBar
                        .padding(.horizontal, 28)
                        .padding(.top, 60)
                        .padding(.bottom, 32)

                    Spacer(minLength: 0)

                    welcomeStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)

                    Spacer(minLength: 0)

                    ctaArea
                        .padding(.horizontal, 24)
                        .padding(.bottom, 48)
                } else {
                    humanOnboardingWizard
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { blobPulse = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { iconPulse = true }
            if hasOnboarded && currentActiveHumanId.isEmpty {
                humanWizardSessionId = UUID()
                step = 1
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.goLime : Color.white.opacity(0.15))
                    .frame(width: i == step ? 28 : nil, height: 4)
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
                    onComplete: { },
                    onHumanSaved: { human in
                        currentActiveHumanId = human.id.uuidString
                        hasOnboarded = true
                    }
                )
                .id(humanWizardSessionId)
            }
            .navigationTitle("家庭成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { step = 0 }
                    } label: {
                        Text("返回")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.goLime)
                    }
                }
            }
        }
    }

    // MARK: - CTA area

    private var ctaArea: some View {
        VStack(spacing: 12) {
            Button(action: advanceFromWelcome) {
                HStack(spacing: 8) {
                    Text("继续")
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

            Text("完全本地存储 · 无账号 · 数据只在你的设备上")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.28))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            // App icon with glow
            ZStack {
                Circle()
                    .fill(Color.goLime)
                    .frame(width: 130, height: 130)
                    .blur(radius: 40)
                    .opacity(iconPulse ? 0.35 : 0.2)
                OhanaIconView(size: 96)
                    .scaleEffect(iconPulse ? 1.04 : 1.0)
            }
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: iconPulse)

            VStack(spacing: 10) {
                Text("欢迎来到 Ohana")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Ohana means family.\nNobody gets left behind.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            // Feature cards
            HStack(spacing: 10) {
                featureCard(icon: "pawprint.fill",  text: "记录宠物",   color: Color(hex: "5B6AFF"))
                featureCard(icon: "leaf.fill",       text: "培育岛屿",  color: Color.goLime)
                featureCard(icon: "heart.fill",      text: "家人联动",  color: Color(hex: "FF6B9D"))
            }
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func featureCard(icon: String, text: String, color: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.06))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            }
        )
    }

    private func advanceFromWelcome() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        humanWizardSessionId = UUID()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { step = 1 }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}

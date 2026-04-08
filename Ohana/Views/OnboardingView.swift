//
//  OnboardingView.swift
//  Ohana
//
//  N3: 首次启动引导 — 建立用户资料并自动绑定设备身份
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("ohana_has_onboarded") private var hasOnboarded: Bool = false
    @AppStorage("currentActiveHumanId") private var currentActiveHumanId: String = ""

    @State private var step: Int = 0
    @State private var userName: String = ""
    @State private var selectedEmoji: String = "😊"
    @State private var selectedColor: String = "4338FF"

    private let emojiOptions = ["😊","😎","🧑‍💻","👩‍🍳","🧑‍🎨","🐱","🐶","🦊","🐸","🦁","🌟","🔥"]
    private let colorOptions = ["4338FF","C8FF00","00E5C8","FF4757","FF9F43","A29BFE","FD79A8","FDCB6E"]

    var body: some View {
        ZStack {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // 进度条
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Color.goPrimary : Color.white.opacity(0.15))
                            .frame(height: 4)
                            .animation(.spring(response: 0.4), value: step)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)
                .padding(.bottom, 40)

                Spacer()

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: profileStep
                    default: bindingStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)

                Spacer()

                VStack(spacing: 12) {
                    Button(action: nextStep) {
                        HStack(spacing: 8) {
                            Text(step == 2 ? "进入 Ohana 🥥" : "继续")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            if step < 2 {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canProceed ? Color.goPrimary : Color.white.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                    }
                    .disabled(!canProceed)

                    if step == 0 {
                        Text("完全本地，无需账号，数据只存在你的设备上")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.3))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            if hasOnboarded && currentActiveHumanId.isEmpty {
                step = 1
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Text("🌴").font(.system(size: 80))
            VStack(spacing: 10) {
                Text("欢迎来到 Ohana")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Ohana means family.\nNobody gets left behind.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 20) {
                featurePill(icon: "pawprint.fill", text: "记录宠物")
                featurePill(icon: "leaf.fill", text: "养成岛屿")
                featurePill(icon: "heart.fill", text: "家人联动")
            }
        }
        .padding(.horizontal, 24)
    }

    private var profileStep: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("先认识一下你吧")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("这台设备的主人是谁？")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            ZStack {
                Circle()
                    .fill(Color(hex: selectedColor).opacity(0.25))
                    .frame(width: 80, height: 80)
                Circle()
                    .strokeBorder(Color(hex: selectedColor).opacity(0.6), lineWidth: 2)
                    .frame(width: 80, height: 80)
                Text(selectedEmoji).font(.system(size: 40))
            }

            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 22)
                TextField("你的名字", text: $userName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            }
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("选一个头像")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text(emoji).font(.system(size: 26))
                                .frame(width: 48, height: 48)
                                .background(
                                    selectedEmoji == emoji
                                        ? Color(hex: selectedColor).opacity(0.3)
                                        : Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            selectedEmoji == emoji ? Color(hex: selectedColor) : .clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("主题颜色")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 4)
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            selectedColor = hex
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: selectedColor == hex ? 2.5 : 0)
                                        .padding(2)
                                )
                                .scaleEffect(selectedColor == hex ? 1.15 : 1.0)
                                .animation(.spring(response: 0.3), value: selectedColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private var bindingStep: some View {
        VStack(spacing: 24) {
            Text("🔗").font(.system(size: 64))
            VStack(spacing: 10) {
                Text("设备身份已绑定")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("这台设备将以\n\(userName.isEmpty ? "你" : userName) 的身份记录所有打卡行为\n并获得椰子奖励 🥥")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(hex: selectedColor).opacity(0.2)).frame(width: 56, height: 56)
                    Text(selectedEmoji).font(.system(size: 28))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(userName)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("设备主人")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.goPrimary)
                }
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.goPrimary)
            }
            .padding(16)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Text("你随时可以在设置中更改设备身份")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var canProceed: Bool {
        if step == 1 { return !userName.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    private func nextStep() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if step == 1 { createHumanAndBind() }
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            withAnimation { hasOnboarded = true }
        }
    }

    private func createHumanAndBind() {
        let name = userName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let human = Human(name: name, avatarEmoji: selectedEmoji)
        human.themeColorHex = selectedColor
        modelContext.insert(human)
        try? modelContext.save()
        currentActiveHumanId = human.id.uuidString
    }

    @ViewBuilder
    private func featurePill(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.goPrimary)
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(width: 72, height: 64)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    OnboardingView()
        .modelContainer(SharedModelContainer.make())
}

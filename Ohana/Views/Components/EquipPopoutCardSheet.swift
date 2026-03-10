//
//  EquipPopoutCardSheet.swift
//  Ohana
//
//  3D 破框悬浮卡片换装引导 Sheet
//  用户购买 fx_popout_card 后，通过此 Sheet 粘贴透明抠图并激活 popout 风格
//

import SwiftUI
import SwiftData

struct EquipPopoutCardSheet: View {
    let pet: Pet
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isPasting = false
    @State private var pasteBreathing = false
    @State private var showErrorToast = false
    @State private var showSuccessToast = false

    private var hasPasteboardImage: Bool { UIPasteboard.general.hasImages }

    var body: some View {
        ZStack {
            ArkBackgroundView()

            VStack(spacing: 0) {
                // 把手
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // 标题栏
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("激活 3D 破框卡片")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(pet.name)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 引导提示卡
                        proTipBanner

                        // 粘贴按钮
                        pasteButton

                        // 当前状态行
                        if pet.cardStyleRaw == "popout" {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.goLime)
                                Text("当前已激活破框风格")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.7))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color.goLime.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.goLime.opacity(0.25), lineWidth: 1))
                        }

                        // 重置回默认按钮
                        if pet.cardStyleRaw == "popout" {
                            Button {
                                pet.cardStyleRaw = "classic"
                                modelContext.safeSave()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                dismiss()
                            } label: {
                                Text("恢复默认风格")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.primary.opacity(0.35))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }

            // 错误 Toast
            if showErrorToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.goOrange)
                        Text("剪贴板没有图片，请先在相册长按宠物并拷贝")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.goDarkBlue, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.goOrange.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }

            // 成功 Toast
            if showSuccessToast {
                VStack {
                    HStack(spacing: 10) {
                        Text("✨").font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("换装成功！")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            Text("3D 破框悬浮卡片已激活")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.black.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.goLime, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color.goLime.opacity(0.4), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pasteBreathing = true
            }
        }
    }

    // MARK: - 引导提示 Banner
    private var proTipBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goLime.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.goLime)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("✨ 3D 破框悬浮效果")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 4) {
                    guideStep("1", "打开系统相册，找到宠物照片")
                    guideStep("2", "长按宠物主体，点击「拷贝」（iOS 自动抠图）")
                    guideStep("3", "返回此页面，点击下方「粘贴并激活」")
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.goLime.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.goLime.opacity(0.25), lineWidth: 1))
        )
    }

    // MARK: - 粘贴按钮
    private var pasteButton: some View {
        Button {
            pasteAndActivate()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        hasPasteboardImage
                            ? LinearGradient(colors: [Color.goLime, Color(hex: "A8E44A")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(
                        color: hasPasteboardImage ? Color.goLime.opacity(pasteBreathing ? 0.55 : 0.15) : .clear,
                        radius: pasteBreathing ? 18 : 6, x: 0, y: 4
                    )

                if isPasting {
                    HStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(hasPasteboardImage ? .black : .white)
                            .scaleEffect(0.85)
                        Text("正在处理…")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                } else {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hasPasteboardImage ? Color.black.opacity(0.12) : Color.white.opacity(0.08))
                                .frame(width: 44, height: 44)
                            Image(systemName: hasPasteboardImage ? "doc.on.clipboard.fill" : "doc.on.clipboard")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.35))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasPasteboardImage ? "粘贴抠图并生成卡片" : "从剪贴板粘贴抠图")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(hasPasteboardImage ? .black : .white.opacity(0.4))
                            Text(hasPasteboardImage ? "检测到剪贴板有图 · 点击激活破框风格" : "先在相册长按宠物主体并拷贝")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(hasPasteboardImage ? .black.opacity(0.5) : .white.opacity(0.22))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(hasPasteboardImage ? .black.opacity(0.45) : .white.opacity(0.1))
                            .scaleEffect(pasteBreathing && hasPasteboardImage ? 1.12 : 1.0)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPasting)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(hasPasteboardImage ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: hasPasteboardImage)
    }

    // MARK: - 引导步骤行
    private func guideStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(Color.goLime, in: Circle())
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.65))
            Spacer()
        }
    }

    // MARK: - 粘贴并激活
    private func pasteAndActivate() {
        guard let img = UIPasteboard.general.image else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.spring(response: 0.3)) { showErrorToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showErrorToast = false }
            }
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isPasting = true

        Task.detached(priority: .userInitiated) {
            let processed = (try? await ImageCutoutService.shared.removeBackground(from: img)) ?? img
            let maxDim: CGFloat = 1024
            let downsampled = AddPetWizardView.downsample(processed, maxDim: maxDim)
            let pngData = downsampled.pngData() ?? downsampled.jpegData(compressionQuality: 0.85)

            await MainActor.run {
                if let data = pngData {
                    pet.avatarImageData = data
                }
                pet.cardStyleRaw = "popout"
                modelContext.safeSave()
                isPasting = false
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.4)) { showSuccessToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation { showSuccessToast = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
                }
            }
        }
    }
}

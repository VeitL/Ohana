//
//  ImageCutoutPreviewSheet.swift
//  Ohana
//
//  裁剪后展示原图 vs 抠图对比，用户手动选择保存方式
//

import SwiftUI

struct ImageCutoutPreviewSheet: View {
    let image: UIImage
    /// finalData: 最终选择的图片 Data，usedCutout: 是否使用了抠图
    let onConfirm: (Data, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cutoutImage: UIImage? = nil
    @State private var isProcessing = true
    @State private var cutoutFailed = false
    @State private var selectedSide: SelectedSide = .none

    enum SelectedSide { case none, original, cutout }

    // 裁剪原图 JPEG
    private var originalData: Data? { image.jpegData(compressionQuality: 0.85) }

    var body: some View {
        ZStack {
            Color.goDarkBlue.ignoresSafeArea()
            LinearGradient(
                colors: [Color.goPrimary.opacity(0.2), Color.goDarkBlue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("选择头像样式")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("点击任意一张完成选择")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.45))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.primary.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                // ── 两张卡片对比
                HStack(spacing: 16) {
                    // 原图
                    imageOptionCard(
                        image: image,
                        label: "保留背景",
                        sublabel: "原始照片",
                        icon: "photo",
                        isSelected: selectedSide == .original,
                        isLoading: false
                    )
                    .onTapGesture { confirmOriginal() }

                    // 抠图
                    if isProcessing {
                        processingCard()
                    } else if let cutout = cutoutImage {
                        imageOptionCard(
                            image: cutout,
                            label: "去除背景",
                            sublabel: "贴纸描边效果",
                            icon: "sparkles",
                            isSelected: selectedSide == .cutout,
                            isLoading: false
                        )
                        .onTapGesture { confirmCutout(cutout) }
                    } else {
                        // 抠图失败
                        failedCard()
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // ── 底部提示
                if !isProcessing && cutoutImage == nil {
                    Label("无法识别主体，仅提供原图", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                        .padding(.bottom, 8)
                }

                // ── 说明文字
                Text("选择「去除背景」后，卡片正面将显示带白色描边的贴纸效果。")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
        .task { await runCutout() }
    }

    // MARK: - Sub views

    @ViewBuilder
    private func imageOptionCard(
        image: UIImage,
        label: String,
        sublabel: String,
        icon: String,
        isSelected: Bool,
        isLoading: Bool
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                // 棋盘格背景（透明区域可见）
                CheckerboardPattern()
                    .opacity(0.15)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(8)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                isSelected ? Color.goPrimary.opacity(0.15) : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.goPrimary : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )

            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.goPrimary : .white.opacity(0.6))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.goPrimary : .white)
            }
            Text(sublabel)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.4))
        }
    }

    @ViewBuilder
    private func processingCard() -> some View {
        VStack(spacing: 10) {
            ZStack {
                CheckerboardPattern()
                    .opacity(0.1)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(Color.goPrimary)
                        .scaleEffect(1.2)
                    Text("AI 智能抠图中…")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )

            Text("去除背景")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.5))
            Text("处理中…")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.3))
        }
    }

    @ViewBuilder
    private func failedCard() -> some View {
        VStack(spacing: 10) {
            ZStack {
                Color.white.opacity(0.04)
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.primary.opacity(0.3))
                    Text("无法抠图")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )

            Text("去除背景")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.3))
            Text("识别失败")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.25))
        }
    }

    // MARK: - Actions

    private func runCutout() async {
        isProcessing = true
        cutoutFailed = false
        if let result = try? await ImageCutoutService.shared.removeBackground(from: image) {
            cutoutImage = result
        } else {
            cutoutFailed = true
        }
        isProcessing = false
    }

    private func confirmOriginal() {
        guard let data = originalData else { return }
        selectedSide = .original
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onConfirm(data, false)
        }
    }

    private func confirmCutout(_ img: UIImage) {
        guard let data = img.pngData() else { confirmOriginal(); return }
        selectedSide = .cutout
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onConfirm(data, true)
        }
    }
}

// MARK: - Checkerboard pattern（透明区域可视化）
private struct CheckerboardPattern: View {
    var tileSize: CGFloat = 8
    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / tileSize) + 1
            let rows = Int(size.height / tileSize) + 1
            for row in 0..<rows {
                for col in 0..<cols {
                    if (row + col) % 2 == 0 {
                        let rect = CGRect(
                            x: CGFloat(col) * tileSize,
                            y: CGFloat(row) * tileSize,
                            width: tileSize,
                            height: tileSize
                        )
                        context.fill(Path(rect), with: .color(.white.opacity(0.4)))
                    }
                }
            }
        }
    }
}

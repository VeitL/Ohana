//
//  ExecutorPickerBar.swift
//  Ohana
//
//  家庭协作共享组件：所有打卡 / 记录 Sheet 顶部的「执行人」胶囊
//
//  - 读取 / 持久化 @AppStorage("currentActiveHumanId")
//  - 胶囊点击 → 统一账户切换 Sheet
//  - 切换后立刻生效于该 Sheet 后续 commit
//

import SwiftUI

struct ExecutorPickerBar: View {
    let humans: [Human]
    var tint: Color = .goPrimary
    var compact: Bool = false

    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @ObservedObject private var avatarPipeline = AvatarPipelineRegistry.current
    @State private var showingExecutorSwitcher = false
    @State private var avatarSignature = ""
    @State private var avatarCacheKey = "executor-picker-avatar-empty"

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
    }

    init(
        humans: [Human] = [],
        tint: Color = .goPrimary,
        compact: Bool = false
    ) {
        self.humans = humans
        self.tint = tint
        self.compact = compact
    }

    var body: some View {
        if humans.isEmpty {
            EmptyView()
        } else {
            Button {
                showingExecutorSwitcher = true
            } label: {
                barLabel
            }
            .buttonStyle(ScaleButtonStyle())
            .sheet(isPresented: $showingExecutorSwitcher) {
                HumanExecutorSwitchSheet(humans: humans)
            }
            .task(id: avatarSourceKey) {
                await prepareAvatar()
            }
            .onDisappear {
                avatarPipeline.cancel(key: avatarCacheKey)
            }
        }
    }

    // MARK: - Label

    private var barLabel: some View {
        HStack(spacing: 8) {
            avatarCircle

            VStack(alignment: .leading, spacing: 0) {
                Text("执行人")
                    .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .tracking(0.6)
                Text(currentHuman.map(displayName) ?? "选择账户")
                    .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.up.chevron.down") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 9, weight: .bold)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, compact ? 5 : 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.ohanaCardSurface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var avatarCircle: some View {
        let size: CGFloat = compact ? 22 : 26
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: size, height: size)
            if let human = currentHuman {
                if let img = preparedAvatarImage(for: human) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    Text(human.avatarEmoji)
                        .font(.system(size: compact ? 12 : 14))
                }
            } else {
                Image(systemName: "person.fill.questionmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func displayName(_ h: Human) -> String {
        h.name.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名成员" : h.name
    }

    private var avatarSourceKey: String {
        guard let human = currentHuman else { return "executor-picker-avatar-empty" }
        return "\(human.id.uuidString):\(human.avatarImageData?.count ?? 0)"
    }

    private func preparedAvatarImage(for human: Human) -> UIImage? {
        guard !avatarSignature.isEmpty else { return nil }
        return avatarPipeline.cachedImage(for: human.id, signature: avatarSignature)
    }

    @MainActor
    private func prepareAvatar() async {
        await OhanaFrameScheduler.waitAfterNextFrame(milliseconds: 24)
        guard !Task.isCancelled else { return }
        guard let human = currentHuman, let data = human.avatarImageData else {
            avatarPipeline.cancel(key: avatarCacheKey)
            avatarSignature = ""
            avatarCacheKey = "executor-picker-avatar-empty"
            return
        }

        let signature = FocusWalletAvatarCache.signature(for: data)
        let nextKey = "executor-picker-avatar-\(human.id.uuidString)-\(signature)"
        if avatarCacheKey != nextKey {
            avatarPipeline.cancel(key: avatarCacheKey)
            avatarCacheKey = nextKey
        }
        avatarSignature = signature
        let payload = FocusWalletAvatarCache.Payload(id: human.id, data: data)
        avatarPipeline.seedPreviewEntries([payload])
        avatarPipeline.preload(
            payloads: [payload],
            key: nextKey,
            delayMilliseconds: 48
        )
    }
}

#Preview {
    ExecutorPickerBar()
        .padding()
        .background(Color.gray.opacity(0.1))
}

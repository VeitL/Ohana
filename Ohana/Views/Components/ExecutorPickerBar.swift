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
import SwiftData

struct ExecutorPickerBar: View {
    @Query(sort: \Human.createdAt) private var humans: [Human]
    @AppStorage("currentActiveHumanId") private var activeHumanId: String = ""
    @State private var showingExecutorSwitcher = false

    var tint: Color = .goPrimary
    var compact: Bool = false

    private var currentHuman: Human? {
        humans.first { $0.id.uuidString == activeHumanId }
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
                HumanExecutorSwitchSheet()
            }
        }
    }

    // MARK: - Label

    private var barLabel: some View {
        HStack(spacing: 8) {
            avatarCircle

            VStack(alignment: .leading, spacing: 0) {
                Text("执行人")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .tracking(0.6)
                Text(currentHuman.map(displayName) ?? "选择账户")
                    .font(.system(size: compact ? 11 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9, weight: .bold))
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
                if let data = human.avatarImageData, let img = UIImage(data: data) {
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
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: compact ? 10 : 12, weight: .semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
        }
    }

    private func displayName(_ h: Human) -> String {
        h.name.trimmingCharacters(in: .whitespaces).isEmpty ? "未命名成员" : h.name
    }
}

#Preview {
    ExecutorPickerBar()
        .padding()
        .background(Color.gray.opacity(0.1))
}

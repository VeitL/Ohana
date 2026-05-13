//
//  HumanPrivacyToggleButton.swift
//  Ohana
//
//  各人类记录详情页共用的「公开 / 仅本人」隐私开关按钮
//  放置在 NavigationStack toolbar leading 位置
//

import SwiftUI
import SwiftData

/// 单字段隐私开关胶囊按钮
/// - 仅当 activeHumanId == human.id 时允许切换（即本人查看时）
/// - 其他家庭成员查看时按钮半透明且不可交互
struct HumanPrivacyToggleButton: View {
    let human: Human
    let field: HumanPrivateField

    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var isFieldPrivate: Bool {
        human.privateFields.contains(field.rawValue)
    }
    private var isOwner: Bool {
        UUID(uuidString: activeHumanIdStr) == human.id
    }

    var body: some View {
        Button {
            guard isOwner else { return }
            human.setPrivate(field, !isFieldPrivate)
            modelContext.safeSave()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            ZStack {
                Color.clear
                    .frame(width: 58, height: 30)

                Circle()
                    .fill(isFieldPrivate ? Color.goYellow : Color.primary.opacity(0.14))
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)
                    .overlay {
                        Image(systemName: isFieldPrivate ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(isFieldPrivate ? Color.arkInk : Color.primary.opacity(0.82))
                    }
                    .offset(x: isFieldPrivate ? 14 : -14)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFieldPrivate)
            .accessibilityLabel(isFieldPrivate ? "隐私已开启，仅本人可见" : "隐私已关闭，家庭成员可见")
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isOwner ? 1 : 0.5)
        .disabled(!isOwner)
    }
}

/// Owner-facing note shown on pages where private human data is still visible to its owner.
struct HumanPrivateDataNotice: View {
    let human: Human
    let field: HumanPrivateField

    @AppStorage("currentActiveHumanId") private var activeHumanIdStr = ""

    private var isOwner: Bool {
        UUID(uuidString: activeHumanIdStr) == human.id
    }

    private var isFieldPrivate: Bool {
        human.privateFields.contains(field.rawValue)
    }

    var body: some View {
        if isOwner && isFieldPrivate {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 28, height: 28)
                    .background(Color.goYellow.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("只有你能看到")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("\(field.title)数据已设为隐私，其他家庭成员不会看到这些内容。")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.goYellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.goYellow.opacity(0.18), lineWidth: 1)
            )
        }
    }
}

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
    @State private var optimisticIsPrivate: Bool?
    @StateObject private var commandQueue = DeferredDomainCommandQueue()

    private var isFieldPrivate: Bool {
        human.privateFields.contains(field.rawValue)
    }
    private var displayIsPrivate: Bool {
        optimisticIsPrivate ?? isFieldPrivate
    }
    private var isOwner: Bool {
        UUID(uuidString: activeHumanIdStr) == human.id
    }

    var body: some View {
        Button {
            guard isOwner else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            togglePrivacy()
        } label: {
            ZStack {
                Capsule()
                    .fill(trackFill)
                    .frame(width: 68, height: 34)
                    .overlay {
                        Capsule()
                            .strokeBorder(trackStroke, lineWidth: 1.25)
                    }

                Circle()
                    .fill(knobFill)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.ohanaCardStroke.opacity(displayIsPrivate ? 0.25 : 0.9), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: displayIsPrivate ? "lock.fill" : "lock.open.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(knobIconColor)
                    }
                    .offset(x: displayIsPrivate ? 17 : -17)
            }
            .frame(width: 74, height: 44)
            .contentShape(Rectangle())
            .animation(GoMotion.feedback, value: displayIsPrivate)
            .accessibilityLabel(displayIsPrivate ? "隐私已开启，仅本人可见" : "隐私已关闭，家庭成员可见")
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isOwner ? 1 : 0.5)
        .disabled(!isOwner)
        .onDisappear {
            commandQueue.cancelAll()
            optimisticIsPrivate = nil
        }
    }

    private func togglePrivacy() {
        let nextValue = !displayIsPrivate
        optimisticIsPrivate = nextValue
        let action = "field.\(field.rawValue).\(nextValue ? "private" : "public")"
        let command = DomainCommand.humanPrivacy(humanID: human.id, action: action)
        commandQueue.enqueue(command) {
            HumanPrivacyCommandExecutor(context: modelContext).setPrivateField(
                field,
                isPrivate: nextValue,
                for: human,
                note: "human.privacy.field"
            )
            optimisticIsPrivate = nil
        }
    }

    private var trackFill: Color {
        displayIsPrivate
            ? Color.goYellow.opacity(0.16)
            : Color.ohanaControlFill
    }

    private var trackStroke: Color {
        displayIsPrivate
            ? Color.goYellow.opacity(0.55)
            : Color.ohanaCardStroke.opacity(0.95)
    }

    private var knobFill: Color {
        displayIsPrivate ? Color.goYellow : Color.ohanaCardSurfaceElevated
    }

    private var knobIconColor: Color {
        displayIsPrivate ? Color.arkInk : Color.ohanaSecondaryText
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

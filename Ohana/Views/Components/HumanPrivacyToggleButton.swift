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
            Image(systemName: isFieldPrivate ? "lock.fill" : "lock.open.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 14, weight: .black))
                .frame(width: 28, height: 28)
            .foregroundStyle(isFieldPrivate ? Color.goYellow : Color.secondary)
            .background(
                isFieldPrivate
                    ? Color.goYellow.opacity(0.14)
                    : Color.primary.opacity(0.07),
                in: Circle()
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isOwner ? 1 : 0.5)
    }
}

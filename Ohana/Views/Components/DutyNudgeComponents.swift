//
//  DutyNudgeComponents.swift
//  Ohana
//
//  模块4：排班提醒与「拍一拍」催办组件

import SwiftUI
import SwiftData

// MARK: - Assignee Avatar Chip（显示在待办旁边）
struct AssigneeChip: View {
    let assigneeId: String
    let allHumans: [Human]

    private var human: Human? {
        allHumans.first { $0.id.uuidString == assigneeId }
    }

    var body: some View {
        if let h = human {
            HStack(spacing: 4) {
                if let data = h.avatarImageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 18, height: 18).clipShape(Circle())
                } else {
                    Text(h.avatarEmoji).font(.system(size: 13))
                        .frame(width: 18, height: 18)
                        .background(Color(hex: h.themeColor).opacity(0.25), in: Circle())
                }
                Text(h.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(hex: h.themeColor).opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: h.themeColor).opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - Nudge Button（催办按钮）
struct NudgeButton: View {
    let targetHuman: Human
    @State private var showAlert = false
    @State private var nudged = false

    var body: some View {
        Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            nudged = true
            showAlert = true
        } label: {
            HStack(spacing: 4) {
                Text(nudged ? "✅" : "👋")
                    .font(.system(size: 12))
                Text(nudged ? "已催" : "催办")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(nudged ? Color.goLime : .white.opacity(0.6))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                nudged ? Color.goLime.opacity(0.12) : Color.white.opacity(0.08),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    nudged ? Color.goLime.opacity(0.35) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .alert("已提醒 \(targetHuman.name)！", isPresented: $showAlert) {
            Button("好的", role: .cancel) {}
        } message: {
            Text("已通知 \(targetHuman.name) 快去完成任务！🐾")
        }
    }
}

// MARK: - Assignee Picker Row（在 Event 编辑时使用）
struct AssigneePickerRow: View {
    @Binding var assigneeId: String?
    let allHumans: [Human]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("指派给")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 无指派选项
                    Button {
                        assigneeId = nil
                    } label: {
                        Text("任何人")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(assigneeId == nil ? .black : Color(.label))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                assigneeId == nil ? Color.goLime : Color(.systemGray5),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(allHumans) { human in
                        Button {
                            assigneeId = human.id.uuidString
                        } label: {
                            HStack(spacing: 6) {
                                Text(human.avatarEmoji).font(.system(size: 14))
                                Text(human.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(assigneeId == human.id.uuidString ? .black : Color(.label))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(
                                assigneeId == human.id.uuidString ? Color.goLime : Color(.systemGray5),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

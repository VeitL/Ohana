//
//  HumanPrivacyTestView.swift
//  Ohana
//
//  Debug privacy visibility matrix.
//

import SwiftData
import SwiftUI

struct HumanPrivacyTestView: View {
    let humans: [Human]
    @Environment(AppServices.self) private var appServices
    @AppStorage("currentActiveHumanId") private var activeHumanId = ""

    @State private var viewerId = ""
    @State private var targetId = ""

    private var viewer: Human? {
        humans.first { $0.id.uuidString == viewerId }
    }

    private var target: Human? {
        humans.first { $0.id.uuidString == targetId }
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    pickerSection
                    matrixSection
                }
                .padding(16)
            }
        }
        .navigationTitle("隐私测试")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: ensureSelection)
        .onChange(of: humans.map(\.id)) { _, _ in ensureSelection() }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goYellow.opacity(0.14), in: RoundedRectangle(cornerRadius: OhanaRadius.chip, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("人类隐私检查")
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text("只显示可见/锁定结果，不展示任何私密内容")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    private var pickerSection: some View {
        VStack(spacing: 12) {
            pickerRow(title: "查看者", selection: $viewerId)
            pickerRow(title: "目标成员", selection: $targetId)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    @ViewBuilder
    private var matrixSection: some View {
        if let target {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("字段矩阵")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(viewer?.id == target.id ? "本人视角" : "他人视角")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.goPrimary, in: Capsule())
                }

                visibleRow(title: "基础身份", subtitle: "名字、头像、角色、性别入口", isLocked: false)
                ForEach(HumanPrivateField.allCases) { field in
                    visibleRow(
                        title: field.title,
                        subtitle: target.privateFields.contains(field.rawValue) ? "目标成员设为仅本人" : "目标成员设为公开",
                        isLocked: appServices.privacy.isLocked(field, for: target, viewedBy: viewer?.id)
                    )
                }
            }
            .padding(16)
            .goTranslucentCard(cornerRadius: OhanaRadius.input)
        } else {
            Text("请先创建人类成员")
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaSecondaryText)
                .frame(maxWidth: .infinity)
                .padding(20)
                .goTranslucentCard(cornerRadius: OhanaRadius.input)
        }
    }

    private func pickerRow(title: String, selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(OhanaFont.callout(.bold))
                .foregroundStyle(Color.ohanaPrimaryText)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(humans) { human in
                    Text(displayName(human)).tag(human.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.goPrimary)
        }
    }

    private func visibleRow(title: String, subtitle: String, isLocked: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isLocked ? "lock.fill" : "eye.fill")
                .font(OhanaFont.adaptive(size: 14, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(isLocked ? Color.goYellow : Color.goPrimary)
                .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background((isLocked ? Color.goYellow : Color.goPrimary).opacity(0.13), in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(subtitle)
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Text(isLocked ? "锁定" : "可见")
                .font(OhanaFont.caption2(.black))
                .foregroundStyle(isLocked ? Color.goYellow : Color.arkInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isLocked ? Color.goYellow.opacity(0.14) : Color.goPrimary, in: Capsule())
        }
        .padding(.vertical, 4)
    }

    private func ensureSelection() {
        guard !humans.isEmpty else { return }
        if viewerId.isEmpty || !humans.contains(where: { $0.id.uuidString == viewerId }) {
            viewerId = humans.first(where: { $0.id.uuidString == activeHumanId })?.id.uuidString ?? humans[0].id.uuidString
        }
        if targetId.isEmpty || !humans.contains(where: { $0.id.uuidString == targetId }) {
            targetId = humans.first(where: { $0.id.uuidString != viewerId })?.id.uuidString ?? humans[0].id.uuidString
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }
}

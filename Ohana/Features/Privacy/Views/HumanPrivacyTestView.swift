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
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    @State private var viewerId = ""
    @State private var targetId = ""

    private var l: L10n { L10n(appLanguage) }

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
        .navigationTitle(l.tr(zh: "隐私测试", en: "Privacy test", de: "Datenschutztest"))
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
                    Text(l.tr(zh: "人类隐私检查", en: "Human privacy check", de: "Menschen-Datenschutzcheck"))
                        .font(OhanaFont.title3(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(l.tr(
                        zh: "只显示可见/锁定结果，不展示任何私密内容",
                        en: "Shows only visible/locked results, never private content.",
                        de: "Zeigt nur sichtbar/gesperrt an, nie private Inhalte."
                    ))
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
            pickerRow(title: l.tr(zh: "查看者", en: "Viewer", de: "Betrachter"), selection: $viewerId)
            pickerRow(title: l.tr(zh: "目标成员", en: "Target member", de: "Zielmitglied"), selection: $targetId)
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: OhanaRadius.input)
    }

    @ViewBuilder
    private var matrixSection: some View {
        if let target {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(l.tr(zh: "字段矩阵", en: "Field matrix", de: "Feldmatrix"))
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Spacer()
                    Text(viewer?.id == target.id ? l.tr(zh: "本人视角", en: "Own view", de: "Eigene Ansicht") : l.tr(zh: "他人视角", en: "Other viewer", de: "Andere Ansicht"))
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.goPrimary, in: Capsule())
                }

                visibleRow(
                    title: l.tr(zh: "基础身份", en: "Basic identity", de: "Basisidentitaet"),
                    subtitle: l.tr(zh: "名字、头像、角色、性别入口", en: "Name, avatar, role, and gender entry", de: "Name, Avatar, Rolle und Geschlecht"),
                    isLocked: false
                )
                ForEach(HumanPrivateField.allCases) { field in
                    visibleRow(
                        title: localizedPrivateFieldTitle(field),
                        subtitle: target.privateFields.contains(field.rawValue)
                            ? l.tr(zh: "目标成员设为仅本人", en: "Target member set this to private", de: "Zielmitglied hat dies privat gesetzt")
                            : l.tr(zh: "目标成员设为公开", en: "Target member set this to public", de: "Zielmitglied hat dies oeffentlich gesetzt"),
                        isLocked: appServices.privacy.isLocked(field, for: target, viewedBy: viewer?.id)
                    )
                }
            }
            .padding(16)
            .goTranslucentCard(cornerRadius: OhanaRadius.input)
        } else {
            Text(l.tr(zh: "请先创建人类成员", en: "Create a human member first", de: "Erstelle zuerst ein Menschenmitglied"))
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
            Text(isLocked ? l.tr(zh: "锁定", en: "Locked", de: "Gesperrt") : l.tr(zh: "可见", en: "Visible", de: "Sichtbar"))
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
        return name.isEmpty ? l.tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenanntes Mitglied") : name
    }

    private func localizedPrivateFieldTitle(_ field: HumanPrivateField) -> String {
        switch field {
        case .weight:
            l.tr(zh: "体重", en: "Weight", de: "Gewicht")
        case .workout:
            l.tr(zh: "运动", en: "Workouts", de: "Training")
        case .medication:
            l.tr(zh: "吃药提醒", en: "Medication", de: "Medikamente")
        case .wishlist:
            l.tr(zh: "椰子资产与心愿", en: "Coconut Assets & Wishes", de: "Kokosnussvermoegen & Wuensche")
        case .expense:
            l.tr(zh: "花费", en: "Expenses", de: "Ausgaben")
        case .note:
            l.tr(zh: "备注", en: "Notes", de: "Notizen")
        }
    }
}

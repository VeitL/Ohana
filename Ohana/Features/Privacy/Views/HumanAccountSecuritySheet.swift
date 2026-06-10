//
//  HumanAccountSecuritySheet.swift
//  Ohana
//
//  Human account security and privacy sheet.
//

import SwiftData
import SwiftUI

struct HumanAccountSecuritySheet: View {
    let human: Human

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var appServices
    @State private var showingPasscodeSheet = false

    private var hasPasscode: Bool {
        appServices.passcodes.hasPasscode(human)
    }

    private var privateCount: Int {
        HumanPrivateField.allCases.filter { human.privateFields.contains($0.rawValue) }.count
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    passcodeCard
                    privacyCard
                }
                .padding(20)
                .padding(.bottom, 10)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showingPasscodeSheet) {
            HumanPasscodeManagementSheet(human: human)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            accountAvatar(size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("密码与隐私")
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(displayName(human))
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    private var passcodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: hasPasscode ? "lock.shield.fill" : "lock.open.fill")
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(hasPasscode ? Color.goYellow : Color.goPrimary)
                    .frame(width: 40, height: 40) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background((hasPasscode ? Color.goYellow : Color.goPrimary).opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("账户密码")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(hasPasscode ? "切换到此账户时需要 4 位密码" : "当前为公开切换，可直接进入")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Text(hasPasscode ? "隐私" : "公开")
                    .font(OhanaFont.caption2(.black))
                    .foregroundStyle(hasPasscode ? Color.goYellow : Color.arkInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(hasPasscode ? Color.goYellow.opacity(0.14) : Color.goPrimary, in: Capsule())
            }

            Button {
                showingPasscodeSheet = true
            } label: {
                Label(hasPasscode ? "修改或关闭密码" : "设置 4 位密码", systemImage: "key.fill")
                    .font(OhanaFont.callout(.black))
                    .foregroundStyle(Color.arkInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("资料可见性")
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(privateCount == 0 ? "所有敏感资料对家庭成员公开" : "\(privateCount) 项设为仅本人可见")
                        .font(OhanaFont.caption(.semibold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
                Button {
                    setAllPrivate(false)
                } label: {
                    Text("全公开")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goPrimary.opacity(0.12), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                Button {
                    setAllPrivate(true)
                } label: {
                    Text("全隐私")
                        .font(OhanaFont.caption2(.black))
                        .foregroundStyle(Color.goYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.goYellow.opacity(0.14), in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }

            ForEach(HumanPrivateField.allCases) { field in
                privacyToggleRow(field)
            }
        }
        .padding(16)
        .goTranslucentCard(cornerRadius: 20)
    }

    private func privacyToggleRow(_ field: HumanPrivateField) -> some View {
        Toggle(isOn: Binding(
            get: { human.privateFields.contains(field.rawValue) },
            set: { isPrivate in
                HumanPrivacyCommandExecutor(context: modelContext, services: appServices).setPrivateField(
                    field,
                    isPrivate: isPrivate,
                    for: human,
                    note: "human.privacy.field"
                )
                UISelectionFeedbackGenerator().selectionChanged()
            }
        )) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: field))
                    .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.goYellow)
                    .frame(width: 30, height: 30) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goYellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.title)
                        .font(OhanaFont.callout(.black))
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(human.privateFields.contains(field.rawValue) ? "仅本人可见" : "家庭成员可见")
                        .font(OhanaFont.caption2(.bold))
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
            }
        }
        .tint(Color.goYellow)
        .padding(.vertical, 4)
    }

    private func setAllPrivate(_ isPrivate: Bool) {
        HumanPrivacyCommandExecutor(context: modelContext, services: appServices).setAllPrivateFields(
            isPrivate: isPrivate,
            for: human,
            note: isPrivate ? "human.privacy.allPrivate" : "human.privacy.allPublic"
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @ViewBuilder
    private func accountAvatar(size: CGFloat) -> some View {
        HumanAvatarPipelineView(
            human: human,
            size: size,
            fallbackScale: 0.45,
            backgroundOpacity: 0.18
        )
    }

    private func icon(for field: HumanPrivateField) -> String {
        switch field {
        case .weight: return "scalemass.fill"
        case .workout: return "figure.run"
        case .medication: return "pills.fill"
        case .wishlist: return "gift.fill"
        case .expense: return "creditcard.fill"
        case .note: return "note.text"
        }
    }

    private func displayName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "未命名成员" : name
    }

}

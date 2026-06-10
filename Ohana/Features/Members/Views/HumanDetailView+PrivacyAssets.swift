//
//  HumanDetailView+PrivacyAssets.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension HumanDetailView {
    var showOnHomeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.goPrimary.opacity(0.2)).frame(width: 48, height: 48)
                Image(systemName: "rectangle.stack.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.title3(.bold))
                    .foregroundStyle(Color.goPrimary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("在首页显示")
                    .font(OhanaFont.callout(.bold))
                    .foregroundStyle(Color(hex: "1E3A8A"))
                Text(displayedHomeVisibility ? "已加入首页卡堆与岛屿统计" : "不在首页卡堆与岛屿体重中显示")
                    .font(OhanaFont.caption())
                    .foregroundStyle(Color(hex: "6B82C4"))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { displayedHomeVisibility },
                set: { visible in
                    if visible, !HomeCardVisibility.canShowHuman(human, pets: allPets, humans: allHumans, raw: hiddenHomePetIDsRaw) {
                        showingHomeStackFullAlert = true
                        return
                    }
                    homeVisibilityOverride = visible
                    commandQueue.enqueue(.memberHomeVisibility(
                        entityID: human.id,
                        kind: EntityKind.human.rawValue,
                        visible: visible
                    )) {
                        MemberCommandExecutor(context: modelContext, services: appServices).setHumanHomeVisibility(
                            human,
                            visible: visible,
                            note: "human.detail.homeVisibility"
                        )
                        homeVisibilityOverride = nil
                    }
                }
            ))
            .tint(Color.goPrimary)
            .labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        .padding(.horizontal, 16)
    }

    var displayedHomeVisibility: Bool {
        homeVisibilityOverride ?? human.shouldShowOnHome
    }

    // MARK: - Asset Card
    var humanAssetCard: some View {
        Button { showingWishlist = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goYellow.opacity(0.18)).frame(width: 48, height: 48)
                    Text("🥥").font(OhanaFont.title2())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("椰子资产")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    HStack(spacing: 4) {
                        Text("\(human.coconutBalance) 个")
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.goYellow)
                        Text("· 兑换心愿")
                            .font(OhanaFont.caption())
                            .foregroundStyle(Color(hex: "6B82C4"))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Expense Card
    var humanExpenseCard: some View {
        Button { showingExpenses = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goCardCyan.opacity(0.18)).frame(width: 48, height: 48)
                    Image(systemName: "yensign") // a11y: allow decorative icon covered by surrounding text or control
                        .font(OhanaFont.title3(.bold))
                        .foregroundStyle(Color.goCardCyan)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("账单花费")
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    Text("查看经手支出明细")
                        .font(OhanaFont.caption())
                        .foregroundStyle(Color(hex: "6B82C4"))
                }
                Spacer()
                Image(systemName: "chevron.right") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.caption(.semibold))
                    .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 16)
    }

    // MARK: - Co-Health Card
    var coHealthCard: some View {
        Button { showingCoHealth = true } label: {
            CoHealthDashboardView(human: human)
                .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
                .padding(.horizontal, 16)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Privacy Placeholder
    func privacyPlaceholderCard(label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.headline())
                .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            Text("🔒 \(label) · 仅本人可见")
                .font(OhanaFont.callout(.semibold))
                .foregroundStyle(Color(hex: "6B82C4"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 14)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        .padding(.horizontal, 16)
    }

    var fullPrivacyPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.metric(size: 34))
                .foregroundStyle(Color.goYellow)
            Text("此成员资料仅本人可见")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color(hex: "1E3A8A"))
            Text("当前家庭成员无法查看 TA 的体重、运动、吃药、备注、花费和椰子资产等相关数据。")
                .font(OhanaFont.callout(.medium))
                .foregroundStyle(Color(hex: "6B82C4"))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .goIslandModuleCard(cornerRadius: OhanaRadius.cardLarge)
        .padding(.horizontal, 16)
    }

    // MARK: - Reminders Section
}

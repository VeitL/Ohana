//
//  HumanDetailView+PrivacyAssets.swift
//  Ohana
//

import SwiftUI

extension HumanDetailView {
    // MARK: - Asset Card
    var humanAssetCard: some View {
        Button { showingWishlist = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.goYellow.opacity(0.18)).frame(width: 48, height: 48)
                    Text("🥥").font(OhanaFont.title2())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.tr(zh: "椰子资产", en: "Coconut Assets", de: "Kokosnussvermögen"))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    HStack(spacing: 4) {
                        Text(l.tr(zh: "\(human.coconutBalance) 个", en: "\(human.coconutBalance) coconuts", de: "\(human.coconutBalance) Kokosnüsse"))
                            .font(OhanaFont.caption(.semibold))
                            .foregroundStyle(Color.goYellow)
                        Text(l.tr(zh: "· 兑换心愿", en: "· Redeem wishes", de: "· Wünsche einlösen"))
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
        .accessibilityIdentifier("human-detail-wishlist-action")
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
                    Text(l.tr(zh: "账单花费", en: "Bill Expenses", de: "Rechnungsausgaben"))
                        .font(OhanaFont.callout(.bold))
                        .foregroundStyle(Color(hex: "1E3A8A"))
                    Text(l.tr(zh: "查看经手支出明细", en: "Review handled expense details", de: "Bearbeitete Ausgaben ansehen"))
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
        .accessibilityIdentifier("human-detail-expense-action")
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
        .accessibilityIdentifier("human-detail-co-health-action")
    }

    // MARK: - Privacy Placeholder
    func privacyPlaceholderCard(label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.headline())
                .foregroundStyle(Color(hex: "6B82C4").opacity(0.6))
            Text(l.tr(
                zh: "🔒 \(label) · 仅本人可见",
                en: "🔒 \(label) · Private to owner",
                de: "🔒 \(label) · Nur selbst sichtbar"
            ))
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
            Text(l.tr(zh: "此成员资料仅本人可见", en: "This member profile is private", de: "Dieses Mitgliederprofil ist privat"))
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color(hex: "1E3A8A"))
            Text(l.tr(
                zh: "当前家庭成员无法查看 TA 的体重、运动、吃药、备注、花费和椰子资产等相关数据。",
                en: "Current family members cannot view their weight, workouts, medication, notes, expenses, coconut assets, or related data.",
                de: "Aktuelle Familienmitglieder können Gewicht, Training, Medikamente, Notizen, Ausgaben, Kokosnussvermögen und verwandte Daten nicht sehen."
            ))
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
        .accessibilityIdentifier("human-detail-private-profile-lock")
    }

    // MARK: - Reminders Section
}

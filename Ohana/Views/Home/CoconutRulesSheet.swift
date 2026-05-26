//
//  CoconutRulesSheet.swift
//  Ohana
//
//  Localized reference sheet for Oasis coconut earning and spending rules.
//

import SwiftUI

struct CoconutRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @State private var appeared = false

    private var l: L10n { L10n(appLanguage) }

    private struct RuleCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let desc: String
        let glowColor: Color
        let reward: String
    }

    private var earnCards: [RuleCard] {
        [
            RuleCard(
                icon: "figure.walk",
                title: l.tr(zh: "遛狗", en: "Dog walk", de: "Gassi"),
                desc: l.tr(zh: "带毛孩子出门溜达", en: "Take a pet outside", de: "Mit Haustier rausgehen"),
                glowColor: Color(hex: "14B8A6"),
                reward: l.tr(zh: "每 100m 得 1🥥", en: "1🥥 per 100m", de: "1🥥 je 100 m")
            ),
            RuleCard(
                icon: "fork.knife",
                title: l.tr(zh: "喂食·喂水", en: "Feed & water", de: "Futter & Wasser"),
                desc: l.tr(zh: "按时照护，爱意满满", en: "Care on time", de: "Pünktlich versorgen"),
                glowColor: Color(hex: "FF8C42"),
                reward: l.tr(zh: "每次 2-3🥥", en: "2-3🥥 each", de: "2-3🥥 je Aktion")
            ),
            RuleCard(
                icon: "trash.fill",
                title: l.tr(zh: "清洁", en: "Cleanup", de: "Reinigung"),
                desc: l.tr(zh: "记录如厕和清洁", en: "Log potty and cleanup", de: "Toilette und Reinigung erfassen"),
                glowColor: Color(hex: "A8E6CF"),
                reward: l.tr(zh: "每次 5-8🥥", en: "5-8🥥 each", de: "5-8🥥 je Aktion")
            ),
            RuleCard(
                icon: "scissors",
                title: l.tr(zh: "护理·梳毛", en: "Grooming", de: "Pflege"),
                desc: l.tr(zh: "精心打理日常护理", en: "Track care routines", de: "Pflegeabläufe erfassen"),
                glowColor: Color(hex: "DDA0DD"),
                reward: l.tr(zh: "5-10🥥，洗澡 15🥥", en: "5-10🥥, bath 15🥥", de: "5-10🥥, Bad 15🥥")
            ),
            RuleCard(
                icon: "cross.case.fill",
                title: l.tr(zh: "健康打卡", en: "Health log", de: "Gesundheit"),
                desc: l.tr(zh: "关注健康，守护生命", en: "Care for health", de: "Gesundheit schützen"),
                glowColor: Color(hex: "FF6B6B"),
                reward: l.tr(zh: "每次 20🥥", en: "20🥥 each", de: "20🥥 je Aktion")
            ),
            RuleCard(
                icon: "creditcard.fill",
                title: l.tr(zh: "记一笔账", en: "Expense log", de: "Ausgabe"),
                desc: l.tr(zh: "记录爱的花销", en: "Track care spending", de: "Ausgaben erfassen"),
                glowColor: Color(hex: "FFD93D"),
                reward: l.tr(zh: "每次 10🥥", en: "10🥥 each", de: "10🥥 je Aktion")
            ),
            RuleCard(
                icon: "gamecontroller.fill",
                title: l.tr(zh: "逗玩互动", en: "Play time", de: "Spielzeit"),
                desc: l.tr(zh: "记录玩耍陪伴", en: "Log play and company", de: "Spiel und Nähe erfassen"),
                glowColor: Color(hex: "6BCB77"),
                reward: l.tr(zh: "每次 10-12🥥", en: "10-12🥥 each", de: "10-12🥥 je Aktion")
            ),
            RuleCard(
                icon: "tree.fill",
                title: l.tr(zh: "每日掉落", en: "Daily drop", de: "Täglicher Drop"),
                desc: l.tr(zh: "生命之树被动收益", en: "Life Tree passive income", de: "Passives Einkommen des Baums"),
                glowColor: Color(hex: "84CC16"),
                reward: l.tr(zh: "定时领取", en: "Claim daily", de: "Täglich abholen")
            ),
            RuleCard(
                icon: "sparkles",
                title: l.tr(zh: "暴击加成", en: "Bonus chance", de: "Bonus-Chance"),
                desc: l.tr(zh: "幸运时会翻倍", en: "Lucky logs can multiply", de: "Glück kann multiplizieren"),
                glowColor: Color(hex: "FFCC00"),
                reward: l.tr(zh: "10% 双倍 · 1% 五倍", en: "10% double · 1% fivefold", de: "10% doppelt · 1% fünffach")
            )
        ]
    }

    private var spendCards: [RuleCard] {
        [
            RuleCard(
                icon: "bolt.fill",
                title: l.tr(zh: "注入生命之树", en: "Inject energy", de: "Energie geben"),
                desc: l.tr(zh: "让生命之树更旺盛", en: "Grow the Life Tree", de: "Den Lebensbaum stärken"),
                glowColor: Color(hex: "F59E0B"),
                reward: l.tr(zh: "每次 10🥥", en: "10🥥 each", de: "10🥥 je Aktion")
            ),
            RuleCard(
                icon: "bag.fill",
                title: l.tr(zh: "椰子商店", en: "Coconut shop", de: "Kokosnuss-Shop"),
                desc: l.tr(zh: "兑换特效、称号和加成", en: "Redeem effects and boosts", de: "Effekte und Boni einlösen"),
                glowColor: Color(hex: "667eea"),
                reward: l.tr(zh: "各种道具", en: "Items", de: "Objekte")
            ),
            RuleCard(
                icon: "shippingbox.fill",
                title: l.tr(zh: "盲盒", en: "Blind box", de: "Blindbox"),
                desc: l.tr(zh: "收集系列奖励", en: "Collect reward series", de: "Serienbelohnungen sammeln"),
                glowColor: Color(hex: "FF6B9D"),
                reward: l.tr(zh: "80🥥/次", en: "80🥥 each", de: "80🥥 je Öffnung")
            ),
            RuleCard(
                icon: "target",
                title: l.tr(zh: "悬赏任务", en: "Bounties", de: "Aufträge"),
                desc: l.tr(zh: "发布、接单和奖励", en: "Post, accept, reward", de: "Erstellen, annehmen, belohnen"),
                glowColor: Color(hex: "FF8C42"),
                reward: l.tr(zh: "转给完成者", en: "Paid to completer", de: "An Erlediger ausgezahlt")
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OhanaAppBackground().ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        bentoCategoryHeader(
                            icon: "leaf.fill",
                            title: l.tr(zh: "赚取椰子", en: "Earn coconuts", de: "Kokosnüsse verdienen"),
                            subtitle: l.tr(
                                zh: "打卡越多，岛屿越繁荣",
                                en: "More care logs grow the island.",
                                de: "Mehr Pflegeeinträge stärken die Insel."
                            )
                        )
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(earnCards.enumerated()), id: \.element.id) { index, card in
                                bentoCard(card, delay: Double(index) * 0.05)
                            }
                        }

                        bentoCategoryHeader(
                            icon: "cart.fill",
                            title: l.tr(zh: "花费椰子", en: "Spend coconuts", de: "Kokosnüsse ausgeben"),
                            subtitle: l.tr(
                                zh: "用于升级岛屿和解锁体验",
                                en: "Use them for upgrades and unlocks.",
                                de: "Für Upgrades und Freischaltungen nutzen."
                            )
                        )
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Array(spendCards.enumerated()), id: \.element.id) { index, card in
                                bentoCard(card, delay: Double(earnCards.count + index) * 0.05)
                            }
                        }

                        bentoCategoryHeader(
                            icon: "person.2.fill",
                            title: l.tr(zh: "双账本系统", en: "Two-ledger system", de: "Zwei-Konten-System"),
                            subtitle: l.tr(
                                zh: "人宠各有账户，共同建设岛屿",
                                en: "People and pets contribute together.",
                                de: "Menschen und Tiere bauen gemeinsam."
                            )
                        )
                        VStack(spacing: 10) {
                            doubleAccountRow(
                                icon: "pawprint.fill",
                                title: l.tr(zh: "宠物账户", en: "Pet ledger", de: "Tier-Konto"),
                                desc: l.tr(zh: "记录宠物自己赚取的椰子", en: "Tracks coconuts earned by pets.", de: "Erfasst Kokosnüsse der Tiere.")
                            )
                            doubleAccountRow(
                                icon: "person.fill",
                                title: l.tr(zh: "主人账户", en: "Human ledger", de: "Menschen-Konto"),
                                desc: l.tr(zh: "记录协助打卡的人类获得的椰子", en: "Tracks coconuts earned by caregivers.", de: "Erfasst Kokosnüsse der Betreuenden.")
                            )
                            doubleAccountRow(
                                icon: "chart.pie.fill",
                                title: l.tr(zh: "全岛总库", en: "Island total", de: "Insel-Summe"),
                                desc: l.tr(zh: "统计全家椰子流动", en: "Summarizes family coconut flow.", de: "Fasst die Kokosnuss-Bewegung zusammen.")
                            )
                        }
                        .padding(14)
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
                        )

                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 24, weight: .black))
                                    .foregroundStyle(Color.goPrimary)
                                Text(l.tr(
                                    zh: "打卡次数越多，椰子越多，生命之树越旺。",
                                    en: "More care logs mean more coconuts and a stronger Life Tree.",
                                    de: "Mehr Pflegeeinträge bringen mehr Kokosnüsse und einen stärkeren Lebensbaum."
                                ))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.35))
                                .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(l.tr(zh: "椰子指南", en: "Coconut guide", de: "Kokosnuss-Guide"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(l.tr(zh: "关闭", en: "Close", de: "Schließen"))
                }
            }
        }
        .ohanaSheetPagePresentation() // ui-v4: allow rules reference sheet
        .onAppear {
            withAnimation(GoMotion.page) { appeared = true }
        }
    }

    @ViewBuilder
    private func bentoCategoryHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 22, height: 22)
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
        }
    }

    @ViewBuilder
    private func bentoCard(_ card: RuleCard, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: card.icon)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 42, height: 42)
                .background(card.glowColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(card.title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(card.desc)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(card.reward)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(card.glowColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(card.glowColor.opacity(0.15), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
        .scaleEffect(appeared ? 1 : 0.88)
        .opacity(appeared ? 1 : 0)
        .animation(GoMotion.page.delay(delay), value: appeared)
    }

    @ViewBuilder
    private func doubleAccountRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32)
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(desc)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()
        }
    }
}

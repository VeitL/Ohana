//
//  CoconutRulesSheet.swift
//  Ohana
//
//  Localized reference sheet for Oasis coconut earning and spending rules.
//

import SwiftUI

struct CoconutRulesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var appeared = false

    private var l: L10n { L10n(appLanguage) }

    private var treeInjectionRewardText: String {
        "\(OasisTreeEnergyInjectionPolicy.starterPackageCost)🥥 -> \(OasisTreeEnergyInjectionPolicy.starterPackageXP)XP"
    }

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
                reward: l.tr(
                    zh: "基础 5-14🥥 · 约每 350m 递增",
                    en: "Base 5-14🥥 · about +1 per 350m",
                    de: "Basis 5-14🥥 · ca. +1 je 350 m"
                )
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
                reward: l.tr(zh: "2-3🥥 · 5-7XP", en: "2-3🥥 · 5-7XP", de: "2-3🥥 · 5-7XP")
            ),
            RuleCard(
                icon: "scissors",
                title: l.tr(zh: "护理·梳毛", en: "Grooming", de: "Pflege"),
                desc: l.tr(zh: "精心打理日常护理", en: "Track care routines", de: "Pflegeabläufe erfassen"),
                glowColor: Color(hex: "DDA0DD"),
                reward: l.tr(zh: "5-8🥥 · 10-14XP", en: "5-8🥥 · 10-14XP", de: "5-8🥥 · 10-14XP")
            ),
            RuleCard(
                icon: "cross.case.fill",
                title: l.tr(zh: "健康打卡", en: "Health log", de: "Gesundheit"),
                desc: l.tr(zh: "关注健康，守护生命", en: "Care for health", de: "Gesundheit schützen"),
                glowColor: Color(hex: "FF6B6B"),
                reward: l.tr(zh: "10🥥 · 16XP", en: "10🥥 · 16XP", de: "10🥥 · 16XP")
            ),
            RuleCard(
                icon: "creditcard.fill",
                title: l.tr(zh: "记一笔账", en: "Expense log", de: "Ausgabe"),
                desc: l.tr(zh: "记录爱的花销", en: "Track care spending", de: "Ausgaben erfassen"),
                glowColor: Color(hex: "FFD93D"),
                reward: l.tr(zh: "2🥥 · 4XP", en: "2🥥 · 4XP", de: "2🥥 · 4XP")
            ),
            RuleCard(
                icon: "gamecontroller.fill",
                title: l.tr(zh: "逗玩互动", en: "Play time", de: "Spielzeit"),
                desc: l.tr(zh: "记录玩耍陪伴", en: "Log play and company", de: "Spiel und Nähe erfassen"),
                glowColor: Color(hex: "6BCB77"),
                reward: l.tr(zh: "走服务预算", en: "Service budget", de: "Service-Budget")
            ),
            RuleCard(
                icon: "calendar.badge.checkmark",
                title: l.tr(zh: "日历任务", en: "Calendar tasks", de: "Kalenderaufgaben"),
                desc: l.tr(zh: "完成可执行事件", en: "Finish actionable events", de: "Erledige ausführbare Termine"),
                glowColor: Color(hex: "38BDF8"),
                reward: l.tr(zh: "5🥥 · 走每日预算", en: "5🥥 · daily budget", de: "5🥥 · Tagesbudget")
            ),
            RuleCard(
                icon: "trophy.fill",
                title: l.tr(zh: "成就徽章", en: "Achievement badges", de: "Erfolgsabzeichen"),
                desc: l.tr(zh: "达成后手动领取", en: "Claim after unlocking", de: "Nach Freischaltung abholen"),
                glowColor: Color(hex: "FACC15"),
                reward: l.tr(zh: "10🥥/徽章 · 一次性", en: "10🥥/badge · one-time", de: "10🥥/Abzeichen · einmalig")
            ),
            RuleCard(
                icon: "flame.fill",
                title: l.tr(zh: "连击里程碑", en: "Streak milestones", de: "Serien-Meilensteine"),
                desc: l.tr(zh: "7/30/100/365 天连胜", en: "7/30/100/365-day streaks", de: "7/30/100/365-Tage-Serien"),
                glowColor: Color(hex: "FB7185"),
                reward: l.tr(zh: "特殊奖励 · 不占预算", en: "Special reward · no budget cap", de: "Sonderlohn · ohne Budgetlimit")
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
                title: l.tr(zh: "幸运奖励", en: "Lucky reward", de: "Glücksbonus"),
                desc: l.tr(zh: "幸运只加额外奖励，不整笔翻倍", en: "Luck adds a small bonus, not a multiplier", de: "Glück addiert einen Bonus, ohne Multiplikator"),
                glowColor: Color(hex: "FFCC00"),
                reward: l.tr(zh: "8% +2🥥 · 1% +8🥥", en: "8% +2🥥 · 1% +8🥥", de: "8% +2🥥 · 1% +8🥥")
            )
        ]
    }

    private var spendCards: [RuleCard] {
        [
            RuleCard(
                icon: "bolt.fill",
                title: l.tr(zh: "注入生命之树", en: "Inject energy", de: "Energie geben"),
                desc: l.tr(zh: "轻度加速，不能直接买穿等级", en: "Light acceleration without buying through levels", de: "Leichte Beschleunigung ohne Levelkauf"),
                glowColor: Color(hex: "F59E0B"),
                reward: treeInjectionRewardText
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
                icon: "chart.bar.doc.horizontal.fill",
                title: l.tr(zh: "照护周报", en: "Care reports", de: "Pflegeberichte"),
                desc: l.tr(zh: "回顾照护、成长和奖励", en: "Review care, growth, and rewards", de: "Pflege, Wachstum und Belohnungen ansehen"),
                glowColor: Color(hex: "FF8C42"),
                reward: l.tr(zh: "本机统计", en: "Local recap", de: "Lokale Übersicht")
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
                        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
                                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
                        )

                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill").accessibilityHidden(true)
                                    .font(OhanaFont.adaptive(size: 24, weight: .black))
                                    .foregroundStyle(Color.goPrimary)
                                Text(l.tr(
                                    zh: "真实照护获得成长 XP；椰子用于外观、玩法和轻度加速。",
                                    en: "Real care earns Growth XP; coconuts power cosmetics, play, and light boosts.",
                                    de: "Echte Pflege bringt Growth XP; Kokosnüsse treiben Kosmetik, Spiel und leichte Boosts an."
                                ))
                                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
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
                        Image(systemName: "xmark").accessibilityHidden(true)
                            .font(OhanaFont.adaptive(size: 17, weight: .black))
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
                    .font(OhanaFont.adaptive(size: 15, weight: .black))
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 22, height: 22) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                Text(title)
                    .font(OhanaFont.adaptive(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
            }
            Text(subtitle)
                .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
        }
    }

    @ViewBuilder
    private func bentoCard(_ card: RuleCard, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: card.icon)
                .font(OhanaFont.adaptive(size: 20, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 42, height: 42) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(card.glowColor, in: RoundedRectangle(cornerRadius: OhanaRadius.row, style: .continuous))
            Text(card.title)
                .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(card.desc)
                .font(OhanaFont.adaptive(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ohanaPrimaryText.opacity(0.45))
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(card.reward)
                .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(card.glowColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(card.glowColor.opacity(0.15), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous)
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
                .font(OhanaFont.adaptive(size: 14, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow visual glyph frame; parent row/control owns the 44pt hit target or the element is non-interactive.
                .background(Color.goPrimary, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(OhanaFont.adaptive(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(desc)
                    .font(OhanaFont.adaptive(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ohanaPrimaryText.opacity(0.4))
            }
            Spacer()
        }
    }
}

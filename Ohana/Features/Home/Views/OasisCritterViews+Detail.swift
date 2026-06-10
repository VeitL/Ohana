//
//  OasisCritterViews+Detail.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension OasisCritterCodexView {
    var selectedDetailContent: some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: selectedCatalogId) ?? OasisUpgradeRewardCatalog.critters[0]
        let critter = ownedCritter(entry.id)
        let fragmentCount = fragments.first(where: { $0.catalogId == entry.id })?.amount ?? 0
        let awakeningCost = OasisCritterPresentationRules.awakeningCost(for: entry.rarity)
        let snapshot = critter.map { renderSnapshot(for: $0) }
        return VStack(alignment: .leading, spacing: 16) {
            if critter == nil {
                VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    rarityColor(entry.rarity).opacity(critter == nil ? 0.08 : 0.26),
                                    Color.ohanaControlFill
                                ],
                                center: .top,
                                startRadius: 20,
                                endRadius: 220
                            )
                        )
                        .frame(height: 212)

                    OasisCritterIllustration(catalogId: entry.id, locked: critter == nil, size: 168, critter: critter)
                        .scaleEffect(pulseCatalogId == entry.id ? 1.08 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    HStack(spacing: 8) {
                        Text(l.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de))
                            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryActionText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rarityColor(entry.rarity), in: Capsule())
                    }
                    .padding(12)
                }

                VStack(spacing: 6) {
                    Text(entry.name(l))
                        .font(OhanaFont.adaptive(size: 25, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(entry.tagline(l))
                        .font(OhanaFont.adaptive(size: 12, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                    HStack(spacing: 7) {
                        codexMetric(value: "\(fragmentCount)◇", label: l.tr(zh: "碎片", en: "Fragments", de: "Fragmente"))
                        if critter == nil {
                            codexMetric(value: "\(awakeningCost.fragments)◇", label: l.tr(zh: "唤醒", en: "Awaken", de: "Wecken"))
                        }
                        if let critter {
                            codexMetric(value: "Lv.\(critter.level)", label: l.tr(zh: "等级", en: "Level", de: "Level"))
                            codexMetric(value: "\(critter.starLevel)★", label: l.tr(zh: "星级", en: "Stars", de: "Sterne"))
                            codexMetric(value: "B\(snapshot?.bondLevel ?? 1)", label: l.tr(zh: "羁绊", en: "Bond", de: "Bindung"))
                            codexMetric(value: "\(snapshot?.todayInteractionCount ?? 0)/3", label: l.tr(zh: "今日", en: "Today", de: "Heute"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                }
            }

            if let critter {
                critterToySurface(entry: entry, critter: critter, snapshot: snapshot ?? renderSnapshot(for: critter), fragmentCount: fragmentCount)
                if let lastInteractionOutcome, lastInteractionOutcome.success {
                    interactionOutcomeBanner(lastInteractionOutcome)
                }
                upgradeLevelButton(critter, snapshot: snapshot ?? renderSnapshot(for: critter))
            } else {
                lockedRoadmap(entry, fragmentCount: fragmentCount)
            }
        }
    }

    var selectedDetail: some View {
        selectedDetailContent
        .padding(16)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.ohanaPrimaryText.opacity(0.08), lineWidth: 1)
        )
    }

    func critterToySurface(
        entry: OasisElectronicPetCatalogEntry,
        critter: OasisElectronicPet,
        snapshot: OasisCritterRenderSnapshot,
        fragmentCount: Int
    ) -> some View {
        let wish = snapshot.dailyWish

        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(critter.displayName(l))
                            .font(OhanaFont.adaptive(size: 20, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaPrimaryText)
                            .lineLimit(1)
                        Text(lifecycleShortText(snapshot.lifecycle))
                            .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .lineLimit(1)
                        }
                    Spacer(minLength: 0)
                    if !(mode == .nest && isPopup) {
                        coconutBalanceButton
                    }
                }

                HStack(spacing: 7) {
                    toyInfoPill("Lv.\(snapshot.displayLevel)")
                    toyInfoPill(l.tr(zh: "形态 \(snapshot.appearanceStage)", en: "Form \(snapshot.appearanceStage)", de: "Form \(snapshot.appearanceStage)"))
                    toyInfoPill(l.tr(zh: entry.rarity.zh, en: entry.rarity.en, de: entry.rarity.de))
                    toyInfoPill("\(fragmentCount)◇")
                }
            }
            .padding(12)
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            GeometryReader { proxy in
                let width = proxy.size.width
                let auraTint = critterAuraTint(for: snapshot.lifecycle.state)
                ZStack {
                    critterAura(tint: auraTint, state: snapshot.lifecycle.state)
                        .frame(width: min(width * 0.94, 360), height: 350)
                        .position(x: width * 0.50, y: 218)

                    OasisCritterIllustration(catalogId: entry.id, locked: false, size: min(306, width * 0.82), critter: critter)
                        .scaleEffect(pulseCatalogId == entry.id ? 1.06 : 1)
                        .animation(GoMotion.feedback, value: pulseCatalogId)
                        .position(x: width * 0.50, y: 218)

                    homeDisplayToggle(critter)
                        .position(x: width - 72, y: 38)

                    toyActionButton(
                        icon: "fork.knife",
                        title: l.tr(zh: "喂", en: "Feed", de: "Füttern"),
                        cost: critterInteractionCostText(snapshot.feedCost),
                        enabled: snapshot.canFeed,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .feed
                    ) {
                        perform(.feed, critter: critter)
                    }
                    .position(x: width * 0.15, y: 138)

                    toyActionButton(
                        icon: "sparkles",
                        title: l.tr(zh: "玩", en: "Play", de: "Spiel"),
                        cost: critterInteractionCostText(snapshot.playCost),
                        enabled: snapshot.canPlay,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .play
                    ) {
                        perform(.play, critter: critter)
                    }
                    .position(x: width * 0.85, y: 138)

                    toyActionButton(
                        icon: "moon.fill",
                        title: l.tr(zh: "睡", en: "Rest", de: "Ruhen"),
                        cost: critterInteractionCostText(snapshot.restCost),
                        enabled: snapshot.canRest,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .rest
                    ) {
                        perform(.rest, critter: critter)
                    }
                    .position(x: width * 0.15, y: 312)

                    toyActionButton(
                        icon: "cross.case.fill",
                        title: l.tr(zh: "照顾", en: "Care", de: "Pflege"),
                        cost: l.tr(zh: "免费", en: "Free", de: "Gratis"),
                        enabled: snapshot.lifecycle.isRescuable && rescuingCritterId != critter.id,
                        highlighted: snapshot.lifecycle.isRescuable
                    ) {
                        rescue(critter)
                    }
                    .position(x: width * 0.85, y: 312)
                }
            }
            .frame(height: 440)

            critterToyCharts(critter, snapshot: snapshot)
        }
    }

    func toyInfoPill(_ text: String) -> some View {
        Text(text)
            .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
            .foregroundStyle(Color.ohanaPrimaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.ohanaCardSurface.opacity(0.72), in: Capsule())
    }

    var coconutBalanceButton: some View {
        CoconutBalanceCapsule(balance: currentCoconutBalance, showsDeltaAnimation: true) {
            if let activeHuman {
                onPresentCoconutLog(.human(activeHuman.id))
            } else {
                onPresentCoconutLog(nil)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .animation(GoMotion.feedback, value: currentCoconutBalance)
        .accessibilityLabel(l.tr(
            zh: "查看椰子历史，当前 \(currentCoconutBalance) 个椰子",
            en: "View coconut history, \(currentCoconutBalance) coconuts",
            de: "Kokosnuss-Verlauf ansehen, \(currentCoconutBalance) Kokosnüsse"
        ))
    }

    func critterAura(tint: Color, state: OasisCritterLifeState) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(state == .healthy ? 0.48 : 0.62),
                            tint.opacity(0.20),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 150
                    )
                )
                .blur(radius: 12)
            Circle()
                .strokeBorder(tint.opacity(state == .healthy ? 0.32 : 0.58), lineWidth: state == .healthy ? 1.2 : 2)
                .scaleEffect(state == .healthy ? 0.82 : 0.94)
                .blur(radius: 5)
            Circle()
                .strokeBorder(Color.ohanaCardSurface.opacity(0.28), lineWidth: 1)
                .scaleEffect(0.58)
                .blur(radius: 2)
        }
        .allowsHitTesting(false)
        .shadow(color: tint.opacity(state == .healthy ? 0.30 : 0.56), radius: state == .healthy ? 24 : 34, y: 0) // ui-v4: allow state aura behind critter
    }

    func homeDisplayToggle(_ critter: OasisElectronicPet) -> some View {
        let isFeatured = featuredDisplayOverrides[critter.id] ?? critter.isFeaturedOnOasis
        return HStack(spacing: 6) {
            Image(systemName: isFeatured ? "house.fill" : "house.slash.fill")
                .font(OhanaFont.adaptive(size: 11, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(isFeatured ? Color.goPrimary : Color.ohanaTertiaryText)
                .frame(width: 16)

            Text(isFeatured
                ? l.tr(zh: "首页显示", en: "Home", de: "Start")
                : l.tr(zh: "已隐藏", en: "Hidden", de: "Verborgen"))
                .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText.opacity(isFeatured ? 0.86 : 0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Toggle("", isOn: homeDisplayBinding(for: critter))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.goPrimary)
                .scaleEffect(0.62)
                .frame(width: 34, height: 22) // a11y: allow decorative non-interactive frame; hit area handled by parent
        }
        .padding(.leading, 9)
        .padding(.trailing, 7)
        .padding(.vertical, 4)
        .background(Color.ohanaControlFill, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .disabled(critter.lifeState == .dead)
        .opacity(critter.lifeState == .dead ? 0.42 : 1)
        .accessibilityLabel(isFeatured
            ? l.tr(zh: "关闭首页显示", en: "Hide from home", de: "Von Startseite ausblenden")
            : l.tr(zh: "显示在首页", en: "Show on home", de: "Auf Startseite zeigen"))
    }

    func homeDisplayBinding(for critter: OasisElectronicPet) -> Binding<Bool> {
        Binding(
            get: { featuredDisplayOverrides[critter.id] ?? critter.isFeaturedOnOasis },
            set: { newValue in
                let visibleValue = featuredDisplayOverrides[critter.id] ?? critter.isFeaturedOnOasis
                guard newValue != visibleValue else { return }
                toggleHomeDisplay(critter, desired: newValue)
            }
        )
    }

    func toyActionButton(icon: String, title: String, cost: String = "", enabled: Bool = true, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 17, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title)
                    .font(OhanaFont.adaptive(size: 10.5, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                if !cost.isEmpty {
                    Text(cost)
                        .font(OhanaFont.adaptive(size: 8.5, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            (highlighted ? Color.arkInk.opacity(0.14) : Color.ohanaControlFill.opacity(0.95)),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(width: 78, height: 66)
            .background(highlighted ? Color.goPrimary : Color.ohanaCardSurface.opacity(0.96), in: shape)
            .overlay(
                shape.strokeBorder(
                    highlighted ? Color.arkInk.opacity(0.18) : Color.ohanaPrimaryText.opacity(0.12),
                    lineWidth: highlighted ? 1.3 : 1
                )
            )
            .shadow(color: (highlighted ? Color.goPrimary : Color.ohanaPrimaryText).opacity(highlighted ? 0.28 : 0.10), radius: highlighted ? 14 : 8, x: 0, y: 5) // ui-v4: allow toy action button lift
            .opacity(enabled ? 1 : 0.42)
            .contentShape(shape)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    func critterToyCharts(_ critter: OasisElectronicPet, snapshot: OasisCritterRenderSnapshot) -> some View {
        VStack(spacing: 10) {
            toyStatusRow(icon: "fork.knife", value: critter.hunger, label: l.tr(zh: "饱腹", en: "Fullness", de: "Satt"), tint: Color.goOrange)
            toyStatusRow(icon: "face.smiling", value: critter.mood, label: l.tr(zh: "心情", en: "Mood", de: "Laune"), tint: Color.goTeal)
            toyStatusRow(icon: "cross.case.fill", value: critter.health, label: l.tr(zh: "健康", en: "Health", de: "Gesund"), tint: Color.goPurple)
            toyStatusRow(icon: "heart.fill", value: snapshot.bondProgress, label: l.tr(zh: "羁绊 B\(snapshot.bondLevel)", en: "Bond B\(snapshot.bondLevel)", de: "Bindung B\(snapshot.bondLevel)"), tint: Color(hex: "FF6AA6"))
            toyProgressRow(icon: "bolt.fill", value: snapshot.xpPercent, label: l.tr(zh: "成长 XP", en: "Growth XP", de: "Wachstum XP"), detail: "\(snapshot.xpProgress)/\(snapshot.xpTarget)", tint: Color.goPrimary)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    func toyStatusRow(icon: String, value: Int, label: String, tint: Color) -> some View {
        let clampedValue = max(0, min(100, value))
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 0)
                    Text("\(clampedValue)%")
                        .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }

                toyProgressTrack(value: clampedValue, tint: tint, height: 12)
            }
        }
        .padding(10)
        .background(Color.ohanaCardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        )
    }

    func toyProgressRow(icon: String, value: Int, label: String, detail: String, tint: Color) -> some View {
        let clampedValue = max(0, min(100, value))
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 12, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(tint)
                .frame(width: 32, height: 28) // a11y: allow decorative non-interactive frame; hit area handled by parent

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(label)
                        .font(OhanaFont.adaptive(size: 10.5, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                    Spacer(minLength: 0)
                    Text(detail)
                        .font(OhanaFont.adaptive(size: 10.5, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                        .monospacedDigit()
                }

                toyProgressTrack(value: clampedValue, tint: tint, height: 8)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    func toyProgressTrack(value: Int, tint: Color, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.ohanaCardSurface.opacity(0.78))
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(100, value))) / 100)
                    .animation(GoMotion.feedback, value: value)
            }
        }
        .frame(height: height)
    }

    func upgradeLevelButton(_ critter: OasisElectronicPet, snapshot: OasisCritterRenderSnapshot) -> some View {
        let isMax = critter.level >= snapshot.maxLevel
        let canUpgrade = snapshot.canUpgradeLevel
        return Button {
            upgrade(critter)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isMax ? "sparkles" : "arrow.up.forward.circle.fill")
                    .font(OhanaFont.adaptive(size: 18, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMax ? l.tr(zh: "已满级", en: "Final Form", de: "Endform") : l.tr(zh: "升级", en: "Upgrade", de: "Upgrade"))
                        .font(OhanaFont.adaptive(size: 15, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    Text(isMax
                        ? l.tr(zh: "Lumo 已经是最终形态", en: "Lumo is fully evolved", de: "Lumo ist voll entwickelt")
                        : l.tr(zh: "需要 \(snapshot.xpNeededForNextLevel) XP", en: "\(snapshot.xpNeededForNextLevel) XP needed", de: "\(snapshot.xpNeededForNextLevel) XP nötig"))
                        .font(OhanaFont.adaptive(size: 11, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .opacity(0.82)
                }
                Spacer()
                Text(isMax ? "Lv.\(snapshot.maxLevel)" : "\(snapshot.xpProgress)/\(snapshot.xpTarget)")
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .monospacedDigit()
            }
            .foregroundStyle(canUpgrade ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(canUpgrade ? Color.goPrimary : Color.ohanaControlFill, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!canUpgrade)
        .opacity(isMax || canUpgrade ? 1 : 0.72)
    }

    func lifecycleShortText(_ snapshot: OasisCritterLifecycleSnapshot) -> String {
        switch snapshot.state {
        case .healthy: return l.tr(zh: "状态很好", en: "Settled", de: "Ruhig")
        case .needsCare: return l.tr(zh: "想你了", en: "Needs you", de: "Vermisst dich")
        case .atRisk: return l.tr(zh: "需要照顾", en: "Needs care", de: "Braucht Pflege")
        case .sick: return l.tr(zh: "有点没精神", en: "Low energy", de: "Wenig Energie")
        case .critical: return l.tr(zh: "请照顾一下", en: "Care now", de: "Jetzt pflegen")
        case .dead: return l.tr(zh: "纪念中", en: "Memorial", de: "Erinnerung")
        }
    }

    func lockedRoadmap(_ entry: OasisElectronicPetCatalogEntry, fragmentCount: Int) -> some View {
        let level = entry.sourceLevel
        let cost = OasisCritterPresentationRules.awakeningCost(for: entry.rarity)
        let isLevelUnlocked = treeMgr.treeLevel.rawValue >= level
        let canAwaken = fragmentCount >= cost.fragments &&
            isLevelUnlocked &&
            currentCoconutBalance >= cost.coconuts
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill") // a11y: allow decorative icon covered by surrounding text or control
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryActionText)
                    .frame(width: 38, height: 38) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goPrimary, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.tr(zh: "生命之树 Lv.\(level) 保底唤醒", en: "Guaranteed at Life Tree Lv.\(level)", de: "Garantiert bei Lebensbaum Lv.\(level)"))
                        .font(OhanaFont.adaptive(size: 14, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaPrimaryText)
                    Text(isLevelUnlocked
                        ? l.tr(zh: "可以使用碎片唤醒。", en: "Fragments can awaken it now.", de: "Fragmente können es jetzt wecken.")
                        : l.tr(zh: "达到等级后可用碎片唤醒。", en: "Fragments unlock after this level.", de: "Fragmente werden ab diesem Level nutzbar."))
                        .font(OhanaFont.adaptive(size: 11, weight: .semibold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.ohanaSecondaryText)
                }
                Spacer()
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.ohanaControlFill)
                    Capsule()
                        .fill(Color.goPrimary)
                        .frame(width: proxy.size.width * CGFloat(min(1, Double(fragmentCount) / Double(cost.fragments))))
                        .animation(GoMotion.feedback, value: fragmentCount)
                }
            }
            .frame(height: 9)
            codexAction(
                icon: "sparkles",
                title: l.tr(zh: "碎片唤醒", en: "Awaken", de: "Wecken"),
                cost: "\(cost.fragments)◇ \(cost.coconuts)🥥",
                enabled: canAwaken
            ) {
                awaken(entry)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

//
//  OasisCritterViews+Detail.swift
//  Ohana
//

import SwiftData
import SwiftUI
import UIKit

extension OasisCritterCodexView {
    var selectedDetailContent: some View {
        let entry = OasisUpgradeRewardCatalog.critter(id: selectedCatalogId) ?? OasisUpgradeRewardCatalog.critters[0]
        let critter = ownedCritter(entry.id)
        let fragmentCount = fragments.first(where: { $0.catalogId == entry.id })?.amount ?? 0
        let awakeningAvailability = commandExecutor.awakenAvailability(catalogId: entry.id)
        let awakeningPlan = awakeningAvailability.fundingPlan
        let snapshot = critter.map { renderSnapshot(for: $0) }
        return VStack(alignment: .leading, spacing: 16) {
            if critter == nil {
                VStack(spacing: 12) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: OhanaRadius.cardLarge, style: .continuous)
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
                                codexMetric(value: "\(awakeningPlan.requiredGrowthCurrency)◇/✦", label: l.tr(zh: "唤醒", en: "Awaken", de: "Wecken"))
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
            .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OhanaRadius.hero, style: .continuous)
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
            .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))

            if let wish {
                critterDailyWishCard(
                    wish,
                    isCompleted: snapshot.isDailyWishCompleted
                )
            }

            VStack(spacing: 14) {
                HStack {
                    Spacer(minLength: 0)
                    homeDisplayToggle(critter)
                }

                ZStack {
                    critterAura(
                        tint: critterAuraTint(for: snapshot.lifecycle.state),
                        state: snapshot.lifecycle.state
                    )
                    .frame(maxWidth: 340)
                    .frame(height: 270)

                    OasisCritterIllustration(
                        catalogId: entry.id,
                        locked: false,
                        size: dynamicTypeSize.isAccessibilitySize ? 206 : 260,
                        critter: critter
                    )
                        .scaleEffect(pulseCatalogId == entry.id ? 1.06 : 1)
                        .animation(GoMotion.feedback, value: pulseCatalogId)
                }

                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 10),
                        count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                    ),
                    spacing: 10
                ) {
                    toyActionButton(
                        icon: "fork.knife",
                        title: l.tr(zh: "喂", en: "Feed", de: "Füttern"),
                        cost: critterInteractionCostText(snapshot.feedCost),
                        enabled: snapshot.canFeed,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .feed
                    ) {
                        perform(.feed, critter: critter)
                    }

                    toyActionButton(
                        icon: "sparkles",
                        title: l.tr(zh: "玩", en: "Play", de: "Spiel"),
                        cost: critterInteractionCostText(snapshot.playCost),
                        enabled: snapshot.canPlay,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .play
                    ) {
                        perform(.play, critter: critter)
                    }

                    toyActionButton(
                        icon: "moon.fill",
                        title: l.tr(zh: "睡", en: "Rest", de: "Ruhen"),
                        cost: critterInteractionCostText(snapshot.restCost),
                        enabled: snapshot.canRest,
                        highlighted: !snapshot.isDailyWishCompleted && wish?.action == .rest
                    ) {
                        perform(.rest, critter: critter)
                    }

                    toyActionButton(
                        icon: "cross.case.fill",
                        title: l.tr(zh: "照顾", en: "Care", de: "Pflege"),
                        cost: l.tr(zh: "免费", en: "Free", de: "Gratis"),
                        enabled: snapshot.lifecycle.isRescuable && rescuingCritterId != critter.id,
                        highlighted: snapshot.lifecycle.isRescuable
                    ) {
                        rescue(critter)
                    }
                }
            }

            critterToyCharts(critter, snapshot: snapshot)

            starUpgradeButton(critter, snapshot: snapshot)
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
        .disabled(critter.lifeState == .dead || critter.lifeState == .critical || critter.lifeState == .sleeping)
        .opacity(critter.lifeState == .dead || critter.lifeState == .critical || critter.lifeState == .sleeping ? 0.42 : 1)
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
        let shape = RoundedRectangle(cornerRadius: OhanaRadius.cardSoft, style: .continuous)
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
                            highlighted ? Color.arkInk.opacity(0.14) : Color.ohanaControlFill.opacity(0.95),
                            in: Capsule()
                        )
                }
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryText)
            .frame(maxWidth: .infinity, minHeight: 70)
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
            toyStatusRow(icon: "heart.fill", value: snapshot.bondProgress, label: l.tr(zh: "羁绊 B\(snapshot.bondLevel)", en: "Bond B\(snapshot.bondLevel)", de: "Bindung B\(snapshot.bondLevel)"), tint: Color(hex: "FF6AA6"))
            toyProgressRow(icon: "bolt.fill", value: snapshot.xpPercent, label: l.tr(zh: "成长 XP", en: "Growth XP", de: "Wachstum XP"), detail: "\(snapshot.xpProgress)/\(snapshot.xpTarget)", tint: Color.goPrimary)
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
    }

    func critterDailyWishCard(_ wish: OasisCritterDailyWish, isCompleted: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : wish.icon)
                .font(OhanaFont.title3(.black))
                .foregroundStyle(isCompleted ? Color.arkInk : Color.ohanaPrimaryActionText)
                .frame(width: 44, height: 44)
                .background(isCompleted ? Color.goPrimary : Color.goPurple, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(isCompleted
                    ? l.tr(zh: "今日心愿已完成", en: "Today's wish is complete", de: "Heutiger Wunsch erfüllt")
                    : wish.title(l))
                    .font(OhanaFont.headline(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)
                Text(isCompleted
                    ? l.tr(zh: "明天会有新的小心愿。", en: "A new tiny wish arrives tomorrow.", de: "Morgen kommt ein neuer kleiner Wunsch.")
                    : wish.detail(l))
                    .font(OhanaFont.subheadline(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                if !isCompleted {
                    Text(wish.rewardText(l))
                        .font(OhanaFont.footnote(.black))
                        .foregroundStyle(Color.goPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    func starUpgradeButton(
        _ critter: OasisElectronicPet,
        snapshot: OasisCritterRenderSnapshot
    ) -> some View {
        let availability = commandExecutor.starUpgradeAvailability(
            for: critter,
            isProcessing: isGrowthCommandInFlight(catalogID: critter.catalogId)
        )
        let plan = availability.fundingPlan
        return Button {
            requestStarUpgrade(critter)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: critter.starLevel >= OasisCompanionCurrency.maxStarLevel ? "star.circle.fill" : "star.fill")
                    .font(OhanaFont.title3(.black))
                VStack(alignment: .leading, spacing: 3) {
                    Text(critter.starLevel >= OasisCompanionCurrency.maxStarLevel
                        ? l.tr(zh: "已满星", en: "Maximum stars", de: "Maximale Sterne")
                        : l.tr(zh: "升至 \(critter.starLevel + 1) 星", en: "Upgrade to \(critter.starLevel + 1) stars", de: "Auf \(critter.starLevel + 1) Sterne"))
                        .font(OhanaFont.headline(.black))
                    Text(growthFundingText(plan))
                        .font(OhanaFont.footnote(.bold))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Text("\(critter.starLevel)/\(OasisCompanionCurrency.maxStarLevel)")
                    .font(OhanaFont.footnote(.black))
                    .monospacedDigit()
            }
            .foregroundStyle(availability.isAvailable ? Color.arkInk : Color.ohanaPrimaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                availability.isAvailable ? Color.goPrimary : Color.ohanaControlFill,
                in: RoundedRectangle(cornerRadius: OhanaRadius.input, style: .continuous)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!availability.isAvailable)
        .opacity(availability.reason == .maxStars || availability.isAvailable ? 1 : 0.72)
        .accessibilityHint(availabilityReasonText(availability.reason))
    }

    func growthFundingText(_ plan: CompanionFundingPlan) -> String {
        var parts = [
            "\(plan.specificFragmentsUsed)◇",
            "\(plan.stardustUsed)✦",
            "\(plan.coconutCost)🥥"
        ]
        if plan.missingGrowthCurrency > 0 {
            parts.append(l.tr(
                zh: "还差 \(plan.missingGrowthCurrency)◇/✦",
                en: "\(plan.missingGrowthCurrency) ◇/✦ short",
                de: "\(plan.missingGrowthCurrency) ◇/✦ fehlen"
            ))
        }
        if plan.missingCoconuts > 0 {
            parts.append(l.tr(
                zh: "还差 \(plan.missingCoconuts)🥥",
                en: "\(plan.missingCoconuts) 🥥 short",
                de: "\(plan.missingCoconuts) 🥥 fehlen"
            ))
        }
        return parts.joined(separator: "  ")
    }

    func availabilityReasonText(_ reason: CompanionActionUnavailableReason?) -> String {
        switch reason {
        case .noActiveHuman:
            l.tr(zh: "请先选择一位有效成员。", en: "Select an active person first.", de: "Wähle zuerst eine aktive Person.")
        case .treeLevelLocked:
            l.tr(zh: "生命之树等级尚未解锁。", en: "The Life Tree level is still locked.", de: "Das Lebensbaum-Level ist noch gesperrt.")
        case .insufficientCoconuts:
            l.tr(zh: "椰子不足。", en: "Not enough coconuts.", de: "Nicht genug Kokosnüsse.")
        case .insufficientGrowthCurrency:
            l.tr(zh: "专属碎片和通用星光不足。", en: "Not enough fragments and stardust.", de: "Nicht genug Fragmente und Sternenstaub.")
        case .insufficientXP:
            l.tr(zh: "成长 XP 不足。", en: "Not enough growth XP.", de: "Nicht genug Wachstums-XP.")
        case .processing:
            l.tr(zh: "正在处理。", en: "Processing.", de: "Wird verarbeitet.")
        case .maxLevel:
            l.tr(zh: "已满级。", en: "Maximum level reached.", de: "Maximales Level erreicht.")
        case .maxStars:
            l.tr(zh: "已达五星。", en: "Five stars reached.", de: "Fünf Sterne erreicht.")
        case .sleeping:
            l.tr(zh: "请先免费唤醒伙伴。", en: "Wake the companion for free first.", de: "Wecke den Begleiter zuerst kostenlos.")
        case .alreadyOwned:
            l.tr(zh: "伙伴已拥有。", en: "Companion already owned.", de: "Begleiter bereits vorhanden.")
        case .unknownCompanion:
            l.tr(zh: "无法识别伙伴。", en: "Unknown companion.", de: "Unbekannter Begleiter.")
        case nil:
            ""
        }
    }

    func toyStatusRow(icon: String, value: Int, label: String, tint: Color) -> some View {
        let clampedValue = max(0, min(100, value))
        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryActionText)
                .frame(width: 32, height: 32) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(tint, in: RoundedRectangle(cornerRadius: OhanaRadius.badge, style: .continuous))

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
        .background(Color.ohanaCardSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OhanaRadius.control, style: .continuous)
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
        case .healthy: l.tr(zh: "状态很好", en: "Settled", de: "Ruhig")
        case .needsCare: l.tr(zh: "想你了", en: "Needs you", de: "Vermisst dich")
        case .atRisk: l.tr(zh: "需要照顾", en: "Needs care", de: "Braucht Pflege")
        case .sick: l.tr(zh: "有点没精神", en: "Low energy", de: "Wenig Energie")
        case .critical, .sleeping, .dead: l.tr(zh: "安心休眠", en: "Safely sleeping", de: "Schläft sicher")
        }
    }

    func lockedRoadmap(_ entry: OasisElectronicPetCatalogEntry, fragmentCount: Int) -> some View {
        let level = entry.sourceLevel
        let availability = commandExecutor.awakenAvailability(
            catalogId: entry.id,
            isProcessing: isGrowthCommandInFlight(catalogID: entry.id)
        )
        let plan = availability.fundingPlan
        let isLevelUnlocked = availability.reason != .treeLevelLocked
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
                        ? l.tr(zh: "专属碎片优先，星光自动补足。", en: "Specific fragments first; stardust fills the gap.", de: "Spezifische Fragmente zuerst, Sternenstaub ergänzt.")
                        : l.tr(zh: "达到等级后可唤醒。", en: "Awakening unlocks at this level.", de: "Erweckung wird ab diesem Level verfügbar."))
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
                        .frame(width: proxy.size.width * CGFloat(
                            plan.requiredGrowthCurrency == 0
                                ? 1
                                : min(1, Double(fragmentCount + plan.stardustBalance) / Double(plan.requiredGrowthCurrency))
                        ))
                        .animation(GoMotion.feedback, value: fragmentCount)
                }
            }
            .frame(height: 9)
            codexAction(
                icon: "sparkles",
                title: entry.id == OasisUpgradeRewardCatalog.firstCritterId
                    ? l.tr(zh: "免费唤醒", en: "Wake for free", de: "Kostenlos wecken")
                    : l.tr(zh: "唤醒伙伴", en: "Awaken", de: "Wecken"),
                cost: growthFundingText(plan),
                enabled: availability.isAvailable
            ) {
                requestAwaken(entry)
            }

            if let reason = availability.reason, reason != .treeLevelLocked {
                Text(availabilityReasonText(reason))
                    .font(OhanaFont.footnote(.semibold))
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: OhanaRadius.controlLarge, style: .continuous))
    }
}

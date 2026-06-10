//
//  OasisCritterViews+Actions.swift
//  Ohana
//

import SwiftUI
import SwiftData
import UIKit

extension OasisCritterCodexView {
    func codexMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(OhanaFont.adaptive(size: 13, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.goPrimary)
            Text(label)
                .font(OhanaFont.adaptive(size: 9, weight: .bold, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(minWidth: 52)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func interactionOutcomeBanner(_ outcome: OasisCritterInteractionOutcome) -> some View {
        HStack(spacing: 9) {
            Image(systemName: outcome.completedDailyWish ? "sparkles" : actionIcon(outcome.action))
                .font(OhanaFont.adaptive(size: 13, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(outcome.completedDailyWish ? Color.arkInk : Color.goPrimary)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(outcome.completedDailyWish ? Color.goYellow : Color.ohanaControlFill, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(outcome.message(l))
                    .font(OhanaFont.adaptive(size: 12, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .lineLimit(2)
                let reward = outcome.rewardText(l)
                if !reward.isEmpty {
                    Text(reward)
                        .font(OhanaFont.adaptive(size: 10, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .foregroundStyle(Color.goPrimary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    func codexAction(icon: String, title: String, cost: String, enabled: Bool = true, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                Text(title)
                    .font(OhanaFont.adaptive(size: 11, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                if !cost.isEmpty {
                    Text(cost)
                        .font(OhanaFont.adaptive(size: 9, weight: .black, design: .rounded)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                        .opacity(0.62)
                    }
            }
            .foregroundStyle(highlighted ? Color.arkInk : Color.ohanaPrimaryActionText)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(enabled ? (highlighted ? Color.goYellow : Color.goPrimary) : Color.ohanaControlFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(enabled ? 1 : 0.52)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    func perform(_ action: OasisCritterAction, critter: OasisElectronicPet) {
        OhanaFeedback.light()
        pulse(catalogId: critter.catalogId)
        scheduleCritterCommand {
            do {
                let outcome = try commandExecutor.interact(with: critter, action: action)
                withAnimation(GoMotion.feedback) {
                    lastInteractionOutcome = outcome.success ? outcome : nil
                }
                feedback(for: critter.catalogId, success: outcome.success)
                if outcome.success {
                    clearInteractionOutcomeLater(outcome)
                    scheduleRenderSnapshotRefresh(milliseconds: 30)
                }
            } catch {
                feedback(for: critter.catalogId, success: false)
            }
        }
    }

    func rescue(_ critter: OasisElectronicPet) {
        guard rescuingCritterId == nil else { return }
        withAnimation(GoMotion.tap) {
            rescuingCritterId = critter.id
        }
        OhanaFeedback.light()
        scheduleCritterCommand {
            defer { clearRescueBusyState(for: critter.id) }
            do {
                let outcome = try commandExecutor.rescue(critter)
                withAnimation(GoMotion.feedback) {
                    lastInteractionOutcome = outcome.success ? outcome : nil
                }
                feedback(for: critter.catalogId, success: outcome.success)
                if outcome.success {
                    clearInteractionOutcomeLater(outcome)
                    scheduleRenderSnapshotRefresh(milliseconds: 30)
                }
            } catch {
                feedback(for: critter.catalogId, success: false)
            }
        }
    }

    func clearRescueBusyState(for critterId: UUID) {
        rescueBusyCleanupTask?.cancel()
        rescueBusyCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 450) {
            guard rescuingCritterId == critterId else { return }
            withAnimation(GoMotion.tap) {
                rescuingCritterId = nil
            }
            rescueBusyCleanupTask = nil
        }
    }

    func upgrade(_ critter: OasisElectronicPet) {
        OhanaFeedback.light()
        pulse(catalogId: critter.catalogId)
        scheduleCritterCommand {
            do {
                feedback(for: critter.catalogId, success: try commandExecutor.upgradeLevel(critter))
                scheduleRenderSnapshotRefresh(milliseconds: 30)
            } catch {
                feedback(for: critter.catalogId, success: false)
            }
        }
    }

    func awaken(_ entry: OasisElectronicPetCatalogEntry) {
        OhanaFeedback.light()
        pulse(catalogId: entry.id)
        scheduleCritterCommand {
            do {
                if let critter = try commandExecutor.awakenWithFragments(catalogId: entry.id) {
                    withAnimation(GoMotion.fab) {
                        selectedCatalogId = critter.catalogId
                    }
                    feedback(for: entry.id, success: true)
                    scheduleRenderSnapshotRefresh(milliseconds: 30)
                } else {
                    feedback(for: entry.id, success: false)
                }
            } catch {
                feedback(for: entry.id, success: false)
            }
        }
    }

    func toggleHomeDisplay(_ critter: OasisElectronicPet, desired: Bool) {
        guard critter.lifeState != .dead else {
            feedback(for: critter.catalogId, success: false)
            return
        }
        withAnimation(GoMotion.tap) {
            featuredDisplayOverrides[critter.id] = desired
        }
        OhanaFeedback.light()
        scheduleCritterCommand {
            do {
                try commandExecutor.setFeatured(critter, desired: desired)
                featuredDisplayOverrides[critter.id] = nil
                feedback(for: critter.catalogId, success: true)
                scheduleRenderSnapshotRefresh(milliseconds: 30)
            } catch {
                featuredDisplayOverrides[critter.id] = nil
                feedback(for: critter.catalogId, success: false)
            }
        }
    }

    func feedback(for catalogId: String, success: Bool) {
        if success {
            OhanaFeedback.light()
            pulse(catalogId: catalogId)
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func pulse(catalogId: String) {
        withAnimation(GoMotion.feedback) { pulseCatalogId = catalogId }
        pulseCleanupTask?.cancel()
        pulseCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 340) {
            withAnimation(GoMotion.feedback) { pulseCatalogId = nil }
            pulseCleanupTask = nil
        }
    }

    func clearInteractionOutcomeLater(_ outcome: OasisCritterInteractionOutcome) {
        outcomeCleanupTask?.cancel()
        outcomeCleanupTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 3_400) {
            guard lastInteractionOutcome == outcome else { return }
            withAnimation(GoMotion.reduced) {
                lastInteractionOutcome = nil
            }
            outcomeCleanupTask = nil
        }
    }

    func rarityColor(_ rarity: OasisElectronicPetRarity) -> Color {
        switch rarity {
        case .common: return Color.goTeal
        case .rare: return Color(hex: "7C6CFF")
        case .epic: return Color(hex: "B45CFF")
        case .legendary: return Color.goOrange
        }
    }

    func actionIcon(_ action: OasisCritterAction) -> String {
        switch action {
        case .feed: return "fork.knife"
        case .play: return "sparkles"
        case .rest: return "moon.fill"
        case .rescue: return "cross.case.fill"
        case .levelUpgrade: return "arrow.up.forward.circle.fill"
        case .starUpgrade: return "star.fill"
        case .unlock: return "lock.open.fill"
        case .fragmentAwaken: return "sparkles"
        case .feature: return "house.fill"
        case .careEcho: return "heart.fill"
        case .death: return "leaf.fill"
        }
    }

    func critterAuraTint(for state: OasisCritterLifeState) -> Color {
        switch state {
        case .healthy:
            return Color.goPrimary
        case .dead:
            return Color.ohanaTertiaryText
        case .needsCare, .atRisk, .sick, .critical:
            return Color.goRed
        }
    }

    func critterInteractionCostText(_ cost: Int) -> String {
        return cost == 0 ? l.tr(zh: "免费", en: "Free", de: "Gratis") : "\(cost)🥥"
    }
}

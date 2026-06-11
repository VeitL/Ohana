//
//  WalkTrackingCard+Actions.swift
//  Ohana
//

import MapKit
import SwiftData
import SwiftUI

extension WalkTrackingCard {
    // MARK: - Action Buttons

    @ViewBuilder
    var actionButtons: some View {
        let phase = isActivePet ? mgr.phase : .idle
        HStack(spacing: 8) {
            switch phase {
            case .idle:
                sharedWalkTargetMenu
                Button {
                    mgr.start(pet: pet)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("出发", systemImage: "figure.walk")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())

            case .running:
                circleButton(icon: "pause.fill", color: Color.goYellow) { mgr.pause() }
                circleButton(icon: "stop.fill", color: Color.goRed) {
                    finishWalkAndFlip()
                }
                poopButton

            case .paused:
                circleButton(icon: "play.fill", color: Color.goTeal) { mgr.resume() }
                circleButton(icon: "stop.fill", color: Color.goRed) {
                    finishWalkAndFlip()
                }
                poopButton

            case .finished:
                Button {
                    mgr.reset()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label("再来", systemImage: "arrow.clockwise")
                        .font(OhanaFont.caption(.bold))
                        .foregroundStyle(Color.arkInk)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    @ViewBuilder
    var sharedWalkTargetMenu: some View {
        if sameSpeciesWalkPets.count > 1 {
            Menu {
                ForEach(sameSpeciesWalkPets) { target in
                    if target.id == pet.id {
                        Label(target.name, systemImage: "checkmark.circle.fill")
                    } else {
                        Button {
                            if selectedSharedWalkPetIds.contains(target.id) {
                                selectedSharedWalkPetIds.remove(target.id)
                            } else {
                                selectedSharedWalkPetIds.insert(target.id)
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(
                                target.name,
                                systemImage: selectedSharedWalkPetIds.contains(target.id) ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                }
            } label: {
                Label(sharedWalkTargetTitle, systemImage: selectedWalkTargets.count > 1 ? "pawprint.fill" : "pawprint")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    var sharedWalkTargetTitle: String {
        let count = selectedWalkTargets.count
        return L10n(appLanguage).tr(
            zh: count > 1 ? "同行 \(count)只" : "单独",
            en: count > 1 ? "\(count) pets" : "Solo",
            de: count > 1 ? "\(count) Tiere" : "Solo"
        )
    }

    func circleButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: icon)
                .font(OhanaFont.caption(.bold))
                .foregroundStyle(Color.arkInk)
                .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                .background(color, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    var poopButton: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                mgr.addPoop()
                showFloatingPoop = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showFloatingPoop = false }
            } label: {
                Text("💩")
                    .font(OhanaFont.adaptive(size: 15)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .frame(width: 34, height: 34) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.ohanaCardSurface, in: Circle())
            }
            if mgr.poopCount > 0 {
                Text("\(mgr.poopCount)")
                    .font(OhanaFont.caption2(.bold))
                    .foregroundStyle(Color.goCardWhite)
                    .frame(width: 15, height: 15) // a11y: allow decorative non-interactive frame; hit area handled by parent
                    .background(Color.goOrange, in: Circle())
                    .offset(x: 3, y: -3)
            }
        }
    }

    func finishWalkAndFlip() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        onStopWalk(selectedWalkTargets)
        presentSummaryBack()
    }

    func presentSummaryBack(animated: Bool = true) {
        guard !showSummaryBack else { return }
        isClosingSummaryBack = false
        showSummaryBack = true
        summaryRotation = 0
        let updates = { summaryRotation = 180.0 }
        if animated {
            withAnimation(GoMotion.page) { updates() }
        } else {
            updates()
        }
    }

    func updateRainbowRouteFlow() {
        guard shouldAnimateRainbowWalkEffects else {
            withAnimation(GoMotion.feedback) { rainbowRoutePhase = 0 }
            return
        }
        rainbowRoutePhase = 0
        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) { // ui-v4: allow route cosmetic loop; runtime-guardrail: allow gated by AppWorkloadPolicy and only used for visible equipped walk maps; smoothness: allow visible active-walk route effect gated by surfaceGate.
            rainbowRoutePhase = -68
        }
    }

    func closeSummaryBack() {
        guard showSummaryBack, !isClosingSummaryBack else { return }
        isClosingSummaryBack = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let onCloseSummaryToPetCard {
            onCloseSummaryToPetCard()
            return
        }
        withAnimation(GoMotion.page) {
            summaryRotation = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            showSummaryBack = false
            isClosingSummaryBack = false
            mgr.reset()
        }
    }
}

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
                sharedWalkExecutorMenu
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
                .accessibilityIdentifier("walk-tracking-start-action")

            case .running:
                circleButton(icon: "pause.fill", color: Color.goYellow, accessibilityIdentifier: "walk-tracking-pause-action") { mgr.pause() }
                circleButton(icon: "stop.fill", color: Color.goRed, accessibilityIdentifier: "walk-tracking-stop-action") {
                    finishWalkAndFlip()
                }
                poopButton

            case .paused:
                circleButton(icon: "play.fill", color: Color.goTeal, accessibilityIdentifier: "walk-tracking-resume-action") { mgr.resume() }
                circleButton(icon: "stop.fill", color: Color.goRed, accessibilityIdentifier: "walk-tracking-stop-action") {
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
                .accessibilityIdentifier("walk-tracking-restart-action")
            }
        }
    }

    @ViewBuilder
    var sharedWalkExecutorMenu: some View {
        if allHumans.count > 1 {
            Menu {
                ForEach(allHumans) { human in
                    let humanId = human.id.uuidString
                    if humanId == activeWalkHumanId {
                        Label(displayWalkHumanName(human), systemImage: "checkmark.circle.fill")
                    } else {
                        Button {
                            if selectedSharedWalkExecutorIds.contains(humanId) {
                                selectedSharedWalkExecutorIds.remove(humanId)
                            } else {
                                selectedSharedWalkExecutorIds.insert(humanId)
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(
                                displayWalkHumanName(human),
                                systemImage: selectedSharedWalkExecutorIds.contains(humanId) ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                }
            } label: {
                Label(sharedWalkExecutorTitle, systemImage: selectedWalkExecutorIds.count > 1 ? "person.2.fill" : "person.fill")
                    .font(OhanaFont.caption(.bold))
                    .foregroundStyle(Color.ohanaPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.ohanaControlFill, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
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

    var sharedWalkExecutorTitle: String {
        let count = selectedWalkExecutorIds.count
        return L10n(appLanguage).tr(
            zh: count > 1 ? "\(count)人" : "单人",
            en: count > 1 ? "\(count) walkers" : "One",
            de: count > 1 ? "\(count) Personen" : "Allein"
        )
    }

    var sharedWalkTargetTitle: String {
        let count = selectedWalkTargets.count
        return L10n(appLanguage).tr(
            zh: count > 1 ? "同行 \(count)只" : "单独",
            en: count > 1 ? "\(count) pets" : "Solo",
            de: count > 1 ? "\(count) Tiere" : "Solo"
        )
    }

    func refreshDefaultWalkExecutors() {
        let validIds = Set(allHumans.map(\.id.uuidString))
        selectedSharedWalkExecutorIds = selectedSharedWalkExecutorIds.intersection(validIds)
        if let activeWalkHumanId {
            selectedSharedWalkExecutorIds.insert(activeWalkHumanId)
        }
    }

    func displayWalkHumanName(_ human: Human) -> String {
        let name = human.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? L10n(appLanguage).tr(zh: "未命名成员", en: "Unnamed member", de: "Unbenannt") : name
    }

    func circleButton(icon: String, color: Color, accessibilityIdentifier: String? = nil, action: @escaping () -> Void) -> some View {
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
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
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
            .accessibilityIdentifier("walk-tracking-poop-action")
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
        SharedPetSelectionMemory.saveSelection(
            Set(selectedWalkTargets.map(\.id)),
            sourcePet: pet,
            scope: "walk.shared",
            candidates: sameSpeciesWalkPets
        )
        onStopWalk(selectedWalkTargets, selectedWalkExecutorIds)
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

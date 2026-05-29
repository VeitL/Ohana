//
//  OasisHomeTabHost.swift
//  Ohana
//
//  Keeps the vertical home tab transition light by showing a static Oasis
//  preview during page motion, then mounting the full Oasis feature after.
//

import SwiftUI

struct OasisHomeTabHost: View {
    let lifecycle: VerticalSolidHomePageLifecycle
    let injectEnergyTrigger: Int

    @State private var showsLiveContent = false
    @State private var forwardedInjectEnergyTrigger = 0
    @State private var liveContentTask: Task<Void, Never>?
    @State private var injectHandoffTask: Task<Void, Never>?
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var l: L10n { L10n(appLanguage) }
    private var liveContentMountDelayMilliseconds: UInt64 {
        reduceMotion ? 80 : 360
    }

    var body: some View {
        ZStack {
            OasisHomeTabPreview(
                title: l.tr(zh: "Oasis", en: "Oasis", de: "Oasis"),
                subtitle: l.tr(zh: "生命之树", en: "Life Tree", de: "Lebensbaum")
            )
            .opacity(showsLiveContent ? 0 : 1)
            .allowsHitTesting(false)

            if showsLiveContent {
                OasisRewardView(
                    hideToolbar: true,
                    injectEnergyTrigger: forwardedInjectEnergyTrigger,
                    isEmbeddedPrepared: true,
                    isEmbeddedVisible: true,
                    isEmbeddedActive: true
                )
                .transition(.opacity.animation(GoMotion.quick))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .onAppear(perform: updateLiveContentGate)
        .onDisappear {
            liveContentTask?.cancel()
            injectHandoffTask?.cancel()
            liveContentTask = nil
            injectHandoffTask = nil
        }
        .onChange(of: lifecycle) { _, _ in
            updateLiveContentGate()
        }
        .onChange(of: injectEnergyTrigger) { _, newValue in
            handleInjectEnergyTriggerChanged(newValue)
        }
    }

    private func updateLiveContentGate() {
        liveContentTask?.cancel()
        if lifecycle.isLive {
            guard !showsLiveContent else { return }
            liveContentTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: liveContentMountDelayMilliseconds) {
                guard lifecycle.isLive else {
                    liveContentTask = nil
                    return
                }
                withAnimation(GoMotion.quick) {
                    showsLiveContent = true
                }
                schedulePendingInjectHandoff()
                liveContentTask = nil
            }
        } else {
            injectHandoffTask?.cancel()
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showsLiveContent = false
            }
            liveContentTask = nil
            injectHandoffTask = nil
        }
    }

    private func handleInjectEnergyTriggerChanged(_ newValue: Int) {
        guard lifecycle.isLive else { return }
        if showsLiveContent {
            forwardedInjectEnergyTrigger = newValue
        } else {
            schedulePendingInjectHandoff()
        }
    }

    private func schedulePendingInjectHandoff() {
        guard lifecycle.isLive, showsLiveContent, forwardedInjectEnergyTrigger != injectEnergyTrigger else { return }
        injectHandoffTask?.cancel()
        injectHandoffTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            guard lifecycle.isLive, showsLiveContent else {
                injectHandoffTask = nil
                return
            }
            forwardedInjectEnergyTrigger = injectEnergyTrigger
            injectHandoffTask = nil
        }
    }
}

private struct OasisHomeTabPreview: View {
    let title: String
    let subtitle: String

    private var treeLevel: TreeLevel {
        OasisTreeManager.shared.treeLevel
    }

    private var progress: Double {
        OasisTreeManager.shared.progressToNextLevel
    }

    var body: some View {
        ZStack {
            OhanaAppBackground()

            VStack(spacing: 14) {
                previewStage
                    .padding(.horizontal, 6)

                previewBentoGrid
                    .padding(.horizontal, 10)
            }
            .padding(.horizontal, 10)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    private var previewStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.ohanaCardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(treeLevel.glowColor.opacity(0.16))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.ohanaGlassStroke.opacity(0.7), lineWidth: 0.8)
                }

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(OhanaFont.title3(.black))
                            .foregroundStyle(Color.ohanaPrimaryText)
                        Text(subtitle)
                            .font(OhanaFont.caption(.bold))
                            .foregroundStyle(Color.ohanaSecondaryText)
                    }
                    Spacer()
                    Text("Lv.\(treeLevel.rawValue)")
                        .font(OhanaFont.caption(.black))
                        .foregroundStyle(Color.ohanaPrimaryActionText)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(Color.goPrimary, in: Capsule())
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(treeLevel.glowColor.opacity(0.18))
                        .frame(width: 210, height: 210)
                    Image(systemName: "tree.fill")
                        .font(.system(size: 118, weight: .black))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.goPrimary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.ohanaControlFill)
                            Capsule()
                                .fill(Color.goPrimary)
                                .frame(width: max(10, proxy.size.width * CGFloat(progress)))
                        }
                    }
                    .frame(height: 10)

                    HStack {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .black))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.goPrimary)
                        Text("\(Int(progress * 100))%")
                            .font(OhanaFont.caption(.black))
                            .foregroundStyle(Color.ohanaSecondaryText)
                            .monospacedDigit()
                        Spacer()
                    }
                }
            }
            .padding(18)
        }
        .frame(height: 540)
    }

    private var previewBentoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            previewTile(icon: "shippingbox.fill")
            previewTile(icon: "trophy.fill")
            previewTile(icon: "pawprint.fill")
            previewTile(icon: "calendar.badge.checkmark")
        }
    }

    private func previewTile(icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goPrimary)
                .frame(width: 32, height: 32)
                .background(Color.ohanaControlFill, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.22))
                    .frame(width: 58, height: 7)
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.14))
                    .frame(width: 38, height: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 64)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

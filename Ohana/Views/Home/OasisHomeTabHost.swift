//
//  OasisHomeTabHost.swift
//  Ohana
//
//  Keeps the vertical home tab transition light by mounting the real Oasis
//  shell for visible motion while deferring active work until the page is live.
//

import SwiftUI

struct OasisHomeTabHost: View {
    let lifecycle: VerticalSolidHomePageLifecycle
    let injectEnergyTrigger: Int
    var onPresentCoconutLog: ((CoconutLogSubject?) -> Void)? = nil

    @State private var showsLiveContent = false
    @State private var forwardedInjectEnergyTrigger = 0
    @State private var liveContentMountTask: Task<Void, Never>?
    @State private var injectHandoffTask: Task<Void, Never>?
    @State private var oasisFlowStartedAt: CFAbsoluteTime?
    @State private var didRecordShellReady = false
    @State private var didRecordLiveReady = false
    @State private var didRecordContentMounted = false
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.code

    private var l: L10n { L10n(appLanguage) }

    private var shouldRenderLiveContent: Bool {
        guard !lifecycle.isPreparingForDisplay else { return false }
        return showsLiveContent && lifecycle.isLive
    }

    var body: some View {
        let rendersLiveContent = shouldRenderLiveContent

        ZStack {
            OasisHomeTabPreview(
                title: l.tr(zh: "Oasis", en: "Oasis", de: "Oasis"),
                subtitle: l.tr(zh: "生命之树", en: "Life Tree", de: "Lebensbaum")
            )
            .opacity(rendersLiveContent ? 0 : 1)
            .allowsHitTesting(false)

            if rendersLiveContent {
                OasisRewardView(
                    hideToolbar: true,
                    injectEnergyTrigger: forwardedInjectEnergyTrigger,
                    isEmbeddedPrepared: lifecycle.isPrepared,
                    isEmbeddedVisible: lifecycle.isVisible,
                    isEmbeddedActive: lifecycle.isLive,
                    onPresentCoconutLog: onPresentCoconutLog
                )
                .allowsHitTesting(lifecycle.isLive)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .onAppear {
            resetFlowIfNeeded()
            updateLiveContentGate()
        }
        .onDisappear {
            liveContentMountTask?.cancel()
            liveContentMountTask = nil
            injectHandoffTask?.cancel()
            injectHandoffTask = nil
            if let oasisFlowStartedAt {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.oasisOpen,
                    AppPerformancePhases.routeDismiss,
                    startedAt: oasisFlowStartedAt
                )
            }
            oasisFlowStartedAt = nil
            didRecordShellReady = false
            didRecordLiveReady = false
            didRecordContentMounted = false
        }
        .onChange(of: lifecycle) { _, _ in
            updateLiveContentGate()
        }
        .onChange(of: injectEnergyTrigger) { _, newValue in
            handleInjectEnergyTriggerChanged(newValue)
        }
    }

    private func updateLiveContentGate() {
        if lifecycle.isPreparingForDisplay {
            liveContentMountTask?.cancel()
            liveContentMountTask = nil
            injectHandoffTask?.cancel()
            unmountLiveContent()
            injectHandoffTask = nil
            return
        }

        if lifecycle.isLive {
            let startedAt = ensureFlowStarted()
            recordShellReadyIfNeeded(startedAt: startedAt, source: "live_preview_shell")
            if !didRecordLiveReady {
                AppFlowPerformance.mark(
                    AppPerformanceFlows.oasisOpen,
                    AppPerformancePhases.firstFrame,
                    startedAt: startedAt,
                    note: ["source": "preview_shell"]
                )
                didRecordLiveReady = true
            }
            scheduleLiveContentMount(startedAt: startedAt)
            schedulePendingInjectHandoff()
        } else if lifecycle.isVisible || lifecycle.isPrepared {
            let startedAt = ensureFlowStarted()
            recordShellReadyIfNeeded(startedAt: startedAt, source: "preview_shell")
            liveContentMountTask?.cancel()
            liveContentMountTask = nil
            unmountLiveContent()
        } else {
            liveContentMountTask?.cancel()
            liveContentMountTask = nil
            injectHandoffTask?.cancel()
            unmountLiveContent()
            injectHandoffTask = nil
        }
    }

    private func resetFlowIfNeeded() {
        guard lifecycle.isPrepared || lifecycle.isVisible || lifecycle.isLive else {
            oasisFlowStartedAt = nil
            didRecordShellReady = false
            didRecordLiveReady = false
            didRecordContentMounted = false
            return
        }
    }

    private func ensureFlowStarted() -> CFAbsoluteTime {
        if let oasisFlowStartedAt {
            return oasisFlowStartedAt
        }
        let startedAt = AppFlowPerformance.start(
            AppPerformanceFlows.oasisOpen,
            note: ["source": "home_tab"]
        )
        oasisFlowStartedAt = startedAt
        return startedAt
    }

    private func recordShellReadyIfNeeded(startedAt: CFAbsoluteTime, source: String) {
        guard !didRecordShellReady else { return }
        AppFlowPerformance.mark(
            AppPerformanceFlows.oasisOpen,
            AppPerformancePhases.shellReady,
            startedAt: startedAt,
            note: [
                "prepared": lifecycle.isPrepared ? "true" : "false",
                "source": source
            ]
        )
        didRecordShellReady = true
    }

    private func scheduleLiveContentMount(startedAt: CFAbsoluteTime) {
        guard lifecycle.isLive else { return }
        guard !showsLiveContent else {
            recordContentMountedIfNeeded(startedAt: startedAt)
            return
        }
        liveContentMountTask?.cancel()
        liveContentMountTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            guard lifecycle.isLive else {
                liveContentMountTask = nil
                return
            }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showsLiveContent = true
            }
            recordContentMountedIfNeeded(startedAt: startedAt)
            liveContentMountTask = nil
            schedulePendingInjectHandoff()
        }
    }

    private func recordContentMountedIfNeeded(startedAt: CFAbsoluteTime) {
        guard !didRecordContentMounted else { return }
        AppFlowPerformance.mark(
            AppPerformanceFlows.oasisOpen,
            AppPerformancePhases.contentMounted,
            startedAt: startedAt,
            note: ["source": "home_tab_live"]
        )
        didRecordContentMounted = true
    }

    private func unmountLiveContent() {
        guard showsLiveContent else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showsLiveContent = false
        }
        didRecordContentMounted = false
    }

    private func handleInjectEnergyTriggerChanged(_ newValue: Int) {
        guard lifecycle.isLive else { return }
        if shouldRenderLiveContent {
            forwardedInjectEnergyTrigger = newValue
        } else {
            schedulePendingInjectHandoff()
        }
    }

    private func schedulePendingInjectHandoff() {
        guard lifecycle.isLive,
              shouldRenderLiveContent,
              forwardedInjectEnergyTrigger != injectEnergyTrigger else { return }
        injectHandoffTask?.cancel()
        injectHandoffTask = OhanaFrameScheduler.runAfterNextFrame(milliseconds: 24) {
            guard lifecycle.isLive, shouldRenderLiveContent else {
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
                    BeautifulCoconutTree(
                        level: treeLevel.rawValue,
                        isInjecting: false,
                        growthProgress: progress,
                        allowsAmbientMotion: false,
                        harvestedCoconuts: []
                    )
                    .scaleEffect(0.72)
                    .frame(width: 230, height: 246)
                    .allowsHitTesting(false)
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
                        Image(systemName: "bolt.fill") // a11y: allow decorative progress icon paired with numeric text
                            .font(OhanaFont.footnote(.black))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.goPrimary)
                            .accessibilityHidden(true)
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
                .font(OhanaFont.title3(.black))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.goPrimary)
                .frame(width: 32, height: 32) // a11y: allow decorative preview icon frame
                .background(Color.ohanaControlFill, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.22))
                    .frame(width: 58, height: 7) // a11y: allow decorative skeleton bar
                Capsule()
                    .fill(Color.ohanaSecondaryText.opacity(0.14))
                    .frame(width: 38, height: 6) // a11y: allow decorative skeleton bar
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(minHeight: 64)
        .background(Color.ohanaCardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

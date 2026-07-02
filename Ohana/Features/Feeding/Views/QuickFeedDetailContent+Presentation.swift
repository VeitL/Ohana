//
//  QuickFeedDetailContent+Presentation.swift
//  Ohana
//
//  Presentation chrome and inline overlay routing for QuickFeedDetailContent.
//

import SwiftUI
import UIKit

extension QuickFeedDetailContent {
    var activeAlert: QuickFeedAlertRoute? {
        get { presentationState.activeAlert }
        nonmutating set { presentationState.activeAlert = newValue }
    }

    var activeAlertBinding: Binding<QuickFeedAlertRoute?> {
        Binding(
            get: { presentationState.activeAlert },
            set: { presentationState.activeAlert = $0 }
        )
    }

    var pendingRepeatAction: (() -> Void)? {
        get { presentationState.pendingRepeatAction }
        nonmutating set { presentationState.pendingRepeatAction = newValue }
    }

    var pendingRepeatActionBinding: Binding<(() -> Void)?> {
        Binding(
            get: { presentationState.pendingRepeatAction },
            set: { presentationState.pendingRepeatAction = $0 }
        )
    }

    var activeOverlay: QuickFeedOverlayRoute? {
        get { presentationState.activeOverlay }
        nonmutating set { presentationState.activeOverlay = newValue }
    }

    var toastTask: Task<Void, Never>? {
        get { presentationState.toastTask }
        nonmutating set { presentationState.toastTask = newValue }
    }

    var feedFeedbackToken: CheckInFeedbackToken? {
        get { presentationState.feedFeedbackToken }
        nonmutating set { presentationState.feedFeedbackToken = newValue }
    }

    var feedFeedbackMetricId: String? {
        get { presentationState.feedFeedbackMetricId }
        nonmutating set { presentationState.feedFeedbackMetricId = newValue }
    }

    var stockFeedbackToken: CheckInFeedbackToken? {
        get { presentationState.stockFeedbackToken }
        nonmutating set { presentationState.stockFeedbackToken = newValue }
    }

    var stockFeedbackKind: FeedFoodKind? {
        get { presentationState.stockFeedbackKind }
        nonmutating set { presentationState.stockFeedbackKind = newValue }
    }

    var treatFeedbackToken: CheckInFeedbackToken? {
        get { presentationState.treatFeedbackToken }
        nonmutating set { presentationState.treatFeedbackToken = newValue }
    }

    var activeEmbeddedPanel: ActiveFeedEmbeddedPanel? {
        get { presentationState.activeEmbeddedPanel }
        nonmutating set { presentationState.activeEmbeddedPanel = newValue }
    }

    var feedbackClearTask: Task<Void, Never>? {
        get { presentationState.feedbackClearTask }
        nonmutating set { presentationState.feedbackClearTask = newValue }
    }

    func systemFeedSheetContent(_ sheet: ActiveFeedSheet) -> some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                VStack(spacing: 0) {
                    feedSheetTopChrome(sheet)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    sheetContent(sheet)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .petMemorialTone(isActive: pet.hasPassedAway)
                        .allowsHitTesting(nestedInlineSheet == nil && !inlineSheetDismissGestureShield)
                }

                if let nestedInlineSheet {
                    inlineFeedSheetOverlay(nestedInlineSheet)
                        .zIndex(40)
                        .ignoresSafeArea(.container, edges: .bottom)
                }

                if inlineSheetDismissGestureShield, nestedInlineSheet == nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global))
                        .zIndex(39)
                        .ignoresSafeArea()
                }
            }
            .feedSheetScrollChrome()
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(l.tr(zh: "完成", en: "Done", de: "Fertig")) {
                        dismissFeedKeyboard()
                    }
                    .font(OhanaFont.adaptive(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.goPrimary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
        .presentationDetents(sheet.detents(measuredHeight: adaptiveSheetHeight))
        .presentationDragIndicator(.hidden)
        .presentationBackground {
            FeedNativeSheetGlassSurface(
                cornerRadius: OhanaRadius.sheetMini,
                glassMode: .regular
            )
            .ignoresSafeArea() // ui-v4: sheet glass belongs to presentation background, not content background
        }
        .presentationCornerRadius(OhanaRadius.sheetMini)
        .presentationContentInteraction(.scrolls)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    func inlineFeedSheetOverlay(_ sheet: ActiveFeedSheet) -> some View {
        GeometryReader { proxy in
            let bottomInset = inlineKeyboardHeight > 0 ? inlineKeyboardHeight + 8 : CGFloat(8)
            let maxHeight = min(sheet.inlineOverlayMaxHeight, proxy.size.height * (inlineKeyboardHeight > 0 ? 0.68 : 0.94))
            let measuredHeight = max(260, adaptiveSheetHeight - sheet.inlineOverlayChromeReduction)
            let panelHeight = min(max(sheet.inlineOverlayMinHeight, measuredHeight), maxHeight)
            let horizontalInset = CGFloat(6)
            let panelWidth = max(0, proxy.size.width - horizontalInset * 2)
            let cornerRadius = CGFloat(52)
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let hiddenOffset = panelHeight + bottomInset + 64

            OhanaMotionScene(role: .sheet, alignment: .bottom, isActive: inlineSheetVisible) {
                inlineSheetBackdrop
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isInlineInputActive {
                            dismissFeedKeyboard()
                        } else {
                            dismissInlineFeedSheet()
                        }
                    }

                ZStack(alignment: .top) {
                    sheetContent(sheet)
                        .frame(maxWidth: .infinity)
                        .frame(height: panelHeight)
                        .clipShape(shape)

                    OhanaPopupDragHandle(tint: Color.ohanaPrimaryText.opacity(0.24))
                        .gesture(inlineSheetDragGesture)
                        .zIndex(3)

                    HStack {
                        Spacer()
                        OhanaPopupCloseButton(tint: Color.ohanaPrimaryText) {
                            dismissInlineFeedSheet()
                        }
                        .padding(.top, inlineSheetCloseTopPadding(for: sheet))
                        .padding(.trailing, 8)
                    }
                    .zIndex(2)
                }
                .background {
                    FeedInlineSheetGlassSurface(
                        cornerRadius: cornerRadius,
                        glassMode: .regular
                    )
                }
                .clipShape(shape)
                .frame(width: panelWidth)
                .shadow( // ui-v4: allow alert-style inline sheet lift shadow
                    color: Color.black.opacity(inlineSheetVisible ? 0.56 : 0), // ui-v4: allow alert-style inline sheet lift shadow
                    radius: 48,
                    x: 0,
                    y: -18
                )
                .shadow( // ui-v4: allow soft grounding shadow behind glass sheet
                    color: Color(hex: "0B102C").opacity(inlineSheetVisible ? 0.46 : 0), // ui-v4: allow soft grounding shadow behind glass sheet
                    radius: 28,
                    x: 0,
                    y: 12
                )
                .offset(y: inlineSheetVisible ? inlineSheetDragOffset : hiddenOffset)
                .opacity(inlineSheetVisible ? 1 : 0.94)
                .scaleEffect(inlineSheetVisible ? 1 : 0.982, anchor: .bottom)
                .padding(.bottom, bottomInset)
                .animation(GoMotion.feedback, value: inlineSheetDragOffset)
                .animation(GoMotion.page, value: inlineSheetVisible)
            }
            .onAppear {
                sheetCoordinator.prepareInlinePresentation()
                DispatchQueue.main.async {
                    sheetCoordinator.showInlinePresentation()
                }
            }
        }
    }

    func inlineSheetCloseTopPadding(for sheet: ActiveFeedSheet) -> CGFloat {
        switch sheet {
        case .plan:
            22
        default:
            10
        }
    }

    var inlineSheetScrollTopMarker: some View {
        Color.clear
            .frame(height: 0)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: FeedInlineSheetScrollTopPreferenceKey.self,
                        value: proxy.frame(in: .named(FeedInlineSheetScrollCoordinateSpace.name)).minY
                    )
                }
            }
    }

    var inlineSheetTopPullDismissGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onEnded { value in
                let vertical = value.translation.height
                let horizontal = abs(value.translation.width)
                guard inlineSheetScrollTopOffset >= -3,
                      vertical > 86,
                      vertical > horizontal * 1.18
                else { return }

                if isInlineInputActive {
                    dismissFeedKeyboard()
                } else if inlineSheetTopPullDismissArmed {
                    dismissInlineFeedSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetTopPullDismissArmed = true
                    }
                }
            }
    }

    var inlineSheetBackdrop: some View {
        ZStack {
            Color.black.opacity(inlineSheetVisible ? 0.16 : 0) // ui-v4: allow modal scrim behind inline glass sheet
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(inlineSheetVisible ? 0.26 : 0) // ui-v4: allow modal grounding shade behind bottom glass sheet
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(GoMotion.page, value: inlineSheetVisible)
    }

    var inlineSheetDragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                inlineSheetDragOffset = min(140, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 72 || value.predictedEndTranslation.height > 130 {
                    dismissInlineFeedSheet()
                } else {
                    withAnimation(GoMotion.feedback) {
                        inlineSheetDragOffset = 0
                    }
                }
            }
    }

    func updateInlineKeyboardHeight(_ notification: Notification) {
        guard activeInlineSheet != nil else { return }
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let height = max(0, frame.height)
        guard abs(inlineKeyboardHeight - height) > 0.5 else { return }
        inlineKeyboardHeight = height
    }
}

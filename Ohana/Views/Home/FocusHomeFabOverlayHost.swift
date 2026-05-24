//
//  FocusHomeFabOverlayHost.swift
//  Ohana
//
//  Isolated FAB menu animation and rendering for the GO Focus home screen.
//

import SwiftUI

struct FocusHomeFabOverlayHost: View {
    var isVisible: Bool
    var activeCard: FocusCard?
    var bottomPadding: CGFloat
    var homeShortcuts: [HomeFabFunctionShortcut]
    var expandedShortcuts: [ExpandedCardFabShortcut]
    @Binding var isExpanded: Bool
    @Binding var itemsVisible: Bool
    var onHomeShortcut: (HomeFabFunctionShortcut) -> Void
    var onExpandedShortcut: (ExpandedCardFabShortcut, FocusCard) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isVisible {
                if isExpanded {
                    Color.black.opacity(0.25) // ui-v4: allow home FAB modal scrim backdrop
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { closeMenu() }
                        .transition(.opacity)
                }

                HomeFabMenuView(
                    activeCard: activeCard,
                    isExpanded: isExpanded,
                    itemsVisible: itemsVisible,
                    bottomPadding: bottomPadding,
                    homeShortcuts: homeShortcuts,
                    expandedShortcuts: expandedShortcuts,
                    onToggle: {
                        OhanaFeedback.medium()
                        toggleMenu()
                    },
                    onHomeShortcut: { item in
                        guard item.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        let startedAt = CFAbsoluteTimeGetCurrent()
                        OhanaFeedback.light()
                        closeMenuForNavigation()
                        onHomeShortcut(item)
                        AppPerformanceMonitor.shared.record(
                            "home.fabRouteSubmitted",
                            startedAt: startedAt,
                            note: item.label
                        )
                    },
                    onExpandedShortcut: { item in
                        guard let activeCard else { return }
                        guard item.isAvailable else {
                            OhanaFeedback.light()
                            return
                        }
                        let startedAt = CFAbsoluteTimeGetCurrent()
                        OhanaFeedback.light()
                        closeMenuForNavigation()
                        onExpandedShortcut(item, activeCard)
                        AppPerformanceMonitor.shared.record(
                            "home.expandedFabRouteSubmitted",
                            startedAt: startedAt,
                            note: item.label
                        )
                    }
                )
                .zIndex(999)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .animation(HeroAnim.fabSpring, value: isExpanded)
        .animation(HeroAnim.fabSpring, value: itemsVisible)
    }

    private func openMenu() {
        guard !isExpanded else { return }
        itemsVisible = false
        withAnimation(HeroAnim.fabSpring) {
            isExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(HeroAnim.fabSpring) {
                itemsVisible = true
            }
        }
    }

    private func closeMenu() {
        guard isExpanded else { return }
        withAnimation(HeroAnim.fabSpring) {
            itemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if isExpanded && !itemsVisible {
                withAnimation(HeroAnim.fabSpring) {
                    isExpanded = false
                }
            }
        }
    }

    private func closeMenuForNavigation() {
        guard isExpanded || itemsVisible else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            itemsVisible = false
            isExpanded = false
        }
    }

    private func toggleMenu() {
        isExpanded ? closeMenu() : openMenu()
    }
}

struct FocusHomeExpandedCardFabHost: View {
    var items: [ExpandedCardFabShortcut]
    @Binding var isExpanded: Bool
    @Binding var itemsVisible: Bool
    var onShortcut: (ExpandedCardFabShortcut) -> Void

    var body: some View {
        OhanaMotionScene(role: .menu, alignment: .bottomTrailing, isActive: isExpanded) {
            ExpandedCardFabMenuView(
                items: items,
                isExpanded: isExpanded,
                itemsVisible: itemsVisible,
                onToggle: {
                    OhanaFeedback.medium()
                    toggleMenu()
                },
                onShortcut: { item in
                    guard item.isAvailable else {
                        OhanaFeedback.light()
                        return
                    }
                    OhanaFeedback.light()
                    closeMenu()
                    onShortcut(item)
                }
            )
        }
    }

    private func openMenu() {
        guard !isExpanded else { return }
        itemsVisible = false
        withAnimation(HeroAnim.fabSpring) {
            isExpanded = true
        }
        DispatchQueue.main.async {
            withAnimation(HeroAnim.fabSpring) {
                itemsVisible = true
            }
        }
    }

    private func closeMenu() {
        guard isExpanded else { return }
        withAnimation(HeroAnim.fabSpring) {
            itemsVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if isExpanded && !itemsVisible {
                withAnimation(HeroAnim.fabSpring) {
                    isExpanded = false
                }
            }
        }
    }

    private func toggleMenu() {
        isExpanded ? closeMenu() : openMenu()
    }
}

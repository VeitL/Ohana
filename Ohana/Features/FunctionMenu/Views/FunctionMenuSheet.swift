// FunctionMenuSheet.swift
// GO Focus UI — 首页 FAB 功能菜单承载层。

import SwiftUI

struct FunctionMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppServices.self) private var appServices
    @AppStorage("appLanguage") private var appLanguage = "zh"

    let initialDestination: FMDest?

    @State private var path = NavigationPath()
    @State private var didOpenInitialDestination = false
    @State private var directLandingIsReady = false

    init(initialDestination: FMDest? = nil) {
        self.initialDestination = initialDestination
    }

    /// FAB 直达这些目的地时跳过根列表，避免先显示菜单再 push 的视觉跳动。
    /// 带实体 id 的目的地继续通过 `path.append` 进入，保留系统返回链路。
    private var directLandingDestination: FMDest? {
        guard let dest = initialRoutedDestination else { return nil }
        switch dest {
        case .featureGroup,
             .featureAggregate,
             .growthRoadmap,
             .calendar,
             .familyWeeklyReport,
             .careLedgerAnalysis,
             .reminderObservability,
             .coconutShop,
             .gacha,
             .wealthDashboard:
            return dest
        default:
            return nil
        }
    }

    private var initialRoutedDestination: FMDest? {
        AppFeatureRouteGuard.visibleFunctionDestination(
            initialDestination,
            currentLevel: appServices.oasisTree.treeLevel.rawValue
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            if let landing = directLandingDestination {
                directLandingShell(landing)
                    .navigationDestination(for: FMDest.self) { dest in
                        navigationDestinationView(dest)
                    }
            } else {
                FunctionMenuRootRouteContainer(
                    appLanguage: appLanguage,
                    onSelect: { path.append($0) },
                    onClose: { dismiss() }
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: FMDest.self) { dest in
                    navigationDestinationView(dest)
                }
            }
        }
        .onAppear(perform: openInitialDestinationIfNeeded)
    }

    private func directLandingShell(_ landing: FMDest) -> some View {
        ZStack {
            if directLandingIsReady {
                directLandingHost(landing) {
                    dismiss()
                }
                .transition(.opacity)
            } else {
                directLandingPlaceholder(landing) {
                    dismiss()
                }
                .transition(.opacity)
            }
        }
        .task(id: landing) {
            await MainActor.run {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    directLandingIsReady = false
                }
            }
            await OhanaFrameScheduler.waitAfterNextFrame()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(GoMotion.quick) {
                    directLandingIsReady = true
                }
            }
        }
    }

    private func openInitialDestinationIfNeeded() {
        guard directLandingDestination == nil else { return }
        guard !didOpenInitialDestination, let initialDestination = initialRoutedDestination else { return }
        didOpenInitialDestination = true
        DispatchQueue.main.async {
            path.append(initialDestination)
        }
    }

    @ViewBuilder
    private func directLandingHost(_ landing: FMDest, closeAction: @escaping () -> Void) -> some View {
        OhanaMotionScene(role: .hero, alignment: .topTrailing, isActive: true) {
            destinationRouter(landing)

            if directLandingNeedsHostClose(landing) {
                pageCloseButton(action: closeAction)
                    .padding(.top, 12)
                    .padding(.trailing, 16)
                    .zIndex(100)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func directLandingPlaceholder(_ landing: FMDest, closeAction: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            OhanaAppBackground()
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Image(systemName: destinationChrome(for: landing).icon)
                    .font(OhanaFont.adaptive(size: 26, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.goPrimary)
                    .frame(width: 58, height: 58)
                    .background(Color.ohanaCardSurface, in: Circle())

                Text(destinationChrome(for: landing).title)
                    .font(OhanaFont.title3(.black))
                    .foregroundStyle(Color.ohanaPrimaryText)

                ProgressView()
                    .tint(Color.goPrimary)
                    .scaleEffect(0.88)
                    .padding(.top, 2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            pageCloseButton(action: closeAction)
                .padding(.top, 12)
                .padding(.trailing, 16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func navigationDestinationView(_ destination: FMDest) -> some View {
        if directLandingNeedsHostClose(destination) {
            directLandingHost(destination) {
                closePushedDestination()
            }
        } else {
            destinationRouter(destination)
        }
    }

    @ViewBuilder
    private func destinationRouter(_ destination: FMDest) -> some View {
        FunctionMenuDestinationRouteContainer(
            destination: destination,
            parentPath: $path
        )
    }

    private func directLandingNeedsHostClose(_ dest: FMDest) -> Bool {
        switch dest {
        case .featureGroup,
             .featureAggregate,
             .growthRoadmap,
             .calendar,
             .familyWeeklyReport,
             .careLedgerAnalysis,
             .reminderObservability,
             .bountyBoard:
            true
        default:
            false
        }
    }

    private func closePushedDestination() {
        if path.isEmpty {
            dismiss()
        } else {
            path.removeLast()
        }
    }

    private func pageCloseButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark") // a11y: allow decorative icon covered by surrounding text or control
                .font(OhanaFont.adaptive(size: 15, weight: .black)) // a11y: allow legacy fixed-size visual token; tracked for dynamic type cleanup
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n(appLanguage).tr(zh: "关闭", en: "Close", de: "Schließen"))
    }

    private func destinationChrome(for destination: FMDest) -> (title: String, icon: String) {
        switch destination {
        case let .featureGroup(group):
            (group.title, group.icon)
        case let .featureAggregate(feature):
            (feature.title, feature.icon)
        case .calendar:
            (L10n(appLanguage).tr(zh: "日历", en: "Calendar", de: "Kalender"), "calendar")
        case .familyWeeklyReport:
            (L10n(appLanguage).tr(zh: "家庭周报", en: "Weekly Report", de: "Wochenbericht"), "chart.bar.xaxis")
        case .careLedgerAnalysis:
            (L10n(appLanguage).tr(zh: "照护账本", en: "Care Ledger", de: "Pflegebuch"), "list.bullet.rectangle.fill")
        case .reminderObservability:
            (L10n(appLanguage).tr(zh: "提醒观测", en: "Reminder Monitor", de: "Erinnerungen"), "bell.badge.fill")
        case .coconutShop:
            (L10n(appLanguage).tr(zh: "椰子商店", en: "Coconut Shop", de: "Kokos-Shop"), "bag.fill")
        case .gacha:
            (L10n(appLanguage).tr(zh: "扭蛋机", en: "Gacha", de: "Gacha"), "circle.grid.cross.fill")
        case .wealthDashboard:
            (L10n(appLanguage).tr(zh: "Ohana 财富", en: "Ohana Wealth", de: "Ohana Vermögen"), "chart.pie.fill")
        case .growthRoadmap:
            (L10n(appLanguage).tr(zh: "椰子树路线", en: "Tree Roadmap", de: "Baum-Roadmap"), "tree.fill")
        case .plantsDashboard:
            (L10n(appLanguage).tr(zh: "植物总览", en: "Plant Overview", de: "Pflanzenübersicht"), "leaf.fill")
        case .plantsList:
            (L10n(appLanguage).tr(zh: "植物列表", en: "Plant List", de: "Pflanzenliste"), "list.bullet.rectangle.fill")
        case .plantsPhotos:
            (L10n(appLanguage).tr(zh: "成长照片", en: "Growth Photos", de: "Wachstumsfotos"), "photo.stack.fill")
        default:
            (L10n(appLanguage).tr(zh: "详情", en: "Details", de: "Details"), "square.grid.2x2.fill")
        }
    }
}

// FunctionMenuSheet.swift
// GO Focus UI — 首页 FAB 功能菜单承载层。

import SwiftUI

struct FunctionMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage = "zh"

    let initialDestination: FMDest?

    @State private var path = NavigationPath()
    @State private var didOpenInitialDestination = false
    @State private var plantRouteStub: Plant?

    init(initialDestination: FMDest? = nil) {
        self.initialDestination = initialDestination
    }

    /// FAB 直达这些目的地时跳过根列表，避免先显示菜单再 push 的视觉跳动。
    /// 带实体 id 的目的地继续通过 `path.append` 进入，保留系统返回链路。
    private var directLandingDestination: FMDest? {
        guard let dest = initialDestination else { return nil }
        switch dest {
        case .featureGroup,
             .featureAggregate,
             .calendar,
             .familyWeeklyReport,
             .careLedgerAnalysis,
             .reminderObservability,
             .coconutShop,
             .gacha,
             .wealthDashboard,
             .plantsDashboard:
            return dest
        default:
            return nil
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            if let landing = directLandingDestination {
                directLandingHost(landing) {
                    dismiss()
                }
                    .navigationDestination(for: FMDest.self) { dest in
                        navigationDestinationView(dest)
                    }
            } else {
                FunctionMenuRootView(
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

    private func openInitialDestinationIfNeeded() {
        guard directLandingDestination == nil else { return }
        guard !didOpenInitialDestination, let initialDestination else { return }
        didOpenInitialDestination = true
        DispatchQueue.main.async {
            path.append(initialDestination)
        }
    }

    @ViewBuilder
    private func directLandingHost(_ landing: FMDest, closeAction: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
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
        FunctionMenuDestinationRouter(
            destination: destination,
            parentPath: $path,
            selectedPlant: $plantRouteStub
        )
    }

    private func directLandingNeedsHostClose(_ dest: FMDest) -> Bool {
        switch dest {
        case .featureGroup,
             .featureAggregate,
             .calendar,
             .familyWeeklyReport,
             .careLedgerAnalysis,
             .reminderObservability,
             .plantsDashboard,
             .bountyBoard:
            return true
        default:
            return false
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
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.ohanaPrimaryText)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(L10n(appLanguage).tr(zh: "关闭", en: "Close", de: "Schließen"))
    }
}

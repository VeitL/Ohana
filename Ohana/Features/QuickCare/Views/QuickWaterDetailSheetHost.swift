//
//  QuickWaterDetailSheetHost.swift
//  Ohana
//
//  Screen-scoped data host for the quick water detail sheet.
//

import SwiftData
import SwiftUI

struct QuickWaterDetailSheetHost: View {
    @Environment(\.modelContext) private var modelContext
    @State private var refreshToken = 0
    let id: UUID
    let onRemove: () -> Void
    let onClose: (() -> Void)?

    init(
        id: UUID,
        onRemove: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.id = id
        self.onRemove = onRemove
        self.onClose = onClose
    }

    var body: some View {
        RouteFirstFrameDeferredLoad(
            initialData: QuickWaterRouteData(),
            refreshToken: refreshToken,
            loadDelayMilliseconds: 0,
            reloadDelayMilliseconds: 0,
            shouldLoad: { !$0.hasLoaded },
            load: { QuickWaterRouteData.load(id: id, from: modelContext) }
        ) { routeData in
            if let pet = routeData.pet {
                QuickWaterDetailSheet(
                    pet: pet,
                    onRemove: onRemove,
                    onClose: onClose,
                    allEvents: routeData.allEvents,
                    allPets: routeData.allPets,
                    waterEntries: routeData.waterEntries,
                    onRecordChanged: {
                        refreshToken += 1
                    }
                )
            } else if routeData.hasLoaded {
                QuickCareMissingRouteEntityView(kind: "pet")
                    .onAppear(perform: onRemove)
            } else {
                QuickWaterRouteLoadingShell()
            }
        }
    }
}

private struct QuickWaterRouteLoadingShell: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(L10n.current.tr(zh: "正在准备浇水页", en: "Preparing water"))
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}

//
//  WalkRouteContainer.swift
//  Ohana
//
//  Route-scoped SwiftData fetches for walk surfaces.
//

import SwiftData
import SwiftUI

struct AppWalkRouteContainer: View {
    @Query private var pets: [Pet]
    let onDismiss: () -> Void

    init(id: UUID, onDismiss: @escaping () -> Void) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.onDismiss = onDismiss
    }

    var body: some View {
        if let pet = pets.first {
            WalkTrackingFullScreen(
                pet: pet,
                onMinimize: onDismiss
            )
        } else {
            WalkRouteMissingEntityView(kind: "pet")
                .onAppear(perform: onDismiss)
        }
    }
}

private struct WalkRouteMissingEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
                .font(OhanaFont.title(.bold))
                .foregroundStyle(Color.goPrimary)
                .accessibilityHidden(true)
            Text("内容已不可用")
                .font(OhanaFont.title3(.black))
                .foregroundStyle(Color.ohanaPrimaryText)
            Text(kind)
                .font(OhanaFont.caption(.semibold))
                .foregroundStyle(Color.ohanaSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OhanaAppBackground().ignoresSafeArea())
    }
}

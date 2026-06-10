import SwiftData
import SwiftUI

struct AppQuickMomentOverlayRouteContainer: View {
    @Query private var pets: [Pet]
    let onSaved: (Pet) -> Void
    let onDismiss: () -> Void

    init(
        id: UUID,
        onSaved: @escaping (Pet) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _pets = Query(filter: #Predicate<Pet> { pet in
            pet.id == id
        })
        self.onSaved = onSaved
        self.onDismiss = onDismiss
    }

    var body: some View {
        if let pet = pets.first {
            QuickMomentSheet(
                pet: pet,
                onRemove: nil,
                onSaved: {
                    onSaved(pet)
                },
                onClose: onDismiss
            )
        } else {
            QuickMomentMissingRouteEntityView(kind: "pet")
                .onAppear(perform: onDismiss)
        }
    }
}

private struct QuickMomentMissingRouteEntityView: View {
    let kind: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.magnifyingglass") // a11y: decorative icon; surrounding text carries the message. // a11y: allow decorative/status glyph; surrounding text or control label carries meaning
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

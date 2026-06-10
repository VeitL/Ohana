import SwiftData
import SwiftUI

struct OasisCritterCodexRouteContainer: View {
    let mode: OasisCritterViewMode
    let initialCatalogId: String?
    let isPopup: Bool
    let onClose: (() -> Void)?
    let onPresentCoconutLog: (CoconutLogSubject?) -> Void

    @Query(sort: \Human.createdAt) private var humans: [Human]
    @Query(sort: \OasisElectronicPet.obtainedAt) private var electronicPets: [OasisElectronicPet]
    @Query(sort: \OasisCritterFragmentBalance.updatedAt) private var fragments: [OasisCritterFragmentBalance]

    init(
        mode: OasisCritterViewMode = .codex,
        initialCatalogId: String? = nil,
        isPopup: Bool = false,
        onClose: (() -> Void)? = nil,
        onPresentCoconutLog: @escaping (CoconutLogSubject?) -> Void = { _ in }
    ) {
        self.mode = mode
        self.initialCatalogId = initialCatalogId
        self.isPopup = isPopup
        self.onClose = onClose
        self.onPresentCoconutLog = onPresentCoconutLog
    }

    var body: some View {
        OasisCritterCodexView(
            mode: mode,
            initialCatalogId: initialCatalogId,
            isPopup: isPopup,
            onClose: onClose,
            humans: humans,
            electronicPets: electronicPets,
            fragments: fragments,
            onPresentCoconutLog: onPresentCoconutLog
        )
    }
}

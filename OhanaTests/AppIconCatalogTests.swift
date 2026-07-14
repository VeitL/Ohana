import Testing
import UIKit
@testable import Ohana

struct AppIconCatalogTests {
    @Test("App icon descriptors keep stable unique identities")
    func descriptorsAreStableAndUnique() {
        let descriptors = AppIconCatalog.icons

        #expect(descriptors.first?.itemId == AppIconCatalog.defaultItemId)
        #expect(descriptors.first?.alternateIconName == nil)
        #expect(Set(descriptors.map(\.itemId)).count == descriptors.count)
        #expect(Set(descriptors.compactMap(\.alternateIconName)).count == descriptors.count - 1)
        #expect(descriptors.dropFirst().allSatisfy { !$0.assetName.isEmpty })
    }

    @Test("System icon names resolve back to their catalog descriptor")
    func systemNamesRoundTrip() {
        for descriptor in AppIconCatalog.icons {
            #expect(
                AppIconCatalog.descriptor(forAlternateIconName: descriptor.alternateIconName) == descriptor
            )
        }
    }

    @Test("Every catalog descriptor has runtime preview artwork")
    func runtimePreviewArtworkExists() {
        for descriptor in AppIconCatalog.icons {
            #expect(UIImage(named: descriptor.assetName) != nil)
        }
    }

    @Test("Unknown system icon names safely fall back to the default")
    func unknownNameFallsBackToDefault() {
        #expect(
            AppIconCatalog.descriptor(forAlternateIconName: "UnknownIcon").itemId
                == AppIconCatalog.defaultItemId
        )
    }
}

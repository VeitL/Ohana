import Testing
@testable import Ohana

struct PlantCreationCatalogImageLoaderTests {
    @Test func emptyCatalogAssetNamesAreRejectedBeforeUIKitLookup() {
        #expect(PlantCreationCatalogImageLoader.normalizedAssetName(nil) == nil)
        #expect(PlantCreationCatalogImageLoader.normalizedAssetName("") == nil)
        #expect(PlantCreationCatalogImageLoader.normalizedAssetName("   \n") == nil)
        #expect(PlantCreationCatalogImageLoader.image(named: nil) == nil)
        #expect(PlantCreationCatalogImageLoader.image(named: "") == nil)
    }

    @Test func validCatalogAssetNamesAreTrimmed() {
        #expect(
            PlantCreationCatalogImageLoader.normalizedAssetName("  plant_catalog_foliage  ")
                == "plant_catalog_foliage"
        )
    }
}

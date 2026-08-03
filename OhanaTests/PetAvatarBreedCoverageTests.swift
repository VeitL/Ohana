import Foundation
import Testing
@testable import Ohana

struct PetAvatarBreedCoverageTests {
    @Test func everyBundledBreedAvatarHasAPickerBreed() throws {
        for species in ["cat", "dog"] {
            let assetSlugs = try bundledBreedSlugs(species: species)
            let pickerSlugs = Set(
                PetBreedDatabase.breeds(for: species)
                    .filter { $0.name != "其他" }
                    .compactMap {
                        PetAvatarAssetCatalog.avatarFilename(
                            species: species,
                            breed: $0.name,
                            gender: "boy",
                            coatColor: ""
                        )
                    }
                    .compactMap { breedSlug(filename: $0, species: species) }
            )

            #expect(!assetSlugs.isEmpty)
            #expect(assetSlugs.isSubset(of: pickerSlugs))
        }
    }

    @Test func avatarBackedPickerBreedsHaveLocalizedGermanNames() {
        let de = L10n("de")
        for species in ["cat", "dog"] {
            for breed in PetBreedDatabase.breeds(for: species) where breed.name != "其他" {
                #expect(
                    de.resourceName(breed.name) != breed.name,
                    "German breed name is missing: \(breed.name)"
                )
            }
        }
    }

    private func bundledBreedSlugs(species: String) throws -> Set<String> {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let directory = root.appendingPathComponent("Resources/Avatars/PetAvatarAssets")
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return Set(files.compactMap {
            breedSlug(filename: $0.lastPathComponent, species: species)
        })
    }

    private func breedSlug(filename: String, species: String) -> String? {
        let prefix = "\(species)_"
        guard filename.hasPrefix(prefix),
              !filename.hasPrefix("\(species)_boy_standard"),
              !filename.hasPrefix("\(species)_girl_standard"),
              let genderRange = filename.range(of: "_boy_")
                ?? filename.range(of: "_girl_")
        else { return nil }
        let breedStart = filename.index(filename.startIndex, offsetBy: prefix.count)
        return String(filename[breedStart ..< genderRange.lowerBound])
    }
}

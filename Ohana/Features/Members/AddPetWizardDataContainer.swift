import SwiftData
import SwiftUI
import UIKit

struct AddPetWizardView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)? = nil
    var onPetSaved: ((Pet) -> Void)? = nil

    var body: some View {
        AddPetWizardContentView(
            onComplete: onComplete,
            onCancel: onCancel,
            onPetSaved: onPetSaved
        )
    }

    nonisolated static func downsample(_ image: UIImage, maxDim: CGFloat) -> UIImage {
        AddPetWizardContentView.downsample(image, maxDim: maxDim)
    }

    nonisolated static func cropReadyImage(from data: Data, maxPixel: CGFloat = 1600) -> UIImage? {
        AddPetWizardContentView.cropReadyImage(from: data, maxPixel: maxPixel)
    }

    nonisolated static func preparedCropImage(_ image: UIImage, maxPixel: CGFloat = 1600) -> UIImage {
        AddPetWizardContentView.preparedCropImage(image, maxPixel: maxPixel)
    }
}

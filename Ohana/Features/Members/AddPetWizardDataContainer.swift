import SwiftData
import SwiftUI
import UIKit

struct AddPetWizardView: View {
    let onComplete: () -> Void
    var onCancel: (() -> Void)?
    var onPetSaved: ((Pet) -> Void)?
    var presentationStyle: MemberCreationPresentationStyle = .standard
    var onHomeJoinHandoffPreflight: (() -> Void)?
    var onHomeJoinHandoffStarted: (() -> Void)?
    var onHomeJoinHandoffEnded: (() -> Void)?

    var body: some View {
        AddPetWizardContentView(
            onComplete: onComplete,
            onCancel: onCancel,
            onPetSaved: onPetSaved,
            presentationStyle: presentationStyle,
            onHomeJoinHandoffPreflight: onHomeJoinHandoffPreflight,
            onHomeJoinHandoffStarted: onHomeJoinHandoffStarted,
            onHomeJoinHandoffEnded: onHomeJoinHandoffEnded
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

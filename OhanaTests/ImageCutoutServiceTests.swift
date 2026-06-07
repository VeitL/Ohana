import Testing
@testable import Ohana
import UIKit

struct ImageCutoutServiceTests {
    @Test func oneTransparentPixelDoesNotMakePhotoAPopout() {
        let image = imageWithTransparentDot()

        #expect(!ImageCutoutService.imageHasTransparentPixels(image))
    }

    @Test func roundedPhotoCornersStillRenderAsPhoto() {
        let image = circularPhotoLikeImage()

        #expect(!ImageCutoutService.imageHasTransparentPixels(image))
    }

    @Test func transparentBackdropWithInsetSubjectRendersAsPopout() {
        let image = transparentBackdropWithSubject()

        #expect(ImageCutoutService.imageHasTransparentPixels(image))
    }

    private func imageWithTransparentDot() -> UIImage {
        render(size: CGSize(width: 160, height: 160)) { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 160, height: 160))
            context.clear(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func circularPhotoLikeImage() -> UIImage {
        render(size: CGSize(width: 160, height: 160)) { context in
            context.clear(CGRect(x: 0, y: 0, width: 160, height: 160))
            UIColor.systemGreen.setFill()
            context.fillEllipse(in: CGRect(x: 0, y: 0, width: 160, height: 160))
        }
    }

    private func transparentBackdropWithSubject() -> UIImage {
        render(size: CGSize(width: 160, height: 160)) { context in
            context.clear(CGRect(x: 0, y: 0, width: 160, height: 160))
            UIColor.systemOrange.setFill()
            context.fillEllipse(in: CGRect(x: 48, y: 18, width: 64, height: 124))
        }
    }

    private func render(size: CGSize, draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext)
        }
    }
}

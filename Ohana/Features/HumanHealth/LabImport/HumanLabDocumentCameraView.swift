//
//  HumanLabDocumentCameraView.swift
//  Ohana
//
//  Full-screen bridge to Apple's document camera. Captured pages remain volatile.
//

import Foundation
import ImageIO
import SwiftUI
import UIKit
import VisionKit

nonisolated enum HumanLabDocumentCameraError: Error, Equatable, Sendable {
    case noReadablePages
    case pageLimitExceeded(maximum: Int)
}

@MainActor
final class HumanLabDocumentScanCapture {
    private var scan: VNDocumentCameraScan?
    let pageCount: Int

    init(scan: VNDocumentCameraScan) {
        self.scan = scan
        pageCount = scan.pageCount
    }

    func page(at pageIndex: Int) -> HumanLabCameraPageImage? {
        guard let scan,
              pageIndex >= 0,
              pageIndex < pageCount else { return nil }
        return autoreleasepool {
            let source = scan.imageOfPage(at: pageIndex)
            guard let image = source.cgImage else { return nil }
            return HumanLabCameraPageImage(
                image: image,
                orientation: source.imageOrientation.cgImagePropertyOrientation
            )
        }
    }

    func release() {
        scan = nil
    }
}

@MainActor
struct HumanLabDocumentCameraView: UIViewControllerRepresentable {
    static let maximumPageCount = HumanLabImagePageProcessingClient.maximumPageCount

    let onFinish: (HumanLabDocumentScanCapture) -> Void
    let onCancel: () -> Void
    let onFailure: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: HumanLabDocumentCameraView

        init(parent: HumanLabDocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(
            _ controller: VNDocumentCameraViewController
        ) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onFailure(error)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            guard scan.pageCount <= HumanLabDocumentCameraView.maximumPageCount else {
                parent.onFailure(HumanLabDocumentCameraError.pageLimitExceeded(
                    maximum: HumanLabDocumentCameraView.maximumPageCount
                ))
                return
            }
            guard scan.pageCount > 0 else {
                parent.onFailure(HumanLabDocumentCameraError.noReadablePages)
                return
            }
            parent.onFinish(HumanLabDocumentScanCapture(scan: scan))
        }
    }
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

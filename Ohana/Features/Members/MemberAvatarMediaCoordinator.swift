//
//  MemberAvatarMediaCoordinator.swift
//  Ohana
//
//  Media route coordination for member avatar capture and cropping.
//

import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UIKit

enum MemberAvatarMediaRoute: Identifiable {
    case photoLibrary
    case camera
    case portraitCrop(MemberPortraitCropItem)
    case permissionAlert

    var id: String {
        switch self {
        case .photoLibrary: "photoLibrary"
        case .camera: "camera"
        case let .portraitCrop(item): "portraitCrop-\(item.id.uuidString)"
        case .permissionAlert: "permissionAlert"
        }
    }
}

enum MemberPortraitCropSource {
    case image(UIImage)
    case photoItem(PhotosPickerItem)
}

struct MemberPortraitCropItem: Identifiable {
    let id = UUID()
    let source: MemberPortraitCropSource
}

@MainActor
final class MemberAvatarMediaCoordinator: ObservableObject {
    @Published var route: MemberAvatarMediaRoute?
    @Published var photoItem: PhotosPickerItem?
    private var didPrepareCamera = false
    private var isRequestingCameraPermission = false

    var isPhotoPickerPresented: Bool {
        if case .photoLibrary = route { return true }
        return false
    }

    var isCameraPresented: Bool {
        if case .camera = route { return true }
        return false
    }

    var cropItem: MemberPortraitCropItem? {
        if case let .portraitCrop(item) = route { return item }
        return nil
    }

    func openPhotoLibrary() {
        MemberCreationPerformance.event("Avatar PhotoPicker Open")
        route = .photoLibrary
    }

    func prepareCameraIfNeeded() {
        guard !didPrepareCamera else { return }
        guard ohanaCameraHardwareAvailable() else { return }
        didPrepareCamera = true
        Task.detached(priority: .utility) { // smoothness: allow legacy off-main media/compute worker; cancellable service migration tracked after P1 baseline
            let signpostID = MemberCreationPerformance.begin("Camera Device Warmup")
            _ = AVCaptureDevice.authorizationStatus(for: .video)
            _ = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            ).devices.count
            MemberCreationPerformance.end("Camera Device Warmup", signpostID)
        }
    }

    func openCamera() {
        MemberCreationPerformance.event("Avatar Camera Open Request")
        guard ohanaCameraHardwareAvailable() else {
            route = .permissionAlert
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            MemberCreationPerformance.event("Avatar Camera Route Presented")
            route = .camera
        case .notDetermined:
            guard !isRequestingCameraPermission else { return }
            isRequestingCameraPermission = true
            let permissionID = MemberCreationPerformance.begin("Camera Permission Request")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    MemberCreationPerformance.end("Camera Permission Request", permissionID)
                    self?.isRequestingCameraPermission = false
                    if granted {
                        MemberCreationPerformance.event("Avatar Camera Route Presented")
                    }
                    self?.route = granted ? .camera : .permissionAlert
                }
            }
        case .denied, .restricted:
            route = .permissionAlert
        @unknown default:
            route = .permissionAlert
        }
    }

    func showCrop(for item: MemberPortraitCropItem) {
        MemberCreationPerformance.event("Avatar Crop Route Presented")
        route = .portraitCrop(item)
    }

    func clearIfRoute(_ routeId: String) {
        guard route?.id == routeId else { return }
        route = nil
    }
}

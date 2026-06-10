//
//  PetCameraPickerView.swift
//  Ohana
//

import AVFoundation
import SwiftUI
import UIKit

@MainActor
func requestOhanaCameraAccess(
    onGranted: @escaping @MainActor () -> Void,
    onDenied: @escaping @MainActor () -> Void
) {
    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil ||
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil ||
        AVCaptureDevice.default(for: .video) != nil
    else {
        onDenied()
        return
    }

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
        onGranted()
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Task { @MainActor in
                granted ? onGranted() : onDenied()
            }
        }
    case .denied, .restricted:
        onDenied()
    @unknown default:
        onDenied()
    }
}

struct PetCameraPickerView: UIViewControllerRepresentable {
    let maxPixel: CGFloat
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    init(
        maxPixel: CGFloat = 2_200,
        onCapture: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.maxPixel = maxPixel
        self.onCapture = onCapture
        self.onCancel = onCancel
    }

    func makeUIViewController(context _: Context) -> OhanaCameraViewController {
        let viewController = OhanaCameraViewController()
        viewController.maxCapturePixel = maxPixel
        viewController.onCapture = onCapture
        viewController.onCancel = onCancel
        return viewController
    }

    func updateUIViewController(_: OhanaCameraViewController, context _: Context) {}
}

final class OhanaCameraViewController: UIViewController {
    var maxCapturePixel: CGFloat = 2_200
    var onCapture: (UIImage) -> Void = { _ in }
    var onCancel: () -> Void = {}

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "ohana.camera.session", qos: .userInitiated)
    private var didConfigureSession = false
    private var captureDelegate: PhotoCaptureDelegate?
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)
    private let closeButton = UIButton(type: .system)
    private let captureButton = UIButton(type: .system)
    private let unavailableLabel = UILabel()
    private let openingLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        MemberCreationPerformance.event("Camera Shell Loaded")
        view.backgroundColor = .black
        configurePreview()
        configureControls()
        showOpeningState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MemberCreationPerformance.event("Camera Shell Appeared")
        showOpeningState()
        startCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    private func configurePreview() {
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
    }

    private func configureControls() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor(Color.goCardWhite)
        closeButton.backgroundColor = UIColor(Color.arkInk).withAlphaComponent(0.36)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.backgroundColor = UIColor(Color.goCardWhite)
        captureButton.layer.cornerRadius = 34
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor(Color.goCardWhite).withAlphaComponent(0.35).cgColor
        captureButton.isEnabled = false
        captureButton.alpha = 0.35
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(captureButton)

        openingLabel.translatesAutoresizingMaskIntoConstraints = false
        openingLabel.text = L10n(AppLanguage.code).tr(zh: "正在打开相机", en: "Opening camera", de: "Kamera wird geöffnet")
        openingLabel.textColor = UIColor(Color.goCardWhite)
        openingLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        openingLabel.textAlignment = .center
        view.addSubview(openingLabel)

        unavailableLabel.translatesAutoresizingMaskIntoConstraints = false
        unavailableLabel.text = L10n(AppLanguage.code).tr(zh: "无法打开相机", en: "Camera unavailable", de: "Kamera nicht verfügbar")
        unavailableLabel.textColor = UIColor(Color.goCardWhite)
        unavailableLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        unavailableLabel.textAlignment = .center
        unavailableLabel.isHidden = true
        view.addSubview(unavailableLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 68),
            captureButton.heightAnchor.constraint(equalToConstant: 68),

            openingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openingLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            openingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            openingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            unavailableLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unavailableLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            unavailableLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            unavailableLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    private func startCamera() {
        MemberCreationPerformance.event("Camera Session Start Requested")
        let session = session
        let output = photoOutput
        let queue = sessionQueue
        queue.async { [weak self] in
            guard let self else { return }
            if !self.didConfigureSession {
                let configureID = MemberCreationPerformance.begin("Camera Session Configure")
                guard self.configureSession(session: session, output: output) else {
                    MemberCreationPerformance.end("Camera Session Configure", configureID)
                    DispatchQueue.main.async { [weak self] in self?.showUnavailableState() }
                    return
                }
                MemberCreationPerformance.end("Camera Session Configure", configureID)
                self.didConfigureSession = true
            }
            if session.isRunning {
                DispatchQueue.main.async { [weak self] in
                    self?.showReadyState()
                }
                return
            }
            let startID = MemberCreationPerformance.begin("Camera Session StartRunning")
            session.startRunning()
            MemberCreationPerformance.end("Camera Session StartRunning", startID)
            DispatchQueue.main.async { [weak self] in
                self?.showReadyState()
            }
        }
    }

    private func stopCamera() {
        let session = session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func configureSession(session: AVCaptureSession, output: AVCapturePhotoOutput) -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(output)
        else {
            return false
        }

        session.addInput(input)
        session.addOutput(output)
        return true
    }

    private func showUnavailableState() {
        openingLabel.isHidden = true
        unavailableLabel.isHidden = false
        captureButton.isEnabled = false
        captureButton.alpha = 0.35
    }

    private func showOpeningState() {
        openingLabel.isHidden = false
        unavailableLabel.isHidden = true
        captureButton.isEnabled = false
        captureButton.alpha = 0.35
    }

    private func showReadyState() {
        MemberCreationPerformance.event("Camera Session Ready")
        openingLabel.isHidden = true
        unavailableLabel.isHidden = true
        captureButton.isEnabled = true
        captureButton.alpha = 1
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func captureTapped() {
        MemberCreationPerformance.event("Camera Capture Tap")
        guard session.isRunning else { return }
        captureButton.isEnabled = false
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut]) {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        } completion: { _ in
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                self.captureButton.transform = .identity
            }
        }

        let settings = AVCapturePhotoSettings()
        let delegate = PhotoCaptureDelegate(maxPixel: maxCapturePixel) { [weak self] image in
            DispatchQueue.main.async {
                guard let self else { return }
                self.captureButton.isEnabled = true
                if let image {
                    self.onCapture(image)
                } else {
                    self.showUnavailableState()
                }
                self.captureDelegate = nil
            }
        }
        captureDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
        let maxPixel: CGFloat
        let completion: (UIImage?) -> Void

        init(maxPixel: CGFloat, completion: @escaping (UIImage?) -> Void) {
            self.maxPixel = maxPixel
            self.completion = completion
        }

        func photoOutput(
            _: AVCapturePhotoOutput,
            didFinishProcessingPhoto photo: AVCapturePhoto,
            error: Error?
        ) {
            let signpostID = MemberCreationPerformance.begin("Camera Photo Decode")
            guard error == nil,
                  let data = photo.fileDataRepresentation(),
                  let image = AddPetWizardView.cropReadyImage(from: data, maxPixel: maxPixel)
            else {
                MemberCreationPerformance.end("Camera Photo Decode", signpostID)
                completion(nil)
                return
            }
            MemberCreationPerformance.end("Camera Photo Decode", signpostID)
            completion(image)
        }
    }
}

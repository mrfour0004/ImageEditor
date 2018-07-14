//
//  CameraViewController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/6.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController {

    // MARK: - Session Management

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private let session = AVCaptureSession()
    private var isSessionRunning = false

    // Communicate with the session and other session object on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")

    private var setupResult: SessionSetupResult = .success
    private var videoDeviceInput: AVCaptureDeviceInput!

    @IBOutlet private weak var previewView: PreviewView!
    @IBOutlet private weak var flashButton: CameraButton!
    @IBOutlet private weak var libraryButton: CameraButton!

    // MARK: - Capturing photos

    private var flashMode: AVCaptureDevice.FlashMode = .off {
        didSet {
            updateFlashButton()
        }
    }
    private var photoOutput: AVCaptureStillImageOutput!
    private weak var focusView: FocusView?
    var photoCapturedHandler: ((UIImage) -> Void)?

    @IBAction private func didClickShutterButton(_ sender: Any) {
        capturePhoto { image in 
            self.photoCapturedHandler?(image)
            self.dismiss(animated: true, completion: nil)
        }
    }

    @IBAction private func didClickLibraryButton(_ sender: Any) {
        presentImagePickerController()
    }

    @IBAction private func didClickFlashButton(_ button: UIButton) {
        flashMode.swith()
    }

    @IBAction private func didTapPreviewView(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
        
        if let gestureView = gestureRecognizer.view {
            focusView?.dismiss()
            focusView = FocusView().show(on: gestureView, atPoint: gestureRecognizer.location(in: gestureView))
        }
    }

    private func updateFlashButton() {
        let height = LayoutConfig.flashIconSize.height
        UIView.transition(with: flashButton, duration: 0.3, options: [.curveEaseIn, .transitionCrossDissolve], animations: {
            self.flashButton.setImage(self.flashMode.icon.resize(toHeight: height)?.tint(with: .white), for: .normal)
            self.flashButton.setImage(self.flashMode.icon.resize(toHeight: height)?.tint(with: .white), for: .highlighted)
        }, completion: nil)

        if #available(iOS 10.0, *) {
            UIViewPropertyAnimator(duration: 0.3, curve: .easeInOut) {
                for _ in 0...1 { // make a 360 degree rotation
                    let transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                    self.flashButton.transform = self.flashButton.transform.concatenating(transform)
                }
            }.startAnimation()
        }
    }

    private func capturePhoto(completion: @escaping (_ image: UIImage) -> Void) {
        //
        // Retrieve the video preview layer's video orientation on the main queue before
        // entering the session queue. We do this to ensure UI elements are accessed on
        // the main thread and session configuration is done on the session queue.
        //
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation

        UIView.transition(with: previewView, duration: 0.1, options: [.curveEaseInOut], animations: {
            self.previewView.alpha = 0
        }, completion: { _ in
            UIView.transition(with: self.previewView, duration: 0.1, options: [.curveEaseInOut], animations: {
                self.previewView.alpha = 1
            }, completion: nil)
        })

        sessionQueue.async {
            let connect = self.photoOutput.connection(with: .video)!
            connect.videoOrientation = videoPreviewLayerOrientation!

            CameraViewController.setFlashMode(self.flashMode, for: self.videoDeviceInput.device)
            self.photoOutput.captureStillImageAsynchronously(from: connect, completionHandler: { imageDataSampleBuffer, error in
                guard let imageDataSampleBuffer = imageDataSampleBuffer else {
                    return print("cannot snap still image with error: \(error!)")
                }

                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
                let image = self.cropImageUsingPreviewBound(UIImage(data: imageData!)!)

                DispatchQueue.main.async {
                    completion(image)
                }
            })
        }
    }

    private func cropImageUsingPreviewBound(_ image: UIImage) -> UIImage {
        let previewBounds = previewView.videoPreviewLayer.bounds
        let outputRect = previewView.videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: previewBounds)

        let takenImage = image.cgImage!
        let width = CGFloat(takenImage.width)
        let height = CGFloat(takenImage.height)
        let cropRect = CGRect(x: outputRect.origin.x * width, y: outputRect.origin.y * height, width: outputRect.size.width * width, height: outputRect.height * height)

        let imageRef = takenImage.cropping(to: cropRect)!
        let image = UIImage(cgImage: imageRef, scale: 0, orientation: image.imageOrientation)

        return image
    }

    private static func setFlashMode(_ flashMode: AVCaptureDevice.FlashMode, for device: AVCaptureDevice) {
        if device.hasFlash && device.isFlashModeSupported(flashMode) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.flashMode = flashMode
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }

    // MARK: - Key Value Observation

    private var keyValueObservations = [NSKeyValueObservation]()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupCaptureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            default:
                break
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            guard self.setupResult == .success else { return }

            self.session.stopRunning()
            self.isSessionRunning = self.session.isRunning
            self.removeObservers()
        }

        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
                deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
                    return
            }

            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }
}

// MARK: - Setup Views

private extension CameraViewController {

    func setupViews() {
        view.backgroundColor = .clear

        setupButton(flashButton, image: flashMode.icon)
        setupButton(libraryButton, image: .photoLibrary)
    }

    func setupButton(_ button: UIButton, image: UIImage) {
        let height = LayoutConfig.flashIconSize.height
        button.setImage(image.resize(toHeight: height)?.tint(with: .white), for: .normal)
        button.setImage(image.resize(toHeight: height)?.tint(with: .white), for: .highlighted)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowRadius = 1
        button.layer.shadowOpacity = 0.5
        button.layer.shadowOffset = .zero
    }

    func setupCaptureSession() {
        previewView.session = session
        previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
        evaluateCameraAuthorization()

        sessionQueue.async {
            self.configureSession()
        }
    }

    func evaluateCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant video access.
             We suspend the session queue to delay session setup until the access request has completed.

             Note that audio access will be implicitly requested when we create an AVCaptureDeviceInput
             for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.sessionQueue.resume()
                } else {
                    self.setupResult = .notAuthorized
                }
            }
        default:
            setupResult = .notAuthorized
        }
    }

    func configureSession() {
        guard setupResult == .success else { return }

        session.beginConfiguration()

        session.sessionPreset = .photo

        func onConfigureFailed(message: String, error: Error?) {
            print("Could not create video device input: \(String(describing: error))")
            setupResult = .configurationFailed
            session.commitConfiguration()
        }

        guard let defaultVideoDevice = AVCaptureDevice.defaultCamera() else { return }

        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)

            guard session.canAddInput(videoDeviceInput) else {
                return onConfigureFailed(message: "Could not add video input to the session", error: nil)
            }

            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput

            DispatchQueue.main.async {
                let statusBarOrientation = UIApplication.shared.statusBarOrientation
                var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                if statusBarOrientation != .unknown {
                    if let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) {
                        initialVideoOrientation = videoOrientation
                    }
                }

                self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
            }

        } catch {
            onConfigureFailed(message: "Could not add video device input to the session", error: error)
        }

        let photoOutput = AVCaptureStillImageOutput()
        if self.session.canAddOutput(photoOutput) {
            photoOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            self.session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            print("Could not add still image output to the sessvion")
            self.setupResult = .configurationFailed
        }

        session.commitConfiguration()
    }

    func addObservers() {
        let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            // disable/enable buttons according session status.
//            DispatchQueue.main.async {
//
//            }
        }

        keyValueObservations.append(keyValueObservation)
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
    }

    func removeObservers() {
        NotificationCenter.default.removeObserver(self)

        keyValueObservations.forEach {
            $0.invalidate()
        }
        keyValueObservations.removeAll()
    }
}

// MARK: - UIImagePickerControllerDelegate Methods

extension CameraViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private func presentImagePickerController() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary

        self.present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        self.photoCapturedHandler?(image)
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Camera

private extension CameraViewController {
    @objc func subjectAreaDidChange(_ notification: Notification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }

    func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()

                //
                // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                // Call set(Focus/Exposure)Mode() to apply the new point of interest.
                //
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }

                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }

                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
}

// MARK: - Configuration

private extension CameraViewController {
    enum LayoutConfig {
        static let flashIconSize = CGSize(width: 24, height: 24)
    }
}

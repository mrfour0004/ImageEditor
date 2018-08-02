//
//  CameraViewController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/6.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit
import AVFoundation

class CameraViewController: UIViewController, StoryboardLoadable {

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
    @IBOutlet private weak var shutterButton: CameraButton!
    @IBOutlet private weak var switchCameraButton: CameraButton!

    // MARK: - Capturing photos

    private var flashMode: AVCaptureDevice.FlashMode = .off {
        didSet { updateFlashButtonIcon() }
    }
    private var photoOutput: AVCaptureStillImageOutput!
    private var isCapturingPhoto = false

    private weak var focusView: FocusView?
    private weak var translucencyView: UIVisualEffectView?

    @IBAction private func didClickShutterButton(_ sender: Any) {
        guard !isCapturingPhoto else { return }
        isCapturingPhoto = true

        capturePhoto { [unowned self] image in
            guard let imagePicker = self.navigationController as? ImagePickerController else { return }

            self.showTranslucencyView(animated: true)
            if imagePicker.allowsEditing {
                let imageEditorViewController = ImageEditorViewController.instantiateFromStoryboard()
                imageEditorViewController.image = image
                imagePicker.pushViewController(imageEditorViewController, animated: true)
            } else {
                imagePicker.pickerDelegate?.imagePicker(imagePicker, didFinishPickingImage: image)
            }
        }
    }

    @IBAction private func didClickLibraryButton(_ sender: Any) {
        DispatchQueue.main.async {
            self.presentImagePickerController()
        }
    }

    @IBAction private func didClickFlashButton(_ button: UIButton) {
        flashMode.switch()
    }

    @IBAction func didClickSwitchCameraButton(_ sender: Any) {
        flipCamera()
    }

    @IBAction func didClickCloseButton(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func didTapPreviewView(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
        focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
        
        if let gestureView = gestureRecognizer.view {
            focusView?.dismiss()
            focusView = FocusView().show(on: gestureView, atPoint: gestureRecognizer.location(in: gestureView))
        }
    }

    private func updateFlashButtonIcon() {
        let fakeButton = flashButton.snapshotView(afterScreenUpdates: false)!
        view.addSubview(fakeButton)
        fakeButton.frame = flashButton.superview!.convert(flashButton.frame, to: view)

        UIView.transition(with: fakeButton, duration: 0.25, options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction], animations: {
            fakeButton.alpha = 0
            fakeButton.transform = CGAffineTransform(rotationAngle: CGFloat(90) * CGFloat.pi / 180)
        }, completion: { _ in
            fakeButton.removeFromSuperview()
        })

        flashButton.alpha = 0
        flashButton.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)

        let height = LayoutConfig.flashIconSize.height
        flashButton.setImage(self.flashMode.icon.resize(toHeight: height)?.tint(with: .white), for: .normal)
        flashButton.setImage(self.flashMode.icon.resize(toHeight: height)?.tint(with: .white), for: .highlighted)

        UIView.animate(withDuration: 0.4, delay: 0.05, usingSpringWithDamping: 0.6, initialSpringVelocity: 1, options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction], animations: {
            self.flashButton.transform = .identity
            self.flashButton.alpha = 1
        }, completion: nil)
    }

    private func onVideoDevicePositionChange() {
        let preferredFalshButtonHidden: Bool
        switch self.videoDeviceInput.device.position {
        case .front, .unspecified:
            preferredFalshButtonHidden = true
        case .back:
            preferredFalshButtonHidden = false
        }

        UIView.transition(with: flashButton.superview!, duration: 0.3, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
            self.flashButton.isHidden = preferredFalshButtonHidden
        }, completion: nil)

        UIView.animate(withDuration: 0.15, delay: preferredFalshButtonHidden ? 0 : 0.15, options: .beginFromCurrentState, animations: {
            self.flashButton.alpha = preferredFalshButtonHidden ? 0 : 1
        }, completion: nil)

        UIView.transition(with: switchCameraButton, duration: 0.3, options: [], animations: {
            self.switchCameraButton.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }, completion: { _ in
            self.switchCameraButton.transform = .identity
        })
    }

    private func capturePhoto(completion: @escaping (_ image: UIImage) -> Void) {
        //
        // Retrieve the video preview layer's video orientation on the main queue before
        // entering the session queue. We do this to ensure UI elements are accessed on
        // the main thread and session configuration is done on the session queue.
        //
        let videoPreviewLayerOrientation = previewView.videoPreviewLayer.connection?.videoOrientation

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
        startRunningSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }

    override func viewWillDisappear(_ animated: Bool) {
        stopRunningSession()

        super.viewWillDisappear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // to re-enable shutter button.
        isCapturingPhoto = false
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

    // MARK: - Translucency View

    func showTranslucencyView(animated: Bool) {
        guard self.translucencyView == nil else { return }
        let translucencyView = UIVisualEffectView()
        translucencyView.frame = view.bounds
        translucencyView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(translucencyView)

        self.translucencyView = translucencyView

        guard animated else {
            translucencyView.effect = UIBlurEffect(style: .light)
            return
        }

        UIView.animateKeyframes(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState], animations: {
            translucencyView.effect = UIBlurEffect(style: .light)
        }, completion: nil)
    }

    func hideTranslucencyView(animated: Bool) {
        guard let translucencyView = translucencyView else { return }
        self.translucencyView = nil

        let animations: () -> Void = {
            translucencyView.effect = nil
        }

        guard animated else {
            translucencyView.removeFromSuperview()
            return animations()
        }

        UIView.animateKeyframes(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState], animations: animations, completion: { _ in
            translucencyView.removeFromSuperview()
        })
    }
}

// MARK: - Setup Views

private extension CameraViewController {

    func setupViews() {
        view.backgroundColor = .black

        setupButton(flashButton, image: flashMode.icon)
        setupButton(libraryButton, image: #imageLiteral(resourceName: "ic_album_white100"))
        setupButton(switchCameraButton, image: #imageLiteral(resourceName: "ic_switch camera_white100"))
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

        guard let defaultVideoDevice = AVCaptureDevice.defaultCamera(position: .back) else { return }

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

    private func startRunningSession() {
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                DispatchQueue.main.async {
                    self.requestCameraPermission()
                }
            case .configurationFailed:
                break
                // show alert or somthing
            }
        }
    }

    private func stopRunningSession() {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
    }

    func requestCameraPermission() {
        // present alert or something
    }

    func addObservers() {
        let isSessionRunningObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }
            // disable/enable buttons according session status.
            DispatchQueue.main.async {
                if isSessionRunning {
                    self.hideTranslucencyView(animated: true)
                } else {
                    self.showTranslucencyView(animated: true)
                }
            }
        }
        keyValueObservations.append(isSessionRunningObservation)

        let isCapturingStillImageObservation = photoOutput.observe(\.isCapturingStillImage, options: .new, changeHandler: { _, change in
            guard let isCapturingStillImage = change.newValue, isCapturingStillImage else { return }
            UIView.transition(with: self.previewView, duration: 0.1, options: [.curveEaseInOut], animations: {
                self.previewView.alpha = 0
            }, completion: { _ in
                UIView.transition(with: self.previewView, duration: 0.1, options: [.curveEaseInOut], animations: {
                    self.previewView.alpha = 1
                }, completion: nil)
            })
        })
        keyValueObservations.append(isCapturingStillImageObservation)

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
        //imagePicker.modalPresentationStyle = .overFullScreen
        showTranslucencyView(animated: true)
        self.present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage

        guard let imagePicker = navigationController as? ImagePickerController else { return }

        if imagePicker.allowsEditing {
            let imageEditorViewController = ImageEditorViewController.instantiateFromStoryboard()
            imageEditorViewController.image = image
            imagePicker.pushViewController(imageEditorViewController, animated: false)

            picker.dismiss(animated: true, completion: nil)
        } else {
            imagePicker.pickerDelegate?.imagePicker(imagePicker, didFinishPickingImage: image)
        }
    }
}

// MARK: - Camera

extension CameraViewController {
    @objc private func subjectAreaDidChange(_ notification: Notification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }

    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            guard self.isSessionRunning else { return }

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

    private func flipCamera() {
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position

            let preferredPosition: AVCaptureDevice.Position

            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
            case .back:
                preferredPosition = .front
            }

            guard let device = AVCaptureDevice.defaultCamera(position: preferredPosition) else { return }

            do {
                let videoDeviceInput = try AVCaptureDeviceInput(device: device)

                self.session.beginConfiguration()

                self.session.removeInput(self.videoDeviceInput)

                if self.session.canAddInput(videoDeviceInput) {
                    NotificationCenter.default.removeObserver(self, name: .AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
                    NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)

                    self.session.addInput(videoDeviceInput)
                    self.videoDeviceInput = videoDeviceInput
                    DispatchQueue.main.async {
                        self.onVideoDevicePositionChange()
                    }
                } else {
                    self.session.addInput(self.videoDeviceInput)
                }

                self.session.commitConfiguration()
            } catch {
                print("Error occured while creating video device input: \(error)")
            }
        }
    }
}

// MARK: - Configuration

private extension CameraViewController {
    enum LayoutConfig {
        static let flashIconSize = CGSize(width: 36, height: 36)
    }
}

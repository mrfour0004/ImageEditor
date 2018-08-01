//
//  ImageEditorViewController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/17.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImageEditorViewController: UIViewController, StoryboardLoadable {

    // MARK: - Properties

    var image: UIImage!
    private var isProcessingImage = false

    var ciContext: CIContext!
    var ciFilter: CIFilter!
    var ciQueue = DispatchQueue(label: "ci queue")

    var isAspectRatioLockEnabled: Bool {
        get { return cropView.isAspectRatioLockEnabled }
        set { cropView.isAspectRatioLockEnabled = newValue }
    }

    var aspectRatioPreset: CropAspectRatioPreset {
        get { return imagePicker.cropAspectRatioPreset }
    }
    
    private var imagePicker: ImagePickerController {
        return navigationController as! ImagePickerController
    }

    // MARK: - IBOutlets

    @IBOutlet private weak var controlPanelContainerView: UIView! {
        didSet {
            controlPanel.delegate = self
            controlPanel.frame = controlPanelContainerView.bounds
            controlPanel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            controlPanelContainerView.addSubview(controlPanel)
        }
    }

    // MARK: - Views

    private lazy var controlPanel: ImageEditorControlPanel = ImageEditorControlPanel.instantiateFromNib()
    private lazy var cropView = CropView(image: image)
    private lazy var doneButton: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDoneButton))

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        automaticallyAdjustsScrollViewInsets = false
        isAspectRatioLockEnabled = imagePicker.isAspectRatioLockEnabled

        updateNavigationItem(for: nil, animated: false)
        setupCropView()
        setupCIContext()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if navigationController == nil {
            cropView.setBackgroundImageViewHidden(true, animated: false)
        }

        if aspectRatioPreset != .original {
            setAspectRatioPreset(aspectRatioPreset, animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if animated {
            if cropView.isGridOverlayHidden {
                cropView.setGridOverlayHidden(false, animated: true)
            }
        }

        if navigationController == nil {
            cropView.setBackgroundImageViewHidden(false, animated: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // crop view dosen't apply auto-layout, so update its layout manually.
        updateCropViewFrame()

        // to fix a weird mis-positioning on iOS 11.
        DispatchQueue.main.async {
            self.cropView.moveCroppedContentToCenter(animated: false)
        }
    }

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCropViewFrame()
    }

    // MARK: - Buttons

    @objc private func didTapDoneButton(_ sender: Any) {
        cropImage()
    }

    // MARK: - Setup Views

    private func setupCropView() {
        updateCropViewFrame()

        // prevent enlarged image exceeding `view.bounds` when navigating to previous view controller.
        view.clipsToBounds = true

        view.insertSubview(cropView, at: 0)
        view.backgroundColor = cropView.backgroundColor
    }

    private func setupCIContext() {
        ciContext = CIContext(options: nil)

        ciFilter = CIFilter(name: "CIColorControls")!
        ciFilter.setValue(CIImage(image: image)!, forKey: kCIInputImageKey)
    }

    /// Update the UI of `navigtaionItem` by the given `editMode`.
    /// Set `editMode` as `nil` to end the editing mode.
    private func updateNavigationItem(for editMode: ImageEditorControlPanel.EditMode?, animated: Bool) {
        if let editMode = editMode {
            navigationItem.hidesBackButton = true
            navigationItem.rightBarButtonItem = nil
            title = editMode.description
        } else {
            navigationItem.hidesBackButton = false
            navigationItem.rightBarButtonItem = doneButton
            title = "Edit Image"
        }

        guard animated else { return }

        let fadeTransition = CATransition()
        fadeTransition.duration = 0.15
        fadeTransition.type = kCATransitionFade
        navigationController?.navigationBar.layer.add(fadeTransition, forKey: nil)
    }

    // MARK: - CropView Methods

    private func updateCropViewFrame() {
        cropView.frame = view.bounds
        var cropRegionInset: UIEdgeInsets = .zero

        if #available(iOS 11.0, *) {
            cropRegionInset.top += view.safeAreaInsets.top
            cropRegionInset.bottom += view.safeAreaInsets.bottom + controlPanelContainerView.frame.height
        } else {
            cropRegionInset.top += topLayoutGuide.length
            cropRegionInset.bottom += bottomLayoutGuide.length + controlPanelContainerView.frame.height
        }
        cropView.cropRegionInset = cropRegionInset
    }

    private func cropImage() {
        let croppedImage = cropView.croppedImage

        ciFilter.setValue(CIImage(image: croppedImage), forKey: kCIInputImageKey)
        let outputImage = self.ciFilter.outputImage!
        let filteredImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent)!

        imagePicker.pickerDelegate?.imagePicker(imagePicker, didFinishPickingImage: UIImage(cgImage: filteredImage, scale: UIScreen.main.scale, orientation: croppedImage.imageOrientation))
    }

    private func setAspectRatioPreset(_ aspectRatioPreset: CropAspectRatioPreset, animated: Bool) {
        var aspectRatio = aspectRatioPreset.aspectRatio

        if (!aspectRatioPreset.isCustom && cropView.cropBoxAspectRatioIsPortrait && !cropView.isAspectRatioLockEnabled) {
            aspectRatio = CGSize(width: aspectRatio.height, height: aspectRatio.width)
        }

        cropView.setAspectRatio(aspectRatio, animated: animated)
    }
    
}

// MARK: - ImageEditorControlPanelDelegate Methods

extension ImageEditorViewController: ImageEditorControlPanelDelegate {
    
    func imageEditorDidTapRotateButton(_ controlPanel: ImageEditorControlPanel) {
        cropView.rotateCropView(animated: true)
    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, didCancelEditing mode: ImageEditorControlPanel.EditMode) {
        updateNavigationItem(for: nil, animated: true)
        isEditing = false
        cropView.isAllowEditing = true

        let dict = controlPanel.editedValueDictionary.ciInputValueConverted
        ciQueue.async {
            self.ciFilter.setValue(CIImage(image: self.image), forKey: kCIInputImageKey)
            self.ciFilter.setValue(dict[mode] ?? mode.ciDefaultValue, forKey: mode.ciInputKey)
        }
    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, sliderValueChangedTo value: Float, for editingMode: ImageEditorControlPanel.EditMode) {
        guard !isProcessingImage else { return }
        isProcessingImage = true

        ciQueue.async {
            print("set \(editingMode.description): \(self.ciFilter.value(forKey: editingMode.ciInputKey)!)")

            self.ciFilter.setValue(value, forKey: editingMode.ciInputKey)
            let outputImage = self.ciFilter.outputImage!
            let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent)!

            DispatchQueue.main.async {
                if let imageViewForFilter = self.cropView.imageViewForFilter {
                    imageViewForFilter.image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: imageViewForFilter.image!.imageOrientation)
                }
            }

            self.isProcessingImage = false
        }
    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, willBedingEditing mode: ImageEditorControlPanel.EditMode) {
        updateNavigationItem(for: mode, animated: true)
        isEditing = true
        cropView.isAllowEditing = false

        guard
            let imageViewForFilter = cropView.imageViewForFilter,
            let croppedImage = self.cropView.croppedImage.resize(toHeight: imageViewForFilter.frame.height)
        else { return }

        ciQueue.async {
            self.ciFilter.setValue(CIImage(image: croppedImage), forKey: kCIInputImageKey)

            let outputImage = self.ciFilter.outputImage!
            let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent)!

            DispatchQueue.main.async {
                imageViewForFilter.image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: croppedImage.imageOrientation)
            }
        }
    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, didEndEditing mode: ImageEditorControlPanel.EditMode) {
        updateNavigationItem(for: nil, animated: true)

        ciQueue.async {
            self.ciFilter.setValue(CIImage(image: self.image), forKey: kCIInputImageKey)
            let outputImage = self.ciFilter.outputImage!
            let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent)!
            DispatchQueue.main.async {
                self.cropView.foregroundImageView.image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: self.image.imageOrientation)
                self.isEditing = false
                self.cropView.isAllowEditing = true
            }
        }
    }

}

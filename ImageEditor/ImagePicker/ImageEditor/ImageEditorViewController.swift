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

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        automaticallyAdjustsScrollViewInsets = false
        updateCropViewFrame()

        setupNavigationItem()
        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if navigationController == nil {
            cropView.setBackgroundImageViewHidden(true, animated: false)
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

    private func setupNavigationItem() {
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDoneButton))
        navigationItem.rightBarButtonItem = doneButton
    }

    private func setupView() {
        view.clipsToBounds = true
        view.insertSubview(cropView, at: 0)
        view.backgroundColor = cropView.backgroundColor
    }

    // MARK: - Convenience Methods

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
        let cropFrame = cropView.imageCropFrame
        let angle = cropView.angle
        let croppedImage = image.cropped(with: cropFrame, angle: angle)
        imagePicker.pickerDelegate?.imagePicker(imagePicker, didFinishPickingImage: croppedImage)
    }

}

// MARK: - ImageEditorControlPanelDelegate Methods

extension ImageEditorViewController: ImageEditorControlPanelDelegate {
    func imageEditorDidTapRotateButton(_ controlPanel: ImageEditorControlPanel) {
        cropView.rotateCropView(animated: true)
    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, sliderValueDidChangeTo value: CGFloat) {

    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, willBedingEditing mode: ImageEditorControlPanel.EditMode) {

    }

    func imageEditor(_ controlPanel: ImageEditorControlPanel, didEndEditing mode: ImageEditorControlPanel.EditMode) {

    }

}

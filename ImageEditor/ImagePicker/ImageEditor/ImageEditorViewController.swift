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

    // MARK: - IBOutlets

    private lazy var cropView = CropView(image: image)

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        automaticallyAdjustsScrollViewInsets = false

        updateCropViewFrame()

        view.clipsToBounds = true
        view.addSubview(cropView)
        view.backgroundColor = cropView.backgroundColor
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

    // MARK: - Convenience Methods

    private func updateCropViewFrame() {
        cropView.frame = view.bounds
        var cropRegionInset: UIEdgeInsets = .zero

        if #available(iOS 11.0, *) {
            cropRegionInset.top += view.safeAreaInsets.top
            cropRegionInset.bottom += view.safeAreaInsets.bottom
        } else {
            cropRegionInset.top += topLayoutGuide.length
            cropRegionInset.bottom += bottomLayoutGuide.length
        }
        cropView.cropRegionInset = cropRegionInset
    }
}

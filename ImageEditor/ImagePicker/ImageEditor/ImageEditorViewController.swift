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
        //setupCropView()

        cropView.frame = view.bounds
        view.addSubview(cropView)
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
        print("view did layout subviews")
        if #available(iOS 11.0, *) {
            cropView.frame = view.safeAreaLayoutGuide.layoutFrame
            cropView.cropRegionInset = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            //cropView.frame = view.frame
        } else {
            cropView.frame = view.frame
        }
        DispatchQueue.main.async {
            self.cropView.moveCroppedContentToCenter(animated: false)
        }
    }

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        print("safe area did change")
    }

    // MARK: - Setup Views

    private func setupCropView() {
        cropView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropView)
        if #available(iOS 11.0, *) {
            NSLayoutConstraint.activate([
                cropView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                cropView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                cropView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                cropView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                cropView.topAnchor.constraint(equalTo: topLayoutGuide.topAnchor),
                cropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                cropView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
    }

    // MARK: - Convenience Methods

    private var frameForCropView: CGRect {
        if #available(iOS 11.0, *) {
            return view.safeAreaLayoutGuide.layoutFrame
        } else {
            var bounds = view.bounds
            bounds.origin.y -= topLayoutGuide.length
            bounds.size.height -= topLayoutGuide.length + bottomLayoutGuide.length
            return view.bounds
        }
    }
}

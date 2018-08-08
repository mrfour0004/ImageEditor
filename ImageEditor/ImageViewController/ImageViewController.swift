//
//  ImageViewController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/8/5.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController {

    // MARK: - Properties

    private let image: UIImage

    // MARK: - Views

    private var scrollView: UIScrollView!
    private var imageView: UIImageView!

    // MARK: - View Lifecycle

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func viewWillLayoutSubviews() {
        setupZoomScale()
    }

    // MARK: - Setup Views

    private func setupViews() {
        imageView = UIImageView(image: image)

        scrollView = UIScrollView(frame: view.bounds)
        scrollView.backgroundColor = .black
        scrollView.contentSize = imageView.bounds.size
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true

        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
    }

    private func setupZoomScale() {
        let imageViewSize = imageView.bounds.size
        let scrollViewSize = scrollView.bounds.size

        let widthScale = scrollViewSize.width / imageViewSize.width
        let heightScale = scrollViewSize.height / imageViewSize.height

        scrollView.minimumZoomScale = min(widthScale, heightScale)
        scrollView.zoomScale = scrollView.minimumZoomScale
    }
}

// MARK: - UIScrollViewDelegate Methods

extension ImageViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = scrollView.bounds.size

        let verticalPadding = max(0, (scrollViewSize.height - imageViewSize.height) / 2)
        let horizontalPadding = max(0, (scrollViewSize.width - imageViewSize.width) / 2)

        scrollView.contentInset = UIEdgeInsets(top: verticalPadding, left: horizontalPadding, bottom: verticalPadding, right: horizontalPadding)
    }
}



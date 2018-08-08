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
    private var needsHideStatusBar = false {
        didSet {
            UIView.animate(withDuration: Double(UINavigationControllerHideShowBarDuration), delay: 0, options: .curveEaseInOut, animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            }, completion: nil)
        }
    }

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        needsHideStatusBar = true
    }

    override func viewWillLayoutSubviews() {
        setupZoomScale()
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }

    override var prefersStatusBarHidden: Bool {
        return needsHideStatusBar
    }

    // MARK: - Setup Views

    private func setupViews() {
        imageView = UIImageView(image: image)

        setupScrollView()
        setupCloseButton()
    }

    private func setupScrollView() {
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

    private func setupCloseButton() {
        let closeButton = UIButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(#imageLiteral(resourceName: "ic_close_white"), for: .normal)
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)

        view.addSubview(closeButton)

        var constraints = [
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
        ]
        if #available(iOS 11.0, *) {
            constraints.append(closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12))
        } else {
            constraints.append(closeButton.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 12))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func setupZoomScale() {
        let imageViewSize = imageView.bounds.size
        let scrollViewSize = scrollView.bounds.size

        let widthScale = scrollViewSize.width / imageViewSize.width
        let heightScale = scrollViewSize.height / imageViewSize.height

        scrollView.minimumZoomScale = min(widthScale, heightScale)
        scrollView.zoomScale = scrollView.minimumZoomScale
    }

    // MARK: - Private Methods

    @objc private func didTapCloseButton(_ button: UIButton) {
        needsHideStatusBar = false
        dismiss(animated: true, completion: nil)
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



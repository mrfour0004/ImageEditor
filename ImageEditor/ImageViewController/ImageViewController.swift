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

    var sourceView: UIImageView?
    let closeButton = UIButton()

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
    var imageView: UIImageView!

    // MARK: - View Lifecycle

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        transitioningDelegate = self
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.15, animations: {
            self.closeButton.alpha = 1
        })
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
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }

        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
    }

    private func setupCloseButton() {

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(#imageLiteral(resourceName: "ic_close_white"), for: .normal)
        closeButton.addTarget(self, action: #selector(didTapCloseButton), for: .touchUpInside)
        closeButton.alpha = 0

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

// MARK: - UIViewControllerTransitioningDelegate Methods

extension ImageViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let sourceView = sourceView else { return nil }
        return ImageViewPresentAnimator(imageView: imageView, sourceView: sourceView)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard let sourceView = sourceView else { return nil }

        let imageViewFrame = imageView.superview!.convert(imageView.frame, to: (UIApplication.shared.delegate?.window).or(view))
        return ImageViewDismissAnimator(imageView: imageView, imageFrame: imageViewFrame, sourceView: sourceView)
    }
}

//
//  ImageViewPresentAnimator.swift
//  ImageEditor
//
//  Created by mrfour on 2018/8/8.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImageViewPresentAnimator: NSObject {
    var sourceView: UIImageView
    var imageView: UIImageView

    init(imageView: UIImageView, sourceView: UIImageView) {
        self.imageView = imageView
        self.sourceView = sourceView
    }
}

extension ImageViewPresentAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.45
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        let imageViewController = transitionContext.viewController(forKey: .to)!
        let presentingViewController = transitionContext.viewController(forKey: .from)!

        containerView.addSubview(imageViewController.view)

        let imageViewFrame: CGRect = {
            let size = imageView.image!.size.resized(toFit: imageViewController.view.bounds.size)
            var frame = CGRect(origin: .zero, size: size)
            frame.origin.y = (imageViewController.view.frame.height - size.height) / 2
            return frame
        }()

        let transitionImageView = UIImageView(image: imageView.image)
        transitionImageView.frame = sourceView.superview!.convert(sourceView.frame, to: containerView)
        transitionImageView.contentMode = sourceView.contentMode
        transitionImageView.clipsToBounds = true
        containerView.addSubview(transitionImageView)

        imageView.alpha = 0
        sourceView.alpha = 0

        if let presentingViewSnapshot = presentingViewController.view.snapshotView(afterScreenUpdates: true) {
            imageViewController.view.insertSubview(presentingViewSnapshot, at: 0)
        }

        imageViewController.view.alpha = 0
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: [], animations: {
            transitionImageView.frame = imageViewFrame
        }, completion: { _ in
            self.imageView.alpha = 1
            UIView.animate(withDuration: 0.1, animations: {
                transitionImageView.alpha = 0
            }, completion: { _ in
                transitionImageView.removeFromSuperview()
            })
        })

        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
            imageViewController.view.alpha = 1
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

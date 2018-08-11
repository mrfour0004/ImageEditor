//
//  ImageViewDismissAnimator.swift
//  ImageEditor
//
//  Created by mrfour on 2018/8/8.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImageViewDismissAnimator: NSObject {
    let imageView: UIImageView
    let imageFrame: CGRect
    let sourceView: UIImageView

    init(imageView: UIImageView, imageFrame: CGRect, sourceView: UIImageView) {
        self.imageView = imageView
        self.imageFrame = imageFrame
        self.sourceView = sourceView
    }
}

extension ImageViewDismissAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.45
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView

        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!

        let imageViewController = fromVC
        let presentingViewController = toVC

        containerView.insertSubview(presentingViewController.view, belowSubview: imageViewController.view)
        let sourceViewFrame = sourceView.superview!.convert(sourceView.frame, to: containerView)

        let transitionImageView = UIImageView(image: imageView.image)
        transitionImageView.frame = imageFrame
        transitionImageView.contentMode = sourceView.contentMode
        transitionImageView.clipsToBounds = true
        containerView.addSubview(transitionImageView)

        imageView.alpha = 0
        sourceView.alpha = 0
        imageViewController.view.alpha = 1
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: [], animations: {
            transitionImageView.frame = sourceViewFrame
        }, completion: { _ in
            UIView.animate(withDuration: 0.1, animations: {
                transitionImageView.alpha = 0
            }, completion: { _ in
                self.sourceView.alpha = 1
                transitionImageView.removeFromSuperview()
            })
        })

        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
            imageViewController.view.alpha = 0
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

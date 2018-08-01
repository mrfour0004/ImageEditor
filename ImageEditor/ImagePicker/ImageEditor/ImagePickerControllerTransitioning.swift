//
//  ImagePickerControllerTransitioning.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/17.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImagePickerControllerTransitioning: NSObject {

    // MARK: - Properties

    var isDismissing: Bool = false

    /// The image that will be used in this animation
    var image: UIImage?

    var fromView: UIView?
    var toView: UIView?

    var fromFrame: CGRect = .zero
    var toFrame: CGRect = .zero

    // MARK: - Methods

    /// Empties all of the properties in this object
    func reset() {
        image = nil
        toView = nil
        fromView = nil
        toFrame = .zero
        fromFrame = .zero
    }

}

extension ImagePickerControllerTransitioning: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.35
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView

        let fromVC = transitionContext.viewController(forKey: .from)!
        let toVC = transitionContext.viewController(forKey: .to)!

        let cropViewController = (isDismissing) ? fromVC : toVC
        let previousController = (isDismissing) ? toVC : fromVC

        // Just in case, match up the frame sizes
        cropViewController.view.frame = containerView.bounds
        if isDismissing {
            previousController.view.frame = containerView.bounds
        }

        if !isDismissing {
            containerView.addSubview(cropViewController.view)
        } else {
            containerView.insertSubview(previousController.view, belowSubview: cropViewController.view)
        }

        if let fromView = fromView, !isDismissing {
            fromFrame = fromView.superview!.convert(fromView.frame, to: containerView)
        } else if let toView = toView, isDismissing {
            toFrame = toView.superview!.convert(toView.frame, to: containerView)
        }

        var imageView: UIImageView?
        if (isDismissing && !toFrame.isEmpty) || (!isDismissing && !fromFrame.isEmpty) {
            imageView = UIImageView(image: image)
            imageView?.contentMode = .scaleAspectFit
            imageView!.frame = fromFrame
            containerView.addSubview(imageView!)
        }

        cropViewController.view.alpha = isDismissing ? 1 : 0
        if let imageView = imageView {
            UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.7, options: [], animations: {
                imageView.frame = self.toFrame
            }, completion: { _ in
                UIView.animate(withDuration: 0.1, animations: {
                    imageView.alpha = 0
                }, completion: { _ in
                    imageView.removeFromSuperview()
                })
            })
        }

        UIView.animate(withDuration: transitionDuration(using: transitionContext), animations: {
            cropViewController.view.alpha = self.isDismissing ? 0 : 1
        }, completion: { _ in
            self.reset()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

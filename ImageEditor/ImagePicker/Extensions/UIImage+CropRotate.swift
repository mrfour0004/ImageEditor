//
//  UIImage+CropRotate.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/17.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

extension UIImage {
    var hasAlpha: Bool {
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        return [.first, .last, .premultipliedLast, .premultipliedFirst].contains(alphaInfo)
    }

    func cropped(with frame: CGRect, angle: Int) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(frame.size, hasAlpha, scale)

        guard let context = UIGraphicsGetCurrentContext() else { return self }

        if angle != 0 {
            let imageView = UIImageView(image: self)
            imageView.layer.minificationFilter = kCAFilterNearest
            imageView.layer.magnificationFilter = kCAFilterNearest
            imageView.transform = CGAffineTransform.identity.rotated(by: CGFloat(angle) * (CGFloat.pi/CGFloat(180.0)))

            let rotatedRect = imageView.bounds.applying(imageView.transform)
            let containerView = UIView(frame: CGRect(origin: .zero, size: rotatedRect.size))
            containerView.addSubview(imageView)
            imageView.center = containerView.center
            context.translateBy(x: -frame.origin.x, y: -frame.origin.y)
            containerView.layer.render(in: context)
        } else {
            context.translateBy(x: -frame.origin.x, y: -frame.origin.y)
            draw(at: .zero)
        }

        guard let croppedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return self
        }

        UIGraphicsEndImageContext();
        return UIImage(cgImage: croppedImage.cgImage!, scale: UIScreen.main.scale, orientation: .up)
    }
}

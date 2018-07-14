//
//  UIImage+Extension.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/14.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

extension UIImage {

    /// Creates a new image with the passed in color.
    ///
    /// - Parameter color: The UIColor to create the image from.
    /// - Returns: A UIImage that is the color passed in.
    func tint(with color: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: 0.0, y: -size.height)

        context.setBlendMode(.multiply)

        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        context.clip(to: rect, mask: cgImage!)
        color.setFill()
        context.fill(rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image?.withRenderingMode(.alwaysOriginal)
    }

    /// Resizes an image based on a given width.
    ///
    /// - Parameter width: The given width.
    /// - Returns: /// - Returns: An optional resized UIImage.
    func resize(toWidth width: CGFloat) -> UIImage? {
        return resize(to: CGSize(width: width, height: 0))
    }

    /// Resizes an image based on a given height.
    ///
    /// - Parameter height: The given height.
    /// - Returns: An optional resized UIImage.
    func resize(toHeight height: CGFloat) -> UIImage? {
        return resize(to: CGSize(width: 0, height: height))
    }

    /// Resizes the image.
    private func resize(to toSize: CGSize) -> UIImage? {
        var w: CGFloat?
        var h: CGFloat?

        if 0 < toSize.width {
            h = size.height * toSize.width / size.width
        } else if 0 < toSize.height {
            w = size.width * toSize.height / size.height
        }

        let g: UIImage?
        let t: CGRect = CGRect(x: 0, y: 0, width: w ?? toSize.width, height: h ?? toSize.height)
        UIGraphicsBeginImageContextWithOptions(t.size, false, UIScreen.main.scale)
        draw(in: t, blendMode: .normal, alpha: 1)
        g = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return g
    }
}

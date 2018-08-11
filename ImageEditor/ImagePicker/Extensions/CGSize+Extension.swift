//
//  CGSize+Extension.swift
//  ImageEditor
//
//  Created by mrfour on 2018/8/11.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

extension CGSize {
    func resizedToFit(width: CGFloat) -> CGSize {
        return resized(toFit: CGSize(width: width, height: height))
    }

    func resizedToFit(height: CGFloat) -> CGSize {
        return resized(toFit: CGSize(width: 0, height: height))
    }

    func resized(toFit toSize: CGSize) -> CGSize {
        var w: CGFloat = toSize.width
        var h: CGFloat = toSize.height

        if 0 < toSize.width {
            h = height * toSize.width / width
        } else if 0 < toSize.height {
            w = width * toSize.height / height
        }

        return CGSize(width: w, height: h)
    }
}


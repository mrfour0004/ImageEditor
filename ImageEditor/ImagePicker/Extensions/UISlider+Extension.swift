//
//  UISlider+Extension.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/31.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

extension UISlider {
    var trackRect: CGRect {
        return trackRect(forBounds: bounds)
    }

    /// Returns the drawing rectangle for the slider’s track.
    var thumbRect: CGRect {
        let trackRect = self.trackRect(forBounds: bounds)
        return thumbRect(forBounds: bounds, trackRect: trackRect, value: value)
    }
}

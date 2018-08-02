//
//  FlashMode+UIImage.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/14.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit
import AVFoundation

extension AVCaptureDevice.FlashMode {
    var icon: UIImage {
        switch self {
        case .auto:
            return #imageLiteral(resourceName: "ic_flashlight_auto_white100")
        case .on:
            return #imageLiteral(resourceName: "ic_flashlight_on_white100")
        case .off:
            return #imageLiteral(resourceName: "ic_flashlight_off_white100")
        }
    }

    /// Switch to the next `FlashMode`.
    mutating func `switch`() {
        guard let newMode = AVCaptureDevice.FlashMode(rawValue: (rawValue + 2) % 3) else { return }
        self = newMode
    }
}

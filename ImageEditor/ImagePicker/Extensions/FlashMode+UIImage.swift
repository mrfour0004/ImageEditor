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
            return .flashAuto
        case .on:
            return .flashOn
        case .off:
            return .flashOff
        }
    }

    /// Switch to the next `FlashMode`.
    mutating func swith() {
        guard let newMode = AVCaptureDevice.FlashMode(rawValue: (rawValue + 1) % 3) else { return }
        self = newMode
    }
}

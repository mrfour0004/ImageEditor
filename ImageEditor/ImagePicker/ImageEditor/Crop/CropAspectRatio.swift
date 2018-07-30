//
//  CropAspectRatio.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/27.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

enum CropAspectRatioPreset {
    case original
    case square
    case custom(CGSize)
    case ratio3x2
    case ratio5x4
    case ratio7x5
    case ratio16x9
}

extension CropAspectRatioPreset {
    var aspectRatio: CGSize {
        switch self {
        case .original:
            return .zero
        case .square:
            return CGSize(width: 1, height: 1)
        case .ratio3x2:
            return CGSize(width: 3, height: 2)
        case .ratio5x4:
            return CGSize(width: 5, height: 4)
        case .ratio7x5:
            return CGSize(width: 7, height: 5)
        case .ratio16x9:
            return CGSize(width: 16, height: 9)
        case .custom(let size):
            return size
        }
    }

    var isCustom: Bool {
        switch self {
        case .custom:
            return true
        default:
            return false
        }
    }
}

// MARK: - Equatable

extension CropAspectRatioPreset: Equatable {
    static func ==(lhs: CropAspectRatioPreset, rhs: CropAspectRatioPreset) -> Bool {
        switch (lhs, rhs) {
        case (.original, original), (.square, .square), (.ratio3x2, .ratio3x2), (.ratio5x4, .ratio5x4), (.ratio7x5, .ratio7x5), (.ratio16x9, .ratio16x9):
            return true
        case let (.custom(lsize), .custom(rsize)):
            return (lsize.width/lsize.height) - (rsize.width/rsize.height) < CGFloat.ulpOfOne
        default:
            return false
        }
    }
}

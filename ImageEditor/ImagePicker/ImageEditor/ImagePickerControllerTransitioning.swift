//
//  ImagePickerControllerTransitioning.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/17.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImagePickerControllerTransitioning: NSObject {
    
}

extension ImagePickerControllerTransitioning: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.45
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {

    }
}

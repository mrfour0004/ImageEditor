//
//  ImageEditorControlButton.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/24.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class ImageEditorControlButton: UIButton {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        animate(transform: CGAffineTransform(scaleX: 0.9, y: 0.9))
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        animate(transform: .identity)
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        animate(transform: .identity)
        super.touchesCancelled(touches, with: event)
    }

    private func animate(transform: CGAffineTransform) {
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
            self.transform = transform
        }, completion: nil)
    }
}

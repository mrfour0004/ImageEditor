//
//  CropScrollView.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/18.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class CropScrollView: UIScrollView {

    // MARK: - Properties

    var touchesBegan: (() -> Void)?
    var touchesCancelled: (() -> Void)?
    var touchesEnded: (() -> Void)?

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        if #available(iOS 11.0, *) {
            contentInsetAdjustmentBehavior = .never
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Touches Methods

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan?()
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded?()
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesCancelled?()
        super.touchesCancelled(touches, with: event)
    }

}

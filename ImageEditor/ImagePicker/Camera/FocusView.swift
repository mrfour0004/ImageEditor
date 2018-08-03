//
//  FocusView.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/14.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class FocusView: UIView {

    // MARK: - View Lifecycle

    init() {
        super.init(frame: CGRect(origin: .zero, size: LayoutConfig.size))
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup Views

    func setup() {
        isUserInteractionEnabled = false
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 1.5
        layer.cornerRadius = LayoutConfig.size.height / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = .zero
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 1
    }

    // MARK: - Methods

    func show(on superview: UIView, atPoint point: CGPoint) -> FocusView {
        superview.addSubview(self)
        superview.bringSubview(toFront: self)

        center = point

        transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        alpha = 0
        UIView.transition(with: self, duration: 0.4, options: [.curveEaseInOut], animations: {
            self.transform = .identity
            self.alpha = 1
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                self.dismiss()
            })
        })

        return self
    }

    func dismiss() {
        UIView.animate(withDuration: 0.1, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}

// MARK: - Configuration

private extension FocusView {
    enum LayoutConfig {
        static let size = CGSize(width: 60, height: 60)
    }
}

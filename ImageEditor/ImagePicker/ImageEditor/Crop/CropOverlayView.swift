//
//  CropOverlayView.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/19.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

class CropOverlayView: UIView {

    // MARK: - Properteis

    private var _isGridHidden: Bool = true
    var isGridHidden: Bool {
        get { return _isGridHidden }
        set { setGridHidden(newValue, animated: false) }
    }

    var displayHorizontalGridLines = true {
        didSet {
            horizontalGridLines.forEach { $0.removeFromSuperview() }
            horizontalGridLines = displayHorizontalGridLines ? makeNewLineViews(count: 2) : []
            setNeedsDisplay()
        }
    }
    var displayVerticalGridLines = true {
        didSet {
            verticalGridLines.forEach { $0.removeFromSuperview() }
            verticalGridLines = displayVerticalGridLines ? makeNewLineViews(count: 2) : []
            setNeedsDisplay()
        }
    }

    override var frame: CGRect {
        didSet {
            layoutLines()
        }
    }

    // MARK: - Grid Lines

    private var horizontalGridLines: [UIView] = []
    private var verticalGridLines: [UIView] = []

    private var outerLineViews: [UIView] = [] // top, right, bottom, left

    private var topLeftLineViews: [UIView] = [] // vertical, horizontal
    private var bottomLeftLineViews: [UIView] = []
    private var bottomRightLineViews: [UIView] = []
    private var topRightLineViews: [UIView] = []

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        layoutLines()
    }

    // MARK: - Public Methods

    func setGridHidden(_ isHidden: Bool, animated: Bool) {
        _isGridHidden = isHidden
        let animations: () -> Void = {
            self.horizontalGridLines.forEach { line in
                line.alpha = isHidden ? 0 : 1
            }
            self.verticalGridLines.forEach { line in
                line.alpha = isHidden ? 0 : 1
            }
        }

        guard animated else { return animations() }
        UIView.animate(withDuration: isHidden ? 0.35 : 0.2, animations: animations)
    }
}

// MARK: - Setup Views

private extension CropOverlayView {
    func setup() {
        outerLineViews = makeNewLineViews(count: 4)
        topLeftLineViews = makeNewLineViews(count: 2)
        bottomLeftLineViews = makeNewLineViews(count: 2)
        topRightLineViews = makeNewLineViews(count: 2)
        bottomRightLineViews = makeNewLineViews(count: 2)

        displayHorizontalGridLines = true
        displayVerticalGridLines = true
    }

    func layoutLines() {
        guard !outerLineViews.isEmpty else { return }


        layoutOuterLines()
        layoutCornerLines()
        layoutGridLines()

    }

    func layoutOuterLines() {
        let boundsSize = bounds.size
        for (index, lineView) in outerLineViews.enumerated() {
            switch index {
            case 0: lineView.frame = CGRect(x: 0, y: -1, width: boundsSize.width + 2, height: 1)
            case 1: lineView.frame = CGRect(x: boundsSize.width, y: 0, width: 1, height: boundsSize.height)
            case 2: lineView.frame = CGRect(x: -1, y: boundsSize.height, width: boundsSize.width + 2, height: 1)
            case 3: lineView.frame = CGRect(x: -1, y: 0, width: 1, height: boundsSize.height + 1)
            default: break
            }
        }
    }

    func layoutCornerLines() {
        let boundsSize = bounds.size
        let cornerLines = [topLeftLineViews, topRightLineViews, bottomRightLineViews, bottomLeftLineViews]
        for lines in cornerLines {
            var verticalFrame: CGRect = .zero
            var horizontalFrame: CGRect = .zero

            switch lines {
            case topLeftLineViews:
                verticalFrame = CGRect(x: -3, y: -3, width: 3, height: Const.overlayCornerWidth)
                horizontalFrame = CGRect(x: 0, y: -3, width: Const.overlayCornerWidth, height: 3)
            case topRightLineViews:
                verticalFrame = CGRect(x: boundsSize.width, y: -3, width: 3, height: Const.overlayCornerWidth + 3)
                horizontalFrame = CGRect(x: boundsSize.width - Const.overlayCornerWidth, y: -3, width: Const.overlayCornerWidth, height: 3)
            case bottomRightLineViews:
                verticalFrame = CGRect(x: boundsSize.width, y: boundsSize.height - Const.overlayCornerWidth, width: 3, height: Const.overlayCornerWidth + 3)
                horizontalFrame = CGRect(x: boundsSize.width - Const.overlayCornerWidth, y: boundsSize.height, width: Const.overlayCornerWidth, height: 3)
            case bottomLeftLineViews:
                verticalFrame = CGRect(x: -3, y: boundsSize.height - Const.overlayCornerWidth, width: 3, height: Const.overlayCornerWidth)
                horizontalFrame = CGRect(x: -3, y: boundsSize.height, width: Const.overlayCornerWidth + 3, height: 3)
            default: break
            }
            lines[0].frame = verticalFrame
            lines[1].frame = horizontalFrame
        }
    }

    func layoutGridLines() {
        let thickness: CGFloat = CGFloat(1) / UIScreen.main.scale
        var numberOfLines: Int = horizontalGridLines.count
        var padding: CGFloat = (bounds.height - thickness*CGFloat(numberOfLines)) / (CGFloat(numberOfLines) + 1)

        for (index, line) in horizontalGridLines.enumerated() {
            let i = CGFloat(index)
            line.frame = CGRect(x: 0, y: (padding*(i+1) + thickness*i), width: bounds.width, height: thickness)
        }

        numberOfLines = verticalGridLines.count
        padding = (bounds.width - thickness*CGFloat(numberOfLines)) / (CGFloat(numberOfLines) + 1)
        for (index, line) in verticalGridLines.enumerated() {
            let i = CGFloat(index)
            line.frame = CGRect(x: (padding*(i + 1) + thickness*i), y: 0, width: thickness, height: bounds.height)
        }
    }
}

// MARK: - Private Methods

private extension CropOverlayView {
    func makeNewLineView() -> UIView {
        let lineView = UIView(frame: .zero)
        lineView.backgroundColor = .white
        addSubview(lineView)
        return lineView
    }

    func makeNewLineViews(count: Int) -> [UIView] {
        guard count > 0 else { return [] }
        return Array(0..<count).map { _ in makeNewLineView() }
    }
}

// MARK: - Configuration

private extension CropOverlayView {
    enum Const {
        static let overlayCornerWidth: CGFloat = 20
    }
}

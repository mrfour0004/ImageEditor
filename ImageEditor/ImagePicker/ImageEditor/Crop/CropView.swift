//
//  CropView.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/18.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

protocol CropViewDelegate: AnyObject {
    func cropViewDidBecomeResettable(_ cropView: CropView)
    func cropViewDidBecomeNonResettable(_ cropView: CropView)
}

class CropView: UIView {

    // MARK: - Public Properties

    enum OverlayEdge {
        case none
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    }

    weak var delegate: CropViewDelegate?

    /// Inset the workable region of the crop view in case in order to make space for accessory views
    var cropRegionInset: UIEdgeInsets = .zero

    /// Set the grid overlay graphic to be hidden
    var isGridOverlayHidden = false

    ///  When performing manual content layout (such as during screen rotation), disable any internal layout
    var isInternalLayoutDisabled = false

    /// In relation to the coordinate space of the image, the frame that the crop view is focusing on
    var imageCropFrame: CGRect {
        get {
            let imageSize = image.size
            let contentSize = scrollView.contentSize
            let cropBoxFrame = self.cropBoxFrame
            let contentOffset = scrollView.contentOffset
            let edgeInsets = scrollView.contentInset

            var frame: CGRect = .zero
            frame.origin.x = max(0, floor((contentOffset.x + edgeInsets.left) * (imageSize.width / contentSize.width)))
            frame.origin.y = max(0, floor((contentOffset.y + edgeInsets.top) * (imageSize.height / contentSize.height)))
            frame.size.width = min(imageSize.width, ceil(cropBoxFrame.width * (imageSize.width / contentSize.width)))
            frame.size.height = min(imageSize.height, ceil(cropBoxFrame.height * (imageSize.height / contentSize.height)))

            return frame
        }
        set {
            guard superview != nil else {
                restoreImageCropFrame = newValue
                return
            }
            updateToImageCropFrame(newValue)
        }
    }


    // MARK: - Properties

    private let image: UIImage

    /// The rotation angle of the crop view (Will always be negative as it rotates in a counter-clockwise direction)
    var angle: Int = 0
    private var isEditing: Bool = false
    private var cropBoxResizeEnabled = false

    /// A width x height ratio that the crop box will be rescaled to (eg 4:3 is {4.0f, 3.0f})
    /// Setting it to CGSizeZero will reset the aspect ratio to the image's own ratio.
    var aspectRatio: CGSize = .zero

    /// When the cropping box is locked to its current aspect ratio (But can still be resized)
    var isAspectRatioLockEnabled: Bool = false

    private var dynamicBlurEffect = true

    /// If restoring to  a previous crop setting, these properties hang onto the values until the view is configured for the first time.
    private var restoreAngle = 0
    private var restoreImageCropFrame: CGRect = .zero
    

    // MARK: - Properties - Rotation State

    /// When performing 90-degree rotations, remember what our last manual size was to use that as a base.
    private var cropBoxLastEditedSize: CGSize = .zero

    /// Remember the zoom size when we last edited
    private lazy var cropBoxLastEditedZoomScale: CGFloat = scrollView.zoomScale

    /// Remember the minimum zoom size when we last edited.
    private lazy var cropBoxLastEditedMinZoomScale: CGFloat = scrollView.minimumZoomScale

    /// Remember which angle we were at when we saved the editing size
    private var cropBoxLastEditedAngle: Int = 0
    private var rotateAnimationInProgress = false


    // MARK: - Properties - Crop Box Handling

    /// The edge region that the user tapped on, to resize the cropping region
    private var tappedEdge: OverlayEdge = .none

    /// When resizing, this is the original frame of the crop box.
    private var cropOriginFrame: CGRect?

    /// The initial touch point of the pan gesture recognizer
    private var panOriginPoint: CGPoint?

    /// At times during animation, disable matching the forground image view to the background
    private var disableForgroundMatching = false

    private var resetTimer: Timer?

    private var _cropBoxFrame: CGRect = .zero
    private var cropBoxFrame: CGRect {
        get { return _cropBoxFrame }
        set { setCropBoxFrame(newValue) }
    }

    // MARK: - Properteis - Gesture Recognizers

    private var gridPanGestureRecognizer: UIPanGestureRecognizer!


    // MARK: - Properties - Reset State

    private var originalCropBoxSize: CGSize = .zero
    private lazy var originalContentOffset = scrollView.contentOffset
    private var canBeReset = false {
        didSet {
            guard canBeReset != oldValue else { return }
            if canBeReset {
                delegate?.cropViewDidBecomeResettable(self)
            } else {
                delegate?.cropViewDidBecomeNonResettable(self)
            }
        }
    }

    // MARK: - Properteis - Views

    var scrollView: CropScrollView!

    /// The main image view, placed within the scroll view
    private var backgroundImageView: UIImageView!

    /// A view which contains the background image view, to separate its transforms from the scroll view.
    private var backgroundContainerView: UIView!

    /// A copy of the background image view, placed over the dimming views
    private var foregroundImageView: UIImageView!

    /// A container view that clips the foreground image view to the crop box frame
    private var foregroundContainerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 200, height: 200)))

    /// A semi-transparent grey view, overlaid on top of the background image
    private var overlayView: UIView!

    /// A blur view that is made visible when the user isn't interacting with the crop view
    private lazy var translucencyView = UIVisualEffectView(effect: translucencyEffect)
    private lazy var translucencyEffect = UIBlurEffect(style: .dark)

    private var gridOverlayView: CropOverlayView!


    // MARK: - Lifecycle

    init(image: UIImage) {
        self.image = image
        super.init(frame: .zero)

        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @available(iOS 11.0, *)
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        layoutInitialImage()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard superview != nil else { return }
        
        layoutInitialImage()

        //If the angle value was previously set before this point, apply it now
        if restoreAngle != 0 {
            angle = restoreAngle
            restoreAngle = 0
        }

        if !restoreImageCropFrame.isEmpty {
            imageCropFrame = restoreImageCropFrame
            restoreImageCropFrame = .zero
        }

        //Check if we performed any resetabble modifications
        checkForCanReset()
    }

    // MARK: - Public Methods

    func setBackgroundImageViewHidden(_ isHidden: Bool, animated: Bool) {
        guard animated else {
            backgroundImageView.isHidden = isHidden
            return
        }

        backgroundImageView.isHidden = false
        backgroundImageView.alpha = isHidden ? 1 : 0
        UIView.animate(withDuration: 0.5, animations: {
            self.backgroundImageView.alpha = isHidden ? 0 : 1
        }, completion: { _ in
            guard isHidden else { return }
            self.backgroundImageView.isHidden = true
        })
    }

    func setGridOverlayHidden(_ isHidden: Bool, animated: Bool) {

    }

    var cropBoxAspectRatioIsPortrait: Bool {
        let cropFrame = self.cropBoxFrame
        return cropFrame.width < cropFrame.height
    }

    // MARK: - Timer

    func cropEdge(for point: CGPoint) -> CropView.OverlayEdge {
        var frame = cropBoxFrame
        frame = frame.insetBy(dx: -32, dy: -32)

        let topLeftRect = CGRect(origin: frame.origin, size: CGSize(width: 64, height: 64))
        if topLeftRect.contains(point) {
            return .topLeft
        }

        var topRightRect = topLeftRect
        topRightRect.origin.x = frame.maxX - 64
        if topRightRect.contains(point) {
            return .topRight
        }

        var bottomLeftRect = topLeftRect
        bottomLeftRect.origin.y = frame.maxY - 64
        if bottomLeftRect.contains(point) {
            return .bottomLeft
        }

        var bottomRightRect = topRightRect
        bottomRightRect.origin.y = bottomLeftRect.origin.y
        if bottomRightRect.contains(point) {
            return .bottomRight
        }

        let topRect = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: 64))
        if topRect.contains(point) {
            return .top
        }

        var bottomRect = topRect
        bottomRect.origin.y = frame.maxY - 64
        if bottomRect.contains(point) {
            return .bottom
        }

        let leftRect = CGRect(origin: frame.origin, size: CGSize(width: 64, height: frame.height))
        if leftRect.contains(point) {
            return .left
        }

        var rightRect = leftRect
        rightRect.origin.x = frame.maxX - 64
        if rightRect.contains(point) {
            return .right
        }

        return .none
    }

}

// MARK: - Setup Views

private extension CropView {

    func setup() {
        autoresizingMask = [.flexibleHeight, .flexibleWidth]
        backgroundColor = UIColor(white: 0.12, alpha: 0.12)

        setupScrollView()
        setupBackgroundContainerView()
        setupOverlayView()
        setupTranslucencyView()
        setupForegroundContainerView()
        setupGridOverlayView()
        setupGestures()
    }

    func setupScrollView() {
        scrollView = CropScrollView(frame: bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false
        scrollView.delegate = self
        addSubview(scrollView)

        scrollView.touchesBegan = { [weak self] in
            self?.startEditing()
        }
        scrollView.touchesEnded = { [weak self] in
            self?.startResetTimer()
        }
    }

    func setupBackgroundContainerView() {
        backgroundImageView = UIImageView(image: image)
        backgroundImageView.layer.minificationFilter = kCAFilterTrilinear

        backgroundContainerView = UIView(frame: backgroundImageView.frame)
        backgroundContainerView.addSubview(backgroundImageView)
        scrollView.addSubview(backgroundContainerView)
    }

    func setupOverlayView() {
        overlayView = UIView(frame: bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlayView.backgroundColor = backgroundColor?.withAlphaComponent(0.35)
        overlayView.isHidden = false
        overlayView.isUserInteractionEnabled = false
        addSubview(overlayView)
    }

    func setupTranslucencyView() {
        translucencyView.frame = bounds
        translucencyView.isHidden = false
        translucencyView.isUserInteractionEnabled = false
        translucencyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(translucencyView)
    }

    func setupForegroundContainerView() {
        foregroundContainerView.clipsToBounds = true
        foregroundContainerView.isUserInteractionEnabled = false
        addSubview(foregroundContainerView)

        foregroundImageView = UIImageView(image: image)
        foregroundImageView.layer.minificationFilter = kCAFilterTrilinear
        foregroundContainerView.addSubview(foregroundImageView)
    }

    func setupGridOverlayView() {
        gridOverlayView = CropOverlayView(frame: foregroundContainerView.frame)
        gridOverlayView.isUserInteractionEnabled = false
        gridOverlayView.isGridHidden = true
        addSubview(gridOverlayView)
    }

    func setupGestures() {
        gridPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(gridPanGestureRecognized))
        gridPanGestureRecognizer.delegate = self
        scrollView.panGestureRecognizer.require(toFail: gridPanGestureRecognizer)
        addGestureRecognizer(gridPanGestureRecognizer)
    }
}

// MARK: - View Layout

private extension CropView {
    func layoutInitialImage() {
        let imageSize = image.size
        scrollView.contentSize = imageSize

        let bounds = contentBounds
        let boundsSize = bounds.size

        var scale = min(bounds.width/imageSize.width, bounds.height/imageSize.height)
        let scaledImageSize = CGSize(width: floor(imageSize.width * scale), height: floor(imageSize.height * scale))

        var cropBoxSize: CGSize = .zero
        if hasAspectRatio {
            let ratioScale = aspectRatio.width / aspectRatio.height
            let fullSizeRatio = CGSize(width: boundsSize.height * ratioScale, height: boundsSize.height)
            let fitScale = min(boundsSize.width / fullSizeRatio.width, boundsSize.height / fullSizeRatio.height)

            cropBoxSize = CGSize(width: fullSizeRatio.width * fitScale, height: fullSizeRatio.height * fitScale)
            scale = max(cropBoxSize.width / imageSize.width, cropBoxSize.height / imageSize.height)
        }

        let scaledSize = CGSize(width: floor(imageSize.width * scale), height: floor(imageSize.height * scale))
        scrollView.minimumZoomScale = scale
        scrollView.maximumZoomScale = 15

        var frame: CGRect = .zero
        frame.size = hasAspectRatio ? cropBoxSize : scaledSize
        frame.origin.x = bounds.origin.x + floor((bounds.width - frame.width) * CGFloat(0.5))
        frame.origin.y = bounds.origin.y + floor((bounds.height - frame.height) * CGFloat(0.5))
        cropBoxFrame = frame

        scrollView.zoomScale = scrollView.minimumZoomScale
        scrollView.contentSize = scaledSize

        // If we ended up with a smaller crop box than the content, offset it in the middle
        if (frame.width < scaledSize.width - CGFloat.ulpOfOne || frame.size.height < scaledSize.height - CGFloat.ulpOfOne) {
            var offset: CGPoint = .zero
            offset.x = -floor((scrollView.frame.width - scaledSize.width) * 0.5)
            offset.y = -floor((scrollView.frame.height - scaledSize.height) * 0.5)
            scrollView.contentOffset = offset
        }

        cropBoxLastEditedAngle = 0
        captureStateForImageRotation()

        originalCropBoxSize = scaledImageSize
        originalContentOffset = scrollView.contentOffset

        checkForCanReset()
        matchForegroundToBackground()
    }

    func prepareForRotation() {

    }

    func matchForegroundToBackground() {
        guard !disableForgroundMatching else { return }

        if let backgroundContainerSuperview = backgroundContainerView.superview {
            foregroundImageView.frame = backgroundContainerSuperview.convert(backgroundContainerView.frame, to: foregroundContainerView)
        }
    }

    func updateToImageCropFrame(_ imageCropFrame: CGRect) {
        //Convert the image crop frame's size from image space to the screen space
        let minimumSize = scrollView.minimumZoomScale
        let scaledOffset = CGPoint(x: imageCropFrame.origin.x * minimumSize, y: imageCropFrame.origin.y * minimumSize)
        let scaledCropSize = CGSize(width: imageCropFrame.width * minimumSize, height: imageCropFrame.height * minimumSize)

        // Work out the scale necessary to upscale the crop size to fit the content bounds of the crop bound
        let bounds = contentBounds
        let scale = min(bounds.width / scaledCropSize.width, bounds.height / scaledCropSize.height)

        // Zoom into the scroll view to the appropriate size
        scrollView.zoomScale = scrollView.minimumZoomScale * scale

        // Work out the size and offset of the upscaed crop box
        var frame = CGRect(origin: .zero, size: CGSize(width: scaledCropSize.width * scale, height: scaledCropSize.height * scale))

        // set the crpo box
        var cropBoxFrame: CGRect = .zero
        cropBoxFrame.size = frame.size
        cropBoxFrame.origin.x = (bounds.width - frame.width) * 0.5
        cropBoxFrame.origin.y = (bounds.height - frame.height) * 0.5
        self.cropBoxFrame = cropBoxFrame

        frame.origin.x = (scaledOffset.x * scale) - scrollView.contentInset.left
        frame.origin.y = (scaledOffset.y * scale) - scrollView.contentInset.top
        scrollView.contentOffset = frame.origin
    }

    private func toggleTranslucencyViewVisible(_ isVisible: Bool) {
        guard dynamicBlurEffect else {
            translucencyView.alpha = isVisible ? 1 : 0
            return
        }

        translucencyView.effect = isVisible ? translucencyEffect : nil
    }

}

// MARK: - Editing Mode

extension CropView {
    private func startEditing() {
        cancelResetTimer()
        setEditing(true, animated: true)
    }

    private func setEditing(_ isEditing: Bool, animated: Bool) {
        guard self.isEditing != isEditing else { return }
        self.isEditing = isEditing

        gridOverlayView.setGridHidden(!isEditing, animated: true)

        if !isEditing {
            moveCroppedContentToCenter(animated: animated)
            captureStateForImageRotation()
            cropBoxLastEditedAngle = angle
        }

        guard animated else {
            return toggleTranslucencyViewVisible(!isEditing)
        }

        let duration = isEditing ? 0.5 : 0.35
        let delay = isEditing ? 0 : 0.35

        UIView.animateKeyframes(withDuration: duration, delay: delay, options: [], animations: {
            self.toggleTranslucencyViewVisible(!isEditing)
        }, completion: nil)
    }

    private func captureStateForImageRotation() {
        cropBoxLastEditedSize = cropBoxFrame.size
        cropBoxLastEditedZoomScale = scrollView.zoomScale
        cropBoxLastEditedMinZoomScale = scrollView.minimumZoomScale
    }

    private func updateCropBoxFrame(with gesturePoint: CGPoint) {
        guard let panOriginPoint = panOriginPoint, let originFrame = cropOriginFrame else { return }
        var frame = cropBoxFrame
        let contentFrame = contentBounds

        var point = gesturePoint
        point.x = max(contentFrame.origin.x, point.x)
        point.y = max(contentFrame.origin.y, point.y)

        var xDelta = ceil(point.x - panOriginPoint.x)
        var yDelta = ceil(point.y - panOriginPoint.y)

        let aspectRatio = originFrame.width / originFrame.height
        var isAspectHorizontal: Bool = false
        var isAspectVertical: Bool = false

        var clampMinFromTop = false
        var clampMinFromLeft = false

        switch tappedEdge {
        case .left:
            if isAspectRatioLockEnabled {
                isAspectHorizontal = true
                xDelta = max(xDelta, 0)
                let scaleOrigin = CGPoint(x: originFrame.maxX, y: originFrame.midY)
                frame.size.height = frame.size.width / aspectRatio
                frame.origin.y = scaleOrigin.y - frame.height*CGFloat(0.5)
            }

            frame.origin.x = originFrame.origin.x + xDelta
            frame.size.width = originFrame.width - xDelta

            clampMinFromLeft = true
        case .right where isAspectRatioLockEnabled:
            isAspectHorizontal = true
            let scaleOrigin = CGPoint(x: originFrame.minX, y: originFrame.midY)
            frame.size.height = frame.size.width / aspectRatio
            frame.origin.y = scaleOrigin.y - frame.height*CGFloat(0.5)
            frame.size.width = originFrame.width + xDelta
            frame.size.width = min(frame.width, contentFrame.height * aspectRatio)
        case .right:
            frame.size.width = originFrame.width + xDelta
        case .bottom where isAspectRatioLockEnabled:
            isAspectVertical = true
            let scaleOrigin = CGPoint(x: originFrame.midX, y: originFrame.minY)
            frame.size.width = frame.height * aspectRatio
            frame.origin.x = scaleOrigin.x - frame.width*CGFloat(0.5)
            frame.size.height = originFrame.height + yDelta
            frame.size.height = min(frame.height, contentFrame.width / aspectRatio)
        case .bottom:
            frame.size.height = originFrame.height + yDelta
        case .top where isAspectRatioLockEnabled:
            isAspectVertical = true
            yDelta = max(0, yDelta)

            let scaleOrigin = CGPoint(x: originFrame.midX, y: originFrame.maxY)
            frame.size.width = frame.size.height * aspectRatio
            frame.origin.x = scaleOrigin.x - frame.width*0.5
            frame.origin.y    = originFrame.origin.y + yDelta
            frame.size.height = originFrame.height - yDelta
            clampMinFromTop = true
        case .top:
            frame.origin.y = originFrame.origin.y + yDelta
            frame.size.height = originFrame.height - yDelta
            clampMinFromTop = true
        case .topLeft where isAspectRatioLockEnabled:
            xDelta = max(xDelta, 0)
            yDelta = max(yDelta, 0)

            var distance: CGPoint = .zero
            distance.x = CGFloat(1.0) - (xDelta / originFrame.width)
            distance.y = CGFloat(1.0) - (yDelta / originFrame.height)

            let scale: CGFloat = (distance.x + distance.y) * CGFloat(0.5)

            frame.size.width = ceil(originFrame.width * scale)
            frame.size.height = ceil(originFrame.height * scale)
            frame.origin.x = originFrame.origin.x + (originFrame.width - frame.width)
            frame.origin.y = originFrame.origin.y + (originFrame.height - frame.size.height)

            isAspectVertical = true
            isAspectHorizontal = true

            clampMinFromLeft = true
            clampMinFromTop = true
        case .topLeft:
            frame.origin.x = originFrame.origin.x + xDelta
            frame.size.width = originFrame.width - xDelta
            clampMinFromLeft = true
            clampMinFromTop = true
        case .topRight where isAspectRatioLockEnabled:
            xDelta = min(xDelta, 0)
            yDelta = max(yDelta, 0)

            var distance: CGPoint = .zero
            distance.x = CGFloat(1.0) - (-xDelta / originFrame.width)
            distance.y = CGFloat(1.0) - (yDelta / originFrame.height)

            let scale = (distance.x + distance.y) * CGFloat(0.5)

            frame.size.width = ceil(originFrame.width * scale)
            frame.size.height = ceil(originFrame.height * scale)
            frame.origin.y = originFrame.origin.y + (originFrame.height - frame.size.height)

            isAspectVertical = true
            isAspectHorizontal = true
            clampMinFromTop = true
        case .topRight:
            frame.size.width = originFrame.width + xDelta
            frame.origin.y = originFrame.origin.y + yDelta
            frame.size.height = originFrame.height - yDelta
            clampMinFromTop = true
        case .bottomLeft where isAspectRatioLockEnabled:
            var distance: CGPoint = .zero
            distance.x = 1.0 - (xDelta / originFrame.width)
            distance.y = 1.0 - (-yDelta / originFrame.height)

            let scale: CGFloat = (distance.x + distance.y) * CGFloat(0.5)

            frame.size.width = ceil(originFrame.width * scale)
            frame.size.height = ceil(originFrame.height * scale)
            frame.origin.x = originFrame.maxX - frame.width

            isAspectVertical = true
            isAspectHorizontal = true
            clampMinFromLeft = true
        case .bottomLeft:
            frame.size.height = originFrame.height + yDelta
            frame.origin.x = originFrame.origin.x + xDelta
            frame.size.width = originFrame.width - xDelta
            clampMinFromLeft = true
        case .bottomRight where isAspectRatioLockEnabled:
            var distance: CGPoint = .zero
            distance.x = CGFloat(1.0) - (-xDelta)/originFrame.width
            distance.y = CGFloat(1.0) - (-yDelta)/originFrame.height

            let scale = (distance.x + distance.y) * CGFloat(0.5)
            frame.size.width = ceil(originFrame.width * scale)
            frame.size.height = ceil(originFrame.height * scale)

            isAspectVertical = true
            isAspectHorizontal = true
        case .bottomRight:
            frame.size.height = originFrame.height + yDelta
            frame.size.width = originFrame.width + xDelta
        case .none: break
        }

        var minSize = Const.cropViewMinimumBoxSize
        var maxSize = contentFrame.size

        if isAspectRatioLockEnabled && isAspectHorizontal {
            maxSize.height = contentFrame.width / aspectRatio
            minSize.width = Const.cropViewMinimumBoxSize.width / aspectRatio
        }

        if isAspectRatioLockEnabled && isAspectVertical {
            maxSize.width = contentFrame.height / aspectRatio
            minSize.height = Const.cropViewMinimumBoxSize.height / aspectRatio
        }

        frame.size.width = max(frame.width, minSize.width)
        frame.size.height = max(frame.height, minSize.height)

        frame.size.width = min(frame.width, maxSize.width)
        frame.size.height = min(frame.height, maxSize.height)

        frame.origin.x = max(frame.origin.x, contentFrame.minX)
        frame.origin.x = min(frame.origin.x, contentFrame.maxX - minSize.width)

        frame.origin.y = max(frame.origin.y, contentFrame.minY)
        frame.origin.y = min(frame.origin.y, contentFrame.maxY - minSize.height)

        if clampMinFromLeft && frame.width <= minSize.width + CGFloat.ulpOfOne {
            frame.origin.x = originFrame.maxX - minSize.width
        }

        if clampMinFromTop && frame.height <= minSize.height + CGFloat.ulpOfOne {
            frame.origin.y = originFrame.maxY - minSize.height
        }

        cropBoxFrame = frame
        checkForCanReset()
    }

    func rotateCropView(animated: Bool) {
        guard !rotateAnimationInProgress else { return }

        // Cancel any pending resizing timers
        if resetTimer != nil {
            cancelResetTimer()
            setEditing(false, animated: false)
            cropBoxLastEditedAngle = angle
            captureStateForImageRotation()
        }

        angle = (angle + 90) % 360
        let angleRadians = CGFloat(angle) * CGFloat.pi / CGFloat(180)
        let rotation = CGAffineTransform(rotationAngle: angleRadians)

        // Work out how much we'll need to scale everything to fit to the new rotation
        let contentBounds = self.contentBounds
        let cropBoxFrame = self.cropBoxFrame
        let scale = min((contentBounds.width / cropBoxFrame.height), (contentBounds.height / cropBoxFrame.width))
        
        // Work out which section of the image we're currently focusing at
        let cropMidPoint = CGPoint(x: cropBoxFrame.midX, y: cropBoxFrame.midY)
        var cropTargetPoint = CGPoint(x: cropMidPoint.x + scrollView.contentOffset.x, y: cropMidPoint.y + scrollView.contentOffset.y)

        //Work out the dimensions of the crop box when rotated
        var newCropFrame: CGRect = .zero
        if (labs(angle) == labs(cropBoxLastEditedAngle)) || (-labs(angle) == ((labs(cropBoxLastEditedAngle) - 180) % 360)) {
            newCropFrame.size = cropBoxLastEditedSize
            scrollView.minimumZoomScale = cropBoxLastEditedMinZoomScale
            scrollView.zoomScale = cropBoxLastEditedZoomScale
        } else {
            newCropFrame.size = CGSize(width: floor(cropBoxFrame.height * scale), height: floor(cropBoxFrame.width * scale))

            // Re-adjust the scrolling dimensions of the scroll view to match the new size
            scrollView.minimumZoomScale *= scale
            scrollView.zoomScale *= scale
        }

        newCropFrame.origin.x = floor(bounds.width - newCropFrame.width) * CGFloat(0.5)
        newCropFrame.origin.y = floor(bounds.height - newCropFrame.height) * CGFloat(0.5)

        // If we're animated, generate a snapshot view that we'll animate in place of the real view
        var snapshotView: UIView? = nil
        if animated {
            snapshotView = foregroundContainerView.snapshotView(afterScreenUpdates: false)
            snapshotView?.frame = foregroundContainerView.frame
            rotateAnimationInProgress = true
        }

        // Rotate the background image view, inside its container view
        backgroundImageView.transform = rotation

        // Flip the width/height of the container view so it matches the rotated image view's size
        let containerSize = backgroundContainerView.frame.size
        backgroundContainerView.frame = CGRect(origin: .zero, size: CGSize(width: containerSize.height, height: containerSize.width))
        backgroundImageView.frame = CGRect(origin: .zero, size: backgroundImageView.frame.size)

        // Rotate the foreground image view to match
        foregroundContainerView.transform = .identity
        foregroundImageView.transform = rotation

        // Flip the content size of the scroll view to match the rotated bounds
        scrollView.contentSize = backgroundContainerView.frame.size

        // assign the new crop box frame and re-adjust the content to fill it
        self.cropBoxFrame = newCropFrame
        moveCroppedContentToCenter(animated: false)
        newCropFrame = self.cropBoxFrame

        // work out how to line up out point of interest into the middle of the crop box
        cropTargetPoint.x *= scale
        cropTargetPoint.y *= scale

        // swap the target dimensions to match a 90 degree rotation (clockwise or counterclockwise)
        let swap = cropTargetPoint.x
        cropTargetPoint.x = scrollView.contentSize.width - cropTargetPoint.y
        cropTargetPoint.y = swap

        // reapply the translated scroll offset to the scroll view
        let midPoint = CGPoint(x: newCropFrame.midX, y: newCropFrame.midY)
        var offset: CGPoint = .zero
        offset.x = floor(-midPoint.x + cropTargetPoint.x)
        offset.y = floor(-midPoint.y + cropTargetPoint.y)
        offset.x = max(-scrollView.contentInset.left, offset.x)
        offset.y = max(-scrollView.contentInset.top, offset.y)

        // if the scroll view's new scale is 1 and the new offset is equal to the old, will not trigger the delegate 'scrollViewDidScroll:'
        // so we should call the method manually to update the foregroundImageView's frame
        if (offset.x == scrollView.contentOffset.x) && (offset.y == scrollView.contentOffset.y) && (scale == 1) {
           matchForegroundToBackground()
        }
        scrollView.contentOffset = offset

        // if we're animated, play an animation of the snapshot view rotating, then fade it out over the live content
        if let snapshotView = snapshotView, animated {
            addSubview(snapshotView)

            backgroundContainerView.isHidden = true
            foregroundContainerView.isHidden = true
            translucencyView.isHidden = true
            gridOverlayView.isHidden = true
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: {
                let rotationTransform = CGAffineTransform(rotationAngle: CGFloat.pi / 2)
                let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
                snapshotView.transform = rotationTransform.concatenating(scaleTransform)
            }, completion: { _ in
                self.backgroundContainerView.isHidden = false
                self.foregroundContainerView.isHidden = false
                self.translucencyView.isHidden = false
                self.gridOverlayView.isHidden = false

                self.backgroundContainerView.alpha = 0
                self.gridOverlayView.alpha = 0
                self.translucencyView.alpha = 1

                UIView.animate(withDuration: 0.45, animations: {
                    snapshotView.alpha = 0.0
                    self.backgroundContainerView.alpha = 1.0
                    self.gridOverlayView.alpha = 1.0
                }, completion: { _ in
                    self.rotateAnimationInProgress = false
                    snapshotView.removeFromSuperview()
                })
            })
        }

        checkForCanReset()
    }

    func setAspectRatio(_ aspectRatio: CGSize, animated: Bool) {
        var aspectRatio = aspectRatio

        self.aspectRatio = aspectRatio

        // Will be executed automatically when added to a super view
        guard superview != nil else { return }

        // Passing in an empty size will revert back to the image aspect ratio
        if (aspectRatio.width < CGFloat.ulpOfOne) && (aspectRatio.height < CGFloat.ulpOfOne) {
            aspectRatio = imageSize
        }

        let boundsFrame = contentBounds
        var cropBoxFrame = self.cropBoxFrame
        var offset = scrollView.contentOffset

        var cropBoxIsProtrait = false
        if (Int(aspectRatio.width) == 1) && (Int(aspectRatio.height) == 1) {
            cropBoxIsProtrait = imageSize.width > imageSize.height
        } else {
            cropBoxIsProtrait = aspectRatio.width < aspectRatio.height
        }

        var zoomOut = false
        if cropBoxIsProtrait {
            let newWidth: CGFloat = floor(cropBoxFrame.height * (aspectRatio.width/aspectRatio.height))
            let delta: CGFloat = cropBoxFrame.width - newWidth
            cropBoxFrame.size.width = newWidth
            offset.x += delta * 0.5

            if delta < CGFloat.ulpOfOne {
                // set to 0 to avoid accidental clamping by the crop frame sanitizer
                cropBoxFrame.origin.x = self.contentBounds.origin.x
            }

            let boundsWidth = boundsFrame.width
            if newWidth > boundsWidth {
                let scale = boundsWidth / newWidth
                cropBoxFrame.size.height *= scale
                cropBoxFrame.size.width = boundsWidth
                zoomOut = true
            }
        } else {
            let newHeight: CGFloat = floor(cropBoxFrame.width * (aspectRatio.height/aspectRatio.width))
            let delta = cropBoxFrame.height - newHeight
            cropBoxFrame.size.height = newHeight
            offset.y += delta * 0.5

            if delta < CGFloat.ulpOfOne {
                cropBoxFrame.origin.x = self.contentBounds.origin.y
            }

            let boundsHeight = boundsFrame.height
            if newHeight > boundsHeight {
                let scale: CGFloat = boundsHeight / newHeight
                cropBoxFrame.size.width *= scale
                cropBoxFrame.size.height = boundsHeight
                zoomOut = true
            }
        }

        self.cropBoxLastEditedSize = cropBoxFrame.size
        self.cropBoxLastEditedAngle = angle

        let animations: () -> Void = {
            self.scrollView.contentOffset = offset
            self.cropBoxFrame = cropBoxFrame

            if zoomOut {
                self.scrollView.zoomScale = self.scrollView.minimumZoomScale
            }

            self.moveCroppedContentToCenter(animated: false)
            self.checkForCanReset()
        }

        guard animated else { return animations() }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.7, options: .beginFromCurrentState, animations: animations, completion: nil)
    }

    func moveCroppedContentToCenter(animated: Bool) {
        guard !isInternalLayoutDisabled else { return }

        let contentRect = contentBounds
        var cropFrame = cropBoxFrame

        guard (cropFrame.width > CGFloat.ulpOfOne) && (cropFrame.height > CGFloat.ulpOfOne) else { return }

        let scale = min(contentRect.width / cropFrame.width, contentRect.height / cropFrame.height)

        let focusPoint = CGPoint(x: cropFrame.midX, y: cropFrame.midY)
        let midPoint = CGPoint(x: contentRect.midX, y: contentRect.midY)

        cropFrame.size.width = ceil(cropFrame.width * scale)
        cropFrame.size.height = ceil(cropFrame.height * scale)
        cropFrame.origin.x = contentRect.origin.x + ceil((contentRect.width - cropFrame.width) * 0.5)
        cropFrame.origin.y = contentRect.origin.y + ceil((contentRect.height - cropFrame.height) * 0.5)

        var contentTargetPoint: CGPoint = .zero
        contentTargetPoint.x = (focusPoint.x + scrollView.contentOffset.x) * scale
        contentTargetPoint.y = (focusPoint.y + scrollView.contentOffset.y) * scale

        var offset = CGPoint(x: -midPoint.x + contentTargetPoint.x, y: -midPoint.y +
            contentTargetPoint.y)
        offset.x = max(-cropFrame.origin.x, offset.x)
        offset.y = max(-cropFrame.origin.y, offset.y)

        let animations: () -> Void = {
            // Setting these scroll view properties will trigger the foreground matching method via their delegates
            // multiple times inside the same animation block, resulting in glitchy animations.
            //
            // Disable matching for now, and explicitly update at the end.
            self.disableForgroundMatching = true

            // Slight hack. This method needs to be called during `[UIViewController viewDidLayoutSubviews]`
            // in order for the crop view to resize itself during iPad split screen events.
            // On the first run, even though scale is exactly 1.0f, performing this multiplication introduces
            // a floating point noise that zooms the image in by about 5 pixels. This fixes that issue.
            if scale < CGFloat(1) - CGFloat.ulpOfOne || scale > CGFloat(1.0) + CGFloat.ulpOfOne {
                self.scrollView.zoomScale *= scale
                self.scrollView.zoomScale = min(self.scrollView.maximumZoomScale, self.scrollView.zoomScale)
            }

            // If it turns out the zoom operation would have exceeded the minizum zoom scale, don't apply
            // the content offset
            if self.scrollView.zoomScale < self.scrollView.maximumZoomScale - CGFloat.ulpOfOne {
                offset.x = min((-cropFrame.maxX + self.scrollView.contentSize.width), offset.x)
                offset.y = min((-cropFrame.maxY + self.scrollView.contentSize.height), offset.y)
                self.scrollView.contentOffset = offset
            }

            self.cropBoxFrame = cropFrame

            self.disableForgroundMatching = false
            self.matchForegroundToBackground()
        }

        guard animated else { return animations() }
        matchForegroundToBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: animations, completion: nil)
        }
    }
}

// MARK: - Convenience Methods

private extension CropView {
    var contentBounds: CGRect {
        var contentRect: CGRect = .zero
        contentRect.origin.x = Const.cropViewPadding + cropRegionInset.left
        contentRect.origin.y = Const.cropViewPadding + cropRegionInset.top
        contentRect.size.width = bounds.width - (Const.cropViewPadding*CGFloat(2) + cropRegionInset.left + cropRegionInset.right)
        contentRect.size.height = bounds.height - (Const.cropViewPadding*CGFloat(2) + cropRegionInset.top + cropRegionInset.bottom)

        return contentRect
    }

    var imageSize: CGSize {
        return .zero
    }

    var hasAspectRatio: Bool {
        return (aspectRatio.width > CGFloat.ulpOfOne) && (aspectRatio.height > CGFloat.ulpOfOne)
    }

    func checkForCanReset() {
        var canReset = false
        if angle != 0 {
            canReset = true
        } else if scrollView.zoomScale > scrollView.minimumZoomScale + CGFloat.ulpOfOne {
            canReset = true
        } else if floor(cropBoxFrame.size.width) != floor(originalCropBoxSize.width) ||
            floor(self.cropBoxFrame.size.height) != floor(originalCropBoxSize.height) {
            canReset = true
        } else if floor(scrollView.contentOffset.x) != floor(originalContentOffset.x) || floor(scrollView.contentOffset.y) != floor(originalContentOffset.y) {
            canReset = true
        }
        canBeReset = canReset
    }

    /// A function only be executed on `cropBoxFrame didSet`.
    private func setCropBoxFrame(_ cropBoxFrame: CGRect) {
        var cropBoxFrame = cropBoxFrame
        guard  _cropBoxFrame != cropBoxFrame else { return }

        if (cropBoxFrame.width < CGFloat.ulpOfOne) || (cropBoxFrame.height < CGFloat.ulpOfOne) {
            return
        }

        //clamp the cropping region to the inset boundaries of the screen
        let contentFrame = contentBounds

        let xOrigin = ceil(contentFrame.origin.x)
        let xDelta = cropBoxFrame.origin.x - xOrigin
        cropBoxFrame.origin.x = floor(max(cropBoxFrame.origin.x, xOrigin))
        if xDelta < -CGFloat.ulpOfOne {
            cropBoxFrame.size.width += xDelta
        }

        let yOrigin = ceil(contentFrame.origin.y)
        let yDelta = cropBoxFrame.origin.y - yOrigin
        cropBoxFrame.origin.y = floor(max(cropBoxFrame.origin.y, yOrigin))
        if yDelta < -CGFloat.ulpOfOne {
            cropBoxFrame.size.height += yDelta
        }

        //Make sure we can't make the crop box too small
        cropBoxFrame.size.width = max(cropBoxFrame.width, Const.cropViewMinimumBoxSize.width)
        cropBoxFrame.size.height = max(cropBoxFrame.height, Const.cropViewMinimumBoxSize.height)

        _cropBoxFrame = cropBoxFrame

        foregroundContainerView.frame = _cropBoxFrame
        gridOverlayView.frame = _cropBoxFrame

        //reset the scroll view insets to match the region of the new crop rect
        scrollView.contentInset = UIEdgeInsets(top: _cropBoxFrame.minY, left: _cropBoxFrame.minX, bottom: (bounds.maxY - _cropBoxFrame.maxY), right: (bounds.maxX - _cropBoxFrame.maxX))

        //if necessary, work out the new minimum size of the scroll view so it fills the crop box
        let imageSize = backgroundContainerView.bounds.size
        let scale = max(cropBoxFrame.height / imageSize.height, cropBoxFrame.width / imageSize.width)
        scrollView.minimumZoomScale = scale

        //make sure content isn't smaller than the crop box
        var size = scrollView.contentSize
        size.width = floor(size.width)
        size.height = floor(size.height)
        scrollView.contentSize = size

        //IMPORTANT: Force the scroll view to update its content after changing the zoom scale
        scrollView.zoomScale = scrollView.zoomScale

        matchForegroundToBackground()
    }
}

// MARK: - Timers

private extension CropView {
    func startResetTimer() {
        guard resetTimer == nil else { return }
        resetTimer = Timer.scheduledTimer(timeInterval: Const.cropTimerDuration, target: self, selector: #selector(timerTriggered), userInfo: nil, repeats: false)
    }

    func cancelResetTimer() {
        resetTimer?.invalidate()
        resetTimer = nil
    }

    @objc private func timerTriggered() {
        setEditing(false, animated: true)
        resetTimer?.invalidate()
        resetTimer = nil
    }
}

// MARK: - UIGestureReconizerDelegate

extension CropView: UIGestureRecognizerDelegate {
    @objc private func gridPanGestureRecognized(_ gestureRecognizer: UIPanGestureRecognizer) {
        let point = gestureRecognizer.location(in: self)

        switch gestureRecognizer.state {
        case .began:
            startEditing()

            panOriginPoint = point
            cropOriginFrame = cropBoxFrame
            tappedEdge = cropEdge(for: point)
        case .ended:
            startResetTimer()
        default: break
        }

        updateCropBoxFrame(with: point)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == gridPanGestureRecognizer else { return true }
        let tapPoint = gestureRecognizer.location(in: self)

        let frame = gridOverlayView.frame
        let innerFrame = frame.insetBy(dx: 22, dy: 22)
        let outerFrame = frame.insetBy(dx: -22, dy: -22)

        if innerFrame.contains(tapPoint) || !outerFrame.contains(tapPoint) {
            return false
        }

        return true
    }
}

// MARK: - UIScrollViewDelegate Methods

extension CropView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return backgroundContainerView
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        matchForegroundToBackground()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        startEditing()
        canBeReset = true
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        startEditing()
        canBeReset = true
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        startResetTimer()
        checkForCanReset()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        startResetTimer()
        checkForCanReset()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            cropBoxLastEditedZoomScale = scrollView.zoomScale
            cropBoxLastEditedMinZoomScale = scrollView.minimumZoomScale
        }
        matchForegroundToBackground()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        startResetTimer()
    }
}

// MARK: - Constants

private extension CropView {
    enum Const {
        static let cropViewPadding: CGFloat = 16
        static let cropTimerDuration: TimeInterval = 0.8
        static let cropViewMinimumBoxSize = CGSize(width: 42, height: 42)
    }
}

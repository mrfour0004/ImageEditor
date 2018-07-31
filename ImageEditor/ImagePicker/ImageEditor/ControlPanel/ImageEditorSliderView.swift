//
//  ImageEditorSliderView.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/30.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

protocol ImageEditorSliderDelegate: AnyObject {
    func sliderViewDidEndEditing(_ sliderView: ImageEditorSliderView)
    func sliderViewDidChange(_ sliderView: ImageEditorSliderView)
    func sliderViewDidCancelEditing(_ sliderView: ImageEditorSliderView)
}

class Slider: UISlider {

    private lazy var trackLayer: CAShapeLayer = {
        let trackLayer = CAShapeLayer()
        trackLayer.backgroundColor = UIColor.lightGray.cgColor
        layer.insertSublayer(trackLayer, at: 0)
        return trackLayer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        var trackRect = self.trackRect
        let midY = trackRect.midY
        trackRect.size.height = 1
        trackRect.origin.y = midY - trackRect.size.height/CGFloat(2)

        trackLayer.frame = trackRect.insetBy(dx: 16, dy: 0)
    }

    private func setup() {
        maximumTrackTintColor = .clear
        minimumTrackTintColor = .clear
        setThumbImage(#imageLiteral(resourceName: "ic_sliders_white100"), for: .normal)
    }

}

class ImageEditorSliderView: UIView, NibLoadable {

    // MARK: - IBOutlets

    @IBOutlet private weak var slider: UISlider!
    @IBOutlet private weak var buttonStackView: UIStackView!

    // MARK: - Views

    private var valueLabel: UILabel = UILabel()

    // MARK: - Properties

    enum Const {
        static let maxSliderValue: Int = 100
        static let minSliderValue: Int = -100
        static let sliderZeroBuffer: Int = 5
        static let thumbImage = #imageLiteral(resourceName: "ic_sliders_white100")
    }

    weak var delegate: ImageEditorSliderDelegate?

    var sliderValue: Int {
        get {
            let roundedValue = Int(slider.value.rounded())
            switch roundedValue {
            case -Const.sliderZeroBuffer...Const.sliderZeroBuffer:
                return 0
            case let x where x > Const.sliderZeroBuffer:
                return x - Const.sliderZeroBuffer
            case let x where x < -Const.sliderZeroBuffer:
                return x + Const.sliderZeroBuffer
            default:
                return roundedValue
            }
        }

        set {
            var value: Int
            switch newValue {
            case 1...100:
                value = newValue + Const.sliderZeroBuffer
            case -100...(-1):
                value = newValue - Const.sliderZeroBuffer
            default:
                hasEnteredHapticZone = true
                value = 0
            }
            slider.value = Float(value)
        }
    }

    /// A flag to decide whether to generate haptic feedback when the slider value has enter zero buffer zone
    /// or has reached the maximum/minimum value. Default value is `true`.
    private var hasEnteredHapticZone: Bool = true

    // MARK: - View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        setupViews()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        guard let superview = superview else { return }
        frame = superview.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateValueLabel(animated: false)
    }

    // MARK: - Public Methods

    func show(animated: Bool) {
        guard animated else {
            alpha = 1
            return
        }

        alpha = 0
        buttonStackView.transform = CGAffineTransform(translationX: 0, y: buttonStackView.frame.height)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: {
            self.alpha = 1
            self.buttonStackView.transform = .identity
        }, completion: nil)
    }

    func hide(animated: Bool) {
        guard animated else {
            return removeFromSuperview()
        }

        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: {
            self.alpha = 0
            self.buttonStackView.transform = CGAffineTransform(translationX: 0, y: self.buttonStackView.frame.height)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }

    // MARK: - IBAction

    @IBAction private func didTapDoneButton(_ sender: Any) {
        delegate?.sliderViewDidEndEditing(self)
    }

    @IBAction private func didTapCancelButton(_ sender: Any) {
        delegate?.sliderViewDidCancelEditing(self)
    }

    // MARK: - Setup Views

    private func setupViews() {
        alpha = 0

        setupSlider()
        setupValueLabel()
    }

    private func setupSlider() {
        slider.maximumValue = Float(Const.maxSliderValue + Const.sliderZeroBuffer)
        slider.minimumValue = Float(Const.minSliderValue - Const.sliderZeroBuffer)
        slider.value = 0

        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    private func setupValueLabel() {
        valueLabel.font = UIFont.systemFont(ofSize: 12)
        valueLabel.textColor = .gray
        addSubview(valueLabel)
    }

    // MARK: - Private Methods

    private func updateValueLabel(animated: Bool) {
        let roundedValue: Int = sliderValue
        valueLabel.text = String(describing: roundedValue)
        valueLabel.sizeToFit()

        let thumbRect = slider.convert(slider.thumbRect, to: self)

        valueLabel.center = CGPoint(x: thumbRect.midX, y: thumbRect.midY)
        valueLabel.frame.origin.y -= thumbRect.height/CGFloat(2) + CGFloat(4) + valueLabel.frame.height/CGFloat(2)

        guard animated else {
            valueLabel.alpha = (roundedValue == 0) ? 0 : 1
            return
        }

        let needsShowValueLabel: Bool = (roundedValue != 0)
        let transform: CGAffineTransform = needsShowValueLabel ? .identity : CGAffineTransform(scaleX: 0.8, y: 0.8)
        let alpha: CGFloat = needsShowValueLabel ? 1 : 0

        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.7, options: .beginFromCurrentState, animations: {
            self.valueLabel.alpha = alpha
            self.valueLabel.transform = transform
        }, completion: nil)
    }

    // MARK: - Slider

    @objc private func sliderValueChanged(_ slider: UISlider, event: UIEvent) {
        let sliderValue = self.sliderValue
        updateValueLabel(animated: true)
        delegate?.sliderViewDidChange(self)

        if #available(iOS 10.0, *) {
            switch sliderValue {
            case 0 where !hasEnteredHapticZone:
                hasEnteredHapticZone = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case 0:
                break
            case Const.maxSliderValue where !hasEnteredHapticZone,
                 Const.minSliderValue where !hasEnteredHapticZone:
                hasEnteredHapticZone = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case Const.maxSliderValue, Const.minSliderValue:
                break
            default:
                hasEnteredHapticZone = false
            }
        }

        guard let touchEvent = event.allTouches?.first else { return }
        switch touchEvent.phase {
        case .ended where sliderValue == 0:
            slider.value = 0
        default: break
        }
    }
}

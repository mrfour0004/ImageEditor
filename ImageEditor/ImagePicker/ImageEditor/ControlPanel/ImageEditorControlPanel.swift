//
//  ImageEditorControlPanel.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/24.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

protocol ImageEditorControlPanelDelegate: AnyObject {
    func imageEditorDidTapRotateButton(_ controlPanel: ImageEditorControlPanel)
    func imageEditor(_ controlPanel: ImageEditorControlPanel, didCancelEditing mode: ImageEditorControlPanel.EditMode)
    func imageEditor(_ controlPanel: ImageEditorControlPanel, sliderValueChangedTo value: Float, for editingMode: ImageEditorControlPanel.EditMode)
    func imageEditor(_ controlPanel: ImageEditorControlPanel, willBedingEditing mode: ImageEditorControlPanel.EditMode)
    func imageEditor(_ controlPanel: ImageEditorControlPanel, didEndEditing mode: ImageEditorControlPanel.EditMode)
}

class ImageEditorControlPanel: UIView, NibLoadable {

    // MARK: - Properties

    enum EditMode: CustomStringConvertible {
        case brightness
        case contrast

        var ciInputKey: String {
            switch self {
            case .brightness: return kCIInputBrightnessKey
            case .contrast: return kCIInputContrastKey
            }
        }

        var ciDefaultValue: Float {
            switch self {
            case .brightness: return 0.00
            case .contrast: return 1.00
            }
        }

        var description: String {
            switch self {
            case .brightness: return NSLocalizedString("Brightness", comment: "")
            case .contrast: return NSLocalizedString("Contrast", comment: "")
            }
        }
    }

    weak var delegate: ImageEditorControlPanelDelegate?
    var editedValueDictionary: [EditMode: Int] = [:]

    private var sliderView: ImageEditorSliderView?
    private var editingMode: EditMode?

    // MARK: - IBOutlets

    @IBOutlet weak var buttonStackView: UIStackView!

    // MARK: - IBActions

    @IBAction func didTapRotateButton(_ sender: Any) {
        delegate?.imageEditorDidTapRotateButton(self)
    }

    @IBAction func didTapContrastButton(_ sender: Any) {
        startEditing(mode: .contrast)
    }

    @IBAction func didTapBrightnessButton(_ sender: Any) {
        startEditing(mode: .brightness)
    }

    // MARK: - Private Methods

    private func startEditing(mode: ImageEditorControlPanel.EditMode) {
        editingMode = mode

        let sliderView = ImageEditorSliderView.instantiateFromNib()
        sliderView.delegate = self
        addSubview(sliderView)

        if let editedValue = editedValueDictionary[mode] {
            sliderView.sliderValue = editedValue
        }

        self.sliderView = sliderView

        showSliderView(animated: true)
        delegate?.imageEditor(self, willBedingEditing: mode)
    }

    private func convert(_ sliderValue: Int, to editMode: EditMode) -> Float {
        switch editMode {
        case .brightness:
            return Float(sliderValue) / 2000.00
        case .contrast:
            return (Float(sliderValue) / 400.00) + 1.00
        }
    }

    private func showSliderView(animated: Bool) {
        guard let sliderView = sliderView else { return }
        sliderView.show(animated: true)

        let animations: () -> Void = {
            self.buttonStackView.transform = CGAffineTransform(translationX: 0, y: self.buttonStackView.frame.height/2)
            self.buttonStackView.alpha = 0
        }

        guard animated else { return animations() }
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: animations, completion: nil)
    }

    private func hideSliderView(animated: Bool) {
        guard let sliderView = sliderView else { return }
        sliderView.hide(animated: animated)

        let animations: () -> Void = {
            self.buttonStackView.transform = .identity
            self.buttonStackView.alpha = 1
        }

        guard animated else { return animations() }
        UIView.animate(withDuration: 0.3, delay: 0.15, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: animations, completion: nil)
    }

}

// MARK: - ImageEditorSliderDelegate Methods

extension ImageEditorControlPanel: ImageEditorSliderDelegate {

    func sliderViewDidEndEditing(_ sliderView: ImageEditorSliderView) {
        hideSliderView(animated: true)

        if let editingMode = editingMode {
            delegate?.imageEditor(self, didEndEditing: editingMode)
            editedValueDictionary[editingMode] = sliderView.sliderValue
            self.editingMode = nil
        }
    }

    func sliderViewDidChange(_ sliderView: ImageEditorSliderView) {
        guard let editingMode = editingMode else { return }
        let convertedValue = convert(sliderView.sliderValue, to: editingMode)
        delegate?.imageEditor(self, sliderValueChangedTo: convertedValue, for: editingMode)
    }

    func sliderViewDidCancelEditing(_ sliderView: ImageEditorSliderView) {
        hideSliderView(animated: true)

        if let editingMode = editingMode {
            delegate?.imageEditor(self, didCancelEditing: editingMode)
            self.editingMode = nil
        }
    }

}

extension Int {
    func converted(to editMode: ImageEditorControlPanel.EditMode) -> Float {
        switch editMode {
        case .brightness:
            return Float(self) / 2000.00
        case .contrast:
            return (Float(self) / 400.00) + 1.00
        }
    }
}

extension Dictionary where Key == ImageEditorControlPanel.EditMode, Value == Int {
    var ciInputValueConverted: [ImageEditorControlPanel.EditMode: Float] {
        return Dictionary<ImageEditorControlPanel.EditMode, Float>(uniqueKeysWithValues: self.map { ($0.key, $0.value.converted(to: $0.key)) })
    }
}

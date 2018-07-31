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
    func imageEditor(_ controlPanel: ImageEditorControlPanel, sliderValueChangedTo value: Int, for editingMode: ImageEditorControlPanel.EditMode)
    func imageEditor(_ controlPanel: ImageEditorControlPanel, willBedingEditing mode: ImageEditorControlPanel.EditMode)
    func imageEditor(_ controlPanel: ImageEditorControlPanel, didEndEditing mode: ImageEditorControlPanel.EditMode)
}

class ImageEditorControlPanel: UIView, NibLoadable {

    // MARK: - Properties

    enum EditMode {
        case brightness
        case contrast
    }

    weak var delegate: ImageEditorControlPanelDelegate?

    private var sliderView: ImageEditorSliderView?
    private var editedValueDictionary: [EditMode: Int] = [:]
    private var editingMode: EditMode?

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
        delegate?.imageEditor(self, willBedingEditing: mode)

        let sliderView = ImageEditorSliderView.instantiateFromNib()
        sliderView.delegate = self
        addSubview(sliderView)

        if let editedValue = editedValueDictionary[mode] {
            sliderView.sliderValue = editedValue
        }

        self.sliderView = sliderView

        sliderView.show(animated: true)
    }

}

// MARK: - ImageEditorSliderDelegate Methods

extension ImageEditorControlPanel: ImageEditorSliderDelegate {

    func sliderViewDidEndEditing(_ sliderView: ImageEditorSliderView) {
        sliderView.hide(animated: true)

        if let editingMode = editingMode {
            delegate?.imageEditor(self, didEndEditing: editingMode)
            editedValueDictionary[editingMode] = sliderView.sliderValue
            self.editingMode = nil
        }
    }

    func sliderViewDidChange(_ sliderView: ImageEditorSliderView) {
        guard let editingMode = editingMode else { return }
        delegate?.imageEditor(self, sliderValueChangedTo: sliderView.sliderValue, for: editingMode)
    }

    func sliderViewDidCancelEditing(_ sliderView: ImageEditorSliderView) {
        sliderView.hide(animated: true)

        if let editingMode = editingMode {
            delegate?.imageEditor(self, didCancelEditing: editingMode)
            self.editingMode = nil
        }
    }

}

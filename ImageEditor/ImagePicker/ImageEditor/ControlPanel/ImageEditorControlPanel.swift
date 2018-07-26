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
    func imageEditor(_ controlPanel: ImageEditorControlPanel, sliderValueDidChangeTo value: CGFloat)
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
        delegate?.imageEditor(self, willBedingEditing: mode)
    }

}

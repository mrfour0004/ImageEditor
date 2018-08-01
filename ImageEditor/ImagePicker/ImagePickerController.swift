//
//  ImagePickerController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/17.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit

protocol ImagePickerControllerDelegate: AnyObject {
    func imagePicker(_ picker: ImagePickerController, didFinishPickingImage image: UIImage)
    func imagePickerDidCancel(_ picker: ImagePickerController)
}

class ImagePickerController: UINavigationController {

    // MARK: - Properties

    /// A Boolean value indicating whether the user is allowed to edit a selected still image. This property is set to `false` by default.
    var allowsEditing = false
    var cropAspectRatioPreset: CropAspectRatioPreset = .original
    var isAspectRatioLockEnabled: Bool = false

    weak var pickerDelegate: ImagePickerControllerDelegate?

    // MARK: - View Lifecycle

    convenience init() {
        self.init(rootViewController: CameraViewController.instantiateFromStoryboard())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        interactivePopGestureRecognizer?.delegate = self
    }
}

// MARK: - UINavigationControllerDelegate Methods

extension ImagePickerController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        navigationController.setNavigationBarHidden(needsHideNavigationBarWhenShowing(viewController), animated: false)
    }

    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        navigationController.setNavigationBarHidden(needsHideNavigationBarWhenShowing(toVC), animated: true)
        return nil
    }

    private func needsHideNavigationBarWhenShowing(_ viewController: UIViewController) -> Bool{
        switch viewController {
        case is CameraViewController:
            return true
        default:
            return false
        }
    }
}

// MARK: - UIGestureRecognizerDelegate Methods

extension ImagePickerController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }

        if let topViewController = topViewController as? ImageEditorViewController {
            return !topViewController.isEditing
        }

        return viewControllers.count > 1
    }
}

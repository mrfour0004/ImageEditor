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

    weak var pickerDelegate: ImagePickerControllerDelegate?

    // MARK: - View Lifecycle

    convenience init() {
        let viewController = UIStoryboard.init(name: "CameraViewController", bundle: nil).instantiateInitialViewController() as! CameraViewController
        self.init(rootViewController: viewController)
    }
}

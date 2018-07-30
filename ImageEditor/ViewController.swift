//
//  ViewController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/6/30.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit
import AVFoundation
import CLImageEditor

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBAction private func presentImageEditor(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera

        present(imagePicker, animated: true, completion: nil)
    }

    @IBAction private func presentCameraViewController(_ sender: Any) {
        let picker = ImagePickerController()
        picker.pickerDelegate = self
        picker.allowsEditing = true
        picker.cropAspectRatioPreset = .square
        picker.isAspectRatioLockEnabled = true

        present(picker, animated: true, completion: nil)
    }

    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage

        let imageEditor = CLImageEditor(image: image, delegate: self)!
        imageEditor.navigationItem.hidesBackButton = true
        imageEditor.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(dismissSelf))

        picker.pushViewController(imageEditor, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {

    }
}

extension ViewController: ImagePickerControllerDelegate {
    func imagePicker(_ picker: ImagePickerController, didFinishPickingImage image: UIImage) {
        imageView.image = image
        dismiss(animated: true, completion: nil)
    }

    func imagePickerDidCancel(_ picker: ImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

extension ViewController: CLImageEditorDelegate {
    func imageEditor(_ editor: CLImageEditor!, didFinishEditingWith image: UIImage!) {
        imageView.image = image
        editor.dismiss(animated: true, completion: nil)
    }

    func imageEditorDidCancel(_ editor: CLImageEditor!) {
        editor.dismiss(animated: true, completion: nil)
    }
}

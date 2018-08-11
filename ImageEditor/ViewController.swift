//
//  ViewController.swift
//  ImageEditor
//
//  Created by mrfour on 2018/6/30.
//  Copyright © 2018 mrfour. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView! {
        didSet {
            imageView.isUserInteractionEnabled = true
            imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapImageView)))
        }
    }
    
    @IBAction private func presentImageEditor(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        
        present(imagePicker, animated: true, completion: nil)
    }

    @IBAction private func presentCameraViewController(_ sender: Any) {
        let picker = ImagePickerController()
        picker.pickerDelegate = self
        picker.allowsEditing = true
//        picker.cropAspectRatioPreset = .square
//        picker.cropAspectRatioPreset = .custom(CGSize(width: 328, height: 200))
//        picker.isAspectRatioLockEnabled = true

        present(picker, animated: true, completion: nil)
    }

    @objc func didTapImageView(_ gesture: UITapGestureRecognizer) {
        guard let image = imageView.image else { return }
        let imageViewController = ImageViewController(image: image)
        imageViewController.sourceView = imageView
        present(imageViewController, animated: true, completion: nil)
    }

    @objc func dismissSelf() {
        dismiss(animated: true, completion: nil)
    }
    
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.image = image
        picker.dismiss(animated: true, completion: nil)
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
        imageView.isHidden = true
        picker.dismissAnimated(withCroppedImage: image, toView: imageView) {
            self.imageView.isHidden = false
        }
        //dismiss(animated: true, completion: nil)
    }

    func imagePickerDidCancel(_ picker: ImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}


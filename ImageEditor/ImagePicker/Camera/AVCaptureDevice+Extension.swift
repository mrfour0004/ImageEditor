//
//  AVCaptureDevice+Extension.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/7.
//  Copyright © 2018 mrfour. All rights reserved.
//

import AVFoundation

extension AVCaptureDevice {
    static func defaultCamera(position: AVCaptureDevice.Position = .back) -> AVCaptureDevice? {
        if #available(iOS 10.2, *) {
            if position == .back, let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                return device
            } else if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
                return device
            }
        } else if #available(iOS 10.0, *) {
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
                return device
            }
        } else {
            let devices = AVCaptureDevice.devices(for: .video)
            var captureDevcie = devices.first

            for device in devices where device.position == position {
                captureDevcie = device
                break
            }
            return captureDevcie
        }

        return AVCaptureDevice.default(for: .video)
    }
}

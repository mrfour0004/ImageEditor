//
//  PhotoCaptureProcessor.swift
//  ImageEditor
//
//  Created by mrfour on 2018/7/7.
//  Copyright © 2018 mrfour. All rights reserved.
//

import AVFoundation
import Photos

@available(iOS 10.0, *)
class PhotoCaptureProcessor: NSObject {

    // MARK: - Properites

    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    private let willCapturePhotoAnimation: () -> Void
    private let livePhotoCaptureHandler: (Bool) -> Void
    private let completionHandler: (PhotoCaptureProcessor) -> Void
    private var photoData: Data?
    private var livePhotoCompanionMovieURL: URL?

    // MARK: - Lifecycle

    init(with requestedPhotoSettings: AVCapturePhotoSettings,
         willCapturePhotoAnimation: @escaping () -> Void,
         livePhotoCaptureHandler: @escaping (Bool) -> Void,
         completionHandler: @escaping (PhotoCaptureProcessor) -> Void) {
        self.requestedPhotoSettings = requestedPhotoSettings
        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        self.livePhotoCaptureHandler = livePhotoCaptureHandler
        self.completionHandler = completionHandler
    }

    private func didFinish() {
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
                do {
                    try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
                } catch {
                    print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }

        completionHandler(self)
    }
}

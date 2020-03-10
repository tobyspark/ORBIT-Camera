//
//  Camera.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os.log

/// Functionality to capture videos and run a preview (i.e. a camera viewfinder)
class Camera {
    // TODO: Consider detach?
    func attachPreview(to layer: AVCaptureVideoPreviewLayer) {
        queue.async {
            // First start on Camera queue
            self.captureSession.startRunning()
            // Then attach on UI queue
            DispatchQueue.main.async {
                layer.session = self.captureSession
            }
        }
    }
    
    init() {
        queue.async {
            // Configure the AVCaptureSession
            self.captureSession.beginConfiguration()
            guard
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                self.captureSession.canAddInput(videoDeviceInput)
            else {
                os_log("Could not configure camera")
                return
            }
            self.captureSession.addInput(videoDeviceInput)
            self.captureSession.commitConfiguration()
        }
    }
    
    /// The `AVCaptureSession` behind this "Camera"
    private let captureSession = AVCaptureSession()
    
    /// A queue to allow camera operations to run in order, in the background
    private let queue = DispatchQueue(label: "cameraSerialQueue")
}

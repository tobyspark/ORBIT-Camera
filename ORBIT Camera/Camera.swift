//
//  Camera.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os

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
    
    func recordStart(to url: URL) {
        queue.async {
            // Configure file output on demand
            if self.videoFileOutput == nil {
                let videoFileOutput = AVCaptureMovieFileOutput()
                if self.captureSession.canAddOutput(videoFileOutput) {
                    self.captureSession.beginConfiguration()
                    self.captureSession.addOutput(videoFileOutput)
                    self.captureSession.sessionPreset = .hd1920x1080
                    if let connection = videoFileOutput.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    self.captureSession.commitConfiguration()
                    self.videoFileOutput = videoFileOutput
                }
            }
            
            guard
                let videoFileOutput = self.videoFileOutput
            else {
                os_log("No videoFileOutput on recordStart")
                return
            }
            
            videoFileOutput.startRecording(to: url, recordingDelegate: self.delegate)
        }
    }
    
    func recordStop() {
        guard let videoFileOutput = videoFileOutput else { return }
        queue.async {
            videoFileOutput.stopRecording()
        }
    }
    
    init() {
        queue.async {
            // Configure the AVCaptureSession sufficient for preview
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
    
    private var videoFileOutput: AVCaptureMovieFileOutput?
    
    private var delegate = CameraDelegate()
}

class CameraDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // TODO: Create Video object and update UI
        print("CameraDelegate didFinishRecording", error)
    }
}

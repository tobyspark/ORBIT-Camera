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

/// Protocol for handling camera output
protocol CameraProtocol {
    /// Called when a recording has finished writing to its file
    func didFinishRecording(to outputFileURL: URL)
}

/// Functionality to capture videos and run a preview (i.e. a camera viewfinder)
///
/// The core part is `captureSession`, which takes the device input and has to run at a device format.
/// This is set to run at `hd1920x1080`. An `AVCaptureVideoPreviewLayer` can preview that, but note it's 16:9 content set to fill the layer while maintaining aspect ratio. The layer should be square to match the recorded output.
/// To record square video, i.e. to encode a square crop of that captureSession stream to a file, `AVCaptureMovieFileOutput` is inadequate.
/// Instead `AVAssetWriterInput` can be configured to scale and crop to a square.
/// To then do what `AVCaptureMovieFileOutput` did otherwise, you need an `AVAssetWriter` configured with that input to actually write-out the file, and an `AVCaptureVideoDataOutput` to get frames from the capture session to that writer.
///
/// As Xcode's iOS simulator doesn't support video capture, this class becomes inert when compiled for that.
class Camera {
    /// Attach a preview layer to this camera.
    /// This previews the video coming from the device, currently set to 16:9, but has presentation attribute set to fill the layer while maintaining the aspect ratio. If the provided layer is square, this will match recorded output.
    // TODO: Consider detach?
    func attachPreview(to layer: AVCaptureVideoPreviewLayer) {
        #if !targetEnvironment(simulator)
        queue.async {
            // First start on Camera queue
            self.captureSession.startRunning()
            // Then attach on UI queue
            DispatchQueue.main.async {
                layer.videoGravity = .resizeAspectFill
                layer.session = self.captureSession
            }
        }
        #endif
    }
    
    /// Start recording to a file
    func recordStart(to url: URL) {
        #if !targetEnvironment(simulator)
        queue.async {
            // The capture objects should only exist during recording.
            guard
                self.writerInput == nil,
                self.writer == nil,
                self.videoDataOutput == nil,
                self.captureDelegate == nil
            else {
                os_log("Stale capture object(s) on recordStart")
                return
            }
            
            // Create CaptureDelegate
            self.captureDelegate = CaptureDelegate()
            self.captureDelegate.camera = self

            // Create AVAssetWriterInput
            // The capture session has to operate using device (e.g. hardware) formats,
            // so this is where the crop happens
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                // Encode to H264
                AVVideoCodecKey: AVVideoCodecType.h264,
                // Scale and crop to square
                AVVideoWidthKey: 1080,
                AVVideoHeightKey: 1080,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            ])
            writerInput.expectsMediaDataInRealTime = true
            
            // Create AVAssetWriter
            guard
                let writer = try? AVAssetWriter(url: url, fileType: .mp4),
                writer.canAdd(writerInput)
            else {
                os_log("Could not create AVAssetWriter")
                return
            }
            writer.add(writerInput)
            guard writer.startWriting()
            else {
                os_log("Could not start AVAssetWriter")
                return
            }
            
            // Create AVCaptureVideoDataOutput
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self.captureDelegate, queue: self.captureDelegate.queue)
            
            guard self.captureSession.canAddOutput(videoDataOutput)
            else {
                os_log("Could not add AVCaptureVideoDataOutput")
                return
            }
            self.captureSession.beginConfiguration()
            self.captureSession.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                // Set portrait, to match non-rotating portrait UI
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // Stablise if possible
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
            self.captureSession.commitConfiguration()

            // Now everything is set, persist the capture objects
            // This will start recording, enacted in the videoDataSource delegate
            self.videoDataOutput = videoDataOutput
            self.writer = writer
            self.writerInput = writerInput
        }
        #endif
    }
    
    /// Stop the recording you started
    func recordStop() {
        #if !targetEnvironment(simulator)
        queue.async {
            // Stop video data being output
            if let videoDataOutput = self.videoDataOutput {
                self.captureSession.removeOutput(videoDataOutput)
            }
            self.videoDataOutput = nil
            self.captureDelegate = nil
            
            // Wrap-up writing
            self.writer?.finishWriting {
                if let writer = self.writer, let delegate = self.delegate
                {
                    let url = writer.outputURL
                    DispatchQueue.main.async {
                        print("Camera recordStop calling didFinishRecording with \(url)")
                        delegate.didFinishRecording(to: url)
                    }
                }
                self.writer = nil
                self.writerInput = nil
            }
        }
        #endif
    }
    
    // A delegate that can be notified when a recording has been created.
    var delegate: CameraProtocol?
    
    init() {
        #if !targetEnvironment(simulator)
        queue.async {
            // Configure the AVCaptureSession sufficient for preview
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1920x1080
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

//            // What native recording formats does this device have? Are any square?
//            for format in videoDevice.formats {
//                let fdesc = format.formatDescription
//                let dims = CMVideoFormatDescriptionGetDimensions(fdesc)
//                print(dims, Float(dims.width) / Float(dims.height))
//            }
        }
        #endif
    }
    
    /// The `AVCaptureSession` behind this "Camera"
    private let captureSession = AVCaptureSession()
    
    /// A queue to allow camera operations to run in order, in the background
    private let queue = DispatchQueue(label: "cameraSerialQueue")

    /// Capture object instantiated for (and only exist during) recording
    private var captureDelegate: CaptureDelegate!
    /// Capture object instantiated for (and only exist during) recording
    private var videoDataOutput: AVCaptureVideoDataOutput?
    /// Capture object instantiated for (and only exist during) recording
    fileprivate var writerInput: AVAssetWriterInput?
    /// Capture object instantiated for (and only exist during) recording
    fileprivate var writer: AVAssetWriter?
}

/// Essential Camera recording functionality, that happens to be in a separate class. Hence private, tightly coupled. Needs to be instantiated new for each capture.
fileprivate class CaptureDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var camera: Camera!
        
    let queue = DispatchQueue(label: "cameraCaptureQueue")
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            let writer = camera.writer,
            let writerInput = camera.writerInput
        else { return }
        
        // To ensure the output video starts at time zero, start the writer's session with the PTS of the first frame it's going to receive
        if !didStart {
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            didStart = false
        }
        
        writerInput.append(sampleBuffer)
    }
    
    private var didStart = false
}

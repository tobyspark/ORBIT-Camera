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
    func attachPreview(to view: PreviewMetalView) {
        #if !targetEnvironment(simulator)
        videoDataDelegate.queue.async {
            view.rotation = .rotate180Degrees
            let result = self.previewViews.insert(WeakRef(object: view))
            if result.inserted {
                os_log("Camera adding preview", type: .debug)
            }
        }
        queue.async {
            self.captureSession.startRunning()
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
                self.writer == nil
            else {
                os_log("Stale capture object(s) on recordStart")
                return
            }

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

            // Now everything is set, declare the record objects
            // This will start recording, enacted in the videoDataSource delegate
            self.writer = writer
            self.writerInput = writerInput
        }
        #endif
    }
    
    /// Stop the recording you started
    func recordStop() {
        #if !targetEnvironment(simulator)
        queue.async {
            self.videoDataDelegate.queue.sync {
                // Wrap-up writing
                if let writer = self.writer,
                   let delegate = self.delegate
                {
                    writer.finishWriting {
                        let url = writer.outputURL
                        DispatchQueue.main.async {
                            os_log("Camera.recordStop calling delegate.didFinishRecording", type: .debug)
                            delegate.didFinishRecording(to: url)
                        }
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
        // FIXME: Debugging (for now)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: .AVCaptureSessionDidStartRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: .AVCaptureSessionDidStopRunning, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: .AVCaptureSessionRuntimeError, object: nil)
        
        #if !targetEnvironment(simulator)
        queue.async {
            // Create CaptureDelegate
            self.videoDataDelegate = VideoDataDelegate()
            self.videoDataDelegate.camera = self
            
            // AVCaptureSession BEGIN
            self.captureSession.beginConfiguration()
            
            // Configure the AVCaptureSession
            self.captureSession.sessionPreset = .hd1920x1080
            
            // Create AVCaptureDeviceInput
            guard
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                self.captureSession.canAddInput(videoDeviceInput)
            else {
                os_log("Could not configure camera")
                return
            }
            self.captureSession.addInput(videoDeviceInput)

            // Create AVCaptureVideoDataOutput
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self.videoDataDelegate, queue: self.videoDataDelegate.queue)
            guard self.captureSession.canAddOutput(videoDataOutput)
            else {
                os_log("Could not add AVCaptureVideoDataOutput")
                return
            }
            self.captureSession.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                // Set portrait, to match non-rotating portrait UI
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // FIXME: After moving from AVCaptureVideoPreviewLayer the following stablisation was causing a run-time error starting the capture queue.
                //   name = AVCaptureSessionRuntimeErrorNotification, object = Optional(<AVCaptureSession: 0x2827f01f0 [AVCaptureSessionPreset1920x1080]>
                //   <AVCaptureDeviceInput: 0x2825fd400 [Back Camera]>[vide] -> <AVCaptureVideoDataOutput: 0x2825fd600>), userInfo = Optional([AnyHashable("AVCaptureSessionErrorKey"): Error Domain=AVFoundationErrorDomain Code=-11819 "Cannot Complete Action" UserInfo={NSLocalizedDescription=Cannot Complete Action, NSLocalizedRecoverySuggestion=Try again later.}])
                // // Stablise if possible
                // if connection.isVideoStabilizationSupported {
                //     connection.preferredVideoStabilizationMode = .auto
                // }
            }
            
            // AVCaptureSession END
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
    
    // FIXME: Debugging (for now)
    @objc func handleNotification(notification: Notification) {
        os_log("handleNotification %s", notification.name.rawValue)
        if notification.name == NSNotification.Name.AVCaptureSessionRuntimeError {
            print(notification)
        }
    }
    
    /// The `AVCaptureSession` behind this "Camera"
    private let captureSession = AVCaptureSession()
    
    /// A queue to allow camera operations to run in order, in the background
    private let queue = DispatchQueue(label: "cameraSerialQueue")
    
    /// The handler for the AVCaptureVideoDataOutput supplied video frames
    private var videoDataDelegate: VideoDataDelegate!

    /// Capture object instantiated for (and only exist during) recording, formats for square mp4
    fileprivate var writerInput: AVAssetWriterInput?
    
    /// Capture object instantiated for (and only exist during) recording, writes that formated data
    fileprivate var writer: AVAssetWriter?
    
    /// Preview layers to update
    fileprivate var previewViews = Set<WeakRef<PreviewMetalView>>()
}

/// Essential Camera recording functionality, that happens to be in a separate class. Hence private, tightly coupled. Needs to be instantiated new for each capture.
fileprivate class VideoDataDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var camera: Camera!
    
    // The serial queue `captureOutput` is called on
    let queue = DispatchQueue(label: "cameraVideoDataQueue")
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Push to preview layers
        if !camera.previewViews.isEmpty {
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            
            for viewRef in camera.previewViews {
                if let view = viewRef.object {
                    view.image = ciImage
                } else {
                    os_log("Camera removing previewLayer", type: .debug)
                    camera.previewViews.remove(viewRef)
                }
            }
        }
        
        // Write to file when recording
        if let writer = camera.writer,
           let writerInput = camera.writerInput
        {
            // To ensure the output video starts at time zero, start the writer's session with the PTS of the first frame it's going to receive
            if !writerDidStart {
                writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
                writerDidStart = true
            }
            
            writerInput.append(sampleBuffer)
        }
        else if writerDidStart
        {
            writerDidStart = false
        }
    }
    
    private var writerDidStart = false
}

struct WeakRef<T: AnyObject>: Hashable where T: Hashable {
    weak var object: T?
}

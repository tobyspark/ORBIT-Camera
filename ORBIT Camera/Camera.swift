//
//  Camera.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/03/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
//

import UIKit
import AVFoundation
import os

/// Functionality to capture videos and run a preview (i.e. a camera viewfinder)
///
/// The core part is an AVCaptureSession, which takes the device input and has to run at a device format. This is currently set to `hd1920x1080`.
/// To get frames out of  AVCaptureSession, an AVCaptureVideoDataOutput is created. This delivers frames to `captureOutput`.
/// These frames are then set to any preview views registered with the camera. These are `PreviewMetalView` which resizes to fill while maintaining aspect ratio.
/// Note an `AVCaptureVideoPreviewLayer` is insufficient as a) fails on multiple instances and b) we cannot manipulate the frames to e.g. increase contrast as an aid to the visually impaired.
/// To record square video, i.e. to encode a square crop of that captureSession stream to a file, an `AVAssetWriterInput` can be configured to scale and crop to a square. Again, `captureOutput` supplies the frames.
/// Note `AVCaptureMovieFileOutput` is inadequate as you cannot set the video format sufficiently.
///
/// As Xcode's iOS simulator doesn't support video capture, this class becomes inert when compiled for that.
class Camera {
    /// Attach a preview view to this camera. Holds a weak reference.
    /// This previews the video coming from the device. A `PreviewMetalView` will fill the view's frame while maintaining the aspect ratio.
    /// As currently set, the frames sent to the preview are 1920x1080. The view renders this onto whatever the size frame is, for a square frame this will visually match the 1080x1080 recorded output.
    func attachPreview(to view: PreviewMetalView) {
        #if !targetEnvironment(simulator)
        videoDataDelegate.queue.async {
            view.rotation = .rotate180Degrees
            // Holding a weak ref should allow 'detach' of the views.
            let result = self.previewViews.insert(WeakRef(object: view))
            if result.inserted {
                os_log("Camera adding preview", log: appCamLog, type: .debug)
            }
        }
        #endif
    }

    func detachPreview(from view: PreviewMetalView) {
        #if !targetEnvironment(simulator)
        videoDataDelegate.queue.async {
            self.previewViews = self.previewViews.filter({ (viewRef) -> Bool in
                let found = viewRef.object == view
                if found {
                    os_log("Camera removing preview", log: appCamLog, type: .debug)
                }
                return !found
            })
        }
        #endif
    }
    
    /// Start the capture session, i.e. turn the device's camera on
    func start() {
        #if !targetEnvironment(simulator)
        queue.async {
            if self.stopCancellableWorkItem != nil {
                os_log("Camera cancelling pending stop", log: appCamLog, type: .debug)
                self.stopCancellableWorkItem?.cancel()
                self.stopCancellableWorkItem = nil
            }
            if !self.captureSession.isRunning {
                os_log("Camera start", log: appCamLog, type: .debug)
                self.captureSession.startRunning()
            }
        }
        #endif
    }
    
    /// Stop the capture session, i.e. turn the device's camera off
    func stop() {
        #if !targetEnvironment(simulator)
        queue.async {
            if self.captureSession.isRunning {
                os_log("Camera stop", log: appCamLog, type: .debug)
                self.captureSession.stopRunning()
            }
        }
        #endif
    }
    
    /// Stop the capture session after a period of grace, where any call to start the session will cancel the stop
    func stopCancellable() {
        #if !targetEnvironment(simulator)
        queue.async {
            // Update (i.e. cancel old and create new) the stop code to enqueue
            self.stopCancellableWorkItem?.cancel()
            self.stopCancellableWorkItem = DispatchWorkItem() { [weak self] in
                guard let self = self
                else { return }
                if self.captureSession.isRunning {
                    os_log("Camera stop, was cancellable", log: appCamLog, type: .debug)
                    self.captureSession.stopRunning()
                }
            }
            // Schedule stop for x seconds in the future
            self.queue.asyncAfter(deadline: DispatchTime.now() + .seconds(2), execute: self.stopCancellableWorkItem!)
        }
        #endif
    }
    
    /// Start recording to a file
    func recordStart(to url: URL, completionHandler: @escaping ()->Void ) {
        #if !targetEnvironment(simulator)
        queue.async {
            // The capture objects should only exist during recording.
            guard
                self.writerInput == nil,
                self.writer == nil
            else {
                os_log("Stale capture object(s) on recordStart", log: appCamLog)
                return
            }

            // Create AVAssetWriterInput
            // The capture session has to operate using device (e.g. hardware) formats,
            // so this is where the crop happens
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                // Encode to H264
                AVVideoCodecKey: AVVideoCodecType.h264,
                // Scale and crop to square
                AVVideoWidthKey: Settings.recordingResolution.width,
                AVVideoHeightKey:  Settings.recordingResolution.height,
                AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            ])
            writerInput.expectsMediaDataInRealTime = true
            
            // Create AVAssetWriter
            guard
                let writer = try? AVAssetWriter(url: url, fileType: .mp4),
                writer.canAdd(writerInput)
            else {
                os_log("Could not create AVAssetWriter", log: appCamLog)
                return
            }
            writer.add(writerInput)
            guard writer.startWriting()
            else {
                os_log("Could not start AVAssetWriter", log: appCamLog)
                return
            }
        
            self.videoDataDelegate.queue.sync {
                // Now everything is set, declare the record objects
                // This will start recording, enacted in the videoDataSource delegate
                self.writer = writer
                self.writerInput = writerInput
                self.completionHandler = completionHandler
            }
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
                   let completionHandler = self.completionHandler
                {
                    writer.finishWriting {
                        DispatchQueue.main.async {
                            os_log("Camera.recordStop calling completionHandler", log: appCamLog, type: .debug)
                            completionHandler()
                        }
                    }
                }
                self.writer = nil
                self.writerInput = nil
                self.completionHandler = nil
            }
        }
        #endif
    }
    
    init() {
        // FIXME: Debugging (for now)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: .AVCaptureSessionDidStartRunning, object: self.captureSession)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: .AVCaptureSessionDidStopRunning, object: self.captureSession)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotification), name: .AVCaptureSessionRuntimeError, object: self.captureSession)
        
        #if !targetEnvironment(simulator)
        queue.async {
            // Create CaptureDelegate
            self.videoDataDelegate = VideoDataDelegate()
            self.videoDataDelegate.camera = self
            
            // AVCaptureSession BEGIN
            self.captureSession.beginConfiguration()
            
            // Configure the AVCaptureSession
            if self.captureSession.canSetSessionPreset(Settings.captureSessionPreset) {
                self.captureSession.sessionPreset = Settings.captureSessionPreset
            } // Otherwise, default.
            
            // Create AVCaptureDeviceInput
            guard
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice),
                self.captureSession.canAddInput(videoDeviceInput)
            else {
                os_log("Could not configure camera", log: appCamLog)
                return
            }
            self.captureSession.addInput(videoDeviceInput)

            // Create AVCaptureVideoDataOutput
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self.videoDataDelegate, queue: self.videoDataDelegate.queue)
            guard self.captureSession.canAddOutput(videoDataOutput)
            else {
                os_log("Could not add AVCaptureVideoDataOutput", log: appCamLog)
                return
            }
            self.captureSession.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                // Set portrait, to match non-rotating portrait UI
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                // Stablise if wanted
                //   This delays the viewfinder to the point of being unusable.
                //   Could set up separate outputs for non-stabilised viewfinder and stablilised recording, but that is a) more code and b) has UX implications, where the recorded video appearing is delayed by a second or more.
                //   What is better for machine learning / ORBIT dataset?
                if Settings.captureSessionStablisesVideo,
                   connection.isVideoStabilizationSupported
                {
                    connection.preferredVideoStabilizationMode = .auto
                }
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
        os_log("%{public}s", log: appCamLog, type: .debug, notification.name.rawValue)
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
    
    /// Capture completion handler, should only exist during recording
    private var completionHandler: ( ()->Void )?
    
    /// Preview layers to update
    fileprivate var previewViews = Set<WeakRef<PreviewMetalView>>()
    
    /// The current, if any, stopCancellable work item. Used to stop the capture session after a period of grace, where any call to start the session will cancel the stop
    private var stopCancellableWorkItem: DispatchWorkItem?
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
                    os_log("Camera removing previewLayer", log: appCamLog, type: .debug)
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

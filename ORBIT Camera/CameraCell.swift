//
//  CameraCell.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

/// A collection view cell that can preview video capture
class CameraCell: UICollectionViewCell {
    var previewLayer: AVCaptureVideoPreviewLayer {
        let previewLayer = layer as! AVCaptureVideoPreviewLayer
        // FIXME: This might be moot when/if capturing square video
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

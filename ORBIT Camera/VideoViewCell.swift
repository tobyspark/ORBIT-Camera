//
//  VideoViewCell.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 06/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation

/// A collection view cell that displays a looping video
class VideoViewCell: UICollectionViewCell {
    var videoURL: URL? {
        get { nil } // Won't ever get
        set {
            guard
                let videoURL = newValue
            else {
                queuePlayer = nil
                playerLooper = nil
                return
            }

            let playerItem = AVPlayerItem(url: videoURL)
            queuePlayer = AVQueuePlayer()
            playerLooper = AVPlayerLooper(player: queuePlayer!, templateItem: playerItem)
            queuePlayer!.play()
                
            playerLayer.player = queuePlayer
        }
    }
    
    func play() { queuePlayer?.play() }
    func pause() { queuePlayer?.pause() }
    
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?

    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

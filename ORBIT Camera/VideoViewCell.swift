//
//  VideoViewCell.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 06/03/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
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
                playerLayer.player = nil
                looper = nil
                return
            }
            
            // Ideal UX: loop videos. However, if low power, just show a still frame.
            let playerItem = AVPlayerItem(url: videoURL)
            if Settings.lowPowerModeDoesNotHaveVideoPlayback && ProcessInfo.processInfo.isLowPowerModeEnabled {
                let player = AVPlayer(playerItem: playerItem)
                player.seek(to: CMTime(seconds: 5, preferredTimescale: 1)) // Jump a little in
                playerLayer.player = player
            } else {
                let queuePlayer = AVQueuePlayer()
                looper = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
                playerLayer.player = queuePlayer
            }
        }
    }
    
    func play() {
        guard ProcessInfo.processInfo.isLowPowerModeEnabled == false
        else { return }
        playerLayer.player?.play()
    }
    func pause() {
        guard ProcessInfo.processInfo.isLowPowerModeEnabled == false
        else { return }
        playerLayer.player?.pause()
    }

    private var looper: AVPlayerLooper?
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

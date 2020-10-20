//
//  Settings.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import QuartzCore
import AVFoundation

struct Settings {
    static let endpointCreateParticipant = "https://example.com/phasetwo/api/createparticipant/"
    struct endpointCreateParticipantRequest: Codable {
        let name: String
        let email: String
    }
    struct endpointCreateParticipantResponse: Codable {
        let auth_credential: String
    }

    static let endpointParticipant = "https://example.com/phasetwo/api/participant/"
    
    static let endpointThing = "https://example.com/phasetwo/api/thing/"
    static func endpointThing(id orbitID: Int) -> URL {
        URL(string: Settings.endpointThing)!.appendingPathComponent("\(orbitID)/")
    }
    
    static let endpointVideo = "https://example.com/phasetwo/api/video/"
    static func endpointVideo(id orbitID: Int) -> URL {
        URL(string: Settings.endpointVideo)!.appendingPathComponent("\(orbitID)/")
    }
    
    static let captureSessionPreset: AVCaptureSession.Preset = .hd1920x1080
    static let captureSessionStablisesVideo = false
    static let recordingResolution = CGSize(width: 1080, height: 1080)
    
    static let desiredVideoLength: [Video.Kind: TimeInterval] = [
        .test: 15,
        .train: 25,
    ]
    
    static let videoTip: [Video.Kind: String] = [
        .test: "Testing: the whole scene, amongst your other stuff",
        .train: "Training: place on a clear surface, with no other stuff",
    ]

    static let videoTipVerbose: [Video.Kind: String] = [
        .test: "To take a video to test the A.I. go to where you usually keep your thing and record the whole scene, showing the thing amongst your other stuff. Take each testing video from a different angle.",
        .train: "To take a video to train the A.I. place your thing on a clear surface with no other objects. Take each training video on a different surface.",
    ]
    
    static let lowPowerModeDoesNotHaveVideoPlayback = true
    
    static let recordButtonRingWidth: CGFloat = 6
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
    
    static let completedThingsTarget = 5
    
    static let videoKindSlots = [
        (kind: Video.Kind.test, slots: 2),
        (kind: Video.Kind.train, slots: 5),
    ]
    
    static let verboseDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        return df
    }()
    
    static let apiDateFomatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

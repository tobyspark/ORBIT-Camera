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
    static let endpointCreateParticipant = "https://example.com/phaseone/api/createparticipant/"
    struct endpointCreateParticipantRequest: Codable {
        let name: String
        let email: String
    }
    struct endpointCreateParticipantResponse: Codable {
        let auth_credential: String
    }
    
    static let endpointThing = "https://example.com/phaseone/api/thing/"
    static let endpointVideo = "https://example.com/phaseone/api/video/"
    
    static let captureSessionPreset: AVCaptureSession.Preset = .hd1920x1080
    static let recordingResolution = CGSize(width: 1080, height: 1080)
    
    static let recordTimeOutSecs: TimeInterval = 120
    
    static let recordButtonRingWidth: CGFloat = 6
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd/MM" // TODO: Localise
        return df
    }()
    
    static let verboseDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short
        return df
    }()
}

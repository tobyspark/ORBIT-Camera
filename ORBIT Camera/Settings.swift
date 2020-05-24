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
    static let endpointCreateParticipant = "https://orbit-data.city.ac.uk/phaseone/api/createparticipant/"
    struct endpointCreateParticipantRequest: Codable {
        let name: String
        let email: String
    }
    struct endpointCreateParticipantResponse: Codable {
        let auth_credential: String
    }

    static let endpointParticipant = "https://orbit-data.city.ac.uk/phaseone/api/participant/"
    
    static let endpointThing = "https://orbit-data.city.ac.uk/phaseone/api/thing/"
    static func endpointThing(id orbitID: Int) -> URL {
        URL(string: Settings.endpointThing)!.appendingPathComponent("\(orbitID)/")
    }
    
    static let endpointVideo = "https://orbit-data.city.ac.uk/phaseone/api/video/"
    static func endpointVideo(id orbitID: Int) -> URL {
        URL(string: Settings.endpointVideo)!.appendingPathComponent("\(orbitID)/")
    }
    
    static let captureSessionPreset: AVCaptureSession.Preset = .hd1920x1080
    static let captureSessionStablisesVideo = false
    static let recordingResolution = CGSize(width: 1080, height: 1080)
    
    static let recordTimeOutSecs: TimeInterval = 120
    
    static let recordButtonRingWidth: CGFloat = 6
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
    
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

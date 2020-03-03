//
//  Settings.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation

struct Settings {
    static let endpointThing = "https://xxx.ngrok.io/phaseone/api/thing/"
    static let endpointVideo = "https://xxx.ngrok.io/phaseone/api/video/"
    static let participant = Participant(
        id: 0,
        authCredential: "Basic " + Data("0:xxx".utf8).base64EncodedString()
    )
}

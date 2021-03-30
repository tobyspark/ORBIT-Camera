//
//  Settings.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
//

import Foundation

struct Settings {
    static let endpointThing = "https://xxx.ngrok.io/phaseone/api/thing/"
    static let endpointVideo = "https://xxx.ngrok.io/phaseone/api/video/"
    static let authCredential = "Basic " + Data("0:xxx".utf8).base64EncodedString()
    
    static let labels = ["One", "Two", "Three", "Four", "Five"]
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yy-MM-dd-HH-mm-ss"
        return df
    }()
}

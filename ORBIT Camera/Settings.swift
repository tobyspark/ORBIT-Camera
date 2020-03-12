//
//  Settings.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import QuartzCore

struct Settings {
    static let endpointThing = "https://orbit-data.city.ac.uk/phaseone/api/thing/"
    static let endpointVideo = "https://orbit-data.city.ac.uk/phaseone/api/video/"
    
    static let recordButtonRingWidth: CGFloat = 6
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "dd/MM" // TODO: Localise
        return df
    }()
}

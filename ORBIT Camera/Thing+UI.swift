//
//  Thing+UI.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 20/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation

extension Thing {
    /// A short description, suitable for a table view cell detail
    /// Currently reports how many videos of the thing. Could get more complicated, e.g. x to go incentives
    func shortDescription() -> String {
        // FIXME: Use NSLocalizedString pluralization
        switch videosCount {
        case 0:
            return "No videos"
        case 1:
            return "1 video"
        default:
            return "\(videosCount) videos"
        }
    }
}

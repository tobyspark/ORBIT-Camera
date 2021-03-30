//
//  UIColor+CSS.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 22/04/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import UIKit

extension UIColor {
    var css: String {
        get {
            guard
                let model = self.cgColor.colorSpace?.model,
                let c = self.cgColor.components
            else {
                assertionFailure("Failed to inspect UIColor")
                return ""
            }
            
            let c255 = c.map { Int($0 * 255) }
            
            switch model {
            case .rgb:
                return "rgb(\(c255[0]), \(c255[1]), \(c255[2]))"
            case .monochrome:
                return "rgb(\(c255[0]), \(c255[0]), \(c255[0]))"
            default:
                assertionFailure("Failed to convert UIColor")
            }
            return ""
        }
    }
}

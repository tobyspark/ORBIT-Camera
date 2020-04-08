//
//  UIAccessibility+Focus.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 08/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import os

extension UIAccessibility {
    static func focus(element: Any?) {
        guard UIAccessibility.isVoiceOverRunning
        else { return }
        
        guard let element = element
        else {
            os_log("Accessibility focus attempted on nil object")
            return
        }
        
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

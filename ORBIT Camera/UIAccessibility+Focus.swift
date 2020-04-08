//
//  UIAccessibility+Focus.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 08/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

extension UIAccessibility {
    static func focus(element: Any) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
}

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
            os_log("Accessibility focus attempted on nil object", log: appUILog)
            return
        }
        
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
    
    /// Trigger announcing the message after a set delay
    static func announce(message: String, delay: DispatchTimeInterval? = nil) {
        guard UIAccessibility.isVoiceOverRunning
        else { return }
        
        if let delay = delay {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

class AccessibilityElementUsingClosures: UIAccessibilityElement {
    var incrementClosure: ( ()->Void )?
    var decrementClosure: ( ()->Void )?
    var activateClosure: ( ()->Bool )?
    
    override func accessibilityIncrement() {
        if let incrementClosure = incrementClosure {
            incrementClosure()
        }
    }
    
    override func accessibilityDecrement() {
        if let decrementClosure = decrementClosure {
            decrementClosure()
        }
    }
    
    override func accessibilityActivate() -> Bool {
        if let activateClosure = activateClosure {
            return activateClosure()
        }
        return false
    }
}

//
//  UIButton+DynamicType.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 27/09/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

extension UIButton {

    @IBInspectable
    var adjustsFontForContentSizeCategory: Bool {
        set {
            self.titleLabel?.adjustsFontForContentSizeCategory = newValue
        }
        get {
            return self.titleLabel?.adjustsFontForContentSizeCategory ?? false
        }
    }
}

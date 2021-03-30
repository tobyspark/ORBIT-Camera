//
//  UIButton+DynamicType.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 27/09/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
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

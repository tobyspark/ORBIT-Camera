//
//  ErrorLabel.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 05/05/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import UIKit

/// A UILabel that reveals itself when text is set. Intended for error labels. Defaults to red, 12point.
class ErrorLabel: UILabel {
    override var text: String? {
        set {
            let desiredHidden = newValue == nil
            if isHidden != desiredHidden {
                UIView.animate(withDuration: 0.3) { [weak self] in
                    self?.isHidden = desiredHidden
                }
            }
            if newValue != nil {
                super.text = newValue
            }
        }
        get {
            isHidden ? nil : super.text
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initCommon()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initCommon()
    }
    
    func initCommon() {
        text = nil
        textColor = .red
        font = UIFont.preferredFont(forTextStyle: .body)
    }
}

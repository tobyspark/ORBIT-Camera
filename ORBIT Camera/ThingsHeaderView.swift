//
//  ThingsHeaderView.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 09/10/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import UIKit

class ThingsHeaderView: UIStackView {
    init(label labelText: String) {
        super.init(frame: CGRect.zero)
        
        axis = .horizontal
        alignment = .center
        distribution = .equalSpacing
        spacing = 8
    
        let leftLine = UIView()
        leftLine.backgroundColor = UIColor.label
        leftLine.heightAnchor.constraint(equalToConstant: 1).isActive = true
        leftLine.widthAnchor.constraint(equalToConstant: 16).isActive = true
        addArrangedSubview(leftLine)
    
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.text = labelText
        addArrangedSubview(label)
    
        let line = UIView()
        line.backgroundColor = UIColor.label
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let lineWidthConstraint = line.widthAnchor.constraint(equalToConstant: 1000)
        lineWidthConstraint.priority = .defaultLow
        lineWidthConstraint.isActive = true
        addArrangedSubview(line)
        
        isAccessibilityElement = true
        accessibilityTraits.formUnion(.header)
        accessibilityLabel = label.accessibilityLabel
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var detail: UILabel? {
        didSet {
            if oldValue != nil {
                arrangedSubviews[3].removeFromSuperview() // Detail
                arrangedSubviews[3].removeFromSuperview() // Line
                accessibilityHint = ""
            }
            if let detail = detail {
                addArrangedSubview(detail)
                
                let line = UIView()
                line.backgroundColor = UIColor.label
                line.heightAnchor.constraint(equalToConstant: 1).isActive = true
                line.widthAnchor.constraint(equalToConstant: 16).isActive = true
                addArrangedSubview(line)
            
                accessibilityHint = detail.accessibilityLabel
            }
        }
    }
}

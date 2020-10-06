//
//  CompletionLabel.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 05/10/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

struct CompletionCount {
    var name: String = ""
    let count: Int
    let target: Int
}

func completionLabel(_ noun: String, items: [CompletionCount]) -> UILabel {
    let label = UILabel()
    label.textColor = UIColor.secondaryLabel
    
    let countTotal = items.reduce(0) { $0 + $1.count }
    let targetTotal = items.reduce(0) { $0 + $1.target }
    
    // "3 / 7"
    let message = NSMutableAttributedString()
    message.append(NSAttributedString(
        string: "\(countTotal)",
        attributes: countTotal < targetTotal ? [NSAttributedString.Key.foregroundColor: UIColor.label.cgColor] : nil
        )
    )
    message.append(NSAttributedString(
        string: "  ̷ \(targetTotal)"
        )
    )
    label.attributedText = message
    
    // "3 videos. 2 testing videos to go. 2 training videos to go"
    // "7 videos. Complete."
    if countTotal >= targetTotal {
        label.accessibilityLabel = "\(countTotal) videos. Complete."
    } else {
        let accessibilityCountStrings: [String] = items.reduce(into: []) { (acc, x) in
            let remaining = x.target - x.count
            if remaining <= 0 { return }
            acc.append("\(remaining) \(x.name) \(noun)\(remaining == 1 ? "" : "s") to go")
        }
        label.accessibilityLabel = "\(countTotal) \(noun)\(countTotal == 1 ? "" : "s"). \(accessibilityCountStrings.joined(separator: ". "))"
    }
    
    return label
}

//
//  CompletionLabel.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 05/10/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
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
    if countTotal > targetTotal {
        message.append(NSAttributedString(
            string: "\(targetTotal)+ ✓"
            )
        )
    }
    else {
        message.append(NSAttributedString(
            string: "\(countTotal)",
            attributes: countTotal < targetTotal ? [NSAttributedString.Key.foregroundColor: UIColor.label.cgColor] : nil
            )
        )
        message.append(NSAttributedString(
            string: "  ̷ \(targetTotal)"
            )
        )
    }
    label.attributedText = message
    
    // "No videos yet. 2 testing videos to go. 5 training videos to go"
    // "3 videos. 2 testing videos to go. 2 training videos to go"
    // "7 videos. Complete."
    if countTotal >= targetTotal {
        label.accessibilityLabel = "\(countTotal) \(noun). Complete."
    } else {
        let overallCountString = countTotal == 0 ? "No \(noun)s yet" : "\(countTotal) \(noun)\(countTotal == 1 ? "" : "s")"
        let accessibilityCountStrings: [String] = items.reduce(into: []) { (acc, x) in
            let remaining = x.target - x.count
            if remaining <= 0 { return }
            acc.append("\(remaining) \(x.name) \(noun)\(remaining == 1 ? "" : "s") to go")
        }
        label.accessibilityLabel = "\(overallCountString). \(accessibilityCountStrings.joined(separator: ". "))"
    }
    
    return label
}

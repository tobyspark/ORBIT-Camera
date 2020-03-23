//
//  RecordButton.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 11/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit

class RecordButton: UIControl {
    enum RecordingState {
        case idle
        case active(Date)
    }
    
    var recordingState = RecordingState.idle

    override var accessibilityLabel: String? {
        get { "Record" }
        set {}
    }
    
    override var accessibilityHint: String? {
        get { "Records a video" }
        set {}
    }
    
    override var accessibilityTraits: UIAccessibilityTraits {
        get { [super.accessibilityTraits, .button] }
        set {}
    }
    
    func toggleRecord() {
        switch recordingState {
        case .idle:
            recordingState = .active(Date())
        case .active(let date):
            recordingState = .idle
            let duration = DateInterval(start: date, end: Date()).duration
            print("RecordButton active for \(duration)s")
        }
        setNeedsDisplay()
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if isTouchInside {
            toggleRecord()
        }
        
        // Call super after, will update isTracking etc.
        super.endTracking(touch, with: event)
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext()
        else { return }
        
        let outerDiameter = min(bounds.width, bounds.height)
        let ringOrigin = CGPoint(x: bounds.origin.x + Settings.recordButtonRingWidth/2, y: bounds.origin.y + Settings.recordButtonRingWidth/2)
        let ringSize = CGSize(width: outerDiameter - Settings.recordButtonRingWidth, height: outerDiameter - Settings.recordButtonRingWidth)
        let buttonOrigin = CGPoint(x: bounds.origin.x + 2*Settings.recordButtonRingWidth, y: bounds.origin.y + 2*Settings.recordButtonRingWidth)
        let buttonSize = CGSize(width: outerDiameter - 4*Settings.recordButtonRingWidth, height: outerDiameter - 4*Settings.recordButtonRingWidth)
        
        context.setStrokeColor(UIColor.label.cgColor)
        context.setLineWidth(Settings.recordButtonRingWidth)
        context.strokeEllipse(in: CGRect(origin: ringOrigin, size: ringSize))
        
        switch recordingState {
        case .idle:
            context.setFillColor(UIColor.label.cgColor)
        case .active:
            context.setFillColor(UIColor.systemRed.cgColor)
        }
        context.fillEllipse(in: CGRect(origin: buttonOrigin, size: buttonSize))
    }
}

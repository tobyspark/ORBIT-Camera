//
//  RecordButton.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 11/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os

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
            os_log("RecordButton.state active", log: appUILog)
            AudioServicesPlaySystemSound(RecordButton.systemSoundVideoBegin)
            pipCount = 0
            pipTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self](timer) in
                guard let self = self else { return }
                self.pipCount += 1
                if self.pipCount > Int(Settings.recordTimeOutSecs) - 5 {
                    AudioServicesPlaySystemSound(RecordButton.systemSoundTink)
                    return
                }
                if self.pipCount % 5 == 0 {
                    AudioServicesPlaySystemSound(RecordButton.systemSoundTink)
                    return
                }
            })
        case .active(let date):
            recordingState = .idle
            let duration = DateInterval(start: date, end: Date()).duration
            os_log("RecordButton.state idle, active for %fs", log: appUILog, duration)
            pipTimer?.invalidate()
            pipTimer = nil
            AudioServicesPlaySystemSound(RecordButton.systemSoundVideoEnd)
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
        let buttonOrigin = CGPoint(x: bounds.origin.x + 1.5*Settings.recordButtonRingWidth, y: bounds.origin.y + 1.5*Settings.recordButtonRingWidth)
        let buttonSize = CGSize(width: outerDiameter - 3*Settings.recordButtonRingWidth, height: outerDiameter - 3*Settings.recordButtonRingWidth)
        
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
    
    private var pipTimer: Timer?
    private var pipCount: Int = 0
    // SystemSoundID    File name    Category
    // 1117    begin_video_record.caf    BeginVideoRecording
    private static let systemSoundVideoBegin: SystemSoundID = 1117
    // 1118    end_video_record.caf    EndVideoRecording
    private static let systemSoundVideoEnd: SystemSoundID = 1118
    // 1103    Tink.caf    sq_tock.caf    KeyPressed
    private static let systemSoundTink: SystemSoundID = 1103
    // 1104    Tock.caf    sq_tock.caf    KeyPressed
    private static let systemSoundTock: SystemSoundID = 1104
    // 1105    Tock.caf    sq_tock.caf    KeyPressed
    private static let systemSoundTockAlt: SystemSoundID = 1105
}

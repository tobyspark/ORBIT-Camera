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
    
    var stopSecs: TimeInterval?
    var everySecAfter: Int?
    var majorSecs: Int?
    var minorSecs: Int?
    
    func toggleRecord() {
        self.hapticHeavy.impactOccurred()
        
        switch recordingState {
        case .idle:
            recordingState = .active(Date())
            os_log("RecordButton.state active", log: appUILog)
            AudioServicesPlaySystemSound(RecordButton.systemSoundVideoBegin)
            pipCount = 0
            pipTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self](timer) in
                guard let self = self else { return }
                self.pipCount += 1
                if let everyPipAfter = self.everySecAfter,
                   self.pipCount > everyPipAfter
                {
                    self.hapticLight.impactOccurred()
                    return
                }
                if let everyPipAfter = self.everySecAfter,
                   self.pipCount == everyPipAfter
                {
                    AudioServicesPlaySystemSound(RecordButton.systemSoundCamera3PStop)
                    self.hapticHeavy.impactOccurred()
                    return
                }
                if let majorPip = self.majorSecs,
                   self.pipCount % majorPip == 0
                {
                    AudioServicesPlaySystemSound(RecordButton.systemSoundCamera3PStart)
                    self.hapticMedium.impactOccurred()
                    return
                }
                if let minorPip = self.minorSecs,
                   self.pipCount % minorPip == 0
                {
                    self.hapticLight.impactOccurred()
                    return
                }
            })
            if let timeout = stopSecs {
                stopTimer?.invalidate()
                stopTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false, block: { [weak self] (timer) in
                    guard let self = self else { return }
                    if case .active = self.recordingState {
                        self.toggleRecord()
                        self.sendActions(for: .touchUpInside)
                    }
                })
            }
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
    
    func startTimeout(_ duration: TimeInterval) {
        stopTimer?.invalidate()
        stopTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false, block: { [weak self] (timer) in
            guard let self = self else { return }
            if case .active = self.recordingState {
                self.toggleRecord()
                self.sendActions(for: .touchUpInside)
            }
        })
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
    
    private var stopTimer: Timer?
    
    private var pipTimer: Timer?
    private var pipCount: Int = 0
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticHeavy = UIImpactFeedbackGenerator(style: .heavy)
    
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
    
    private static let systemSoundCamera3PRetry: SystemSoundID = {
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/nano/3rdParty_Retry_Haptic.caf")
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return soundID
    }()
    
    private static let systemSoundCamera3PStart: SystemSoundID = {
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/nano/3rdParty_Start_Haptic.caf")
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return soundID
    }()
    
    private static let systemSoundCamera3PStop: SystemSoundID = {
        let url = URL(fileURLWithPath: "/System/Library/Audio/UISounds/nano/3rdParty_Stop_Haptic.caf")
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return soundID
    }()
}

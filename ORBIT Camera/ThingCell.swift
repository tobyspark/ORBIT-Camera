//
//  ThingCell.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 04/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB

// A standard table view cell to display a Thing, with database observers to keep the view updated
class ThingCell: UITableViewCell {
    var thing: Thing? {
        didSet { configureView() }
    }
    
    // Needed to respond to dark mode changes, as the attributed string needs to be re-made
    override func layoutSubviews() {
        super.layoutSubviews()
        configureView()
    }
    
    func configureView() {
        thingObserver = nil
        videosObserver = nil
        
        guard
            let thing = thing,
            let thingID = thing.id
        else {
            return
        }
        
        let thingRequest = Thing.filter(Video.Columns.id == thingID)
        let thingObservation = thingRequest.observationForFirst()
        thingObserver = try! thingObservation.start(
            in: dbQueue,
            onChange: { [weak self] thing in
                guard
                    let self = self,
                    let thing = thing
                else { return }
                
                self.textLabel!.text = thing.labelParticipant
        })
        
        let videosRequest = Video.filter(Video.Columns.thingID == thingID)
        let videosObservation = videosRequest.observationForAll()
        videosObserver = try! videosObservation.start(
            in: dbQueue,
            onChange: { [weak self] videos in
                guard
                    let self = self,
                    let detailTextLabel =  self.detailTextLabel
                else { return }
                
                let count = videos.count
                let total = Settings.videoKindSlots.reduce(0) { return $0 + $1.slots }
                
                // "3 / 7"
                let message = NSMutableAttributedString()
                message.append(NSAttributedString(
                    string: "\(count)",
                    attributes: count < total ? [NSAttributedString.Key.foregroundColor: UIColor.label.cgColor] : nil
                    )
                )
                message.append(NSAttributedString(
                    string: "  ̷ \(total)"
                    )
                )
                detailTextLabel.attributedText = message
                
                // "3 videos. 2 testing videos to go. 2 training videos to go"
                // "7 videos. Complete."
                if count >= total {
                    detailTextLabel.accessibilityLabel = "\(count) videos. Complete."
                } else {
                    let accessibilityCountStrings: [String] = Settings.videoKindSlots.reduce(into: []) { (acc, x) in
                        let kindVideos = videos.filter( { video in video.kind == x.kind } )
                        let kindToGo = x.slots - kindVideos.count
                        if kindToGo <= 0 { return }
                        acc.append("\(kindToGo) \(x.kind.verboseDescription) video\(kindToGo == 1 ? "" : "s") to go")
                    }
                    detailTextLabel.accessibilityLabel = "\(count) videos. \(accessibilityCountStrings.joined(separator: ". "))"
                }
        })
    }
    
    private var thingObserver: TransactionObserver?
    private var videosObserver: TransactionObserver?
    
    private static func smallCapsVariant(of font: UIFont) -> UIFont {
        let descriptor = font.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName.featureSettings: [
                [
                    UIFontDescriptor.FeatureKey.featureIdentifier: kUpperCaseType,
                    UIFontDescriptor.FeatureKey.typeIdentifier: kUpperCaseSmallCapsSelector
                ]
            ]
        ])
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    
    private static func smallVariant(of font: UIFont) -> UIFont {
        UIFont(descriptor: font.fontDescriptor, size: font.pointSize*2/3)
    }
}

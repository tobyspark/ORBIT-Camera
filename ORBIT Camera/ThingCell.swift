//
//  ThingCell.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 04/04/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
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
        
        let thingFetch = Thing.filter(Video.Columns.id == thingID).fetchOne
        let thingObservation = ValueObservation.tracking(thingFetch)
        thingObserver = thingObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
                assertionFailure()
            },
            onChange: { [weak self] thing in
                guard
                    let self = self,
                    let thing = thing
                else { return }
                
                self.textLabel!.text = thing.labelParticipant
        })
        
        let videosFetch = Video.filter(Video.Columns.thingID == thingID).fetchAll
        let videosObservation = ValueObservation.tracking(videosFetch)
        videosObserver = videosObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
                assertionFailure()
            },
            onChange: { [weak self] videos in
                guard
                    let self = self,
                    let detailTextLabel =  self.detailTextLabel
                else { return }
                
                let counts: [CompletionCount] = Settings.videoKindSlots.reduce(into: []) { (acc, x) in
                    let kindVideos = videos.filter( { video in video.kind == x.kind } )
                    acc.append(CompletionCount(name: x.kind.description, count: kindVideos.count, target: x.slots))
                }
                let label = completionLabel("video", items: counts)
                
                detailTextLabel.attributedText = label.attributedText
                detailTextLabel.accessibilityLabel = label.accessibilityLabel
        })
    }
    
    private var thingObserver: DatabaseCancellable?
    private var videosObserver: DatabaseCancellable?
    
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

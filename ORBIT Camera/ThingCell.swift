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
        didSet {
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
                    
                    let countStrings: [String] = Video.Kind.allCases.map { kind in
                        let kindVideos = videos.filter( { video in video.kind == kind } )
                        return "\(kind.description): \(kindVideos.count)"
                    }
                    let accessibilityCountStrings: [String] = Video.Kind.allCases.map { kind in
                        let kindVideos = videos.filter( { video in video.kind == kind } )
                        let count = (kindVideos.count == 0) ? "No" : "\(kindVideos.count)"
                        let videoPluralised = (kindVideos.count > 1) ? "videos" : "video"
                        return "\(count) \(kind.verboseDescription) \(videoPluralised) "
                    }
                    detailTextLabel.text = "Videos – \( countStrings.joined(separator: ", ") )"
                    detailTextLabel.accessibilityLabel = accessibilityCountStrings.joined(separator: ", ")
            })
        }
    }
    
    private var thingObserver: TransactionObserver?
    private var videosObserver: TransactionObserver?
}

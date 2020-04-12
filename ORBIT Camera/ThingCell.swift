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
                    
                    let message = NSMutableAttributedString(
                        string: "Videos – ",
                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.placeholderText.cgColor]
                    )
                    for (index, kind) in Video.Kind.allCases.enumerated() {
                        let kindVideos = videos.filter( { video in video.kind == kind } )
                        let separator = index > 0 ? ", " : ""
                        message.append(NSMutableAttributedString(
                            string: "\(separator)\(kind.description):",
                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.placeholderText.cgColor]
                            )
                        )
                        message.append(NSAttributedString(
                            string: " \(kindVideos.count)",
                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.label.cgColor]
                            )
                        )
                    }
                    detailTextLabel.attributedText = message
                    
                    let accessibilityCountStrings: [String] = Video.Kind.allCases.map { kind in
                        let kindVideos = videos.filter( { video in video.kind == kind } )
                        let count = (kindVideos.count == 0) ? "No" : "\(kindVideos.count)"
                        let videoPluralised = (kindVideos.count > 1) ? "videos" : "video"
                        return "\(count) \(kind.verboseDescription) \(videoPluralised) "
                    }
                    detailTextLabel.accessibilityLabel = accessibilityCountStrings.joined(separator: ", ")
            })
        }
    }
    
    private var thingObserver: TransactionObserver?
    private var videosObserver: TransactionObserver?
}

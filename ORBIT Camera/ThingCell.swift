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
            videoCountObserver = nil
            
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
            
            let videoCountRequest = Video.filter(Video.Columns.thingID == thingID)
            let videoCountObservation = videoCountRequest.observationForCount()
            videoCountObserver = try! videoCountObservation.start(
                in: dbQueue,
                onChange: { [weak self] count in
                    guard let self = self
                    else { return }
                    
                    switch count {
                    case 0:
                        self.detailTextLabel!.text = "No videos"
                    case 1:
                        self.detailTextLabel!.text = "1 video"
                    default:
                        self.detailTextLabel!.text = "\(count) videos"
                    }
            })
        }
    }
    
    private var thingObserver: TransactionObserver?
    private var videoCountObserver: TransactionObserver?
}

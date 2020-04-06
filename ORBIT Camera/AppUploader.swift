//
//  AppUploader.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB
import os

var appUploader: AppUploader!

struct AppUploader {
    
    var thingsObserver: TransactionObserver!
    var videosObserver: TransactionObserver!
    
    init() {
        guard dbQueue != nil
        else { fatalError("AppUploader without qbQueue set")}
        
        guard appNetwork != nil
        else { fatalError("AppUploader without appNetwork set")}
        
        let thingsRequest = Thing.filter(Thing.Columns.orbitID == nil)
        let thingsObservation = thingsRequest.observationForAll()
        thingsObserver = thingsObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: self.enqueue(things:)
        )

        let videosRequest = Video.filter(Video.Columns.orbitID == nil)
        let videosObservation = videosRequest.observationForAll()
        videosObserver = videosObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: self.enqueue(videos:)
        )
        
        // TODO: Set up observer for participant credential change
        
        // TODO: Schedule retries, e.g. daily?
    }
    
    func enqueue(things: [Thing]) {
        guard let participant = try? Participant.appParticipant()
        else {
            os_log("Cannot enqueue things for upload, no participant")
            return
        }
        for thing in things {
            os_log("Attempting upload of Thing %d in foreground session", type: .debug, thing.id!)
            thing.upload(by: participant, using: &appNetwork.thingsSession)
        }
    }
    
    func enqueue(videos: [Video]) {
        guard let participant = try? Participant.appParticipant()
        else {
            os_log("Cannot enqueue videos for upload, no participant")
            return
        }
        for video in videos {
            os_log("Attempting upload of Video %d in background session", type: .debug, video.id!)
            video.upload(by: participant, using: &appNetwork.videosSession)
        }
    }
    
    static func setup() {
        appUploader = AppUploader()
    }
}

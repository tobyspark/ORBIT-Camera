//
//  AppUploader.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import Network
import GRDB
import os

var appUploader: AppUploader!

/// A struct, instantiated as a global, to upload whatever needs to be uploaded, automatically
/// When things with no ORBIT ids change, upload
/// When videos with no ORBIT ids change, upload
/// When participant credential changes, upload
/// When network connectivity appears, upload
struct AppUploader {
    
    // Database observation
    let thingsObserver: TransactionObserver
    let videosObserver: TransactionObserver
    let participantObserver: TransactionObserver
    
    // Network observation
    let networkMonitor = NWPathMonitor()
    let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        guard dbQueue != nil
        else { fatalError("AppUploader without qbQueue set")}
        
        guard appNetwork != nil
        else { fatalError("AppUploader without appNetwork set")}
        
        // Note there is a lot of copy and paste following, to set up enqueing the items. However more elegant options were failing to compile with `capture mutable self` errors, despite not (in this surface level code at least) mutating self.
        
        // Background serial queue. Upload work should be atomised onto this, to not block foreground (or other background) activity
        let uploadQueue = DispatchQueue(label: "Upload Queue", qos: .background, attributes: [], autoreleaseFrequency: .inherit, target: nil)
        
        let thingsRequest = Thing.filter(Thing.Columns.orbitID == nil)
        let thingsObservation = thingsRequest.observationForAll()
        thingsObserver = thingsObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: { things in
                for thing in things {
                    uploadQueue.async {
                        os_log("Attempting upload of %{public}s in foreground session (things change)", log: appNetLog, type: .debug, thing.description)
                        appNetwork.thingsSession.upload(thing)
                    }
                }
            }
        )
        
        let videosRequest = Video.filter(Video.Columns.orbitID == nil)
        let videosObservation = videosRequest.observationForAll()
        videosObserver = videosObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: { videos in
                for video in videos {
                    uploadQueue.async {
                        os_log("Attempting upload of %{public}s in background session (videos change)", log: appNetLog, type: .debug, video.description)
                        appNetwork.videosSession.upload(video)
                    }
                }
            }
        )
        
        let participantRequest = Participant.all()
        let participantObservation = participantRequest.observationForFirst()
        participantObserver = participantObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: { participant in
                let things = try! dbQueue.read { db in try thingsRequest.fetchAll(db) }
                for thing in things {
                    uploadQueue.async {
                        os_log("Attempting upload of %{public}s in foreground session (participant credential change)", log: appNetLog, type: .debug, thing.description)
                        appNetwork.thingsSession.upload(thing)
                    }
                }
                let videos = try! dbQueue.read { db in try videosRequest.fetchAll(db) }
                for video in videos {
                    uploadQueue.async {
                        os_log("Attempting upload of %{public}s in background session (participant credential change)", log: appNetLog, type: .debug, video.description)
                        appNetwork.videosSession.upload(video)
                    }
                }
            }
        )
        
        networkMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied { 
                let things = try! dbQueue.read { db in try thingsRequest.fetchAll(db) }
                for thing in things {
                    uploadQueue.async {
                        os_log("Attempting upload of %{public}s in foreground session (network change)", log: appNetLog, type: .debug, thing.description)
                        appNetwork.thingsSession.upload(thing)
                    }
                }
                let videos = try! dbQueue.read { db in try videosRequest.fetchAll(db) }
                for video in videos {
                    uploadQueue.async {
                        os_log("Attempting upload of %{public}s in background session (network change)", log: appNetLog, type: .debug, video.description)
                        appNetwork.videosSession.upload(video)
                    }
                }
                appNetwork.actionDeleteURLs()
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    static func setup() {
        DispatchQueue.global(qos: .background).async {
            appUploader = AppUploader()
        }
    }
}

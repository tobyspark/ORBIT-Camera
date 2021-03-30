//
//  AppUploader.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/04/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
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
    let thingsObserver: DatabaseCancellable
    let videosObserver: DatabaseCancellable
    let participantObserver: DatabaseCancellable
    
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
        
        let thingsFetch = Thing.filter(Thing.Columns.orbitID == nil).fetchAll
        let thingsObservation = ValueObservation.tracking(thingsFetch)
        thingsObserver = thingsObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: { things in
                for thing in things {
                    uploadQueue.async {
                        guard let authCredential = appNetwork.authCredential
                        else { return }
                        os_log("Attempting upload of %{public}s in foreground session (things change)", log: appNetLog, type: .debug, thing.description)
                        appNetwork.thingsSession.upload(thing, with: authCredential)
                    }
                }
            }
        )
        
        let videosFetch = Video.filter(Video.Columns.orbitID == nil).fetchAll
        let videosObservation = ValueObservation.tracking(videosFetch)
        videosObserver = videosObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: { videos in
                for video in videos {
                    uploadQueue.async {
                        guard let authCredential = appNetwork.authCredential
                        else { return }
                        os_log("Attempting upload of %{public}s in background session (videos change)", log: appNetLog, type: .debug, video.description)
                        appNetwork.videosSession.upload(video, with: authCredential)
                    }
                }
            }
        )
        
        let participantFetch = Participant.all().fetchOne // TODO: check why `all` is there
        let participantObservation = ValueObservation.tracking(participantFetch)
        participantObserver = participantObservation.start(
            in: dbQueue,
            onError: { error in
                print(error)
            },
            onChange: { participant in
                // Set credential for API access as participant
                appNetwork.authCredential = participant?.authCredential
                
                // Action pending API tasks
                let things = try! dbQueue.read { db in try thingsFetch(db) }
                for thing in things {
                    uploadQueue.async {
                        guard let authCredential = appNetwork.authCredential
                        else { return }
                        os_log("Attempting upload of %{public}s in foreground session (participant credential change)", log: appNetLog, type: .debug, thing.description)
                        appNetwork.thingsSession.upload(thing, with: authCredential)
                    }
                }
                let videos = try! dbQueue.read { db in try videosFetch(db) }
                for video in videos {
                    uploadQueue.async {
                        guard let authCredential = appNetwork.authCredential
                        else { return }
                        os_log("Attempting upload of %{public}s in background session (participant credential change)", log: appNetLog, type: .debug, video.description)
                        appNetwork.videosSession.upload(video, with: authCredential)
                    }
                }
                appNetwork.actionDeleteURLs()
            }
        )
        
        networkMonitor.pathUpdateHandler = { path in
            if path.status == .satisfied,
                Self.networkNextBackoffTime.compare(Date()) == .orderedAscending
            {
                let things = try! dbQueue.read { db in try thingsFetch(db) }
                for thing in things {
                    uploadQueue.async {
                        guard let authCredential = appNetwork.authCredential
                        else { return }
                        os_log("Attempting upload of %{public}s in foreground session (network change)", log: appNetLog, type: .debug, thing.description)
                        appNetwork.thingsSession.upload(thing, with: authCredential)
                    }
                }
                let videos = try! dbQueue.read { db in try videosFetch(db) }
                for video in videos {
                    uploadQueue.async {
                        guard let authCredential = appNetwork.authCredential
                        else { return }
                        os_log("Attempting upload of %{public}s in background session (network change)", log: appNetLog, type: .debug, video.description)
                        appNetwork.videosSession.upload(video, with: authCredential)
                    }
                }
                appNetwork.actionDeleteURLs()
                
                // Set to 30mins in future
                // OK, really, this isn't a back-off. Should progressively increasing the interval, and resetting on success. 
                Self.networkNextBackoffTime = Date(timeIntervalSinceNow: 30*60)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    static func setup() {
        DispatchQueue.global(qos: .background).async {
            appUploader = AppUploader()
        }
    }
    
    static var networkNextBackoffTime = Date() // FIXME: This is an avoiding mutating self hack
}

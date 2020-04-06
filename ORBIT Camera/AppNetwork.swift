//
//  AppDelegate+URLSessionDelegate.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

/// Abstract: Support network transfers in the background. Provides the background URLSession and background-requiring delegates.

// Note: this is patterned on AppDatabase. A global, a struct static func to initialise it, delegates not on the struct etc. might look a bit wierd, but this works out neatly and swifty, avoiding obj-c classes, singletons and suchlike.

import UIKit
import os

var appNetwork: AppNetwork!

/// A struct, instantiated as an app global, to support network transfers in the backround.
struct AppNetwork {
    
    /// The network session used for things
    var thingsSession: AppURLSession
    
    /// The network session used for videos
    var videosSession: AppURLSession!
    
    /// The completion handler to call once all background tasks have completed
    var completionHandler: (() -> Void)?
    
    /// Configure and assign the app's network struct
    static func setup(delegate: URLSessionDelegate) throws {
        let thingsConfig = URLSessionConfiguration.ephemeral
        let videosConfig = URLSessionConfiguration.background(withIdentifier: "uk.ac.city.orbit-camera")
        videosConfig.isDiscretionary = true
        videosConfig.sessionSendsLaunchEvents = true
        appNetwork = AppNetwork(
            thingsSession: AppURLSession(session: URLSession(configuration: thingsConfig, delegate: delegate, delegateQueue: nil)),
            videosSession: AppURLSession(session: URLSession(configuration: videosConfig, delegate: delegate, delegateQueue: nil)),
            completionHandler: nil
        )
    }
}

struct AppURLSession {
    let session: URLSession
    var tasks: [Int: Uploadable] = [:]
}

extension AppDelegate: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            appNetwork.completionHandler?()
            appNetwork.completionHandler = nil
        }
    }
}

extension AppDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        switch session {
        case appNetwork.thingsSession.session:
            appNetwork.thingsSession.tasks[task.taskIdentifier] = nil
        case appNetwork.videosSession.session:
            appNetwork.videosSession.tasks[task.taskIdentifier] = nil
        default:
            fatalError("Unknown session")
        }
    }
}

extension AppDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let httpResponse = dataTask.response as? HTTPURLResponse
        else {
            os_log("URLSessionDataDelegate dataTaskDidReceive – could not parse response")
            return
        }
        guard (200..<300).contains(httpResponse.statusCode)
        else {
            os_log(
                "URLSessionDataDelegate dataTaskDidReceive – failed with status %d: %s",
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
            return
        }
        
        let tasks: [Int: Uploadable]
        switch session {
        case appNetwork.thingsSession.session:
            tasks = appNetwork.thingsSession.tasks
        case appNetwork.videosSession.session:
            tasks = appNetwork.videosSession.tasks
        default:
            fatalError("Unknown session")
        }
        
        guard var uploadable = tasks[dataTask.taskIdentifier]
        else {
            os_log("URLSession didReceive cannot find Uploadable with task")
            assertionFailure()
            return
        }
        do {
            try uploadable.uploadDidReceive(data)
        } catch {
            os_log("Upload failed")
        }
    }
}

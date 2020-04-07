//
//  AppDelegate+URLSessionDelegate.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

/// Abstract: Support network transfers, including in the background.
/// - Tracks tasks to the uploadable item.
/// - Provides URLSession infrastructure able to handle background tasks

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
    
    mutating func associate(task taskIdentifier: Int, in session: URLSession, with uploadable: Uploadable) {
        switch session {
        case thingsSession.session:
            thingsSession.associate(taskIdentifier, with: uploadable)
        case videosSession.session:
            videosSession.associate(taskIdentifier, with: uploadable)
        default:
            fatalError("Unknown session")
        }
    }
    
    mutating func clear(task taskIdentifier: Int, in session: URLSession) {
        switch session {
        case thingsSession.session:
            thingsSession.clear(taskIdentifier)
        case videosSession.session:
            videosSession.clear(taskIdentifier)
        default:
            fatalError("Unknown session")
        }
    }
    
    func uploadable(in session: URLSession, with taskIdentifier: Int) -> Uploadable? {
        switch session {
        case thingsSession.session:
            return thingsSession.uploadable(with: taskIdentifier)
        case videosSession.session:
            return videosSession.uploadable(with: taskIdentifier)
        default:
            fatalError("Unknown session")
        }
    }
    
    /// Configure and assign the app's network struct
    static func setup(delegate: URLSessionDelegate) throws {
        let thingsConfig = URLSessionConfiguration.ephemeral
        let videosConfig = URLSessionConfiguration.background(withIdentifier: "uk.ac.city.orbit-camera")
        videosConfig.isDiscretionary = true
        videosConfig.sessionSendsLaunchEvents = true
        appNetwork = AppNetwork(
            thingsSession: AppURLSession(URLSession(configuration: thingsConfig, delegate: delegate, delegateQueue: nil)),
            videosSession: AppURLSession(URLSession(configuration: videosConfig, delegate: delegate, delegateQueue: nil)),
            completionHandler: nil
        )
    }
}

struct AppURLSession {
    let session: URLSession
    
    mutating func associate(_ taskIdentifier: Int, with uploadable: Uploadable) {
        if tasks.keys.contains(taskIdentifier) {
            os_log("Continuing with %{public}s; stale task identifier present in session", uploadable.description)
            assertionFailure("task \(taskIdentifier) in \(tasks)")
        }
        tasks[taskIdentifier] = uploadable
    }
    
    mutating func clear(_ taskIdentifier: Int) {
        tasks[taskIdentifier] = nil
    }
    
    func uploadable(with taskIdentifier: Int) -> Uploadable? {
        return tasks[taskIdentifier]
    }
    
    init(_ session: URLSession) {
        self.session = session
        self.tasks = [:]
    }
    
    private var tasks: [Int: Uploadable]
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
            appNetwork.thingsSession.clear(task.taskIdentifier)
        case appNetwork.videosSession.session:
            appNetwork.videosSession.clear(task.taskIdentifier)
        default:
            fatalError("Unknown session")
        }
    }
}

extension AppDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Find uploadable for this task
        guard var uploadable = appNetwork.uploadable(in: session, with: dataTask.taskIdentifier)
        else {
            os_log("URLSession didReceive cannot find Uploadable with task")
            return
        }
        
        // Check response
        guard let httpResponse = dataTask.response as? HTTPURLResponse
        else {
            os_log("URLSessionDataDelegate dataTaskDidReceive – %{public}s – could not parse response", uploadable.description)
            return
        }
        guard (200..<300).contains(httpResponse.statusCode)
        else {
            os_log(
                "URLSessionDataDelegate dataTaskDidReceive – %{public}s – failed with status %d: %{public}s",
                uploadable.description,
                httpResponse.statusCode,
                HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
            return
        }
        
        // Hand data to uploadable.
        do {
            try uploadable.uploadDidReceive(data)
        } catch {
            os_log("Upload failed for %{public}s", uploadable.description)
        }
    }
}

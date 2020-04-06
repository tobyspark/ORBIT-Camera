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
    
    /// The shared foreground – i.e. instantaneous response – network session
    var foreground: AppURLSession
    
    /// The shared background network session
    var background: AppURLSession!
    
    /// The completion handler to call once all background tasks have completed
    var completionHandler: (() -> Void)?
    
    /// Configure and assign the app's network struct
    static func setup(delegate: URLSessionDelegate) throws {
        let foregroundConfig = URLSessionConfiguration.ephemeral
        let backgroundConfig = URLSessionConfiguration.background(withIdentifier: "uk.ac.city.orbit-camera")
        backgroundConfig.isDiscretionary = true
        backgroundConfig.sessionSendsLaunchEvents = true
        appNetwork = AppNetwork(
            foreground: AppURLSession(session: URLSession(configuration: foregroundConfig, delegate: delegate, delegateQueue: nil)),
            background: AppURLSession(session: URLSession(configuration: backgroundConfig, delegate: delegate, delegateQueue: nil)),
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
        case appNetwork.foreground.session:
            appNetwork.foreground.tasks[task.taskIdentifier] = nil
        case appNetwork.background.session:
            appNetwork.background.tasks[task.taskIdentifier] = nil
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
        case appNetwork.foreground.session:
            tasks = appNetwork.foreground.tasks
        case appNetwork.background.session:
            tasks = appNetwork.background.tasks
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

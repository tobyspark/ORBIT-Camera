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

var appNetwork: AppNetwork!

/// A struct, instantiated as an app global, to support network transfers in the backround.
struct AppNetwork {
    
    /// The shared background network session
    var session: URLSession!
    
    /// The completion handler to call once all background tasks have completed
    var completionHandler: (() -> Void)?
    
    /// Configure and assign the app's network struct
    static func setup(delegate: URLSessionDelegate) throws {
        let config = URLSessionConfiguration.background(withIdentifier: "uk.ac.city.orbit-camera")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        appNetwork = AppNetwork(
            session: URLSession(configuration: config, delegate: delegate, delegateQueue: nil),
            completionHandler: nil
        )
    }
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
    // `urlSession(_:, dataTask:, didReceive:, completionHandler:` is not called for upload tasks in background sessions.
    // Therefore we don't get to find out about server-side errors via HTTPURLResponse.statusCode.
    // So, clean-up an unsuccessful POST here?
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try! Thing.uploadableDidComplete(with: task.taskIdentifier) // Uploadable static func, works for Videos also.
    }
}

extension AppDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var uploadable = try! Thing.uploadable(with: dataTask.taskIdentifier) // Uploadable static func, works for Videos also.
        try! uploadable.uploadDidReceive(data)
    }
}

//
//  AppDelegate+URLSessionDelegate.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

/// Abstract: Support network transfers, including in the background.
/// - Tracks tasks to the uploadable item.
/// - Provides URLSession infrastructure able to handle background tasks

import UIKit
import os

var appNetwork = AppNetwork(delegate: AppNetworkDelegate())

/// A struct, instantiated as an app global, to support network transfers in the backround.
struct AppNetwork {
    
    /// The network session used for things
    var thingsSession: UploadableSession
    
    /// The network session used for videos
    var videosSession: UploadableSession
    
    /// The authorisation credential used to identify the participant
    // TODO: Refactor app to use this? Or move deleteURLS to database, so
    var authCredential: String?
    
    /// The completion handler to call once all background tasks have completed
    var completionHandler: (() -> Void)?
    
    /// A list of server records to ensure deleted, as endpoint URLs to call delete on
    var deleteURLs: [URL] {
        didSet {
            os_log("deleteURLs: %d", log: appNetLog, deleteURLs.count)
            UserDefaults.standard.set(deleteURLs.map { $0.absoluteString }, forKey: "deleteURLs")
            actionDeleteURLs()
        }
    }
    
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
    
    mutating func actionDeleteURLs() {
        guard
            let url = deleteURLs.randomElement(),
            let authCredential = authCredential
        else
            { return }
        
        // Create the delete request
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(authCredential, forHTTPHeaderField: "Authorization")
        
        // Create and action task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let httpResponse = response as? HTTPURLResponse
            else {
                os_log("actionDeleteURLs failed, cannot parse response", log: appNetLog)
                return
            }
            // Deleted success is 204
            // If it's already deleted, 404 Forbidden
            guard httpResponse.statusCode == 204 || httpResponse.statusCode == 404
            else {
                os_log("actionDeleteURLs failed: %d", log: appNetLog, httpResponse.statusCode)
                return
            }
            appNetwork.deleteURLs.removeAll(where: { $0 == url }) // FIXME: appNetwork not self is cheating
        }
        task.resume()
    }
    
    /// Configure and assign the app's network struct
    init(delegate: URLSessionDelegate) {
        let thingsConfig = URLSessionConfiguration.ephemeral
        thingsSession = UploadableSession(URLSession(configuration: thingsConfig, delegate: delegate, delegateQueue: nil))
        
        let videosConfig = URLSessionConfiguration.background(withIdentifier: "uk.ac.city.orbit-camera")
        videosConfig.isDiscretionary = true
        videosConfig.sessionSendsLaunchEvents = true
        videosSession = UploadableSession(URLSession(configuration: videosConfig, delegate: delegate, delegateQueue: nil))
        
        authCredential = nil // AppUploader database observer will set
        completionHandler = nil
        deleteURLs = UserDefaults.standard.stringArray(forKey: "deleteURLs")?.compactMap { URL(string: $0)! } ?? []
    }
}

class AppNetworkDelegate: NSObject {}

extension AppNetworkDelegate: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            appNetwork.completionHandler?()
            appNetwork.completionHandler = nil
            
            // Clear any remaining stale UploadableSession tasks
            if session.configuration.identifier == appNetwork.videosSession.session.configuration.identifier {
                session.getAllTasks { tasks in
                    os_log("urlSessionDidFinishEvents. Session tasks remaining %d (expect: 0).", log: appNetLog, tasks.count)
                    appNetwork.videosSession.clear(except: tasks.map { $0.taskIdentifier })
                }
            }
        }
    }
}

extension AppNetworkDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let uploadable = appNetwork.uploadable(in: session, with: task.taskIdentifier)
        else {
            os_log("URLSession didSendBodyData cannot find Uploadable with task", log: appNetLog)
            return
        }
        os_log("Upload task for %{public}s did complete", log: appNetLog, uploadable.description)
        
        switch session {
        case appNetwork.thingsSession.session:
            appNetwork.thingsSession.clear(task.taskIdentifier)
        case appNetwork.videosSession.session:
            appNetwork.videosSession.clear(task.taskIdentifier)
        default:
            fatalError("Unknown session")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        // Find uploadable for this task
        guard let uploadable = appNetwork.uploadable(in: session, with: task.taskIdentifier)
        else {
            os_log("URLSession didSendBodyData cannot find Uploadable with task", log: appNetLog)
            return
        }
        os_log("Uploading %{public}s. %d bytes sent. %.1f progress.", log: appNetLog, type: .debug,
               uploadable.description,
               bytesSent,
               100 * Float(totalBytesSent)/Float(totalBytesExpectedToSend)
        )
    }
}

extension AppNetworkDelegate: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Find uploadable for this task
        guard var uploadable = appNetwork.uploadable(in: session, with: dataTask.taskIdentifier)
        else {
            os_log("URLSession didReceive cannot find Uploadable with task", log: appNetLog)
            return
        }
        
        // Check response
        guard let httpResponse = dataTask.response as? HTTPURLResponse
        else {
            os_log("URLSessionDataDelegate dataTaskDidReceive – %{public}s – could not parse response", log: appNetLog, uploadable.description)
            return
        }
        guard (200..<300).contains(httpResponse.statusCode)
        else {
            os_log(
                "URLSessionDataDelegate dataTaskDidReceive – %{public}s – failed with status %d: %{public}s",
                log: appNetLog,
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
            // Body of upload response is lost if app not running. WTF.
            // https://forums.developer.apple.com/thread/84413
            // Well, hack through it may be, we own the server, and lo! the orbit ID is now stuffed in the header.
            // The following will re-create the data response the app expects, using the header value.
            // This assumes Videos are the only background type. Could be made generic...
            guard
                let orbitIDString = httpResponse.allHeaderFields["orbit-id"] as? String,
                let orbitID = Int(orbitIDString),
                var video = uploadable as? Video,
                let data = try? JSONEncoder().encode(Video.APIResponse(id: orbitID))
            else {
                os_log("Upload failed for %{public}s. Upload likely success at server but response could not be parsed.", log: appNetLog, type: .error, uploadable.description)
                return
            }
            try! video.uploadDidReceive(data)
            os_log("Upload succeeded for %{public}s. Response body parse failed but used fall-back header.", log: appNetLog, uploadable.description)
        }
    }
}

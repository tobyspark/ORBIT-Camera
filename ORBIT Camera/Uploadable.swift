//
//  Uploadable.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 03/03/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import Foundation
import GRDB
import os

protocol Uploadable: CustomStringConvertible {
    /// A unique ID for the uploadable. This comes from the database, and is here in this protocol as a poor man's equatable, to avoid Equality on the protocol and corresponding PAT issues.
    var id: Int64? { get }
    
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    var orbitID: Int? { get set }
    
    /// Upload the uploadable
    func upload(with credential: String, using session: URLSession) -> Int?
    
    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws
}

/// A wrapper for URLSession that tracks uploads
/// To start upload –
///     if let taskIdentifier = thing.upload(by: Settings.participant, using: uploadableSession.session) {
///         uploadableSession.associate(taskIdentifier, with: thing)
///     }
///
/// To process response in `urlSession(_:, dataTask:, didReceive:)`–
///     if var uploadable = uploadableSession.uploadable(with: task.taskIdentifier) {
///         uploadable.uploadDidReceive(data)
///     }
///
/// To handle completion in `urlSession(_:, task:, didCompleteWithError:)`
///     uploadableSession.clear(task.taskIdentifier)`
///
struct UploadableSession {
    let session: URLSession
    
    mutating func upload(_ uploadable: Uploadable, with authCredential: String) {
        // Check we have a trackable id
        guard uploadable.id != nil
        else {
            os_log("Attempted upload of pre-db uploadable", log: appNetLog)
            assertionFailure()
            return
        }
        
        // Check we're not mid-upload already
        guard !tasks.values.map({ $0.id }).contains(uploadable.id)
        else {
            os_log("Aborting upload %{public}s, is already being uploaded.", log: appNetLog, type: .debug, uploadable.description)
            return
        }
        
        // Upload and associate taskIdentifier
        if let taskIdentifier = uploadable.upload(with: authCredential, using: session) {
            associate(taskIdentifier, with: uploadable)
        }
    }
    
    mutating func associate(_ taskIdentifier: Int, with uploadable: Uploadable) {
        if tasks.keys.contains(taskIdentifier) {
            os_log("Continuing with %{public}s; stale task identifier present in session", log: appNetLog, uploadable.description)
            assertionFailure("task \(taskIdentifier) in \(tasks)")
        }
        tasks[taskIdentifier] = uploadable
    }
    
    mutating func clear(_ taskIdentifier: Int) {
        tasks[taskIdentifier] = nil
    }
    
    mutating func clear(except keepIdentifiers: [Int]) {
        tasks = tasks.filter { keepIdentifiers.contains($0.key)  }
    }
    
    mutating func cancelUpload(of uploadable: Uploadable) {
        guard let (identifier, _) = tasks.first(where: { $0.value.id == uploadable.id })
        else { return }
        
        clear(identifier)
        session.getAllTasks {
            for task in $0 {
                if task.taskIdentifier == identifier {
                    task.cancel()
                    os_log("Cancelled upload of %{public}s", log: appNetLog, uploadable.description)
                    return
                }
            }
        }
    }
    
    func uploadable(with taskIdentifier: Int) -> Uploadable? {
        return tasks[taskIdentifier]
    }
    
    init(_ session: URLSession) {
        self.session = session
        self.tasks = [:]
        
        // If a background session, restore `tasks`
        if let backgroundIdentifier = session.configuration.identifier {
            try! dbQueue.read { db in
                if let taskIDArray = UserDefaults.standard.array(forKey: backgroundIdentifier + "-task") as? [Int],
                   let uploadableIDArray = UserDefaults.standard.array(forKey: backgroundIdentifier + "-uploadable") as? [Int]
                   
                {
                    let uploadableArray = try Video.filter(keys: uploadableIDArray).fetchAll(db) // This is a hack. Hardcoded Video. Right now, better architecture would be for the task ID should be saved as a property of the uploadable, in the database. But I started with that, and abandoned. Hmm.
                    if taskIDArray.count == uploadableArray.count {
                        self.tasks = Dictionary(uniqueKeysWithValues: zip(taskIDArray, uploadableArray))
                    } else {
                        os_log("Failure restoring background upload task list")
                        assertionFailure()
                    }
                }
            }
        }
    }
    
    private var tasks: [Int: Uploadable] {
        didSet {
            // If a background session, persist
            if let backgroundIdentifier = session.configuration.identifier {
                UserDefaults.standard.set(Array(tasks.keys), forKey: backgroundIdentifier + "-task")
                UserDefaults.standard.set(tasks.values.map { $0.id! }, forKey: backgroundIdentifier + "-uploadable")
            }
        }
    }
}

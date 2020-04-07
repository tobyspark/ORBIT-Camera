//
//  Uploadable.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 03/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
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
    func upload(by participant: Participant, using session: URLSession) -> Int?
    
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
    
    mutating func upload(_ uploadable: Uploadable) {
        // Get participant
        guard let participant = try? Participant.appParticipant()
        else { return }
        
        // Check we're not mid-upload already
        guard !tasks.values.map({ $0.id }).contains(uploadable.id)
        else {
            os_log("Aborting upload %{public}s, is already being uploaded.", uploadable.description)
            return
        }
        
        // Upload and associate taskIdentifier
        if let taskIdentifier = uploadable.upload(by: participant, using: session) {
            associate(taskIdentifier, with: uploadable)
        }
    }
    
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

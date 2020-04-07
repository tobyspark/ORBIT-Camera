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
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    var orbitID: Int? { get set }
    
    /// Upload the uploadable
    func upload(by participant: Participant, using session: inout UploadableSession) throws
    
    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws
}

struct UploadableSession {
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

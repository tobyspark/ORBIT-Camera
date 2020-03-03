//
//  Uploadable.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 03/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB

enum UploadableError: Error {
    case nonUniqueUploadID
}

protocol Uploadable {
    /// An ID to track an in-progress upload, corresponds to URLSessionTask.taskIdentifier
    var uploadID: Int? { get set }
    
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    var orbitID: Int? { get set }
    
    /// Upload the uploadable
    mutating func upload(by participant: Participant, using session: URLSession) throws
    
    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws
    
    /// GRDB write method
    func update(_ db: Database) throws
}

extension Uploadable {
    /// Return the uploadable with the uploadID
    static func uploadable(with uploadID: Int) throws -> Uploadable {
        var uploadables: [Uploadable] = []
        try dbQueue.read { db in
            uploadables += try Thing
                .filter(Thing.Columns.uploadID == uploadID)
                .fetchAll(db)
            uploadables += try Video
                .filter(Video.Columns.uploadID == uploadID)
                .fetchAll(db)
        }
        guard
            uploadables.count == 1
        else {
            throw UploadableError.nonUniqueUploadID
        }
        return uploadables[0]
    }
    
    /// On upload task completion, check uploadable for uploadID, orbitID consistency. Reset both to nil on failed upload.
    // FIXME: check assumptions behind this.
    // This is a workaround for not receiving HTTPURLRequest on background uploads, so can't know about failed uploads through HTTP status code.
    // If uploadDidReceive fails to set orbitID, this should catch it. But actually, the uploadDidReceive should throw on malformed data?
    // And what about stale failed uploads that didn't event get to task completion?
    static func uploadableDidComplete(with uploadID: Int) throws {
        // On task completion, a successful upload will by now have their orbitID set, and uploadID unset.
        // If that is not the case, unset both to allow a new upload attempt.
        var uploadables: [Uploadable] = []
        try dbQueue.read { db in
            uploadables += try Thing
                .filter(Thing.Columns.uploadID == uploadID)
                .fetchAll(db)
            uploadables += try Video
                .filter(Video.Columns.uploadID == uploadID)
                .fetchAll(db)
        }
        switch uploadables.count {
        case 0: // No stale uploadIDs, good.
            return
        case 1: // Failed uploadTask.
            print("Failed upload task: \(uploadables[0])")
            uploadables[0].uploadID = nil
            uploadables[0].orbitID = nil
            try dbQueue.write { db in try uploadables[0].update(db) }
        default: // Uh-oh.
            throw UploadableError.nonUniqueUploadID
        }
    }
}

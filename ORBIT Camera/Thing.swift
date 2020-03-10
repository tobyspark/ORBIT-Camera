//
//  Thing.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

///  Abstract: the representation of a 'thing', the basic data type of the ORBIT Dataset.

import Foundation
import GRDB

/// A 'thing' that is important to a visually impaired person, and for a which a phone might be useful as a tool to pick it out of a scene.
/// For the ORBIT Dataset, to train and test computer vision / machine learning algorithms, this becomes a label – "what is it" – and set of videos – "this is what it looks like".
struct Thing: Codable, Equatable {
    /// A unique ID for this struct (within this app), populated on write to database
    var id: Int64?
    
    /// An ID to track an in-progress upload, corresponds to URLSessionTask.taskIdentifier
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var uploadID: Int?
    
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var orbitID: Int?
    
    /// The label the participant gives it. This may contain personally identifying information.
    var labelParticipant: String
    /// The label used in the ORBIT Dataset. This is assigned by the research team. Goals: anonymised, regularised across dataset.
    var labelDataset: String?
    
    /// Initialises a new thing, with the information we have at the time: what the participant calls it.
    ///
    /// Parameter label: The label the participant wants to give the thing.
    init(withLabel label: String) {
        self.id = nil
        self.uploadID = nil
        self.orbitID = nil
        self.labelParticipant = label
        self.labelDataset = nil
    }
}

extension Thing: FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let uploadID = Column(CodingKeys.uploadID)
        static let orbitID = Column(CodingKeys.orbitID)
        static let labelParticipant = Column(CodingKeys.labelParticipant)
        static let labelDataset = Column(CodingKeys.labelDataset)
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    /// Return an index, newest first, for the thing in Things
    func index() throws -> Int? {
        try dbQueue.read { db in
            let ids = try Int64.fetchAll(db, Thing.select(Thing.Columns.id))
            assert(ids == ids.sorted(), "Expediency, uncovered")
            return ids.reversed().firstIndex(of: id ?? -1)
        }
    }
    
    /// Return a thing based on a contiguous index, newest first
    static func at(index: Int) throws -> Thing {
        var thing: Thing?
        try dbQueue.read { db in
            let ids = try Int64.fetchAll(db, Thing.select(Thing.Columns.id))
            assert(ids == ids.sorted(), "Expediency, uncovered")
            let id = ids[ids.count - 1 - index]
            thing = try Thing.filter(key: id).fetchOne(db)
            if thing == nil { assertionFailure("Could not find Thing") } // FIXME: throw an error
        }
        return thing!
    }
    
    /// Delete a thing based on a contiguous index, newest first
    static func deleteAt(index: Int) throws {
        try dbQueue.write { db in
            let ids = try Int64.fetchAll(db, Thing.select(Thing.Columns.id))
            assert(ids == ids.sorted(), "Expediency, uncovered")
            let id = ids[ids.count - 1 - index]
            let deleteCount = try Thing.filter(key: id).deleteAll(db)
            if deleteCount != 1 { assertionFailure("Could not delete Thing") } // FIXME: throw an error
        }
    }
    
    // MARK: Videos (reverse relationship)
    
    /// The count of all videos of this thing
    var videosCount: Int {
        return try! dbQueue.read { db in // FIXME: try!
            try Video
                .filter(Video.Columns.thingID == self.id)
                .fetchCount(db)
        }
    }
    
    /// The count of all videos of this thing
    var videos: [Video] {
        return try! dbQueue.read { db in // FIXME: try!
            try Video
                .filter(Video.Columns.thingID == self.id)
                .fetchAll(db)
        }
    }
    
    /// Attempt to return the nth video of the thing. Zero-based.
    func videoAt(index: Int) throws -> Video? {
        try dbQueue.read { db in // FIXME: try!
            let request = Video
                .filter(Video.Columns.thingID == self.id)
                .select(Video.Columns.id)
            let ids = try Int64.fetchAll(db, request)
            assert(ids == ids.sorted(), "Expediency, uncovered")
            let id = ids[ids.count - 1 - index]
            return try Video.filter(key: id).fetchOne(db)
        }
    }
}

//
//  Thing.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

///  Abstract: the representation of a 'thing', the basic data type of the ORBIT Dataset.

import Foundation
import GRDB
import os

/// A 'thing' that is important to a visually impaired person, and for a which a phone might be useful as a tool to pick it out of a scene.
/// For the ORBIT Dataset, to train and test computer vision / machine learning algorithms, this becomes a label – "what is it" – and set of videos – "this is what it looks like".
struct Thing: Codable, Equatable {
    /// A unique ID for this struct (within this app), populated on write to database
    var id: Int64?
    
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
        self.orbitID = nil
        self.labelParticipant = label
        self.labelDataset = nil
    }
}

extension Thing: FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let orbitID = Column(CodingKeys.orbitID)
        static let labelParticipant = Column(CodingKeys.labelParticipant)
        static let labelDataset = Column(CodingKeys.labelDataset)
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    /// Delete the record, removing the video files as well
    // Note any within-db delete will not invoke this
    @discardableResult
    func delete(_ db: Database) throws -> Bool {
        let deleted = try performDelete(db)
        if !deleted { os_log("Failed to delete Thing") }
        
        // Delete videos individually to ensure the file clean-up in the struct's delete method is invoked
        let orphanVideos = try Video.filter(Video.Columns.thingID == nil).fetchAll(db)
        for video in orphanVideos {
            try video.delete(db)
        }
        
        return deleted
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
    
    /// All videos of this thing
    var videos: [Video] {
        return try! dbQueue.read { db in // FIXME: try!
            try Video
                .filter(Video.Columns.thingID == self.id)
                .fetchAll(db)
        }
    }
}

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
    
    /// URLs to videos the participant has recorded of the thing, following the ORBIT procedure for capturing 'training' data.
    /// e.g. Blank background, rotate [around] the thing
    var videosTrain: [Video] {
        return try! dbQueue.read { db in
            try Video
                .filter(Video.Columns.thingID == self.id)
                // FIXME: filter for this type
                .fetchAll(db)
        }
    }

    /// URLs to videos the participant has recorded of the thing, following the ORBIT procedure for capturing 'test' data.
    /// e.g. Film the thing 'in the wild'. The more locations (and their differing backgrounds) the better.
    var videosTest: [Video] {
        return try! dbQueue.read { db in
            try Video
                .filter(Video.Columns.thingID == self.id)
                // FIXME: filter for this type
                .fetchAll(db)
        }
    }
    
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
}

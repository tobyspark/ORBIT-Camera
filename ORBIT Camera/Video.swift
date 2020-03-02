//
//  Video.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB

struct Video: Codable, Equatable {
    /// A unique ID for this struct (within this app), populated on write to database
    var id: Int64?
    
    /// The app database ID of the Thing this is a video of
    var thingID: Int64
    
    /// On-device file URL of a video the participant has recorded
    var url: URL
    
    /// An ID to track an in-progress upload, corresponds to URLSessionTask.taskIdentifier
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var uploadID: Int?
    
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var orbitID: Int?
}

extension Video: FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let thingID = Column(CodingKeys.thingID)
        static let url = Column(CodingKeys.url)
        static let uploadID = Column(CodingKeys.uploadID)
        static let orbitID = Column(CodingKeys.orbitID)
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

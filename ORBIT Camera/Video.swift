//
//  Video.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB
import os

struct Video: Codable, Equatable {
    /// A unique ID for this struct (within this app), populated on write to database
    var id: Int64?
    
    /// The app database ID of the Thing this is a video of
    /// Deleting the Thing should null this, orphaned videos can then be deleted using the type method which also removes the video file
    var thingID: Int64?
    
    /// On-device file URL of a video the participant has recorded
    /// As the app's data folder is named dynamically, only store the filename and get/set the URL relative to a type set storage location
    var url: URL {
        get { URL(fileURLWithPath: filename, relativeTo: Video.storageURL) }
        set { filename = newValue.lastPathComponent }
    }
    
    /// When the video was recorded
    var recorded: Date
    
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var orbitID: Int?
    
    /// The kind of video this is.
    /// Current terminology: videos are taken with one of two goals: "train" or "test", with two "techniques" used for test videos: "zoom" and "pan".
    // Note String rather than Character is currently required for automatic codable compliance
    enum Kind: String, Codable, CaseIterable, CustomStringConvertible {
        case train = "T"
        case testZoom = "Z"
        case testPan = "P"
        
        var description: String {
            switch self {
            case .train: return "train"
            case .testZoom: return "test: zoom"
            case .testPan: return "test: pan"
            }
        }
        
        var verboseDescription: String {
            switch self {
            case .train: return "training"
            case .testZoom: return "testing with zoom"
            case .testPan: return "testing with pan"
            }
        }
    }
    var kind: Kind
    
    init?(of thing: Thing, url: URL, kind: Kind) {
        guard
            let thingID = thing.id
        else {
            os_log("Could not create Video as thing has no ID")
            assertionFailure()
            return nil
        }
        self.id = nil
        self.thingID = thingID
        self.filename = ""
        self.recorded = Date()
        self.orbitID = nil
        self.kind = kind
        
        self.url = url
    }
    
    // Private property backing `url`
    private var filename: String
    
    // Private type property backing `url`
    private static var storageURL: URL {
        try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) // FIXME: try!
    }
}

extension Video: FetchableRecord, MutablePersistableRecord {
    enum Columns {
        static let id = Column(CodingKeys.id)
        static let thingID = Column(CodingKeys.thingID)
        static let filename = Column(CodingKeys.filename)
        static let recorded = Column(CodingKeys.recorded)
        static let orbitID = Column(CodingKeys.orbitID)
        static let kind = Column(CodingKeys.kind)
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    /// Delete the record, removing movie file as well
    // Note any within-db delete will not invoke this, e.g. foreign key cascade
    @discardableResult
    func delete(_ db: Database) throws -> Bool {
        try FileManager.default.removeItem(at: url)
        let deleted = try performDelete(db)
        if !deleted { os_log("Failed to delete Video") }
        return deleted
    }
}

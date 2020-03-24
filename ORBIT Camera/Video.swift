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
    var thingID: Int64
    
    /// On-device file URL of a video the participant has recorded
    /// As the app's data folder is named dynamically, only store the filename and get/set the URL relative to a type set storage location
    var url: URL {
        get { URL(fileURLWithPath: filename, relativeTo: Video.storageURL) }
        set { filename = newValue.lastPathComponent }
    }
    
    /// When the video was recorded
    var recorded: Date
    
    /// An ID to track an in-progress upload, corresponds to URLSessionTask.taskIdentifier
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var uploadID: Int?
    
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    // Note this was handled more elegantly by orbitID being an UploadStatus enum, but the supporting code was getting ridiculous.
    var orbitID: Int?
    
    /// The kind of video this is.
    /// Current terminology: videos are taken with one of two goals: "registration" or "recognition", with two "techniques" used for registration videos: "zoom" and "rotate".
    // Note String rather than Character is currently required for automatic codable compliance
    enum Kind: String, Codable {
        case registerRotate = "R"
        case registerZoom = "Z"
        case recognition = "N" // On the server, as per pilot, this is "No technique", hence the 'N'
        
        func description() -> String {
            switch self {
            case .registerRotate: return "rotate technique"
            case .registerZoom: return "zoom technique"
            case .recognition: return "recognition example"
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
        self.uploadID = nil
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
        static let uploadID = Column(CodingKeys.uploadID)
        static let orbitID = Column(CodingKeys.orbitID)
        static let kind = Column(CodingKeys.kind)
    }
    
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
}

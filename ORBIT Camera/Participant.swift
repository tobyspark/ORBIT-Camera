//
//  Participant.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 28/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

///  Abstract: the representation of a participant, a contributor to the ORBIT Dataset.

import Foundation
import GRDB
import os

/// A participant in an ORBIT data collection phase
struct Participant: Codable, Equatable {
    
    /// A unique ID for this struct (within this app), populated on write to database
    /// Note this is not the ORBIT participant ID! We don't actually need that at present, further at present it's encoded into the authCredential.
    var id: Int64?
    
    /// Authorisation string for HTTP requests made for this participant. Should only be populated with validated credential.
    var authCredential: String?
}

extension Participant: FetchableRecord, MutablePersistableRecord {
    // Update auto-incremented id upon successful insertion
    mutating func didInsert(with rowID: Int64, for column: String?) {
        id = rowID
    }
    
    /// The app is designed for only one participant. This returns the one participant from the database.
    static func appParticipant() throws -> Participant {
        if let participant = try dbQueue.read({ db in try Participant.filter(key: 1).fetchOne(db) }) {
            return participant
        }
        var participant = Participant()
        try dbQueue.write { db in try participant.save(db) }
        assert(participant.id == 1, "appParticipant created with ID other than 1")
        return participant
    }
    
    static func appParticipantGivenConsent() -> Bool {
        if let participant = try? appParticipant(),
           participant.authCredential != nil
        {
            return true
        }
        return false
    }
}

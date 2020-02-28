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

/// A participant in an ORBIT data collection phase
struct Participant: Codable, Equatable {
    
    /// The ORBIT Participant ID
    // Note this isn't the app DB rowID. Scope for confusion is limited however as there should be only one participant per app instance.
    let id: Int
    
    /// Authorisation string for HTTP requests made for this participant
    var authCredential: String
}

extension Participant: FetchableRecord, PersistableRecord {
    // We don't care about obtaining app DB rowID.
}

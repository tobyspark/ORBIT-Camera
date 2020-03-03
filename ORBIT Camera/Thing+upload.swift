//
//  Thing+upload.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 23/01/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

///  Abstract: the functionality to upload a thing. First, the label needs to be uploaded, which will create the server record and return the thing's ID. The videos will then need to be uploaded with that ID.

import UIKit
import GRDB

extension Thing {
    /// Thing endpoint request body JSON structure
    /// ```json
    /// {
    ///     "label_participant": "Mug"
    /// }
    /// ```
    struct APIRequest: Codable {
        /// The label to create the server record with
        let label_participant: String
    }
    
    /// Thing endpoint response body JSON structure
    /// ```json
    /// {
    ///     "id": 1,
    ///     "label_participant": "Mug",
    ///     "label_validated": ""
    /// }
    /// ```
    struct APIResponse: Codable {
        /// The server database ID of the successfully inserted upload
        let id: Int
        let label_participant: String
        let label_validated: String
    }
    
    /// Upload the thing. This should create a server record for the thing, and return that record's ID.
    mutating func upload(by participant: Participant, using session: URLSession) throws {
        // Create upload request
        let url = URL(string: Settings.endpointThing)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(participant.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create data to upload
        let uploadStruct = APIRequest(label_participant: labelParticipant)
        guard let uploadData = try? JSONEncoder().encode(uploadStruct) else {
            assertionFailure("Could not create uploadData from \(uploadStruct)")
            return
        }
        
        // Create task
        let task = session.uploadTask(with: request, from: uploadData)
    
        // Associate upload with Video
        uploadID = task.taskIdentifier
        try dbQueue.write { db in try save(db) }
        
        // Action task
        task.resume()
    }
    
    /// Check all Things on uploadDidComplete for uploadID, orbitID consistency. Reset both to nil on failed upload.
    static func uploadDidComplete(for uploadID: Int) throws {
        // On task completion, a successful upload will by now have their orbitID set, and uploadID unset.
        // If that is not the case, unset both to allow a new upload attempt.
        try dbQueue.write { db in
            var things = try Thing
                .filter(Columns.uploadID == uploadID)
                .fetchAll(db)
            switch things.count {
            case 0: // No stale uploadIDs, good.
                return
            case 1: // Failed uploadTask.
                print("Failed upload task: \(things[0])")
                things[0].uploadID = nil
                things[0].orbitID = nil
                try things[0].update(db)
            default: // Uh-oh.
                assertionFailure("Multiple Things with same uploadID on task completion.")
            }
        }
    }

    /// Assign orbitID from returned data
    static func uploadDidReceive(for uploadID: Int, data: Data) throws {
        try dbQueue.write { db in
            var things = try Thing
                .filter(Columns.uploadID == uploadID)
                .fetchAll(db)
            guard
                things.count == 1
            else {
                assertionFailure("Multiple Things (or none) with same uploadID on receive data")
                return
            }
            guard
                let apiResponse = try? JSONDecoder().decode(APIResponse.self, from: data)
            else {
                let dataString = String(data: data, encoding: .utf8) ?? "Could not interpret return data: \(data)"
                assertionFailure("Could not parse upload response data:\n\(dataString)")
                return
            }
            things[0].uploadID = nil
            things[0].orbitID = apiResponse.id
            try things[0].update(db)
        }
        
        // TODO: Now action upload of next video
    }
}

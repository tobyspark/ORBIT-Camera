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
import os

extension Thing: Uploadable {
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
    
    /// Upload the thing. This should action the creation of a server record for the thing, and (handled in `uploadDidReceive`) return that record's ID.
    func upload(by participant: Participant, using session: inout AppURLSession) {
        guard orbitID == nil else {
            os_log("Attempted to upload Video that has already been uploaded")
            return
        }
        
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
        let task = session.session.uploadTask(with: request, from: uploadData)
    
        // Associate upload with Video
        guard !session.tasks.keys.contains(task.taskIdentifier)
        else {
            os_log("Stale task identifier present in session")
            assertionFailure()
            return
        }
        session.tasks[task.taskIdentifier] = self
        
        // Action task
        task.resume()
    }

    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws {
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        os_log("Parsed Thing upload response")
        orbitID = apiResponse.id
        try dbQueue.write { db in try update(db) }
    }
}

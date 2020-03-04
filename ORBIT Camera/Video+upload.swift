//
//  Video+upload.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB

extension Video: Uploadable {
    /// Thing endpoint response body JSON structure
    /// ```json
    /// {
    ///     "id": 1,
    ///     "thing": 1,
    ///     "file": "http://orbit-data.city.ac.uk/media/qwertyuiop.mp4",
    ///     "technique": "R",
    ///     "validation": "-"
    /// }
    /// ```
    struct APIResponse: Codable {
        /// The server database ID of the successfully inserted upload
        let id: Int
    }
    
    /// Upload the video. This should create a server record for the thing, and return that record's ID.
    mutating func upload(by participant: Participant, using session: URLSession) throws {
        guard
            let thing = try dbQueue.read { db in try Thing.filter(key: thingID).fetchOne(db) },
            let thingOrbitID = thing.orbitID
        else {
            assertionFailure("Cannot upload without yet having orbitID of thing")
            return
        }
        
        guard
            let formFile = try? MultipartFormFile(
                    fields: [
                        (name: "thing", value: "\(thingOrbitID)"),
                        (name: "technique", value: "R"), // FIXME: placeholder value
                        ],
                    files: [
                        (name: "file", value: url)
                        ]
                    )
        else {
            assertionFailure("Can't upload, could not create form data")
            return
        }
        
        // Create upload request
        let endpointURL = URL(string: Settings.endpointVideo)!
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue(participant.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue(formFile.contentType, forHTTPHeaderField: "Content-Type")
        
        // Create task
        let task = session.uploadTask(with: request, fromFile: formFile.body)
        
        // Associate upload with Video
        uploadID = task.taskIdentifier
        try dbQueue.write { db in try save(db) }
        
        // Action task
        task.resume()
    }

    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws {
        print("Video uploadDidReceive")
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        uploadID = nil
        orbitID = apiResponse.id
        try dbQueue.write { db in try update(db) }
        
        // TODO: Now action upload of next video
    }
}

//
//  Video+upload.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 02/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB
import os

extension Video: Uploadable {
    /// Thing endpoint response body JSON structure
    /// ```json
    /// {
    ///     "id": 1,
    ///     "thing": 1,
    ///     "file": "http://example.com/media/qwertyuiop.mp4",
    ///     "technique": "R",
    ///     "validation": "-"
    /// }
    /// ```
    struct APIResponse: Codable {
        /// The server database ID of the successfully inserted upload
        let id: Int
    }
    
    /// Upload the video. This should action the creation of a server record for the video, and (handled in `uploadDidReceive`) return that record's ID.
    func upload(by participant: Participant, using session: inout AppURLSession) {
        guard orbitID == nil else {
            os_log("Attempted to upload Video that has already been uploaded")
            return
        }
        
        guard
            let thing = try? dbQueue.read({ db in try Thing.filter(key: thingID).fetchOne(db) }),
            let thingOrbitID = thing.orbitID
        else {
            os_log("Attempted to upload Video without orbitID of thing")
            return
        }
        
        guard
            let formFile = try? MultipartFormFile(
                    fields: [
                        (name: "thing", value: "\(thingOrbitID)"),
                        (name: "technique", value: kind.rawValue),
                        ],
                    files: [
                        (name: "file", value: url)
                        ]
                    )
        else {
            os_log("Failed attempt to upload Video, could not create form data")
            return
        }
        
        // Create upload request
        let endpointURL = URL(string: Settings.endpointVideo)!
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue(participant.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue(formFile.contentType, forHTTPHeaderField: "Content-Type")
        
        // Create task
        let task = session.session.uploadTask(with: request, fromFile: formFile.body)
        
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
        os_log("Parsed Video upload response")
        orbitID = apiResponse.id
        try dbQueue.write { db in try update(db) }
    }
}

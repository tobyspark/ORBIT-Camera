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
    var description: String { "Video \(id ?? 0)" }
    
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
    
    /// Upload the video. This should action the creation of a server record for the video, and (handled in `uploadDidReceive`) return that record's ID.
    func upload(by participant: Participant, using session: URLSession) -> Int? {
        guard orbitID == nil else {
            os_log("Aborting upload of Video %d: it has already been uploaded", log: appNetLog, description)
            return nil
        }
        
        guard
            let thing = try? dbQueue.read({ db in try Thing.filter(key: thingID).fetchOne(db) }),
            let thingOrbitID = thing.orbitID
        else {
            os_log("Aborting upload of %{public}s: could not get the associated Thing's id", log: appNetLog, description)
            return nil
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
            os_log("Aborting upload of %{public}s: could not create upload data", log: appNetLog, description)
            return nil
        }
        
        // Create upload request
        let endpointURL = URL(string: Settings.endpointVideo)!
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue(participant.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue(formFile.contentType, forHTTPHeaderField: "Content-Type")
        
        // Create and action task
        let task = session.uploadTask(with: request, fromFile: formFile.body)
        task.resume()
        
        // Return the task ID
        return task.taskIdentifier
    }

    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws {
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        os_log("Parsed upload response for %{public}s", log: appNetLog, description)
        orbitID = apiResponse.id
        try dbQueue.write { db in try update(db) }
    }
}

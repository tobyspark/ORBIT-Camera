//
//  Video+ServerStatus.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 23/05/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB
import os

extension Video {
    struct APIGETItemResponse: Codable {
        /// The server database ID of the successfully inserted upload
        let id: Int
        let thing: Int
        let file: String
        let technique: String
        let validation: String
    }
    
    struct APIGETPageResponse: Codable {
        /// The server database ID of the successfully inserted upload
        let count: Int
        let next: String?
        let previous: String?
        let results: [APIGETItemResponse]
    }
    
    static func updateServerStatuses(url: URL = URL(string: Settings.endpointVideo)!) {
        var request = URLRequest(url: url)
        request.setValue(appNetwork.authCredential, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                os_log("updateServerStatuses failed, received error", log: appNetLog)
                print(error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse
            else {
                os_log("updateServerStatuses failed, cannot parse response", log: appNetLog)
                return
            }
            guard httpResponse.statusCode == 200
            else {
                os_log("updateServerStatuses failed: %d", log: appNetLog, httpResponse.statusCode)
                return
            }
            guard
                let mimeType = httpResponse.mimeType,
                mimeType == "application/json",
                let data = data,
                let pageData = try? JSONDecoder().decode(APIGETPageResponse.self, from: data)
            else {
                os_log("updateServerStatuses failed, could not decode data")
                return
            }
            
            // Update videos
            try! dbQueue.write { db in
                for result in pageData.results {
                    guard let video = try Video.filter(Video.Columns.orbitID == result.id).fetchOne(db)
                    else {
                        os_log("Video GET returned unknown orbitID: %d", log: appNetLog, type: .error, result.id)
                        continue
                    }
                    print(video, result)
                }
            }
            
            // Process next page if needed
            if let nextPage = pageData.next {
                Video.updateServerStatuses(url: URL(string: nextPage)!)
            }
        }
        task.resume()
    }
}

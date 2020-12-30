//
//  Participant+ServerStatus.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 24/05/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB
import os

extension Participant {
    struct APIPOSTRequest: Codable {
        let charityChoice: String
        
        enum CodingKeys: String, CodingKey {
            case charityChoice = "charity_choice"
        }
    }
    
    struct APIPOSTResponse: Codable {
        let charityChoice: String
        
        enum CodingKeys: String, CodingKey {
            case charityChoice = "charity_choice"
        }
    }
    
    static func setCharityChoice(_ choice: String, url: URL = URL(string: Settings.endpointParticipant)!) {
        // Save to DB
        var participant = try! Participant.appParticipant()
        participant.charityChoice = choice
        try! dbQueue.write { db in try participant.save(db) }
        
        // Upload
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(appNetwork.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let uploadStruct = APIPOSTRequest(charityChoice: choice)
        guard let uploadData = try? JSONEncoder().encode(uploadStruct) else {
            os_log("Aborting setCharityChoice", log: appNetLog)
            assertionFailure("uploadStruct: \(uploadStruct)")
            return
        }
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                os_log("Participant.setCharityChoice failed, received error", log: appNetLog)
                print(error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse
            else {
                os_log("Participant.setCharityChoice failed, cannot parse response", log: appNetLog)
                return
            }
            guard httpResponse.statusCode == 200
            else {
                os_log("Participant.setCharityChoice failed: %d", log: appNetLog, httpResponse.statusCode)
                return
            }
        }
        task.resume()
        os_log("setCharityChoice upload started", log: appNetLog)
    }
    
    struct APIGETResponse: Codable {
        let studyStart: Date
        let studyEnd: Date
        
        enum CodingKeys: String, CodingKey {
            case studyStart = "study_start"
            case studyEnd = "study_end"
        }
    }
    
    static func updateServerStatuses(url: URL = URL(string: Settings.endpointParticipant)!) {
        var request = URLRequest(url: url)
        request.setValue(appNetwork.authCredential, forHTTPHeaderField: "Authorization")
        
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .formatted(Settings.apiDateFomatter)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                os_log("Participant.updateServerStatuses failed, received error", log: appNetLog)
                print(error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse
            else {
                os_log("Participant.updateServerStatuses failed, cannot parse response", log: appNetLog)
                return
            }
            guard httpResponse.statusCode == 200
            else {
                os_log("Participant.updateServerStatuses failed: %d", log: appNetLog, httpResponse.statusCode)
                return
            }
            guard
                let mimeType = httpResponse.mimeType,
                mimeType == "application/json",
                let data = data,
                let participantData = try? jsonDecoder.decode(APIGETResponse.self, from: data)
            else {
                os_log("Participant.updateServerStatuses failed, could not decode data")
                return
            }
            
            var participant = try! Participant.appParticipant()
            if participant.studyStart != participantData.studyStart || participant.studyEnd != participantData.studyEnd {
                participant.studyStart = participantData.studyStart
                participant.studyEnd = participantData.studyEnd
                try! dbQueue.write { db in try participant.save(db) }
            }
        }
        task.resume()
    }
}

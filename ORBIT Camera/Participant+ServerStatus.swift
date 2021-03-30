//
//  Participant+ServerStatus.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 24/05/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import Foundation
import GRDB
import os

extension Participant {
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

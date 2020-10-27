//
//  APNS+upload.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/10/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import os

struct APNS {
    struct APIPOSTRequest: Codable {
        let registrationID: String
        
        enum CodingKeys: String, CodingKey {
            case registrationID = "registration_id"
        }
    }

    static func uploadDeviceToken(token: Data, url: URL = URL(string: Settings.endpointAPNS)!) {
        // Upload
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(appNetwork.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let uploadStruct = APIPOSTRequest(registrationID: token.reduce("", {$0 + String(format: "%02X", $1)}))
        guard let uploadData = try? JSONEncoder().encode(uploadStruct) else {
            os_log("Aborting uploadAPNSDeviceToken", log: appNetLog)
            assertionFailure("uploadStruct: \(uploadStruct)")
            return
        }
        
        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { data, response, error in
            if let error = error {
                os_log("uploadAPNSDeviceToken failed, received error", log: appNetLog)
                print(error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse
            else {
                os_log("uploadAPNSDeviceToken failed, cannot parse response", log: appNetLog)
                return
            }
            guard (200...201).contains(httpResponse.statusCode)
            else {
                os_log("uploadAPNSDeviceToken failed: %d", log: appNetLog, httpResponse.statusCode)
                return
            }
            os_log("uploadAPNSDeviceToken upload complete", log: appNetLog)
        }
        task.resume()
        os_log("uploadAPNSDeviceToken upload started", log: appNetLog)
    }
}

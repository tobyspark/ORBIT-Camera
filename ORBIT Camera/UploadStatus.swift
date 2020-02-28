//
//  UploadStatus.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 24/01/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

///  Abstract: functionality to help track objects uploading to a server.

import Foundation

/// A status to track an object's upload to a server
enum UploadStatus {
    /// Upload has not yet been attempted, there is no ID to track
    case noID
    /// Upload is in progress, and can be tracked by URLSessionTask.taskIdentifier
    case upload(Int)
    /// Upload and database insertion successful, the server record can be tracked by this ID
    case server(Int)
}

// This seems highly auto-generatable. Perhaps in the future we won't need this faff.
extension UploadStatus: Codable {
    enum CodingKeys: String, CodingKey {
        case noID
        case upload
        case server
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .noID:
            try container.encode(true, forKey: .noID)
        case .upload(let value):
            try container.encode(value, forKey: .upload)
        case .server(let value):
            try container.encode(value, forKey: .server)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard container.allKeys.count == 1 else {
            assertionFailure("ServerStatus failed to decode")
            self = .noID
            return
        }
        switch container.allKeys.first! {
        case .noID:
            self = .noID
        case .upload:
            let value = try container.decode(Int.self, forKey: .upload)
            self = .upload(value)
        case .server:
            let value = try container.decode(Int.self, forKey: .server)
            self = .server(value)
        }
    }
}

// Ditto. This is faff.
extension UploadStatus: Equatable {
    static func ==(lhs: UploadStatus, rhs: UploadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.noID, .noID):
            return true
        case (.upload(let lhsValue), .upload(let rhsValue)):
            return lhsValue == rhsValue
        case (.server(let lhsValue), .server(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

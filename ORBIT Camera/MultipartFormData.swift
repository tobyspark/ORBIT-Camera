//
//  FormData.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 23/01/2020.
//  https://tobyz.net
//  Copyright © 2020 Apple. All rights reserved.
//

import Foundation

struct MultipartFormFile {
    let contentType: String
    let body: URL
    
    private let chunkSize = 16384 // 16 kibibytes, for want of a better number
    
    init?(fields: [(name: String, value: String)], files: [(name: String, value: URL)]) throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        
        contentType = "multipart/form-data; boundary=\(boundary)"
        
        body = URL(fileURLWithPath: NSTemporaryDirectory().appending(UUID().uuidString))
        try Data().write(to: body) // easiest way to create file!?
        let bodyHandle = try FileHandle(forWritingTo: body)
        
        for field in fields {
            bodyHandle.write("--\(boundary)\r\n")
            bodyHandle.write("Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n")
            bodyHandle.write("\(field.value)\r\n")
        }
        
        for field in files {
            let mimeType = "video/mp4" // FIXME: don't hardcode
            bodyHandle.write("--\(boundary)\r\n")
            bodyHandle.write("Content-Disposition: form-data; name=\"\(field.name)\"; filename=\"\(field.value.lastPathComponent)\"\r\n")
            bodyHandle.write("Content-Type: \(mimeType)\r\n\r\n")
            let sourceHandle = try FileHandle(forReadingFrom: field.value)
            var sourceChunk = sourceHandle.readData(ofLength: chunkSize)
            while sourceChunk.count > 0 {
                bodyHandle.write(sourceChunk)
                sourceChunk = sourceHandle.readData(ofLength: chunkSize)
            }
            
            bodyHandle.write("\r\n")
        }
        
        bodyHandle.write("--\(boundary)\r\n")
    }
}

extension FileHandle {
    func write(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            write(data)
        }
    }
}

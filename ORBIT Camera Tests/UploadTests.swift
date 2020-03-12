//
//  UploadTests.swift
//  ORBIT Camera Tests
//
//  Created by Toby Harris on 03/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

// FIXME: This is the happiest of happy-path testing. Served to get a known-good implementation of upload, but doesn't test any adverse situation.

import XCTest
import GRDB

class UploadTests: XCTestCase {
    var session: URLSession!
    var didCompleteExpectation: XCTestExpectation!
    
    override func setUp() {
        dbQueue = DatabaseQueue()
        do {
            try AppDatabase.migrator.migrate(dbQueue)
        } catch {
            XCTFail("Could not migrate DB")
        }
        
        session = URLSession(configuration: URLSessionConfiguration.ephemeral, delegate: self, delegateQueue: nil)
        
        didCompleteExpectation = expectation(description: "uploadDidComplete")
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // Upload a Thing, check we get back the orbitID
    func testThingUpload() throws {
        var thing = Thing(withLabel: "labelParticipant")
        try dbQueue.write { db in try thing.save(db) }

        try thing.upload(by: Settings.participant, using: session)
        wait(for: [didCompleteExpectation], timeout: 5)
        
        let things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertNil(things[0].uploadID, "The uploadID should be unset after upload")
        XCTAssertNotNil(things[0].orbitID, "The orbitID should be set after upload")
    }
    
    // Upload a Video and check we get back the orbitID
    func testVideoUpload() throws {
        let testID = 1 // Assumes this is so on the server, will be if testUploadThing has run once
        let testURL = Bundle(for: type(of: self)).url(forResource: "orbit-cup-photoreal", withExtension:"mp4")!
        
        var thing = Thing(withLabel: "labelParticipant")
        thing.orbitID = testID
        try dbQueue.write { db in try thing.save(db) }
        
        var video = Video(of: thing, url: testURL, kind:.registerRotate)!
        try dbQueue.write { db in try video.save(db) }

        try video.upload(by: Settings.participant, using: session)
        wait(for: [didCompleteExpectation], timeout: 10)

        let videos = try dbQueue.read { db in try Video.fetchAll(db) }
        XCTAssertNil(videos[0].uploadID, "The uploadID should be unset after upload")
        XCTAssertNotNil(videos[0].orbitID, "The orbitID should be set after upload")
    }
}



extension UploadTests: URLSessionDelegate {
    func urlSessionDidFinishEvents(forBackgroundURLSession: URLSession) {
        print("urlSessionDidFinishEvents(forBackgroundURLSession:) –– called")
    }
}

extension UploadTests: URLSessionTaskDelegate {
    // As upload tasks in background sessions do not receive the headers back, we need to clean-up an unsuccessful POST here.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("urlSession(_:, task:, didCompleteWithError:) –– called")
        
        try! Thing.uploadableDidComplete(with: task.taskIdentifier)
        didCompleteExpectation.fulfill()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        print("urlSession(_:, task:, didSendBodyData:, totalBytesSent:, totalBytesExpectedToSend:) –– called") // Yes, gets called
        print(bytesSent, totalBytesSent, totalBytesExpectedToSend)
        print(Float(totalBytesSent)/Float(totalBytesExpectedToSend))
    }
}

extension UploadTests: URLSessionDataDelegate {
    // Oh look, what's in the source but not documentation? This line
    //  * This method will not be called for background upload tasks (which cannot be converted to download tasks).
    // ...so there's no way to get the headers for background upload tasks!
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        print("urlSession(_:, dataTask:, didReceive:, completionHandler:) –– called")
        if let response = response as? HTTPURLResponse {
            print(response.statusCode, response.allHeaderFields)
        }
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("urlSession(_:, dataTask:, didReceive:) –– called") // Yes, gets called
        
        var uploadable = try! Thing.uploadable(with: dataTask.taskIdentifier)
        try! uploadable.uploadDidReceive(data)
    }
}

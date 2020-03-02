//
//  ThingTests.swift
//  ORBIT Camera Tests
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import XCTest
import GRDB

class PersistenceTests: XCTestCase {
    override func setUp() {
        dbQueue = DatabaseQueue()
        do {
            try AppDatabase.migrator.migrate(dbQueue)
        } catch {
            XCTFail("Could not migrate DB")
        }
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    /// Persist a participant. Create it, write it to storage, read it from storage, check it's the same.
    func testPersistParticipant() throws {
        let participant = Participant(id: 123, authCredential: "qwertyuiop")
        try dbQueue.write { db in
            try participant.save(db)
            let participants = try Participant.fetchAll(db)
            XCTAssertEqual(participants.count, 1, "Persisting a participant should result in one thing persisted")
            XCTAssertEqual(participant, participants[0], "Retreiving a persisted participant should return an identical participant")
        }
    }
    
    /// Persist a thing. Create it, write it to storage, read it from storage, check it's the same.
    func testPersistThing() throws {
        var thing = Thing(withLabel: "labelParticipant")
        XCTAssertEqual(thing.id, nil, "Unstored thing should have no ID")
        try dbQueue.write { db in try thing.save(db) }
        XCTAssertNotNil(thing.id, "Stored thing should have an ID")
        try dbQueue.write { db in try thing.save(db) } // Extra save, should not insert new
        
        var things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertEqual(things.count, 1, "Persisting a thing should result in one thing persisted")
        XCTAssertEqual(thing, things[0], "Retreiving a persisted thing should return an identical thing")

        thing.uploadID = 123
        thing.orbitID = 456
        thing.labelParticipant = "labelParticipant"
        thing.labelDataset = "labelDataset"
        try dbQueue.write { db in try thing.save(db) }
        
        things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertEqual(thing, things[0])
    }
    
    /// Persist a video. Create it, write it to storage, read it from storage, check it's the same. Check the Thing's video property returns the video.
    func testPersistVideo() throws {
        var thing = Thing(withLabel: "labelParticipant")
        try dbQueue.write { db in try thing.save(db) }
        var video = Video(thingID: thing.id!, url: URL(fileURLWithPath: "path/to/1"))
        try dbQueue.write { db in try video.save(db) }
        try dbQueue.write { db in try video.save(db) } // Extra save, should not insert new
        
        var videos = try dbQueue.read { db in try Video.fetchAll(db) }
        XCTAssertEqual(videos.count, 1, "Persisting a video should result in one thing persisted")
        // WTF: Equating the original URL with the encoded and decoded URLs fails!
        // "path/to/1 -- file:///" != "file:///path/to/1"
        //XCTAssertEqual(video, videos[0], "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.thingID, videos[0].thingID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.url.absoluteString, videos[0].url.absoluteString, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.uploadID, videos[0].uploadID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.orbitID, videos[0].orbitID, "Retreiving a persisted thing should return an identical thing")
        
        video.uploadID = 123
        video.orbitID = 456
        try dbQueue.write { db in try video.save(db) }
        
        videos = try dbQueue.read { db in try Video.fetchAll(db) }
        XCTAssertEqual(video.uploadID, videos[0].uploadID,"Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.orbitID, videos[0].orbitID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual([video].map { $0.url.absoluteString }, thing.videosTest.map { $0.url.absoluteString }, "The thing's video property should return the video")
    }
}

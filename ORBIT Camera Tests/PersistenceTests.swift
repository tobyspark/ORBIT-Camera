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
        var video = Video(thingID: thing.id!, url: URL(fileURLWithPath: "path/to/1"), kind:.recognition)
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
        XCTAssertEqual(video.kind, videos[0].kind, "Retreiving a persisted thing should return an identical thing")
        
        video.uploadID = 123
        video.orbitID = 456
        try dbQueue.write { db in try video.save(db) }
        
        videos = try dbQueue.read { db in try Video.fetchAll(db) }
        XCTAssertEqual(video.uploadID, videos[0].uploadID,"Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.orbitID, videos[0].orbitID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual([video].map { $0.url.absoluteString }, thing.videosTest.map { $0.url.absoluteString }, "The thing's video property should return the video")
    }
    
    /// Load test data, checking it's what we expect
    func testLoadTestData() throws {
        try AppDatabase.loadTestData()
        var participants = try dbQueue.read { db in try Participant.fetchAll(db) }
        var things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertEqual(participants.count, 1, "Test (pilot) data should only load one participant")
        XCTAssertEqual(things.count, 5, "Test (pilot) data should have five things")
        XCTAssertEqual(things[0].videosTrain.count, 5, "Test (pilot) data should have five videos for a thing")
        
        try AppDatabase.loadTestData()
        participants = try dbQueue.read { db in try Participant.fetchAll(db) }
        things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertEqual(participants.count, 1, "Test (pilot) data should only ever load one participant")
        XCTAssertEqual(things.count, 5, "Test (pilot) data should only ever have five things")
        XCTAssertEqual(things[0].videosTrain.count, 5, "Test (pilot) data should only ever have five videos for a thing")
    }
    
    /// Load test data, delete the one Participant, check it's gone.
    func testParticipantDelete() throws {
        try AppDatabase.loadTestData()
        
        let deletedCount = try dbQueue.write { db in try Participant.filter(key: 1).deleteAll(db) }
        XCTAssertEqual(deletedCount, 1, "The participant should have been deleted")
        
        let participantCount = try dbQueue.read { db in try Participant.fetchCount(db) }
        XCTAssertEqual(participantCount, 0, "The participant should have been deleted")
    }
    
    /// Load test data, delete the first Thing, check it's gone, and check it's videos have also gone.
    func testThingDelete() throws {
        try AppDatabase.loadTestData()
                
        var thingCount = try dbQueue.read { db in try Thing.filter(key: 1).fetchCount(db) }
        XCTAssertEqual(thingCount, 1, "The thing should be loaded from test data")
        
        var videoCount = try dbQueue.read { db in try Video.filter(Video.Columns.thingID == 1).fetchCount(db) }
        XCTAssertEqual(videoCount, 5, "The thing's videos should be loaded from test data")
        
        let deletedCount = try dbQueue.write { db in try Thing.filter(key: 1).deleteAll(db) }
        XCTAssertEqual(deletedCount, 1, "The thing should have been deleted")
        
        thingCount = try dbQueue.read { db in try Thing.filter(key: 1).fetchCount(db) }
        XCTAssertEqual(thingCount, 0, "The thing should have been deleted")
        
        videoCount = try dbQueue.read { db in try Video.filter(Video.Columns.thingID == 1).fetchCount(db) }
        XCTAssertEqual(videoCount, 0, "The thing's videos should have been deleted")
        
        thingCount = try dbQueue.read { db in try Thing.fetchCount(db) }
        XCTAssertEqual(thingCount, 4, "No other things should have been deleted")
        
        videoCount = try dbQueue.read { db in try Video.fetchCount(db) }
        XCTAssertEqual(videoCount, 20, "No other videos should have been deleted")
    }
    
    func testThingIndexing() throws {
        try AppDatabase.loadTestData()
        
        try dbQueue.read { db in
            XCTAssertEqual(try Thing.filter(key: 1).fetchOne(db)?.labelParticipant, "House keys")
            XCTAssertEqual(try Thing.filter(key: 2).fetchOne(db)?.labelParticipant, "Rucksack")
            XCTAssertEqual(try Thing.filter(key: 3).fetchOne(db)?.labelParticipant, "White guide cane")
            XCTAssertEqual(try Thing.filter(key: 4).fetchOne(db)?.labelParticipant, "LG remote control")
            XCTAssertEqual(try Thing.filter(key: 5).fetchOne(db)?.labelParticipant, "Lifemax talking watch")
        }
        
        XCTAssertEqual(try Thing.at(index: 4).labelParticipant, "House keys")
        XCTAssertEqual(try Thing.at(index: 3).labelParticipant, "Rucksack")
        XCTAssertEqual(try Thing.at(index: 2).labelParticipant, "White guide cane")
        XCTAssertEqual(try Thing.at(index: 1).labelParticipant, "LG remote control")
        XCTAssertEqual(try Thing.at(index: 0).labelParticipant, "Lifemax talking watch")
        
        _ = try dbQueue.write { db in try Thing.filter(key: 3).deleteAll(db) }
        
        XCTAssertEqual(try Thing.at(index: 3).labelParticipant, "House keys")
        XCTAssertEqual(try Thing.at(index: 2).labelParticipant, "Rucksack")
        XCTAssertEqual(try Thing.at(index: 1).labelParticipant, "LG remote control")
        XCTAssertEqual(try Thing.at(index: 0).labelParticipant, "Lifemax talking watch")
        
        try Thing.deleteAt(index: 1)
        
        XCTAssertEqual(try Thing.at(index: 2).labelParticipant, "House keys")
        XCTAssertEqual(try Thing.at(index: 1).labelParticipant, "Rucksack")
        XCTAssertEqual(try Thing.at(index: 0).labelParticipant, "Lifemax talking watch")
    }
}

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
        try dbQueue.write { db in
            try thing.save(db)
            XCTAssertNotNil(thing.id, "Stored thing should have an ID")
            let things = try Thing.fetchAll(db)
            XCTAssertEqual(things.count, 1, "Persisting a thing should result in one thing persisted")
            XCTAssertEqual(thing, things[0], "Retreiving a persisted thing should return an identical thing")
        }

        thing.uploadID = 123
        thing.orbitID = 456
        thing.labelParticipant = "labelParticipant"
        thing.labelDataset = "labelDataset"
        thing.videosTrain = [URL(fileURLWithPath: "path/to/1"), URL(fileURLWithPath: "path/to/2")]
        thing.videosTest = [URL(fileURLWithPath: "path/to/3"), URL(fileURLWithPath: "path/to/4")]
        try dbQueue.write { db in
            try thing.save(db)
            let things = try Thing.fetchAll(db)
            // WTF: Equating the original URL with the encoded and decoded URLs fails!
            // "path/to/1 -- file:///" != "file:///path/to/1"
            //XCTAssertEqual(thing, things[0], "Retreiving a persisted thing should return an identical thing")
            XCTAssertEqual(thing.id, things[0].id)
            XCTAssertEqual(thing.uploadID, things[0].uploadID)
            XCTAssertEqual(thing.orbitID, things[0].orbitID)
            XCTAssertEqual(thing.labelParticipant, things[0].labelParticipant)
            XCTAssertEqual(thing.labelDataset, things[0].labelDataset)
            XCTAssertEqual(thing.videosTrain.map { $0.absoluteString }, things[0].videosTrain.map { $0.absoluteString })
            XCTAssertEqual(thing.videosTest.map { $0.absoluteString }, things[0].videosTest.map { $0.absoluteString })
        }
    }
}

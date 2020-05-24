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
    var testDataIdentifier: String?
    
    override func setUp() {
        dbQueue = DatabaseQueue()
        do {
            try AppDatabase.migrator.migrate(dbQueue)
        } catch {
            XCTFail("Could not migrate DB")
        }
    }

    override func tearDown() {
        try! cleanTestFiles()
    }
    
    func loadTestData() throws {
        guard testDataIdentifier != nil
        else {
            XCTFail("Load of test data requires testDataIdentifier to be set")
            exit(EXIT_FAILURE)
        }
        
        // Mint participant
        _ = try Participant.appParticipant()
        
        // Mint five things, with five videos each
        let testVideoURL = Bundle(for: type(of: self)).url(forResource: "orbit-cup-photoreal", withExtension:"mp4")!
        for thingLabel in Settings.labels {
            var thing = Thing(withLabel: thingLabel)
            try dbQueue.write { db in try thing.save(db) }
            
            for videoLabel in Settings.labels {
                let url = videoURL(thing: thingLabel, video: videoLabel)
                try FileManager.default.copyItem(at: testVideoURL, to: url)
                
                var video = Video(of: thing, url: url, kind: .train)!
                try dbQueue.write { db in try video.save(db) }
            }
        }
    }
    
    func cleanTestFiles() throws {
        guard testDataIdentifier != nil
        else { return }
        
        for thingLabel in Settings.labels {
            for videoLabel in Settings.labels {
                do {
                    try FileManager.default.removeItem(at: videoURL(thing: thingLabel, video: videoLabel))
                } catch {
                    break
                }
            }
        }
    }
    
    func videoURL(thing: String, video: String) -> URL {
        guard let identifier = testDataIdentifier
        else { exit(EXIT_FAILURE) }
        
        let documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let filename = "_TEST--\(thing)-\(video)--\(identifier).mp4"
        return documentsDirectory.appendingPathComponent(filename)
    }
    
    /// Persist a participant. Create it, write it to storage, read it from storage, check it's the same.
    func testPersistParticipant() throws {
        var participant = Participant()
        XCTAssertNil(participant.id, "Unstored thing should have no ID")
        try dbQueue.write { db in try participant.save(db) }
        XCTAssertNotNil(participant.id, "Stored thing should have an ID")
        try dbQueue.write { db in try participant.save(db) } // Extra save, should not insert new
        
        var participants = try dbQueue.read { db in try Participant.fetchAll(db) }
        XCTAssertEqual(participants.count, 1, "Persisting a participant should result in one thing persisted")
        XCTAssertEqual(participant, participants[0], "Retreiving a persisted participant should return an identical participant")
        
        participant.studyStart = Date()
        participant.studyEnd = Date()
        try dbQueue.write { db in try participant.save(db) }
        participants = try dbQueue.read { db in try Participant.fetchAll(db) }
        XCTAssertEqual(participant.studyStart!.description, participants[0].studyStart!.description, "Retreiving a persisted participant should return an identical participant")
        XCTAssertEqual(participant.studyEnd!.description, participants[0].studyEnd!.description, "Retreiving a persisted participant should return an identical participant")
    }
    
    /// Persist a thing. Create it, write it to storage, read it from storage, check it's the same.
    func testPersistThing() throws {
        var thing = Thing(withLabel: "labelParticipant")
        XCTAssertNil(thing.id, "Unstored thing should have no ID")
        try dbQueue.write { db in try thing.save(db) }
        XCTAssertNotNil(thing.id, "Stored thing should have an ID")
        try dbQueue.write { db in try thing.save(db) } // Extra save, should not insert new
        
        var things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertEqual(things.count, 1, "Persisting a thing should result in one thing persisted")
        XCTAssertEqual(thing, things[0], "Retreiving a persisted thing should return an identical thing")

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
        var video = Video(of: thing, url: URL(fileURLWithPath: "path/to/1"), kind:.train)!
        try dbQueue.write { db in try video.save(db) }
        try dbQueue.write { db in try video.save(db) } // Extra save, should not insert new
        
        var videos = try dbQueue.read { db in try Video.fetchAll(db) }
        XCTAssertEqual(videos.count, 1, "Persisting a video should result in one thing persisted")
        // WTF: Equating the original URL with the encoded and decoded URLs fails!
        // "path/to/1 -- file:///" != "file:///path/to/1"
        //XCTAssertEqual(video, videos[0], "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.thingID, videos[0].thingID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.url, videos[0].url, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.recorded.description, videos[0].recorded.description, "Retreiving a persisted thing should return an identical thing") // Floating point internal representation is rounded to three decimal places on coding, so for expediency let's just compare the description.
        XCTAssertEqual(video.orbitID, videos[0].orbitID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.kind, videos[0].kind, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual(video.verified, videos[0].verified, "Retreiving a persisted thing should return an identical thing")
        
        video.orbitID = 456
        try dbQueue.write { db in try video.save(db) }
        
        videos = try dbQueue.read { db in try Video.fetchAll(db) }
        XCTAssertEqual(video.orbitID, videos[0].orbitID, "Retreiving a persisted thing should return an identical thing")
        XCTAssertEqual([video].map { $0.url.absoluteString }, thing.videos.map { $0.url.absoluteString }, "The thing's video property should return the video")
    }
    
    /// Load test data, checking it's what we expect
    func testLoadTestData() throws {
        testDataIdentifier = Settings.dateFormatter.string(from: Date())
        try loadTestData()
        
        let participants = try dbQueue.read { db in try Participant.fetchAll(db) }
        let things = try dbQueue.read { db in try Thing.fetchAll(db) }
        XCTAssertEqual(participants.count, 1, "Test data should only load one participant")
        XCTAssertEqual(things.count, 5, "Test data should have five things")
        XCTAssertEqual(things[0].videosCount, 5, "Test data should have five videos for a thing")
        XCTAssertNoThrow({
            let videos = try dbQueue.read { db in try Video.fetchAll(db) }
            for video in videos {
                try _ = video.url.checkResourceIsReachable()
            }
        }, "Test video files should have been placed")
    }
    
    /// Load test data, delete the one Participant, check it's gone.
    func testParticipantDelete() throws {
        testDataIdentifier = Settings.dateFormatter.string(from: Date())
        try loadTestData()
        
        let deletedCount = try dbQueue.write { db in try Participant.filter(key: 1).deleteAll(db) }
        XCTAssertEqual(deletedCount, 1, "The participant should have been deleted")
        
        let participantCount = try dbQueue.read { db in try Participant.fetchCount(db) }
        XCTAssertEqual(participantCount, 0, "The participant should have been deleted")
    }
    
    /// Load test data, delete the first Thing, check it's gone, and check it's videos have also gone.
    func testThingDelete() throws {
        testDataIdentifier = Settings.dateFormatter.string(from: Date())
        try loadTestData()
                
        var thingCount = try dbQueue.read { db in try Thing.filter(key: 1).fetchCount(db) }
        XCTAssertEqual(thingCount, 1, "The thing should be loaded from test data")
        
        var videoCount = try dbQueue.read { db in try Video.filter(Video.Columns.thingID == 1).fetchCount(db) }
        XCTAssertEqual(videoCount, 5, "The thing's videos should be loaded from test data")
        
        let deletedCount = try dbQueue.write { db in try Thing.filter(key: 1).deleteAll(db) }
        XCTAssertEqual(deletedCount, 1, "The thing should have been deleted")
        
        thingCount = try dbQueue.read { db in try Thing.filter(key: 1).fetchCount(db) }
        XCTAssertEqual(thingCount, 0, "The thing should have been deleted")
        
        videoCount = try dbQueue.read { db in try Video.filter(Video.Columns.thingID == 1).fetchCount(db) }
        XCTAssertEqual(videoCount, 0, "The thing should have no videos")
        
        let orphanVideos = try dbQueue.read { db in try Video.filter(Video.Columns.thingID == nil).fetchAll(db) }
        XCTAssertEqual(orphanVideos.count, 5, "There should be five orphaned videos")
        
        for label in Settings.labels {
            XCTAssertNoThrow(try videoURL(thing: Settings.labels[0], video: label).checkResourceIsReachable(), "The video file should also have been deleted")
        }
        for video in orphanVideos {
            _ = try dbQueue.write { db in try video.delete(db) }
        }
        videoCount = try dbQueue.read { db in try Video.filter(Video.Columns.thingID == nil).fetchCount(db) }
        XCTAssertEqual(videoCount, 0, "The five orphan videos should have been deleted")
        
        for label in Settings.labels {
            XCTAssertThrowsError(try videoURL(thing: Settings.labels[0], video: label).checkResourceIsReachable(), "The video file should also have been deleted")
        }
        
        thingCount = try dbQueue.read { db in try Thing.fetchCount(db) }
        XCTAssertEqual(thingCount, 4, "No other things should have been deleted")

        videoCount = try dbQueue.read { db in try Video.fetchCount(db) }
        XCTAssertEqual(videoCount, 20, "No other videos should have been deleted")
        
        for label in Settings.labels {
            XCTAssertNoThrow(try videoURL(thing: Settings.labels[1], video: label).checkResourceIsReachable(), "No other video files should have been deleted")
            XCTAssertNoThrow(try videoURL(thing: Settings.labels[2], video: label).checkResourceIsReachable(), "No other video files should have been deleted")
            XCTAssertNoThrow(try videoURL(thing: Settings.labels[3], video: label).checkResourceIsReachable(), "No other video files should have been deleted")
            XCTAssertNoThrow(try videoURL(thing: Settings.labels[4], video: label).checkResourceIsReachable(), "No other video files should have been deleted")
        }
    }
}

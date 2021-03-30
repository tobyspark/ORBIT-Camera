//
//  AppDatabase.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
//

import UIKit
import GRDB
import os

// The shared database queue
var dbQueue: DatabaseQueue!

/// A type responsible for initializing the application database.
///
/// See AppDelegate.setupDatabase()
struct AppDatabase {
    
    /// Setup qbQueue
    static func setup(_ application: UIApplication) throws {
        let databaseURL = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("db.sqlite")
        dbQueue = try openDatabase(atPath: databaseURL.path)
    }
    
    /// Creates a fully initialized database at path
    static func openDatabase(atPath path: String) throws -> DatabaseQueue {
        // Connect to the database
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
        let dbQueue = try DatabaseQueue(path: path)
        
        // Clear content if phase one data present
        if let migrations = try? dbQueue.read({ db in try migrator.completedMigrations(db) }),
           migrations.contains("createParticipant"),
           !migrations.contains("phaseTwo")
        {
            os_log("Removing Phase One participant")
            try dbQueue.write { db in
                let participants = try Participant.fetchAll(db)
                for participant in participants {
                    try participant.delete(db)
                }
            }
        }
           
        // Define the database schema
        try migrator.migrate(dbQueue)
        
        return dbQueue
    }
    
    /// The DatabaseMigrator that defines the database schema.
    ///
    /// See https://github.com/groue/GRDB.swift/blob/master/README.md#migrations
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("createParticipant") { db in
            try db.create(table: "participant") { t in
                // Column names as per CodingKeys
                t.autoIncrementedPrimaryKey("id")
                t.column("authCredential", .text)
            }
        }
        
        migrator.registerMigration("createThing") { db in
            try db.create(table: "thing") { t in
                // Column names as per CodingKeys
                t.autoIncrementedPrimaryKey("id")
                t.column("orbitID", .integer)
                t.column("labelParticipant", .text).notNull()
                t.column("labelDataset", .text)
            }
        }
        
        migrator.registerMigration("createVideo") { db in
            try db.create(table: "video") { t in
                // Column names as per CodingKeys
                t.autoIncrementedPrimaryKey("id")
                t.column("thingID", .integer).references("thing", onDelete: .setNull)
                t.column("filename", .text).notNull()
                t.column("recorded", .blob).notNull()
                t.column("orbitID", .integer)
                t.column("kind", .text)
            }
        }
        
        migrator.registerMigration("addVerifiedToVideo") { db in
            try db.alter(table: "video") { t in
                t.add(column: "verified", .text)
            }
            
            try Video.updateAll(db, [Video.Columns.verified.set(to: Video.Verified.unvalidated.rawValue)])
        }
        
        migrator.registerMigration("addStudyDatesToParticipant") { db in
            try db.alter(table: "participant") { t in
                t.add(column: "studyStart", .blob)
                t.add(column: "studyEnd", .blob)
            }
        }
        
        migrator.registerMigration("phaseTwo") { db in
            // Be able to test for a phase two app loading phase one data.
        }
        
        migrator.registerMigration("addUIOrderToVideo") { db in
            try db.create(table: "new_video") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("thingID", .integer).references("thing", onDelete: .setNull)
                t.column("filename", .text).notNull()
                t.column("recorded", .blob).notNull()
                t.column("orbitID", .integer)
                t.column("kind", .text)
                t.column("verified", .text)
                t.column("uiOrder", .integer).notNull()
                t.uniqueKey(["thingID", "kind", "uiOrder"])
            }
            for row in try Row.fetchAll(db, sql: "SELECT * FROM video") {
                let synthesisedUIOrder = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM new_video WHERE thingID = ?",
                    arguments: [row["thingID"]]
                )
                try db.execute(literal: """
                    INSERT INTO new_video (id, thingID, filename, recorded, orbitID, kind, verified, uiOrder)
                    VALUES(\(row["id"]), \(row["thingID"]), \(row["filename"]), \(row["recorded"]), \(row["orbitID"]), \(row["kind"]), \(row["verified"]), \(synthesisedUIOrder))
                    """
                )
            }
            try db.drop(table: "video")
            try db.rename(table: "new_video", to: "video")
        }
        return migrator
    }
}

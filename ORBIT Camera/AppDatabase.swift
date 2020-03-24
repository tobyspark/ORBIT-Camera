//
//  AppDatabase.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB

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
        
        // Be a nice iOS citizen, and don't consume too much memory
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#memory-management
        dbQueue.setupMemoryManagement(in: application)
    }
    
    /// Creates a fully initialized database at path
    static func openDatabase(atPath path: String) throws -> DatabaseQueue {
        // Connect to the database
        // See https://github.com/groue/GRDB.swift/blob/master/README.md#database-connections
        let dbQueue = try DatabaseQueue(path: path)
        
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
                t.column("uploadID", .integer)
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
                t.column("uploadID", .integer)
                t.column("orbitID", .integer)
                t.column("kind", .text)
            }
        }
        
        return migrator
    }
}

//
//  AppDatabase+TestData.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 05/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB

fileprivate let pilotData = [
    ("House keys", ["No technique": ["vntfptbnfp-square.mp4", "nnqykolszu-square.mp4", "sgfgkuronb-square.mp4"], "Rotate": ["ejkkfgrini-square.mp4"], "Zoom": ["scadigobdh-square.mp4"]]),
    ("Rucksack", ["No technique": ["iulqidvzyy-square.mp4", "gpfxtwcboq-square.mp4", "bmeddeqyzy-square.mp4"], "Rotate": ["dmfwfgqkqo-square.mp4"], "Zoom": ["kfogadrjvp-square.mp4"]]),
    ("White guide cane", ["No technique": ["nhypjmcteu-square.mp4", "xvhfnfpdlw-square.mp4", "ulcxypbtbr-square.mp4"], "Rotate": ["mjyfppcjcj-square.mp4"], "Zoom": ["kqgbslyhnp-square.mp4"]]),
    ("LG remote control", ["No technique": ["cggxjvrhzv-square.mp4", "bntumpdugq-square.mp4", "clwegalczo-square.mp4"], "Rotate": ["usdkfvycdi-square.mp4"], "Zoom": ["xovdsjalqn-square.mp4"]]),
    ("Lifemax talking watch", ["No technique": ["vgdvfwzkll-square.mp4", "knyitmaxiz-square.mp4", "oruwakvkvv-square.mp4"], "Rotate": ["wvdmxmssuv-square.mp4"], "Zoom": ["wsavgniidy-square.mp4"]])
    ]

enum TestDataError: Error {
    case unknownTechnique
}

// Will load in test data if database has no things. i.e. to load test data, remove all things from UI and then re-start.
extension AppDatabase {
    static func loadTestData() throws {
        guard try dbQueue.read({ db in try Thing.fetchCount(db) }) == 0
        else { return }
        
        let simulatorHostDirectory = URL(fileURLWithPath: "xxx/orbit_ml_dataset_export_2020-02-11_12-40-27") // The pilot `orbit_ml_dataset_export` folder
        let documentsDirectory = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        for (label, techniques) in pilotData {
            var thing = Thing(withLabel: label)
            try dbQueue.write { db in try thing.save(db) }
                
            for (technique, videoFilenames) in techniques {
                var videoKind: Video.Kind
                switch technique {
                case "No technique": videoKind = .train // arbitrary mapping of pilot to phase one kinds
                case "Rotate": videoKind = .test
                case "Zoom": videoKind = .test
                default: throw TestDataError.unknownTechnique
                }
                for videoFilename in videoFilenames{
                    let videoURL = URL(fileURLWithPath: videoFilename, relativeTo: documentsDirectory)
                    do {
                        try _ = videoURL.checkResourceIsReachable()
                    } catch {
                        try FileManager.default.copyItem(
                            at: URL(fileURLWithPath: videoFilename, relativeTo: simulatorHostDirectory),
                            to: URL(fileURLWithPath: videoFilename, relativeTo: documentsDirectory)
                        )
                    }
                    do {
                        try _ = videoURL.checkResourceIsReachable()
                    } catch {
                        assertionFailure("When loading test data could not locate video file")
                    }
                    var video = Video(of: thing, url: videoURL, kind: videoKind)!
                    video.recorded = Date(timeIntervalSinceNow: -Double.random(in: 0...7*24*60*60))
                    video.orbitID = 1
                    try dbQueue.write { db in try video.save(db) }
                }
            }
        }
    }
}

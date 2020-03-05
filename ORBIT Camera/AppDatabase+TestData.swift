//
//  AppDatabase+TestData.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 05/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB

fileprivate let testParticipant = Participant(
    id: 0,
    authCredential: "Basic " + Data("0:xxx".utf8).base64EncodedString()
)

fileprivate let pilotData = [
    "House keys": ["No technique": ["vntfptbnfp.mp4", "nnqykolszu.mp4", "sgfgkuronb.mp4"], "Rotate": ["ejkkfgrini.mp4"], "Zoom": ["scadigobdh.mp4"]],
    "Rucksack": ["No technique": ["iulqidvzyy.mp4", "gpfxtwcboq.mp4", "bmeddeqyzy.mp4"], "Rotate": ["dmfwfgqkqo.mp4"], "Zoom": ["kfogadrjvp.mp4"]],
    "White guide cane": ["No technique": ["nhypjmcteu.mp4", "xvhfnfpdlw.mp4", "ulcxypbtbr.mp4"], "Rotate": ["mjyfppcjcj.mp4"], "Zoom": ["kqgbslyhnp.mp4"]],
    "LG remote control": ["No technique": ["cggxjvrhzv.mp4", "bntumpdugq.mp4", "clwegalczo.mp4"], "Rotate": ["usdkfvycdi.mp4"], "Zoom": ["xovdsjalqn.mp4"]],
    "Lifemax talking watch": ["No technique": ["vgdvfwzkll.mp4", "knyitmaxiz.mp4", "oruwakvkvv.mp4"], "Rotate": ["wvdmxmssuv.mp4"], "Zoom": ["wsavgniidy.mp4"]]
    ]

enum TestDataError: Error {
    case unknownTechnique
}

// Note this shows the need for some comparison methods independent of app state e.g. uploadID
extension AppDatabase {
    static func loadTestData() throws {
        let dbParticipants = try dbQueue.read { db in try Participant.fetchAll(db) }
        if dbParticipants.count == 0 {
            try dbQueue.write { db in try testParticipant.save(db) }
        }
        
        let dbThings = try dbQueue.read { db in try Thing.fetchAll(db) }
        let dbLabels = dbThings.map { $0.labelParticipant }
        
        let dbVideos = try dbQueue.read { db in try Video.fetchAll(db) }
        let dbURLs = dbVideos.map { $0.url }
        
        let videoDirectory = URL(fileURLWithPath: "xxx/orbit_ml_dataset_export_2020-02-11_12-40-27") // The pilot `orbit_ml_dataset_export` folder
        for (label, techniques) in pilotData {
            var thing = Thing(withLabel: label)
            guard !dbLabels.contains(thing.labelParticipant) else { continue }
            try dbQueue.write { db in try thing.save(db) }
                
            for (technique, videoFilenames) in techniques {
                var videoKind: Video.Kind
                switch technique {
                case "No technique": videoKind = .recognition
                case "Rotate": videoKind = .registerRotate
                case "Zoom": videoKind = .registerZoom
                default: throw TestDataError.unknownTechnique
                }
                for videoFilename in videoFilenames{
                    let videoURL = URL(fileURLWithPath: videoFilename, relativeTo: videoDirectory)
                    try _ = videoURL.checkResourceIsReachable()
                    var video = Video(thingID: thing.id!, url: videoURL, kind: videoKind)
                    if !dbURLs.contains(video.url) {
                        try dbQueue.write { db in try video.save(db) }
                    }
                }
            }
        }
    }
}

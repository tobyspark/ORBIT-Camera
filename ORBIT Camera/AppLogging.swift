//
//  AppLogging.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 01/05/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
//

import os

let appUILog = OSLog(subsystem: "uk.ac.city.orbitcamera", category: "User Interface")
let appNetLog = OSLog(subsystem: "uk.ac.city.orbitcamera", category: "Network")
let appCamLog = OSLog(subsystem: "uk.ac.city.orbitcamera", category: "Camera")

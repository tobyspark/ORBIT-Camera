//
//  Settings+secrets.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 29/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation

extension Settings {
    static let appAuthCredential = "Basic " + Data("x:xxx".utf8).base64EncodedString()
}

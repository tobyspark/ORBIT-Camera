//
//  Settings+secrets.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 29/04/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
//

/// Further changes to this file should not be tracked in Git.
/// The file is included in Git so the project compiles and future users have an idea what's going on.
///
/// Relevant Git arcana –
/// `git update-index --assume-unchanged 'ORBIT Camera/Settings+secrets.swift'`
///

import Foundation

extension Settings {
    static let appAuthCredential = "Basic " + Data("x:xxx".utf8).base64EncodedString()
}

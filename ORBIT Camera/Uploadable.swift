//
//  Uploadable.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 03/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import Foundation
import GRDB

protocol Uploadable: CustomStringConvertible {
    /// A unique ID for the thing in the ORBIT dataset (or rather, the database the dataset will be produced from)
    var orbitID: Int? { get set }
    
    /// Upload the uploadable
    func upload(by participant: Participant, using session: inout AppURLSession) throws
    
    /// Assign orbitID from returned data
    mutating func uploadDidReceive(_ data: Data) throws
}

//
//  Collection+SafeSubscript.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 03/04/2020.
//  Copyright © 2020 City, University of London. All rights reserved.
//

import Foundation

extension Collection where Indices.Iterator.Element == Index {
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

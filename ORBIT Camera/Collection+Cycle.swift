//
//  Collection+Cycle.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/04/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import Foundation

extension Collection where Iterator.Element: Equatable {
    func cycle(after: Iterator.Element) -> Iterator.Element? {
        var iterator = self.makeIterator()
        while let element = iterator.next() {
            if element == after {
                if let returnElement = iterator.next() {
                    return returnElement
                } else {
                    return self.first!
                }
            }
        }
        return nil
    }
}

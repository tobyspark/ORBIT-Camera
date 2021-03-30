//
//  String+slugify.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 23/04/2020.
//  https://tobyz.net
//
//  Copyright © 2020 City, University of London. All rights reserved.
//  https://hcid.city
//

import Foundation

extension String {
    /// Produce a version of the string suitable for use as a URI part
    func slugify() -> String {
        // A port of readily found javascript slugify function –
        //    function slugify(text)
        //    {
        //      return text.toString().toLowerCase()
        //        .replace(/\s+/g, '-')           // Replace spaces with -
        //        .replace(/[^\w\-]+/g, '')       // Remove all non-word chars
        //        .replace(/\-\-+/g, '-')         // Replace multiple - with single -
        //        .replace(/^-+/, '')             // Trim - from start of text
        //        .replace(/-+$/, '');            // Trim - from end of text
        //    }
        
        return self
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)      // Replace spaces with -
            .replacingOccurrences(of: #"[^\w\-]+"#, with: "", options: .regularExpression)  // Remove all non-word chars
            .replacingOccurrences(of: #"\-\-+"#, with: "-", options: .regularExpression)    // Replace multiple - with single -
            .replacingOccurrences(of: #"^-+"#, with: "", options: .regularExpression)       // Trim - from start of text
            .replacingOccurrences(of: #"-+$"#, with: "", options: .regularExpression)       // Trim - from end of text
    }
}

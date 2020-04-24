//
//  MarkdownParser.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 24/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import Ink
import os

struct MarkdownParser {
    /// Return a HTML page generated from a markdown file bundled as an app's resource
    /// The file extension must be '.markdown'
    static func html(markdownResource: String) -> String {
        guard
            let url = Bundle.main.url(forResource: markdownResource, withExtension: "markdown"),
            let markdown = try? String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
        else {
            os_log("Could not load %{public}s.markdown", markdownResource)
            assertionFailure()
            return ("")
        }

        return MarkdownParser.htmlPage(bodyHTML: MarkdownParser.inkParser.html(from: markdown))
    }
    
    /// Return a HTML page and a dictionary of HTML element IDs keyed by Video.Kind.
    /// The results are generated from a markdown file bundled as an app's resource, with metadata values such as
    /// `train-header: training-video-tutorial`
    /// The file extension must be '.markdown'
    // The Ink markdown parser doesn't like Windows line-endings, so this will replace CRLF with LF on import
    static func parse(markdownResource: String) -> (html: String, kindElementIDs: Dictionary<Video.Kind, String>) {
        guard
            let url = Bundle.main.url(forResource: markdownResource, withExtension: "markdown"),
            let markdown = try? String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
        else {
            os_log("Could not load %{public}s.markdown", markdownResource)
            assertionFailure()
            return ("", [:])
        }

        let result = MarkdownParser.inkParser.parse(markdown)
        let kindElementIDs = Video.Kind.allCases.reduce(into: Dictionary<Video.Kind, String>(), { (dict, kind) in
            let key = kind.description.replacingOccurrences(of: " ", with: "-") + "-header"
            if let markdownValue = result.metadata[key] {
                dict[kind] = markdownValue
            } else {
                os_log("Could not find expected markdown metadata key: %{public}s", key)
                assertionFailure()
            }
        })
        return (MarkdownParser.htmlPage(bodyHTML: result.html), kindElementIDs)
    }
    
    /// Wrap the supplied HTML body content in a full HTML page
    static func htmlPage(bodyHTML: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <title>Title to validate</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, shrink-to-fit=no">
        <style>
            body {
                font-family: system-ui, sans-serif;
                color: \(UIColor.label.css);
                background-color: \(UIColor.systemBackground.css);
            }
        </style>
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }
    
    private static let inkParser = Ink.MarkdownParser(modifiers: [
        // Add id to header elements, to enable linking to them
        // i.e. <h1>A glorious heading</h1> -> <h1 id="a-glorious-heading">A glorious heading</h1>
        Modifier(target: .headings) { html, markdown in
            let header = markdown.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            let slug = header.slugify()
            let insertIndex = html.firstIndex(of: ">")!
            return html[html.startIndex..<insertIndex] + " id=\"" + slug + "\"" + html[insertIndex...]
        }
    ])
}

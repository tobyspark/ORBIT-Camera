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
    
    /// Return a HTML page and metadata generated from a markdown file bundled as an app's resource
    /// The file extension must be '.markdown'
    static func parse(markdownResource: String) -> Markdown {
        guard
            let url = Bundle.main.url(forResource: markdownResource, withExtension: "markdown"),
            let markdown = try? String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
        else {
            os_log("Could not load %{public}s.markdown", markdownResource)
            assertionFailure()
            return (MarkdownParser.inkParser.parse(""))
        }
        
        var result = MarkdownParser.inkParser.parse(markdown)
        result.html = MarkdownParser.htmlPage(bodyHTML: result.html)
        return result
    }
    
    /// Return a HTML page and a dictionary of HTML element IDs keyed by Video.Kind.
    /// The results are generated from a markdown file bundled as an app's resource, with metadata values such as
    /// `train-header: training-video-tutorial`
    /// The file extension must be '.markdown'
    // The Ink markdown parser doesn't like Windows line-endings, so this will replace CRLF with LF on import
    static func videoKindParse(markdownResource: String, startKey: String? = nil) -> (html: String, kindElementIDs: Dictionary<Video.Kind, String>) {
        guard
            let url = Bundle.main.url(forResource: markdownResource, withExtension: "markdown"),
            let markdown = try? String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
        else {
            os_log("Could not load %{public}s.markdown", markdownResource)
            assertionFailure()
            return ("", [:])
        }
        
        let result = MarkdownParser.inkParser.parse(markdown)
        
        // If startKey header markdown provided, start the HTML at the corresponding header tag
        // Find the slugified header id value within the header tag, and then work backwards to the opening bracket
        let html: String
        if let startKey = startKey,
           let startIDValue = result.metadata[startKey]?.slugify(),
           let startIDRange = result.html.range(of: startIDValue),
           let startIndex = result.html[..<startIDRange.lowerBound].lastIndex(of: "<")
        {
            html = String(result.html[startIndex...])
        } else {
            html = result.html
        }
        
        let kindElementIDs = Video.Kind.allCases.reduce(into: Dictionary<Video.Kind, String>(), { (dict, kind) in
            let key = kind.description.replacingOccurrences(of: " ", with: "-") + "-header"
            if let markdownValue = result.metadata[key] {
                dict[kind] = markdownValue.slugify()
            } else {
                os_log("Could not find expected markdown metadata key: %{public}s", key)
                assertionFailure()
            }
        })
        return (MarkdownParser.htmlPage(bodyHTML: html), kindElementIDs)
    }
    
    /// Wrap the supplied HTML body content in a full HTML page
    static func htmlPage(bodyHTML: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <title>Title to validate</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, shrink-to-fit=no">
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }
    
    // Use only single-quotes.
    static let css = """
    body {
        font-family: system-ui, sans-serif;
        color: \(UIColor.label.css);
        background-color: \(UIColor.systemBackground.css);
    }
    form ul {
        list-style-type: none;
        padding-inline-start: unset;
        margin-block-start: unset;
    }
    form li {
        margin-bottom: 0.5em;
    }
    form label, input {
        display: inline-block;
    }
    form input[type='checkbox'] {
        width: 10vw;
        vertical-align: top;
        position: relative;
        top: 0.1875em;
    }
    form label {
        width: 80vw;
    }
    """
    
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

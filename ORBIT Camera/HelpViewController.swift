//
//  HelpViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 23/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB
import WebKit
import Ink // Markdown
import os

class HelpViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var webViewHeightContstraint: NSLayoutConstraint!
    
    var kind: Video.Kind?
    var kindElementIds: [Video.Kind: String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let result = parse(markdownResource: "TutorialScript")
        kindElementIds = result.kindElementIDs
        
        webView.navigationDelegate = self
        webView.loadHTMLString(result.html, baseURL: nil)
    }
    
    let parser = MarkdownParser(modifiers: [
        // Add id to header elements, to enable linking to them
        // i.e. <h1>A glorious heading</h1> -> <h1 id="a-glorious-heading">A glorious heading</h1>
        Modifier(target: .headings) { html, markdown in
            let header = markdown.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            let slug = header.slugify()
            let insertIndex = html.firstIndex(of: ">")!
            return html[html.startIndex..<insertIndex] + " id=\"" + slug + "\"" + html[insertIndex...]
        }
    ])
    
    // The Ink markdown parser doesn't like Windows line-endings, so this will replace CRLF with LF on import
    func parse(markdownResource: String) -> (html: String, kindElementIDs: Dictionary<Video.Kind, String>) {
        guard
            let url = Bundle(for: type(of: self)).url(forResource: markdownResource, withExtension: "markdown"),
            let markdown = try? String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
        else {
            os_log("Could not load %{public}s.markdown", markdownResource)
            assertionFailure()
            return ("", [:])
        }

        let result = parser.parse(markdown)
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
            <title>\(markdownResource)</title>
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
            \(result.html)
            </body>
            </html>
            """
        let kindElementIDs = Video.Kind.allCases.reduce(into: Dictionary<Video.Kind, String>(), { (dict, kind) in
            let key = kind.description.replacingOccurrences(of: " ", with: "-") + "-header"
            if let markdownValue = result.metadata[key] {
                dict[kind] = markdownValue
            } else {
                os_log("Could not find expected markdown metadata key: %{public}s", key)
                assertionFailure()
            }
        })
        return (html, kindElementIDs)
    }
}

extension HelpViewController: WKNavigationDelegate {
    // On page load...
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Set the WebView to be the height of the page
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] (height, error) in
            guard let self = self else { return }
            self.webViewHeightContstraint.constant = height as! CGFloat
        }
        // Scroll the scrollView to the desired element, and set accessibility focus to it.
        //
        // Except that, as of iOS 11.3.2, the javascript focus() method is ignored when not user-initiated.
        // Which is a bummer, as per a 2016 Apple Accessibility mailing list post, that's how you set the accessibility focus.
        // Want to swizzle obj-c? You can hack into WKWebView and flip the isUserInteractive flag or somesuch. But this ain't that kind of project.
        // Alternatives around setting the javascript location.hash didn't work out (but loading the page with the fragment identifier has to be possible somehow).
        // Less deterministic, but there is some logic to scrolling and then telling UIAccessibility to find the first on-screen element
        // And that seems to work? If you set it to focus the enclosing scroll view? Which is fixed to the screen, rather than the web view, which very much ain't.
        // ...but, well, not reliably. Hmm.
        if let kind = kind,
           let kindElementIds = kindElementIds,
           let anchor = kindElementIds[kind]
        {
            webView.evaluateJavaScript("document.getElementById('\(anchor)').offsetTop") { [weak self] (offset, error) in
                guard let self = self else { return }
                self.scrollView.contentOffset.y = self.webView.frame.minY + (offset as! CGFloat) - 8
                UIAccessibility.post(notification: .layoutChanged, argument: self.scrollView)
            }
        }
    }
    
    // On clicking a link, scroll the overall view to the appropriate place (as the webview is sized to be static)
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let aboutBlank = "about:blank%23"
        if navigationAction.navigationType == .linkActivated,
           let link = navigationAction.request.url?.absoluteString,
           link.hasPrefix(aboutBlank)
        {
            let anchor = link.dropFirst(aboutBlank.count)
            webView.evaluateJavaScript("document.getElementById('\(anchor)').offsetTop") { [weak self] (offset, error) in
                guard let self = self else { return }
                self.scrollView.contentOffset.y = webView.frame.minY + (offset as! CGFloat) - 8
            }
        }
        decisionHandler(WKNavigationActionPolicy.allow)
    }
}

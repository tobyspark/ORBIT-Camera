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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        let introHTML = html(markdownResource: "Introduction")
        webView.loadHTMLString(introHTML, baseURL: nil)
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
    func html(markdownResource: String) -> String {
        guard let url = Bundle(for: type(of: self)).url(forResource: markdownResource, withExtension: "markdown")
        else {
            os_log("Could not find %{public}s.markdown", markdownResource)
            return ""
        }
        
        do {
            let markdown = try String(contentsOf: url).replacingOccurrences(of: "\r\n", with: "\n")
            return """
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
            \(parser.html(from: markdown))
            </body>
            </html>
            """
        } catch {
            print(error)
            assertionFailure()
        }
        return ""
    }
}

extension HelpViewController: WKNavigationDelegate {
    // On page load, set the WebView to be the height of the page
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] (height, error) in
            guard let self = self else { return }
            self.webViewHeightContstraint.constant = height as! CGFloat
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

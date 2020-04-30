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
import os

class HelpViewController: UIViewController {
    
    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var webViewHeightContstraint: NSLayoutConstraint!
    
    var kind: Video.Kind?
    var kindElementIds: [Video.Kind: String]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let result = MarkdownParser.videoKindParse(markdownResource: "TutorialScript", startKey: "help-start-header")
        kindElementIds = result.kindElementIDs
        
        webView.navigationDelegate = self
        webView.loadHTMLString(result.html, baseURL: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Announce the screen change
        UIAccessibility.post(notification: .screenChanged, argument: "Recording help sheet")
    }
    
    override func viewDidLayoutSubviews() {
        // Make the dismiss accessibility frame a strip down the RHS edge of the screen
        // To not mess with the visual UI expected touches, this requires a separate element to mock the button
        let dismissElement = UIAccessibilityElement(accessibilityContainer: view!)
        dismissElement.accessibilityLabel = dismissButton.accessibilityLabel
        dismissElement.accessibilityTraits = dismissButton.accessibilityTraits
        
        let viewFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        let dismissButtonFrame = UIAccessibility.convertToScreenCoordinates(dismissButton.bounds, in: dismissButton)
        dismissElement.accessibilityFrame = CGRect(
            x: dismissButtonFrame.minX,
            y: viewFrame.minY,
            width: viewFrame.maxX - dismissButtonFrame.minX,
            height: viewFrame.height
        )
        dismissElement.accessibilityActivationPoint = CGPoint(x: dismissButtonFrame.midX, y: dismissButtonFrame.midY)
        
        view.accessibilityElements = [
            dismissElement,
            scrollView!
        ]
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

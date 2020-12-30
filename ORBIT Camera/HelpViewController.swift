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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide until we're ready, reveal by WKNavigationDelegate
        scrollView.alpha = 0
        
        let html = MarkdownParser.html(markdownResource: "Recording")
        
        // Webview: handle page load completion, etc.
        webView.navigationDelegate = self
        
        // Webview: inject CSS on page load
        let cssInjectJS = """
            var style = document.createElement('style');
            style.innerHTML = "\(MarkdownParser.css.components(separatedBy: .newlines).joined())";
            document.head.appendChild(style);
            """
        let userScript = WKUserScript(source: cssInjectJS,
                                      injectionTime: .atDocumentEnd,
                                      forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(userScript)
        
        webView.loadHTMLString(html, baseURL: nil)
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
        
        // iPad: size to be within the videoview, half width and stopping above pager and add button
        let insetToClearControls: CGFloat = 83 // a magic number
        preferredContentSize = CGSize(width: UIScreen.main.bounds.width/2, height: UIScreen.main.bounds.width - insetToClearControls)
    }
}

extension HelpViewController: WKNavigationDelegate {
    // On page load...
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Set the WebView to be the height of the page
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] (height, error) in
            guard let self = self else { return }
            self.webViewHeightContstraint.constant = height as! CGFloat
            
            // Reveal the content
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.scrollView.alpha = 1
            }
        }
    }
    
    /// On clicking a local link, scroll the overall view to the appropriate place (as the webview is sized to be static)
    /// Otherwise, open in device's web browser
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let aboutBlank = "about:blank%23"
        if navigationAction.navigationType == .linkActivated,
           let link = navigationAction.request.url
        {
            if link.absoluteString.hasPrefix(aboutBlank) {
                let anchor = link.absoluteString.dropFirst(aboutBlank.count)
                webView.evaluateJavaScript("document.getElementById('\(anchor)').offsetTop") { [weak self] (offset, error) in
                    guard let self = self else { return }
                    self.scrollView.contentOffset.y = webView.frame.minY + (offset as! CGFloat) - 8
                }
                decisionHandler(WKNavigationActionPolicy.allow)
            } else {
                UIApplication.shared.open(link)
                decisionHandler(WKNavigationActionPolicy.cancel)
            }
        } else {
            decisionHandler(WKNavigationActionPolicy.allow)
        }
    }
}

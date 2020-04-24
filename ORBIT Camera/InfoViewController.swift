//
//  InfoViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB
import WebKit
import Ink // Markdown
import os

class InfoViewController: UIViewController {

    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var unlockCode: UITextField!
    @IBOutlet weak var unlockCodeStatus: UILabel!
    
    @IBOutlet weak var introWebView: WKWebView!
    @IBOutlet weak var introWebViewHeightContstraint: NSLayoutConstraint!
    
    @IBOutlet weak var tutorialWebView: WKWebView!
    @IBOutlet weak var tutorialWebViewHeightContstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        introWebView.navigationDelegate = self
        let introHTML = html(markdownResource: "Introduction")
        introWebView.loadHTMLString(introHTML, baseURL: nil)
        
        tutorialWebView.navigationDelegate = self
        let tutorialHTML = html(markdownResource: "TutorialScript")
        tutorialWebView.loadHTMLString(tutorialHTML, baseURL: nil)
        
        if let credential = try! Participant.appParticipant().authCredential { // FIXME: try!
            unlockCode.text = credential
            checkCredential(credential)
        }
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
    
    @IBAction func unlockCodeEditingDidEnd(_ sender: Any) {
        if let credential = unlockCode.text {
            checkCredential(credential)
        }
    }
    
    enum CredentialError: Error {
        case transportError
        case responseError
        case unexpectedResponse
        case credentialRejected
    }
    
    func checkCredential(_ credential: String) {
        // Test the auth credential by hitting an API endpoint
        let url = URL(string: Settings.endpointThing)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(credential, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            let result: Result<String, CredentialError>
            if error != nil {
                result = .failure(.transportError)
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        result = .success(credential) // TODO: also return the ORBIT participant ID, having hit a participant end-point and decoding the json
                    case 403:
                        result = .failure(.credentialRejected)
                    default:
                        result = .failure(.unexpectedResponse)
                    }
                } else {
                    result = .failure(.responseError)
                }
            }
            if case .failure(let error) = result {
                os_log("%{public}@", error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.handleCredentialResult(result)
            }
        }
        task.resume()
        unlockCodeStatus.textColor = .label
        unlockCodeStatus.text = "Verifying credential..."
    }
    
    func handleCredentialResult(_ result: Result<String, CredentialError>) {
        switch result {
        case .success(let credential):
            // UI
            unlockCodeStatus.textColor = .systemGreen
            unlockCodeStatus.text = "Code accepted"
            // Save validated credential
            var participant = try! Participant.appParticipant() // FIXME: try!
            participant.authCredential = credential
            try! dbQueue.write { db in try participant.save(db) } // FIXME: try!
        case .failure(let error):
            unlockCodeStatus.textColor = .systemRed
            switch error {
            case .transportError:
                unlockCodeStatus.text = "Could not verify: transport error"
            case .responseError:
                unlockCodeStatus.text = "Could not verify: error in server response"
            case .unexpectedResponse:
                unlockCodeStatus.text = "Could not verify: unexpected server response"
            case .credentialRejected:
                unlockCodeStatus.text = "Code rejected"
            }
        }
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

extension InfoViewController: WKNavigationDelegate {
    // On page load, set the WebView to be the height of the page
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] (height, error) in
            guard let self = self else { return }
            if webView === self.introWebView {
                self.introWebViewHeightContstraint.constant = height as! CGFloat
            }
            if webView === self.tutorialWebView {
                self.tutorialWebViewHeightContstraint.constant = height as! CGFloat
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

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
import os

class InfoViewController: UIViewController {

    @IBOutlet weak var dismissButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var webViewHeightContstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.navigationDelegate = self
        let introHTML = MarkdownParser.html(markdownResource: "TutorialScript")
        webView.loadHTMLString(introHTML, baseURL: nil)

// TODO: Move to first-run
//        if let credential = try! Participant.appParticipant().authCredential { // FIXME: try!
//            unlockCode.text = credential
//            checkCredential(credential)
//        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Announce the screen change
        UIAccessibility.post(notification: .screenChanged, argument: "Info sheet")
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

// TODO: Move to first-run
//    @IBAction func unlockCodeEditingDidEnd(_ sender: Any) {
//        if let credential = unlockCode.text {
//            checkCredential(credential)
//        }
//    }
//
//    enum CredentialError: Error {
//        case transportError
//        case responseError
//        case unexpectedResponse
//        case credentialRejected
//    }
//
//    func checkCredential(_ credential: String) {
//        // Test the auth credential by hitting an API endpoint
//        let url = URL(string: Settings.endpointThing)!
//        var request = URLRequest(url: url)
//        request.httpMethod = "GET"
//        request.setValue(credential, forHTTPHeaderField: "Authorization")
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
//            let result: Result<String, CredentialError>
//            if error != nil {
//                result = .failure(.transportError)
//            } else {
//                if let httpResponse = response as? HTTPURLResponse {
//                    switch httpResponse.statusCode {
//                    case 200...299:
//                        result = .success(credential) // TODO: also return the ORBIT participant ID, having hit a participant end-point and decoding the json
//                    case 403:
//                        result = .failure(.credentialRejected)
//                    default:
//                        result = .failure(.unexpectedResponse)
//                    }
//                } else {
//                    result = .failure(.responseError)
//                }
//            }
//            if case .failure(let error) = result {
//                os_log("%{public}@", error.localizedDescription)
//            }
//            DispatchQueue.main.async {
//                self.handleCredentialResult(result)
//            }
//        }
//        task.resume()
//        unlockCodeStatus.textColor = .label
//        unlockCodeStatus.text = "Verifying credential..."
//    }
//
//    func handleCredentialResult(_ result: Result<String, CredentialError>) {
//        switch result {
//        case .success(let credential):
//            // UI
//            unlockCodeStatus.textColor = .systemGreen
//            unlockCodeStatus.text = "Code accepted"
//            // Save validated credential
//            var participant = try! Participant.appParticipant() // FIXME: try!
//            participant.authCredential = credential
//            try! dbQueue.write { db in try participant.save(db) } // FIXME: try!
//        case .failure(let error):
//            unlockCodeStatus.textColor = .systemRed
//            switch error {
//            case .transportError:
//                unlockCodeStatus.text = "Could not verify: transport error"
//            case .responseError:
//                unlockCodeStatus.text = "Could not verify: error in server response"
//            case .unexpectedResponse:
//                unlockCodeStatus.text = "Could not verify: unexpected server response"
//            case .credentialRejected:
//                unlockCodeStatus.text = "Code rejected"
//            }
//        }
//    }
}

extension InfoViewController: WKNavigationDelegate {
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

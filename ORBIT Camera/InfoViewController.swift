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

    @IBOutlet weak var sheetButton: UIButton!
    
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var stackView: UIStackView!
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var webViewHeightContstraint: NSLayoutConstraint!
    
    /// The kinds of page the info scene can display
    enum InfoPageKind {
        /// Participant Info
        /// - Share button
        /// - Markdown text
        /// - Continue button
        case participantInfo
        
        /// InformedConsent
        /// - Dismiss button
        /// - Markdown text
        /// - Name text field
        /// - Series of checkbox consents
        /// - Email text field
        /// - Submit button
        case informedConsent
        
        /// App Information
        /// - Dismiss button
        /// - Markdown text
        /// - Registered email address
        /// - Verified
        case appInfo
    }
    /// The page the info scene is set to display
    var page: InfoPageKind = .participantInfo {
        didSet { configurePage() }
    }
    
    @IBAction func dismissButtonAction() {
        switch page {
        case .participantInfo:
            shareParticipantInfo()
        case .informedConsent:
            page = .participantInfo
        case .appInfo:
            dismiss(animated: true)
        }
        
    }
    
    @objc func participantInfoContinueAction() {
        page = .informedConsent
    }
    
    var informedConsentNameField: UITextField?
    var informedConsentEmailField: UITextField?
    var informedConsentErrorLabel: UILabel?
    var informedConsentSubmitButton: UIButton?
    var informedConsentAllConsentsChecked = false {
        didSet { informedConsentSetSubmitEnable() }
    }
    var informedConsentIsSubmitting = false {
        didSet {
            guard let informedConsentSubmitButton = informedConsentSubmitButton
            else { return }
            
            informedConsentSubmitButton.isEnabled = !informedConsentIsSubmitting
            informedConsentSubmitButton.setTitle(!informedConsentIsSubmitting ? "Submit" : "Submitting...", for: .normal)
        }
    }
    func informedConsentSetSubmitEnable() {
        guard
            let button = informedConsentSubmitButton,
            let name = informedConsentNameField?.text,
            let email = informedConsentEmailField?.text
        else
            { return }
        
        button.isEnabled = informedConsentAllConsentsChecked &&
            isValidName(name) &&
            isValidEmail(email)
    }

    @objc func informedConsentSubmitAction() {
        guard
            let name = informedConsentNameField?.text,
            let email = informedConsentEmailField?.text
        else
            { return }

        requestCredential(name: name, email: email)
    }
    
    func shareParticipantInfo() {
        // Create document. HTML good for accessibility and more known than markdown.
        let html = MarkdownParser.html(markdownResource: "ParticipantInformation")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ORBIT-Participation-Information.html")
        do {
            try html.write(to: tempURL, atomically: false, encoding: .utf8)
        } catch {
            os_log("Participant Information HTML file creation failed")
            return
        }
        
        let docController = UIDocumentInteractionController(url: tempURL)
        docController.presentOpenInMenu(from: sheetButton.frame, in: view, animated: true)
    }
    
    func configurePage() {
        guard
            sheetButton != nil,
            webView != nil,
            webViewHeightContstraint != nil,
            stackView != nil
        else
            { return }
        
        let html: String
        
        webViewHeightContstraint.constant = 0
        for view in stackView.subviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        switch page {
        case .participantInfo:
            isModalInPresentation = true
            
            let shareImage = UIImage(systemName: "square.and.arrow.up")!
            sheetButton.setImage(shareImage, for: .normal)
            sheetButton.accessibilityLabel = "Share"
            sheetButton.accessibilityHint = "Brings up share sheet so you can save this information"
            
            html = MarkdownParser.html(markdownResource: "ParticipantInformation")
            
            let button = UIButton(type: .system)
            button.setTitle("Continue", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            button.addTarget(self, action: #selector(participantInfoContinueAction), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        case .informedConsent:
            let backImage = UIImage(systemName: "xmark.circle")!
            sheetButton.setImage(backImage, for: .normal)
            sheetButton.accessibilityLabel = "Back"
            sheetButton.accessibilityHint = "Returns to Participant Information"
            
            // Webview: get HTML, appending form created from markdown metadata
            let result = MarkdownParser.parse(markdownResource: "InformedConsent")
            let metaKeys = result.metadata.keys.sorted()
            
            var formHTML = "<form><ul>"
            for key in metaKeys {
                formHTML += """
                    <li>
                        <input type='checkbox' name='consent-checkbox' id='id-\(key)' required>
                        <label for='id-\(key)'>\(result.metadata[key]!)</label>
                    </li>
                """
            }
            formHTML += "</ul></form>"
            
            html = result.html + formHTML
                        
            // Webview: inject script on page load
            var notifyOnChangeJS = """
                const checkboxOnChange = () => {
                    const checkboxes = document.getElementsByName('consent-checkbox');
                    const allChecked = Array.from(checkboxes).every( element => element.checked );
                    window.webkit.messageHandlers.orbitcamera.postMessage(allChecked);
                };
                
                """
            for key in metaKeys {
                notifyOnChangeJS += """
                document.getElementById('id-\(key)').onchange = checkboxOnChange;
                
                """
            }
            
            let userScript = WKUserScript(source: notifyOnChangeJS,
                                          injectionTime: .atDocumentEnd,
                                          forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(userScript)
            
            let signedLabel = UILabel()
            signedLabel.text = "Signed –"
            stackView.addArrangedSubview(signedLabel)
            
            let nameField = UITextField()
            nameField.placeholder = "Enter your name"
            nameField.accessibilityLabel = "Name"
            nameField.returnKeyType = .next
            nameField.delegate = self
            informedConsentNameField = nameField
            stackView.addArrangedSubview(nameField)
            
            let emailField = UITextField()
            emailField.placeholder = "Enter your email address"
            emailField.accessibilityLabel = "Email address"
            emailField.keyboardType = .emailAddress
            emailField.returnKeyType = .done
            emailField.delegate = self
            informedConsentEmailField = emailField
            stackView.addArrangedSubview(emailField)
            
            let errorLabel = UILabel()
            errorLabel.numberOfLines = 0 // As many as needed
            errorLabel.textColor = .systemRed
            errorLabel.isHidden = true
            informedConsentErrorLabel = errorLabel
            stackView.addArrangedSubview(errorLabel)
            
            let button = UIButton(type: .system)
            button.setTitle("Submit consent", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            button.isEnabled = false
            button.addTarget(self, action: #selector(informedConsentSubmitAction), for: .touchUpInside)
            informedConsentSubmitButton = button
            stackView.addArrangedSubview(button)
        case .appInfo:
            isModalInPresentation = false
            
            let closeImage = UIImage(systemName: "xmark.circle")!
            sheetButton.setImage(closeImage, for: .normal)
            
            html = MarkdownParser.html(markdownResource: "TutorialScript")
        }
        
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        
        scrollView.setContentOffset(CGPoint.zero, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        // Webview: Set message handler
        webView.configuration.userContentController.add(self, name: "orbitcamera")
        
        // Webview: handle page load completion, etc.
        webView.navigationDelegate = self
        
        // Keyboard: handle it showing
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardShow), name: UIWindow.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardShow), name: UIWindow.keyboardWillHideNotification, object: nil)
        
        configurePage()

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
        let buttonElement = UIAccessibilityElement(accessibilityContainer: view!)
        buttonElement.accessibilityLabel = sheetButton.accessibilityLabel
        buttonElement.accessibilityTraits = sheetButton.accessibilityTraits
        
        let viewFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        let dismissButtonFrame = UIAccessibility.convertToScreenCoordinates(sheetButton.bounds, in: sheetButton)
        buttonElement.accessibilityFrame = CGRect(
            x: dismissButtonFrame.minX,
            y: viewFrame.minY,
            width: viewFrame.maxX - dismissButtonFrame.minX,
            height: viewFrame.height
        )
        buttonElement.accessibilityActivationPoint = CGPoint(x: dismissButtonFrame.midX, y: dismissButtonFrame.midY)
        
        view.accessibilityElements = [
            buttonElement,
            scrollView!
        ]
    }
    
    @objc func handleKeyboardShow(notification: Notification) {
        guard
            let keyboardEndRect = notification.userInfo?["UIKeyboardFrameEndUserInfoKey"] as? CGRect
        else { return }
        
        switch notification.name {
        case UIWindow.keyboardWillShowNotification:
            scrollView.contentInset.bottom = keyboardEndRect.height
        case UIWindow.keyboardWillHideNotification:
            scrollView.contentInset.bottom = 0
        default:
            break
        }
    }
    
    func isValidName(_ candidate: String) -> Bool {
        return candidate.trimmingCharacters(in: .whitespaces).count > 2
    }
    
    func isValidEmail(_ candidate: String) -> Bool {
        guard
            let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
            let matchRange = dataDetector.firstMatch(in: candidate, options: .anchored, range: NSMakeRange(0, candidate.count))
        else { return false }
        
        return matchRange.range.length == candidate.count
    }
    
    enum CredentialError: Error {
        case transportError
        case responseError
        case badRequest([String: [String]])
        case forbidden
        case unexpectedResponse
    }

    func requestCredential(name: String, email: String) {
        guard informedConsentIsSubmitting == false
        else { return }
        
        informedConsentIsSubmitting = true
        
        guard let uploadData = try? JSONEncoder().encode(
            Settings.endpointCreateParticipantRequest(name: name, email: email)
            )
        else {
            os_log("Could not create uploadData")
            assertionFailure()
            return
        }
        
        let url = URL(string: Settings.endpointCreateParticipant)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Settings.appAuthCredential, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.uploadTask(with: request, from: uploadData) { (data, response, error) in
            let result: Result<String, CredentialError>
            if error != nil {
                result = .failure(.transportError)
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 201:
                        if let data = data,
                           let json = try? JSONDecoder().decode(Settings.endpointCreateParticipantResponse.self, from: data)
                        {
                            result = .success(json.auth_credential)
                        }
                        else {
                            result = .failure(.unexpectedResponse)
                        }
                    case 400:
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String:[String]]
                        {
                            result = .failure(.badRequest(json))
                        } else {
                            result = .failure(.badRequest([:]))
                        }
                    case 403:
                        result = .failure(.forbidden)
                    default:
                        result = .failure(.unexpectedResponse)
                    }
                } else {
                    result = .failure(.responseError)
                }
            }
            if case .failure(let error) = result {
                os_log("Request credential %{public}@", error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.handleCredentialResult(result)
            }
        }
        task.resume()
    }

    func handleCredentialResult(_ result: Result<String, CredentialError>) {
        switch result {
        case .success(let credential):
            // Save validated credential
            var participant = try! Participant.appParticipant() // FIXME: try!
            participant.authCredential = credential
            try! dbQueue.write { db in try participant.save(db) } // FIXME: try!
            
            // Dismiss screen, i.e. enter app proper
            dismiss(animated: true)
        case .failure(let error):
            if let informedConsentErrorLabel = informedConsentErrorLabel,
               let informedConsentSubmitButton = informedConsentSubmitButton
            {
                switch error {
                case .transportError:
                    informedConsentErrorLabel.text = "There was a network problem submitting your consent. Is your iOS connected to the internet?\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
                case .responseError:
                    informedConsentErrorLabel.text = "There was a problem submitting your consent. The app received an unexpected response from the ORBIT servers.\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
                case .badRequest(let response):
                    var message = "There was a problem submitting your consent. The ORBIT servers rejected the request.\n\n"
                    for (field, values) in response {
                        for value in values {
                            message += value.replacingOccurrences(of: "this field", with: field) + "\n"
                        }
                    }
                    message += "\nIf this problem persists, please contact info@orbit.city.ac.uk"
                    informedConsentErrorLabel.text = message
                case .unexpectedResponse:
                    informedConsentErrorLabel.text = "There was a problem submitting your consent. The app received an unexpected response from the ORBIT servers.\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
                case .forbidden:
                    informedConsentErrorLabel.text = "There was a problem submitting your consent. The app could not authenticate with the ORBIT servers.\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
                }
                informedConsentErrorLabel.isHidden = false
                scrollView.scrollRectToVisible(stackView.frame, animated: true)
                informedConsentIsSubmitting = false
            }
        }
    }
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

extension InfoViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let allConsentsChecked = message.body as? Bool
        {
            informedConsentAllConsentsChecked = allConsentsChecked
        }
    }
}

extension InfoViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === informedConsentNameField {
            informedConsentEmailField?.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        informedConsentSetSubmitEnable()
        return true
    }
}

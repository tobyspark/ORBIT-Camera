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

/// This presents a screen about the app. It contains
/// - Logo and name
/// - A webview for loading in structured text etc.
/// - A stackview that can be used for page specific UI elements
///
/// Currently, it can display three different types of page. See `InfoPageKind`
/// Aaaand this whole thing should probably be refactored into a subclass per page. But so it goes.
class InfoViewController: UIViewController {
    
    /// Accessibility - a heading element to name the screen.
    // `screenChanged` notification messages were not proving reliable, without this would lead to "dismiss" etc. as the announcement.
    var headingElement: UIAccessibilityElement!
    
    /// Top-right button anchored to sheet.
    @IBOutlet weak var sheetButton: UIButton!
    /// Accessibility - equivalent to the sheetButton, but with frame down RHS of screen for easy, always there access.
    var sheetButtonElement: UIAccessibilityElement!
    
    /// Content is enclosed in scroll view
    @IBOutlet weak var scrollView: UIScrollView!
    
    @IBOutlet weak var logoView: UIImageView!
    
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
    
    /// Navigate internally, or dismiss.
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
    var informedConsentNameErrorLabel: UILabel?
    var informedConsentNameErrorLabelText: String? {
        didSet {
            if informedConsentNameErrorLabelText != nil {
                informedConsentNameErrorLabel?.text = informedConsentNameErrorLabelText
            }
            if informedConsentNameErrorLabelText != oldValue {
                UIView.animate(withDuration: 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.informedConsentNameErrorLabel?.isHidden = self.informedConsentNameErrorLabelText == nil
                }
            }
        }
    }
    var informedConsentEmailField: UITextField?
    var informedConsentEmailErrorLabel: UILabel?
    var informedConsentEmailErrorLabelText: String? {
        didSet {
            if informedConsentEmailErrorLabelText != nil {
                informedConsentEmailErrorLabel?.text = informedConsentEmailErrorLabelText
            }
            if informedConsentEmailErrorLabelText != oldValue {
                UIView.animate(withDuration: 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.informedConsentEmailErrorLabel?.isHidden = self.informedConsentEmailErrorLabelText == nil
                }
            }
        }
    }
    var informedConsentErrorLabel: UILabel?
    var informedConsentErrorLabelText: String? {
        didSet {
            if informedConsentErrorLabelText != nil {
                informedConsentErrorLabel?.text = informedConsentErrorLabelText
            }
            if informedConsentErrorLabelText != oldValue {
                UIView.animate(withDuration: 0.3) { [weak self] in
                    guard let self = self else { return }
                    self.informedConsentErrorLabel?.isHidden = self.informedConsentErrorLabelText == nil
                }
            }
        }
    }
    var informedConsentSubmitButton: UIButton?
    var informedConsentAllConsentsChecked = false {
        didSet { informedConsentSetValidationUI() }
    }
    var informedConsentIsSubmitting = false {
        didSet {
            guard let informedConsentSubmitButton = informedConsentSubmitButton
            else { return }
            
            informedConsentSubmitButton.isEnabled = !informedConsentIsSubmitting
            informedConsentSubmitButton.setTitle(!informedConsentIsSubmitting ? "Submit" : "Submitting...", for: .normal)
        }
    }
    func informedConsentSetValidationUI() {
        guard
            let button = informedConsentSubmitButton,
            let nameField = informedConsentNameField,
            let emailField = informedConsentEmailField
        else
            { return }
        let nameValid = isValidName(nameField.text ?? "")
        let emailValid = isValidEmail(emailField.text ?? "")
        
        informedConsentErrorLabelText = nil
        informedConsentNameErrorLabelText = nameValid ? nil : "Name is too short"
        informedConsentEmailErrorLabelText = emailValid ? nil : "Email is not a valid address"
        button.isEnabled = informedConsentAllConsentsChecked && nameValid && emailValid
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
            os_log("Participant Information HTML file creation failed", log: appUILog)
            return
        }
        
        let docController = UIDocumentInteractionController(url: tempURL)
        docController.presentOpenInMenu(from: sheetButton.frame, in: view, animated: true)
    }
    
    func configurePage(accessibilityScreenChangedMessage: String? = nil) {
        guard
            sheetButton != nil,
            webView != nil,
            webViewHeightContstraint != nil,
            stackView != nil
        else
            { return }
        
        let html: String
        
        // Reset
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.scrollView.alpha = 0 // Set back to 1 on page load. This is set in webview delegate.
        }
        webViewHeightContstraint.constant = 0
        for view in stackView.subviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        switch page {
        case .participantInfo:
            isModalInPresentation = true
            
            headingElement.accessibilityLabel = "Participant information sheet"
            
            let shareImage = UIImage(systemName: "square.and.arrow.up")!
            sheetButton.setImage(shareImage, for: .normal)
            sheetButton.accessibilityLabel = "Share"
            sheetButton.accessibilityHint = "Brings up share sheet so you can save this information"
            sheetButtonElement.accessibilityLabel = sheetButton.accessibilityLabel
            sheetButtonElement.accessibilityHint = sheetButton.accessibilityHint
            
            logoView.image = UIImage(named: "City logo")
            
            html = MarkdownParser.html(markdownResource: "ParticipantInformation")
            
            let button = UIButton(type: .system)
            button.setTitle("Continue", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            button.addTarget(self, action: #selector(participantInfoContinueAction), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        case .informedConsent:
            headingElement.accessibilityLabel = "Consent sheet"
            
            let backImage = UIImage(systemName: "xmark.circle")!
            sheetButton.setImage(backImage, for: .normal)
            sheetButton.accessibilityLabel = "Back"
            sheetButton.accessibilityHint = "Returns to Participant Information"
            sheetButtonElement.accessibilityLabel = sheetButton.accessibilityLabel
            sheetButtonElement.accessibilityHint = sheetButton.accessibilityHint
            
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
            
            let nameErrorLabel = UILabel()
            nameErrorLabel.text = "Name is too short"
            nameErrorLabel.textColor = .systemRed
            nameErrorLabel.font = UIFont.systemFont(ofSize: 12)
            nameErrorLabel.isHidden = true
            informedConsentNameErrorLabel = nameErrorLabel
            stackView.addArrangedSubview(nameErrorLabel)
            
            let emailField = UITextField()
            emailField.placeholder = "Enter your email address"
            emailField.accessibilityLabel = "Email address"
            emailField.autocapitalizationType = .none
            emailField.keyboardType = .emailAddress
            emailField.returnKeyType = .done
            emailField.delegate = self
            informedConsentEmailField = emailField
            stackView.addArrangedSubview(emailField)
            
            let emailErrorLabel = UILabel()
            emailErrorLabel.text = "Invalid email address"
            emailErrorLabel.textColor = .systemRed
            emailErrorLabel.font = UIFont.systemFont(ofSize: 12)
            emailErrorLabel.isHidden = true
            informedConsentEmailErrorLabel = emailErrorLabel
            stackView.addArrangedSubview(emailErrorLabel)
            
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
            
            headingElement.accessibilityLabel = "ORBIT instructions sheet"
            
            let closeImage = UIImage(systemName: "xmark.circle")!
            sheetButton.setImage(closeImage, for: .normal)
            sheetButton.accessibilityLabel = "Close"
            sheetButton.accessibilityHint = "Returns you to the Things list screen"
            sheetButtonElement.accessibilityLabel = sheetButton.accessibilityLabel
            sheetButtonElement.accessibilityHint = sheetButton.accessibilityHint
            
            html = MarkdownParser.html(markdownResource: "Introduction")
        }
        
        webView.loadHTMLString(html, baseURL: Bundle.main.resourceURL)
        
        scrollView.setContentOffset(CGPoint.zero, animated: true)
        
        UIAccessibility.post(notification: .screenChanged, argument: accessibilityScreenChangedMessage)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        headingElement = UIAccessibilityElement(accessibilityContainer: view!)
        headingElement.accessibilityTraits = .header
        
        sheetButtonElement = UIAccessibilityElement(accessibilityContainer: view!)
        sheetButtonElement.accessibilityTraits = sheetButton.accessibilityTraits
        
        logoView.image = UIImage(named: "ORBIT logo")
        
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
        
        // First-run
        if page == .participantInfo {
            configurePage(accessibilityScreenChangedMessage: "Welcome to the ORBIT Dataset research project")
        }
        // Not first-run
        else {
            configurePage()
        }
    }
    
    override func viewDidLayoutSubviews() {

        //   Make the dismiss accessibility frame a strip down the RHS edge of the screen
        //   To not mess with the visual UI expected touches, this requires a separate element to mock the button
        let viewFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        let dismissButtonFrame = UIAccessibility.convertToScreenCoordinates(sheetButton.bounds, in: sheetButton)
        sheetButtonElement.accessibilityFrame = CGRect(
            x: dismissButtonFrame.minX,
            y: viewFrame.minY,
            width: viewFrame.maxX - dismissButtonFrame.minX,
            height: viewFrame.height
        )
        sheetButtonElement.accessibilityActivationPoint = CGPoint(x: dismissButtonFrame.midX, y: dismissButtonFrame.midY)
        
        view.accessibilityElements = [
            headingElement!,
            sheetButtonElement!,
            scrollView!
        ]
        
        // iPad: size to be more like full-screen
        preferredContentSize = CGSize(width: UIScreen.main.bounds.width*2/3, height: UIScreen.main.bounds.height)
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
        // Test: does the data detector think it's a link
        guard
            let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
            let matchRange = dataDetector.firstMatch(in: candidate, options: .anchored, range: NSMakeRange(0, candidate.count))
        else { return false }
        
        return matchRange.range.length == candidate.count
    }
}

extension InfoViewController: WKNavigationDelegate {
    /// On page load, set the WebView to be the height of the page
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] (height, error) in
            guard let self = self else { return }
            self.webViewHeightContstraint.constant = height as! CGFloat
            
            // Now content has loaded, reveal. Should have been set to 0 in configurePage.
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.scrollView.alpha = 1
            }
        }
    }
    
    /// On clicking a link, scroll the overall view to the appropriate place (as the webview is sized to be static)
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
    /// On a user checking/unchecking a consent checkbox
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let allConsentsChecked = message.body as? Bool
        {
            informedConsentAllConsentsChecked = allConsentsChecked
        }
    }
}

extension InfoViewController: UITextFieldDelegate {
    /// On return, either go to next or dismiss
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case informedConsentNameField:
            informedConsentEmailField?.becomeFirstResponder()
        case informedConsentEmailField:
            informedConsentEmailField?.resignFirstResponder()
            UIAccessibility.focus(element: informedConsentSubmitButton)
        default:
            break
        }
        return false
    }
    
    /// On the user entering name or email, validate to enable the submit button
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        informedConsentSetValidationUI()
        return true
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        informedConsentSetValidationUI()
    }
}

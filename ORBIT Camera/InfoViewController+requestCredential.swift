//
//  InfoViewController+requestCredential.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 30/04/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import os

extension InfoViewController {
    enum CredentialError: Error {
        case transportError
        case responseError
        case badRequest([String: [String]])
        case forbidden
        case unexpectedResponse
    }
    
    /// Upload the name and email address to hopefully register as a new participant, returning an authorisation credential for that participant
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
            switch result {
            case .success:
                os_log("Request credential success", log: appNetLog)
            case .failure(let error):
                os_log("Request credential %{public}@", log: appNetLog, error.localizedDescription)
            }
            DispatchQueue.main.async {
                self.handleCredentialResult(result)
            }
        }
        task.resume()
        os_log("Request credential sent", log: appNetLog)
    }

    func handleCredentialResult(_ result: Result<String, CredentialError>) {
        switch result {
        case .success(let credential):
            // Save validated credential
            var participant = try! Participant.appParticipant() // FIXME: try!
            participant.authCredential = credential
            try! dbQueue.write { db in try participant.save(db) } // FIXME: try!
            
            // Dismiss this screen, i.e. enter app proper
            //   Accessibility: the things screen doesn't seem to announce itself despire viewDidAppear below, for some unknown reason
            //   So, announce something else here, that won't interfere if that does magically start working
            if let presentingViewController = presentingViewController {
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .announcement, argument: "Consent submission successful. You are now a participant in the ORBIT research project. The app will load shortly")
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(7)) {
                        presentingViewController.dismiss(animated: true) {
                            presentingViewController.viewDidAppear(true)
                        }
                    }
                } else {
                    presentingViewController.dismiss(animated: true) {
                        presentingViewController.viewDidAppear(true)
                    }
                }
            }
        case .failure(let error):
            switch error {
            case .transportError:
                informedConsentErrorLabel?.text = "There was a problem submitting your consent. The ORBIT servers could not be reached. Is this iOS device connected to the internet?\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
            case .responseError:
                informedConsentErrorLabel?.text = "There was a problem submitting your consent. The app received an unexpected response from the ORBIT servers.\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
            case .badRequest(let response):
                var genericMessage = "There was a problem submitting your consent. The ORBIT servers rejected the request.\n"
                for (field, values) in response {
                    let message = values.reduce("") { $0 + $1.replacingOccurrences(of: "this field", with: field)}
                    switch field {
                    case "name":
                        informedConsentNameErrorLabel?.text = message
                    case "email":
                        informedConsentEmailErrorLabel?.text = message
                    default:
                        genericMessage += message + "\n"
                    }
                }
                genericMessage += "\nIf this problem persists, please contact info@orbit.city.ac.uk"
                informedConsentErrorLabel?.text = genericMessage
            case .unexpectedResponse:
                informedConsentErrorLabel?.text = "There was a problem submitting your consent. The app received an unexpected response from the ORBIT servers.\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
            case .forbidden:
                informedConsentErrorLabel?.text = "There was a problem submitting your consent. The app could not authenticate with the ORBIT servers.\n\nIf this problem persists, please contact info@orbit.city.ac.uk"
            }
            scrollView.scrollRectToVisible(stackView.frame, animated: true)
            UIAccessibility.focus(element: informedConsentErrorLabel)
            informedConsentIsSubmitting = false
        }
    }
}

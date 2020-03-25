//
//  InfoViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 10/03/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB
import os

class InfoViewController: UIViewController {

    @IBOutlet weak var unlockCode: UITextField!
    @IBOutlet weak var unlockCodeStatus: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let credential = try! Participant.appParticipant().authCredential { // FIXME: try!
            unlockCode.text = credential
            checkCredential(credential)
        }
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
}

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
        guard
            let participant = try? Participant.appParticipant()
        else {
            return
        }
        unlockCode.text = participant.authCredential
        checkCredential(participant)
    }
    
    
    @IBAction func unlockCodeEditingDidEnd(_ sender: Any) {
        guard
            var participant = try? Participant.appParticipant()
        else {
            return
        }
        
        if let credential = unlockCode.text {
            participant.authCredential = credential
            do { try dbQueue.write { db in try participant.save(db) } }
            catch { os_log("Failed to save participant updated authCredential") }
            
            checkCredential(participant)
        }
    }
    
    enum CredentialError: Error {
        case transportError
        case responseError
        case unexpectedResponse
        case credentialRejected
    }
    
    func checkCredential(_ participant: Participant) {
        // Test the auth credential by hitting an API endpoint
        let url = URL(string: Settings.endpointThing)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
            request.setValue(participant.authCredential, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
            let result: Result<Int, CredentialError>
            if let error = error {
                result = .failure(.transportError)
            } else {
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        result = .success(0) // TODO: return the actual ORBIT participant ID, having hit a participant end-point and decoding the json
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
        unlockCodeStatus.textColor = .darkText
        unlockCodeStatus.text = "Verifying credential..."
    }
    
    func handleCredentialResult(_ result: Result<Int, CredentialError>) {
        switch result {
        case .success:
            unlockCodeStatus.textColor = .systemGreen
            unlockCodeStatus.text = "Code accepted"
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

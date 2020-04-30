//
//  MasterViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB
import os

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil

    /// The label to make the 'add new' thing with, to be set upon some editing action
    @CleanString var candidateLabel: String
    
    /// A test of the adequacy of the 'add new' label.
    enum labelError: Error {
        case blank
        case tooShort
    }
    /// Currently, minimum character count of 2
    func candidateLabelTest() -> Result<String, labelError> {
        if candidateLabel.isEmpty { return .failure(.blank) }
        if candidateLabel.count < 3 { return .failure(.tooShort) }
        return .success(candidateLabel)
    }
    
    /// A string that 'cleans' its value when set
    /// Currently, trimming whitespace
    @propertyWrapper struct CleanString {
        private var label: String
        init() { self.label = "" }
        var wrappedValue: String {
            get { return label }
            set { label = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
    }
    
    /// Current state of thing's videos
    private var things: [Thing] = []
    
    /// Database observer for things changes
    private var thingsObserver: TransactionObserver?
    
    /// Segue to detail, creating the new `Thing`
    // Triggered by 'go' on keyboard only
    // cell in storyboard is wired to trigger segue there
    @IBAction func addNewAction() {
        // Select the cell (`shouldPerform` expects this)
        tableView.selectRow(at: addNewPath, animated: false, scrollPosition: .none)
        
        // Perform segue (or not)
        if shouldPerformSegue(withIdentifier: "showDetail", sender: self) {
            performSegue(withIdentifier: "showDetail", sender: self)
        }
    }
    
    /// The 'cleaned' label is kept updated
    @IBAction func addNewFieldDidEditingChanged(sender: UITextField) {
        candidateLabel = sender.text ?? ""
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set edit button, to delete things or edit their label
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.leftBarButtonItem?.accessibilityHint = "Delete things, or change their name"
        
        // Set detailViewController if already present
        if let splitViewController = splitViewController,
           let detailNavigationController = splitViewController.viewControllers.last as? UINavigationController
        {
            detailViewController = detailNavigationController.topViewController as? DetailViewController
        }
        
        // Register for changes
        let request = Thing
            .all()
            .order(Thing.Columns.id.desc)
        let observation = request.observationForAll()
        thingsObserver = observation.start(
            in: dbQueue,
            onError: { error in
                os_log("MasterViewController observer error")
                print(error)
            },
            onChange: { [weak self] things in
                guard let self = self
                else { return }
                
                if self.tableView.window == nil {
                    self.things = things
                } else {
                    let difference = things.difference(from: self.things)
                    self.tableView.performBatchUpdates({
                        self.things = things
                        for change in difference {
                            switch change {
                            case let .remove(offset, _, _):
                                self.tableView.deleteRows(at: [IndexPath(row: offset, section: ThingSection.things.rawValue)], with: .automatic)
                            case let .insert(offset, _, _):
                                self.tableView.insertRows(at: [IndexPath(row: offset, section: ThingSection.things.rawValue)], with: .automatic)
                                self.tableView.selectRow(at: IndexPath(row: offset, section: ThingSection.things.rawValue), animated: true, scrollPosition: .none)
                            }
                        }
                    }, completion: nil)
                }
            }
        )
        
        // Select the thing set in the detailViewController, if present
        if let detailViewController = detailViewController,
           let thing = detailViewController.detailItem,
           let thingIndex = things.firstIndex(of: thing)
        {
            let path = IndexPath(row: thingIndex, section: ThingSection.things.rawValue)
            tableView.selectRow(at: path, animated: false, scrollPosition: .middle)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        // Clear selection if single-pane, keep selection if side-by-side
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // First-run
        if !Participant.appParticipantGivenConsent() {
            performSegue(withIdentifier: "showInfo", sender: self)
            return
        }
        
        // Announce the screen change
        // Without this, the element nearest the previous screen's focussed element will become focussed.
        UIAccessibility.post(notification: .screenChanged, argument: "Things list screen. Nav bar focussed")
        
        // If there is no thing, prompt the user to create one.
        if tableView.numberOfRows(inSection: ThingSection.things.rawValue) == 0 {
            guard let cell = tableView.cellForRow(at: addNewPath) as? NewThingCell
            else { return }
            cell.labelField.becomeFirstResponder()
        }
    }

    // MARK: - Segues
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            let indexPath = tableView.indexPathForSelectedRow ?? addNewPath
            switch ThingSection(rawValue: indexPath.section)! {
            case .addNew:
                let shouldSegue = candidateLabelTest()
                if let cell = tableView.cellForRow(at: addNewPath) as? NewThingCell {
                    switch shouldSegue {
                    case .success(_):
                        // If we're going ahead, we don't want it still focussed when we unwind back
                        cell.labelField.resignFirstResponder()
                    case .failure(let error):
                        // Accessible UI: Inform the user, but don't change screen state
                        if UIAccessibility.isVoiceOverRunning {
                            switch error {
                            case .blank:
                                UIAccessibility.announce(message: "The textfield is blank. Please enter the name there first", delay: .milliseconds(100))
                            case .tooShort:
                                UIAccessibility.announce(message: "The name in the textfield is too short. Please enter a more descriptive name", delay: .milliseconds(100))
                            }
                        // Visual UI: If the label isn't adequate, set the field to edit
                        } else {
                            cell.labelField.becomeFirstResponder()
                        }
                    }
                    // Any addNew selection should not be kept whether if editing or when we unwind back
                    tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
                }
                switch shouldSegue {
                case .success: return true // ...really no readable way just to get a bool?
                case .failure: return false
                }
            case .things:
                return true
            }
        }
        return true // e.g. info popover segue
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "showDetail":
            let indexPath = tableView.indexPathForSelectedRow ?? addNewPath

            // Create or get thing to detail
            var thing: Thing
            switch ThingSection(rawValue: indexPath.section)! {
                case .addNew:
                    thing = Thing(withLabel: candidateLabel) // candidateLabel verified in `shouldPerformSegue`
                    try! dbQueue.write { db in try thing.save(db) } // FIXME: try!
                    
                    // Clear 'new' cell
                    if let cell = tableView.cellForRow(at: addNewPath) as? NewThingCell {
                        cell.labelField.text = ""
                        candidateLabel = ""
                    }
                case .things:
                    thing = things[indexPath.row]
            }
            
            // Segue to detail
            let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
            controller.detailItem = thing
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
            detailViewController = controller
        case "showInfo":
            let controller = (segue.destination as! InfoViewController)
            controller.page = Participant.appParticipantGivenConsent() ? .appInfo : .participantInfo
        default:
            os_log("Unknown segue")
            assertionFailure()
        }
    }

    /// Allow unwind segues to this view controller
    // This is found by Info Scene's exit doohikey.
    // Note it is *not* used in the nav controller back button segue, which would be mighty convenient to update state.
    // The presence of the method is enough to allow the unwind on the storyboard.
    @IBAction func unwindAction(unwindSegue: UIStoryboardSegue) {}

    // MARK: - Table View
    
    enum ThingSection: Int, CaseIterable {
        case addNew
        case things
    }
    
    let addNewPath = IndexPath(row: 0, section: ThingSection.addNew.rawValue)

    override func numberOfSections(in tableView: UITableView) -> Int {
        return ThingSection.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch ThingSection(rawValue: section)! {
        case .addNew:
            return 1
        case .things:
            return things.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch ThingSection(rawValue: indexPath.section)! {
        case .addNew:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Add new cell", for: indexPath)
            return cell
        case .things:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as? ThingCell
            else { fatalError("Expected a `\(VideoViewCell.self)` but did not receive one.") }
            cell.thing = things[indexPath.row]
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch ThingSection(rawValue: section)! {
        case .addNew:
            return "Add a new thing"
        case .things:
            return "Your things"
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch ThingSection(rawValue: indexPath.section)! {
        case .addNew:
            return false
        case .things:
            return true
        }
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let thing = things[indexPath.row]
            // Stop the detail view displaying it, if so
            if let detailThing = detailViewController?.detailItem,
               detailThing == thing
            {
                detailViewController?.detailItem = nil
            }
            // Remove from database
            _ = try! dbQueue.write { db in try thing.delete(db) } // FIXME: try!
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }


}


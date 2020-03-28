//
//  MasterViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import os

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil

    /// The label to make the 'add new' thing with, to be set upon some editing action
    @CleanString var candidateLabel: String
    
    /// A test of the adequacy of the 'add new' label.
    /// Currently, minimum character count of 2
    func candidateLabelTest() -> Bool {
            candidateLabel.count > 2 // Does it have enough characters?
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
    
    /// Segue to detail, creating the new `Thing`
    // Triggered by 'go' on keyboard only
    // cell in storyboard is wired to trigger segue there
    @IBAction func addNewAction() {
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
        
        // Set detailViewController if already present
        if let splitViewController = splitViewController,
           let detailNavigationController = splitViewController.viewControllers.last as? UINavigationController
        {
            detailViewController = detailNavigationController.topViewController as? DetailViewController
        }
        
        // Select the thing set in the detailViewController, if present
        if let detailViewController = detailViewController,
           let thing = detailViewController.detailItem,
           let thingIndex = try? thing.index()
        {
            let path = IndexPath(row: thingIndex, section: ThingSection.things.rawValue)
            tableView.selectRow(at: path, animated: false, scrollPosition: .middle)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        // If any `thing` cell is selected, the underlying data might have changed.
        if let path = tableView.indexPathForSelectedRow,
            ThingSection(rawValue: path.section) == .things,
            let thing = try? Thing.at(index: path.row),
            let label = tableView.cellForRow(at: path)?.detailTextLabel
        {
            label.text = thing.shortDescription()
        }
        
        // Clear selection if single-pane, keep selection if side-by-side
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
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
                    if shouldSegue {
                        // If we're going ahead, we don't want it still focussed when we unwind back
                        cell.labelField.resignFirstResponder()
                    } else {
                        // If the label isn't adequate, set the field to edit
                        cell.labelField.becomeFirstResponder()
                    }
                    // Any addNew selection should not be kept whether if editing or when we unwind back
                    tableView.selectRow(at: nil, animated: false, scrollPosition: .none)
                }
                return shouldSegue
            case .things:
                return true
            }
        }
        return true // e.g. info popover segue
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let indexPath = tableView.indexPathForSelectedRow ?? addNewPath

            // Create or get thing to detail
            var thing: Thing
            switch ThingSection(rawValue: indexPath.section)! {
                case .addNew:
                    // Clear 'new' cell
                    if let cell = tableView.cellForRow(at: addNewPath) as? NewThingCell {
                        cell.labelField.text = ""
                        candidateLabel = ""
                    }
                    
                    // Insert new thing
                    thing = Thing(withLabel: candidateLabel) // candidateLabel verified in `shouldPerformSegue`
                    try! dbQueue.write { db in try thing.save(db) } // FIXME: try!
                    let indexPath = IndexPath(row: 0, section: ThingSection.things.rawValue)
                    tableView.insertRows(at: [indexPath], with: .automatic)
                    tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                case .things:
                    thing = try! Thing.at(index: indexPath.row) // FIXME: try!
            }
            
            // Segue to detail
            let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
            controller.detailItem = thing
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
            detailViewController = controller
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
            return try! dbQueue.read { db in try Thing.fetchCount(db) } // FIXME: try!
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch ThingSection(rawValue: indexPath.section)! {
        case .addNew:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Add new cell", for: indexPath)
            return cell
        case .things:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            let thing = try! Thing.at(index: indexPath.row) // FIXME: try!
            cell.textLabel!.text = thing.labelParticipant
            cell.detailTextLabel!.text = thing.shortDescription()
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
            let thing = try! Thing.at(index: indexPath.row) // FIXME: try!
            // Stop the detail view displaying it, if so
            if let detailThing = detailViewController?.detailItem,
               detailThing == thing
            {
                detailViewController?.detailItem = nil
            }
            // Remove from database
            _ = try! dbQueue.write { db in try thing.delete(db) } // FIXME: try!
            // Remove from Things UI
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }


}


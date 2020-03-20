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
    // Triggered by 'go' on keyboard, the '+' button
    // FIXME: Not yet triggered by selection, which seems to be possible despite the above
    @IBAction func addNewAction() {
        tableView.selectRow(at: nil, animated: false, scrollPosition: .none) // Or UX-wise, select addNewPath?
        if shouldPerformSegue(withIdentifier: "showDetail", sender: self) {
            performSegue(withIdentifier: "showDetail", sender: self)
        }
    }
    
    /// The 'cleaned' label is kept updated
    @IBAction func addNewFieldDidEditingChanged(sender: UITextField) {
        candidateLabel = sender.text ?? ""
    }

    /// The add new text field's primary action, e.g. what happens when 'go' is pressed on the keyboard
    @IBAction func addNewFieldAction(sender: UITextField) {
        // Stop editing
        sender.resignFirstResponder()
        
        // Go!
        addNewAction()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        navigationItem.leftBarButtonItem = editButtonItem

        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
            
            // If nothing is selected, and we're coming from a detailViewController, make the corresponding selection. This happens on e.g. iPad first-run.
            if let detailViewController = detailViewController,
                let thing = detailViewController.detailItem,
                let thingIndex = try? thing.index(),
                tableView.indexPathForSelectedRow == nil
            {
                let path = IndexPath(row: thingIndex, section: ThingSection.things.rawValue)
                tableView.selectRow(at: path, animated: false, scrollPosition: .middle)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    // MARK: - Segues
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            let indexPath = tableView.indexPathForSelectedRow ?? addNewPath
            switch ThingSection(rawValue: indexPath.section)! {
            case .addNew:
                return candidateLabelTest()
            case .things:
                return true
            }
        }
        return false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let indexPath = tableView.indexPathForSelectedRow ?? addNewPath

            // Create or get thing to detail
            var thing: Thing
            switch ThingSection(rawValue: indexPath.section)! {
                case .addNew:
                    // Clear 'new' cell
                    (tableView
                        .cellForRow(at: addNewPath)?
                        .contentView
                        .subviews
                        .first(where: { $0 is UITextField }) as? UITextField)?
                        .text = ""
                    
                    // Insert new thing
                    thing = Thing(withLabel: candidateLabel) // candidateLabel verified in `shouldPerformSegue`
                    try! dbQueue.write { db in try thing.save(db) } // FIXME: try!
                    tableView.insertRows(at: [IndexPath(row: 0, section: ThingSection.things.rawValue)], with: .automatic)
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

// FIXME: This isn't called, and unwind happens even when commented out!?
//    @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
//        // The presence of the method is enough to allow the unwind on the storyboard.
//        print("reload")
//        tableView.reloadData()
//    }

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
            // FIXME: Use NSLocalizedString pluralization
            switch thing.videosCount {
            case 0:
                cell.detailTextLabel!.text = "No videos"
            case 1:
                cell.detailTextLabel!.text = "1 video"
            default:
                cell.detailTextLabel!.text = "\(thing.videosCount) videos"
            }
            return cell
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
            try! Thing.deleteAt(index: indexPath.row) // FIXME: try!
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }


}


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

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        navigationItem.leftBarButtonItem = editButtonItem

//        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
//        navigationItem.rightBarButtonItem = addButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
            
            // If nothing is selected, and we're coming from a detailViewController, make the corresponding selection. This happens on e.g. iPad first-run.
            if let detailViewController = detailViewController,
                let thing = detailViewController.detailItem,
                let thingIndex = try? thing.index(),
                tableView.indexPathForSelectedRow == nil
            {
                let path = IndexPath(row: thingIndex, section: 0)
                tableView.selectRow(at: path, animated: false, scrollPosition: .middle)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    @objc
    func insertNewObject(_ sender: Any) {
        var thing = Thing(withLabel: "A new thing")
        try! dbQueue.write { db in try thing.save(db) } // FIXME: try!
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let thing = try! Thing.at(index: indexPath.row) // FIXME: try!
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = thing
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
                detailViewController = controller
            }
        }
    }
    
    @IBAction func unwindAction(unwindSegue: UIStoryboardSegue) {
        // The presence of the method is enough to allow the unwind on the storyboard.
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return try! dbQueue.read { db in try Thing.fetchCount(db) } // FIXME: try!
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
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

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
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


//
//  DetailViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import os

class DetailViewController: UIViewController {

    @IBOutlet weak var thingNavigationItem: UINavigationItem!
    @IBOutlet weak var videoCollectionView: UICollectionView!
    @IBOutlet weak var videoPageControl: UIPageControl!
    
    var detailItem: Thing? {
        didSet {
            // Update the view.
            configureView()
        }
    }
    
    /// Update the user interface for the detail item.
    func configureView() {
        guard
            let thing = detailItem
        else {
                os_log("DetailView with no detailItem")
                assertionFailure()
                return
        }
        // Set title for screen
        thingNavigationItem.title = thing.labelParticipant
        
        // FIXME: INEXPLICABLE TOOLING FAILURE: videoCollectionView and videoPageView are nil, despite being hooked up in the storyboard.
        videoCollectionView = view.subviews[0] as! UICollectionView
        videoPageControl = view.subviews[1] as! UIPageControl
        
        // Set number of videos in paging control
        videoPageControl.numberOfPages = thing.videosCount
    }
    
    @IBAction func pageControlAction(sender: UIPageControl) {
        videoCollectionView.scrollToItem(at: IndexPath(row: videoPageControl.currentPage, section: 0), at: .centeredHorizontally, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        configureView()
    }
}

extension DetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard
            let thing = detailItem
        else {
                os_log("DetailView with no detailItem")
                assertionFailure()
                return 0
        }
        return thing.videosCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("collectionView cellForItemAt: \(indexPath)")
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Video Cell", for: indexPath) as! VideoViewCell
        guard
            let thing = detailItem,
            let video = try? thing.videoAt(index: indexPath.row)
        else {
                os_log("DetailView with no detailItem")
                assertionFailure()
                return cell
        }
        cell.videoURL = video.url
        return cell
    }
}

extension DetailViewController: UIScrollViewDelegate {
    /// Utility to determine the path of the most visible item
    // Note UICollectionView.visible cells wasn't proving reliable, possibly as cell is 1px smaller than collection view or somesuch.
    func visiblePath() -> IndexPath? {
        var center = CGPoint(x: videoCollectionView.bounds.midX, y:videoCollectionView.bounds.midY)
        if let path = videoCollectionView.indexPathForItem(at: center) {
            return path
        }
        // fuzzy match, don't return nil between images
        center.x += 50 // a magic number. should be spacing between cells.
        return videoCollectionView.indexPathForItem(at: center)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let indexPath = visiblePath() else { return }
        videoPageControl.currentPage = indexPath.row
    }
}

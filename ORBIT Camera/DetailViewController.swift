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
    
    /// The thing this detail view is to show the detail of
    var detailItem: Thing? {
        didSet {
            // Update the view.
            configureView()
        }
    }
    
    /// The index of the currently selected video of the thing, as per `thing.videoAt(index:)`
    var videoIndex: Int! {
        didSet {
            // Don't animate to new position if the position is being set by direct manipulation
            if !isManuallyScrolling {
                videoCollectionView.scrollToItem(
                    at: IndexPath(row: videoIndex, section: 0),
                    at: .centeredHorizontally,
                    animated: true
                )
            }
            videoPageControl.currentPage = videoIndex
            videoPageControl.accessibilityValue = "video \(videoPageControl.currentPage + 1) of \(videoPageControl.numberOfPages)"
        }
    }
    
    /// Implementation detail: need to be able to differentiate whether scrolling is happening due to direct manipulation or actioned animation
    var isManuallyScrolling = false
    
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
        videoIndex = 0
        videoPageControl.numberOfPages = thing.videosCount
    }
    
    /// Action the video corresponding to page
    @IBAction func pageControlAction(sender: UIPageControl) {
        videoIndex = sender.currentPage
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // On load without MasterViewController instantiated (e.g. iPad), display an item
        if detailItem == nil {
            detailItem = try? dbQueue.read { db in try Thing.fetchOne(db) }
        }
        configureView()
    }
}

extension DetailViewController: UICollectionViewDataSource {
    /// The videoCollectionView should contain all the videos
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
    
    /// The videoCollectionView cells should display the video
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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

extension DetailViewController: UICollectionViewDelegateFlowLayout {
    /// The videoCollectionView cells should fill the view
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return videoCollectionView.bounds.size
    }
}

extension DetailViewController: UIScrollViewDelegate {
    /// Update current video based on user scrolling through direct manipulation
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if isManuallyScrolling {
            // Note `UICollectionView.indexPathsForVisibleItems` wasn't proving reliable
            let center = CGPoint(x: videoCollectionView.bounds.midX, y:videoCollectionView.bounds.midY)
            if let indexPath = videoCollectionView.indexPathForItem(at: center) {
                videoIndex = indexPath.row
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}

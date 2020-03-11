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
            let indexPath = collectionPath(withIndex: videoIndex)
            
            // Update collection
            // Don't animate to new position if the position is being set by direct manipulation
            if !isManuallyScrolling {
                videoCollectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredHorizontally,
                    animated: true
                )
            }
            
            // Update page control
            videoPageControl.currentPage = videoIndex
            switch indexPath.section {
            case CollectionSection.camera.rawValue:
                videoPageControl.accessibilityValue = "Take new video"
            case CollectionSection.videos.rawValue:
                videoPageControl.accessibilityValue = "video \(indexPath.row + 1) of \(collectionView(videoCollectionView, numberOfItemsInSection: CollectionSection.videos.rawValue))"
            default:
                assertionFailure("videoIndex failure")
            }
            
        }
    }
    
    /// The camera object that encapsulates capture new video functionality
    let camera = Camera()
    
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
        self.title = thing.labelParticipant
        
        // FIXME: INEXPLICABLE TOOLING FAILURE: videoCollectionView and videoPageView are nil, despite being hooked up in the storyboard.
        videoCollectionView = view.subviews[0] as! UICollectionView
        videoPageControl = view.subviews[1] as! UIPageControl
        
        // Set number of videos in paging control
        videoIndex = 0
        videoPageControl.numberOfPages = collectionCount()
    }
    
    /// Action the video corresponding to page
    @IBAction func pageControlAction(sender: UIPageControl) {
        videoIndex = sender.currentPage
    }
    
    @IBAction func recordButtonAction(sender: RecordButton) {
        switch sender.recordingState {
        case .active:
            guard let url = try? FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(NSUUID().uuidString)
                .appendingPathExtension("mov")
            else {
                os_log("Could not create URL for recordStart")
                return
            }
            camera.recordStart(to: url)
        case .idle:
            camera.recordStop()
        }
    }
    
    enum CollectionSection: Int, CaseIterable {
        case camera
        case videos
    }
    
    func collectionIndex(withPath path: IndexPath) -> Int {
        var aIndex = 0
        for section in 0..<path.section {
            aIndex += collectionView(videoCollectionView, numberOfItemsInSection: section)
        }
        return aIndex + path.row
    }
    
    func collectionPath(withIndex index: Int) -> IndexPath {
        var rIndex = index
        for section in CollectionSection.allCases {
            if rIndex < collectionView(videoCollectionView, numberOfItemsInSection: section.rawValue) {
                return IndexPath(row: rIndex, section: section.rawValue)
            } else {
                rIndex -= collectionView(videoCollectionView, numberOfItemsInSection: section.rawValue)
            }
        }
        assertionFailure("indexPath error")
        return IndexPath(row: 0, section: 0)
    }
    
    func collectionCount() -> Int {
        CollectionSection.allCases.reduce(0) { result, section in
            result + collectionView(videoCollectionView, numberOfItemsInSection: section.rawValue)
        }
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
    /// The videoCollectionView should contain camera section and video section
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return CollectionSection.allCases.count
    }
    
    /// The videoCollectionView camera section should contain the camera, and the video section contain all the videos
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case CollectionSection.camera.rawValue:
            return 1
        case CollectionSection.videos.rawValue:
            guard
                let thing = detailItem
            else {
                    os_log("DetailView with no detailItem")
                    assertionFailure()
                    return 0
            }
            return thing.videosCount
        default:
            assertionFailure("collectionView numberOfItemsInSection indexPath error")
            return 0
        }
        
    }
    
    /// The videoCollectionView cells should display the video
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case CollectionSection.camera.rawValue:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Camera Cell", for: indexPath) as? CameraCell else {
                fatalError("Expected a `\(CameraCell.self)` but did not receive one.")
            }
            camera.attachPreview(to: cell.previewLayer)
            return cell
        case CollectionSection.videos.rawValue:
            guard
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Video Cell", for: indexPath) as? VideoViewCell
            else {
                fatalError("Expected a `\(VideoViewCell.self)` but did not receive one.")
            }
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
        default:
            assertionFailure("collectionView cellForItemAt indexPath error")
            return UICollectionViewCell()
        }
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
                videoIndex = collectionIndex(withPath: indexPath)
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}

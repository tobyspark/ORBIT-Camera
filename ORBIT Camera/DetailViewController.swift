//
//  DetailViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import AVFoundation
import os

class DetailViewController: UIViewController {

    @IBOutlet weak var thingNavigationItem: UINavigationItem!
    @IBOutlet weak var videoCollectionView: UICollectionView!
    @IBOutlet weak var videoPageControl: UIPageControl!
    @IBOutlet weak var videoLabel: UILabel!
    @IBOutlet weak var cameraControlView: UIView!
    @IBOutlet weak var cameraControlConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordButton: RecordButton!
    @IBOutlet weak var videoRerecordButton: UIButton!
    
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
            guard oldValue != videoIndex else { return}
            let indexPath = collectionPath(withIndex: videoIndex)
            let collectionSection = CollectionSection(rawValue: indexPath.section)!
            
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
            let pageDescription: String
            switch collectionSection {
            case .camera:
                pageDescription = "Add new video to collection"
            case .videos:
                let number = indexPath.row + 1
                let total = collectionView(videoCollectionView, numberOfItemsInSection: CollectionSection.videos.rawValue)
                let kind = try! detailItem!.videoAt(index: indexPath.row)!.kind.description() // FIXME: kinda crazy
                pageDescription = "Video \(number) of \(total): \(kind)"
            }
            videoLabel.text = pageDescription
            videoPageControl.accessibilityValue = pageDescription
            
            // Update camera control
            // Note animation on/off is set by cameraControlVisibility which is set by scrollViewDidScroll
            switch collectionSection {
            case .camera:
                videoRerecordButton.isAccessibilityElement = false
                recordButton.isAccessibilityElement = true
            case .videos:
                videoRerecordButton.isAccessibilityElement = true
                recordButton.isAccessibilityElement = false
            }
        }
    }
    
    /// The 'visibility' of the cameraControlView, where 0 is offscreen and 1 is onscreen
    var cameraControlVisibility: CGFloat = 1 {
        didSet {
            // This animates the control view on, from the bottom of the screen, in sync with the collection view
            cameraControlConstraint.constant = -(1 - cameraControlVisibility)*cameraControlView.frame.size.height
            view.layoutIfNeeded()
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
        //videoPageControl = view.subviews[1] as! UIPageControl
        
        // Set number of videos in paging control
        videoIndex = 0
        videoPageControl.numberOfPages = collectionCount()
        
        // Set delegate for camera, to pass in new recordings
        camera.delegate = self
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
        // Set videoIndex from scroll position, if direct manipulation
        if isManuallyScrolling {
            // Note `UICollectionView.indexPathsForVisibleItems` wasn't proving reliable
            let center = CGPoint(x: videoCollectionView.bounds.midX, y:videoCollectionView.bounds.midY)
            if let indexPath = videoCollectionView.indexPathForItem(at: center) {
                videoIndex = collectionIndex(withPath: indexPath)
            }
        }
        
        // Bring on camera with camera cell scroll
        // Hard-coded assumes camera is first cell and cell is width of collectionView
        cameraControlVisibility = 1 - min(1, scrollView.contentOffset.x / scrollView.frame.width)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}

extension DetailViewController: AVCaptureFileOutputRecordingDelegate {
    /// Act on the video file the camera has just produced: create a Video record, and update the UI.
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard
            let thing = detailItem,
            let thingID = thing.id
        else {
            os_log("DetailView with no detailItem")
            return
        }
        
        // Create Video
        var video = Video(thingID: thingID, url: outputFileURL, kind: .recognition)
        do {
            try dbQueue.write { db in try video.save(db) }
        } catch {
            os_log("Could not save video to database")
        }
        
        // Update UI
        let insertionPath = IndexPath(row: 0, section: CollectionSection.videos.rawValue)
        videoIndex = collectionIndex(withPath: insertionPath)
        videoPageControl.numberOfPages = collectionCount()
        videoCollectionView.insertItems(at: [insertionPath])
    }
}

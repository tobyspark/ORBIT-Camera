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
    @IBOutlet weak var videoPagingView: UIView!
    @IBOutlet weak var videoPageControl: UIPageControl!
    @IBOutlet weak var videoLabel: UILabel!
    
    @IBOutlet weak var videoRecordedIcon: UIImageView!
    @IBOutlet weak var videoRecordedLabel: UILabel!
    @IBOutlet weak var videoRerecordButton: UIButton!
    
    @IBOutlet weak var videoUploadedIcon: UIImageView!
    @IBOutlet weak var videoUploadedLabel: UILabel!
    
    @IBOutlet weak var videoVerifiedIcon: UIImageView!
    @IBOutlet weak var videoVerifiedLabel: UILabel!
    
    @IBOutlet weak var videoPublishedIcon: UIImageView!
    @IBOutlet weak var videoPublishedLabel: UILabel!
    
    @IBOutlet weak var videoDeleteButton: UIButton!
    
    @IBOutlet weak var cameraControlView: UIView!
    @IBOutlet weak var cameraControlYConstraint: NSLayoutConstraint!
    @IBOutlet weak var cameraControlHConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordButton: RecordButton!
    
    /// The thing this detail view is to show the detail of
    var detailItem: Thing? {
        didSet {
            if detailItem == nil {
                os_log("Setting detailItem to no item", type: .debug)
                
                // Show the master view if required
                splitViewController?.preferredDisplayMode = .primaryOverlay
            } else {
                os_log("Setting detailItem to an item", type: .debug)
                
                // Ensure the split view behaviour reverts
                splitViewController?.preferredDisplayMode = .automatic
            }
            
            // Update the view.
            configureView()
        }
    }
    
    /// The selected page, i.e. index of the currently visible videoCollection item.
    /// This is as per `thing.videoAt(index:)`, modified by any 'add new' camera cell.
    var pageIndex: Int = 0 {
        didSet { configurePage() }
    }
    
    /// The page index where the camera to take new videos is placed. Currently the first, but an alternative could be the last
    let addNewPageIndex = 0
    
    /// The page index where just recorded videos are inserted.
    let insertionPageIndex = 1
    
    /// A dynamic set of page indexes where the videos are flagged for re-recording
    var rerecordPageIndexes = IndexSet()
    
    /// All pages that need the camera displayed, i.e. `rerecordPageIndexes` and `addNewPageIndex`
    var cameraPageIndexes: IndexSet {
        rerecordPageIndexes.union(IndexSet(integer: addNewPageIndex))
    }
    
    /// The video index desired at that page index
    func pageVideoIndex(_ pageIndex:Int? = nil) -> Int? {
        let index = pageIndex ?? self.pageIndex
        if index == addNewPageIndex { return nil }
        if index > addNewPageIndex { return index - 1 }
        return index
    }
    
    /// The actual video at that page index
    func pageVideo(_ index: Int? = nil) -> Video? {
        guard
            let thing = detailItem,
            let videoIndex = pageVideoIndex(index)
        else {
            return nil
        }
        return try? thing.video(with: videoIndex)
    }
    
    /// The 'visibility' of the cameraControlView, where 0 is offscreen and 1 is onscreen
    var cameraControlVisibility: CGFloat = 1 {
        didSet {
            // This animates the control view on, from the bottom of the screen, in sync with the collection view
            cameraControlYConstraint.constant = -(1 - cameraControlVisibility)*cameraControlView.frame.size.height
            view.layoutIfNeeded()
        }
    }
    
    /// The camera object that encapsulates capture new video functionality
    let camera = Camera()
    
    /// Implementation detail: need to be able to differentiate whether scrolling is happening due to direct manipulation or actioned animation
    var isManuallyScrolling = false
    
    /// Update the user interface for the detail item.
    func configureView() {
        inexplicableToolingFailureWorkaround()
        
        // Disable view if no thing.
        // Setting accessibility elements complicates this, so most of the work is actually done in configurePage
        self.view.alpha = (detailItem != nil) ? 1.0 : 0.5
        
        // Set title for screen
        self.title = detailItem?.labelParticipant ?? ""
        
        // Set number of videos in paging control
        pageIndex = 0
        videoPageControl.numberOfPages = collectionView(videoCollectionView, numberOfItemsInSection: 0)
    }
    
    /// Update the user interface for the selected page
    func configurePage() {
        inexplicableToolingFailureWorkaround()
        
        let isCameraPage = cameraPageIndexes.contains(pageIndex)
        let video = pageVideo()
        
        // Update collection
        // Don't animate to new position if the position is being set by direct manipulation
        if !isManuallyScrolling {
            videoCollectionView.scrollToItem(
                at: IndexPath(row: pageIndex, section: 0),
                at: .centeredHorizontally,
                animated: true
            )
        }
        
        // Update page control
        videoPageControl.currentPage = pageIndex
        let pageDescription: String
        if pageIndex == addNewPageIndex {
            pageDescription = (pageIndex == addNewPageIndex) ? "Add new video to collection" : "Re-record video"
        } else if let video = video {
            let number = pageVideoIndex()! + 1 // index-based to count-based
            let total = collectionView(videoCollectionView, numberOfItemsInSection: 0) - 1 // take off count of 'add new' items
            let kind = video.kind.description()
            pageDescription = isCameraPage ? "Re-record video \(number) of \(total)" : "Video \(number) of \(total): \(kind)"
        } else {
            os_log("Page is not camera and has no video")
            assertionFailure()
            pageDescription = ""
        }
        videoLabel.text = pageDescription
        videoPageControl.accessibilityValue = pageDescription
        
        // Update statuses
        if let video = video {
            videoRecordedLabel.text = "Recorded on \(Settings.dateFormatter.string(from:video.recorded))"
            videoUploadedIcon.image = video.uploadID == nil ? UIImage(systemName: "arrow.up.circle") : UIImage(systemName: "arrow.up.circle.fill")
            videoUploadedLabel.text = video.uploadID == nil ? "Not yet uploaded" : "Uploaded"
            // TODO: videoVerified
            // TODO: videoPublished
        }
        
        // Set availability of labels and controls
        // The cameraControlView animation on/off is not reflected by VoiceOver, so doing here (the animation on/off is set elsewhere by cameraControlVisibility which is set by scrollViewDidScroll).
        // The controls should be unresponsive when no thing set
        let pageEnable = (detailItem != nil)
        let statusEnable = (pageEnable && !isCameraPage)
        let recordEnable = (pageEnable && isCameraPage)
        let pageElements = [
            videoPageControl
        ]
        let statusElements = [
            videoRerecordButton,
            videoRecordedLabel,
            videoUploadedLabel,
            videoVerifiedLabel,
            videoPublishedLabel,
            videoDeleteButton,
        ]
        let recordElements = [
            recordButton
        ]
        pageElements.forEach { $0?.isAccessibilityElement = pageEnable }
        statusElements.forEach { $0?.isAccessibilityElement = statusEnable }
        recordElements.forEach { $0?.isAccessibilityElement = recordEnable }
        pageElements.forEach { ($0 as? UIControl)?.isEnabled = pageEnable }
        statusElements.forEach { ($0 as? UIControl)?.isEnabled = statusEnable }
        recordElements.forEach { ($0 as? UIControl)?.isEnabled = recordEnable }
    }
    
    /// Action the video corresponding to page
    @IBAction func pageControlAction(sender: UIPageControl) {
        pageIndex = sender.currentPage
    }
    
    /// Action a video recording. This might be a new video, or the re-recording of an existing one.
    @IBAction func recordButtonAction(sender: RecordButton) {
        switch sender.recordingState {
        case .active:
            if rerecordPageIndexes.contains(pageIndex) {
                guard
                    let video = pageVideo()
                else {
                    os_log("Could not get video for re-record recordStart")
                    return
                }
                do {
                    try FileManager.default.removeItem(at: video.url)
                } catch {
                    os_log("Could not delete previous recording to re-record")
                    return
                }
                camera.recordStart(to: video.url)
            } else {
                guard
                    let url = try? FileManager.default
                        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent(NSUUID().uuidString)
                        .appendingPathExtension("mov")
                else {
                    os_log("Could not create URL for recordStart")
                    return
                }
                camera.recordStart(to: url)
            }
        case .idle:
            camera.recordStop()
        }
    }
    
    /// Put a video in a state to re-record
    @IBAction func rerecordButtonAction(sender: UIButton) {
        os_log("DetailViewController.rerecordButtonAction, pageIndex %d", type: .debug, pageIndex)
        rerecordPageIndexes.insert(pageIndex)
        
        // Update UI
        cameraControlVisibility = 1.0
        // DEBUG NOTE
        // reloadItems gets the replacement cell twice.
        // reloadItems done, the collectionView then reloads the adjacent cells.
        // this wouldn't be a problem, but the camera cell
        videoCollectionView.reloadItems(at: [IndexPath(row: pageIndex, section: 0)])
        configurePage()
    }
    
    /// Delete the video
    @IBAction func deleteAction(sender: UIButton) {
        // Are you sure?
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = sender
            popoverController.sourceRect = sender.bounds
        }
        alert.addAction(UIAlertAction(title: "Delete video", style: .destructive, handler: { [weak self] _ in
            guard
               let self = self,
               let thing = self.detailItem,
               let videoIndex = self.pageVideoIndex(),
               let video = try? thing.video(with: videoIndex)
            else {
               os_log("Could not get video to delete")
               return
            }
            // Delete
            try! dbQueue.write { db in // FIXME: try!
               _ = try video.delete(db)
            }
            // Update UI
            self.videoCollectionView.deleteItems(at: [IndexPath(row: self.pageIndex, section: 0)])
            let pageCount = self.collectionView(self.videoCollectionView, numberOfItemsInSection: 0)
            self.videoPageControl.numberOfPages = pageCount
            self.pageIndex = self.pageIndex < pageCount ? self.pageIndex : pageCount - 1
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set delegate for camera, to pass in new recordings
        camera.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Attempt to display an item if none set (e.g. launch on iPad)
        if detailItem == nil {
            os_log("viewWillAppear without detailItem. Attempting load from database.", type: .debug)
            detailItem = try? dbQueue.read { db in try Thing.fetchOne(db) }
        }
        
        configureView()
    }
    
    // Note: I'd have thought `updateViewConstraints` was the override to use, but it doesn't have the required effect here
    override func viewDidLayoutSubviews() {
        // Set height of camera control view
        cameraControlHConstraint.constant = view.bounds.height - view.convert(videoRecordedIcon.bounds, from: videoRecordedIcon).minY
    }
    
    func inexplicableToolingFailureWorkaround() {
        if videoCollectionView == nil {
            os_log("INEXPLICABLE TOOLING FAILURE: videoCollectionView was nil, despite being hooked up in the storyboard.", type: .debug)
            videoCollectionView = view.subviews[0] as! UICollectionView
        }
    }
}

extension DetailViewController: UICollectionViewDataSource {
    /// The videoCollectionView should contain camera section and video section
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    /// The videoCollectionView camera section should contain the camera, and the video section contain all the videos
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        var itemCount = 1 // Camera item
        if let thing = detailItem {
            itemCount += thing.videosCount
        }
        return itemCount
    }
    
    /// The videoCollectionView cells should display the camera and videos
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        os_log("DetailViewController.cellForItemAt entered with page %d", type: .debug, indexPath.row)
        if cameraPageIndexes.contains(indexPath.row) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Camera Cell", for: indexPath)
            guard let view = cell.contentView as? PreviewMetalView else {
                fatalError("Expected a `\(PreviewMetalView.self)` but did not receive one.")
            }
            camera.attachPreview(to: view)
            os_log("DetailViewController.cellForItemAt returning camera cell", type: .debug, indexPath.row)
            return cell
        } else {
            guard
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Video Cell", for: indexPath) as? VideoViewCell
            else {
                fatalError("Expected a `\(VideoViewCell.self)` but did not receive one.")
            }
            guard
                let video = pageVideo(indexPath.row)
            else {
                os_log("No video found")
                assertionFailure()
                return cell
            }
            cell.videoURL = video.url
            os_log("DetailViewController.cellForItemAt returning video cell", type: .debug, indexPath.row)
            return cell
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
        let position = scrollView.contentOffset.x / view.bounds.width
        let leftIndex = position.rounded(.down)
        let rightIndex = position.rounded(.up)
        let transition = position - leftIndex
        
        // Set videoIndex from scroll position, if direct manipulation
        if isManuallyScrolling {
            let newIndex = transition < 0.5 ? Int(leftIndex) : Int(rightIndex)
            if newIndex != pageIndex {
                pageIndex = newIndex
            }
        }
        
        // Bring on camera with scroll around camera cells
        let isLeftCamera = cameraPageIndexes.contains(Int(leftIndex))
        let isRightCamera = cameraPageIndexes.contains(Int(rightIndex))
        cameraControlVisibility = (1 - transition) * (isLeftCamera ? 1.0 : 0.0) + transition * (isRightCamera ? 1.0 : 0.0)
        
        // Only run capture session when a camera cell is visible
        let visiblePageIndexes = IndexSet(videoCollectionView.indexPathsForVisibleItems.map { $0.row })
        if cameraPageIndexes.intersection(visiblePageIndexes).isEmpty {
            camera.stop()
        } else {
            camera.start()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}

extension DetailViewController: CameraProtocol {
    /// Act on the video file the camera has just produced.
    /// If new, create a Video record, and update the UI.
    /// If a replacement, update the re-record state and UI
    func didFinishRecording(to outputFileURL: URL) {
        guard
            let thing = detailItem
        else {
            os_log("DetailView with no detailItem")
            return
        }
        
        if let videoIndex = thing.videoIndex(with: outputFileURL) {
            let videoPageIndex = videoIndex < addNewPageIndex ? videoIndex : videoIndex + 1
            rerecordPageIndexes.remove(videoPageIndex)
            videoCollectionView.reloadItems(at: [IndexPath(row: videoPageIndex, section: 0)])
            configurePage()
            cameraControlVisibility = 0
            os_log("DetailViewController.didFinishRecording has updated video on page %d", type: .debug, videoPageIndex)
        } else {
            guard
                var video = Video(of: thing, url: outputFileURL, kind: .recognition)
            else {
                os_log("Could not create video")
                return
            }
            do {
                try dbQueue.write { db in try video.save(db) }
            } catch {
                os_log("Could not save video to database")
            }
            videoPageControl.numberOfPages = collectionView(videoCollectionView, numberOfItemsInSection: 0)
            videoCollectionView.insertItems(at: [IndexPath(row: insertionPageIndex, section: 0)])
            pageIndex = insertionPageIndex
            os_log("DetailViewController.didFinishRecording has inserted video", type: .debug)
        }
    }
}

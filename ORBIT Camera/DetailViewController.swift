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
            // Update the view.
            configureView()
        }
    }
    
    /// The selected page, i.e. index of the currently visible videoCollection item.
    /// This is as per `thing.videoAt(index:)`, modified by any 'add new' camera cell.
    var pageIndex: Int = 0 {
        didSet {
            guard oldValue != pageIndex else { return}
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
            if isCameraPage {
                pageDescription = "Add new video to collection"
            } else if let video = video {
                let number = pageVideoIndex()! + 1
                let total = collectionView(videoCollectionView, numberOfItemsInSection: 0)
                let kind = video.kind.description()
                pageDescription = "Video \(number) of \(total): \(kind)"
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
            
            // Update camera control
            // Note animation on/off is set by cameraControlVisibility which is set by scrollViewDidScroll
            if isCameraPage {
                videoRerecordButton.isAccessibilityElement = false
                videoRecordedLabel.isAccessibilityElement = false
                videoUploadedLabel.isAccessibilityElement = false
                videoVerifiedLabel.isAccessibilityElement = false
                videoPublishedLabel.isAccessibilityElement = false
                videoDeleteButton.isAccessibilityElement = false
                recordButton.isAccessibilityElement = true
            } else {
                videoRerecordButton.isAccessibilityElement = true
                videoRecordedLabel.isAccessibilityElement = true
                videoUploadedLabel.isAccessibilityElement = true
                videoVerifiedLabel.isAccessibilityElement = true
                videoPublishedLabel.isAccessibilityElement = true
                videoDeleteButton.isAccessibilityElement = true
                recordButton.isAccessibilityElement = false
            }
        }
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
        pageIndex = 0
        videoPageControl.numberOfPages = collectionView(videoCollectionView, numberOfItemsInSection: 0)
        
        // Set delegate for camera, to pass in new recordings
        camera.delegate = self
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
        rerecordPageIndexes.insert(pageIndex)
        
        // Update UI
        cameraControlVisibility = 1.0
        videoCollectionView.reloadItems(at: [IndexPath(row: pageIndex, section: 0)])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // On load without MasterViewController instantiated (e.g. iPad), display an item
        if detailItem == nil {
            detailItem = try? dbQueue.read { db in try Thing.fetchOne(db) }
        }
        configureView()
    }
    
    // Note: I'd have thought `updateViewConstraints` was the override to use, but it doesn't have the required effect here
    override func viewDidLayoutSubviews() {
        // Set height of camera control view
        cameraControlHConstraint.constant = view.bounds.height - videoRecordedIcon.frame.minY
    }
}

extension DetailViewController: UICollectionViewDataSource {
    /// The videoCollectionView should contain camera section and video section
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    /// The videoCollectionView camera section should contain the camera, and the video section contain all the videos
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard
            let thing = detailItem
        else {
                os_log("DetailView with no detailItem")
                assertionFailure()
                return 0
        }
        return thing.videosCount + 1 // Add the 'add new' camera item
    }
    
    /// The videoCollectionView cells should display the camera and videos
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if cameraPageIndexes.contains(indexPath.row) {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Camera Cell", for: indexPath) as? CameraCell else {
                fatalError("Expected a `\(CameraCell.self)` but did not receive one.")
            }
            camera.attachPreview(to: cell.previewLayer)
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
        // Set videoIndex from scroll position, if direct manipulation
        if isManuallyScrolling {
            // Note `UICollectionView.indexPathsForVisibleItems` wasn't proving reliable
            let center = CGPoint(x: videoCollectionView.bounds.midX, y:videoCollectionView.bounds.midY)
            if let indexPath = videoCollectionView.indexPathForItem(at: center) {
                pageIndex = indexPath.row
            }
        }
        
        // Bring on camera with camera cell scroll
        let position = scrollView.contentOffset.x / view.bounds.width
        let leftIndex = position.rounded(.down)
        let rightIndex = position.rounded(.up)
        let transition = position - leftIndex
        let isLeftCamera = cameraPageIndexes.contains(Int(leftIndex))
        let isRightCamera = cameraPageIndexes.contains(Int(rightIndex))
        cameraControlVisibility = (1 - transition) * (isLeftCamera ? 1.0 : 0.0) + transition * (isRightCamera ? 1.0 : 0.0)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}

extension DetailViewController: AVCaptureFileOutputRecordingDelegate {
    /// Act on the video file the camera has just produced.
    /// If new, create a Video record, and update the UI.
    /// If a replacement, update the re-record state and UI
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
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
        }
    }
}

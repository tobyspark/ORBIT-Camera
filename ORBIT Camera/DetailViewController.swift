//
//  DetailViewController.swift
//  ORBIT Camera
//
//  Created by Toby Harris on 25/02/2020.
//  Copyright © 2020 Toby Harris. All rights reserved.
//

import UIKit
import GRDB
import AVFoundation
import os

class DetailViewController: UIViewController {

    @IBOutlet weak var thingNavigationItem: UINavigationItem!
    @IBOutlet weak var videoCollectionView: UICollectionView!
    @IBOutlet weak var addNewPageShortcutButton: UIButton!
    @IBOutlet weak var videoPagingView: UIView!
    @IBOutlet weak var videoPageControl: UIPageControl!
    @IBOutlet weak var videoLabel: UILabel!
    @IBOutlet weak var videoLabelKindButton: UIButton!
    
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
    @IBOutlet weak var recordTypePicker: VideoKindPickerView!
    
    /// The thing this detail view is to show the detail of
    var detailItem: Thing? {
        didSet {
            os_log("Setting detailItem to %{public}s item", type: .debug, detailItem == nil ? "no" : "an")
            
            // Update the view.
            configureView()
            
            // Register for changes
            if let thing = detailItem,
               let thingID = thing.id
            {
                let request = Video
                    .filter(Video.Columns.thingID == thingID)
                    .order(Video.Columns.recorded.asc)
                let observation = request.observationForAll()
                detailItemObserver = observation.start(
                    in: dbQueue,
                    onError: { error in
                        os_log("DetailViewController observer error")
                        print(error)
                    },
                    onChange: { [weak self] videos in
                        guard let self = self
                        else { return }
                        
                        // Video collection view
                        let difference = videos.difference(from: self.videos)
                        self.videoCollectionView.performBatchUpdates({
                            self.videos = videos
                            for change in difference {
                                switch change {
                                case let .remove(offset, _, _):
                                    self.videoCollectionView.deleteItems(at: [IndexPath(row: offset, section: 0)])
                                case let .insert(offset, _, _):
                                    self.videoCollectionView.insertItems(at: [IndexPath(row: offset, section: 0)])
                                }
                            }
                        }, completion: nil)
                        
                        // Page state via video count
                        self.videoPageControl.numberOfPages = self.pagesCount
                        
                        // Page state via page index
                        self.configurePage()
                        
                        // Page state via collection view position
                        self.scrollViewDidScroll(self.videoCollectionView)
                    }
                )
            }
        }
    }
    
    /// Current state of thing's videos
    private var videos: [Video] = []
    
    /// Handle updates to videos
    private var pagesCount: Int {
        get { videos.count + 1 }
    }
    
    /// The selected page, i.e. index of the currently visible videoCollection item.
    private var pageIndex: Int = 0 {
        didSet { configurePage() }
    }
    
    /// The page index where the camera to take new videos is placed. Currently the first, but an alternative could be the last
    private var addNewPageIndex: Int {
        get { pagesCount - 1 }
    }
    
    /// A dynamic set of page indexes where the videos are flagged for re-recording
    private var rerecordPageIndexes = IndexSet()
    
    /// All pages that need the camera displayed, i.e. `rerecordPageIndexes` and `addNewPageIndex`
    private var cameraPageIndexes: IndexSet {
        rerecordPageIndexes.union(IndexSet(integer: addNewPageIndex))
    }
    
    /// The 'visibility' of the cameraControlView, where 0 is offscreen and 1 is onscreen
    private var cameraControlVisibility: CGFloat = 1 {
        didSet {
            // This animates the control view on, from the bottom of the screen, in sync with the collection view
            cameraControlYConstraint.constant = -(1 - cameraControlVisibility)*cameraControlView.frame.size.height
            view.layoutIfNeeded()
        }
    }
    
    /// Database observer for detailItem changes
    private var detailItemObserver: TransactionObserver?
    
    /// The camera object that encapsulates capture new video functionality
    private let camera = Camera()
    
    /// Implementation detail: need to be able to differentiate whether scrolling is happening due to direct manipulation or actioned animation
    private var isManuallyScrolling = false
    
    /// Update the user interface for the detail item.
    private func configureView() {
        inexplicableToolingFailureWorkaround()
        
        // Disable view if no thing.
        // Setting accessibility elements complicates this, so most of the work is actually done in configurePage
        self.view.alpha = (detailItem != nil) ? 1.0 : 0.5
        
        // Set title for screen
        self.title = detailItem?.labelParticipant ?? ""
        
        // Split view special-cases
        if let splitViewController = splitViewController {
            // If there is no thing set, ensure the list of things is displayed, so a thing can be added.
            if detailItem == nil && splitViewController.displayMode == .primaryHidden {
                splitViewController.preferredDisplayMode = .primaryOverlay
            // Otherwise ensure the split view behaviour is as per normal
            } else {
                splitViewController.preferredDisplayMode = .automatic
            }
        }
        
        // Set current page, will trigger configurePage
        pageIndex = 0
        
        // Set camera controls visibility
        cameraControlVisibility = cameraPageIndexes.contains(pageIndex) ? 1 : 0
    }
    
    /// Update the user interface for the selected page
    private func configurePage() {
        inexplicableToolingFailureWorkaround()
        
        let isCameraPage = cameraPageIndexes.contains(pageIndex)
        
        // Update collection
        // Don't animate to new position if the position is being set by direct manipulation
        if !isManuallyScrolling {
            videoCollectionView.scrollToItem(
                at: IndexPath(row: pageIndex, section: 0),
                at: .centeredHorizontally,
                animated: true
            )
        }
        
        // Update add new shortcut button
        UIView.animate(withDuration: 0.3) {
            let hidden = (self.pageIndex == self.addNewPageIndex)
            self.addNewPageShortcutButton.alpha = hidden ? 0 : 1
        }
        
        // Update page control
        videoPageControl.currentPage = pageIndex
        let pageDescription: String
        var kindDescription: String?
        if pageIndex == addNewPageIndex {
            pageDescription = "Add new video to collection"
            recordTypePicker.kind = .train // default
        } else if let video = videos[safe: pageIndex] {
            let number = pageIndex + 1 // index-based to count-based
            let total = videos.count
            if isCameraPage {
                recordTypePicker.kind = video.kind
                pageDescription = "Re-record video \(number) of \(total)"
            } else {
                pageDescription = "Video \(number) of \(total): "
                kindDescription = video.kind.description()
            }
        } else {
            os_log("Page is not camera and has no video")
            assertionFailure()
            pageDescription = ""
        }
        videoLabel.text = pageDescription
        videoPageControl.accessibilityValue = pageDescription
        UIView.performWithoutAnimation { // setTitle animates by default, which is out of keeping with link-in-label aesthetic
            if let kindDescription = kindDescription {
                videoLabelKindButton.setTitle(kindDescription, for: .normal)
                videoLabelKindButton.isHidden = false
            } else {
                videoLabelKindButton.isHidden = true
            }
            videoLabelKindButton.layoutIfNeeded() // will perform with animation without this
        }
        
        
        // Update statuses
        if let video = videos[safe: pageIndex] {
            videoRecordedLabel.text = "Recorded on \(Settings.dateFormatter.string(from:video.recorded))"
            videoUploadedIcon.image = video.orbitID == nil ? UIImage(systemName: "arrow.up.circle") : UIImage(systemName: "arrow.up.circle.fill")
            videoUploadedLabel.text = video.orbitID == nil ? "Not yet uploaded" : "Uploaded"
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
    
    /// Action the addNewPageShortcutButton
    @IBAction func addNewPageShortcutButtonAction(sender: UIButton) {
        os_log("Add new shortcut action", type: .debug)
        camera.start() // Start it now so it has the best chance of running by the time the scroll completes
        pageIndex = addNewPageIndex
    }
    
    /// Action the video corresponding to page
    @IBAction func pageControlAction(sender: UIPageControl) {
        pageIndex = sender.currentPage
    }
    
    @IBAction func videoLabelKindButtonAction(sender: UIButton) {
        guard var video = videos[safe: pageIndex]
        else {
            os_log("videoLabelKindButtonAction with no video for page")
            return
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let videoKindViewController = storyboard.instantiateViewController(identifier: "VideoKindViewController") as VideoKindPickerViewController

        // Style as popover and set anchor
        videoKindViewController.modalPresentationStyle = .popover
        videoKindViewController.popoverPresentationController?.sourceRect = sender.bounds
        videoKindViewController.popoverPresentationController?.sourceView = sender
        
        // VideoKindController overrides adaptive presentation, so here ensures always popover (i.e. and not a form sheet on compact size classes)
        videoKindViewController.popoverPresentationController?.delegate = videoKindViewController
        
        // Handle choice on dismiss
        videoKindViewController.dismissHandler = { kind in
            video.kind = kind
            try! dbQueue.write { db in try video.save(db) } // FIXME: try!
            self.configurePage()
        }
        
        // Present!
        self.present(videoKindViewController, animated: true, completion: nil)
    }

    /// Action a video recording. This might be a new video, or the re-recording of an existing one.
    @IBAction func recordButtonAction(sender: RecordButton) {
        switch sender.recordingState {
        case .active:
            // IF RE-RECORD START
            if rerecordPageIndexes.contains(pageIndex) {
                guard var video = videos[safe: pageIndex]
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
                
                // Update kind from camera controls
                video.kind = recordTypePicker.kind
                try! dbQueue.write { db in try video.save(db) } // FIXME: try!
                
                // Go, configuring completion handler that updates the UI
                let videoPageIndex = pageIndex
                camera.recordStart(to: video.url) { [weak self] in
                    guard let self = self
                    else { return }
                    
                    // Update controller state
                    self.rerecordPageIndexes.remove(videoPageIndex)
                    
                    // Update record
                    video.recorded = Date() // TODO: This needs to trigger a re-upload
                    try! dbQueue.write { db in try video.save(db) }
                    
                    os_log("Record completion handler has updated video on page %d", type: .debug, videoPageIndex)
                }
            // IF NEW VIDEO START
            } else {
                guard let thing = detailItem
                else {
                    os_log("No thing on recordStart")
                    return
                }
                guard let url = try? FileManager.default
                        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent(NSUUID().uuidString)
                        .appendingPathExtension("mov")
                else {
                    os_log("Could not create URL for recordStart")
                    return
                }
                
                // Go, setting completion handler that creates a Video record and updates the UI
                let kind = recordTypePicker.kind
                camera.recordStart(to: url) {
                    // Create a Video record
                    guard var video = Video(of: thing, url: url, kind: kind)
                    else {
                        os_log("Could not create video")
                        return
                    }
                    do {
                        try dbQueue.write { db in try video.save(db) }
                    } catch {
                        os_log("Could not save video to database")
                    }
                    
                    os_log("Record completion handler has inserted video", type: .debug)
                }
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
                let video = self.videos[safe: self.pageIndex]
            else {
                os_log("Could not get video to delete")
                return
            }
            // Delete
            try! dbQueue.write { db in // FIXME: try!
               _ = try video.delete(db)
            }
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Attempt to display an item if none set (e.g. launch on iPad)
        if detailItem == nil {
            os_log("viewWillAppear without detailItem. Attempting load from database.", type: .debug)
            detailItem = try? dbQueue.read { db in try Thing.fetchOne(db) }
        }
        
        configureView()
    }
    
    override func viewWillLayoutSubviews() {
        // Maintain adaptive UIColor systemBackground colour, while making it semi-transparent
        videoPagingView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
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
        return pagesCount
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
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Video Cell", for: indexPath) as? VideoViewCell
            else {
                fatalError("Expected a `\(VideoViewCell.self)` but did not receive one.")
            }
            guard
                let video = videos[safe: indexPath.row]
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
            camera.stopCancellable() // Perform the stop after a period of grace, to avoid stop/starting while scrolling through
        } else {
            camera.start()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}


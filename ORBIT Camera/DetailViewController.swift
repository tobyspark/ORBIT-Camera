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
    @IBOutlet weak var videoPageControl: OrbitPagerView!
    @IBOutlet weak var videoPagingViewYConstraint: NSLayoutConstraint!
    @IBOutlet weak var videoPagingViewWConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var videoStatusView: UIStackView!
    @IBOutlet weak var videoRecordedIcon: UIImageView!
    @IBOutlet weak var videoRecordedLabel: UILabel!
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
    @IBOutlet weak var recordLabel: UILabel!
    @IBOutlet weak var recordNextButton: UIButton!
    

    lazy var pagerElement = AccessibilityElementUsingClosures(accessibilityContainer: view!)

    lazy var detailHeaderElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var recordedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var uploadedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var verifiedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var publishedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var deleteElement = UIAccessibilityElement(accessibilityContainer: view!)

    lazy var cameraHeaderElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var cameraRecordElement = AccessibilityElementUsingClosures(accessibilityContainer: view!)
    lazy var cameraNextElement = AccessibilityElementUsingClosures(accessibilityContainer: view!)
    
    /// The thing this detail view is to show the detail of
    var detailItem: Thing? {
        didSet {
            os_log("Setting detailItem to %{public}s item", log: appUILog, type: .debug, detailItem == nil ? "no" : "an")
            
            // Update the view.
            configureView()
            
            // Register for changes
            if let thing = detailItem,
               let thingID = thing.id
            {
                for (kind, slots) in Settings.videoKindSlots {
                    let request = Video
                        .filter(Video.Columns.thingID == thingID && Video.Columns.kind == kind.rawValue)
                    let observation = request.observationForAll()
                    detailItemObservers[kind] = observation.start(
                        in: dbQueue,
                        onError: { error in
                            os_log("DetailViewController observer error", log: appUILog)
                            print(error)
                        },
                        onChange: { [weak self] videos in
                            guard let self = self
                            else { return }
                            
                            let updatedVideos = videos.reduce(into: Array<Video?>(repeating: nil, count: slots)) {
                                guard $0.indices.contains($1.uiOrder)
                                else {
                                    os_log("Video with UI Order outside of video slot range")
                                    assertionFailure()
                                    return
                                }
                                $0[$1.uiOrder] = $1
                            }

                            // Video collection view
                            self.inexplicableToolingFailureWorkaround()
                            let difference = updatedVideos.difference(from: self.videos[kind]!)
                            self.videoCollectionView.performBatchUpdates({
                                self.videos[kind] = updatedVideos
                                
                                // Update pager, from which the collection view pulls its number of pages etc.
                                self.videoPageControl.categoryPages = self.videoPageControl.categoryPages.map {
                                    $0.name == kind.description
                                        ? ($0.name, self.videos[kind]!.map({ video in video != nil ? OrbitPagerView.PageKind.item : OrbitPagerView.PageKind.empty }))
                                        : $0
                                }
                                
                                // Now update collection view
                                for change in difference {
                                    switch change {
                                    case let .remove(offset, _, _):
                                        let pageIndex = self.videoPageControl.pageIndexFor(category: kind.description, index: offset)!
                                        self.videoCollectionView.reloadItems(at: [IndexPath(row: pageIndex, section: 0)])
                                    case let .insert(offset, _, _):
                                        let pageIndex = self.videoPageControl.pageIndexFor(category: kind.description, index: offset)!
                                        self.videoCollectionView.reloadItems(at: [IndexPath(row: pageIndex, section: 0)])
                                    }
                                }
                            }, completion: { _ in
                                // Page state via page index
                                self.configurePage()
                                
                                // Page state via collection view position
                                self.scrollViewDidScroll(self.videoCollectionView)
                            })
                        }
                    )
                }
            } else {
                detailItemObservers = [:]
            }
        }
    }
    
    /// Current state of thing's videos
    private var videos: [Video.Kind: [Video?]] = Settings.videoKindSlots.reduce(into: [:]) { $0[$1.kind] = Array(repeating: nil, count: $1.slots)}
    
    /// Handle updates to videos
    private var pagesCount: Int {
        get { videoPageControl.pageCount }
    }
    
    /// The selected page, i.e. index of the currently visible videoCollection item.
    private var pageIndex: Int = 0 {
        didSet { configurePage() }
    }
    
    /// The page index where the camera to take new videos is placed. Currently the first, but an alternative could be the last
    private var addNewPageIndexes: IndexSet {
        get { videoPageControl.pageIndexes(of: .empty) }
    }
    
    /// A dynamic set of page indexes where the videos are flagged for re-recording
    private var rerecordPageIndexes = IndexSet()
    
    /// All pages that need the camera displayed, i.e. `rerecordPageIndexes` and `addNewPageIndex`
    private var cameraPageIndexes: IndexSet {
        rerecordPageIndexes.union(addNewPageIndexes)
    }
    
    /// The 'visibility' of the cameraControlView, where 0 is offscreen and 1 is onscreen
    private var cameraControlVisibility: CGFloat = 1 {
        didSet {
            // This animates the control view on, from the bottom of the screen, in sync with the collection view
            cameraControlYConstraint.constant = -(1 - cameraControlVisibility)*cameraControlView.frame.size.height
            view.layoutIfNeeded()
        }
    }
    
    /// A style of page being displayed
    private enum PageStyle {
        case status
        case rerecord
        case addNew
        case disable
    }
    
    /// The style of page being displayed, i.e. video status, video rerecord, add new.
    private var pageStyle: PageStyle {
        if detailItem == nil {
            return .disable
        } else if rerecordPageIndexes.contains(pageIndex) {
            return .rerecord
        } else if addNewPageIndexes.contains(pageIndex) {
            return .addNew
        } else {
            return .status
        }
    }
    
    /// What video kind is this page displaying
    private var pageKind: Video.Kind { videoKind(description: self.videoPageControl.currentCategoryName!) }
    
    /// What video (if any) this page is displaying
    private var pageVideo: Video? { videos[pageKind]![videoPageControl.currentCategoryIndex!] }
    
    /// The index of page within the video kind
    private var pageKindIndex: Int { self.videoPageControl.currentCategoryIndex! }
    
    /// The count of pages for the video kind
    private var pageKindVideoCount: Int { videos[pageKind]!.count }
    
    /// Database observers for detailItem changes
    private var detailItemObservers: [Video.Kind: TransactionObserver] = [:]
    
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
        
        // Record shortcuts buttons work differently for voiceover UI
        addNewPageShortcutButton.isHidden = UIAccessibility.isVoiceOverRunning
        recordNextButton.isHidden = !UIAccessibility.isVoiceOverRunning
        
        // Set title for screen
        self.title = detailItem?.labelParticipant ?? ""
        if let label = detailItem?.labelParticipant {
            thingNavigationItem.accessibilityLabel = "\(label). Collect videos for the thing called \(label)."
        }
        
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
        cameraControlVisibility = [.rerecord, .addNew].contains(pageStyle) ? 1 : 0
    }
    
    /// Update the user interface for the selected page
    private func configurePage() {
        inexplicableToolingFailureWorkaround()
        
        // Update page control
        videoPageControl.pageIndex = pageIndex
        
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
            self.addNewPageShortcutButton.alpha = (self.pageStyle != .addNew && self.videoPageControl.pageIndexForNext(.empty) != nil) ? 1 : 0
        }
        
        // For VO UX, camera is kept up on the page after recording. This is done via the (otherwise vestigial) rerecordPages, and needs to be cleared once moved on.
        if UIAccessibility.isVoiceOverRunning {
            self.rerecordPageIndexes.formIntersection(IndexSet([self.pageIndex]))
        }
        
        // Update video label
        let accessibilityDescription: String
        switch pageStyle {
        case .addNew:
            accessibilityDescription = "To record. \(pageKind.verboseDescription) video \(pageKindIndex + 1) of \(pageKindVideoCount)."
        case .rerecord:
            accessibilityDescription = "Re-record \(pageKind.verboseDescription) video \(pageKindIndex + 1) of \(pageKindVideoCount)"
        case .status:
            assert(pageVideo != nil, "pageVideo should be valid")
            let isNew = pageVideo!.recorded > Date(timeIntervalSinceNow: -5) ? "New! " : ""
            accessibilityDescription = "\(isNew)\(pageKind.verboseDescription) video \(pageKindIndex + 1) of \(pageKindVideoCount). Done."
        case .disable:
            accessibilityDescription = ""
        }
        pagerElement.accessibilityValue = accessibilityDescription
        
        // Update statuses
        if let video = pageVideo
        {
            videoRecordedLabel.text = Settings.dateFormatter.string(from:video.recorded)
            recordedElement.accessibilityLabel = "Video recorded on \(Settings.verboseDateFormatter.string(from:video.recorded))"
            
            videoUploadedIcon.image = video.orbitID == nil ? UIImage(systemName: "arrow.up.circle") : UIImage(systemName: "arrow.up.circle.fill")
            videoUploadedLabel.text = video.orbitID == nil ? "Not yet uploaded" : "Uploaded"
            uploadedElement.accessibilityLabel = "ORBIT dataset status: Video \(videoUploadedLabel.text!)"
            
            switch video.verified {
            case .unvalidated:
                videoVerifiedIcon.image = UIImage(systemName: "checkmark.circle")
            case .rejectInappropriate, .rejectMissingObject, .rejectPII:
                videoVerifiedIcon.image = UIImage(systemName: "x.circle.fill")
            case .clean:
                videoVerifiedIcon.image = UIImage(systemName: "checkmark.circle.fill")
            }
            videoVerifiedLabel.text = video.verified.description
            verifiedElement.accessibilityLabel = "Video \(videoVerifiedLabel.text!)"
            
            switch video.verified {
            case .unvalidated:
                videoPublishedIcon.image = UIImage(systemName: "lock.circle")
                videoPublishedLabel.text = "Not yet published"
            case .rejectInappropriate, .rejectMissingObject, .rejectPII:
                videoPublishedIcon.image = UIImage(systemName: "lock.circle")
                videoPublishedLabel.text = "Re-record to publish"
            case .clean:
                let published: Bool
                if let studyEnd = try! Participant.appParticipant().studyEnd {
                    published = studyEnd < Date(timeIntervalSinceNow: -60*60*24) // comparing a date to a datetime, add a day on to get end of day
                } else {
                    published = false
                }
                videoPublishedIcon.image = published ? UIImage(systemName: "lock.circle.fill") : UIImage(systemName: "lock.circle")
                videoPublishedLabel.text = published ? "Published in dataset" : "Not yet published"
            }
            publishedElement.accessibilityLabel = "Video \(videoPublishedLabel.text!)"
        }
        
        // Update camera
        if let desired = Settings.desiredVideoLength[pageKind]
        {
            recordButton.stopSecs = desired + 5
            recordButton.everySecAfter = Int(desired)
            recordButton.majorSecs = 5
            recordButton.minorSecs = 1
        }
        recordLabel.text = Settings.videoTip[pageKind]
        cameraHeaderElement.accessibilityLabel = Settings.videoTipVerbose[pageKind]!
        
        // Set availability of labels and controls
        // The cameraControlView animation on/off is not reflected by VoiceOver, so doing here (the animation on/off is set elsewhere by cameraControlVisibility which is set by scrollViewDidScroll).
        // The controls should be unresponsive when no thing set
        
        videoRecordedLabel.isEnabled = (pageStyle == .status)
        videoUploadedLabel.isEnabled = (pageStyle == .status)
        videoVerifiedLabel.isEnabled = (pageStyle == .status)
        videoPublishedLabel.isEnabled = (pageStyle == .status)
        videoDeleteButton.isEnabled = (pageStyle == .status)
        
        recordButton.isEnabled = [.rerecord, .addNew].contains(pageStyle)
        recordNextButton.isEnabled = videoPageControl.pageIndexForNext(.empty) != nil
        if recordNextButton.isEnabled { cameraNextElement.accessibilityTraits.remove(.notEnabled) }
        else { cameraNextElement.accessibilityTraits.insert(.notEnabled) }
        
        switch pageStyle {
        case .disable:
            view.accessibilityElements = []
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        case .status:
            view.accessibilityElements = [
                pagerElement,
                detailHeaderElement,
                recordedElement,
                uploadedElement,
                verifiedElement,
                publishedElement,
                deleteElement
            ]
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        case .rerecord:
            view.accessibilityElements = [
                pagerElement,
                cameraHeaderElement,
                cameraRecordElement,
                cameraNextElement
            ]
            // Don't announce or change focus, i.e. attempt to keep as-was coming from record stop, but add back pagerElement etc.
        case .addNew:
            view.accessibilityElements = [
                pagerElement,
                cameraHeaderElement,
                cameraRecordElement,
                cameraNextElement
            ]
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }
    
    func configureAccessibilityElements() {
        pagerElement.accessibilityLabel = "Recording slots"
        pagerElement.accessibilityHint = ""
        pagerElement.accessibilityTraits = super.accessibilityTraits.union([.adjustable, .header])
        pagerElement.incrementClosure = { [weak self] in
            guard let self = self
            else { return }
            guard
                self.videoPageControl.pageRange.contains(self.pageIndex + 1)
            else {
                let quantityProse: String
                switch self.cameraPageIndexes.count {
                case 0: quantityProse = "All slots filled with videos."
                case 1: quantityProse = "One slot to fill with a video."
                default: quantityProse = "\(self.cameraPageIndexes.count) slots to fill."
                }
                UIAccessibility.post(notification: .announcement, argument: "You are at the last slot. \(quantityProse)")
                return
            }
            self.pageIndex += 1
        }
        pagerElement.decrementClosure = { [weak self] in
            guard
                let self = self,
                self.videoPageControl.pageRange.contains(self.pageIndex - 1)
            else {
                UIAccessibility.post(notification: .announcement, argument: "You are at the first slot.")
                return
            }
            self.pageIndex -= 1
        }
        
        detailHeaderElement.accessibilityLabel = "Video Status"
        detailHeaderElement.accessibilityHint = "The following is about the selected video. It is currently being shown on the screen."
        detailHeaderElement.accessibilityTraits = super.accessibilityTraits.union(.header)
        
        recordedElement.accessibilityLabel = "" // Set in configurePage
        
        uploadedElement.accessibilityLabel = "" // Set in configurePage
        
        verifiedElement.accessibilityLabel = "" // Set in configurePage
        
        publishedElement.accessibilityLabel = "" // Set in configurePage
        
        deleteElement.accessibilityLabel = "Delete video"
        deleteElement.accessibilityHint = "Removes this video from the thing's collection"
        deleteElement.accessibilityTraits = super.accessibilityTraits.union(.button)
        
        cameraHeaderElement.accessibilityLabel = "" // Set in configurePage
        cameraHeaderElement.accessibilityHint = "" // Set in configurePage
        cameraHeaderElement.accessibilityTraits = super.accessibilityTraits.union(.header)
        
        cameraRecordElement.accessibilityLabel = "Record"
        cameraRecordElement.accessibilityHint = "Starts recording a video. Action again to stop"
        cameraRecordElement.accessibilityTraits = super.accessibilityTraits.union([.button, .startsMediaSession])
        cameraRecordElement.activateClosure = { [weak self] in
            guard let self = self
            else { return false }
            
            self.recordButton.toggleRecord()
            self.recordButtonAction(sender: self.recordButton)
            
            switch self.recordButton.recordingState {
            case .idle:
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { // Voodoo
                    // Ideally, this would just be...
                    // UIAccessibility.post(notification: .announcement, argument: "Stopped")
                    // ...but .startsMediaSession has somehow now silenced the announcement of the pager label
                    //
                    // At the point of this firing, the focusedElement is still this cameraRecordElement, so we can't test for that.
                    // But the pager value is updated, so here's a hack...
                    UIAccessibility.post(notification: .announcement, argument: "Stopped. " + self.pagerElement.accessibilityLabel! + ". " + self.pagerElement.accessibilityValue!)
                }
            case .active:
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { // Voodoo
                    UIAccessibility.post(notification: .announcement, argument: "Started")
                }
            }
            
            return true
        }
        
        cameraNextElement.accessibilityLabel = "Next recording slot"
        cameraNextElement.accessibilityHint = "Selects the next available recording slot"
        cameraNextElement.accessibilityTraits = super.accessibilityTraits.union([.button, .startsMediaSession])
        cameraNextElement.activateClosure = { [weak self] in
            guard let self = self
            else { return false }
            
            self.addNewPageShortcutButtonAction(sender:self.recordNextButton)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { // Voodoo
                UIAccessibility.post(notification: .announcement, argument: "\(self.pageKind.verboseDescription) video \(self.pageKindIndex + 1) of \(self.pageKindVideoCount).")
            }
            
            return true
        }
    }
    
    func layoutAccessibilityElements() {
        guard let view = view
        else { return }
        
        // For voiceover, extend the touch target to maximise screen coverage for controls
        let viewFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        let videoFrame = UIAccessibility.convertToScreenCoordinates(videoCollectionView.bounds, in: videoCollectionView)
        let pagerFrame = UIAccessibility.convertToScreenCoordinates(videoPagingView.bounds, in: videoPagingView)
        let recordedFrame = UIAccessibility.convertToScreenCoordinates(videoRecordedIcon.bounds, in: videoRecordedIcon)
                            .union(UIAccessibility.convertToScreenCoordinates(videoRecordedLabel.bounds, in: videoRecordedLabel))
        let uploadedFrame = UIAccessibility.convertToScreenCoordinates(videoUploadedIcon.bounds, in: videoUploadedIcon)
        let verifiedFrame = UIAccessibility.convertToScreenCoordinates(videoVerifiedIcon.bounds, in: videoVerifiedIcon)
        let publishedFrame = UIAccessibility.convertToScreenCoordinates(videoPublishedIcon.bounds, in: videoPublishedIcon)
        let deleteFrame = UIAccessibility.convertToScreenCoordinates(videoDeleteButton.bounds, in: videoDeleteButton)
        
        pagerElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: viewFrame.minY,
            width: viewFrame.width,
            height: videoFrame.union(pagerFrame).maxY - viewFrame.minY
        )
        detailHeaderElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: pagerElement.accessibilityFrame.maxY,
            width: viewFrame.width,
            height: deleteFrame.maxY - pagerElement.accessibilityFrame.maxY
        )
        recordedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: recordedFrame.minY,
            width: viewFrame.width,
            height: recordedFrame.height
        )
        uploadedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: uploadedFrame.minY,
            width: viewFrame.width,
            height: uploadedFrame.height
        )
        verifiedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: verifiedFrame.minY,
            width: viewFrame.width,
            height: verifiedFrame.height
        )
        publishedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: publishedFrame.minY,
            width: viewFrame.width,
            height: publishedFrame.height
        )
        deleteElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: deleteFrame.minY,
            width: viewFrame.width,
            height: deleteFrame.height
        )
        deleteElement.accessibilityActivationPoint = CGPoint(x: deleteFrame.midX, y: deleteFrame.midY)
        
        let cameraControlFrame = UIAccessibility.convertToScreenCoordinates(cameraControlView.bounds, in: cameraControlView)
        let recordFrame = UIAccessibility.convertToScreenCoordinates(recordButton.bounds, in: recordButton)
        let recordNextFrame = UIAccessibility.convertToScreenCoordinates(recordNextButton.bounds, in: recordNextButton)
        let midPointX = (recordFrame.maxX + recordNextFrame.minX) / 2
        cameraHeaderElement.accessibilityFrame = cameraControlFrame
        cameraRecordElement.accessibilityFrame = CGRect(
            x: cameraControlFrame.minX,
            y: cameraControlFrame.minY,
            width: midPointX - cameraControlFrame.minX,
            height: cameraControlFrame.height
        )
        cameraNextElement.accessibilityFrame = CGRect(
            x: midPointX,
            y: cameraControlFrame.minY,
            width: cameraControlFrame.maxX - midPointX,
            height: cameraControlFrame.height
        )
    }
    
    /// Action the addNewPageShortcutButton
    @IBAction func addNewPageShortcutButtonAction(sender: UIButton) {
        guard let pageIndexForNext = videoPageControl.pageIndexForNext(.empty)
        else {
            os_log("addNewPageShortcutButtonAction called when no pageIndexForNext(.empty)")
            return
        }
        os_log("Add new shortcut action", log: appUILog, type: .debug)
        // Start it now so it has the best chance of running by the time the scroll completes
        camera.start()
        // Action going to the page, will start the scroll
        pageIndex = pageIndexForNext
    }

    /// Action a video recording. This might be a new video, or the re-recording of an existing one.
    @IBAction func recordButtonAction(sender: RecordButton) {
        switch sender.recordingState {
        case .active:
            switch pageStyle {
            case .rerecord:
                guard var video = pageVideo
                else {
                    os_log("Could not get video for re-record recordStart", log: appUILog)
                    return
                }
                
                // Go, configuring completion handler that updates the UI
                let url = Video.mintRecordURL()
                let videoPageIndex = pageIndex
                camera.recordStart(to: url) {
                    // Update record
                    video.rerecordReset()
                    video.url = url
                    video.recorded = Date()
                    try! dbQueue.write { db in try video.save(db) }
                    
                    os_log("Record completion handler has updated video on page %d", log: appUILog, type: .debug, videoPageIndex)
                }
            case .addNew:
                guard let thing = detailItem
                else {
                    os_log("No thing on recordStart", log: appUILog)
                    return
                }
                
                // Go, setting completion handler that creates a Video record and updates the UI
                let url = Video.mintRecordURL()
                let kind = videoKind(description: videoPageControl.currentCategoryName!)
                camera.recordStart(to: url) {
                    // For VO UX, keep camera active
                    if UIAccessibility.isVoiceOverRunning {
                        self.rerecordPageIndexes.insert(self.pageIndex)
                    }
                    
                    // Create a Video record
                    guard var video = Video(of: thing, url: url, kind: kind, uiOrder: self.pageKindIndex)
                    else {
                        os_log("Could not create video", log: appUILog)
                        return
                    }
                    do {
                        try dbQueue.write { db in try video.save(db) }
                    } catch {
                        os_log("Could not save video to database", log: appUILog)
                    }
                    
                    os_log("Record completion handler has inserted video", log: appUILog, type: .debug)
                }
            default:
                os_log("recordButtonAction on non-camera page", log: appUILog)
                assertionFailure()
            }
            
            // Disable any navigation etc. while recording!
            videoCollectionView.isUserInteractionEnabled = false
            navigationItem.hidesBackButton = true
            view.accessibilityElements = [cameraRecordElement]
            cameraRecordElement.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        case .idle:
            camera.recordStop()
            
            // Allow navigation again
            videoCollectionView.isUserInteractionEnabled = true
            navigationItem.hidesBackButton = false
            layoutAccessibilityElements() // page refresh on database write will set elements
        }
    }
    
    /// Put a video in a state to re-record
    @IBAction func rerecordButtonAction(sender: UIButton) {
        os_log("DetailViewController.rerecordButtonAction, pageIndex %d", log: appUILog, type: .debug, pageIndex)
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
                let video = self.pageVideo
            else {
                os_log("Could not get video to delete", log: appUILog)
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
        
        // Don't monopolise audio with our (silent!) videos, e.g. let music continue to play
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        
        // Initialise videoPageControl's categories
        videoPageControl.categoryPages = Settings.videoKindSlots.map {
            ($0.kind.description, Array(repeating: OrbitPagerView.PageKind.empty, count: $0.slots))
        }
        
        // Set gesture handlers
        videoPageControl.actionNextPage = { [weak self] in
            guard
                let self = self,
                self.pageIndex + 1 < self.pagesCount
            else
                { return }
            self.pageIndex += 1
        }
        videoPageControl.actionPrevPage = { [weak self] in
            guard
                let self = self,
                self.pageIndex > 0
            else
                { return }
            self.pageIndex -= 1
        }
        videoPageControl.actionPage = { [weak self] newPageIndex in
            guard
                let self = self
                // No point bounds checking, as newPageIndex comes from the control that supplies the bounds
            else
                { return }
            self.pageIndex = newPageIndex
        }
        
        configureAccessibilityElements()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Ensure consent screen if no consent (e.g. first launch on iPad)
        if let splitViewController = splitViewController {
            splitViewController.preferredDisplayMode = Participant.appParticipantGivenConsent() ? .automatic : .primaryOverlay
        }
        
        // Attempt to display an item if none set (e.g. launch on iPad)
        if detailItem == nil {
            os_log("viewWillAppear without detailItem. Attempting load from database.", log: appUILog, type: .debug)
            detailItem = try? dbQueue.read { db in try Thing.fetchOne(db) }
        }
        
        addNewPageShortcutButton.layer.cornerRadius = addNewPageShortcutButton.bounds.height/2
        
        configureView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Announce the screen change
        UIAccessibility.post(notification: .screenChanged, argument: "Thing record and review screen. Nav bar focussed")
    }
    
    override func viewWillLayoutSubviews() {
        // Maintain adaptive UIColor systemBackground colour, while making it semi-transparent
        videoPagingView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
    }
    
    // Note: I'd have thought `updateViewConstraints` was the override to use, but it doesn't have the required effect here
    override func viewDidLayoutSubviews() {
        // Layout pager between video and statuses if room. Storyboard defaults it to within video.
        // Plus, if doing this, widen view to screen width to better capture gestures
        let height = videoPagingView.frame.height + 8
        if videoStatusView.frame.minY - videoCollectionView.frame.maxY > height {
            videoPagingViewYConstraint.constant = height // constant is vertical spacing between video bottom and pager bottom
            videoPagingViewWConstraint.isActive = true
        }
        
        // Set height of camera control view to cover from bottom of screen up to status view
        cameraControlHConstraint.constant = view.bounds.height - view.convert(videoStatusView.bounds, from: videoStatusView).minY
        
        // Set initial position of camera control view now height is known
        let visibility = cameraControlVisibility // trigger didSet
        cameraControlVisibility = visibility
        
        // Layout accessibility elements
        layoutAccessibilityElements()
    }
    
    // TODO: Refactor away, pager category should be protocol stringconvertible or somesuch.
    func videoKind(description: String) -> Video.Kind {
        switch description {
        case Video.Kind.train.description:
            return Video.Kind.train
        case Video.Kind.test.description:
            return Video.Kind.test
        case Video.Kind.testPan.description:
            return Video.Kind.testPan
        case Video.Kind.testZoom.description:
            return Video.Kind.testZoom
        default:
            assertionFailure()
            return Video.Kind.train
        }
    }
    
    func inexplicableToolingFailureWorkaround() {
        if videoCollectionView == nil {
            os_log("INEXPLICABLE TOOLING FAILURE: videoCollectionView was nil, despite being hooked up in the storyboard.", log: appUILog, type: .debug)
            videoCollectionView = view.subviews[0] as! UICollectionView
        }
    }
    
    /// Allow unwind segues to this view controller
    // This is found by Help Scene's exit doohikey.
    // The presence of the method is enough to allow the unwind on the storyboard.
    @IBAction func unwindAction(unwindSegue: UIStoryboardSegue) {}
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
        os_log("DetailViewController.cellForItemAt entered with page %d", log: appUILog, type: .debug, indexPath.row)
        if cameraPageIndexes.contains(indexPath.row) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Camera Cell", for: indexPath)
            os_log("DetailViewController.cellForItemAt returning camera cell", log: appUILog, type: .debug, indexPath.row)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Video Cell", for: indexPath)
            os_log("DetailViewController.cellForItemAt returning video cell", log: appUILog, type: .debug, indexPath.row)
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

extension DetailViewController: UICollectionViewDelegate {
    // Set camera preview and video on willDisplay
    // Note this is insufficient for optimal resource usage, as these "visible" cells are present either side of the displayed cell.
    // So the actual start/stop is handled with the more precise information in scrollViewDidScroll (the leftIndex, rightIndex we compute).
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        switch cell.reuseIdentifier {
        case "Camera Cell":
            guard let view = cell.contentView as? PreviewMetalView
            else {
                fatalError("Expected a `\(PreviewMetalView.self)` but did not receive one.")
            }
            camera.attachPreview(to: view)
            // If we've got battery, warm the camera
            if ProcessInfo.processInfo.isLowPowerModeEnabled == false {
                camera.start()
            }
        case "Video Cell":
            guard let videoCell = cell as? VideoViewCell
            else {
                fatalError("Expected a `\(VideoViewCell.self)` but did not receive one.")
            }
            guard
                let (name, index) = videoPageControl.categoryIndex(pageIndex: indexPath.row),
                let video = videos[videoKind(description: name)]![index]
            else {
                os_log("No video found", log: appUILog)
                assertionFailure()
                return
            }
            videoCell.videoURL = video.url
        case .none, .some(_):
            os_log("Could not handle willDisplay cell", log: appUILog)
        }
    }
    
    // Clear camera preview and video on didEndDisplay
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        switch cell.reuseIdentifier {
        case "Camera Cell":
            guard let view = cell.contentView as? PreviewMetalView
            else {
                fatalError("Expected a `\(PreviewMetalView.self)` but did not receive one.")
            }
            camera.detachPreview(from: view)
        case "Video Cell":
            guard let videoCell = cell as? VideoViewCell
            else {
                fatalError("Expected a `\(VideoViewCell.self)` but did not receive one.")
            }
            videoCell.videoURL = nil
        case .none, .some(_):
            os_log("Could not handle willDisplay cell", log: appUILog)
        }
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
        // See note on collectionView willDisplay cell above
        let visiblePageIndexes = IndexSet([Int(leftIndex), Int(rightIndex)])
        if cameraPageIndexes.intersection(visiblePageIndexes).isEmpty {
            camera.stopCancellable() // Perform the stop after a period of grace, to avoid stop/starting while scrolling through
        } else {
            camera.start()
        }
        
        // Only play video when visible
        // See note on collectionView willDisplay cell above
        videoCollectionView.indexPathsForVisibleItems.forEach { indexPath in
            guard let cell = videoCollectionView.cellForItem(at: indexPath) as? VideoViewCell
            else { return }
            if visiblePageIndexes.contains(indexPath.row) {
                cell.play()
            } else {
                cell.pause()
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { isManuallyScrolling = true }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { isManuallyScrolling = false }
}


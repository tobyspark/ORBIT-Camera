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
    
    lazy var kindElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var addNewElement = AccessibilityElementUsingClosures(accessibilityContainer: view!)
    lazy var pagerElement = AccessibilityElementUsingClosures(accessibilityContainer: view!)

    lazy var detailHeaderElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var recordedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var rerecordElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var uploadedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var verifiedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var publishedElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var deleteElement = UIAccessibilityElement(accessibilityContainer: view!)

    lazy var cameraHeaderElement = UIAccessibilityElement(accessibilityContainer: view!)
    lazy var cameraRecordElement = AccessibilityElementUsingClosures(accessibilityContainer: view!)
    
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
                for kind in Video.Kind.allCases {
                    let request = Video
                        .filter(Video.Columns.thingID == thingID && Video.Columns.kind == kind.rawValue)
                        .order(Video.Columns.id.asc)
                    let observation = request.observationForAll()
                    detailItemObservers[kind] = observation.start(
                        in: dbQueue,
                        onError: { error in
                            os_log("DetailViewController observer error")
                            print(error)
                        },
                        onChange: { [weak self] videos in
                            guard let self = self
                            else { return }
                            
                            // Video collection view
                            let difference = videos.difference(from: self.videos[kind]!)
                            self.videoCollectionView.performBatchUpdates({
                                self.videos[kind] = videos
                                
                                // Update pager, from which the collection view pulls its number of pages etc.
                                self.videoPageControl.categoryCounts = Video.Kind.allCases.map({ kind in
                                    (kind.description, self.videos[kind]!.count)
                                })
                                
                                // Now update collection view
                                for change in difference {
                                    switch change {
                                    case let .remove(offset, _, _):
                                        let pageIndex = self.videoPageControl.pageIndexFor(category: kind.description, index: offset)!
                                        self.videoCollectionView.deleteItems(at: [IndexPath(row: pageIndex, section: 0)])
                                    case let .insert(offset, _, _):
                                        let pageIndex = self.videoPageControl.pageIndexFor(category: kind.description, index: offset)!
                                        self.videoCollectionView.insertItems(at: [IndexPath(row: pageIndex, section: 0)])
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
    private var videos: [Video.Kind: [Video]] = Video.Kind.allCases.reduce(into: [:]) { $0[$1] = []}
    
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
        get { videoPageControl.addNewPageIndexes }
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
    private var pageVideo: Video? { videos[pageKind]![safe: videoPageControl.currentCategoryIndex!] }
    
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
        
        // Set title for screen
        self.title = detailItem?.labelParticipant ?? ""
        if let navItem = navigationController?.navigationBar.topItem,
           let label = detailItem?.labelParticipant
        {
            navItem.accessibilityLabel = "\(label). This screen is about the thing you've named \(label). You can add, remove and re-record videos of the thing."
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
            self.addNewPageShortcutButton.alpha = (self.pageStyle == .addNew) ? 0 : 1
        }
        
        // Update video label
        let accessibilityDescription: String
        switch pageStyle {
        case .addNew:
            accessibilityDescription = "Camera selected, adds a new \(pageKind.verboseDescription) video to the collection."
        case .rerecord:
            accessibilityDescription = "Re-record \(pageKind.verboseDescription) video \(pageKindIndex + 1) of \(pageKindVideoCount)"
        case .status:
            assert(pageVideo != nil, "pageVideo should be valid")
            let isNew = pageVideo!.recorded > Date(timeIntervalSinceNow: -5) ? "New! " : ""
            accessibilityDescription = "\(isNew)\(pageKind.verboseDescription) video \(pageKindIndex + 1) of \(pageKindVideoCount) selected."
        case .disable:
            accessibilityDescription = ""
        }
        pagerElement.accessibilityValue = accessibilityDescription
        
        // Update statuses
        if let video = pageVideo
        {
            videoRecordedLabel.text = "Recorded on \(Settings.dateFormatter.string(from:video.recorded))"
            recordedElement.accessibilityLabel = "Recorded on \(Settings.verboseDateFormatter.string(from:video.recorded))"
            
            videoUploadedIcon.image = video.orbitID == nil ? UIImage(systemName: "arrow.up.circle") : UIImage(systemName: "arrow.up.circle.fill")
            videoUploadedLabel.text = video.orbitID == nil ? "Not yet uploaded" : "Uploaded"
            uploadedElement.accessibilityLabel = "ORBIT dataset status: \(videoUploadedLabel.text!)"
            
            // TODO: videoVerified
            verifiedElement.accessibilityLabel = "\(videoVerifiedLabel.text!)"
            
            // TODO: videoPublished
            publishedElement.accessibilityLabel = "\(videoPublishedLabel.text!)"
        }
        
        // Set availability of labels and controls
        // The cameraControlView animation on/off is not reflected by VoiceOver, so doing here (the animation on/off is set elsewhere by cameraControlVisibility which is set by scrollViewDidScroll).
        // The controls should be unresponsive when no thing set
        
        videoRerecordButton.isEnabled = (pageStyle == .status)
        videoRecordedLabel.isEnabled = (pageStyle == .status)
        videoUploadedLabel.isEnabled = (pageStyle == .status)
        videoVerifiedLabel.isEnabled = (pageStyle == .status)
        videoPublishedLabel.isEnabled = (pageStyle == .status)
        videoDeleteButton.isEnabled = (pageStyle == .status)
        
        recordButton.isEnabled = [.rerecord, .addNew].contains(pageStyle)
        
        switch pageStyle {
        case .disable:
            view.accessibilityElements = []
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        case .status:
            view.accessibilityElements = [
                kindElement,
                addNewElement,
                pagerElement,
                detailHeaderElement,
                recordedElement,
                rerecordElement,
                uploadedElement,
                verifiedElement,
                publishedElement,
                deleteElement
            ]
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        case .rerecord:
            view.accessibilityElements = [
                kindElement,
                pagerElement,
                addNewElement,
                cameraHeaderElement,
                cameraRecordElement
            ]
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        case .addNew:
            view.accessibilityElements = [
                kindElement,
                addNewElement
                // Accessibility flow is different. Actioning add new sets the camera elements.
            ]
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }
    
    func configureAccessibilityElements() {
        // Kind element mocks a UISegmentedControl
        kindElement.isAccessibilityElement = false
        kindElement.accessibilityElements = Video.Kind.allCases.map { kind in
            let segment = AccessibilityElementUsingClosures(accessibilityContainer: kindElement)
            segment.accessibilityLabel = kind.description
            segment.accessibilityHint = "Activate to add \(kind.verboseDescription) videos, or review ones you have already taken."
            segment.accessibilityTraits = super.accessibilityTraits.union(.button)
            segment.activateClosure = { [weak self] in
                guard let self = self
                else { return false }
                
                let prefix = "Selected. "
                (self.kindElement.accessibilityElements! as! [UIAccessibilityElement])
                    .filter { $0.accessibilityLabel!.hasPrefix(prefix) }
                    .forEach { $0.accessibilityLabel = String($0.accessibilityLabel!.dropFirst(prefix.count)) }
                segment.accessibilityLabel = prefix + segment.accessibilityLabel!
                self.pageIndex = self.videoPageControl.pageIndexFor(category: kind.description, index: 0)!
                return true
            }
            return segment
        }
        addNewElement.accessibilityLabel = "Add new video"
        addNewElement.accessibilityHint = "Brings up the camera controls"
        addNewElement.accessibilityTraits = super.accessibilityTraits.union(.button)
        addNewElement.activateClosure = { [weak self] in
            guard let self = self
            else { return false }
            // Action even when UIButton is hidden
            self.addNewPageShortcutButtonAction(sender: self.addNewPageShortcutButton)
            return true
        }
        pagerElement.accessibilityLabel = "Video review selector"
        pagerElement.accessibilityHint = "Adjust to change the video detailed below"
        pagerElement.accessibilityTraits = super.accessibilityTraits.union([.adjustable, .header])
        pagerElement.incrementClosure = { [weak self] in
            guard
                let self = self,
                self.pageIndex + 1 < self.videoPageControl.pageIndexForCurrentAddNew!
            else
                { return }
            self.pageIndex += 1
        }
        pagerElement.decrementClosure = { [weak self] in
            guard
                let self = self,
                self.pageIndex > self.videoPageControl.pageIndexFor(category: self.videoPageControl.currentCategoryName!, index: 0)!
            else
                { return }
            self.pageIndex -= 1
        }
        
        detailHeaderElement.accessibilityLabel = "Video review detail"
        detailHeaderElement.accessibilityHint = "The following relates to the selected video"
        detailHeaderElement.accessibilityTraits = super.accessibilityTraits.union(.header)
        
        recordedElement.accessibilityLabel = "" // Set in configurePage
        
        rerecordElement.accessibilityLabel = "Re-record video" // Set in configurePage
        rerecordElement.accessibilityHint = "If you wish to re-record, activate to bring up the camera controls"
        rerecordElement.accessibilityTraits = super.accessibilityTraits.union(.button)
                
        uploadedElement.accessibilityLabel = "" // Set in configurePage
        
        verifiedElement.accessibilityLabel = "" // Set in configurePage
        
        publishedElement.accessibilityLabel = "" // Set in configurePage
        
        deleteElement.accessibilityLabel = "Delete video"
        deleteElement.accessibilityHint = "Removes this video from the thing's collection"
        deleteElement.accessibilityTraits = super.accessibilityTraits.union(.button)
        
        cameraHeaderElement.accessibilityLabel = "Camera controls"
        cameraHeaderElement.accessibilityHint = "The camera controls are now active"
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
    }
    
    func layoutAccessibilityElements() {
        guard let view = view
        else { return }
        
        // For voiceover, extend the touch target to maximise screen coverage for controls
        let viewFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        let videoFrame = UIAccessibility.convertToScreenCoordinates(videoCollectionView.bounds, in: videoCollectionView)
        let addNewFrame = UIAccessibility.convertToScreenCoordinates(addNewPageShortcutButton.bounds, in: addNewPageShortcutButton)
        let pagerFrame = UIAccessibility.convertToScreenCoordinates(videoPagingView.bounds, in: videoPagingView)
        let recordedFrame = UIAccessibility.convertToScreenCoordinates(videoRecordedIcon.bounds, in: videoRecordedIcon)
                            .union(UIAccessibility.convertToScreenCoordinates(videoRecordedLabel.bounds, in: videoRecordedLabel))
        let uploadedFrame = UIAccessibility.convertToScreenCoordinates(videoUploadedIcon.bounds, in: videoUploadedIcon)
        let verifiedFrame = UIAccessibility.convertToScreenCoordinates(videoVerifiedIcon.bounds, in: videoVerifiedIcon)
        let publishedFrame = UIAccessibility.convertToScreenCoordinates(videoPublishedIcon.bounds, in: videoPublishedIcon)
        let deleteFrame = UIAccessibility.convertToScreenCoordinates(videoDeleteButton.bounds, in: videoDeleteButton)
        
        let viewWidthLessAddNew = addNewFrame.minX - viewFrame.minX
        let segmentWidth = viewWidthLessAddNew / CGFloat(kindElement.accessibilityElements!.count)
        
        // A strip running down the RHS of the screen, for physical findability
        addNewElement.accessibilityFrame = CGRect(
            x: addNewFrame.minX,
            y: videoFrame.minY,
            width: viewFrame.maxX - addNewFrame.minX,
            height: viewFrame.maxY - videoFrame.minY
        )
        // Other controls are arranged in a stack from left hand side to the addNew strip
        kindElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: videoFrame.minY,
            width: viewWidthLessAddNew,
            height: pagerFrame.minY - videoFrame.minY
        )
        for (index, segment) in (kindElement.accessibilityElements! as! [UIAccessibilityElement]).enumerated() {
            segment.accessibilityFrame = CGRect(
                x: kindElement.accessibilityFrame.minX + CGFloat(index)*segmentWidth,
                y: kindElement.accessibilityFrame.minY,
                width: segmentWidth,
                height: kindElement.accessibilityFrame.height
            )
        }
        pagerElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: pagerFrame.minY,
            width: viewWidthLessAddNew,
            height: videoFrame.union(pagerFrame).maxY - pagerFrame.minY
        )
        detailHeaderElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: pagerElement.accessibilityFrame.maxY,
            width: viewWidthLessAddNew,
            height: deleteFrame.maxY - pagerElement.accessibilityFrame.maxY
        )
        recordedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: recordedFrame.minY,
            width: recordedFrame.maxX - viewFrame.minX,
            height: recordedFrame.height
        )
        rerecordElement.accessibilityFrame = CGRect(
            x: recordedFrame.maxX,
            y: recordedFrame.minY,
            width: addNewFrame.minX - recordedFrame.maxX,
            height: recordedFrame.height
        )
        uploadedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: uploadedFrame.minY,
            width: viewWidthLessAddNew,
            height: uploadedFrame.height
        )
        verifiedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: verifiedFrame.minY,
            width: viewWidthLessAddNew,
            height: verifiedFrame.height
        )
        publishedElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: publishedFrame.minY,
            width: viewWidthLessAddNew,
            height: publishedFrame.height
        )
        deleteElement.accessibilityFrame = CGRect(
            x: viewFrame.minX,
            y: deleteFrame.minY,
            width: viewWidthLessAddNew,
            height: deleteFrame.height
        )
        
        
        let cameraControlFrame = UIAccessibility.convertToScreenCoordinates(cameraControlView.bounds, in: cameraControlView)
        
        cameraHeaderElement.accessibilityFrame = cameraControlFrame
        cameraRecordElement.accessibilityFrame = cameraControlFrame
        
        let videoRerecordButtonFrame = UIAccessibility.convertToScreenCoordinates(videoRerecordButton.bounds, in: videoRerecordButton)
        let videoDeleteButtonFrame = UIAccessibility.convertToScreenCoordinates(videoDeleteButton.bounds, in: videoDeleteButton)
        
        rerecordElement.accessibilityActivationPoint = CGPoint(x: videoRerecordButtonFrame.midX, y: videoRerecordButtonFrame.midY)
        deleteElement.accessibilityActivationPoint = CGPoint(x: videoDeleteButtonFrame.midX, y: videoDeleteButtonFrame.midY)
    }
    
    /// Action the addNewPageShortcutButton
    @IBAction func addNewPageShortcutButtonAction(sender: UIButton) {
        os_log("Add new shortcut action", type: .debug)
        // Start it now so it has the best chance of running by the time the scroll completes
        camera.start()
        // Action going to the page, will start the scroll
        pageIndex = videoPageControl.pageIndexForCurrentAddNew!
        // Accessibility steps through this button to bring up the camera controls
        view.accessibilityElements = [
            kindElement,
            cameraHeaderElement,
            cameraRecordElement
        ]
        UIAccessibility.focus(element: cameraHeaderElement)
    }

    /// Action a video recording. This might be a new video, or the re-recording of an existing one.
    @IBAction func recordButtonAction(sender: RecordButton) {
        switch sender.recordingState {
        case .active:
            switch pageStyle {
            case .rerecord:
                guard var video = pageVideo
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
            case .addNew:
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
                let kind = videoKind(description: videoPageControl.currentCategoryName!)
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
            default:
                os_log("recordButtonAction on non-camera page")
                assertionFailure()
            }
            
            // Disable any navigation etc. while recording!
            videoCollectionView.isUserInteractionEnabled = false
            navigationItem.hidesBackButton = true
            accessibilityElements = [cameraRecordElement]
            cameraRecordElement.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(view.bounds, in: view)
        case .idle:
            camera.recordStop()
            
            // Allow navigation again
            videoCollectionView.isUserInteractionEnabled = true
            navigationItem.hidesBackButton = false
            accessibilityElements = [pagerElement] // page refresh on database write will deal with this properly
            layoutAccessibilityElements()
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
                let video = self.pageVideo
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
        
        // Don't monopolise audio with our (silent!) videos, e.g. let music continue to play
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        
        // Set categories to enable addNew pages
        videoPageControl.categoryCounts = Video.Kind.allCases.map { ($0.description, 0) }
        
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

        configureAccessibilityElements()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Attempt to display an item if none set (e.g. launch on iPad)
        if detailItem == nil {
            os_log("viewWillAppear without detailItem. Attempting load from database.", type: .debug)
            detailItem = try? dbQueue.read { db in try Thing.fetchOne(db) }
        }
        
        addNewPageShortcutButton.layer.cornerRadius = addNewPageShortcutButton.bounds.height/2
        
        configureView()
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
                let (name, index) = videoPageControl.categoryIndex(pageIndex: indexPath.row),
                let video = videos[videoKind(description: name)]![safe: index]
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


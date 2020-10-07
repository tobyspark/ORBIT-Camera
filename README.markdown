# ORBIT Camera

An iOS app used by blind and low-vision people to collect videos for the ORBIT dataset project. The client for [ORBIT Data](https://github.com/tobyspark/orbit_data) server.

Developed by Toby Harris – https://tobyz.net  
For ORBIT Object Recognition for Blind Image Training – https://orbit.city.ac.uk  
At City, University of London – https://hcid.city https://www.city.ac.uk  
Funded by Microsoft AI for Accessibility – https://www.microsoft.com/en-us/research/blog/wheres-my-stuff-developing-ai-with-help-from-people-who-are-blind-or-low-vision-to-meet-their-needs/  

![ORBIT Camera v1.0](Documentation/ORBIT Camera - Available.jpg)

## A quick tour

### First-run
On first-run, the user gives research project consent. This is a two-page modal screen, first with the ethics committee approved participant information, then the consent form. The participant information page has a share button, which will produce a HTML file. This provides an appropriate and accessible equivalent to providing a physical copy of a participant info hand-out.

On providing consent, the server creates the participant record and supplies credentials that the app will then use to further access the API endpoints. The app does not have any record of which participant ID it represents, it only has a set of credentials. The server identifies the app instance by these credentials, internally assigning the participant from them.

`InfoViewController.swift`, with content from `ParticipantInformation.markdown` and `InformedConsent.markdown`

### Things list screen
The app follows the Master-Detail pattern. The Master screen lists all the `Things` the user has added. A thing is something that is important to the user, that they would like a future AI to be able to recognise. Things are created with a user-supplied label.

`MasterViewController.swift`
`Thing.swift`

Plus an app/project information screen.

`InfoViewController.swift`, with content from `Introduction.markdown`

### Thing record and review screen
This is the detail screen, of the thing-centric Master-Detail pattern. The aim of the app is to record videos of a thing, following a certain filming procedure. Visually, this screen presents a carousel of videos organised into the different categories of procedure. For each category, there are the videos already taken, plus a live-camera view as the last entry to add a new video. Information and options relating to the video selected in the carousel appear below, with a camera control overlay when appropriate.

The voiceover experience has a different structure. Here, the user first selects the procedure category, within which they can add a new video to that category or review existing videos for that category.

`DetailViewController.swift`
`Video.swift`

Plus a filming instructions screen.

`HelpViewController.swift`, with content from `Recording.markdown`

### ORBIT Data API Endpoints
Endpoints are set in `settings.swift`. The API access credentials the app ships with are set in `Settings+secrets.swift`, which as far as `Git` is concerned, should only have an `xxx` value. See note about relevant git command there.

The app requests credentials using a synchronous connection; the device must be online for consent to be granted.
`InfoViewController+requestCredential.swift`

Upload of `Things` and `Videos` are managed by an autonomous part of the app that tracks database state and connectivity. It will keep up trying to upload until they are done.
`AppUploader.swift`

Things are created using a syncronous connection, this is just a small JSON request with the participant supplied label and JSON response with the server ID of the freshly created record. Videos will only be uploaded once that server record has been obtained. Given the potential of 1GB+ of upload required in total, videos are uploaded in the background. Typically iOS will wait until the phone has power and Wi-Fi to upload. Once given to the iOS system they are mostly managed by the system from there. The app can be suspended and uploads will continue, the only thing that will cancel this is a force-quit of the app. At which point, the app should detect the upload failure and re-submit those videos.
`AppNetwork.swift`
`Uploadable.swift`
`Thing+upload.swift`
`Video+upload.swift`

On coming into the foreground, the app checks study dates and video statuses from the server using a synchronous connection
`Participant+ServerStatus.swift`
`Video+ServerStatus.swift`

### UI Notes

For voiceover, the touch targets of the UI elements were often inadequate. The clearest example of this is the close button of the first-run / app info / help screen. As there is long-form text on this screen, swiping left and right to get to this control was impractical, and the button was hard to find partly because it's small and top-right, and partly of being swamped by this content. So the accessible experience was re-jigged to have this close control be a strip along the right-hand-side edge. Another clear example is the camera's start/stop button accessible touch target extends to the screen edges. This means that most screens actually have an entirely bespoke accessiblity layer. A starting point would be `viewDidLayoutSubviews` in `InfoViewController.swift`.

More gratuitously, the slick UX of the carousel took some coding. It features multiple camera viewfinders, which meant a lower-level approach than `AVCaptureVideoPreviewLayer` was required. Start at `attachPreview` in `Camera.swift`. The pager having categories meant `UIPageControl` was inadequate, requiring a custom `UIControl`. See `OrbitPagerView.swift`. 

## Informational content

The non-UI text such as introduction prose is parsed into the app from markdown files in the `Resources` folder of this repository.

### Linking to headers
Links within a document work. Use the markdown link format, with the slugified heading text as fragment identifier. What's a slug? It's the URL-friendly form, i.e. with dashes instead of spaces, lowercase, etc. What's the fragment identifier? It's the part of the URL after the page in the form `#xxx`.
i.e. at the time of writing, one document has the link `[Training videos for small/medium things](#training-videos-for-smallmedium-things)` which links to `#### Training videos for small/medium things`. To be clear, the number of hashes in the markdown heading is irrelevant, you'll always use one hash in the link.

### Consent form
The consent markdown file has the introductory prose preceded by the consent items as metadata key:value pairs. These will be rendered into a list of checkbox items. Keys are not displayed but are used for sorting (i.e. dispay is not set by order in metadata). No markdown parsing on the text to display.

### Charity choice
The charity choice markdown file has the introductory prose preceded by the database and presentation values as metadata key:value pairs. The key (left hand side) must be five characters or less with no spaces, and is what you will see in the `participant` CSV export. The value (right hand side) is what is displayed in the picker.

## Known issues
- Thing labels cannot be edited #12
- Thing list editing not accessible, i.e. can't delete via voiceover. #19
- Voiceover rotor headings etc. don’t work in embedded web views #37

## Not yet implemented
- Server state changes reflected in app, e.g. video statuses for verified, notifications
- Study phases implemented in app
- Contrast effect and control for viewfinder / videos

## Version history

v1.1.1
- Thing list screen font size and dark mode fixes

v1.1.0
- Verified and published statuses are displayed (requires ORBIT Data v1.1)
- Once uploaded, the video files are cached rather than stored (i.e. not part of iCloud backup, will be culled by the system on low storage)
- A placeholder video (orbit cup) will show if a cached video file has been culled by the system
- Redesigned Things list screen video counts display
- Informational content updates
- PR: [Feature: Move video file to purgeable storage once uploaded](https://github.com/tobyspark/ORBIT-Camera/pull/42)
- PR: [Feature: Thing screen verified + published status updates from server](https://github.com/tobyspark/ORBIT-Camera/pull/41)

v1.0.3
- Consent form as-you-type validation labels

v1.0.2
- iPad first-run tweak
- Robustness pass

v0.6.3
- Prerelease polish
- PR: [Tweaks: Prerelease polish](https://github.com/tobyspark/ORBIT-Camera/pull/38)

v0.6.2
- Uploading fixes
- Informational content updates
- PR: [Fixes: Uploading](https://github.com/tobyspark/ORBIT-Camera/pull/36)

v0.6.1
- Informational content restructure, recording pips, various tweaks
- PR: [Tweaks: Informational content restructure, Recording pips](https://github.com/tobyspark/ORBIT-Camera/pull/35)

v0.6.0
- First-run: participant info → consent w/email address → app unlocks
- Consent requests server participant record → further API use authenticated as that participant
- PR: [Feature: First-run](https://github.com/tobyspark/ORBIT-Camera/pull/33)

v0.5.7
- Markdown updated by ORBIT Team
- Unlock UI stripped out

v0.5.6
- Info sheet features info and tutorial text, parsed from bundled markdown file
- Things detail scene features help scene with tutorial text
- PR: [Feature: Introduction, tutorial text](https://github.com/tobyspark/ORBIT-Camera/pull/31)

v0.5.4
- Thing scene has video-kind centric UX
- PR: [Feature: Thing scene has video kind centric UX](https://github.com/tobyspark/ORBIT-Camera/pull/29)

v0.5.3
- Improved Thing screen accessibility structure and messaging
- PR: [Tweak: Accessibility](https://github.com/tobyspark/ORBIT-Camera/pull/27)

v0.5.2
- Things list breaks out counts of video types
- Various fixes
- PR [Tweak: General](https://github.com/tobyspark/ORBIT-Camera/pull/18)

v0.5.1
- Tweaks to Things scene accessibility experience
- Complete overhaul of Thing scene accessibility experience
- PR [Tweak: Voiceover UX](https://github.com/tobyspark/ORBIT-Camera/pull/17)

v0.5.0
- Uploads in the background
- PR [Feature: Background uploader](https://github.com/tobyspark/ORBIT-Camera/pull/16)
- PR [Refactor: Use database observers](https://github.com/tobyspark/ORBIT-Camera/pull/15)
- PR [Refactor: Camera](https://github.com/tobyspark/ORBIT-Camera/pull/11)

v0.4.2
- Fixes to camera at end, videos newest last.

v0.4.1
- Thing scene adds new videos at end
- PR [Tweak: Thing scene adds new at end](https://github.com/tobyspark/ORBIT-Camera/pull/10)

v0.4.0
- _Important: incompatible database changes, delete any previous installation on your device._
- Videos are classified as training or testing
- Add new video shortcut button when viewing videos
- PR [Feature: Video kind](https://github.com/tobyspark/ORBIT-Camera/pull/6)
- PR [Feature: Shortcut button to add new page](https://github.com/tobyspark/ORBIT-Camera/pull/9)

v0.3.2
- Minor UX and UI fixes
- PR [UI issues around Master-Detail interaction](https://github.com/tobyspark/ORBIT-Camera/pull/4)

v0.3.1
- No blank camera viewfinders
- No recording lag or start-up artefacts
- PR [Feature: Recording and multiple viewfinders via AVCaptureVideoDataOutput](https://github.com/tobyspark/ORBIT-Camera/pull/1)

v0.3.0
- Main screen lists things
- Main screen allows you to add new thing
- Main screen allows you to remove existing things
- Thing screen can record new videos
- Thing screen will page through existing videos
- Thing screen allows you to re-record videos
- Thing screen allows you to delete videos



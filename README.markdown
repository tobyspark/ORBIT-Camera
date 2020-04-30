# ORBIT Camera

## Informational content

The non-UI text such as introduction prose is parsed into the app from markdown files in the `Resources` folder of this repository.

### Linking to headers
Links within a document work. Use the markdown link format, with the slugified heading text as fragment identifier. What's a slug? It's the URL-friendly form, i.e. with dashes instead of spaces, lowercase, etc. What's the fragment identifier? It's the part of the URL after the page in the form `#xxx`.
i.e. at the time of writing, one document has the link `[Training videos for small/medium things](#training-videos-for-smallmedium-things)` which links to `#### Training videos for small/medium things`. To be clear, the number of hashes in the markdown heading is irrelevant, you'll always use one hash in the link.

### Setting the help screen selection points
The help screen displays an excerpt of the TutorialScript markdown file. The excerpt starts at a heading, and the help screen will then attempt to present it at a heading appropriate to the current video kind. Where to start, and which heading is to be used for which video kind is set at the top of the tutorial script document. They are `key: value` pairs, so the heading in the document is the value, on the right. 
Example – `help-start-header: collecting-videos-with-orbit`
Example – `train-header: training-videos-for-smallmedium-things`

(Attempts, because... as of iOS 13-or-so, it seems security has locked down something that accessibility relies on, and accessibility hasn't yet caught up) 

## Known issues
- Thing labels cannot be edited #12
- Thing list editing not accessible, i.e. can't delete via voiceover. #19
- Re-recording a video does not re-upload #20
- AppNetwork.videosSession.tasks is not persisted #24
- Record should have sonic feedback during recording #14

## Not yet implemented
- Server state changes reflected in app, e.g. video statuses for verified, notifications
- Deleting a video does not update server
- Study phases implemented in app
- Contrast effect and control for viewfinder / videos

## Version history

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



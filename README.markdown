# ORBIT Camera

## Known issues
- Thing labels cannot be edited
- Thing list editing not accessible, i.e. can't delete via voiceover.
- Re-recording a video does not re-upload
- AppNetwork.videosSession.tasks is not persisted

## Not yet implemented
- Server state changes reflected in app, e.g. video statuses for verified, notifications
- Deleting a video does not update server
- Study phases implemented in app
- Contrast effect and control for viewfinder / videos
- Participant on-boarding

## Version history

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



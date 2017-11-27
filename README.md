## HiDef

## Notes
* Primary reference: https://developer.apple.com/library/content/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQPlayback/PlayingAudio.html
* many Apple docs make reference to the SpeakHere example, but it has disappeared from the developer site. There are some clones on GitHub. Looking at the code, it's really all C++ and not ObjC anyway.
* Google: speakhere sample code
  * https://github.com/robovm/apple-ios-samples/tree/master/SpeakHere
  * https://github.com/shaojiankui/SpeakHere
* Here's an example that uses the new dispatchQueue API: https://gist.github.com/hpux735/2913436
* You need to wait until the AudioQueue finishes running before you dispose of it
  * https://lists.apple.com/archives/coreaudio-api/2008/Sep/msg00155.html
  * https://developer.apple.com/documentation/audiotoolbox/1502091-audioqueueaddpropertylistener
  * https://developer.apple.com/documentation/audiotoolbox/audioqueuepropertylistenerproc
  * Already have an exmple of listening to the property in the audioplayer/main.swift example

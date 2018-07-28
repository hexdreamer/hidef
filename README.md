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
  * Already have an example of listening to the property in the audioplayer/main.swift example

* Start/Stop still have some glitches. May need to make a distinction in play state between playing/stopped/paused. If you stop, play won't play again because all the priming needs to be re-done.

* Sat Jul 28 09:22:08 PDT 2018 - AnvilOfCrom suddenly doesn't play because AudioFileGetPropertyInfo suddenly returns kAudioFileInvalidChunkError. Vocalize doesn't do this. Nevertheless, Vocalise returns 0 size for this call anyway, so the info is not crucial. Going to add a way to bypass this.
  * TODO:
    * 1) make PDFileAudioSource have ignorable errors instead of catching any error - should not allow throwing an error if you can help it - makes it difficult for debugging in the future.
    * 2) add play/stopped/pause states so we can have cleaner start/resume behaviour
    
